# Hetzner S3 notes

Hetzner Object Storage is S3-compatible, so the migration flow should use the same general approach as AWS S3:

- create bucket
- create object key for a single migration
- generate presigned PUT URL with short TTL
- optionally generate presigned GET URL for the import side

## Recommended TTLs

- Upload URL: 30 to 60 minutes
- Download URL for import worker: 15 to 30 minutes

## Recommended metadata stored server-side

For each migration session:
- migration_id
- telegram_user_id
- secret hash
- object key
- expected max size (5 GiB)
- created_at
- expires_at
- status: created / uploaded / imported / expired / failed
- archive_size_bytes
- sha256 (reported by exporter)

## Important

Do not trust the client-reported checksum blindly. It is useful for diagnostics and consistency checks, but your backend should still enforce:
- object path binding
- TTL
- single-use migration session
- size limit
- import only into the matching Telegram user's fresh instance
