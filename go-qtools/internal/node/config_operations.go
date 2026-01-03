package node

import (
	"fmt"
	"net"
	"strconv"
	"strings"
)

// SetP2PListenMultiaddr sets the P2P listen multiaddr
func SetP2PListenMultiaddr(configPath string, multiaddr string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("p2p.listenMultiaddr", multiaddr)
}

// SetGRPCMultiaddr sets the gRPC listen multiaddr
func SetGRPCMultiaddr(configPath string, multiaddr string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("grpc.listenMultiaddr", multiaddr)
}

// SetRESTMultiaddr sets the REST listen multiaddr
func SetRESTMultiaddr(configPath string, multiaddr string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("rest.listenMultiaddr", multiaddr)
}

// SetStreamListenMultiaddr sets the P2P stream listen multiaddr
func SetStreamListenMultiaddr(configPath string, multiaddr string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("p2p.streamListenMultiaddr", multiaddr)
}

// SetDataWorkerMultiaddrs sets the data worker multiaddrs
func SetDataWorkerMultiaddrs(configPath string, multiaddrs []string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("engine.dataWorkerMultiaddrs", multiaddrs)
}

// SetDataWorkerP2PMultiaddrs sets the data worker P2P multiaddrs
func SetDataWorkerP2PMultiaddrs(configPath string, multiaddrs []string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("engine.dataWorkerP2PMultiaddrs", multiaddrs)
}

// SetDataWorkerStreamMultiaddrs sets the data worker stream multiaddrs
func SetDataWorkerStreamMultiaddrs(configPath string, multiaddrs []string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("engine.dataWorkerStreamMultiaddrs", multiaddrs)
}

// ClearDataWorkers clears all data worker arrays
func ClearDataWorkers(configPath string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}

	// Clear all three arrays
	if err := mgr.SetValue("engine.dataWorkerMultiaddrs", []string{}); err != nil {
		return err
	}
	if err := mgr.SetValue("engine.dataWorkerP2PMultiaddrs", []string{}); err != nil {
		return err
	}
	if err := mgr.SetValue("engine.dataWorkerStreamMultiaddrs", []string{}); err != nil {
		return err
	}

	return nil
}

// AddDirectPeer adds a direct peer to the config
func AddDirectPeer(configPath, peerID, multiaddr string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}

	// Get current direct peers
	var directPeers []map[string]interface{}
	if peers, err := mgr.GetValue("p2p.directPeers"); err == nil {
		if peersList, ok := peers.([]interface{}); ok {
			for _, p := range peersList {
				if peerMap, ok := p.(map[string]interface{}); ok {
					directPeers = append(directPeers, peerMap)
				}
			}
		}
	}

	// Check if peer already exists
	for _, peer := range directPeers {
		if pID, ok := peer["peerId"].(string); ok && pID == peerID {
			return fmt.Errorf("peer %s already exists", peerID)
		}
	}

	// Add new peer
	newPeer := map[string]interface{}{
		"peerId":    peerID,
		"multiaddr": multiaddr,
	}
	directPeers = append(directPeers, newPeer)

	return mgr.SetValue("p2p.directPeers", directPeers)
}

// RemoveDirectPeer removes a direct peer from the config
func RemoveDirectPeer(configPath, peerID string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}

	// Get current direct peers
	var directPeers []map[string]interface{}
	if peers, err := mgr.GetValue("p2p.directPeers"); err == nil {
		if peersList, ok := peers.([]interface{}); ok {
			for _, p := range peersList {
				if peerMap, ok := p.(map[string]interface{}); ok {
					directPeers = append(directPeers, peerMap)
				}
			}
		}
	}

	// Remove peer
	found := false
	var updatedPeers []map[string]interface{}
	for _, peer := range directPeers {
		if pID, ok := peer["peerId"].(string); ok && pID == peerID {
			found = true
			continue
		}
		updatedPeers = append(updatedPeers, peer)
	}

	if !found {
		return fmt.Errorf("peer %s not found", peerID)
	}

	return mgr.SetValue("p2p.directPeers", updatedPeers)
}

// SetEngineSetting sets an engine setting
func SetEngineSetting(configPath, key string, value interface{}) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.SetValue("engine."+key, value)
}

// GetEngineSetting gets an engine setting
func GetEngineSetting(configPath, key string) (interface{}, error) {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return nil, err
	}
	return mgr.GetValue("engine." + key)
}

// EnableCustomLogging enables custom logging with the specified options
func EnableCustomLogging(configPath string, opts LoggingOptions) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}

	loggerConfig := map[string]interface{}{
		"path":      opts.Path,
		"maxSize":   opts.MaxSize,
		"maxBackups": opts.MaxBackups,
		"maxAge":    opts.MaxAge,
		"compress":  opts.Compress,
	}

	return mgr.SetValue("logger", loggerConfig)
}

// DisableCustomLogging disables custom logging (reverts to stdout)
func DisableCustomLogging(configPath string) error {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return err
	}
	return mgr.DeleteValue("logger")
}

// GetLoggingConfig gets the logging configuration
func GetLoggingConfig(configPath string) (*LoggerConfig, error) {
	mgr, err := NewNodeConfigManager(configPath)
	if err != nil {
		return nil, err
	}

	logger, err := mgr.GetValue("logger")
	if err != nil {
		return nil, err // Logger not configured
	}

	loggerMap, ok := logger.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid logger config format")
	}

	config := &LoggerConfig{}

	if path, ok := loggerMap["path"].(string); ok {
		config.Path = path
	}
	if maxSize, ok := loggerMap["maxSize"].(int); ok {
		config.MaxSize = maxSize
	}
	if maxBackups, ok := loggerMap["maxBackups"].(int); ok {
		config.MaxBackups = maxBackups
	}
	if maxAge, ok := loggerMap["maxAge"].(int); ok {
		config.MaxAge = maxAge
	}
	if compress, ok := loggerMap["compress"].(bool); ok {
		config.Compress = compress
	}

	return config, nil
}

// BuildMultiaddr builds a multiaddr string from IP, port, and protocol
func BuildMultiaddr(ip string, port int, proto string) string {
	if ip == "" {
		ip = "0.0.0.0"
	}

	if proto == "udp" {
		return fmt.Sprintf("/ip4/%s/udp/%d/quic-v1", ip, port)
	}
	return fmt.Sprintf("/ip4/%s/tcp/%d", ip, port)
}

// ParseMultiaddr parses a multiaddr string and returns IP, port, and protocol
func ParseMultiaddr(multiaddr string) (ip string, port int, proto string, err error) {
	// Simple parser for /ip4/IP/tcp/PORT or /ip4/IP/udp/PORT/quic-v1
	parts := strings.Split(multiaddr, "/")
	
	if len(parts) < 4 {
		return "", 0, "", fmt.Errorf("invalid multiaddr format")
	}

	// Find IP (should be after /ip4/)
	ipIndex := -1
	for i, part := range parts {
		if part == "ip4" && i+1 < len(parts) {
			ip = parts[i+1]
			ipIndex = i + 1
			break
		}
	}

	if ip == "" {
		return "", 0, "", fmt.Errorf("could not parse IP from multiaddr")
	}

	// Find protocol and port
	for i := ipIndex + 1; i < len(parts); i++ {
		if parts[i] == "tcp" || parts[i] == "udp" {
			proto = parts[i]
			if i+1 < len(parts) {
				port, err = strconv.Atoi(parts[i+1])
				if err != nil {
					return "", 0, "", fmt.Errorf("could not parse port: %w", err)
				}
				return ip, port, proto, nil
			}
		}
	}

	return "", 0, "", fmt.Errorf("could not parse protocol and port from multiaddr")
}

// GetLocalIP gets the local IP address
func GetLocalIP() (string, error) {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "", err
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String(), nil
}
