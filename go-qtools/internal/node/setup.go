package node

import (
	"fmt"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// SetupOptions represents options for node setup
type SetupOptions struct {
	AutomaticMode bool
	WorkerCount   int
	PeerID        string
	ListenPort    int
	StreamPort    int
	BaseP2PPort   int
	BaseStreamPort int
}

// SetupNode sets up the node with the given options
// Defaults to manual mode (opinionated default for better reliability)
func SetupNode(opts SetupOptions, cfg *config.Config) error {
	if cfg == nil {
		return fmt.Errorf("config is nil")
	}

	// Default to manual mode unless explicitly requested
	if opts.AutomaticMode {
		return SetupAutomaticMode(cfg)
	}

	// Setup manual mode (default)
	workerCount := opts.WorkerCount
	if workerCount == 0 {
		workerCount = GetWorkerCount(cfg)
	}

	return SetupManualMode(cfg, workerCount, opts)
}

// SetupManualMode sets up manual mode (default, more reliable)
func SetupManualMode(cfg *config.Config, workerCount int, opts SetupOptions) error {
	if cfg.Manual == nil {
		cfg.Manual = &config.ManualConfig{}
	}

	cfg.Manual.Enabled = true
	cfg.Manual.WorkerCount = workerCount
	cfg.Manual.LocalOnly = true

	// Get node config path
	nodeConfigPath := config.GetNodeConfigPath()
	mgr, err := NewNodeConfigManager(nodeConfigPath)
	if err != nil {
		return fmt.Errorf("failed to create node config manager: %w", err)
	}

	// Get local IP
	localIP, err := GetLocalIP()
	if err != nil {
		localIP = "0.0.0.0" // Fallback
	}

	// Get base ports from config or use defaults
	baseP2P := opts.BaseP2PPort
	if baseP2P == 0 {
		if cfg.Service != nil && cfg.Service.Clustering != nil {
			baseP2P = cfg.Service.Clustering.WorkerBaseP2PPort
		}
		if baseP2P == 0 {
			baseP2P = 50000 // Default
		}
	}

	baseStream := opts.BaseStreamPort
	if baseStream == 0 {
		if cfg.Service != nil && cfg.Service.Clustering != nil {
			baseStream = cfg.Service.Clustering.WorkerBaseStreamPort
		}
		if baseStream == 0 {
			baseStream = 60000 // Default
		}
	}

	// Set base ports in node config
	if err := mgr.SetValue("engine.dataWorkerBaseP2PPort", baseP2P); err != nil {
		return fmt.Errorf("failed to set base P2P port: %w", err)
	}
	if err := mgr.SetValue("engine.dataWorkerBaseStreamPort", baseStream); err != nil {
		return fmt.Errorf("failed to set base stream port: %w", err)
	}

	// Clear existing arrays
	if err := ClearDataWorkers(nodeConfigPath); err != nil {
		return fmt.Errorf("failed to clear data workers: %w", err)
	}

	// Populate worker arrays
	var p2pMultiaddrs []string
	var streamMultiaddrs []string

	for i := 0; i < workerCount; i++ {
		p2pPort := baseP2P + i
		streamPort := baseStream + i
		p2pMultiaddrs = append(p2pMultiaddrs, BuildMultiaddr(localIP, p2pPort, "tcp"))
		streamMultiaddrs = append(streamMultiaddrs, BuildMultiaddr(localIP, streamPort, "tcp"))
	}

	if err := SetDataWorkerP2PMultiaddrs(nodeConfigPath, p2pMultiaddrs); err != nil {
		return fmt.Errorf("failed to set P2P multiaddrs: %w", err)
	}
	if err := SetDataWorkerStreamMultiaddrs(nodeConfigPath, streamMultiaddrs); err != nil {
		return fmt.Errorf("failed to set stream multiaddrs: %w", err)
	}

	return nil
}

// SetupAutomaticMode sets up automatic mode (optional, less reliable)
func SetupAutomaticMode(cfg *config.Config) error {
	if cfg.Manual == nil {
		cfg.Manual = &config.ManualConfig{}
	}

	cfg.Manual.Enabled = false
	cfg.Manual.WorkerCount = 0

	// Clear worker arrays in node config
	nodeConfigPath := config.GetNodeConfigPath()
	if err := ClearDataWorkers(nodeConfigPath); err != nil {
		return fmt.Errorf("failed to clear data workers: %w", err)
	}

	return nil
}
