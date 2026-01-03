# Shared Constants and Configuration Values

## Rule: Define Usernames, Groups, and System Values Once

**Problem:** Hardcoding values like `"quilibrium"`, `"qtools"`, `"/home/quilibrium/qtools"`, `"ceremonyclient"`, `"/usr/local/bin/node"` throughout the codebase leads to:
- Inconsistency when values need to change
- Difficult refactoring
- Hard to test with different values
- Maintenance burden
- Risk of typos and inconsistencies

**Solution:** Define all system-level constants (usernames, groups, default paths, service names, binary paths, ports, etc.) in a central location and reference them throughout the codebase.

## Implementation Pattern

### 1. Create a Constants Package

Create `internal/constants/constants.go` with all shared values:

```go
package constants

import "github.com/tjsturos/qtools/go-tools/internal/config"

const (
    // User and Group
    DefaultUser  = "quilibrium"
    DefaultGroup = "qtools"
    
    // Paths
    DefaultQtoolsPath     = "/home/quilibrium/qtools"
    DefaultNodePath       = "/home/quilibrium/node"
    DefaultClientPath     = "/home/quilibrium/client"
    DefaultConfigPath     = "/home/quilibrium/qtools/config.yml"
    DefaultNodeConfigPath = "/home/quilibrium/node/.config/config.yml"
    DefaultLogsPath       = "/home/quilibrium/node/.logs"
    
    // Service Names
    DefaultServiceName = "ceremonyclient"
    
    // Binary Paths
    DefaultNodeBinaryPath   = "/usr/local/bin/node"
    DefaultQtoolsBinaryPath = "/usr/local/bin/qtools"
    
    // Ports
    DefaultP2PListenPort         = 8336
    DefaultStreamPort            = 8340
    DefaultGRPCPort              = 8337
    DefaultRESTPort              = 8338
    DefaultWorkerBaseP2PPort     = 50000
    DefaultWorkerBaseStreamPort  = 60000
    
    // File Permissions
    DefaultDirPerm  = 0755
    DefaultFilePerm = 0644
    DefaultGroupPerm = "g+rwx"
    
    // Log Files
    MasterLogFile = "master.log"
    WorkerLogFilePattern = "worker-%d.log"
)

// GetUser returns the configured user, checking config first, then default
func GetUser(cfg *config.Config) string {
    if cfg != nil && cfg.Service != nil && cfg.Service.DefaultUser != "" {
        return cfg.Service.DefaultUser
    }
    return DefaultUser
}

// GetGroup returns the configured group
func GetGroup() string {
    return DefaultGroup
}

// GetServiceName returns the configured service name
func GetServiceName(cfg *config.Config) string {
    if cfg != nil && cfg.Service != nil && cfg.Service.FileName != "" {
        return cfg.Service.FileName
    }
    return DefaultServiceName
}
```

### 2. Import and Use Throughout Codebase

```go
// ❌ BAD - Hardcoded
user := "quilibrium"
group := "qtools"
path := "/home/quilibrium/qtools"
serviceName := "ceremonyclient"
symlinkPath := "/usr/local/bin/node"
cmd := exec.Command("sudo", "chown", "quilibrium:qtools", path)

// ✅ GOOD - Use constants
import "github.com/tjsturos/qtools/go-tools/internal/constants"

user := constants.GetUser(cfg)
group := constants.GetGroup()
path := constants.DefaultQtoolsPath
serviceName := constants.GetServiceName(cfg)
symlinkPath := constants.DefaultNodeBinaryPath
cmd := exec.Command("sudo", "chown", fmt.Sprintf("%s:%s", constants.DefaultUser, constants.DefaultGroup), path)
```

### 3. Allow Override via Config

Values should be configurable via config file, with sensible defaults:

```go
// In config package
type Config struct {
    Service *ServiceConfig `yaml:"service"`
    // ...
}

type ServiceConfig struct {
    DefaultUser string `yaml:"default_user"` // Defaults to "quilibrium"
    FileName    string `yaml:"file_name"`    // Defaults to "ceremonyclient"
    // ...
}
```

### 4. Environment Variable Support

For flexibility, also support environment variables (already implemented in `paths.go`):

```go
func GetQtoolsPath() string {
    if path := os.Getenv("QTOOLS_PATH"); path != "" {
        return path
    }
    return constants.DefaultQtoolsPath
}
```

## Current Hardcoded Values in Codebase

### Files Needing Refactoring

**`internal/node/update.go`:**
- Line 201: `"/usr/local/bin/node"` → Should use `constants.DefaultNodeBinaryPath`
- Line 309: `"quilibrium:qtools"` → Should use `constants.DefaultUser` and `constants.DefaultGroup`

**`internal/node/install.go`:**
- Multiple: `"quilibrium"`, `"qtools"` → Should use constants

**`internal/node/commands.go`:**
- Line 14: `"/usr/local/bin/node"` → Should use `constants.DefaultNodeBinaryPath`

**`internal/service/manager.go`:**
- Line 212: `"ceremonyclient"` → Should use `constants.DefaultServiceName`

**`internal/service/systemd.go`:**
- Templates use `{{.User}}` and `{{.Group}}` which are set to hardcoded values → Should use constants

**`internal/service/launchd.go`:**
- Plist generation uses hardcoded user → Should use constants

**`internal/config/paths.go`:**
- Already has some constants, but should be moved to `constants` package for consistency

## Examples of Values to Centralize

### User/Group
- `"quilibrium"` - Default user for running services
- `"qtools"` - Default group for file permissions

### Paths
- `/home/quilibrium/qtools` - Qtools installation directory
- `/home/quilibrium/node` - Node installation directory
- `/home/quilibrium/client` - Client installation directory
- `/home/quilibrium/qtools/config.yml` - Qtools config file
- `/home/quilibrium/node/.config/config.yml` - Node config file
- `/home/quilibrium/node/.logs` - Log directory

### Service/Binary Names
- `"ceremonyclient"` - Default service name
- `"/usr/local/bin/node"` - Node binary symlink path
- `"/usr/local/bin/qtools"` - Qtools binary symlink path

### Ports
- `8336` - Default P2P listen port
- `8337` - Default gRPC port
- `8338` - Default REST port
- `8340` - Default stream port
- `50000` - Default worker base P2P port
- `60000` - Default worker base stream port

### File Permissions
- `0755` - Directory permissions
- `0644` - File permissions
- `"g+rwx"` - Group permissions string

### Log Files
- `"master.log"` - Master log file name
- `"worker-%d.log"` - Worker log file pattern

## Real Examples from Codebase

### Example 1: Hardcoded in `internal/node/update.go`
```go
// ❌ CURRENT - Line 201, 309
symlinkPath := "/usr/local/bin/node"
cmd := exec.Command("sudo", "chown", "quilibrium:qtools", path)
```

```go
// ✅ SHOULD BE - Using constants
import "github.com/tjsturos/qtools/go-tools/internal/constants"

symlinkPath := constants.DefaultNodeBinaryPath
cmd := exec.Command("sudo", "chown", 
    fmt.Sprintf("%s:%s", constants.DefaultUser, constants.DefaultGroup), path)
```

### Example 2: Hardcoded in `internal/service/manager.go`
```go
// ❌ CURRENT - Line 212
func getServiceName(cfg *config.Config) string {
    if cfg != nil && cfg.Service != nil && cfg.Service.FileName != "" {
        return cfg.Service.FileName
    }
    return "ceremonyclient"  // Hardcoded
}
```

```go
// ✅ SHOULD BE
import "github.com/tjsturos/qtools/go-tools/internal/constants"

func getServiceName(cfg *config.Config) string {
    if cfg != nil && cfg.Service != nil && cfg.Service.FileName != "" {
        return cfg.Service.FileName
    }
    return constants.DefaultServiceName
}
```

### Example 3: Hardcoded in `internal/service/systemd.go` templates
```go
// ❌ CURRENT - ServiceConfig.User/Group set to hardcoded strings
serviceConfig := &ServiceConfig{
    User:  "quilibrium",  // Hardcoded
    Group: "qtools",      // Hardcoded
    // ...
}
```

```go
// ✅ SHOULD BE - Pass constants
serviceConfig := &ServiceConfig{
    User:  constants.GetUser(cfg),
    Group: constants.GetGroup(),
    // ...
}
```

## Benefits

1. **Single Source of Truth:** Change values in one place
2. **Testability:** Easy to override for testing
3. **Consistency:** Same values used everywhere
4. **Maintainability:** Clear where values come from
5. **Flexibility:** Can be overridden via config or env vars
6. **Type Safety:** Constants are typed and checked at compile time

## Migration Strategy

1. Create `internal/constants/constants.go` package with all values
2. Update `internal/config/paths.go` to import and use constants (or move constants there)
3. Update one package at a time:
   - Start with `internal/node/update.go`
   - Then `internal/service/manager.go`
   - Then `internal/service/systemd.go` and `launchd.go`
   - Continue with other packages
4. Replace hardcoded strings with constant references
5. Test each migration
6. Update documentation

## Implementation Notes

- Constants should be exported (capitalized) for use across packages
- Helper functions like `GetUser(cfg)` allow config-based overrides
- Environment variables can still override (as in `paths.go`)
- Consider creating a `Constants` struct if many values need to be passed together
- Use `go generate` or build tags if platform-specific constants are needed
