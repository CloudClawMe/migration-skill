#!/usr/bin/env bash
set -euo pipefail

# Required env vars:
# TELEGRAM_USER_ID
# MIGRATION_ID
# SECRET
# UPLOAD_URL
# MAX_SIZE_BYTES (optional, default 5368709120)
# WORKSPACE_DIR (optional, default $HOME/.openclaw)
# EXPORT_ROOT (optional, default ./tmp-openclaw-export)

MAX_SIZE_BYTES="${MAX_SIZE_BYTES:-5368709120}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/.openclaw}"
EXPORT_ROOT="${EXPORT_ROOT:-./tmp-openclaw-export}"
STAGING_DIR="$EXPORT_ROOT/openclaw-export"
ARCHIVE_BASE="$EXPORT_ROOT/openclaw-export.tar"
ARCHIVE_ZST="$ARCHIVE_BASE.zst"
ARCHIVE_GZ="$ARCHIVE_BASE.gz"
MANIFEST="$STAGING_DIR/manifest.json"

require() {
  local var="$1"
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required env var: $var" >&2
    exit 1
  fi
}

require TELEGRAM_USER_ID
require MIGRATION_ID
require SECRET
require UPLOAD_URL

mkdir -p "$EXPORT_ROOT"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/workspace"

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  echo "Workspace not found: $WORKSPACE_DIR" >&2
  exit 1
fi

echo "Estimating workspace size..."
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

echo "Scanning for likely secrets..."
SECRET_REPORT="$EXPORT_ROOT/likely-secrets.txt"
{
  find "$WORKSPACE_DIR" \( -name '.env' -o -iname '*secret*' -o -iname '*token*' -o -iname '*key*' -o -iname '*credential*' -o -iname '*auth*' -o -path '*/.aws/*' -o -path '*/.ssh/*' -o -iname '*.pem' -o -iname '*.p12' -o -iname '*.kdbx' \) -print 2>/dev/null || true
} | sed "s#^$WORKSPACE_DIR#.#" | sort -u > "$SECRET_REPORT"

TOP_LEVEL_PATHS=$(find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | jq -R . | jq -s .)

cat <<EOF
Potential secret-bearing paths written to:
$SECRET_REPORT

Review them with the user before continuing.
EOF

read -r -p "Type YES_INCLUDE_SECRETS to continue with full export including secrets: " CONFIRM
if [[ "$CONFIRM" != "YES_INCLUDE_SECRETS" ]]; then
  echo "Aborted by operator."
  exit 3
fi

INCLUDES_SECRETS=true

echo "Copying workspace..."
cp -a "$WORKSPACE_DIR"/. "$STAGING_DIR/workspace/"

ARCHIVE_PATH=""
if command -v zstd >/dev/null 2>&1; then
  echo "Creating .tar.zst archive..."
  tar -C "$EXPORT_ROOT" -cf - openclaw-export | zstd -19 -T0 -o "$ARCHIVE_ZST"
  ARCHIVE_PATH="$ARCHIVE_ZST"
else
  echo "zstd not available, creating .tar.gz archive..."
  tar -C "$EXPORT_ROOT" -czf "$ARCHIVE_GZ" openclaw-export
  ARCHIVE_PATH="$ARCHIVE_GZ"
fi

ARCHIVE_SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH")
if (( ARCHIVE_SIZE_BYTES > MAX_SIZE_BYTES )); then
  echo "ERROR: archive exceeds hard limit of $MAX_SIZE_BYTES bytes" >&2
  exit 4
fi

SHA256=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
HOSTNAME_VALUE=$(hostname || true)

cat > "$MANIFEST" <<EOF
{
  "format_version": "1",
  "migration_id": "$MIGRATION_ID",
  "telegram_user_id": "$TELEGRAM_USER_ID",
  "created_at": "$CREATED_AT",
  "export_mode": "full",
  "includes_secrets": $INCLUDES_SECRETS,
  "top_level_paths": $TOP_LEVEL_PATHS,
  "estimated_size_bytes": $ESTIMATED_SIZE_BYTES,
  "archive_size_bytes": $ARCHIVE_SIZE_BYTES,
  "sha256": "$SHA256",
  "source": {
    "product": "OpenClaw",
    "hostname": "$HOSTNAME_VALUE",
    "workspace_path": "$WORKSPACE_DIR"
  }
}
EOF

# Re-pack so manifest is included with final checksum metadata in place.
if [[ "$ARCHIVE_PATH" == "$ARCHIVE_ZST" ]]; then
  rm -f "$ARCHIVE_ZST"
  tar -C "$EXPORT_ROOT" -cf - openclaw-export | zstd -19 -T0 -o "$ARCHIVE_ZST"
  ARCHIVE_PATH="$ARCHIVE_ZST"
else
  rm -f "$ARCHIVE_GZ"
  tar -C "$EXPORT_ROOT" -czf "$ARCHIVE_GZ" openclaw-export
  ARCHIVE_PATH="$ARCHIVE_GZ"
fi
ARCHIVE_SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH")
SHA256=$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')

# Update manifest one last time, then repack once more for checksum consistency.
cat > "$MANIFEST" <<EOF
{
  "format_version": "1",
  "migration_id": "$MIGRATION_ID",
  "telegram_user_id": "$TELEGRAM_USER_ID",
  "created_at": "$CREATED_AT",
  "export_mode": "full",
  "includes_secrets": $INCLUDES_SECRETS,
  "top_level_paths": $TOP_LEVEL_PATHS,
  "estimated_size_bytes": $ESTIMATED_SIZE_BYTES,
  "archive_size_bytes": $ARCHIVE_SIZE_BYTES,
  "sha256": "$SHA256",
  "source": {
    "product": "OpenClaw",
    "hostname": "$HOSTNAME_VALUE",
    "workspace_path": "$WORKSPACE_DIR"
  }
}
EOF

if [[ "$ARCHIVE_PATH" == "$ARCHIVE_ZST" ]]; then
  rm -f "$ARCHIVE_ZST"
  tar -C "$EXPORT_ROOT" -cf - openclaw-export | zstd -19 -T0 -o "$ARCHIVE_ZST"
  ARCHIVE_PATH="$ARCHIVE_ZST"
else
  rm -f "$ARCHIVE_GZ"
  tar -C "$EXPORT_ROOT" -czf "$ARCHIVE_GZ" openclaw-export
  ARCHIVE_PATH="$ARCHIVE_GZ"
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
echo "includes_secrets=$INCLUDES_SECRETS"
echo "top_level_paths=$(find "$WORKSPACE_DIR" -mindepth 1 -maxdepth 1 -printf '%f ' | sed 's/ $//')"
