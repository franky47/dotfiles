---
name: plannotator-review
description: Open Plannotator's browser-based code review UI for the current worktree or a pull request URL, then act on the feedback that comes back.
---

# Plannotator Review

Use this skill when the user wants to review current code changes in Plannotator instead of reading a diff inline.

On `echo`, launch reviews only through `webctl`, never by invoking
`plannotator review` directly:

```bash
webctl review \
  --slug <stable-unique-slug> \
  --discord-url <origin-thread-or-message-url> \
  --title <human-readable-title> \
  --project <project-name> \
  -- review --git
```

Use the current Discord thread/message URL so feedback remains bound to the
originating conversation. Run the launcher as a tracked background process
when the review must remain live.

On other hosts, run `plannotator review` for the current worktree or
`plannotator review "<pr-url>"` for a pull request.

Behavior:

1. Confirm the intended local diff or PR scope before launching.
2. On `echo`, launch through `webctl review` with the exact origin Discord URL.
   On other hosts, run Plannotator directly.
3. Verify the registered review URL is reachable and report it in the origin thread.
4. Wait for feedback. If annotations arrive, address them in the same conversation.
5. Treat approval/LGTM as the gate for commit, push, or PR actions when the user's workflow requires it.

Do not ask the user to copy shell commands into chat. Run the command yourself.
