---
name: openclaw-import
description: "Import a full OpenClaw workspace archive into a fresh instance using a one-time migration URL or object URL. Use when the user is restoring or migrating an existing OpenClaw into a new empty instance."
metadata: { "openclaw": { "emoji": "📦" } }
---

# OpenClaw Import Skill

Use this skill only when importing an existing OpenClaw archive into a fresh empty instance.

## Preconditions

- Target instance must be fresh / empty
- Archive must be a migration archive produced by the migration flow
- Maximum archive size is 5 GiB
- Secrets may be included; do not print secret values back to the user

## Expected inputs

You should be given either:
- a direct download URL to the archive, or
- an internal migration identifier that backend logic can resolve to a download URL

## Import procedure

1. Download the archive locally
2. Determine whether it is `.tar.zst` or `.tar.gz`
3. Extract it into a temporary directory
4. Validate that the archive contains:
   - `openclaw-export/manifest.json`
   - `openclaw-export/workspace/`
5. Read `manifest.json`
6. Verify:
   - `format_version == "1"`
   - `export_mode == "full"`
   - archive size is <= 5 GiB
   - target workspace is fresh enough for a full restore
7. Replace the current workspace contents with `openclaw-export/workspace/`
8. Confirm that key files exist after restore
9. Report completion to the user in plain language

## Key files to verify after import

Check for whichever of these exist in the archive:
- `MEMORY.md`
- `USER.md`
- `SOUL.md`
- `IDENTITY.md`
- `TOOLS.md`
- `memory/`

## Safety rules

- Never merge into a non-empty actively used workspace without explicit instruction
- Never display secret values in chat
- If validation fails, abort before replacing files
- If archive exceeds 5 GiB, abort
- Be alert for suspicious paths or extraction attempts outside the target directory

## Practical shell outline

Example sequence:

```bash
mkdir -p /tmp/openclaw-import
cd /tmp/openclaw-import
curl -L "$ARCHIVE_URL" -o archive.bin
file archive.bin
mkdir extracted
# if tar.zst
unzstd -c archive.bin | tar -xvf - -C extracted
# if tar.gz
# tar -xzf archive.bin -C extracted
```

Then validate the extracted structure and restore only if the target workspace is intended to be replaced.

## User-facing response style

Keep the reply simple:
- archive received
- archive validated
- workspace restored
- import complete

If import fails, explain briefly what went wrong and whether the user should try again with a fresh migration link.
