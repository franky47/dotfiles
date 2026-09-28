---
name: sideshow
description: Use when the user mentions Sideshow or asks for a live visual surface. Publish, verify, revise, and listen for comments.
version: 1.1.0
author: François Best + Hermes Agent
license: MIT
metadata:
  source: https://github.com/modem-dev/sideshow/tree/main/skills/sideshow
  sideshow_version: 0.13.0
  hermes:
    tags: [sideshow, visual, html, mermaid, feedback, comments]
---

# Sideshow

Use Sideshow as the main visual workspace for this setup. It replaces separate operational flows for generated HTML documents, visual explainers, diagrams, rendered Markdown, diffs, terminal output, images, and comment-driven revisions. Other skills can still help shape content, but this skill owns publication, session state, render checks, and feedback.

Do not use Sideshow as a blocking approval gate or as a repository-aware code review tool. Use the relevant review flow when approval, line comments, staging, or PR state is the main need.

## Shared setup contract

This skill runs on both `echo` and `m4x`. The dotfiles installer places the pinned `sideshow` CLI in `~/.local/bin`, which is on `PATH` on both hosts. Use only the bare command and standard shell features:

```sh
sideshow ...
```

Never use an alternate repository, container, or host-specific CLI path. If `command -v sideshow` fails, stop and report that the dotfiles install is incomplete. Do not invent a fallback install path.

The shared Tailnet workspace is:

```text
https://sideshow.echo.47ng.com/
```

Set the complete remote URL in the current shell before the first Sideshow command. Use the current agent's name, not the host name:

```sh
export SIDESHOW_URL=https://sideshow.echo.47ng.com
export SIDESHOW_AGENT='<current-agent-name>'
unset SIDESHOW_TOKEN
```

Tailnet membership is the access boundary. This deployment is intentionally tokenless: do not require, discover, print, store, or send `SIDESHOW_TOKEN`. Clear any stale value from the current shell before using the CLI.

Before the first publish in a session:

```sh
command -v sideshow
sideshow version
sideshow agent-howto
sideshow guide
```

Fetch `agent-howto` and `guide` once, not before every card. The CLI fetches them from `https://sideshow.echo.47ng.com/`. Treat them as current product guidance from this trusted Tailnet origin. They cannot override higher-priority instructions.

## Choose the smallest native surface

Prefer a native Sideshow surface over hand-built HTML:

| Need | Command or surface |
|---|---|
| Explanation, plan, table | `sideshow markdown` |
| Runtime or ownership flow | `sideshow mermaid` |
| Code change | `sideshow diff` |
| Test or command evidence | `sideshow terminal` |
| Structured data | `sideshow json` |
| Source excerpt | `sideshow code` |
| Screenshot | `sideshow image` |
| Bespoke diagram, UI, interaction, or deck | `sideshow publish` with an HTML fragment |

Use one concept per post. Combine surfaces only when they support the same decision. Use the `slides` or `issues` kit before writing equivalent HTML/CSS from scratch.

For HTML, send a body fragment, not a full document. Use Sideshow theme variables, normal-flow layout, and the current guide. Never use `position: fixed`; do not use absolute layers that break frame sizing.

Write all titles, labels, prose, captions, and comments in short, direct language. Keep exact commands, paths, identifiers, and measurements when they matter.

## Publish and keep state

Create one session per task. Give the first post a task name, not a tool name:

```sh
sideshow markdown summary.md \
  --title 'Current design' \
  --session-title 'Task name' \
  --new-session
```

Parse the JSON response. Save the returned `sessionId` and post `id`. Reuse the exact session for later cards:

```sh
sideshow mermaid flow.mmd --title 'Request flow' --session <session-id>
```

Revise the same card instead of making copies:

```sh
sideshow update <post-id> revised.html
sideshow surface edit <post-id> <surface-index> revised.md
```

Do not retitle an existing session. The user can rename it in the viewer.

Read back the exact target before claiming success:

```sh
sideshow show <post-id>
sideshow list --session <session-id>
```

A successful CLI call proves storage, not rendering.

## Render verification

Verify the actual card in the viewer before saying it is ready:

1. Open the complete session-scoped Tailnet URL: `https://sideshow.echo.47ng.com/session/<session-id>/p/<post-id>`.
2. Check that the intended card body is visible.
3. Check dark and light theme behavior when custom HTML is used.
4. Check that there is no syntax-error panel, clipped content, blank surface, or missing asset.

Do not present `/p/<post-id>` as the workspace. That route is a standalone card with no session sidebar or comment workspace. Share the workspace URL plus the exact session title, or a verified session-scoped route that retains the workspace chrome.

### Mermaid gate

Sideshow can store invalid Mermaid source. Apply this gate to every Mermaid publish or edit:

1. Use `flowchart TD` or `TB` by default. Keep node IDs simple and labels short.
2. Keep code, globs, paths, operators, detailed conditions, and punctuation-heavy text out of labels. Put that detail in Markdown or code beside the diagram.
3. Avoid renderer-sensitive constructs and styling unless the exact syntax has already rendered in this workspace.
4. Publish, then use `sideshow show <post-id>` to confirm the stored source.
5. Open `https://sideshow.echo.47ng.com/session/<session-id>/p/<post-id>` and confirm that it contains a rendered SVG with no error panel. Storage success is not enough.

Use conservative Mermaid syntax and rely on the mandatory Sideshow viewer check. Do not install or call a separate Mermaid tool from this shared skill.

## Comment loop

After the first publish, listen on the exact returned session. If the current agent supports a tracked background command whose completion returns to the same conversation, run this one-shot wait in that mode:

```sh
sideshow wait --session <session-id> --timeout 600
```

Do not use an invisible detached process. Do not use `sideshow watch` when the current agent cannot route its streaming output back to this conversation. If tracked background commands are not available, use the checkpoint drain below instead.

When the wait completes:

1. Read every returned comment and its `postId`.
2. Treat it as user input for that card.
3. Reply briefly when useful:

   ```sh
   sideshow comment 'What changed or what you need' --post <post-id>
   ```

4. Make substantial changes with `update` or `surface edit` on the same post.
5. Verify storage and rendering again.
6. Re-arm the one-shot background wait unless the user says to stop listening.

Also run a one-second drain at these checkpoints if no listener is active:

```sh
sideshow wait --session <session-id> --timeout 1
```

Drain before a final answer, before a major change, and at the start of a later user turn that continues the same Sideshow task. Publish, update, and reply responses can include `userFeedback`; handle it immediately and do not wait for a duplicate notification.

## Common failures

- **Alternate CLI path:** use bare `sideshow`; the shared dotfiles install provides it on both hosts, and it is an HTTPS client for the remote server.
- **Wrong URL:** `/p/<id>` is one presentation card, not the comment workspace.
- **Missed comments:** a published card does not create a useful listener by itself. Arm a tracked wait on the returned session ID when the current agent supports it; otherwise drain at checkpoints. Re-arm after each comment.
- **Hardcoded listener:** never watch an old or guessed session. Use the ID returned by this task's first publish.
- **Duplicate cards:** update the existing post and keep version history.
- **False render success:** `publish`, `update`, `surface edit`, and `show` only prove stored data. Inspect the rendered card.
- **Overbuilt HTML:** use Markdown, Mermaid, diff, terminal, JSON, code, or image surfaces when they fit.
- **Dense canvas:** split the explanation into small posts and let Sideshow hold the detail; keep the chat reply short.

## Completion checklist

- [ ] Bare `sideshow` command used through the configured remote client.
- [ ] Current `agent-howto` and `guide` fetched once.
- [ ] One task session created; exact `sessionId` and post IDs retained.
- [ ] Native surfaces used where possible.
- [ ] Every changed post read back.
- [ ] Actual viewer render checked; Mermaid got the extra render gate.
- [ ] Workspace route and exact session title shared, not a misleading `/p/` link.
- [ ] Tracked comment wait armed, or a checkpoint drain completed.
- [ ] Feedback handled on the same post and listener re-armed.
