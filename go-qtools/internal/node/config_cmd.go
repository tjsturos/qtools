package node

import (
	"fmt"
	"os"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// ConfigCommandType represents the type of config command
type ConfigCommandType string

const (
	ConfigCommandGet    ConfigCommandType = "get"
	ConfigCommandSet    ConfigCommandType = "set"
	ConfigCommandDelete ConfigCommandType = "delete"
)

// ConfigCommandOptions represents options for config commands
type ConfigCommandOptions struct {
	ConfigType string // "qtools" or "quil" (node config)
	Default    string // Default value for get command
	Quiet      bool   // Suppress output for set command
}

// ExecuteConfigCommand executes a config command (get/set/delete)
func ExecuteConfigCommand(cmdType ConfigCommandType, path string, value string, opts ConfigCommandOptions, cfg *config.Config) error {
	if opts.ConfigType == "" {
		opts.ConfigType = "qtools"
	}

	switch cmdType {
	case ConfigCommandGet:
		return getConfigValue(path, opts, cfg)
	case ConfigCommandSet:
		return setConfigValue(path, value, opts, cfg)
	case ConfigCommandDelete:
		return deleteConfigValue(path, opts, cfg)
	default:
		return fmt.Errorf("unknown config command type: %s", cmdType)
	}
}

// getConfigValue gets a config value
func getConfigValue(path string, opts ConfigCommandOptions, cfg *config.Config) error {
	var val interface{}
	var err error

	if opts.ConfigType == "quil" {
		// Node config
		mgr, err := NewNodeConfigManager("")
		if err != nil {
			return fmt.Errorf("failed to create node config manager: %w", err)
		}
		val, err = mgr.GetValue(path)
	} else {
		// Qtools config
		val, err = config.GetConfigValue(cfg, path)
	}

	if err != nil {
		if opts.Default != "" {
			fmt.Println(opts.Default)
			return nil
		}
		return fmt.Errorf("failed to get config value: %w", err)
	}

	// Print value
	fmt.Println(formatValue(val))
	return nil
}

// setConfigValue sets a config value
func setConfigValue(path string, value string, opts ConfigCommandOptions, cfg *config.Config) error {
	var err error

	if opts.ConfigType == "quil" {
		// Node config
		mgr, err := NewNodeConfigManager("")
		if err != nil {
			return fmt.Errorf("failed to create node config manager: %w", err)
		}

		// Parse value (try to convert to appropriate type)
		parsedValue := parseValue(value)
		err = mgr.SetValue(path, parsedValue)
	} else {
		// Qtools config
		parsedValue := parseValue(value)
		err = config.SetConfigValue(cfg, path, parsedValue)
		if err == nil {
			// Save config
			configPath := config.GetConfigPath()
			if err := config.SaveConfig(cfg, configPath); err != nil {
				return fmt.Errorf("failed to save config: %w", err)
			}
		}
	}

	if err != nil {
		return fmt.Errorf("failed to set config value: %w", err)
	}

	if !opts.Quiet {
		fmt.Printf("Set %s = %s\n", path, value)
	}

	return nil
}

// deleteConfigValue deletes a config value
func deleteConfigValue(path string, opts ConfigCommandOptions, cfg *config.Config) error {
	if opts.ConfigType == "quil" {
		// Node config
		mgr, err := NewNodeConfigManager("")
		if err != nil {
			return fmt.Errorf("failed to create node config manager: %w", err)
		}
		return mgr.DeleteValue(path)
	}

	// Qtools config - would need delete support in config package
	return fmt.Errorf("delete not yet implemented for qtools config")
}

// parseValue parses a string value into an appropriate type
func parseValue(value string) interface{} {
	// Try boolean
	if value == "true" {
		return true
	}
	if value == "false" {
		return false
	}

	// Try integer
	if intVal, err := parseInt(value); err == nil {
		return intVal
	}

	// Try float
	if floatVal, err := parseFloat(value); err == nil {
		return floatVal
	}

	// Default to string
	return value
}

// parseInt tries to parse an integer
func parseInt(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}

// parseFloat tries to parse a float
func parseFloat(s string) (float64, error) {
	var result float64
	_, err := fmt.Sscanf(s, "%g", &result)
	return result, err
}

// formatValue formats a value for output
func formatValue(val interface{}) string {
	switch v := val.(type) {
	case bool:
		if v {
			return "true"
		}
		return "false"
	case int:
		return fmt.Sprintf("%d", v)
	case float64:
		return fmt.Sprintf("%g", v)
	case string:
		return v
	case nil:
		return ""
	default:
		return fmt.Sprintf("%v", v)
	}
}

// ValidateConfig validates a config file
func ValidateConfig(configType string) error {
	if configType == "" {
		configType = "qtools"
	}

	if configType == "quil" {
		// Validate node config
		mgr, err := NewNodeConfigManager("")
		if err != nil {
			return fmt.Errorf("failed to create node config manager: %w", err)
		}

		_, err = mgr.Load()
		if err != nil {
			return fmt.Errorf("node config is invalid: %w", err)
		}

		fmt.Println("Node config is valid")
		return nil
	}

	// Validate qtools config
	configPath := config.GetConfigPath()
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		return fmt.Errorf("config file does not exist: %s", configPath)
	}

	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		return fmt.Errorf("qtools config is invalid: %w", err)
	}

	if cfg == nil {
		return fmt.Errorf("config is nil")
	}

	fmt.Println("Qtools config is valid")
	return nil
}
