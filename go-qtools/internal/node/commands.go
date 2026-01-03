package node

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// ExecuteNodeCommand executes the node binary with the given arguments
func ExecuteNodeCommand(args []string, cfg *config.Config) ([]byte, error) {
	// Get node binary path
	nodePath := "/usr/local/bin/node"
	if cfg != nil && cfg.Service != nil && cfg.Service.LinkName != "" {
		nodePath = cfg.Service.LinkName
	}

	// Build command with flags from config
	cmdArgs := []string{}

	// Add signature check flag
	if cfg != nil && cfg.Service != nil && !cfg.Service.SignatureCheck {
		cmdArgs = append(cmdArgs, "--signature-check=false")
	}

	// Add testnet flag
	if cfg != nil && cfg.Service != nil && cfg.Service.Testnet {
		cmdArgs = append(cmdArgs, "--network=1")
	}

	// Add debug flag
	if cfg != nil && cfg.Service != nil && cfg.Service.Debug {
		cmdArgs = append(cmdArgs, "--debug")
	}

	// Add config path
	configPath := config.GetNodeConfigPath()
	cmdArgs = append(cmdArgs, "--config", configPath)

	// Add user-provided arguments
	cmdArgs = append(cmdArgs, args...)

	// Execute command
	cmd := exec.Command(nodePath, cmdArgs...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("node command failed: %w", err)
	}

	return output, nil
}

// NodeInfo represents node information
type NodeInfo struct {
	PeerID      string
	Version     string
	Seniority   string
	Balance     string
	WorkerCount int
}

// GetNodeInfo gets node information by running node --node-info
func GetNodeInfo(cfg *config.Config) (*NodeInfo, error) {
	output, err := ExecuteNodeCommand([]string{"--node-info"}, cfg)
	if err != nil {
		return nil, err
	}

	// Parse output (similar to bash scripts)
	info := &NodeInfo{}
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Parse different fields from output
		// This is a simplified parser - actual implementation should match bash script parsing
		if strings.HasPrefix(line, "Peer ID:") {
			info.PeerID = strings.TrimSpace(strings.TrimPrefix(line, "Peer ID:"))
		} else if strings.HasPrefix(line, "Version:") {
			info.Version = strings.TrimSpace(strings.TrimPrefix(line, "Version:"))
		} else if strings.HasPrefix(line, "Seniority:") {
			info.Seniority = strings.TrimSpace(strings.TrimPrefix(line, "Seniority:"))
		} else if strings.HasPrefix(line, "Balance:") {
			info.Balance = strings.TrimSpace(strings.TrimPrefix(line, "Balance:"))
		}
	}

	return info, nil
}

// GetPeerID gets the peer ID by running node --peer-id
func GetPeerID(cfg *config.Config) (string, error) {
	output, err := ExecuteNodeCommand([]string{"--peer-id"}, cfg)
	if err != nil {
		return "", err
	}

	// Parse peer ID from output
	peerID := strings.TrimSpace(string(output))
	return peerID, nil
}
