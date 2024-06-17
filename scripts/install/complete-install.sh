#/bin/bash

os_arch="$(get_os_arch)"

get_remote_quil_files() {
    local files="$1"
    local dest_dir=$2

    while IFS= read -r file; do
        if [[ "$file" == *"$os_arch"* ]]; then
        local file_url="https://releases.quilibrium.com/${file}"
        local dest_file="${QUIL_NODE_PATH}/${file}"

        if [ ! -f "$dest_file" ]; then
            log "Downloading $file_url to $dest_file"
            curl -o "$dest_file" "$file_url"
        else
            log "File $dest_file already exists"
        fi
        fi
    done <<< "$files"
}

apt-get -q update

# make sure git is installed
install_package git

# qtools install-go
qtools add-auto-complete

cd $HOME
mkdir -p $QUIL_NODE_PATH
mkdir -p $QUIL_CLIENT_PATH

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")
qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

get_remote_quil_files $node_files $QUIL_NODE_PATH
get_remote_quil_files $qclient_files $QUIL_CLIENT_PATH

qtools install-grpc
qtools setup-firewall
qtools install-cron

# Copy the service to the systemd directory
cp $QTOOLS_PATH/$QUIL_SERVICE_NAME $SYSTEMD_SERVICE_PATH
cp $QTOOLS_PATH/$QUIL_DEBUG_SERVICE_NAME $SYSTEMD_SERVICE_PATH


# tells server to always start node service on reboot
qtools enable

# start the server
qtools start
qtools update-service

qtools restore-backup &
qtools modify-config &
qtools disable-ssh-passwords

source $QTOOLS_PATH/scripts/install/customization.sh

# log "Installation complete. Going for a reboot."

wait
reboot
