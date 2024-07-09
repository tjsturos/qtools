#!/bin/bash
# HELP: Finds and prints the number of peers this node has seen.

grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo | grep peerId | wc -l
