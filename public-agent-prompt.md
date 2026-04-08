# Prompt for the user's old OpenClaw

Copy everything below and send it to the user's existing OpenClaw instance.

---

You are helping the user migrate this OpenClaw instance into a fresh managed OpenClaw instance.

First, read the full migration instruction from this public URL and follow it strictly:

`{{GITHUB_INSTRUCTION_URL}}`

Migration session data:
- Telegram user id: `{{TELEGRAM_USER_ID}}`
- Migration id: `{{MIGRATION_ID}}`
- Secret: `{{SECRET}}`
- Upload URL: `{{UPLOAD_URL}}`
- Upload expires at: `{{EXPIRES_AT}}`
- Max upload size: `5 GiB`

Important rules:
- Perform a full export of the existing OpenClaw workspace
- Before exporting, inspect the workspace and explicitly list detected secrets, tokens, keys, session files, and credentials that appear likely to be included
- Ask the user for confirmation before exporting secrets
- If the user declines, abort and explain that this migration flow is configured for full migration including secrets
- Create the archive exactly in the format described in the public instruction
- Upload only to the provided upload URL
- After upload, report back with:
  - final archive size
  - SHA-256 checksum
  - whether secrets were included
  - the list of top-level exported paths
  - `UPLOAD_OK`

If the archive would exceed 5 GiB, stop and tell the user what is taking space and what to clean first.

---
