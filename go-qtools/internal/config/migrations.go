package config

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// MigrationFunc represents a migration function that transforms config data
type MigrationFunc func(oldConfig map[string]interface{}) (map[string]interface{}, error)

// Migration represents a single migration
type Migration struct {
	FromVersion string
	ToVersion   string
	Function    MigrationFunc
}

// MigrationRegistry holds all registered migrations
var migrationRegistry []Migration

// RegisterMigration registers a migration function
func RegisterMigration(fromVersion, toVersion string, fn MigrationFunc) {
	migrationRegistry = append(migrationRegistry, Migration{
		FromVersion: fromVersion,
		ToVersion:   toVersion,
		Function:    fn,
	})
}

// ApplyMigrations applies all registered migrations to the config
func ApplyMigrations(config map[string]interface{}) (map[string]interface{}, error) {
	result := make(map[string]interface{})
	
	// Deep copy the config
	for k, v := range config {
		result[k] = deepCopy(v)
	}

	// Get current version (default to "1.0" if not set)
	currentVersion := "1.0"
	if v, ok := result["config_version"].(string); ok {
		currentVersion = v
	}

	// Apply migrations in order
	for _, migration := range migrationRegistry {
		// Check if migration is needed
		if currentVersion == migration.FromVersion {
			var err error
			result, err = migration.Function(result)
			if err != nil {
				return nil, fmt.Errorf("migration from %s to %s failed: %w", migration.FromVersion, migration.ToVersion, err)
			}
			result["config_version"] = migration.ToVersion
			currentVersion = migration.ToVersion
		}
	}

	return result, nil
}

// MigrateCrontabToScheduledTasks migrates .crontab.* to .scheduled_tasks.*
func MigrateCrontabToScheduledTasks(old map[string]interface{}) (map[string]interface{}, error) {
	if crontab, ok := old["crontab"].(map[string]interface{}); ok {
		// Create scheduled_tasks if doesn't exist
		if _, exists := old["scheduled_tasks"]; !exists {
			old["scheduled_tasks"] = make(map[string]interface{})
		}
		st := old["scheduled_tasks"].(map[string]interface{})

		// Migrate each crontab section
		for key, value := range crontab {
			if _, exists := st[key]; !exists {
				st[key] = value
			}
		}

		// Remove old crontab section after migration
		delete(old, "crontab")
	}
	return old, nil
}

// MigrateServiceSettings migrates service setting changes
func MigrateServiceSettings(old map[string]interface{}) (map[string]interface{}, error) {
	if service, ok := old["service"].(map[string]interface{}); ok {
		// Migrate signature_check to signatureCheck if needed
		if sigCheck, ok := service["signature_check"]; ok {
			if _, exists := service["signatureCheck"]; !exists {
				service["signatureCheck"] = sigCheck
			}
		}
	}
	return old, nil
}

// MigrateListenAddr migrates listen address format changes
func MigrateListenAddr(old map[string]interface{}) (map[string]interface{}, error) {
	if settings, ok := old["settings"].(map[string]interface{}); ok {
		// Ensure listenAddr structure exists
		if _, exists := settings["listenAddr"]; !exists {
			settings["listenAddr"] = map[string]interface{}{
				"mode": "udp",
				"port": 8336,
			}
		}
	}
	return old, nil
}

// deepCopy performs a deep copy of an interface{}
func deepCopy(src interface{}) interface{} {
	switch v := src.(type) {
	case map[string]interface{}:
		dst := make(map[string]interface{})
		for k, val := range v {
			dst[k] = deepCopy(val)
		}
		return dst
	case []interface{}:
		dst := make([]interface{}, len(v))
		for i, val := range v {
			dst[i] = deepCopy(val)
		}
		return dst
	default:
		return src
	}
}

// BackupConfig creates a backup of the config file before migration
func BackupConfig(configPath string) (string, error) {
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return "", nil // No file to backup
	}

	timestamp := time.Now().Format("20060102_150405")
	backupPath := configPath + "." + timestamp + ".bak"
	backupDir := filepath.Dir(backupPath)
	
	// Ensure backup directory exists
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create backup directory: %w", err)
	}

	// Read original file
	data, err := os.ReadFile(configPath)
	if err != nil {
		return "", fmt.Errorf("failed to read config file: %w", err)
	}

	// Write backup
	if err := os.WriteFile(backupPath, data, 0644); err != nil {
		return "", fmt.Errorf("failed to write backup file: %w", err)
	}

	return backupPath, nil
}

// InitializeMigrations registers all migration functions
func InitializeMigrations() {
	// Register migrations in order
	RegisterMigration("1.0", "1.1", MigrateCrontabToScheduledTasks)
	RegisterMigration("1.1", "1.2", MigrateServiceSettings)
	RegisterMigration("1.2", "1.3", MigrateListenAddr)
	// Add more migrations as config structure evolves
}
