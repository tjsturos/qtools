#!/bin/bash
# HELP: Add commonly-used qtools environment variables to .bashrc
# Usage: qtools add-env-var

log "Adding commonly-used qtools environment variables to $BASHRC_FILE..."

# Function to add an environment variable if it doesn't already exist
add_env_var() {
    local VAR_NAME="$1"
    local VAR_VALUE="$2"

    # Check if the export already exists in .bashrc
    if grep -q "^export $VAR_NAME=" "$BASHRC_FILE" 2>/dev/null; then
        log "Environment variable $VAR_NAME already exists in $BASHRC_FILE. Skipping."
        return 0
    fi

    # Construct the export line
    local EXPORT_LINE="export $VAR_NAME=\"$VAR_VALUE\""

    # Add the export to .bashrc (append_to_file already logs)
    append_to_file "$BASHRC_FILE" "$EXPORT_LINE" true
}

# Calculate QUIL_BASE_PATH similar to qtools.sh
QUIL_BASE_PATH="$HOME/ceremonyclient"
if [ -f "$QTOOLS_CONFIG_FILE" ] && command -v yq >/dev/null 2>&1; then
    SERVICE_USER=$(yq '.service.default_user // "quilibrium"' $QTOOLS_CONFIG_FILE 2>/dev/null || echo "quilibrium")
    if [ "$SERVICE_USER" == "quilibrium" ]; then
        QUIL_BASE_PATH="/home/quilibrium/ceremonyclient"
        CONFIGURED_NODE_PATH=$(yq '.service.quilibrium_node_path // ""' $QTOOLS_CONFIG_FILE 2>/dev/null)
        if [ -n "$CONFIGURED_NODE_PATH" ] && [ "$CONFIGURED_NODE_PATH" != "null" ] && [ "$CONFIGURED_NODE_PATH" != "" ]; then
            CONFIGURED_NODE_PATH=$(echo "$CONFIGURED_NODE_PATH" | sed "s|\$HOME|/home/quilibrium|g")
            QUIL_NODE_PATH_FROM_CONFIG=$(eval echo "$CONFIGURED_NODE_PATH" 2>/dev/null || echo "")
            if [ -n "$QUIL_NODE_PATH_FROM_CONFIG" ] && [ -d "$(dirname "$QUIL_NODE_PATH_FROM_CONFIG" 2>/dev/null)" ]; then
                QUIL_BASE_PATH=$(dirname "$QUIL_NODE_PATH_FROM_CONFIG" 2>/dev/null | sed 's|/node$||' || echo "$QUIL_BASE_PATH")
            fi
        fi
    fi
fi

# Add commonly-used environment variables from qtools.sh
add_env_var "QTOOLS_PATH" "$QTOOLS_PATH"
add_env_var "QTOOLS_CONFIG_FILE" "$QTOOLS_CONFIG_FILE"
add_env_var "QUIL_PATH" "$QUIL_BASE_PATH"
add_env_var "QUIL_NODE_HOME" "$QUIL_BASE_PATH/node"
add_env_var "QUIL_NODE_PATH" "$QUIL_BASE_PATH/node"
add_env_var "QUIL_CLIENT_PATH" "$QUIL_BASE_PATH/client"
add_env_var "QUIL_NODE_BIN" "/usr/local/bin/node"
add_env_var "QTOOLS_BIN_PATH" "/usr/local/bin/qtools"
add_env_var "QUIL_QCLIENT_BIN" "/usr/local/bin/qclient"
add_env_var "GO_BIN_DIR" "/usr/local"
add_env_var "GOROOT" "/usr/local/go"
add_env_var "GOPATH" "$HOME/go"

# Add PATH additions for Go (only if not already present)
if ! grep -q "GOPATH/bin.*GOROOT/bin" "$BASHRC_FILE" 2>/dev/null; then
    PATH_ADDITION="export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH"
    if ! grep -qFx "$PATH_ADDITION" "$BASHRC_FILE" 2>/dev/null; then
        # append_to_file already logs
        append_to_file "$BASHRC_FILE" "$PATH_ADDITION" true
    fi
fi

log "Finished adding environment variables to $BASHRC_FILE"
log "Run 'source $BASHRC_FILE' or start a new terminal session to apply the changes"
