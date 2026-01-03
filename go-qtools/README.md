# Qtools Go Rewrite

This is the Go rewrite of qtools with TUI support, following the implementation plan in `.cursor/plans/go_tools_rewrite_with_tui.plan.md`.

## Status

### ✅ Completed

- **Phase 1: Foundation & Config Management**
  - ✅ Go module initialization
  - ✅ Directory structure
  - ✅ Config system with auto-migration (`internal/config/`)
    - `paths.go` - Path management
    - `config.go` - Config structs
    - `loader.go` - Config loading/saving
    - `migrations.go` - Migration system
    - `generator.go` - Default config generation

- **Phase 2: Node Setup**
  - ✅ Node config types (`internal/node/config_types.go`)
  - ✅ Node config manager (`internal/node/config.go`)
  - ✅ Config operations (`internal/node/config_operations.go`)
  - ✅ Mode detection (`internal/node/mode.go`)
  - ✅ Node setup (`internal/node/setup.go`)
  - ✅ Node commands (`internal/node/commands.go`)
  - ✅ Installation scaffolding (`internal/node/install.go`)

- **Phase 3: Service Management**
  - ✅ Service options (`internal/service/options.go`)
  - ✅ Service manager (`internal/service/manager.go`)
  - ✅ Platform detection (`internal/service/platform.go`)
  - ✅ Systemd integration (`internal/service/systemd.go`)
  - ✅ Launchd integration (`internal/service/launchd.go`)
  - ✅ Plist generation (`internal/service/plist.go`)
  - ✅ Worker management (`internal/service/workers.go`)

- **Phase 4: CLI Interface**
  - ✅ Basic CLI structure with Cobra (`cmd/qtools/main.go`)
  - ✅ Node commands (setup, mode, install)
  - ✅ Service commands (start, stop, restart, status)
  - ✅ TUI command integration

- **Phase 5: TUI Implementation**
  - ✅ Main TUI app (`internal/tui/app.go`)
  - ✅ Node setup view (`internal/tui/views/node_setup.go`)
  - ✅ Service control view (`internal/tui/views/service_control.go`)
  - ✅ Status view (`internal/tui/views/status.go`)
  - ✅ Log view (`internal/tui/views/log_view.go`)
  - ✅ Components (menu, core input)
  - ✅ Log filtering (`internal/log/filters.go`, `internal/log/viewer.go`)

- **Phase 6: Desktop Integration (Stubs)**
  - ✅ Messaging stub (`internal/messaging/stub.go`)
  - ✅ Node client (`internal/client/node_client.go`)
    - Binary command support (works when node is stopped)
    - gRPC support stub (for when node is running)
    - Hybrid approach (tries gRPC first, falls back to binary)

### 🚧 Future Enhancements

- **Phase 2: Node Setup**
  - ⏳ Complete `install.go` implementation (download binaries, create users/groups, etc.)

- **Phase 4: CLI Interface**
  - ⏳ Implement actual command handlers (currently stubs)
  - ⏳ Log commands
  - ⏳ Config commands

- **Phase 6: Desktop Integration**
  - ⏳ Implement actual Quilibrium Messaging integration
  - ⏳ Full gRPC client implementation
  - ⏳ Desktop app SDK/examples

## Building

```bash
cd go-tools
go build -o qtools ./cmd/qtools
```

## Running

```bash
# CLI
./qtools --help
./qtools node setup --help
./qtools service start --help

# TUI
./qtools tui
```

## Shell Completion

Qtools supports shell completion for bash, zsh, fish, and PowerShell.

### Installation

**Automatic installation (recommended):**

Simply run `qtools completion` without arguments. Qtools will:
- Auto-detect your shell
- Prompt you if detection fails
- Install completions permanently

```bash
# Auto-detect and install
qtools completion

# Or specify shell explicitly
qtools completion bash
qtools completion zsh
qtools completion fish
```

**Generate completion script (for manual installation):**

If you prefer to install manually, use the `--generate` flag:

```bash
# Generate to stdout
qtools completion bash --generate > ~/.local/share/bash-completion/completions/qtools

# Or use the installation script
./scripts/install-completion.sh bash
```

**PowerShell:**

PowerShell completion requires manual setup:
```powershell
qtools completion powershell --generate | Out-String | Invoke-Expression
# Or add to profile:
qtools completion powershell --generate | Out-String | Add-Content $PROFILE
```

After installation, restart your shell or source the completion file as instructed.

## Architecture

The project follows the structure defined in the plan:

```
go-tools/
├── cmd/qtools/          # CLI entry point
├── internal/
│   ├── config/         # Config management
│   ├── node/           # Node setup and management
│   ├── service/        # Service management
│   ├── log/            # Log viewing and filtering
│   ├── tui/            # TUI implementation
│   ├── messaging/      # Desktop integration stub
│   └── client/         # Node client library
```

## Key Features

- **Dynamic Config System**: Auto-migrating config with programmatic defaults
- **Manual Mode Default**: Opinionated default for better reliability (each worker as separate service)
- **Cross-platform**: Linux (systemd) and macOS (launchd) support
- **TUI Support**: Full Bubble Tea-based TUI interface
- **Service Management**: Complete service control for master and workers
- **Log Viewing**: Real-time log tailing with filtering support

## Command Structure

Commands are organized into separate branches:

- **`qtools node`** - All node-related commands:
  - `node setup` - Setup node
  - `node install` - Complete installation
  - `node download` - Download node binary
  - `node update` - Update node binary
  - `node config` - Node configuration management
  - `node info` - Get node information
  - `node peer-id` - Get peer ID
  - `node balance` - Get balance
  - `node seniority` - Get seniority
  - `node worker-count` - Get worker count

- **`qtools qclient`** - All qclient-related commands:
  - `qclient download` - Download qclient binary
  - (More qclient commands coming: transfer, merge, split, coins, account, etc.)

- **Other top-level commands**:
  - `qtools service` - Service management (start, stop, restart, status)
  - `qtools config` - Qtools configuration management
  - `qtools toggle` - Toggle settings (auto-updates, etc.)
  - `qtools util` - Utility commands (public-ip, etc.)
  - `qtools logs` - Log viewing and management
  - `qtools backup` - Backup and restore
  - `qtools diagnostics` - Diagnostic commands
  - `qtools update` - Update commands
  - `qtools completion` - Shell completion
  - `qtools tui` - Launch TUI mode

## Status

✅ **All core phases complete!** The foundation is fully implemented:
- Config system with auto-migration
- Node setup and management
- Service management (systemd/launchd)
- CLI interface
- TUI interface
- Desktop integration stubs

## Next Steps

1. Wire up CLI command handlers - Connect service management to CLI commands
2. Complete install.go implementation - Download binaries, user/group creation
3. Implement actual Quilibrium Messaging integration - Replace stubs with real implementation
4. Add comprehensive testing - Unit tests, integration tests
5. Add documentation - User guide, API documentation
