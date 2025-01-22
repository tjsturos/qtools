# Available Commands

This document provides a comprehensive list of all available qtools commands.

## Table of Contents
- [Service Commands](#service-commands)
- [Update Commands](#update-commands)
- [Cluster Commands](#cluster-commands)
- [Config Commands](#config-commands)
- [Diagnostic Commands](#diagnostic-commands)
- [Installation Commands](#installation-commands)
- [Shortcut Commands](#shortcut-commands)
- [QClient Commands](#qclient-commands)
- [Backup Commands](#backup-commands)
- [Configuration Commands](#configuration-commands)

## Service Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `start` | Starts the node application service | `--debug`: Start in debug mode | `qtools start` |
| `stop` | Stops the node application service | `--kill`: Force stop<br>`--core-index`: Stop specific core<br>`--wait`: Wait for completion | `qtools stop` |
| `restart` | Restarts the node application service | `--wait`: Wait for next proof before restart | `qtools restart` |
| `status` | Gets the node application service's current status | `--worker <num>`: Check specific worker status | `qtools status` |

## Update Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `update-node` | Updates node to latest version | `--force`: Force update<br>`--skip-clean`: Skip cleanup<br>`--auto`: Auto update mode | `qtools update-node` |
| `self-update` | Updates the Qtools suite | `--auto`: Run in auto mode | `qtools self-update` |
| `update-kernel` | Installs new Linux kernels | None | `qtools update-kernel` |

## Cluster Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `cluster-update` | Updates cluster nodes | `--master`: Run as master<br>`--dry-run`: Test without changes<br>`--update-qtools`: Update qtools on nodes | `qtools cluster-update` |
| `cluster-start` | Starts cluster services | None | `qtools cluster-start` |
| `cluster-stop` | Stops cluster services | None | `qtools cluster-stop` |
| `cluster-restart` | Restarts cluster services | None | `qtools cluster-restart` |
| `cluster-status` | Gets cluster services' current status | None | `qtools cluster-status` |
| `cluster-remote-command` | Executes a command on all remote servers in the cluster | `"<command>"`: Command to execute | `qtools cluster-remote-command "qtools self-update"` |


## Config Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `modify-config` | Formats node's config file | None | `qtools modify-config` |
| `migrate-qtools-config` | Updates config structure | None | `qtools migrate-qtools-config` |
| `config-carousel` | Switches peer configurations | `--frames`: Frames before switch<br>`--daemon`: Run continuously | `qtools config-carousel` |

## Diagnostic Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `status-report` | Generates node status report | `--json`: Output in JSON format | `qtools status-report` |
| `check-node-files` | Verifies node file integrity | None | `qtools check-node-files` |
| `ports-listening` | Checks listening ports | None | `qtools ports-listening` |

## Installation Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `install-cron` | Sets up automated tasks | None | `qtools install-cron` |
| `install-dev-dependencies` | Installs development tools | None | `qtools install-dev-dependencies` |
| `add-auto-complete` | Adds command auto-completion | None | `qtools add-auto-complete` |

## Shortcut Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `consolidate-rewards` | Consolidates node rewards to a configured address | `--dry-run`: Test mode<br>`--transfer-to`: Target address<br>`--skip-sig-check`: Skip signature verification | `qtools consolidate-rewards` |
| `update-hostname` | Updates server hostname | `<hostname>`: New hostname | `qtools update-hostname quil-node-1` |
| `toggle-auto-update-qtools` | Toggles auto-updates for qtools | `--on`: Enable<br>`--off`: Disable | `qtools toggle-auto-update-qtools --on` |
| `toggle-auto-update-node` | Toggles auto-updates for ceremony node | `--on`: Enable<br>`--off`: Disable | `qtools toggle-auto-update-node --on` |

## QClient Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `transfer` | Transfers tokens to another address | `--to`: Recipient address<br>`--token|-t|-c`: Token ID<br>`--skip-sig-check`: Skip signature check<br>`--dry-run`: Test mode<br>`--public-rpc|-p`: Use public RPC<br>`--delay`: Delay in seconds<br>`--no-confirm`: Skip confirmation<br>`--config`: Config directory path | `qtools transfer --to 0x123... --token abc` |

| `coins` | Lists available coins and balances | `-p|--public-rpc`: Use public RPC<br>`-c|--config <config-dir>`: Config directory path | `qtools coins` |
| `split` | Splits tokens | `--token`: Token ID<br>`--amount`: Split amount<br>`--skip-sig-check`: Skip signature check | `qtools split --token <id> --amount <value>` |

## Backup Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `backup-peer` | Backs up peer config files (keys.yml and config.yml) to remote location | `--confirm`: Prompt for confirmation<br>`--peer-id <string>`: Peer ID for backup<br>`--force`: Bypass backup enabled check<br>`--local <path>`: Backup to local directory | `qtools backup-peer --confirm` |
| `backup-store` | Backs up store directory to remote location | `--restart`: Restart node after backup<br>`--config <path>`: Custom config directory<br>`--peer-id <string>`: Peer ID for backup | `qtools backup-store --restart` |
| `make-local-backup` | Creates a local backup of node's .config directory | None | `qtools make-local-backup` |
| `restore-backup` | Restores a complete backup from remote location | `--peer-id <string>`: Peer ID to restore<br>`--force`: Bypass backup enabled check<br>`--no-store`: Skip store restore<br>`--stats`: Include statistics<br>`--confirm`: Prompt for confirmation | `qtools restore-backup --peer-id Qm...` |
| `restore-local-backup` | Restores a local backup of node's .config directory | `--overwrite`: Skip prompt and overwrite existing backup | `qtools restore-local-backup` |
| `restore-peer` | Restores peer config files from remote location | `--confirm`: Prompt for confirmation<br>`--peer-id <string>`: Peer ID to restore<br>`--force`: Bypass backup enabled check<br>`--local <path>`: Restore from local directory | `qtools restore-peer --confirm` |
| `restore-store` | Restores store from remote backup | `--restart`: Restart node after restore<br>`--config <path>`: Custom config directory<br>`--peer-id <string>`: Peer ID to restore | `qtools restore-store --peer-id Qm...` |
| `upload-dev-build` | Uploads a development build to remote storage | `--file <path>`: Path to build file<br>`--version <string>`: Version name for upload | `qtools upload-dev-build --file ./build --version v1.0.0` |

## Configuration Commands

| Command | Description | Parameters | Example |
|---------|-------------|------------|---------|
| `add-direct-peer` | Adds a direct peer to node's config | `<peer_address>`: Full peer address with ID | `qtools add-direct-peer /ip4/1.2.3.4/tcp/40000/p2p/12D3KooWxxxxxx` |
| `clear-data-workers` | Removes all data worker addresses | None | `qtools clear-data-workers` |
| `edit-quil-config` | Opens node's config file in editor | None | `qtools edit-quil-config` |
| `get-core-index-ma` | Gets multiaddress for specific core index | `<int>`: Core index number | `qtools get-core-index-ma 0` |
| `max-frame` | Sets maximum frame number for node | `<frame_number>`: Max frame number or 'default' | `qtools max-frame 1000` |
| `set-dynamic-target` | Sets target number for dynamic proofs | `<int>`: Target number of proofs | `qtools set-dynamic-target 5` |
| `set-listen-addr-port` | Sets the listening port for node | `<port>`: Port number<br>`--proto <udp/tcp>`: Protocol type | `qtools set-listen-addr-port 8336 --proto tcp` |
| `set-ping-timeout` | Sets P2P ping timeout value | `<int>`: Timeout in seconds<br>`default`: Reset to default | `qtools set-ping-timeout 30` |
| `set-sync-timeout` | Sets node sync timeout value | `<int>`: Timeout in seconds<br>`default`: Reset to default | `qtools set-sync-timeout 60` |
| `setup-firewall` | Configures UFW firewall rules | None | `qtools setup-firewall` |
| `toggle-dynamic-proofs` | Toggles dynamic proof creation | `--on`: Enable<br>`--off`: Disable | `qtools toggle-dynamic-proofs --on` |
| `update-bandwidth` | Updates node bandwidth settings | `--plan <low/high/default>`: Bandwidth plan<br>`--d`: D value<br>`--dLo`: Low D value<br>`--dHi`: High D value<br>`--dOut`: Out D value<br>`--lower-watermark`: Low connection limit<br>`--high-watermark`: High connection limit | `qtools update-bandwidth --plan high` |
| `update-direct-peers` | Updates direct peer list from remote source | `--dry-run`: Test without changes<br>`--wait`: Wait for next proof | `qtools update-direct-peers` |

These commands help configure various aspects of your node's operation, from networking parameters to performance settings. The firewall setup ensures proper port access while maintaining security. 