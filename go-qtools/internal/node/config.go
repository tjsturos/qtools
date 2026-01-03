package node

import (
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"gopkg.in/yaml.v3"
)

// NodeConfigManager manages the Quilibrium node's config file
type NodeConfigManager struct {
	configPath string
}

// NewNodeConfigManager creates a new NodeConfigManager
func NewNodeConfigManager(configPath string) (*NodeConfigManager, error) {
	if configPath == "" {
		configPath = config.GetNodeConfigPath()
	}

	// Ensure config directory exists
	dir := filepath.Dir(configPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create config directory: %w", err)
	}

	return &NodeConfigManager{
		configPath: configPath,
	}, nil
}

// Load loads the node config file
func (ncm *NodeConfigManager) Load() (*NodeConfig, error) {
	data, err := os.ReadFile(ncm.configPath)
	if err != nil {
		if os.IsNotExist(err) {
			// Return empty config if file doesn't exist
			return &NodeConfig{
				Raw: make(map[string]interface{}),
			}, nil
		}
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var rawConfig map[string]interface{}
	if err := yaml.Unmarshal(data, &rawConfig); err != nil {
		return nil, fmt.Errorf("failed to parse YAML: %w", err)
	}

	// Convert to structured type
	nodeConfig := &NodeConfig{}
	if err := yaml.Unmarshal(data, nodeConfig); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Store raw config for dynamic access
	nodeConfig.Raw = rawConfig

	return nodeConfig, nil
}

// Save saves the node config file
func (ncm *NodeConfigManager) Save(nodeConfig *NodeConfig) error {
	// Use raw config if available, otherwise marshal structured config
	var configBytes []byte
	var err error

	if nodeConfig.Raw != nil {
		configBytes, err = yaml.Marshal(nodeConfig.Raw)
	} else {
		configBytes, err = yaml.Marshal(nodeConfig)
	}

	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	// Ensure directory exists
	dir := filepath.Dir(ncm.configPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	// Write config file with appropriate permissions
	var fileMode os.FileMode = 0644
	if info, err := os.Stat(ncm.configPath); err == nil {
		fileMode = info.Mode()
	}

	if err := os.WriteFile(ncm.configPath, configBytes, fileMode); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	// Try to set ownership to quilibrium:qtools if possible
	if err := setNodeConfigOwnership(ncm.configPath); err != nil {
		// Non-fatal error
	}

	return nil
}

// GetValue gets a config value by dot-separated path (e.g., "p2p.listenMultiaddr")
func (ncm *NodeConfigManager) GetValue(path string) (interface{}, error) {
	config, err := ncm.Load()
	if err != nil {
		return nil, err
	}

	return getNestedValue(config.Raw, path)
}

// SetValue sets a config value by dot-separated path
func (ncm *NodeConfigManager) SetValue(path string, value interface{}) error {
	config, err := ncm.Load()
	if err != nil {
		return err
	}

	if config.Raw == nil {
		config.Raw = make(map[string]interface{})
	}

	if err := setNestedValue(config.Raw, path, value); err != nil {
		return err
	}

	return ncm.Save(config)
}

// DeleteValue deletes a config value by dot-separated path
func (ncm *NodeConfigManager) DeleteValue(path string) error {
	config, err := ncm.Load()
	if err != nil {
		return err
	}

	if config.Raw == nil {
		return nil // Nothing to delete
	}

	if err := deleteNestedValue(config.Raw, path); err != nil {
		return err
	}

	return ncm.Save(config)
}

// getNestedValue gets a nested value from a map using dot-separated path
func getNestedValue(m map[string]interface{}, path string) (interface{}, error) {
	keys := splitPath(path)
	current := m

	for i, key := range keys {
		if i == len(keys)-1 {
			if val, ok := current[key]; ok {
				return val, nil
			}
			return nil, fmt.Errorf("key %s not found", path)
		}

		if next, ok := current[key].(map[string]interface{}); ok {
			current = next
		} else {
			return nil, fmt.Errorf("path %s is not a map at key %s", path, key)
		}
	}

	return nil, fmt.Errorf("key %s not found", path)
}

// setNestedValue sets a nested value in a map using dot-separated path
func setNestedValue(m map[string]interface{}, path string, value interface{}) error {
	keys := splitPath(path)
	current := m

	for i, key := range keys {
		if i == len(keys)-1 {
			current[key] = value
			return nil
		}

		if next, ok := current[key].(map[string]interface{}); ok {
			current = next
		} else {
			current[key] = make(map[string]interface{})
			current = current[key].(map[string]interface{})
		}
	}

	return nil
}

// deleteNestedValue deletes a nested value from a map using dot-separated path
func deleteNestedValue(m map[string]interface{}, path string) error {
	keys := splitPath(path)
	current := m

	for i, key := range keys {
		if i == len(keys)-1 {
			delete(current, key)
			return nil
		}

		if next, ok := current[key].(map[string]interface{}); ok {
			current = next
		} else {
			return fmt.Errorf("path %s is not a map at key %s", path, key)
		}
	}

	return nil
}

// splitPath splits a dot-separated path into keys
func splitPath(path string) []string {
	return strings.Split(path, ".")
}

// setNodeConfigOwnership attempts to set file ownership to quilibrium:qtools
func setNodeConfigOwnership(path string) error {
	_, err := user.Lookup("quilibrium")
	if err != nil {
		return nil // User doesn't exist, skip
	}

	_, err = user.LookupGroup("qtools")
	if err != nil {
		return nil // Group doesn't exist, skip
	}

	// Ownership change would require os.Chown with appropriate permissions
	// For now, we'll skip this and let the caller handle it if needed
	return nil
}
