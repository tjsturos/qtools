#!/bin/bash

os_arch="$(get_os_arch)"
log "Downloading release files..."

get_remote_quil_files() {
    local files="$1"
    local dest_dir=$2

    while IFS= read -r file; do
        if [[ "$file" == *"$os_arch"* ]]; then
        local file_url="https://releases.quilibrium.com/${file}"
        local dest_file="${dest_dir}/${file}"

        if [ ! -f "$dest_file" ]; then
            log "Downloading $file_url to $dest_file"
            curl -o "$dest_file" "$file_url"
        else
            log "File $dest_file already exists"
        fi
        fi
    done <<< "$files"
}

mkdir -p $QUIL_NODE_PATH
mkdir -p $QUIL_CLIENT_PATH

node_files=$(fetch_available_files "https://releases.quilibrium.com/release")
qclient_files=$(fetch_available_files "https://releases.quilibrium.com/qclient-release")

get_remote_quil_files $node_files $QUIL_NODE_PATH
get_remote_quil_files $qclient_files $QUIL_CLIENT_PATH