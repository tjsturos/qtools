package config

// Config represents the root configuration structure
// Uses map[string]interface{} for flexibility while supporting structured access
type Config struct {
	// Raw config data for dynamic access
	Raw map[string]interface{} `yaml:",inline"`

	// Structured fields for common access
	User              string                 `yaml:"user"`
	QuilibriumRepoDir string                 `yaml:"quilibrium_repo_install_dir"`
	ReleaseVersion    string                 `yaml:"release_version"`
	CurrentNodeVersion string                `yaml:"current_node_version"`
	CurrentQClientVersion string             `yaml:"current_qclient_version"`
	OSArch            string                 `yaml:"os_arch"`
	QtoolsVersion     int                    `yaml:"qtools_version"`
	QClientCLIName    string                 `yaml:"qclient_cli_name"`
	SSH               *SSHConfig             `yaml:"ssh,omitempty"`
	Service           *ServiceConfig        `yaml:"service,omitempty"`
	DataWorkerService *DataWorkerServiceConfig `yaml:"data_worker_service,omitempty"`
	Manual            *ManualConfig         `yaml:"manual,omitempty"`
	ScheduledTasks    *ScheduledTasksConfig `yaml:"scheduled_tasks,omitempty"`
	Settings          *SettingsConfig       `yaml:"settings,omitempty"`
	Dev               *DevConfig            `yaml:"dev,omitempty"`
	NodeRegistry      *NodeRegistry         `yaml:"node_registry,omitempty"` // For desktop app integration
}

// SSHConfig represents SSH configuration
type SSHConfig struct {
	AllowFromIP      bool   `yaml:"allow_from_ip"`
	Port             int    `yaml:"port"`
	Skip192168Block  bool   `yaml:"skip_192_168_block"`
}

// ServiceConfig represents service configuration
type ServiceConfig struct {
	FileName          string              `yaml:"file_name"`
	Debug             bool                `yaml:"debug"`
	SignatureCheck    bool                `yaml:"signature_check"`
	Testnet           bool                `yaml:"testnet"`
	WorkingDir        string              `yaml:"working_dir"`
	LinkDirectory     string              `yaml:"link_directory"`
	LinkName          string              `yaml:"link_name"`
	DefaultUser       string              `yaml:"default_user"`
	QuilibriumNodePath string             `yaml:"quilibrium_node_path"`
	QuilibriumClientPath string           `yaml:"quilibrium_client_path"`
	RestartTime       string              `yaml:"restart_time"`
	WorkerService     *WorkerServiceConfig `yaml:"worker_service,omitempty"`
	Clustering        *ClusteringConfig   `yaml:"clustering,omitempty"`
	Args              string              `yaml:"args"`
	MaxThreads        interface{}         `yaml:"max_threads"` // Can be bool or int
}

// WorkerServiceConfig represents worker service configuration
type WorkerServiceConfig struct {
	GOGC        string `yaml:"gogc"`
	GOMEMLimit  string `yaml:"gomemlimit"`
	RestartTime string `yaml:"restart_time"`
}

// ClusteringConfig represents clustering configuration
type ClusteringConfig struct {
	Enabled              bool     `yaml:"enabled"`
	MasterServiceName    string   `yaml:"master_service_name"`
	LocalOnly            bool     `yaml:"local_only"`
	DataWorkerServiceName string  `yaml:"data_worker_service_name"`
	BasePort             int      `yaml:"base_port"`
	WorkerBaseP2PPort    int      `yaml:"worker_base_p2p_port"`
	WorkerBaseStreamPort int      `yaml:"worker_base_stream_port"`
	MasterStreamPort     int      `yaml:"master_stream_port"`
	DefaultSSHPort       int      `yaml:"default_ssh_port"`
	DefaultUser          string   `yaml:"default_user"`
	LocalDataWorkerCount *int     `yaml:"local_data_worker_count"`
	SSHKeyPath           string   `yaml:"ssh_key_path"`
	DataWorkerPriority   int      `yaml:"dataworker_priority"`
	SSHKeyName           string   `yaml:"ssh_key_name"`
	MainIP               string   `yaml:"main_ip"`
	Servers              []string `yaml:"servers"`
	AutoRemovedServers   []string `yaml:"auto_removed_servers"`
}

// DataWorkerServiceConfig represents data worker service configuration
type DataWorkerServiceConfig struct {
	WorkerCount int `yaml:"worker_count"`
	BasePort    int `yaml:"base_port"`
	BaseIndex   int `yaml:"base_index"`
}

// ManualConfig represents manual mode configuration
type ManualConfig struct {
	Enabled     bool `yaml:"enabled"`
	WorkerCount int  `yaml:"worker_count"`
	LocalOnly   bool `yaml:"local_only"`
}

// ScheduledTasksConfig represents scheduled tasks configuration
type ScheduledTasksConfig struct {
	Cluster      map[string]interface{} `yaml:"cluster,omitempty"`
	DirectPeers  map[string]interface{} `yaml:"direct_peers,omitempty"`
	Backup       map[string]interface{} `yaml:"backup,omitempty"`
	Updates      map[string]interface{} `yaml:"updates,omitempty"`
	Logs         map[string]interface{} `yaml:"logs,omitempty"`
	Statistics   map[string]interface{} `yaml:"statistics,omitempty"`
	Diagnostics  map[string]interface{} `yaml:"diagnostics,omitempty"`
	PublicIP     map[string]interface{} `yaml:"public_ip,omitempty"`
}

// SettingsConfig represents settings configuration
type SettingsConfig struct {
	UseAVX512        bool                   `yaml:"use_avx512"`
	PublishMultiaddr map[string]interface{} `yaml:"publish_multiaddr,omitempty"`
	CentralServer    map[string]interface{} `yaml:"central_server,omitempty"`
	ListenAddr       map[string]interface{} `yaml:"listenAddr,omitempty"`
	SourceRepository map[string]interface{} `yaml:"source_repository,omitempty"`
	Install          map[string]interface{} `yaml:"install,omitempty"`
	LogFile          string                 `yaml:"log_file"`
	Snapshots        map[string]interface{} `yaml:"snapshots,omitempty"`
	InternalIP       string                 `yaml:"internal_ip"`
}

// DevConfig represents development configuration
type DevConfig struct {
	DefaultRepoBranch string                 `yaml:"default_repo_branch"`
	DefaultRepoURL    string                 `yaml:"default_repo_url"`
	DefaultRepoPath   string                 `yaml:"default_repo_path"`
	RemoteBuild       map[string]interface{} `yaml:"remote_build,omitempty"`
}

// NodeRegistry represents a registry of nodes for desktop app integration
type NodeRegistry struct {
	Nodes []RegisteredNode `yaml:"nodes,omitempty"`
}

// RegisteredNode represents a registered node in the registry
type RegisteredNode struct {
	Name       string `yaml:"name"`
	Endpoint   string `yaml:"endpoint"`
	AuthToken  string `yaml:"auth_token"`
	PeerID     string `yaml:"peer_id,omitempty"`
	LastSeen   string `yaml:"last_seen,omitempty"`
}
