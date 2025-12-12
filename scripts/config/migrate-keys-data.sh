#!/bin/bash
# HELP: Migrate keys and sensitive config from a source .config into the current node
# PARAM: <source_config_dir> Absolute path containing config.yml and keys.yml
# Usage: qtools migrate-keys-data /path/to/.config

SOURCE_DIR="$1"

# Validate input
if [ -z "$SOURCE_DIR" ]; then
  echo "Error: Missing source .config directory argument"
  echo "Usage: qtools migrate-keys-data /absolute/path/to/.config"
  return 1 2>/dev/null || exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory not found: $SOURCE_DIR"
  return 1 2>/dev/null || exit 1
fi

SOURCE_KEYS_FILE="$SOURCE_DIR/keys.yml"
SOURCE_CONFIG_FILE="$SOURCE_DIR/config.yml"

if [ ! -f "$SOURCE_KEYS_FILE" ] || [ ! -f "$SOURCE_CONFIG_FILE" ]; then
  echo "Error: Source must contain keys.yml and config.yml"
  echo "       Missing: $( [ ! -f "$SOURCE_KEYS_FILE" ] && echo keys.yml ) $( [ ! -f "$SOURCE_CONFIG_FILE" ] && echo config.yml )"
  return 1 2>/dev/null || exit 1
fi

# Ensure required env vars/files exist
if [ -z "$QUIL_CONFIG_FILE" ] || [ -z "$QUIL_KEYS_FILE" ] || [ -z "$QUIL_NODE_PATH" ]; then
  echo "Error: Required environment not loaded. Run via 'qtools migrate-keys-data'"
  return 1 2>/dev/null || exit 1
fi

# Check if QUIL config file exists (handle quilibrium-owned files)
if ! safe_file_exists "$QUIL_CONFIG_FILE"; then
  echo "Error: Current config.yml not found at $QUIL_CONFIG_FILE"
  return 1 2>/dev/null || exit 1
fi

# Check if file is owned by quilibrium user and use sudo if needed
file_owner=$(stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || sudo stat -c '%U' "$QUIL_CONFIG_FILE" 2>/dev/null || stat -f '%Su' "$QUIL_CONFIG_FILE" 2>/dev/null || echo "")
use_sudo=false
if [ "$file_owner" == "quilibrium" ] && [ "$(whoami)" != "root" ]; then
    use_sudo=true
fi

CURRENT_CONFIG_DIR="$(dirname "$QUIL_CONFIG_FILE")"

# Read values from source config
SOURCE_ENCRYPTION_KEY="$(yq eval '.key.keyManagerFile.encryptionKey // ""' "$SOURCE_CONFIG_FILE")"
SOURCE_P2P_PRIV_KEY="$(yq eval '.p2p.peerPrivKey // ""' "$SOURCE_CONFIG_FILE")"

if [ -z "$SOURCE_ENCRYPTION_KEY" ] || [ "$SOURCE_ENCRYPTION_KEY" = "null" ]; then
  echo "Error: Source .key.encryptionKey is empty or missing"
  return 1 2>/dev/null || exit 1
fi

if [ -z "$SOURCE_P2P_PRIV_KEY" ] || [ "$SOURCE_P2P_PRIV_KEY" = "null" ]; then
  echo "Error: Source .p2p.peerPrivKey is empty or missing"
  return 1 2>/dev/null || exit 1
fi

# Create backup directory with rotation: .config-bak, .config-bak.1, .2, ...
BACKUP_BASE="$QUIL_NODE_PATH/.config-bak"
BACKUP_DIR="$BACKUP_BASE"
if [ -d "$BACKUP_DIR" ]; then
  i=1
  while [ -d "$BACKUP_BASE.$i" ]; do
    i=$((i+1))
  done
  BACKUP_DIR="$BACKUP_BASE.$i"
fi

mkdir -p "$BACKUP_DIR"

# Backup current files (if present)
if [ -f "$QUIL_KEYS_FILE" ]; then
  cp "$QUIL_KEYS_FILE" "$BACKUP_DIR/keys.yml"
fi
cp "$QUIL_CONFIG_FILE" "$BACKUP_DIR/config.yml"

if command -v log >/dev/null 2>&1; then
  log "Backed up current config to $BACKUP_DIR"
else
  echo "Backed up current config to $BACKUP_DIR"
fi

# Replace keys.yml
rm -f "$QUIL_KEYS_FILE"
cp "$SOURCE_KEYS_FILE" "$QUIL_KEYS_FILE"

# Update sensitive fields in current config.yml from source values
if [ "$use_sudo" == "true" ]; then
    ENCRYPTION_KEY="$SOURCE_ENCRYPTION_KEY" sudo yq -i e '.key.keyManagerFile.encryptionKey = strenv(ENCRYPTION_KEY)' "$QUIL_CONFIG_FILE"
    P2P_PRIV_KEY="$SOURCE_P2P_PRIV_KEY" sudo yq -i e '.p2p.peerPrivKey = strenv(P2P_PRIV_KEY)' "$QUIL_CONFIG_FILE"
else
    ENCRYPTION_KEY="$SOURCE_ENCRYPTION_KEY" yq -i e '.key.keyManagerFile.encryptionKey = strenv(ENCRYPTION_KEY)' "$QUIL_CONFIG_FILE"
    P2P_PRIV_KEY="$SOURCE_P2P_PRIV_KEY" yq -i e '.p2p.peerPrivKey = strenv(P2P_PRIV_KEY)' "$QUIL_CONFIG_FILE"
fi

if command -v log >/dev/null 2>&1; then
  log "Migrated keys.yml and updated .key.keyManagerFile.encryptionKey and .p2p.peerPrivKey in $QUIL_CONFIG_FILE"
else
  echo "Migrated keys.yml and updated .key.keyManagerFile.encryptionKey and .p2p.peerPrivKey in $QUIL_CONFIG_FILE"
fi

echo "Done. Backups saved at $BACKUP_DIR"


