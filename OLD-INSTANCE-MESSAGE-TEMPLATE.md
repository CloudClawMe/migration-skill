# Message template for the user's old OpenClaw instance

Send the filled message below to the user's old instance.

---

You are helping the user migrate data from this old OpenClaw instance into a new OpenClaw instance.

First, read the full public migration instruction and follow it strictly:

`{{INSTRUCTION_URL}}`

Migration session data:
- Migration id: `{{MIGRATION_ID}}`
- Upload URL: `{{UPLOAD_URL}}`
- Upload expires at: `{{EXPIRES_AT}}`
- Max upload size: `{{MAX_SIZE_BYTES}}`
- Requested migration mode: `{{MIGRATION_MODE}}`
- Requested archive format: `{{ARCHIVE_FORMAT}}`
- Requested scope summary: `{{SCOPE_SUMMARY}}`

Important rules:
- The upload URL is already pre-issued by the new host; do not request any other URL and do not ask for storage credentials
- Inspect this instance first and summarize what will be migrated
- Explicitly list likely sensitive files, keys, tokens, session files, and credentials that may be included
- Ask the user whether secrets / active credentials should be included before building the archive
- If the user declines, continue only if the requested migration scope allows excluding secrets; otherwise stop and explain why
- Build exactly one archive in the requested format
- Upload only to the provided `Upload URL`
- Do not invent any other destination path
- After successful upload, reply with:
  - final archive filename
  - final archive size
  - SHA-256 checksum
  - whether secrets were included
  - exported scope summary
  - top-level exported paths
  - `UPLOAD_OK`

If the archive would be too large, stop and explain what should be cleaned up first.

---
