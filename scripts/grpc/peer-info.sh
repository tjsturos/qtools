#!/bin/bash
# HELP: Prints the Peer Info for this node.

grpcurl -plaintext -max-msg-sz 5000000 localhost:8337 quilibrium.node.node.pb.NodeService.GetPeerInfo
