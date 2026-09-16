"""User plugin providing a deterministic Discord /done command."""

from __future__ import annotations

import contextvars
import logging
import threading
import unicodedata
from typing import Any


_invocation: contextvars.ContextVar[dict[str, str] | None] = contextvars.ContextVar(
    "thread_done_invocation",
    default=None,
)
_state_lock = threading.Lock()
_STATE_KEY = "discord_threads"
_MAX_TRACKED_THREADS = 1000
_STATE_ERROR = "Could not read `/done` thread metadata; check the gateway log."
logger = logging.getLogger(__name__)


def _discord_thread_id(session_key: str) -> str:
    """Extract chat/thread ids from Hermes' Discord thread session key."""
    marker = ":discord:thread:"
    if marker not in session_key:
        raise ValueError("/done must be used inside a Discord thread")

    fields = session_key.split(marker, 1)[1].split(":")
    if len(fields) < 2:
        raise ValueError("Could not resolve the current Discord thread")

    chat_id, thread_id = fields[:2]
    if not chat_id.isdecimal() or not thread_id.isdecimal() or chat_id != thread_id:
        raise ValueError("Could not safely resolve the current Discord thread")
    return thread_id


def _completed_title(current: str) -> str:
    current = current.strip()
    if current == "✅" or current.startswith("✅ "):
        return current
    first, separator, rest = current.partition(" ")
    has_leading_emoji = (
        bool(first) and bool(separator) and unicodedata.category(first[0]) == "So"
    )
    body = rest if has_leading_emoji else current
    return f"✅ {body}".strip()


def _thread_title_from_chat_name(chat_name: str, *, has_parent: bool) -> str:
    """Recover a full title from Hermes' two Discord chat-name formats."""
    parts = chat_name.strip().split(" / ")
    prefix_segments = 2 if has_parent else 1
    if len(parts) <= prefix_segments:
        return ""
    title = " / ".join(parts[prefix_segments:]).strip()
    if not has_parent:
        title = title.removeprefix("#").strip()
    return title


def _action_error(result: dict[str, Any], fallback: str) -> str:
    code = str(result.get("error") or fallback)
    detail = str(result.get("detail") or "").strip()
    return f"{code}: {detail}" if detail else code


def register(ctx) -> None:
    thread_cache: dict[str, Any] | None = None

    def save_thread(
        payload: dict[str, Any], *, require_existing: bool = False
    ) -> bool:
        nonlocal thread_cache
        thread_id = str(payload.get("thread_id") or "").strip()
        if not thread_id.isdecimal():
            logger.debug("thread-done ignored invalid thread id")
            return False

        with _state_lock:
            if thread_cache is None:
                try:
                    stored = ctx.state.get(_STATE_KEY, default={}) or {}
                except Exception:
                    logger.exception(
                        "thread-done could not read plugin state while refreshing metadata"
                    )
                    return False
            else:
                stored = thread_cache
            if not isinstance(stored, dict):
                logger.warning("thread-done state was not a mapping; resetting it")
                stored = {}
            threads = dict(stored)
            existing = threads.get(thread_id)
            if require_existing and not isinstance(existing, dict):
                logger.debug("thread-done has no parent metadata for thread %s", thread_id)
                return False
            metadata = dict(existing) if isinstance(existing, dict) else {}
            parent_chat_id = payload.get("parent_chat_id")
            name = payload.get("name") or payload.get("new_name")
            if parent_chat_id is not None:
                parent_chat_id = str(parent_chat_id).strip()
                if parent_chat_id.isdecimal():
                    metadata["parent_chat_id"] = parent_chat_id
            if name is not None:
                name = str(name).strip()
                if name:
                    metadata["name"] = name

            if not metadata:
                logger.debug("thread-done ignored empty thread metadata")
                return False

            if isinstance(existing, dict) and metadata == existing:
                # Bound persistence writes; eviction recency is last metadata change.
                return True

            threads.pop(thread_id, None)
            threads[thread_id] = metadata
            while len(threads) > _MAX_TRACKED_THREADS:
                threads.pop(next(iter(threads)))
            try:
                ctx.state.set(_STATE_KEY, threads)
            except Exception:
                logger.exception("thread-done could not persist refreshed metadata")
                return False
            thread_cache = threads
            return True

    def on_platform_event(
        *,
        platform: str,
        event_type: str,
        payload: dict[str, Any],
        **_: Any,
    ) -> None:
        if platform == "discord" and event_type in {"thread_created", "thread_renamed"}:
            save_thread(payload)

    def on_pre_gateway_dispatch(*, event: Any, **_: Any) -> None:
        """Refresh metadata from the current native Discord message lane.

        Hermes-created Discord threads are owned by the bot, so their
        thread-created/renamed observer events are rejected by the gateway's
        user-authorization boundary. The normalized inbound SessionSource is
        available on ordinary thread messages with the parent id. Native slash
        interactions omit the parent id, but can refresh the title of a thread
        whose parent was observed previously.
        """
        source = getattr(event, "source", None)
        platform = getattr(getattr(source, "platform", None), "value", None)
        if platform != "discord" or getattr(source, "chat_type", None) != "thread":
            return

        thread_id = str(getattr(source, "thread_id", None) or "").strip()
        parent_chat_id = str(getattr(source, "parent_chat_id", None) or "").strip()
        has_parent = parent_chat_id.isdecimal()
        current_name = _thread_title_from_chat_name(
            str(getattr(source, "chat_name", None) or ""),
            has_parent=has_parent,
        )
        if not thread_id.isdecimal() or not current_name:
            logger.warning("thread-done could not parse normalized Discord thread metadata")
            return

        payload = {"thread_id": thread_id, "name": current_name}
        if has_parent:
            payload["parent_chat_id"] = parent_chat_id
            save_thread(payload)
        else:
            save_thread(payload, require_existing=True)

    def on_pre_command(
        *,
        surface: str,
        command: str,
        platform: str | None = None,
        session_key: str | None = None,
        **_: Any,
    ) -> None:
        if surface == "gateway" and command == "done" and platform == "discord":
            _invocation.set(
                {
                    "session_key": str(session_key or ""),
                }
            )

    async def handle_done(_raw_args: str) -> str | None:
        invocation = _invocation.get()
        _invocation.set(None)
        if not invocation:
            return "`/done` is only available from a Discord gateway thread."

        try:
            thread_id = _discord_thread_id(invocation["session_key"])
        except ValueError as exc:
            return str(exc)

        try:
            threads = ctx.state.get(_STATE_KEY, default={}) or {}
        except Exception:
            logger.exception("thread-done could not read plugin state")
            return _STATE_ERROR
        if not isinstance(threads, dict):
            logger.warning("thread-done state was not a mapping")
            return _STATE_ERROR
        metadata = threads.get(thread_id) or {}
        if not isinstance(metadata, dict):
            logger.warning("thread-done metadata for %s was not a mapping", thread_id)
            return _STATE_ERROR
        parent_chat_id = str(metadata.get("parent_chat_id") or "")
        current_name = str(metadata.get("name") or "")
        if not parent_chat_id or not current_name:
            return (
                "`/done` does not yet know this thread's parent and title. "
                "Send one normal message in the thread, then retry `/done`."
            )

        completed_name = _completed_title(current_name)
        try:
            renamed = await ctx.platform_actions.set_thread_title(
                platform="discord",
                chat_id=thread_id,
                thread_id=thread_id,
                title=completed_name,
            )
        except Exception:
            logger.exception("thread-done title action raised unexpectedly")
            return "Could not mark the thread done; check the gateway log."
        if not isinstance(renamed, dict) or not renamed.get("ok"):
            if not isinstance(renamed, dict):
                renamed = {"error": "invalid platform-action result"}
            return f"Could not mark the thread done: {_action_error(renamed, 'rename failed')}"

        try:
            reacted = await ctx.platform_actions.add_reaction(
                platform="discord",
                chat_id=parent_chat_id,
                message_id=thread_id,
                emoji="✅",
            )
        except Exception:
            logger.exception("thread-done reaction action raised unexpectedly")
            return (
                "Thread title was marked done, but the reaction failed; "
                "check the gateway log."
            )
        if not isinstance(reacted, dict) or not reacted.get("ok"):
            if not isinstance(reacted, dict):
                reacted = {"error": "invalid platform-action result"}
            return (
                "Thread title was marked done, but the opening-message reaction failed: "
                f"{_action_error(reacted, 'reaction failed')}"
            )

        # Native Discord slash dispatch removes its deferred ephemeral response.
        # Returning None avoids posting a redundant channel message.
        return None

    ctx.register_hook("pre_gateway_dispatch", on_pre_gateway_dispatch)
    ctx.register_hook("pre_command", on_pre_command)
    ctx.register_hook("gateway_platform_event", on_platform_event)
    ctx.register_command(
        "done",
        handler=handle_done,
        description="Mark this idle native Discord work thread done",
    )
