#!/bin/bash

source "$QTOOLS_PATH/utils/index.sh"
source "$QTOOLS_PATH/utils/hardware.sh"

if [ "$(get_vendor)" != "AuthenticAMD" ]; then
    echo "This script is for AMD CPUs only."
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_NAME="set_cpu_performance.sh"
SCRIPT_PATH="$QTOOLS_PATH/scripts/install/amd/$SCRIPT_NAME"

echo -e "${YELLOW}Starting setup for CPU Performance Script...${NC}"
# Check if cron jobs already exist
CRON_REBOOT=$(crontab -l 2>/dev/null | grep "@reboot $SCRIPT_PATH")
CRON_PERIODIC=$(crontab -l 2>/dev/null | grep "0 */6 \* \* \* $SCRIPT_PATH")

if [ -z "$CRON_REBOOT" ]; then
    echo "Adding cron job to run at reboot..."
    (crontab -l 2>/dev/null; echo "@reboot $SCRIPT_PATH") | crontab -
else
    echo -e "${GREEN}Cron job for reboot already exists.${NC}"
fi

if [ -z "$CRON_PERIODIC" ]; then
    echo "Adding cron job to run every 6 hours..."
    (crontab -l 2>/dev/null; echo "0 */6 * * * $SCRIPT_PATH") | crontab -
else
    echo -e "${GREEN}Cron job for periodic execution already exists.${NC}"
fi

echo -e "${GREEN}Setup complete!${NC}"
echo "The CPU performance script is located at: $SCRIPT_PATH"
echo "It will run at system reboot and every 6 hours."
echo "Logs will be stored in: /root/scripts/logs/"
echo -e "${YELLOW}You can manually run the script at any time with: $SCRIPT_PATH${NC}"