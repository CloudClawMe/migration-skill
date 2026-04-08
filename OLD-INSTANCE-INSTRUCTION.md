# Full migration instruction for the old OpenClaw instance

This document is intended to be public and auditable.

## Goal

Prepare an archive from the user's old OpenClaw instance and upload it to the exact one-time upload URL provided by the new instance.

## Important principles

- be transparent with the user
- inspect before exporting
- ask before including secrets
- create one archive only
- upload only to the exact one-time upload URL
- do not exceed the size limit

## Inputs

The caller will provide:
- migration id
- upload URL
- upload expiry timestamp
- max upload size
- requested migration mode
- requested archive format
- requested scope summary

## Supported migration modes

### Full migration

Export the full OpenClaw workspace needed to preserve continuity.

Typical items included:
- long-term memory
- daily memory files
- identity and user profile files
- notes and project files
- website files
- custom skills
- supporting workspace data
- secrets / active credentials only after explicit confirmation

### Selective migration

Export only the user-approved subset.

Examples:
- only memory and notes
- only website files
- only custom skills
- exclude secrets
- exclude temporary files

Before exporting, restate the selected scope clearly.

## Required behavior

### 1. Inspect the existing instance

Inspect the current OpenClaw workspace.

Before export, present the user with:
- a short summary of what will be migrated
- a concrete list of likely secret-bearing paths
- a confirmation question about whether secrets / active credentials should be included

Do not print secret values. Only show paths and short descriptions.

### 2. Estimate size before packing

Estimate size first.

Warn the user if estimated size is:
- above 4.0 GiB — upload may be slow
- above 4.5 GiB — cleanup is strongly recommended
- above the configured hard limit — abort

### 3. Build export structure

Create this structure before archiving:

```text
openclaw-export/
  manifest.json
  workspace/
```

Place exported files under `openclaw-export/workspace/`.

### 4. Manifest requirements

Create `manifest.json` with at least:
- `format_version`
- `migration_id`
- `created_at`
- `export_mode`
- `includes_secrets`
- `scope_summary`
- `top_level_paths`
- `estimated_size_bytes`
- `archive_size_bytes`
- `sha256`
- `archive_format`

If a schema file is available, follow it.

### 5. Archive format

Preferred: `tar.gz`

Allowed alternative: `zip`

Use exactly the format requested by the migration session.

Preferred archive names:
- `openclaw-export.tar.gz`
- `openclaw-export.zip`

### 6. Upload

Upload the archive with a single HTTP PUT to the exact provided upload URL.

Do not add extra query parameters.
Do not change the destination path.

### 7. Final report

After successful upload, report:
- final archive filename
- final archive size
- SHA-256 checksum
- whether secrets were included
- exported scope summary
- top-level exported paths
- `UPLOAD_OK`

## Secret detection guidance

Look for likely secret-bearing paths such as:
- `.env`
- `.ssh/`
- `.aws/`
- files containing `secret`, `token`, `key`, `credential`, `auth`
- provider auth or session files
- bot tokens
- service-account files

Do not show raw secret values in chat.

## Safety rules

- do not delete the source workspace
- do not mutate user files except temporary export artifacts
- if validation or upload fails, explain briefly and stop
- clean temporary artifacts when practical after success
