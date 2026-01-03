# Bash Script Migration Candidates

This document lists bash scripts that could be migrated to the Go implementation, organized by their new nested command structure.

## Command Structure Mapping

### Node Commands (`qtools node ...`)
- ✅ `node setup` - **Already implemented** (from `scripts/config/manual-mode.sh`)
- ✅ `node install` - **Partially implemented** (from `scripts/install/complete-install.sh`)
- ⚠️ `node update` - Update node binary (from `scripts/update/update-node.sh`)
- ✅ `node config get <path> [--config qtools|quil] [--default <value>]` - **Implemented** Get config value (from `scripts/config/config.sh`)
- ✅ `node config set <path> <value> [--config qtools|quil] [--quiet]` - **Implemented** Set config value (from `scripts/config/config.sh`)
- ⚠️ `node config add-direct-peer <peer-id> <multiaddr>` - **Already implemented** (from `scripts/config/add-direct-peer.sh`)
- ⚠️ `node config remove-direct-peer <peer-id>` - **Already implemented** (from `scripts/config/clear-direct-peers.sh`)
- ⚠️ `node config get-direct-peers` - Get direct peers list (from `scripts/config/get-direct-peers.sh`)
- ⚠️ `node config update-direct-peers` - Update direct peers (from `scripts/config/update-direct-peers.sh`)
- ⚠️ `node config set-max-frame <value>` - Set max frame (from `scripts/config/max-frame.sh`)
- ⚠️ `node config set-sync-timeout <value>` - Set sync timeout (from `scripts/config/set-sync-timeout.sh`)
- ⚠️ `node config set-reward-peer-id <peer-id>` - Set reward peer ID (from `scripts/config/set-reward-peer-id.sh`)
- ⚠️ `node config set-announce-multiaddrs <multiaddrs...>` - Set announce multiaddrs (from `scripts/config/set-announce-multiaddrs.sh`)
- ⚠️ `node config clear-announce-multiaddrs` - Clear announce multiaddrs (from `scripts/config/clear-announce-multiaddrs.sh`)
- ⚠️ `node config enable-logging [--path] [--max-size] [--max-backups] [--max-age] [--compress]` - **Already implemented** (from `scripts/config/enable-custom-logging.sh`)
- ⚠️ `node config disable-logging` - **Already implemented** (from `scripts/config/enable-custom-logging.sh`)
- ⚠️ `node info` - Get node info (from `scripts/grpc/node-info.sh`, **partially implemented**)
- ⚠️ `node peer-id` - Get peer ID (from `scripts/grpc/peer-id.sh`, **partially implemented**)
- ⚠️ `node balance` - Get balance (from `scripts/grpc/balance.sh`)
- ⚠️ `node seniority` - Get seniority (from `scripts/grpc/seniority.sh`)
- ⚠️ `node worker-count` - Get worker count (from `scripts/grpc/worker-count.sh`)

### Service Commands (`qtools service ...`)
- ✅ `service start` - **Already implemented** (from `scripts/service-commands/start.sh`)
- ✅ `service stop` - **Already implemented** (from `scripts/service-commands/stop.sh`)
- ✅ `service restart` - **Already implemented** (from `scripts/service-commands/restart.sh`)
- ✅ `service status` - **Already implemented** (from `scripts/service-commands/status.sh`)
- ⚠️ `service enable` - Enable service on boot (from `scripts/service-commands/enable.sh`)
- ⚠️ `service disable` - Disable service on boot
- ⚠️ `service update [--testnet] [--debug] [--restart-time] ...` - **Already implemented** (from `scripts/update/update-service.sh`)
- ⚠️ `service pid` - Get process ID (from `scripts/service-commands/get-pid.sh`)
- ⚠️ `service kill-worker <core-index>` - Kill specific worker (from `scripts/service-commands/kill-workers-by-core.sh`)

### Backup Commands (`qtools backup ...`)
- ⚠️ `backup peer [--peer-id] [--local <path>]` - Backup peer config (from `scripts/backup/backup-peer.sh`)
- ⚠️ `backup store [--peer-id]` - Backup store directory (from `scripts/backup/backup-store.sh`)
- ⚠️ `backup local [--path]` - Create local backup (from `scripts/backup/make-local-backup.sh`)
- ⚠️ `backup restore [--peer-id] [--no-store]` - Restore complete backup (from `scripts/backup/restore-backup.sh`)
- ⚠️ `backup restore-peer [--peer-id] [--local <path>]` - Restore peer config (from `scripts/backup/restore-peer.sh`)
- ⚠️ `backup restore-store [--peer-id]` - Restore store (from `scripts/backup/restore-store.sh`)
- ⚠️ `backup restore-local [--overwrite]` - Restore local backup (from `scripts/backup/restore-local-backup.sh`)
- ⚠️ `backup verify [--peer-id]` - Verify backup integrity (from `scripts/backup/verify-backup-integrity.sh`)

### Diagnostics Commands (`qtools diagnostics ...`)
- ⚠️ `diagnostics status-report [--json]` - Generate status report (from `scripts/diagnostics/status-report.sh`)
- ⚠️ `diagnostics check-files` - Check node file integrity (from `scripts/diagnostics/check-node-files.sh`)
- ⚠️ `diagnostics check-ports` - Check listening ports (from `scripts/diagnostics/ports-listening.sh`)
- ⚠️ `diagnostics check-memory` - Check memory usage (from `scripts/diagnostics/memory-usage.sh`)
- ⚠️ `diagnostics check-cpu` - Check CPU load (from `scripts/diagnostics/check-cpu-load.sh`)
- ⚠️ `diagnostics check-disk` - Check disk space (from `scripts/diagnostics/check-disk-space.sh`)
- ⚠️ `diagnostics check-service` - Check service status (from `scripts/diagnostics/check-service-status.sh`)
- ⚠️ `diagnostics check-network` - Check network connectivity (from `scripts/diagnostics/check-network-connectivity.sh`)
- ⚠️ `diagnostics run` - Run all diagnostics (from `scripts/diagnostics/run-diagnostics.sh`)
- ⚠️ `diagnostics proof-info` - Get proof information (from `scripts/diagnostics/proof-info.sh`)
- ⚠️ `diagnostics reward-rate` - Calculate hourly reward rate (from `scripts/diagnostics/hourly-reward-rate.sh`)
- ⚠️ `diagnostics clean-logs` - Clean old log files (from `scripts/diagnostics/clean-logs.sh`)

### Update Commands (`qtools update ...`)
- ✅ `node update [--force] [--skip-clean]` - **Implemented** Update node binary (from `scripts/update/update-node.sh`)
- ⚠️ `update self [--check]` - Check/update qtools itself (from `scripts/update/self-update.sh`)
  - Note: Changed to `update self` to avoid confusion with `node update`
  - `--check` flag to only check for updates without updating
- ⚠️ `update kernel` - Update Linux kernel (from `scripts/update/update-kernel.sh`)
- ✅ `service update [--testnet] [--debug] ...` - **Already implemented** (from `scripts/update/update-service.sh`)
- ⚠️ `update cron` - Update cron tasks (from `scripts/update/update-cron.sh`)
- ⚠️ `update hostname <hostname>` - Update hostname (from `scripts/update/update-hostname.sh`)

### Log Commands (`qtools logs ...`)
- ✅ `logs view [--master|--worker <n>|--qtools]` - **Already implemented** (from `scripts/diagnostics/view-log.sh`)
- ⚠️ `logs filters [--preset <name>] [--save <name>]` - Manage log filters (from log filter system)
- ⚠️ `logs configure [--path] [--max-size] [--max-backups] [--max-age] [--compress]` - **Already implemented** (from `scripts/config/enable-custom-logging.sh`)
- ⚠️ `logs disable-custom` - **Already implemented** (from `scripts/config/enable-custom-logging.sh`)
- ⚠️ `logs clean` - Clean old logs (from `scripts/diagnostics/clean-logs.sh`)

### Config Commands (`qtools config ...`)
- ⚠️ `config get <path>` - Get config value (from `scripts/config/config.sh`)
- ⚠️ `config set <path> <value>` - Set config value (from `scripts/config/config.sh`)
- ⚠️ `config migrate` - Migrate config structure (from `scripts/update/migrate-qtools-config.sh`)
- ⚠️ `config edit` - Edit config file (from `scripts/shortcuts/edit-qtools-config.sh`)

### Install Commands (`qtools install ...`)
- ⚠️ `install complete [--peer-id] [--listen-port] ...` - **Partially implemented** (from `scripts/install/complete-install.sh`)
- ⚠️ `install user` - Create quilibrium user (from `scripts/install/create-quilibrium-user.sh`)
- ⚠️ `install go` - Install Go (from `scripts/install/install-go.sh`)
- ⚠️ `install grpc` - Install grpcurl (from `scripts/install/install-grpc.sh`)
- ⚠️ `install firewall` - Setup firewall (from `scripts/install/setup-firewall.sh`)
- ⚠️ `install cron` - Install cron tasks (from `scripts/install/install-cron.sh`)
- ⚠️ `install autocomplete` - Add shell autocomplete (from `scripts/install/add-auto-complete.sh`)

### Cluster Commands (`qtools cluster ...`) - Lower Priority
- ⚠️ `cluster setup` - Setup cluster (from `scripts/cluster/cluster-setup.sh`)
- ⚠️ `cluster start` - Start cluster (from `scripts/cluster/cluster-start.sh`)
- ⚠️ `cluster stop` - Stop cluster (from `scripts/cluster/cluster-stop.sh`)
- ⚠️ `cluster update` - Update cluster (from `scripts/cluster/cluster-update.sh`)
- ⚠️ `cluster add-server <server>` - Add server (from `scripts/cluster/cluster-add-server.sh`)
- ⚠️ `cluster remove-server <server>` - Remove server (from `scripts/cluster/cluster-remove-server.sh`)
- ⚠️ `cluster status` - Get cluster status
- ⚠️ `cluster remote-command <command>` - Execute command on remote servers (from `scripts/cluster/cluster-remote-command.sh`)

### QClient Commands (`qtools qclient ...`) - Lower Priority
- ⚠️ `qclient transfer --to <addr> --token <id>` - Transfer tokens (from `scripts/qclient/transfer.sh`)
- ⚠️ `qclient merge --token <id>` - Merge tokens (from `scripts/qclient/merge.sh`)
- ⚠️ `qclient split --token <id> --amount <value>` - Split tokens (from `scripts/qclient/split.sh`)
- ⚠️ `qclient account` - Account operations (from `scripts/qclient/account.sh`)
- ⚠️ `qclient consolidate-rewards [--dry-run]` - Consolidate rewards (from `scripts/shortcuts/consolidate-rewards.sh`)

## Migration Priority

### Phase 1: Core Commands (High Priority)
1. **Node Commands**
   - ✅ `node update` - **Implemented** Update node binary
   - ✅ `node config get/set` - **Implemented** Generic config operations
   - ⚠️ `node info/balance/seniority` - Node information queries (partially implemented)

2. **Service Commands**
   - `service enable/disable` - Service lifecycle
   - `service pid` - Process information

3. **Backup Commands**
   - `backup peer/store` - Basic backup functionality
   - `backup restore` - Restore functionality

4. **Diagnostics Commands**
   - `diagnostics status-report` - Comprehensive status
   - `diagnostics check-files/ports/memory` - Basic checks

### Phase 2: Enhanced Features (Medium Priority)
1. **Update Commands**
   - `update node` - Node updates
   - `update self` - Self-updates

2. **Install Commands**
   - Complete `install complete` implementation
   - `install user/go/grpc/firewall/cron`

3. **Log Commands**
   - `logs filters` - Filter management
   - `logs clean` - Log cleanup

### Phase 3: Advanced Features (Lower Priority)
1. **Cluster Commands** - Full cluster management
2. **QClient Commands** - Token operations
3. **Advanced Diagnostics** - Complex diagnostic tools

## Notes

- Commands marked with ✅ are already implemented
- Commands marked with ⚠️ need implementation
- Nested structure provides better organization and discoverability
- Each command group can be implemented incrementally
