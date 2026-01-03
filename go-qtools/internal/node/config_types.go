package node

// NodeConfig represents the Quilibrium node configuration structure
type NodeConfig struct {
	P2P     *P2PConfig     `yaml:"p2p,omitempty"`
	GRPC    *GRPCConfig    `yaml:"grpc,omitempty"`
	REST    *RESTConfig    `yaml:"rest,omitempty"`
	Engine  *EngineConfig  `yaml:"engine,omitempty"`
	Logger  *LoggerConfig  `yaml:"logger,omitempty"`
	Settings map[string]interface{} `yaml:"settings,omitempty"`
	Raw     map[string]interface{} `yaml:",inline"` // For dynamic access
}

// P2PConfig represents P2P network settings
type P2PConfig struct {
	ListenMultiaddr      string                 `yaml:"listenMultiaddr,omitempty"`
	StreamListenMultiaddr string                 `yaml:"streamListenMultiaddr,omitempty"`
	DirectPeers          []DirectPeer           `yaml:"directPeers,omitempty"`
	AnnounceMultiaddrs   []string                `yaml:"announceMultiaddrs,omitempty"`
	AdditionalSettings   map[string]interface{} `yaml:",inline"`
}

// DirectPeer represents a direct peer configuration
type DirectPeer struct {
	PeerID   string `yaml:"peerId"`
	Multiaddr string `yaml:"multiaddr"`
}

// GRPCConfig represents gRPC settings
type GRPCConfig struct {
	ListenMultiaddr string `yaml:"listenMultiaddr,omitempty"`
}

// RESTConfig represents REST API settings
type RESTConfig struct {
	ListenMultiaddr string `yaml:"listenMultiaddr,omitempty"`
}

// EngineConfig represents engine settings
type EngineConfig struct {
	DataWorkerMultiaddrs      []string                `yaml:"dataWorkerMultiaddrs,omitempty"`
	DataWorkerP2PMultiaddrs   []string                `yaml:"dataWorkerP2PMultiaddrs,omitempty"`
	DataWorkerStreamMultiaddrs []string               `yaml:"dataWorkerStreamMultiaddrs,omitempty"`
	DataWorkerBaseP2PPort     *int                    `yaml:"dataWorkerBaseP2PPort,omitempty"`
	DataWorkerBaseStreamPort  *int                    `yaml:"dataWorkerBaseStreamPort,omitempty"`
	MaxFrame                  *int                    `yaml:"maxFrame,omitempty"`
	SyncTimeout               *string                 `yaml:"syncTimeout,omitempty"`
	DynamicTarget             *bool                   `yaml:"dynamicTarget,omitempty"`
	RewardPeerID              *string                 `yaml:"rewardPeerId,omitempty"`
	AdditionalSettings        map[string]interface{} `yaml:",inline"`
}

// LoggerConfig represents logger settings
type LoggerConfig struct {
	Path      string `yaml:"path,omitempty"`
	MaxSize   int    `yaml:"maxSize,omitempty"`
	MaxBackups int   `yaml:"maxBackups,omitempty"`
	MaxAge    int    `yaml:"maxAge,omitempty"`
	Compress  bool   `yaml:"compress,omitempty"`
}

// LoggingOptions represents options for configuring logging
type LoggingOptions struct {
	Path      string
	MaxSize   int // in MB
	MaxBackups int
	MaxAge    int // in days
	Compress  bool
}

// DefaultLoggingOptions returns default logging options
func DefaultLoggingOptions() LoggingOptions {
	return LoggingOptions{
		Path:      ".logs",
		MaxSize:   50,
		MaxBackups: 5,
		MaxAge:    10,
		Compress:  true,
	}
}
