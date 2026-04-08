# migration-skill

A dedicated OpenClaw skill for migrating a user from an **old existing OpenClaw instance** into a **new destination instance**.

## What this repository contains

This repository is structured as a skill repository, with the main skill in:

- `SKILL.md` — the primary migration skill for the **new instance**

Supporting documents:

- `OLD-INSTANCE-MESSAGE-TEMPLATE.md` — the exact message template that the new instance should generate for the old instance
- `OLD-INSTANCE-INSTRUCTION.md` — the full public instruction the old instance should read and follow
- `manifest.schema.json` — suggested archive manifest schema
- `export-openclaw.sh` — reference helper export script for the old instance
- `telegram-copy-ru.md` — user-facing copy ideas in Russian
- `HETZNER-S3-NOTES.md` — storage notes
- `INTEGRATION.md` — presigner service wiring for the new host
- `.env.example` — example environment variables for the new host integration

## Intended flow

1. User starts migration on the **new instance**
2. The new instance uses `SKILL.md`
3. The new instance asks whether migration is **full** or **selective**
4. The new instance generates a fresh `migration_id`
5. The new instance calls the presigner service for a one-time upload URL
6. The new instance gives the user one ready-to-send message for the old instance
7. The old instance creates an archive and uploads it to the one-time URL
8. The new instance calls the presigner service for a one-time download URL
9. The new instance downloads and restores the uploaded archive

## Presigner microservice

This skill is designed to work with a separate migration presigner service.

Current expected endpoint base:
- `https://migration-presigner.claw-slave1.4129.pro`

Current upload URL endpoint:
- `POST /v1/migrations/upload-url`

Current download URL endpoint:
- `POST /v1/migrations/download-url`

Auth model:
- `Authorization: Bearer <INTERNAL_API_TOKEN>`

### Example request: upload-url

```bash
curl -X POST https://migration-presigner.claw-slave1.4129.pro/v1/migrations/upload-url \
  -H 'Authorization: Bearer <INTERNAL_API_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
    "telegram_user_id": "123456789",
    "migration_id": "550e8400-e29b-41d4-a716-446655440000",
    "archive_format": "tar.gz",
    "content_type": "application/gzip",
    "expires_in": 3600
  }'
```

### Example request: download-url

```bash
curl -X POST https://migration-presigner.claw-slave1.4129.pro/v1/migrations/download-url \
  -H 'Authorization: Bearer <INTERNAL_API_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
    "object_key": "imports/123456789/550e8400-e29b-41d4-a716-446655440000/openclaw-export.tar.gz",
    "expires_in": 3600
  }'
```

## Important design choice

This repository does **not** embed long-lived S3 credentials.

Those live behind the separate presigner microservice.
The new host talks to the presigner.
The old host receives only the already-issued upload URL and public instructions.

## Recommended archive format

Recommended default:
- `tar.gz`

Allowed fallback:
- `zip`

## Publishing / installation goal

This repository is meant to be published as a reusable skill repo so it can be installed on a fresh new instance.

For a production install, the new instance should be configured with:
- presigner base URL
- internal bearer token
- public instruction URL
- default upload/download expiry
- maximum upload size
