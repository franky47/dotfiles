---
name: plannotator-annotate
description: Open Plannotator's annotation UI for a markdown file, plain-text config file (.yaml, .json, .toml, .ini, .csv, .log, …), HTML file, URL, or folder and then respond to the returned annotations.
---

# Plannotator Annotate

Use this skill when the user wants to annotate a document in Plannotator instead of reviewing it inline in chat.

Run from the document's repository or vault root. For a standalone file, run
from its containing directory. Never start from `$HOME`. If there is no clear
project or document directory, create a unique empty temporary directory and
remove it after Plannotator exits.

On `echo`, launch through `webctl`, using a stable unique slug and the current
Discord message URL:

```bash
webctl preview \
  --slug <stable-unique-slug> \
  --discord-url <origin-message-url> \
  --title <human-readable-title> \
  --project <project-name> \
  -- plannotator annotate "<path-or-url>" --no-jina
```

On other hosts, run:

```bash
plannotator annotate "<path-or-url>" --no-jina
```

On `echo`, run the launcher as a tracked background process and share the HTTPS
URL that `webctl` prints. Wait for Plannotator to finish. Address returned
annotations immediately. Carry approval notes into later work without
reopening the approved document solely because of them. If Plannotator cannot
resolve the target, identify the concrete file, URL, or folder and rerun it
yourself.

Do not ask the user to run the command.
