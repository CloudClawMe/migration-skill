#!/usr/bin/env bash
set -euo pipefail

# Reference export helper for the old OpenClaw instance.
#
# Required env vars:
# MIGRATION_ID
# UPLOAD_URL
# ARCHIVE_FORMAT      (tar.gz | zip)
# SCOPE_MODE          (full | selective)
# SCOPE_SUMMARY
#
# Optional env vars:
# MAX_SIZE_BYTES      (default: 5368709120)
# WORKSPACE_DIR       (default: $HOME/.openclaw/workspace)
# EXPORT_ROOT         (default: ./tmp-openclaw-export)
# INCLUDE_SECRETS     (true | false) - must be decided explicitly with the user before running

MAX_SIZE_BYTES="${MAX_SIZE_BYTES:-5368709120}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
EXPORT_ROOT="${EXPORT_ROOT:-./tmp-openclaw-export}"
ARCHIVE_FORMAT="${ARCHIVE_FORMAT:-tar.gz}"
SCOPE_MODE="${SCOPE_MODE:-full}"
SCOPE_SUMMARY="${SCOPE_SUMMARY:-full workspace export}"
INCLUDE_SECRETS="${INCLUDE_SECRETS:-false}"

STAGING_DIR="$EXPORT_ROOT/openclaw-export"
MANIFEST="$STAGING_DIR/manifest.json"
SECRET_REPORT="$EXPORT_ROOT/likely-secrets.txt"

require() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required env var: $var" >&2
    exit 1
  fi
}

require MIGRATION_ID
require UPLOAD_URL

mkdir -p "$EXPORT_ROOT"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/workspace"

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  echo "Workspace not found: $WORKSPACE_DIR" >&2
  exit 1
fi

echo "Estimating export size..."
ESTIMATED_SIZE_BYTES=$(du -sb "$WORKSPACE_DIR" | awk '{print $1}')
echo "Estimated size: $ESTIMATED_SIZE_BYTES bytes"

if (( ESTIMATED_SIZE_BYTES > 4294967296 )); then
  echo "WARNING: estimated size exceeds 4.0 GiB"
fi
if (( ESTIMATED_SIZE_BYTES > 4831838208 )); then
  echo "WARNING: estimated size exceeds 4.5 GiB; cleanup recommended"
fi
if (( ESTIMATED_SIZE_BYTES > MAX_SIZE_BYTES )); then
  echo "ERROR: estimated size exceeds hard limit of $MAX_SIZE_BYTES bytes" >&2
  exit 2
fi

echo "Scanning for likely secret-bearing paths..."
{
  find "$WORKSPACE_DIR" \( -name '.env' -o -path '*/.ssh/*' -o -path '*/.aws/*' -o -iname '*secret*' -o -iname '*token*' -o -iname '*key*' -o -iname '*credential*' -o -iname '*auth*' -o -iname '*.pem' -o -iname '*.p12' -o -iname '*.kdbx' \) -print 2>/dev/null || true
} | sed "s#^$WORKSPACE_DIR#.#" | sort -u > "$SECRET_REPORT"

echo "Potential secret-bearing paths list written to: $SECRET_REPORT"
echo "Do not continue until the user has explicitly approved whether secrets should be included."

if [[ "$SCOPE_MODE" == "full" ]]; then
  echo "Copying full workspace..."
  cp -a "$WORKSPACE_DIR"/. "$STAGING_DIR/workspace/"
else
  echo "Selective mode selected. Populate $STAGING_DIR/workspace/ only with the approved subset before continuing."
  exit 3
fi

ARCHIVE_PATH=""
if [[ "$ARCHIVE_FORMAT" == "tar.gz" ]]; then
  ARCHIVE_PATH="$EXPORT_ROOT/openclaw-export.tar.gz"
elif [[ "$ARCHIVE_FORMAT" == "zip" ]]; then
  ARCHIVE_PATH="$EXPORT_ROOT/openclaw-export.zip"
else
  echo "Unsupported ARCHIVE_FORMAT: $ARCHIVE_FORMAT" >&2
  exit 4
fi

CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TOP_LEVEL_PATHS=$(find "$STAGING_DIR/workspace" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | jq -R . | jq -s .)

cat > "$MANIFEST" <<EOF
{
  "format_version": "1",
  "migration_id": "$MIGRATION_ID",
  "created_at": "$CREATED_AT",
  "export_mode": "$SCOPE_MODE",
  "includes_secrets": $INCLUDE_SECRETS,
  "scope_summary": "$SCOPE_SUMMARY",
  "top_level_paths": $TOP_LEVEL_PATHS,
  "estimated_size_bytes": $ESTIMATED_SIZE_BYTES,
  "archive_format": "$ARCHIVE_FORMAT"
}
EOF

echo "Packing archive..."
if [[ "$ARCHIVE_FORMAT" == "tar.gz" ]]; then
  tar -C "$EXPORT_ROOT" -czf "$ARCHIVE_PATH" openclaw-export
else
  (
    cd "$EXPORT_ROOT"
    zip -qr "$ARCHIVE_PATH" openclaw-export
  )
fi

ARCHIVE_SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH")
if (( ARCHIVE_SIZE_BYTES > MAX_SIZE_BYTES )); then
  echo "ERROR: archive exceeds hard limit of $MAX_SIZE_BYTES bytes" >&2
  exit 5
fi

SHA256=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

cat > "$MANIFEST" <<EOF
{
  "format_version": "1",
  "migration_id": "$MIGRATION_ID",
  "created_at": "$CREATED_AT",
  "export_mode": "$SCOPE_MODE",
  "includes_secrets": $INCLUDE_SECRETS,
  "scope_summary": "$SCOPE_SUMMARY",
  "top_level_paths": $TOP_LEVEL_PATHS,
  "estimated_size_bytes": $ESTIMATED_SIZE_BYTES,
  "archive_size_bytes": $ARCHIVE_SIZE_BYTES,
  "sha256": "$SHA256",
  "archive_format": "$ARCHIVE_FORMAT"
}
EOF

# Repack once more so the final manifest is inside the archive.
echo "Repacking final archive with completed manifest..."
if [[ "$ARCHIVE_FORMAT" == "tar.gz" ]]; then
  rm -f "$ARCHIVE_PATH"
  tar -C "$EXPORT_ROOT" -czf "$ARCHIVE_PATH" openclaw-export
else
  rm -f "$ARCHIVE_PATH"
  (
    cd "$EXPORT_ROOT"
    zip -qr "$ARCHIVE_PATH" openclaw-export
  )
fi

ARCHIVE_SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH")
SHA256=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

echo "Uploading archive..."
curl --fail --show-error -X PUT -T "$ARCHIVE_PATH" "$UPLOAD_URL"

echo
echo "UPLOAD_OK"
echo "archive_path=$ARCHIVE_PATH"
echo "archive_size_bytes=$ARCHIVE_SIZE_BYTES"
echo "sha256=$SHA256"
echo "includes_secrets=$INCLUDE_SECRETS"
echo "scope_mode=$SCOPE_MODE"
echo "scope_summary=$SCOPE_SUMMARY"
