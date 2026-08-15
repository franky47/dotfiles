---
name: plannotator-last
description: Open Plannotator on the latest rendered assistant message and use the returned annotations to revise that message or continue.
---

# Plannotator Last

Use this skill when the user wants to annotate the latest assistant response in Plannotator.

Do not send a commentary/status message before running the command. The command
targets the latest rendered assistant response, so a preamble can mistakenly
become the thing being annotated.

Create a unique empty temporary directory and use it as the terminal `workdir`.
Never run from `$HOME`. On `echo`, launch through `webctl`, using a stable
unique slug and the current Discord message URL:

```bash
webctl preview \
  --slug <stable-unique-slug> \
  --discord-url <origin-message-url> \
  --title <human-readable-title> \
  --project <project-name> \
  -- plannotator last
```

On other hosts, run `plannotator last` directly.

On `echo`, run the launcher as a tracked background process and share the HTTPS
URL that `webctl` prints. Wait for Plannotator to finish. Remove the temporary
directory when it exits. Incorporate returned feedback immediately. Carry
approval notes into later work without redoing the approved response solely
because of them.

Run the command yourself.
