# Go Tools Rewrite with TUI - Implementation Plan

## Project Structure

Create `/go-tools` directory with the following structure:

```
go-tools/
├── cmd/
│   └── qtools/
│       └── main.go                 # Main entry point (CLI/TUI mode)
├── internal/
│   ├── config/
│   │   ├── config.go              # Config struct and migration from YAML
│   │   └── loader.go              # Config loading/saving
│   ├── node/
│   │   ├── setup.go               # Node setup logic (manual/automatic)
│   │   ├── install.go             # Installation functions
│   │   ├── mode.go                # Mode detection (manual/automatic/clustering)
│   │   ├── config.go              # Node config manager
│   │   ├── config_operations.go   # Node config operations
│   │   ├── config_types.go        # Node config types
│   │   └── commands.go             # Node binary commands
│   ├── log/
│   │   ├── viewer.go              # Log file tailing/viewing
│   │   ├── filters.go             # Log filtering and presets
│   │   └── logging.go             # Custom logging configuration
│   ├── service/
│   │   ├── manager.go             # Service management (start/stop/restart/status)
│   │   ├── platform.go            # Platform detection and abstraction
│   │   ├── systemd.go             # Systemd integration (Linux)
│   │   ├── launchd.go             # Launchd integration (macOS)
│   │   ├── plist.go                # macOS plist generation
│   │   └── workers.go             # Worker management
│   ├── tui/
│   │   ├── app.go                 # Main TUI application
│   │   ├── views/
│   │   │   ├── node_setup.go      # Node setup TUI view
│   │   │   ├── service_control.go  # Service control TUI view
│   │   │   └── status.go          # Status display TUI view
│   │   └── components/
│   │       ├── menu.go            # Navigation menu
│   │       └── status_bar.go      # Status bar component
│   ├── messaging/
│   │   └── stub.go                # Stub for future Quilibrium Messaging integration
│   └── client/
│       ├── node_client.go         # Client for connecting to Quilibrium nodes
│       └── auth.go                 # Authentication for node connections
├── go.mod
├── go.sum
└── README.md
```

## Architecture Overview

### Desktop App Integration Architecture

```
Desktop App (local)
    │
    └──> IPC Connection ──> qtools Process (local)
            │
            ├──> Node 1 (gRPC/REST on port 8337/8338)
            │
            ├──> Node 2 (gRPC/REST on port 8337/8338)
            │
            └──> Node N (gRPC/REST on port 8337/8338)
```

**Key Points:**

- Focus on **CLI and TUI** functionality for now
- Desktop app integration will use **Quilibrium Messaging** protocol (stubbed for future)
- qtools manages connections to Quilibrium nodes
- Each node connection is **authenticated** using public/private key encryption via Quilibrium Messaging layer
- qtools provides:
  - Node setup (manual/automatic)
  - Service management (start/stop/restart/status)
  - Node configuration management
  - Direct node operations via CLI/TUI

## Phase 1: Foundation & Config Management

### 1.1 Initialize Go Module

- Create `go.mod` with Go 1.21+
- Add dependencies:
  - `gopkg.in/yaml.v3` - YAML parsing
  - `github.com/charmbracelet/bubbletea` - TUI framework
  - `github.com/charmbracelet/lipgloss` - Styling
  - `github.com/spf13/cobra` - CLI framework
  - `google.golang.org/grpc` - gRPC client/server
  - `github.com/gorilla/mux` or `github.com/gin-gonic/gin` - HTTP router
  - `golang.org/x/crypto` - Authentication/crypto
- Set module path: `github.com/tjsturos/qtools/go-tools` (or appropriate)

### 1.2 Dynamic Config System with Auto-Migration

- Create `internal/config/paths.go`:
  - Default path constants:
    - `DefaultQtoolsPath = "/home/quilibrium/qtools"`
    - `DefaultNodePath = "/home/quilibrium/node"`
    - `DefaultClientPath = "/home/quilibrium/client"`
    - `DefaultConfigPath = "/home/quilibrium/qtools/config.yml"`
    - `DefaultNodeConfigPath = "/home/quilibrium/node/.config/config.yml"`
  - `GetQtoolsPath() string` - Get qtools installation path
  - `GetNodePath() string` - Get node installation path
  - `GetClientPath() string` - Get client installation path

- Create `internal/config/config.go`:
  - Define Go structs for config structure (not tied to static sample file)
  - Key structs:
    - `Config` (root) - Uses `map[string]interface{}` for flexibility
    - `ServiceConfig` (service settings, clustering, manual mode)
    - `ScheduledTasksConfig` (updates, backups, etc.)
    - `SettingsConfig` (listenAddr, snapshots, etc.)
    - `NodeRegistry` - Registry of nodes for desktop app (new)
  - Config structs use YAML tags for serialization
  - Support for both structured access and dynamic key access

- Create `internal/config/loader.go`:
  - `LoadConfig(path string) (*Config, error)` - Load and auto-migrate config
  - `SaveConfig(config *Config, path string) error` - Save config in new format
  - `ReadConfigRaw(path string) (map[string]interface{}, error)` - Read raw YAML
  - `MigrateConfig(oldConfig map[string]interface{}) (*Config, error)` - Apply migrations
  - `ValidateConfig(config *Config) error` - Validate config structure
  - Handle file permissions:
    - Config files owned by `quilibrium:qtools`
    - Use `sg qtools` or run as quilibrium:qtools when possible
    - Request sudo only when necessary (if user not in qtools group)

- Create `internal/config/migrations.go`:
  - Migration registry: `RegisterMigration(fromPath, toPath string, fn MigrationFunc)`
  - `MigrationFunc` type: `func(oldValue interface{}) (interface{}, error)`
  - Individual migration functions for each parameter change:
    - `MigrateCrontabToScheduledTasks(oldConfig map[string]interface{}) `- `.crontab.*` → `.scheduled_tasks.*`
    - `MigrateServiceSettings(oldConfig map[string]interface{})` - Service setting migrations
    - `MigrateListenAddr(oldConfig map[string]interface{})` - Listen address format changes
    - Add new migrations as config structure evolves
  - `ApplyMigrations(config map[string]interface{}) (map[string]interface{}, error)` - Apply all registered migrations
  - Migration functions are idempotent (safe to run multiple times)

- Create `internal/config/generator.go`:
  - `GenerateDefaultConfig() *Config` - Generate default config programmatically
  - `MergeDefaults(config *Config) *Config` - Merge user config with defaults
  - `GetConfigValue(path string) (interface{}, error)` - Dynamic path access (e.g., `.scheduled_tasks.status.enabled`)
  - `SetConfigValue(path string, value interface{}) error` - Dynamic path setting
  - Path format: dot-separated keys (e.g., `scheduled_tasks.status.enabled`)
  - Support for nested structures and arrays
  - Default config paths:
    - Qtools config: `/home/quilibrium/qtools/config.yml`
    - Node config: `/home/quilibrium/node/.config/config.yml`
  - **Default config values:**
    - `manual.enabled = true` (opinionated default - manual mode for better reliability)
      - Each worker as separate service = better isolation, monitoring, reliability
      - User experience remains automatic - tooling handles all complexity
    - `manual.worker_count = 0` (auto-calculated based on CPU cores)
    - `manual.local_only = true`

- Migration Strategy:

  1. Load raw YAML into `map[string]interface{}`
  2. Detect config version/format (if version field exists)
  3. Apply all registered migrations in order
  4. Convert migrated map to structured `Config` type
  5. Merge with defaults for missing values
  6. Validate final config
  7. Save in new format (with version marker)
  8. Backup old config file before migration

- Example Migration Function:
  ```go
  func MigrateCrontabToScheduledTasks(old map[string]interface{}) map[string]interface{} {
      // Check if old format exists
      if crontab, ok := old["crontab"].(map[string]interface{}); ok {
          // Create scheduled_tasks if doesn't exist
          if _, exists := old["scheduled_tasks"]; !exists {
              old["scheduled_tasks"] = make(map[string]interface{})
          }
          st := old["scheduled_tasks"].(map[string]interface{})
          
          // Migrate each crontab section
          if status, ok := crontab["status"].(map[string]interface{}); ok {
              if st["status"] == nil {
                  st["status"] = make(map[string]interface{})
              }
              stStatus := st["status"].(map[string]interface{})
              if enabled, ok := status["enabled"]; ok {
                  stStatus["enabled"] = enabled
              }
          }
          
          // Remove old crontab section after migration
          delete(old, "crontab")
      }
      return old
  }
  ```


## Phase 2: Node Setup Implementation

### 2.1 Mode Detection

- Create `internal/node/mode.go`:
  - `DetectMode(config *config.Config) Mode` - Returns Manual/Automatic/Clustering
  - `IsManualMode(config *config.Config) bool` - Defaults to `true` if not explicitly set
  - `IsAutomaticMode(config *config.Config) bool` - Returns true if manual mode is disabled
  - `IsClusteringEnabled(config *config.Config) bool`
  - `GetWorkerCount(config *config.Config) int` - Calculate worker count based on mode
  - **Default mode: Manual** (opinionated default for better reliability)
    - **Rationale:** Manual mode runs each worker as a separate service, providing better reliability and isolation
    - **User experience:** Still feels automatic - tooling handles all complexity transparently
    - Users get benefits of separate services without managing them manually
  - `ToggleMode(config *config.Config) error` - Toggle between manual and automatic mode

### 2.2 Node Setup Logic

- Create `internal/node/setup.go`:
  - `SetupNode(opts SetupOptions) error` - Main setup function
  - **Defaults to manual mode** (opinionated default for reliability)
    - Each worker runs as separate service (better isolation, reliability, monitoring)
    - Tooling automatically manages all workers - user doesn't need to think about it
    - Better than automatic mode where master spawns workers (less reliable, harder to monitor)
  - `SetupManualMode(config *config.Config, workerCount int) error` - Setup manual mode (default)
    - Creates separate service files for each worker
    - Automatically calculates worker count if not provided
    - Configures ports automatically
    - User experience: Still automatic, just more reliable
  - `SetupAutomaticMode(config *config.Config) error` - Setup automatic mode (optional, less reliable)
  - `ToggleMode(config *config.Config) error` - Toggle between manual/automatic modes
  - Port calculation logic (base ports, worker ports)
  - Uses `NodeConfigManager` for node config file generation/modification
  - Reference: `scripts/config/manual-mode.sh` for manual mode setup
  - During installation, manual mode is enabled by default with calculated worker count

### 2.3 Installation Functions

- Create `internal/node/install.go`:
  - `CompleteInstall(opts InstallOptions) error` - Equivalent to `complete-install.sh`
  - Functions for:
    - **Creating qtools group** (if doesn't exist)
    - **Creating quilibrium user** (Linux only):
      - System user with no login shell
      - Added to qtools group
      - Home directory: `/home/quilibrium`
    - **Adding installing user to qtools group** (if non-root)
    - **Setting up directory structure**:
      - Qtools: `/home/quilibrium/qtools` (owned by quilibrium:qtools)
      - Node: `/home/quilibrium/node` (owned by quilibrium:qtools)
      - Client: `/home/quilibrium/client` (owned by quilibrium:qtools)
      - All files owned by `quilibrium:qtools` with group read/write permissions
    - Downloading node binary to `/home/quilibrium/node/`
    - Downloading qclient binary to `/home/quilibrium/client/`
    - **Creating symlinks**:
      - `/usr/local/bin/node` → node binary
      - `/usr/local/bin/qtools` → qtools binary
    - Setting up firewall (platform-specific, requires sudo)
    - Installing dependencies (Go, grpcurl, may require sudo)
    - Generating default config
    - **Enabling manual mode by default** (opinionated default for reliability)
      - Calculate worker count based on CPU cores
      - Configure node config for manual mode
      - Create separate service files for each worker
      - **User experience:** Still automatic - tooling manages all workers transparently
      - **Benefit:** Better reliability through service isolation
    - **Enabling custom logging by default** (with file splitting: master.log, worker-N.log)
      - Default settings: path `.logs`, maxSize 50MB, maxBackups 5, maxAge 10 days, compress true
      - Configured in node config file during installation
    - Creating and enabling service (systemd on Linux, launchd on macOS, requires sudo)
    - Note: Authentication will use public/private key encryption via Quilibrium Messaging layer (to be implemented)
  - **Permission handling:**
    - All qtools/node files owned by `quilibrium:qtools`
    - Group permissions: `g+rwx` (read, write, execute for qtools group)
    - Installing user added to qtools group can run commands without sudo
    - Sudo only requested for privileged operations (user/group creation, systemd, firewall)

### 2.4 Node Config Manager

- Create `internal/node/config.go`:
  - `NodeConfigManager` struct for managing Quilibrium node's config file
  - Config file path: `/home/quilibrium/node/.config/config.yml` (separate from qtools config)
  - Default paths:
    - Node path: `/home/quilibrium/node`
    - Client path: `/home/quilibrium/client`
    - Qtools path: `/home/quilibrium/qtools`
  - `NewNodeConfigManager(configPath string) (*NodeConfigManager, error)`
  - `Load() (*NodeConfig, error)` - Load node config file
  - `Save(config *NodeConfig) error` - Save node config file
  - `GetValue(path string) (interface{}, error)` - Get config value by dot path
  - `SetValue(path string, value interface{}) error` - Set config value by dot path
  - `DeleteValue(path string) error` - Delete config value
  - Handle file permissions (owned by quilibrium:qtools)
  - Run operations as quilibrium:qtools when possible (using `sg qtools` or similar)
  - Use sudo only when necessary (file creation/modification if not in qtools group)

- Create `internal/node/config_operations.go`:
  - High-level operations for common node config tasks:
    - `SetP2PListenMultiaddr(configPath, multiaddr string) error` - Set `.p2p.listenMultiaddr`
    - `SetGRPCMultiaddr(configPath, multiaddr string) error` - Set `.grpc.listenMultiaddr`
    - `SetRESTMultiaddr(configPath, multiaddr string) error` - Set `.rest.listenMultiaddr`
    - `SetStreamListenMultiaddr(configPath, multiaddr string) error` - Set `.p2p.streamListenMultiaddr`
    - `SetDataWorkerMultiaddrs(configPath string, multiaddrs []string) error` - Set `.engine.dataWorkerMultiaddrs`
    - `SetDataWorkerP2PMultiaddrs(configPath string, multiaddrs []string) error` - Set `.engine.dataWorkerP2PMultiaddrs`
    - `SetDataWorkerStreamMultiaddrs(configPath string, multiaddrs []string) error` - Set `.engine.dataWorkerStreamMultiaddrs`
    - `ClearDataWorkers(configPath string) error` - Clear all data worker arrays
    - `AddDirectPeer(configPath, peerID, multiaddr string) error` - Add to `.p2p.directPeers`
    - `RemoveDirectPeer(configPath, peerID string) error` - Remove from `.p2p.directPeers`
    - `SetEngineSetting(configPath, key string, value interface{}) error` - Set engine settings
    - `GetEngineSetting(configPath, key string) (interface{}, error)` - Get engine settings
    - `EnableCustomLogging(configPath string, opts LoggingOptions) error` - Enable/configure custom logging
    - `DisableCustomLogging(configPath string) error` - Disable custom logging (revert to stdout)
    - `GetLoggingConfig(configPath string) (*LoggingConfig, error)` - Get logging configuration
    - Called automatically during `CompleteInstall()` with default settings
  - Reference implementations:
    - `scripts/config/set-p2p-listen-multiaddr.sh`
    - `scripts/config/set-grpc-multiaddr.sh`
    - `scripts/config/set-rest-multiaddr.sh`
    - `scripts/config/clear-data-workers.sh`
    - `scripts/config/add-direct-peer.sh`
    - `scripts/config/set-dynamic-target.sh`
    - `scripts/config/max-frame.sh`
    - `scripts/config/set-sync-timeout.sh`

- Create `internal/node/config_types.go`:
  - `NodeConfig` struct matching Quilibrium node config structure
  - Key sections:
    - `P2P` - P2P network settings (listenMultiaddr, streamListenMultiaddr, directPeers, etc.)
    - `GRPC` - gRPC settings (listenMultiaddr)
    - `REST` - REST API settings (listenMultiaddr)
    - `Engine` - Engine settings (dataWorkerMultiaddrs, maxFrame, syncTimeout, etc.)
    - `Logger` - Logger settings (path, maxSize, maxBackups, maxAge, compress)
    - `Settings` - Other node settings
  - `LoggingConfig` struct:
    - `Path` - Log directory path (default: `.logs`)
    - `MaxSize` - Maximum log file size in MB (default: 50)
    - `MaxBackups` - Maximum number of backup files (default: 5)
    - `MaxAge` - Maximum age in days (default: 10)
    - `Compress` - Enable compression (default: true)
  - YAML tags for serialization
  - Support for both structured access and dynamic path access

- Config File Handling:
  - Handle file ownership (may be owned by `quilibrium` user)
  - Use `sg quilibrium` or `sudo` when needed (similar to bash scripts)
  - Backup config before modifications
  - Validate YAML structure before saving
  - Preserve comments and formatting where possible

### 2.5 Node Binary Commands

- Create `internal/node/commands.go`:
  - `ExecuteNodeCommand(args []string, configPath string) ([]byte, error)` - Execute node binary
  - `GetNodeInfo(configPath string) (*NodeInfo, error)` - Run `node --node-info --config <path>`
  - `GetPeerID(configPath string) (string, error)` - Run `node --peer-id --config <path>`
  - Parse text output similar to bash scripts
  - Reference: `utils/index.sh` `run_node_command()` function
  - Handle signature-check, testnet, debug flags from config
  - Support for `--config` flag to specify config file path
  - Uses `NodeConfigManager` to get config path

## Phase 3: Service Commands

### 3.1 Service Manager

- Create `internal/service/options.go`:
  - `ServiceOptions` struct for service configuration:
    - `Testnet bool` - Enable testnet mode
    - `Debug bool` - Enable debug mode
    - `SkipSignatureCheck bool` - Skip signature verification
    - `IPFSDebug bool` - Enable IPFS debugging
    - `RestartTime string` - Master service restart delay (e.g., "60s")
    - `WorkerRestartTime string` - Worker service restart delay (e.g., "5s")
    - `GOGC string` - GOGC environment variable for workers (optional)
    - `GOMEMLIMIT string` - GOMEMLIMIT environment variable for workers (optional)
    - `EnableCPUScheduling bool` - Enable CPU scheduling for workers (optional, default false)
    - `DataWorkerPriority int` - CPU scheduling priority (default 90, only used if EnableCPUScheduling is true)
    - `EnableService bool` - Enable service after update
    - `RestartService bool` - Restart service after update
    - `MasterOnly bool` - Update master only (don't update workers)
  - `ParseServiceOptions(args []string) (*ServiceOptions, error)` - Parse command-line arguments
  - `LoadServiceOptionsFromConfig(config *config.Config) (*ServiceOptions, error)` - Load from config file
  - `ApplyServiceOptions(opts *ServiceOptions, config *config.Config) error` - Save options to config
  - Reference: `scripts/update/update-service.sh` (lines 52-161) for parameter parsing

- Create `internal/service/manager.go`:
  - `StartService(opts StartOptions) error` - Uses platform backend
    - **In manual mode (default):** Automatically starts all worker services + master
    - User experience: Single command starts everything, tooling handles complexity
    - Better reliability: Each worker isolated as separate service
    - `StartMasterOnly() error` - Start master service only
    - `StartWorkers(coreNumbers []int) error` - Start specific workers by core number
    - Support for `--master` flag to start master only
    - Support for `--core-index N` flag to start specific worker
  - `StopService(opts StopOptions) error` - Uses platform backend
    - **In manual mode:** Automatically stops all worker services + master
    - `StopMasterOnly() error` - Stop master service only
    - `StopWorkers(coreNumbers []int) error` - Stop specific workers by core number
    - Support for `--master` flag to stop master only
    - Support for `--core-index N` flag to stop specific worker
  - `RestartService(opts RestartOptions) error` - Uses platform backend
    - **In manual mode:** Automatically restarts all worker services + master
    - `RestartMasterOnly() error` - Restart master service only
    - `RestartWorkers(coreNumbers []int) error` - Restart specific workers by core number
    - Support for `--master` flag to restart master only
    - Support for `--core-index N` flag to restart specific worker
  - `GetStatus(opts StatusOptions) (*Status, error)` - Uses platform backend
    - Shows status of master + all workers (even in manual mode)
    - User sees unified status, tooling handles checking individual services
    - Can get status of individual workers with `--core-index N`
  - `CreateServiceFile(name string, opts *ServiceOptions) error` - Platform-aware
  - `UpdateServiceFile(name string, opts *ServiceOptions) error` - Update service file with new parameters
  - Uses `ServiceOptions` struct (defined in `options.go`) for all parameters
  - Handle different modes (automatic/manual/clustering)
  - **Manual mode (default):** Automatically manages all worker services transparently
  - Support for `--master`, `--core-index` flags (for advanced users and TUI)
  - Automatically selects systemd (Linux) or launchd (macOS) backend
  - **Service runs as quilibrium user with qtools group**
  - Service files specify `User=quilibrium` and `Group=qtools`
  - **User experience:** Commands work the same regardless of mode - tooling abstracts complexity
  - **Granular control:** Available when needed (restart master only, restart specific workers)

### 3.2 Platform Detection & Abstraction

- Create `internal/service/platform.go`:
  - `DetectPlatform() Platform` - Returns Linux/macOS/Unknown
  - `ServiceBackend` interface:
    - `StartService(name string) error`
    - `StopService(name string) error`
    - `RestartService(name string) error`
    - `GetStatus(name string) (*ServiceStatus, error)`
    - `EnableService(name string) error`
    - `DisableService(name string) error`
    - `CreateServiceFile(name string, config *ServiceConfig) error`
  - `GetServiceBackend() ServiceBackend` - Returns appropriate backend for platform

### 3.3 Systemd Integration (Linux)

- Create `internal/service/systemd.go`:
  - Implements `ServiceBackend` interface
  - `StartSystemdService(name string) error` - Requires sudo
  - `StopSystemdService(name string) error` - Requires sudo
  - `GetSystemdStatus(name string) (*SystemdStatus, error)` - May require sudo
  - `CreateSystemdServiceFile(name string, config *ServiceConfig) error` - Requires sudo
  - `UpdateSystemdServiceFile(name string, config *ServiceConfig) error` - Update existing service file
  - Service file generation with all parameters (reference: `scripts/update/update-service.sh`, `scripts/update/update-worker-service.sh`):
    - **Master Service Parameters:**
      - `User=quilibrium`
      - `Group=qtools`
      - `WorkingDirectory=/home/quilibrium/node`
      - `ExecStart` with flags:
        - `--network=1` (if testnet enabled)
        - `--debug` (if debug enabled)
        - `--signature-check=false` (if signature check disabled)
      - `ExecStop=/bin/kill -s SIGINT $MAINPID`
      - `ExecReload` (same flags as ExecStart)
      - `RestartSec=<value>` (from config, default 60s, normalized to "<int>s")
      - `Restart=always`
      - `KillSignal=SIGINT`
      - `RestartKillSignal=SIGINT`
      - `FinalKillSignal=SIGKILL`
      - `TimeoutStopSec=240`
      - `Environment=IPFS_LOGGING=debug` (if IPFS debug enabled)
    - **Worker Service Parameters (template with %i):**
      - `User=quilibrium`
      - `Group=qtools`
      - `WorkingDirectory=/home/quilibrium/node`
      - `ExecStart` with flags:
        - `--network=1` (if testnet enabled)
        - `--debug` (if debug enabled)
        - `--signature-check=false` (if signature check disabled)
        - `--core %i` (worker instance number)
      - `ExecStop=/bin/kill -s SIGINT $MAINPID`
      - `ExecReload` (same flags as ExecStart)
      - `RestartSec=<value>` (from `service.worker_service.restart_time`, fallback to `service.restart_time`, default 5s)
      - `Restart=on-failure`
      - `StartLimitBurst=5`
      - `KillSignal=SIGINT`
      - `RestartKillSignal=SIGINT`
      - `FinalKillSignal=SIGKILL`
      - `TimeoutStopSec=240`
      - `CPUSchedulingPolicy=rr` (optional, conditionally included if `EnableCPUScheduling` is true)
      - `CPUSchedulingPriority=<value>` (optional, from `service.dataworker_priority`, default 90, conditionally included if `EnableCPUScheduling` is true)
      - Reference: `scripts/update/update-worker-service.sh` (line 235-236) - Currently always included, but can be made optional
      - `Environment` variables:
        - `IPFS_LOGGING=debug` (if IPFS debug enabled)
        - `GOGC=<value>` (if set in `service.worker_service.gogc`)
        - `GOMEMLIMIT=<value>` (if set in `service.worker_service.gomemlimit`)
  - Use `github.com/coreos/go-systemd/v22/dbus` or exec `systemctl` (with sudo when needed)
  - Service files location: `/etc/systemd/system/` or `/lib/systemd/system/`
  - Request sudo only when necessary (service file creation, start/stop operations)
  - Reference: `scripts/update/update-service.sh` (lines 52-240) and `scripts/update/update-worker-service.sh` (lines 66-256)

### 3.4 Launchd Integration (macOS)

- Create `internal/service/launchd.go`:
  - Implements `ServiceBackend` interface
  - `StartLaunchdService(name string) error` - Uses `launchctl load`
  - `StopLaunchdService(name string) error` - Uses `launchctl unload`
  - `GetLaunchdStatus(name string) (*LaunchdStatus, error)` - Uses `launchctl list`
  - `CreateLaunchdServiceFile(name string, config *ServiceConfig) error`
  - Plist contents:
    - `UserName` = `quilibrium` (for system daemon)
    - `WorkingDirectory` = `/home/quilibrium/node`
  - Service files location: `~/Library/LaunchAgents/` (user) or `/Library/LaunchDaemons/` (system)
  - Request sudo only when necessary (system daemon creation)

### 3.5 macOS Plist Generation

- Create `internal/service/plist.go`:
  - `GeneratePlist(config *PlistConfig) ([]byte, error)` - Generate plist XML
  - `GenerateMasterPlist(config *ServiceConfig) ([]byte, error)` - Generate master service plist
  - `GenerateWorkerPlist(config *ServiceConfig, instance int) ([]byte, error)` - Generate worker service plist
  - `PlistConfig` struct with:
    - Label (service identifier)
    - ProgramArguments (command and args array)
      - Include flags: `--network=1` (testnet), `--debug`, `--signature-check=false`
      - For workers: include `--core <instance>` flag
    - RunAtLoad (start on load)
    - KeepAlive (restart policy)
      - Master: `true` (always restart)
      - Workers: `dict` with `SuccessfulExit=false` (restart on failure)
    - WorkingDirectory (`/home/quilibrium/node`)
    - StandardOutPath, StandardErrorPath (logging)
    - EnvironmentVariables:
      - `IPFS_LOGGING=debug` (if IPFS debug enabled)
      - `GOGC=<value>` (for workers, if set)
      - `GOMEMLIMIT=<value>` (for workers, if set)
    - ThrottleInterval (restart delay, equivalent to RestartSec)
      - Master: from `service.restart_time` (default 60s)
      - Workers: from `service.worker_service.restart_time` (default 5s)
    - UserName (for system daemon: `quilibrium`)
  - Support for:
    - User agent (LaunchAgents)
    - System daemon (LaunchDaemons)
    - Worker services (separate plist files per instance)
  - Use `github.com/DHowett/go-plist` or standard XML encoding
  - Reference: `scripts/update/update-service.sh` and `scripts/update/update-worker-service.sh` for parameter mapping

### 3.6 Worker Management

- Create `internal/service/workers.go`:
  - `StartWorkers(count int, basePort int) error` - Start all workers
  - `StartWorker(coreIndex int) error` - Start specific worker by core index
  - `StartWorkersByCores(coreNumbers []int) error` - Start specific workers by core numbers
  - `StopWorkers(count int) error` - Stop all workers
  - `StopWorker(coreIndex int) error` - Stop specific worker by core index
  - `StopWorkersByCores(coreNumbers []int) error` - Stop specific workers by core numbers
  - `RestartWorkers(coreNumbers []int) error` - Restart specific workers
  - `RestartWorker(coreIndex int) error` - Restart specific worker by core index
  - `ParseCoreNumbers(input string) ([]int, error)` - Parse core number input:
    - Single: `"5"` → `[5]`
    - Range: `"1-4"` → `[1,2,3,4]`
    - Multiple: `"1,3,5"` → `[1,3,5]`
    - Combination: `"1-3,5,7-9"` → `[1,2,3,5,7,8,9]`
    - Validation: Check core numbers are valid (1 to max workers)
    - Error handling for invalid formats
  - `GetWorkerStatus(workerIndex int) (*WorkerStatus, error)`
  - `GetAllWorkerStatus() (map[int]*WorkerStatus, error)` - Get status of all workers
  - Worker port calculation
  - Workers run as `quilibrium:qtools` user/group
  - Worker service files specify `User=quilibrium` and `Group=qtools`

## Phase 4: CLI Interface

### 4.1 Main CLI

- Create `cmd/qtools/main.go`:
  - Parse command-line arguments using `github.com/spf13/cobra`
  - Commands:
    - `node setup [--automatic] [--workers N]` - Setup node (defaults to manual mode, use --automatic to override)
    - `node mode [--manual|--automatic]` - Toggle between manual and automatic mode
    - `node install [--peer-id ID] [--listen-port PORT] ...`
    - `service start [--master] [--core-index N] [--cores "1-4,6,8"]` - Start all (default), master only, or specific workers
    - `service stop [--master] [--core-index N] [--cores "1-4,6,8"] [--kill]` - Stop all (default), master only, or specific workers
    - `service restart [--master] [--core-index N] [--cores "1-4,6,8"] [--wait]` - Restart all (default), master only, or specific workers
    - `service update [--master] [--testnet] [--debug] [--skip-sig-check] [--ipfs-debug] [--restart-time TIME] [--gogc VALUE] [--gomemlimit VALUE] [--enable-cpu-scheduling] [--cpu-priority VALUE] [--enable] [--restart]` - Update service file with new parameters
    - `--enable-cpu-scheduling` - Enable CPU scheduling for workers (optional)
    - `--cpu-priority VALUE` - Set CPU scheduling priority (default 90, only used if CPU scheduling enabled)
    - Core number format: single (`5`), range (`1-4`), multiple (`1,3,5`), or combination (`1-3,5,7-9`)
    - Reference: `scripts/update/update-service.sh` and `scripts/update/update-worker-service.sh` for all parameter options
    - `service status [--worker N]`
    - `logs view [--master|--worker N|--qtools] [--filter STRING] [--exclude STRING]` - View logs
    - `logs filters [--preset NAME] [--save NAME]` - Manage log filter presets
    - `logs configure [--path PATH] [--max-size MB] [--max-backups N] [--max-age DAYS] [--compress]` - Configure custom logging (enabled by default)
    - `logs disable-custom` - Disable custom logging (revert to stdout)
    - `node register [--name NAME] [--endpoint ENDPOINT]` - Register node for desktop app (uses public/private key encryption via Quilibrium Messaging)
    - `tui` - Launch TUI mode
  - Flag: `--tui` to launch TUI from any command

## Phase 5: TUI Implementation

### 5.1 Main TUI App

- Create `internal/tui/app.go`:
  - Main Bubble Tea model implementing `tea.Model`
  - Navigation between views
  - Global keybindings (q to quit, etc.)
  - State management

### 5.2 Node Setup View

- Create `internal/tui/views/node_setup.go`:
  - Interactive form for node setup
  - **Default mode: Manual** (opinionated default for better reliability)
    - UI messaging: "Recommended: Separate worker services for better reliability"
    - Can toggle to Automatic mode if desired
  - Mode toggle button (Manual ↔ Automatic)
    - Tooltip/help text explains: Manual = separate services (more reliable), Automatic = master spawns workers
  - Worker count input (for manual mode, auto-calculated by default)
  - Port configuration (auto-configured)
  - Progress display during installation
  - Calls `node.SetupNode()` and `node.CompleteInstall()`
  - Shows current mode prominently
  - **User experience:** Setup feels automatic - tooling handles all complexity

### 5.3 Service Control View

- Create `internal/tui/views/service_control.go`:
  - Main actions (primary view):
    - Start All / Stop All / Restart All buttons
    - **In manual mode (default):** Single button starts/stops everything automatically
    - User doesn't need to manage individual workers - tooling handles it
  - Real-time status display:
    - Shows unified status (master + all workers)
    - Can expand to see individual worker status
    - Shows core numbers for each worker
  - **Advanced controls (expandable section):**
    - **Master Only Controls:**
      - Start Master Only button
      - Stop Master Only button
      - Restart Master Only button
      - Leaves all workers running/stopped as they are
      - Useful for master-specific operations
    - **Worker(s) Controls:**
      - Start Worker(s) section:
        - Input field for core number(s)
        - Start button
      - Stop Worker(s) section:
        - Input field for core number(s)
        - Stop button
      - Restart Worker(s) section:
        - Input field for core number(s)
        - Restart button
      - Core number input supports:
        - Single core: `5` (affect worker 5)
        - Range: `1-4` (affect workers 1, 2, 3, 4)
        - Multiple: `1,3,5` (affect workers 1, 3, 5)
        - Combination: `1-3,5,7-9` (affect workers 1,2,3,5,7,8,9)
      - Input validation (check valid core numbers)
      - Shows which workers will be affected before confirming
      - Confirmation dialog before executing
      - Shared core input component (reused for start/stop/restart)
  - Navigation:
    - Tab or expandable section to show/hide advanced controls
    - Default: Simple view (start/stop/restart all)
    - Advanced: Expand to show granular controls
  - Calls `service.*` functions:
    - `StartMasterOnly()` - Start master service only
    - `StopMasterOnly()` - Stop master service only
    - `RestartMasterOnly()` - Restart master service only
    - `StartWorkers(coreNumbers []int)` - Start specific workers
    - `StopWorkers(coreNumbers []int)` - Stop specific workers
    - `RestartWorkers(coreNumbers []int)` - Restart specific workers
    - `ParseCoreNumbers(input string)` - Parse user input for core numbers
    - `GetAllWorkerStatus()` - Get status of all workers for display
  - **User experience:** 
    - Simple by default (start/stop/restart all)
    - Advanced controls available when needed
    - Clear indication of what will be started/stopped/restarted
    - Same core number input format works for all operations

### 5.4 Status View

- Create `internal/tui/views/status.go`:
  - Display current service status
  - Worker status table
  - System information
  - Auto-refresh capability
  - Calls `service.GetStatus()`

### 5.5 Log View

- Create `internal/tui/views/log_view.go`:
  - Real-time log viewing using `tail -F` equivalent
  - Display logs from:
    - Master log: `master.log` (or journalctl if custom logging disabled)
    - Worker logs: `worker-1.log`, `worker-2.log`, etc.
    - Qtools log: `$QTOOLS_PATH/log` or `$QTOOLS_PATH/qtools.log`
  - Filter controls:
    - Include mode: Show only lines matching filter strings
    - Exclude mode: Hide lines matching filter strings
    - Multiple filters supported (AND logic for include, OR logic for exclude)
  - Filter presets:
    - Load from `log-selector-list.yml`
    - Save current filters as preset
    - Quick preset selection
  - Controls:
    - Switch between master/worker/qtools logs
    - Toggle filter mode (include/exclude)
    - Add/remove filter strings
    - Save/load presets
    - Pause/resume log following
    - Scroll through log history
  - Reference: `scripts/diagnostics/view-log.sh`

### 5.6 Log Filter Management

- Create `internal/tui/components/log_filters.go`:
  - Filter input component
  - Filter list display
  - Preset selector
  - Mode toggle (include/exclude)

- Create `internal/log/filters.go`:
  - `LogFilter` struct:
    - `Mode` - "include" or "exclude"
    - `Strings` - []string of filter patterns
  - `FilterLogLine(line string, filter *LogFilter) bool` - Apply filter to log line
  - `LoadFilters(path string) (*LogFilter, error)` - Load from `log-selector-list.yml`
  - `SaveFilters(filter *LogFilter, path string) error` - Save to `log-selector-list.yml`
  - `log-selector-list.yml` format:
    ```yaml
    mode: include  # or "exclude"
    filters:
      "error": true    # include/exclude lines with "error"
      "warning": false # don't include/exclude lines with "warning"
      "proof": true    # include/exclude lines with "proof"
    ```

  - Boolean values indicate whether the filter string is active

- Create `internal/log/viewer.go`:
  - `LogViewer` struct for tailing log files
  - `TailLogFile(path string, filter *LogFilter) (<-chan string, error)` - Tail with filtering
  - `GetLogFilePaths(config *config.Config) (masterPath, workerPaths []string, qtoolsPath string, error)`
  - Handle custom logging vs journalctl:
    - Check `.logger` config in node config
    - **Default:** Custom logging is enabled, use file logs (`master.log`, `worker-N.log`)
    - If disabled: fallback to `journalctl -u <service-name> -f`
  - Support for rotated log files
  - Handle file permissions (quilibrium user ownership)
  - Log directory: `/home/quilibrium/node/.logs/` (or configured path)
  - Log files owned by `quilibrium:qtools` with group read permissions

### 5.7 TUI Components

- Create reusable components:
  - `internal/tui/components/menu.go` - Navigation menu
  - `internal/tui/components/status_bar.go` - Status bar with current mode
  - `internal/tui/components/table.go` - Data tables
  - `internal/tui/components/form.go` - Form inputs
  - `internal/tui/components/log_viewer.go` - Log viewer component
  - `internal/tui/components/log_filters.go` - Log filter controls
  - `internal/tui/components/core_input.go` - Core number input component:
    - Text input field for core numbers
    - Real-time validation
    - Preview of which cores will be affected
    - Examples shown: "1-4,6,8" or "5" or "1,3,5"

## Phase 6: Desktop Integration (Stubbed for Future)

### 6.1 Quilibrium Messaging Integration (Stub)

- Create `internal/messaging/stub.go`:
  - Stub implementation for future Quilibrium Messaging integration
  - Placeholder for desktop app communication via Quilibrium Messaging protocol
  - Will be implemented in future phase
  - For now, focus on CLI/TUI functionality

### 6.2 Node Client Library (Internal)

- Create `internal/client/node_client.go`:
  - `NewNodeClient(binaryPath string) *NodeClient` - Create client for local node binary
  - Methods to get node information (used internally by qtools CLI/TUI):
    - `GetNodeInfo(configPath string) (*NodeInfo, error)` - Execute `node --node-info --config <path>`
    - `GetPeerID(configPath string) (string, error)` - Execute `node --peer-id --config <path>`
    - Parse text output from node binary commands
  - Reference implementation: `scripts/grpc/node-info.sh`, `scripts/grpc/peer-id.sh`
  - Alternative: Use gRPC client for real-time data (when node is running)
    - `GetPeerInfoViaGRPC() (*PeerInfo, error)` - Via `grpcurl` or gRPC client
    - Reference: `scripts/grpc/peer-info.sh` uses `grpcurl -plaintext localhost:8337`

**Implementation Approach Discussion:**

**Option 1: Node Binary Commands (Recommended for most cases)**

- Pros:
  - Works even when node service is stopped
  - No network connection required
  - Simple text parsing (grep/awk style)
  - Already proven in bash scripts
  - Can read from config files directly
- Cons:
  - Requires node binary to be available
  - Text parsing can be fragile
  - Not real-time (reads from config, not running node)

**Option 2: gRPC Client (For real-time data)**

- Pros:
  - Real-time data from running node
  - Structured data (protobuf)
  - More reliable than text parsing
- Cons:
  - Requires node service to be running
  - Requires gRPC connection (localhost:8337)
  - More complex implementation

**Hybrid Approach (Recommended):**

- Use node binary commands (`--node-info`, `--peer-id`) for:
  - Static info (peer ID, version from config)
  - When node is not running
  - Initial setup/configuration
- Use gRPC client for:
  - Real-time status when node is running
  - Dynamic data (current balance, active workers)
  - Service status checks

**Implementation Details:**

- Parse `--node-info` output similar to bash scripts:
  - Extract fields: Peer ID, Version, Seniority, Balance, Worker counts
  - Use regex or structured parsing (if node binary supports JSON output)
- Reference bash scripts:
  - `scripts/grpc/node-info.sh` - Basic node info
  - `scripts/grpc/peer-id.sh` - Peer ID extraction
  - `scripts/grpc/worker-count.sh` - Worker count parsing
  - `scripts/grpc/balance.sh` - Balance extraction
  - `scripts/grpc/seniority.sh` - Seniority extraction
  - `scripts/grpc/peer-info.sh` - gRPC peer info (alternative)

## Implementation Details

### Installation & Permissions

**Default Paths:**

- Qtools: `/home/quilibrium/qtools`
- Node: `/home/quilibrium/node`
- Client: `/home/quilibrium/client`
- Config: `/home/quilibrium/qtools/config.yml`
- Node Config: `/home/quilibrium/node/.config/config.yml`
- Logs: `/home/quilibrium/node/.logs/`

**User & Group Setup:**

- `quilibrium` user created (system user, no login shell)
- `qtools` group created
- Installing user (if non-root) added to `qtools` group
- All qtools/node files owned by `quilibrium:qtools`
- Group permissions: `g+rwx` (read, write, execute for qtools group members)

**Symlinks:**

- `/usr/local/bin/node` → node binary in `/home/quilibrium/node/`
- `/usr/local/bin/qtools` → qtools binary

**Permission Handling:**

- Commands run as `quilibrium:qtools` when possible (using `sg qtools` or similar)
- Crontasks run as `quilibrium:qtools` to avoid permission issues
- Sudo requested only for privileged operations:
  - User/group creation
  - Service file creation/modification
  - Systemd/launchd operations
  - Firewall configuration
  - Binary installation to `/usr/local/bin`
- If user is in `qtools` group, most operations don't require sudo

### Key Dependencies

- `github.com/charmbracelet/bubbletea` - TUI framework
- `github.com/charmbracelet/lipgloss` - Styling
- `github.com/spf13/cobra` - CLI framework
- `gopkg.in/yaml.v3` - YAML parsing
  - `google.golang.org/grpc` - gRPC client (optional, for real-time node data when running)
- `os/exec` - Execute node binary commands (standard library)
  - `github.com/coreos/go-systemd/v22/dbus` - Systemd integration (Linux, optional)
- `github.com/DHowett/go-plist` - Plist encoding/decoding (macOS, optional)
- `golang.org/x/crypto` - Authentication/crypto
- `runtime` - Platform detection (`runtime.GOOS`)
- Standard library: `os/exec` for system commands, `net` for networking, `encoding/xml` for plist

### Authentication Flow

**Authentication Method:**

- Authentication will use **public/private key encryption** via Quilibrium Messaging layer
- This authentication will be required for:
  - Desktop app connections
  - gRPC API access (port 8337)
  - REST API access (port 8338)
- Implementation details will be added when Quilibrium Messaging integration is implemented

**Desktop App Integration (Future - Stubbed):**

- Desktop app integration will use **Quilibrium Messaging** protocol
- Implementation is stubbed for now - focus on CLI/TUI
- Future phase will implement:
  - Quilibrium Messaging integration for desktop app communication
  - Public/private key encryption for authentication
  - Node registry and management via messaging protocol
  - Service control via messaging protocol
  - Configuration management via messaging protocol

### Config Migration Strategy

- **Dynamic Config Loading:**

  1. Read existing `config.yml` as raw YAML (`map[string]interface{}`)
  2. Detect config version/format (check for version field or structure patterns)
  3. Apply registered migrations automatically
  4. Convert to structured `Config` type
  5. Merge with programmatic defaults
  6. Validate structure
  7. Save in new format (backup old config first)

- **Migration Functions:**
  - Each config parameter change gets its own migration function
  - Migrations are registered in `migrations.go`
  - Migrations are idempotent (safe to run multiple times)
  - Migrations handle path changes (e.g., `.crontab.status.enabled` → `.scheduled_tasks.status.enabled`)

- **Default Config Generation:**
  - No reliance on `config.sample.yml` file
  - Defaults generated programmatically in Go code
  - New parameters automatically get defaults when config is loaded
  - User's existing config values are preserved

- **Benefits:**
  - No need to maintain static sample file
  - Automatic migration when config structure changes
  - Backward compatible with old config formats
  - Easy to add new config parameters without breaking existing configs

### Error Handling

- Consistent error types across packages
- User-friendly error messages in TUI
- Detailed logging for debugging
- Proper error responses in IPC protocol

### Testing Strategy

- Unit tests for config loading/migration
- Unit tests for individual migration functions
- Unit tests for config value getters/setters (dynamic path access)
- Integration tests for full config migration scenarios
- Unit tests for mode detection
- Unit tests for platform detection
- Unit tests for plist generation (macOS)
- Integration tests for service commands (mock systemd/launchd)
- TUI testing using Bubble Tea's testing utilities
- Node client integration tests (mock gRPC server)
- Cross-platform testing (Linux and macOS)

## File References

Key files to reference from existing codebase:

**Config & Setup:**

- `config.sample.yml` - Reference for config structure (but use dynamic generation instead)
- Existing `config.yml` files in use - Examples of actual config values
- `scripts/install/create-quilibrium-user.sh` - User/group creation and permission setup
- `scripts/install/complete-install.sh` - Installation flow
- `scripts/config/manual-mode.sh` - Manual mode setup
- `scripts/service-commands/start.sh`, `stop.sh`, `restart.sh`, `status.sh` - Service commands
- `scripts/cluster/service-helpers.sh` - Service helper functions (systemd examples)
- `scripts/cluster/utils.sh` - Utility functions
- `scripts/update/update-service.sh` - Service file generation (systemd) - **Reference for all master service parameters**
- `scripts/update/update-worker-service.sh` - Worker service file generation (systemd) - **Reference for all worker service parameters**

**Node Information (Binary Commands):**

- `utils/index.sh` - `run_node_command()` function (lines 159-197) - Core function for executing node binary
- `scripts/grpc/node-info.sh` - Node info via `--node-info` flag
- `scripts/grpc/peer-id.sh` - Peer ID via `--peer-id` flag
- `scripts/grpc/worker-count.sh` - Worker count parsing from `--node-info`
- `scripts/grpc/balance.sh` - Balance extraction from `--node-info`
- `scripts/grpc/seniority.sh` - Seniority extraction from `--node-info`
- `scripts/grpc/node-version.sh` - Version extraction from `--node-info`

**Node Information (gRPC - Alternative):**

- `scripts/grpc/peer-info.sh` - Peer info via gRPC (`grpcurl`)
- `scripts/grpc/network-info.sh` - Network info via gRPC
- `scripts/grpc/token-info.sh` - Token info via gRPC

**Configuration:**

**Node Config Management:**

- `scripts/config/set-p2p-listen-multiaddr.sh` - P2P listen address configuration
- `scripts/config/set-grpc-multiaddr.sh` - gRPC endpoint configuration
- `scripts/config/set-rest-multiaddr.sh` - REST endpoint configuration
- `scripts/config/set-stream-listen-multiaddr.sh` - Stream listen address configuration
- `scripts/config/clear-data-workers.sh` - Clear data worker arrays
- `scripts/config/add-direct-peer.sh` - Add direct peer
- `scripts/config/get-direct-peers.sh` - Get direct peers list
- `scripts/config/update-direct-peers.sh` - Update direct peers
- `scripts/config/set-dynamic-target.sh` - Set dynamic proof target
- `scripts/config/max-frame.sh` - Set max frame
    - `scripts/config/set-sync-timeout.sh` - Set sync timeout
    - `scripts/config/toggle-dynamic-proofs.sh` - Toggle dynamic proofs
    - `scripts/config/set-reward-peer-id.sh` - Set reward peer ID
    - `scripts/config/set-announce-multiaddrs.sh` - Set announce multiaddrs
    - `scripts/config/clear-announce-multiaddrs.sh` - Clear announce multiaddrs
    - `scripts/config/config.sh` - General config operations (get-value, set-value with --config quil)
    - `scripts/config/enable-custom-logging.sh` - Enable custom logging with file splitting

**Log Management:**

- `scripts/diagnostics/view-log.sh` - View logs with filtering (--filter, --exclude, --core)
- `scripts/diagnostics/clean-logs.sh` - Clean log files

### macOS Plist Reference

macOS plist structure should mirror systemd service structure:

**Plist Structure:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.quilibrium.node</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>--signature-check=false</string>
        <string>--debug</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>WorkingDirectory</key>
    <string>/Users/username/ceremonyclient/node</string>
    <key>StandardOutPath</key>
    <string>/Users/username/ceremonyclient/node/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/username/ceremonyclient/node/logs/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
```

**Key Mappings:**

- `Label` → Service identifier (e.g., `com.quilibrium.node`, `com.quilibrium.node.worker.1`)
- `ProgramArguments` → Equivalent to systemd `ExecStart` (array format)
- `RunAtLoad` → Equivalent to systemd `WantedBy` (start on load)
- `KeepAlive` → Equivalent to systemd `Restart=always` (dict with conditions)
- `WorkingDirectory` → Equivalent to systemd `WorkingDirectory`
- `StandardOutPath/StandardErrorPath` → Equivalent to systemd logging
- `ThrottleInterval` → Restart delay (equivalent to `RestartSec`)

**File Locations:**

- User agent: `~/Library/LaunchAgents/com.quilibrium.node.plist`
- System daemon: `/Library/LaunchDaemons/com.quilibrium.node.plist` (requires root)
- Worker services: `~/Library/LaunchAgents/com.quilibrium.node.worker.1.plist` (template with %i)

**Launchd Commands:**

- Load service: `launchctl load ~/Library/LaunchAgents/com.quilibrium.node.plist`
- Unload service: `launchctl unload ~/Library/LaunchAgents/com.quilibrium.node.plist`
- Start service: `launchctl start com.quilibrium.node`
- Stop service: `launchctl stop com.quilibrium.node`
- List services: `launchctl list | grep quilibrium`

## Next Steps After Phase 1-6

Future phases can add:

- Quilibrium Messaging integration for desktop app communication
- Update commands (node updates, self-update)
- Cluster management
- Backup/restore functionality
- Diagnostics and monitoring
- QClient integration
- Desktop app SDK/examples