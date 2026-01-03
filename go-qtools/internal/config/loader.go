package config

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// LoadConfig loads and auto-migrates config from the specified path
func LoadConfig(path string) (*Config, error) {
	// Read raw YAML
	rawConfig, err := ReadConfigRaw(path)
	if err != nil {
		return nil, err
	}

	// Initialize migrations
	InitializeMigrations()

	// Apply migrations
	migratedConfig, err := ApplyMigrations(rawConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to apply migrations: %w", err)
	}

	// Convert to structured Config type
	config := &Config{}
	configBytes, err := yaml.Marshal(migratedConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal migrated config: %w", err)
	}

	if err := yaml.Unmarshal(configBytes, config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Store raw config for dynamic access
	config.Raw = migratedConfig

	// Merge with defaults
	config = MergeDefaults(config)

	// Validate
	if err := ValidateConfig(config); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}

	return config, nil
}

// SaveConfig saves the config to the specified path
func SaveConfig(config *Config, path string) error {
	// Ensure directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	// Use raw config if available, otherwise marshal structured config
	var configBytes []byte
	var err error

	if config.Raw != nil {
		configBytes, err = yaml.Marshal(config.Raw)
	} else {
		configBytes, err = yaml.Marshal(config)
	}

	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	// Write config file with appropriate permissions
	// Try to preserve ownership if file exists
	var fileMode os.FileMode = 0644
	if info, err := os.Stat(path); err == nil {
		fileMode = info.Mode()
	}

	// Write file
	if err := os.WriteFile(path, configBytes, fileMode); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	// Try to set ownership to quilibrium:qtools if possible
	if err := setFileOwnership(path); err != nil {
		// Non-fatal error, just log it
		// In production, this might be logged but not fail the operation
	}

	return nil
}

// ReadConfigRaw reads raw YAML config as map[string]interface{}
func ReadConfigRaw(path string) (map[string]interface{}, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			// Return empty config if file doesn't exist
			return make(map[string]interface{}), nil
		}
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var rawConfig map[string]interface{}
	if err := yaml.Unmarshal(data, &rawConfig); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	return rawConfig, nil
}

// ValidateConfig validates the config structure
func ValidateConfig(config *Config) error {
	// Basic validation
	if config == nil {
		return fmt.Errorf("config is nil")
	}

	// Validate required fields have defaults
	if config.Service == nil {
		config.Service = &ServiceConfig{}
	}

	if config.Manual == nil {
		config.Manual = &ManualConfig{}
	}

	return nil
}

// setFileOwnership attempts to set file ownership to quilibrium:qtools
// This is a best-effort operation and failures are non-fatal
func setFileOwnership(path string) error {
	// Check if quilibrium user exists
	_, err := user.Lookup("quilibrium")
	if err != nil {
		// User doesn't exist, skip ownership change
		return nil
	}

	// Check if qtools group exists
	_, err = user.LookupGroup("qtools")
	if err != nil {
		// Group doesn't exist, skip ownership change
		return nil
	}

	// Try to change ownership using chown command
	// This requires appropriate permissions
	// In practice, this might need sudo or the user might need to be in qtools group
	// For now, we'll skip this and let the caller handle it if needed
	// This can be implemented using os.Chown if we have the right permissions

	return nil
}
