# Integration guide for the new OpenClaw host

This document explains how the **new destination instance** should use the migration presigner service.

## Goal

The new host is responsible for:
- generating a fresh migration id
- requesting a one-time upload URL from the presigner
- sending the old host only a ready-made instruction message
- later requesting a one-time download URL for import

The old host should never receive presigner credentials.

## Environment variables

Recommended variables on the new host:

- `MIGRATION_PRESIGNER_BASE_URL`
- `MIGRATION_PRESIGNER_TOKEN`
- `MIGRATION_INSTRUCTION_URL`
- `MIGRATION_DEFAULT_EXPIRES_IN`
- `MIGRATION_MAX_SIZE_BYTES`

Example:

```env
MIGRATION_PRESIGNER_BASE_URL=https://migration-presigner.claw-slave1.4129.pro
MIGRATION_PRESIGNER_TOKEN=replace-me
MIGRATION_INSTRUCTION_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/OLD-INSTANCE-INSTRUCTION.md
MIGRATION_DEFAULT_EXPIRES_IN=3600
MIGRATION_MAX_SIZE_BYTES=5368709120
```

## Step 1: request upload URL

Request:

```bash
curl -X POST "$MIGRATION_PRESIGNER_BASE_URL/v1/migrations/upload-url" \
  -H "Authorization: Bearer $MIGRATION_PRESIGNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "telegram_user_id": "123456789",
    "migration_id": "550e8400-e29b-41d4-a716-446655440000",
    "archive_format": "tar.gz",
    "content_type": "application/gzip",
    "expires_in": 3600
  }'
```

Expected response fields:
- `object_key`
- `upload_url`
- `expires_in`
- `expires_at`
- `max_size_bytes`

## Step 2: generate message for the old host

Use the returned `upload_url` and `object_key` metadata to fill `OLD-INSTANCE-MESSAGE-TEMPLATE.md`.

Important:
- include only the upload URL
- do not include internal bearer tokens
- do not include storage credentials

## Step 3: request download URL after upload

Once the old host reports `UPLOAD_OK`, request a one-time download URL:

```bash
curl -X POST "$MIGRATION_PRESIGNER_BASE_URL/v1/migrations/download-url" \
  -H "Authorization: Bearer $MIGRATION_PRESIGNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "object_key": "imports/123456789/550e8400-e29b-41d4-a716-446655440000/openclaw-export.tar.gz",
    "expires_in": 3600
  }'
```

Expected response fields:
- `download_url`
- `expires_in`
- `expires_at`

## Suggested runtime behavior in the skill

1. choose migration mode
2. generate `migration_id`
3. call upload-url endpoint
4. store `object_key`
5. generate message for old host
6. wait for `UPLOAD_OK`
7. call download-url endpoint with stored `object_key`
8. download archive
9. validate structure
10. import into fresh workspace

## Safety

- never show bearer tokens to the user
- never log full presigned URLs unless absolutely necessary
- prefer short expiry windows
- reject archives above the configured max size
- import only into the matching fresh destination instance
