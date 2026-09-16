from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from types import SimpleNamespace


PLUGIN_PATH = Path(__file__).resolve().parents[1] / "__init__.py"
SPEC = importlib.util.spec_from_file_location("thread_done_plugin", PLUGIN_PATH)
assert SPEC and SPEC.loader
plugin = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(plugin)


class FakeState:
    def __init__(self):
        self.values = {}
        self.get_calls = 0
        self.set_calls = 0
        self.get_error = None
        self.set_error = None

    def get(self, key, default=None):
        self.get_calls += 1
        if self.get_error:
            raise self.get_error
        return self.values.get(key, default)

    def set(self, key, value):
        if self.set_error:
            raise self.set_error
        self.set_calls += 1
        self.values[key] = value


class FakeActions:
    def __init__(self):
        self.calls = []
        self.title_result = {"ok": True, "action": "set_thread_title"}
        self.reaction_result = {"ok": True, "action": "add_reaction"}
        self.title_error = None
        self.reaction_error = None

    async def set_thread_title(self, **kwargs):
        self.calls.append(("title", kwargs))
        if self.title_error:
            raise self.title_error
        if not isinstance(self.title_result, dict):
            return self.title_result
        return dict(self.title_result)

    async def add_reaction(self, **kwargs):
        self.calls.append(("reaction", kwargs))
        if self.reaction_error:
            raise self.reaction_error
        if not isinstance(self.reaction_result, dict):
            return self.reaction_result
        return dict(self.reaction_result)


class FakeContext:
    def __init__(self):
        self.state = FakeState()
        self.platform_actions = FakeActions()
        self.hooks = {}
        self.commands = {}

    def register_hook(self, name, callback):
        self.hooks[name] = callback

    def register_command(self, name, handler, description="", args_hint=""):
        self.commands[name] = SimpleNamespace(
            handler=handler,
            description=description,
            args_hint=args_hint,
        )


class ThreadDonePluginTests(unittest.IsolatedAsyncioTestCase):
    THREAD_ID = "123"
    PARENT_ID = "456"
    SESSION_KEY = "agent:main:discord:thread:123:123"

    def setUp(self):
        plugin._invocation.set(None)
        self.ctx = FakeContext()
        plugin.register(self.ctx)

    def ordinary_source(self, title="🧹 homelab · Initial placeholder"):
        return SimpleNamespace(
            platform=SimpleNamespace(value="discord"),
            chat_type="thread",
            chat_id=self.THREAD_ID,
            thread_id=self.THREAD_ID,
            parent_chat_id=self.PARENT_ID,
            chat_name=f"47ng / #hermes-home / {title}",
        )

    def slash_source(self, title="🧹 homelab · Prune safe stale worktrees"):
        return SimpleNamespace(
            platform=SimpleNamespace(value="discord"),
            chat_type="thread",
            chat_id=self.THREAD_ID,
            thread_id=self.THREAD_ID,
            parent_chat_id=None,
            chat_name=f"47ng / #{title}",
        )

    def capture_done(self):
        self.ctx.hooks["pre_command"](
            surface="gateway",
            command="done",
            alias_used="done",
            args_raw="",
            session_key=self.SESSION_KEY,
            platform="discord",
        )

    def test_extracts_thread_id_from_gateway_session_key(self):
        self.assertEqual(plugin._discord_thread_id(self.SESSION_KEY), self.THREAD_ID)

    def test_rejects_non_thread_malformed_and_mismatched_session_keys(self):
        bad_keys = (
            "agent:main:discord:channel:123",
            "agent:main:discord:thread:123",
            "agent:main:discord:thread:not-a-number:123",
            "agent:main:discord:thread:123:456",
        )
        for key in bad_keys:
            with self.subTest(key=key), self.assertRaises(ValueError):
                plugin._discord_thread_id(key)

    def test_raw_args_do_not_supply_the_thread_id(self):
        command = self.ctx.commands["done"]
        self.assertEqual(command.args_hint, "")
        self.assertIn("idle native Discord", command.description)

    def test_extracts_full_title_from_message_and_slash_formats(self):
        title = "🧹 homelab · Fix CI / CD pipeline / #123"
        self.assertEqual(
            plugin._thread_title_from_chat_name(
                f"47ng / #hermes-home / {title}", has_parent=True
            ),
            title,
        )
        self.assertEqual(
            plugin._thread_title_from_chat_name(
                f"47ng / hermes-home / {title}", has_parent=True
            ),
            title,
        )
        self.assertEqual(
            plugin._thread_title_from_chat_name(
                f"47ng / #{title}", has_parent=False
            ),
            title,
        )

    def test_refuses_parented_chat_names_without_parent_prefix(self):
        self.assertEqual(
            plugin._thread_title_from_chat_name("bare title", has_parent=True),
            "",
        )
        self.assertEqual(
            plugin._thread_title_from_chat_name("guild / #title", has_parent=True),
            "",
        )

    def test_completed_title_replaces_emoji_but_preserves_other_symbols(self):
        self.assertEqual(plugin._completed_title("🧹 Work"), "✅ Work")
        self.assertEqual(plugin._completed_title("✅ Work"), "✅ Work")
        self.assertEqual(plugin._completed_title("✅"), "✅")
        self.assertEqual(plugin._completed_title("- fix parser"), "✅ - fix parser")
        self.assertEqual(plugin._completed_title("$ deploy"), "✅ $ deploy")
        self.assertEqual(plugin._completed_title("→ migrate"), "✅ → migrate")
        self.assertEqual(plugin._completed_title("± investigate"), "✅ ± investigate")
        self.assertEqual(plugin._completed_title("^ pin"), "✅ ^ pin")

    async def test_slash_refreshes_title_while_preserving_message_parent(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(
                source=self.slash_source("🧹 homelab · Fix CI / CD pipeline")
            )
        )
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIsNone(result)
        self.assertEqual(
            self.ctx.platform_actions.calls,
            [
                (
                    "title",
                    {
                        "platform": "discord",
                        "chat_id": self.THREAD_ID,
                        "thread_id": self.THREAD_ID,
                        "title": "✅ homelab · Fix CI / CD pipeline",
                    },
                ),
                (
                    "reaction",
                    {
                        "platform": "discord",
                        "chat_id": self.PARENT_ID,
                        "message_id": self.THREAD_ID,
                        "emoji": "✅",
                    },
                ),
            ],
        )

    async def test_slash_without_prior_message_does_not_create_partial_state(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.slash_source())
        )
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIn("Send one normal message", result)
        self.assertEqual(self.ctx.state.values, {})
        self.assertEqual(self.ctx.platform_actions.calls, [])

    def test_unchanged_message_metadata_does_not_rewrite_state(self):
        event = SimpleNamespace(source=self.ordinary_source())
        self.ctx.hooks["pre_gateway_dispatch"](event=event)
        self.ctx.hooks["pre_gateway_dispatch"](event=event)
        self.assertEqual(self.ctx.state.get_calls, 1)
        self.assertEqual(self.ctx.state.set_calls, 1)

    def test_unchanged_slash_title_does_not_rewrite_state(self):
        event = SimpleNamespace(source=self.ordinary_source())
        self.ctx.hooks["pre_gateway_dispatch"](event=event)
        slash = SimpleNamespace(
            source=self.slash_source("🧹 homelab · Initial placeholder")
        )
        self.ctx.hooks["pre_gateway_dispatch"](event=slash)
        self.assertEqual(self.ctx.state.get_calls, 1)
        self.assertEqual(self.ctx.state.set_calls, 1)

    def test_empty_platform_event_does_not_consume_state_slot(self):
        self.ctx.hooks["gateway_platform_event"](
            platform="discord",
            event_type="thread_created",
            payload={"thread_id": self.THREAD_ID},
        )
        self.assertEqual(self.ctx.state.values, {})

    def test_state_cap_evicts_oldest_metadata_change(self):
        for offset in range(plugin._MAX_TRACKED_THREADS + 1):
            thread_id = str(10_000 + offset)
            self.ctx.hooks["gateway_platform_event"](
                platform="discord",
                event_type="thread_created",
                payload={"thread_id": thread_id, "name": f"Work {offset}"},
            )
        stored = self.ctx.state.values[plugin._STATE_KEY]
        self.assertEqual(len(stored), plugin._MAX_TRACKED_THREADS)
        self.assertNotIn("10000", stored)
        self.assertIn(str(10_000 + plugin._MAX_TRACKED_THREADS), stored)

    async def test_observed_platform_event_still_works(self):
        self.ctx.hooks["gateway_platform_event"](
            platform="discord",
            event_type="thread_created",
            payload={
                "thread_id": self.THREAD_ID,
                "parent_chat_id": self.PARENT_ID,
                "name": "🧹 Hermes · Work",
                "owner_id": "42",
            },
        )
        self.ctx.hooks["gateway_platform_event"](
            platform="discord",
            event_type="thread_renamed",
            payload={
                "thread_id": self.THREAD_ID,
                "parent_chat_id": self.PARENT_ID,
                "new_name": "🧹 Hermes · Renamed work",
                "owner_id": "42",
            },
        )
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIsNone(result)
        self.assertEqual(
            self.ctx.platform_actions.calls[0][1]["title"],
            "✅ Hermes · Renamed work",
        )
        self.assertEqual(self.ctx.platform_actions.calls[1][1]["chat_id"], self.PARENT_ID)

    async def test_action_failures_include_provider_detail(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.ctx.platform_actions.title_result = {
            "ok": False,
            "error": "discord_api_error",
            "detail": "Missing Permissions",
        }
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIn("discord_api_error: Missing Permissions", result)
        self.assertEqual(len(self.ctx.platform_actions.calls), 1)

    async def test_invalid_or_raising_action_results_are_contained(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.ctx.platform_actions.title_result = None
        self.capture_done()
        result = await self.ctx.commands["done"].handler("")
        self.assertIn("invalid platform-action result", result)

        self.ctx.platform_actions.title_result = {"ok": True}
        self.ctx.platform_actions.reaction_error = RuntimeError("unexpected")
        self.capture_done()
        result = await self.ctx.commands["done"].handler("")
        self.assertIn("reaction failed", result)
        self.assertIn("check the gateway log", result)

    async def test_reaction_failure_reports_partial_success_and_detail(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.ctx.platform_actions.reaction_result = {
            "ok": False,
            "error": "not_found",
            "detail": "opening message unavailable",
        }
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIn("Thread title was marked done", result)
        self.assertIn("not_found: opening message unavailable", result)

    def test_state_persistence_failure_is_contained(self):
        self.ctx.state.set_error = OSError("disk full")
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.assertEqual(self.ctx.state.values, {})

    async def test_invalid_or_unreadable_state_fails_with_log_guidance(self):
        self.ctx.state.values[plugin._STATE_KEY] = "corrupt"
        self.capture_done()
        result = await self.ctx.commands["done"].handler("")
        self.assertIn("check the gateway log", result)

        self.ctx.state.get_error = RuntimeError("unreadable")
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.assertEqual(self.ctx.state.set_calls, 0)
        self.capture_done()
        result = await self.ctx.commands["done"].handler("")
        self.assertIn("check the gateway log", result)

    async def test_done_fails_closed_without_observed_thread_metadata(self):
        self.capture_done()

        result = await self.ctx.commands["done"].handler("")

        self.assertIn("Send one normal message", result)
        self.assertEqual(self.ctx.platform_actions.calls, [])

    async def test_invocation_is_consumed_once(self):
        self.ctx.hooks["pre_gateway_dispatch"](
            event=SimpleNamespace(source=self.ordinary_source())
        )
        self.capture_done()
        self.assertIsNone(await self.ctx.commands["done"].handler(""))

        result = await self.ctx.commands["done"].handler("")
        self.assertIn("only available", result)
        self.assertEqual(len(self.ctx.platform_actions.calls), 2)


if __name__ == "__main__":
    unittest.main()
