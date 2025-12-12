#!/bin/bash
# HELP: Parse CSV file and add servers to cluster configuration
# PARAM: --from-csv <file>: CSV file to parse
# Usage: qtools cluster-parse-csv --from-csv servers.csv

source $QTOOLS_PATH/scripts/cluster/utils.sh

CSV_FILE=""
DRY_RUN=false
BASE_PORT=$(yq eval ".service.clustering.base_port // \"40000\"" $QTOOLS_CONFIG_FILE)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from-csv)
            CSV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}${ERROR_ICON} Error: --from-csv <file> is required${RESET}"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}${ERROR_ICON} Error: CSV file not found: $CSV_FILE${RESET}"
    exit 1
fi

# Function to add a server to the cluster configuration
add_server_to_config() {
    local ip=$1
    local user=${2:-$DEFAULT_USER}
    local ssh_port=${3:-$DEFAULT_SSH_PORT}
    local data_worker_count=${4:-null}
    local base_port=${5:-$BASE_PORT}

    # Check if the server already exists in the config
    if yq eval ".service.clustering.servers[] | select(.ip == \"$ip\")" "$QTOOLS_CONFIG_FILE" | grep -q .; then
        echo -e "${YELLOW}${WARNING_ICON} Server $ip already exists in the configuration. Removing existing entry.${RESET}"
        yq eval -i "del(.service.clustering.servers[] | select(.ip == \"$ip\"))" "$QTOOLS_CONFIG_FILE"
    fi

    # Add the new server to the configuration
    if [ "$DRY_RUN" == "true" ]; then
        echo -e "${BLUE}${INFO_ICON} [DRY RUN] Would add server $user@$ip:$ssh_port${RESET}"
        if [ "$data_worker_count" != "null" ]; then
            echo -e "${BLUE}${INFO_ICON}   with $data_worker_count workers${RESET}"
        fi
    else
        if [ "$data_worker_count" != "null" ]; then
            yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"data_worker_count\": $data_worker_count, \"base_port\": $base_port}" "$QTOOLS_CONFIG_FILE"
            echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port with $data_worker_count workers${RESET}"
        else
            yq eval -i ".service.clustering.servers += {\"ip\": \"$ip\", \"ssh_port\": $ssh_port, \"user\": \"$user\", \"base_port\": $base_port}" "$QTOOLS_CONFIG_FILE"
            echo -e "${GREEN}${CHECK_ICON} Added server $user@$ip:$ssh_port${RESET}"
        fi
    fi
}

# Read CSV file
# Skip header row and empty lines/comments
line_num=0
while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))

    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Remove leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip header row (first non-empty, non-comment line)
    if [ $line_num -eq 1 ] && [[ "$line" =~ ^[[:alpha:]_]+ ]]; then
        continue
    fi

    # Parse CSV line (handle quoted fields)
    IFS=',' read -ra FIELDS <<< "$line"

    # Extract fields (trim whitespace)
    ip=$(echo "${FIELDS[0]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
    user=$(echo "${FIELDS[1]:-$DEFAULT_USER}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
    ssh_port=$(echo "${FIELDS[2]:-$DEFAULT_SSH_PORT}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
    data_worker_count=$(echo "${FIELDS[3]:-null}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')
    base_port_val=$(echo "${FIELDS[4]:-$BASE_PORT}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '"')

    # Validate required fields
    if [ -z "$ip" ] || [ "$ip" == "null" ]; then
        echo -e "${YELLOW}${WARNING_ICON} Skipping line $line_num: missing IP address${RESET}"
        continue
    fi

    # Validate and convert data_worker_count
    if [ "$data_worker_count" != "null" ] && [ -n "$data_worker_count" ]; then
        if ! [[ "$data_worker_count" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}${WARNING_ICON} Skipping line $line_num: invalid data_worker_count '$data_worker_count'${RESET}"
            continue
        fi
    else
        data_worker_count="null"
    fi

    # Validate ssh_port
    if ! [[ "$ssh_port" =~ ^[0-9]+$ ]]; then
        ssh_port=$DEFAULT_SSH_PORT
    fi

    # Validate base_port
    if ! [[ "$base_port_val" =~ ^[0-9]+$ ]]; then
        base_port_val=$BASE_PORT
    fi

    # Add server to config
    add_server_to_config "$ip" "$user" "$ssh_port" "$data_worker_count" "$base_port_val"
done < "$CSV_FILE"

echo -e "${GREEN}${CHECK_ICON} CSV parsing completed${RESET}"
if [ "$DRY_RUN" != "true" ]; then
    echo -e "${BLUE}${INFO_ICON} Run 'qtools cluster-setup --master' to configure the newly added servers${RESET}"
fi
