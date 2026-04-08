---
name: migration_skill
description: "Help the user migrate an existing OpenClaw instance into this new instance: clarify scope, request a one-time upload session from backend tooling, generate the exact message for the old instance, and then import the uploaded archive back into this instance."
metadata: { "openclaw": { "emoji": "📦" } }
---

# Migration Skill

Use this skill when the user wants to move data from an **existing / old OpenClaw instance** into **this new instance**.

This skill belongs on the **new destination instance**.

## Goal

Make migration simple for the user:

1. briefly explain what migration will do
2. ask whether they want a **full migration** or a **selective migration**
3. when possible, prefer **full migration** as the default because it is simpler and safer for continuity
4. obtain a **one-time upload session** from the backend / microservice
5. generate one ready-to-send message for the user's **old instance**
6. after the old instance uploads the archive, import it into this instance
7. confirm success in plain language

## Core product behavior

The user should not have to manually assemble instructions.

Your job is to guide the user through the flow and produce the exact message that should be sent to the old instance.

## Migration modes

### 1. Full migration (default)

Prefer this when the user says things like:
- "перенеси всё"
- "хочу как было"
- "полностью перенести старый инстанс"
- "хочу переехать без возни"

What full migration means:
- export the old workspace as an archive
- include memory, notes, identity, user profile, website files, custom skills, settings, and other workspace state
- include secrets / active credentials **only after explicit user confirmation** on the old instance
- upload the archive using the one-time upload URL
- restore the archive into this fresh instance

### 2. Selective migration

Use this only if the user explicitly asks for a partial transfer.

Examples:
- only memories and notes
- only website files
- only custom skills
- no secrets
- no cached files

If selective migration is requested, summarize the exact selected scope before proceeding.

## Required conversation flow on the new instance

## Backend integration contract

This skill assumes a dedicated migration presigner microservice is available.

The **new destination instance** talks to that service directly.
The **old source instance** must never receive storage credentials and does not need to know how URLs are minted.
It should receive only:
- the public instruction URL
- the migration id
- the one-time upload URL
- upload expiry
- max upload size
- migration mode
- archive format
- scope summary

### Presigner endpoints

Expected endpoints:

- `POST /v1/migrations/upload-url`
- `POST /v1/migrations/download-url`

Example upload-url request body:

```json
{
  "telegram_user_id": "123456789",
  "migration_id": "550e8400-e29b-41d4-a716-446655440000",
  "archive_format": "tar.gz",
  "content_type": "application/gzip",
  "expires_in": 3600
}
```

Expected upload-url response:

```json
{
  "bucket": "cloudclaw-migrations",
  "object_key": "imports/123456789/550e8400-e29b-41d4-a716-446655440000/openclaw-export.tar.gz",
  "upload_url": "https://...",
  "expires_in": 3600,
  "expires_at": "2026-04-08T16:00:00Z",
  "max_size_bytes": 5368709120
}
```

Example download-url request body:

```json
{
  "object_key": "imports/123456789/550e8400-e29b-41d4-a716-446655440000/openclaw-export.tar.gz",
  "expires_in": 3600
}
```

Expected download-url response:

```json
{
  "download_url": "https://...",
  "expires_in": 3600,
  "expires_at": "2026-04-08T16:00:00Z"
}
```

Authentication model:
- `Authorization: Bearer <INTERNAL_API_TOKEN>`
- token must be configured on the new host only
- never include this token in user-visible messages or repository examples with real values

### Step 1 — explain briefly

Use plain language. Example:

> Я помогу перенести данные из старого инстанса сюда. Проще всего сделать полный перенос: старый инстанс соберёт архив, загрузит его по одноразовой ссылке, а потом я восстановлю его здесь.

### Step 2 — clarify migration scope

Ask one short question if the scope is not already clear.

Preferred question:

> Хочешь полный перенос или выборочно? Если без уточнений — рекомендую полный.

If the user does not care, choose **full migration**.

### Step 3 — prepare migration session

The new instance should call the migration presigner microservice itself.

Recommended behavior:
1. generate a fresh `migration_id` on the new instance
2. call `POST /v1/migrations/upload-url`
3. store the returned `object_key` for later import
4. generate the user-facing message for the old instance

The upload-url response should provide at least:
- `object_key`
- `upload_url`
- `expires_at`
- `max_size_bytes`
- implied archive filename from the selected format

If a public instruction document is hosted separately, include its URL in the generated message.
If not, the instruction can come from this repository content mirrored to a public URL or pasted inline when needed.

If the backend also returns any secret or internal token, treat it as sensitive and do not expose it to the user or the old instance.

## Upload session contract

Assume the backend will provide a one-time upload URL. Do not embed long-lived storage credentials in this skill or in public files.

Preferred archive format:
- `tar.gz`

Allowed alternative:
- `zip`

The chosen format must be stated in the session data and in the message for the old instance.

## Message generation for the old instance

After the upload session exists, generate a single ready-to-send message for the user.

That message must instruct the old instance to:
1. read the public detailed instruction document
2. inspect the current workspace
3. show the user what is likely to be migrated
4. explicitly ask whether secrets / active credentials should be included
5. build the archive in the required format
6. upload it only to the provided one-time upload URL
7. report `UPLOAD_OK` with archive summary

Use the template from `{baseDir}/OLD-INSTANCE-MESSAGE-TEMPLATE.md`.

Replace placeholders carefully.

## What the old instance must do

The old instance should:
- inspect the existing OpenClaw workspace
- identify likely secret-bearing paths
- ask for confirmation before including secrets
- create one archive file
- upload it with a single HTTP PUT to the provided URL
- report back with archive size, checksum, included scope, and `UPLOAD_OK`

Detailed old-instance behavior is described in `{baseDir}/OLD-INSTANCE-INSTRUCTION.md`.

## Import flow on the new instance

Once the old instance confirms `UPLOAD_OK`, continue here.

### Preconditions before restore

- this instance should be fresh or explicitly approved for replacement
- the uploaded archive must belong to the current migration session
- archive size must be within the configured limit
- the new instance must have the `object_key` returned by the upload-url call

### Restore procedure

1. call `POST /v1/migrations/download-url` with the stored `object_key`
2. download the archive locally from the returned `download_url`
3. detect archive type (`tar.gz` or `zip`)
4. extract into a temporary directory
5. validate expected structure:
   - `openclaw-export/manifest.json`
   - `openclaw-export/workspace/`
6. read `manifest.json`
7. verify:
   - `format_version == "1"`
   - `export_mode` matches requested scope
   - archive belongs to the expected migration session when such metadata exists
8. if this is a full migration, replace current workspace contents with exported workspace
9. verify key files after restore
10. report completion simply

## Key files to verify after restore

Check for whichever are expected in the export:
- `MEMORY.md`
- `USER.md`
- `SOUL.md`
- `IDENTITY.md`
- `TOOLS.md`
- `memory/`
- `skills/`
- `www/`

## Safety rules

- never expose raw secret values in chat
- never silently include secrets; the old instance must ask first
- never upload to any URL other than the exact one-time upload URL
- never import into a non-fresh workspace without explicit approval
- abort if structure validation fails
- abort if archive exceeds the configured hard limit
- be alert for path traversal or suspicious extraction paths

## If backend / microservice is not wired yet

Be honest and useful.

Say that the migration skill structure is ready, but the missing backend piece is the service that issues one-time upload URLs and later resolves the uploaded archive for import.

## User-facing response style

Keep it short and practical.

Good examples:
- `Готово. Я подготовил сообщение для старого инстанса.`
- `Старый инстанс загрузил архив. Начинаю импорт.`
- `Архив проверен. Восстанавливаю данные.`
- `Импорт завершён.`

Avoid long technical explanations unless the user asks.
