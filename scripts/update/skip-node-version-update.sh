#! /bin/bash

VERSION=$1

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)*$ ]]; then
    echo "Error: Invalid version format. Expected format: <int>.<int>(.<int>)+"
    exit 1
fi

yq -i ".scheduled_tasks.updates.node.skip_version = \"$VERSION\"" $QTOOLS_CONFIG_FILE
