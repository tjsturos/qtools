package config

import (
	"os"
	"path/filepath"
)

// Default path constants
const (
	DefaultQtoolsPath     = "/home/quilibrium/qtools"
	DefaultNodePath       = "/home/quilibrium/node"
	DefaultClientPath     = "/home/quilibrium/client"
	DefaultConfigPath     = "/home/quilibrium/qtools/config.yml"
	DefaultNodeConfigPath = "/home/quilibrium/node/.config/config.yml"
)

// GetQtoolsPath returns the qtools installation path
// Checks QTOOLS_PATH environment variable first, then defaults to DefaultQtoolsPath
func GetQtoolsPath() string {
	if path := os.Getenv("QTOOLS_PATH"); path != "" {
		return path
	}
	return DefaultQtoolsPath
}

// GetNodePath returns the node installation path
// Checks QUIL_NODE_PATH environment variable first, then defaults to DefaultNodePath
func GetNodePath() string {
	if path := os.Getenv("QUIL_NODE_PATH"); path != "" {
		return path
	}
	return DefaultNodePath
}

// GetClientPath returns the client installation path
// Checks QUIL_CLIENT_PATH environment variable first, then defaults to DefaultClientPath
func GetClientPath() string {
	if path := os.Getenv("QUIL_CLIENT_PATH"); path != "" {
		return path
	}
	return DefaultClientPath
}

// GetConfigPath returns the qtools config file path
// Checks QTOOLS_CONFIG_FILE environment variable first, then defaults to DefaultConfigPath
func GetConfigPath() string {
	if path := os.Getenv("QTOOLS_CONFIG_FILE"); path != "" {
		return path
	}
	return DefaultConfigPath
}

// GetNodeConfigPath returns the node config file path
// Checks QUIL_CONFIG_FILE environment variable first, then defaults to DefaultNodeConfigPath
func GetNodeConfigPath() string {
	if path := os.Getenv("QUIL_CONFIG_FILE"); path != "" {
		return path
	}
	return DefaultNodeConfigPath
}

// EnsureDirectory ensures a directory exists, creating it if necessary
func EnsureDirectory(path string) error {
	return os.MkdirAll(path, 0755)
}

// EnsureConfigDirectory ensures the config directory exists
func EnsureConfigDirectory() error {
	configPath := GetConfigPath()
	dir := filepath.Dir(configPath)
	return EnsureDirectory(dir)
}

// EnsureNodeConfigDirectory ensures the node config directory exists
func EnsureNodeConfigDirectory() error {
	nodeConfigPath := GetNodeConfigPath()
	dir := filepath.Dir(nodeConfigPath)
	return EnsureDirectory(dir)
}
