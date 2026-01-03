package client

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/node"
)

// NodeClient provides a client interface for interacting with Quilibrium nodes
// Supports both binary commands and gRPC (when available)
type NodeClient struct {
	binaryPath string
	configPath string
	config     *config.Config
	grpcAddr   string // e.g., "localhost:8337"
}

// NewNodeClient creates a new node client
func NewNodeClient(cfg *config.Config) *NodeClient {
	binaryPath := "/usr/local/bin/node"
	if cfg != nil && cfg.Service != nil && cfg.Service.LinkName != "" {
		binaryPath = cfg.Service.LinkName
	}

	configPath := config.GetNodeConfigPath()
	grpcAddr := "localhost:8337"

	return &NodeClient{
		binaryPath: binaryPath,
		configPath: configPath,
		config:     cfg,
		grpcAddr:   grpcAddr,
	}
}

// NodeInfo represents comprehensive node information
type NodeInfo struct {
	PeerID      string
	Version     string
	Seniority   string
	Balance     string
	WorkerCount int
	Network     string // "mainnet" or "testnet"
}

// PeerInfo represents peer information from gRPC
type PeerInfo struct {
	PeerID    string
	Address   string
	Connected bool
	Latency   int64 // milliseconds
}

// GetNodeInfo gets node information using the node binary command
// This works even when the node service is not running
func (nc *NodeClient) GetNodeInfo() (*NodeInfo, error) {
	info, err := node.GetNodeInfo(nc.config)
	if err != nil {
		return nil, fmt.Errorf("failed to get node info: %w", err)
	}

	nodeInfo := &NodeInfo{
		PeerID:      info.PeerID,
		Version:     info.Version,
		Seniority:   info.Seniority,
		Balance:     info.Balance,
		WorkerCount: info.WorkerCount,
	}

	// Determine network
	if nc.config != nil && nc.config.Service != nil && nc.config.Service.Testnet {
		nodeInfo.Network = "testnet"
	} else {
		nodeInfo.Network = "mainnet"
	}

	return nodeInfo, nil
}

// GetPeerID gets the peer ID using the node binary command
func (nc *NodeClient) GetPeerID() (string, error) {
	return node.GetPeerID(nc.config)
}

// GetPeerInfoViaGRPC gets peer information via gRPC (when node is running)
// This is a stub implementation - would use actual gRPC client in production
func (nc *NodeClient) GetPeerInfoViaGRPC() (*PeerInfo, error) {
	// Stub: Would use grpcurl or gRPC client library
	// Reference: scripts/grpc/peer-info.sh uses `grpcurl -plaintext localhost:8337`
	
	// For now, try to use grpcurl if available
	cmd := exec.Command("grpcurl", "-plaintext", nc.grpcAddr, 
		"quilibrium.node.node.pb.NodeService.GetPeerInfo")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("gRPC call failed (node may not be running): %w", err)
	}

	// Parse output (simplified - would use proper protobuf parsing in production)
	peerInfo := &PeerInfo{
		Address: nc.grpcAddr,
	}

	// Try to extract peer ID from output
	outputStr := string(output)
	if strings.Contains(outputStr, "peerId") {
		// Extract peer ID using regex
		re := regexp.MustCompile(`"peerId"\s*:\s*"([^"]+)"`)
		matches := re.FindStringSubmatch(outputStr)
		if len(matches) > 1 {
			peerInfo.PeerID = matches[1]
		}
	}

	peerInfo.Connected = peerInfo.PeerID != ""

	return peerInfo, nil
}

// GetNodeInfoViaGRPC gets node information via gRPC (when node is running)
func (nc *NodeClient) GetNodeInfoViaGRPC() (*NodeInfo, error) {
	// Stub: Would use grpcurl or gRPC client library
	cmd := exec.Command("grpcurl", "-plaintext", nc.grpcAddr,
		"quilibrium.node.node.pb.NodeService.GetNodeInfo")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("gRPC call failed (node may not be running): %w", err)
	}

	// Parse output (simplified - would use proper protobuf parsing in production)
	nodeInfo := &NodeInfo{}

	outputStr := string(output)
	
	// Extract fields using regex patterns
	if peerIDMatch := regexp.MustCompile(`"peerId"\s*:\s*"([^"]+)"`).FindStringSubmatch(outputStr); len(peerIDMatch) > 1 {
		nodeInfo.PeerID = peerIDMatch[1]
	}
	
	if versionMatch := regexp.MustCompile(`"version"\s*:\s*"([^"]+)"`).FindStringSubmatch(outputStr); len(versionMatch) > 1 {
		nodeInfo.Version = versionMatch[1]
	}

	// Determine network
	if nc.config != nil && nc.config.Service != nil && nc.config.Service.Testnet {
		nodeInfo.Network = "testnet"
	} else {
		nodeInfo.Network = "mainnet"
	}

	return nodeInfo, nil
}

// GetWorkerCount gets the worker count from node info
func (nc *NodeClient) GetWorkerCount() (int, error) {
	info, err := nc.GetNodeInfo()
	if err != nil {
		return 0, err
	}
	return info.WorkerCount, nil
}

// GetBalance gets the balance from node info
func (nc *NodeClient) GetBalance() (string, error) {
	info, err := nc.GetNodeInfo()
	if err != nil {
		return "", err
	}
	return info.Balance, nil
}

// GetSeniority gets the seniority from node info
func (nc *NodeClient) GetSeniority() (string, error) {
	info, err := nc.GetNodeInfo()
	if err != nil {
		return "", err
	}
	return info.Seniority, nil
}

// IsNodeRunning checks if the node is running by attempting a gRPC call
func (nc *NodeClient) IsNodeRunning() bool {
	_, err := nc.GetPeerInfoViaGRPC()
	return err == nil
}

// GetNodeInfoHybrid gets node info using the best available method
// Tries gRPC first (real-time), falls back to binary command (static)
func (nc *NodeClient) GetNodeInfoHybrid() (*NodeInfo, error) {
	// Try gRPC first for real-time data
	if info, err := nc.GetNodeInfoViaGRPC(); err == nil {
		return info, nil
	}

	// Fall back to binary command
	return nc.GetNodeInfo()
}

// RegisterNode registers this node with the desktop app registry
// Authentication will use public/private key encryption via Quilibrium Messaging layer
func (nc *NodeClient) RegisterNode(name string, endpoint string) error {
	// Stub: Would register node via Quilibrium Messaging with public/private key authentication
	// For now, this is a placeholder
	return fmt.Errorf("node registration not yet implemented - requires Quilibrium Messaging integration")
}

// UnregisterNode unregisters this node from the desktop app registry
func (nc *NodeClient) UnregisterNode(name string) error {
	// Stub: Would unregister node via Quilibrium Messaging
	return fmt.Errorf("node unregistration not yet implemented - requires Quilibrium Messaging integration")
}

// ListRegisteredNodes lists all registered nodes
func (nc *NodeClient) ListRegisteredNodes() ([]RegisteredNode, error) {
	// Stub: Would list nodes from registry via Quilibrium Messaging
	return nil, fmt.Errorf("node listing not yet implemented - requires Quilibrium Messaging integration")
}

// RegisteredNode represents a registered node in the desktop app registry
// Authentication uses public/private key encryption via Quilibrium Messaging layer
type RegisteredNode struct {
	Name     string
	Endpoint string
	PeerID   string
	// Public key will be used for authentication (stored/retrieved via Quilibrium Messaging)
	PublicKey string
	LastSeen  string
}
