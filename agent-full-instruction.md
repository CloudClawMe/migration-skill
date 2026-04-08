# Full migration instruction for an existing OpenClaw instance

This document is intended to be public and auditable. The user may inspect it before running migration.

## Goal

Export the current OpenClaw workspace from the old instance, including secrets only after explicit confirmation, package it into a single archive, and upload it to the one-time upload URL provided by the destination service.

## Non-goals

- Do not upload anywhere except the exact provided upload URL
- Do not split the archive into multiple parts
- Do not continue if the final archive would exceed 5 GiB
- Do not silently include secrets without first listing and confirming them with the user

## Inputs

The caller will provide:

- Telegram user id
- migration id
- secret
- upload URL
- upload expiry timestamp
- max upload size

## Required behavior

### 1. Inspect the current instance

Inspect the existing OpenClaw workspace and identify likely sensitive material, including but not limited to:

- `.env` files
- API keys
- bearer tokens
- SSH keys
- cloud credentials
- cookies/session files
- provider auth files
- bot tokens
- service account JSON files
- database credentials

Before export, present the user with:

- a short summary of what will be migrated
- a specific list of likely sensitive files or secret-bearing paths
- a direct yes/no confirmation request

Suggested wording:

> I found files that likely contain secrets or active credentials. This migration flow is configured to include them so the new instance can continue from the same state. Review the list below and confirm if I should proceed.

If the user does not confirm, stop.

### 2. Measure size before packing

Estimate export size first.

Warn the user if estimated size is:

- above 4.0 GiB — upload may be slow and fragile
- above 4.5 GiB — strongly recommend cleanup first
- above 5.0 GiB — abort

### 3. Export format

Create a folder structure like this before archiving:

```text
openclaw-export/
  manifest.json
  workspace/
```

Copy the full OpenClaw workspace contents into `openclaw-export/workspace/`.

### 4. Manifest

Create `manifest.json` using the schema in `manifest.schema.json`.

At minimum include:

- `format_version`
- `migration_id`
- `telegram_user_id`
- `created_at`
- `export_mode = "full"`
- `includes_secrets`
- `top_level_paths`
- `estimated_size_bytes`
- `archive_size_bytes`
- `sha256`

### 5. Archive format

Preferred archive name:

`openclaw-export.tar.zst`

If `zstd` is unavailable, `openclaw-export.tar.gz` is acceptable.

### 6. Upload

Upload the archive with a single HTTP PUT to the exact provided upload URL.

Recommended command pattern:

```bash
curl -X PUT -T openclaw-export.tar.zst "<UPLOAD_URL>"
```

Do not add custom destination paths. The upload URL already defines the object key.

### 7. Final report to the user

After successful upload, report:

- archive filename
- final size
- sha256 checksum
- whether secrets were included
- top-level exported paths
- `UPLOAD_OK`

## Suggested detection rules for likely secrets

Look for file names or paths containing:

- `.env`
- `secret`
- `token`
- `key`
- `credential`
- `auth`
- `.npmrc`
- `.pypirc`
- `.aws`
- `.ssh`
- `gcloud`
- `service-account`
- `cookies`
- `session`

Also inspect common text files for patterns such as:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `BOT_TOKEN`
- `DATABASE_URL`

## Preferred implementation approach

The easiest path is:

1. Create a helper shell script in the workspace
2. Run the script
3. Show the user the findings before upload
4. Upload after confirmation

A reference helper script is provided separately as `export-openclaw.sh`

## Safety notes

- Do not delete the source workspace
- Do not mutate user files except creating temporary export artifacts
- Clean temporary export files if possible after successful upload
- Never print full secret values in chat; only print paths and secret types
