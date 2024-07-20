#!/bin/bash
# HELP: Prints the current frame count.

IS_APP_FINISHED_STARTING="$(is_app_finished_starting)"

if [ $IS_APP_FINISHED_STARTING == "true" ]; then
    echo "$(grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo | grep -oP '"maxFrame":\s*"\K[^"]+')"
else
    echo "Could not fetch frame count.  App hasn't finished starting."
fi
