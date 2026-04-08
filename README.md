# migration-skill

A dedicated OpenClaw skill for migrating a user from an **old existing OpenClaw instance** into a **new destination instance**.

## What this repository contains

This repository is structured as a real skill repository, with the main skill in:

- `SKILL.md` — the primary migration skill for the **new instance**

Supporting documents:

- `OLD-INSTANCE-MESSAGE-TEMPLATE.md` — the exact message template that the new instance should generate for the old instance
- `OLD-INSTANCE-INSTRUCTION.md` — the full public instruction the old instance should read and follow
- `manifest.schema.json` — suggested archive manifest schema
- `export-openclaw.sh` — reference helper export script for the old instance
- `telegram-copy-ru.md` — user-facing copy ideas in Russian
- `HETZNER-S3-NOTES.md` — storage notes

## Intended flow

1. User starts migration on the **new instance**
2. The new instance uses `SKILL.md`
3. The new instance asks whether migration is **full** or **selective**
4. The new instance requests a one-time upload session from a backend / microservice
5. The new instance gives the user one ready-to-send message for the old instance
6. The old instance creates an archive and uploads it to the one-time URL
7. The new instance downloads and restores the uploaded archive

## Important design choice

This repository does **not** embed long-lived S3 credentials.

Those should live behind a separate microservice that:
- creates migration sessions
- returns one-time upload URLs
- optionally resolves uploaded archives back into download URLs for import

## Recommended archive format

Recommended default:
- `tar.gz`

Allowed fallback:
- `zip`

## Current status

The repository is now organized around the migration skill itself.

What is still external:
- the backend / microservice for issuing upload URLs
- the runtime wiring that lets the skill call that backend directly
