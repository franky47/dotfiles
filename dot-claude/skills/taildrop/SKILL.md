---
name: taildrop
description: Use when the user asks to send, transfer, or taildrop files to a device. Triggers on phrases like "send to 
hex", "transfer to m4x", "taildrop this".
user-invocable: false
---

# Sending files to available Tailscale devices via Taildrop

Known devices:
- m4x
- hex
- echo

## To send files to a device

Use the `tailscale file cp <file> <device>:` command.

> Note the trailing colon, it's important.

## Notes
- Directories are automatically tar'd before sending.
- Files are to be left in place after sending.

## Documentation

For the complete options of Tailscale's file sharing system, run:

``
tailscale file --help`
``
