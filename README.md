# OpenClaw Migration Kit

This folder contains a practical migration flow for importing an existing user-owned OpenClaw instance into a fresh CloudClaw / managed OpenClaw instance.

## Recommended flow

- Storage: Hetzner Object Storage (S3-compatible)
- Upload method: one-time presigned PUT URL
- Import target: only a fresh empty instance
- Import mode: full workspace export/import
- Secrets: included, but only after explicit confirmation from the user
- Max archive size: 5 GiB hard limit
- Archive retention: auto-delete after 24h (recommended)

## Why presigned PUT instead of permanent write-only keys

Hetzner Object Storage is S3-compatible, so the usual S3 presigned upload flow should work.

Advantages:
- no long-lived credentials on the user's old instance
- one upload, one object, one deadline
- easy to bind the upload to a single migration session
- easier cleanup and abuse control

## Object key format

Use this object key format:

`imports/<telegram_user_id>/<migration_id>/openclaw-export.tar.zst`

Example:

`imports/123456789/0a8c46a6-d3d3-4b2e-8fd1-26d9bf0a7f78/openclaw-export.tar.zst`

## Migration session fields

When the user starts migration in the Telegram bot, create:

- `migration_id` — UUID
- `telegram_user_id`
- `secret` — random high-entropy token
- `upload_url` — presigned PUT URL to the final object key
- `expires_at`
- `max_size_bytes` — 5368709120
- `github_instruction_url` — public URL to `agent-full-instruction.md`

## User flow

1. User taps `Import from existing OpenClaw`
2. Your bot creates migration session + presigned upload URL
3. Your bot sends one short prompt from `public-agent-prompt.md`
4. User pastes that prompt into their old OpenClaw
5. Old OpenClaw downloads/reads the full public migration instruction from GitHub
6. Old OpenClaw:
   - inspects the old instance
   - lists detected secrets / keys / sessions to the user
   - asks for confirmation
   - builds export archive
   - uploads archive to Hetzner via presigned URL
   - returns manifest summary and checksum
7. User returns to your Telegram bot and presses `Finish import`
8. New instance receives an import skill instruction and restores the archive
9. Import skill validates archive, extracts it into the fresh workspace, and confirms success

## 5 GiB warnings

The old agent must warn the user before upload when:

- archive size exceeds 4.0 GiB — say upload may be slow and interruption risk is higher
- archive size exceeds 4.5 GiB — strongly recommend cleaning cache / temp files first
- archive size exceeds 5.0 GiB — abort export

## What still needs wiring on your side

You asked me to do everything I can. The remaining pieces that require your action are:

1. Give me the real GitHub repo / path where these files should live publicly
2. Give me the Hetzner S3 credentials / bucket details if you want me to wire concrete code against them
3. Expose the migration start / finish flow in your Telegram bot
4. Make sure new instances include the import skill from `import-skill/SKILL.md`

## Suggested cleanup rules

After import completes or expires:
- delete uploaded archive
- delete manifest sidecar if you store one
- mark migration session consumed
- never allow the same `migration_id` to import twice

## Suggested archive layout

Archive root:

- `manifest.json`
- `workspace/`

Inside `workspace/`, place the full exported OpenClaw workspace contents.

## Included files in this kit

- `public-agent-prompt.md` — short prompt pasted into the user's old OpenClaw
- `agent-full-instruction.md` — full public migration instruction hosted on GitHub
- `export-openclaw.sh` — migration helper script the agent can create/run
- `manifest.schema.json` — export manifest format
- `import-skill/SKILL.md` — skill for the fresh instance to import the archive
- `telegram-copy-ru.md` — ready-to-use user-facing copy
