package node

import (
	"fmt"
	"runtime"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// Mode represents the node operation mode
type Mode string

const (
	ModeManual     Mode = "manual"
	ModeAutomatic  Mode = "automatic"
	ModeClustering Mode = "clustering"
)

// DetectMode detects the current mode from config
func DetectMode(cfg *config.Config) Mode {
	if cfg == nil {
		return ModeManual // Default to manual mode
	}

	// Check clustering first
	if cfg.Service != nil && cfg.Service.Clustering != nil && cfg.Service.Clustering.Enabled {
		return ModeClustering
	}

	// Check manual mode (default to true if not explicitly set)
	if cfg.Manual != nil && cfg.Manual.Enabled {
		return ModeManual
	}

	// Default to manual mode (opinionated default for better reliability)
	return ModeManual
}

// IsManualMode checks if manual mode is enabled
func IsManualMode(cfg *config.Config) bool {
	return DetectMode(cfg) == ModeManual
}

// IsAutomaticMode checks if automatic mode is enabled
func IsAutomaticMode(cfg *config.Config) bool {
	return DetectMode(cfg) == ModeAutomatic
}

// IsClusteringEnabled checks if clustering is enabled
func IsClusteringEnabled(cfg *config.Config) bool {
	return DetectMode(cfg) == ModeClustering
}

// GetWorkerCount calculates worker count based on mode and config
func GetWorkerCount(cfg *config.Config) int {
	if cfg == nil {
		return calculateDefaultWorkerCount()
	}

	// In manual mode, use configured worker count or calculate default
	if IsManualMode(cfg) {
		if cfg.Manual != nil && cfg.Manual.WorkerCount > 0 {
			return cfg.Manual.WorkerCount
		}
		return calculateDefaultWorkerCount()
	}

	// In clustering mode, use local data worker count if set
	if IsClusteringEnabled(cfg) {
		if cfg.Service != nil && cfg.Service.Clustering != nil && cfg.Service.Clustering.LocalDataWorkerCount != nil {
			return *cfg.Service.Clustering.LocalDataWorkerCount
		}
	}

	// In automatic mode or default, return 0 (master spawns workers)
	return 0
}

// ToggleMode toggles between manual and automatic mode
func ToggleMode(cfg *config.Config) error {
	if cfg == nil {
		return fmt.Errorf("config is nil")
	}

	if cfg.Manual == nil {
		cfg.Manual = &config.ManualConfig{}
	}

	// Toggle manual mode
	cfg.Manual.Enabled = !cfg.Manual.Enabled

	// If enabling manual mode, calculate worker count if not set
	if cfg.Manual.Enabled && cfg.Manual.WorkerCount == 0 {
		cfg.Manual.WorkerCount = calculateDefaultWorkerCount()
	}

	return nil
}

// calculateDefaultWorkerCount calculates default worker count based on CPU cores
func calculateDefaultWorkerCount() int {
	cores := runtime.NumCPU()

	// Legacy calculation logic (matching bash script)
	if cores == 1 {
		return 1
	} else if cores <= 4 {
		return cores - 1
	} else if cores <= 16 {
		return cores - 2
	} else if cores <= 32 {
		return cores - 3
	} else if cores <= 64 {
		return cores - 4
	} else {
		return cores - 5
	}
}
