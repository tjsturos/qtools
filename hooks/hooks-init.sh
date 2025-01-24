#!/bin/bash
# Initialize hooks directory and permissions

# Hook directories
HOOKS_BASE="/etc/node/hooks"
declare -A HOOK_DIRS=(
    ["start.d"]="$HOOKS_BASE/start.d"
    ["stop.d"]="$HOOKS_BASE/stop.d"
    ["proof_start.d"]="$HOOKS_BASE/proof_start.d"
    ["proof_submit.d"]="$HOOKS_BASE/proof_submit.d"
)

HOOKS_LOG="/var/log/node_hooks.log"

# Create hook directories
for dir in "${HOOK_DIRS[@]}"; do
    sudo mkdir -p "$dir"
done

# Install default hooks from qtools hooks directory
sudo cp -r $QTOOLS_PATH/hooks/start.d/* "${HOOK_DIRS[start.d]}/" 2>/dev/null || true
sudo cp -r $QTOOLS_PATH/hooks/stop.d/* "${HOOK_DIRS[stop.d]}/" 2>/dev/null || true
sudo cp -r $QTOOLS_PATH/hooks/proof_start.d/* "${HOOK_DIRS[proof_start.d]}/" 2>/dev/null || true
sudo cp -r $QTOOLS_PATH/hooks/proof_submit.d/* "${HOOK_DIRS[proof_submit.d]}/" 2>/dev/null || true

# Set permissions
for dir in "${HOOK_DIRS[@]}"; do
    sudo chmod 755 "$dir"
    sudo find "$dir" -type f -exec chmod +x {} \;
done

sudo touch $HOOKS_LOG
sudo chown $USER:$USER $HOOKS_LOG

# Move original node binary if needed
if [ ! -f "/usr/local/bin/node.real" ] && [ -f "/usr/local/bin/node" ]; then
    sudo mv /usr/local/bin/node /usr/local/bin/node.real
fi

# Install wrapper
sudo cp $QTOOLS_PATH/hooks/node_wrapper /usr/local/bin/node
sudo chmod +x /usr/local/bin/node 