package service

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// ServiceOptions represents service configuration options
type ServiceOptions struct {
	Testnet              bool
	Debug                bool
	SkipSignatureCheck   bool
	IPFSDebug            bool
	RestartTime          string // e.g., "60s" or "5s"
	WorkerRestartTime    string // e.g., "5s"
	GOGC                 string // e.g., "100"
	GOMEMLimit           string // e.g., "8GiB"
	EnableCPUScheduling  bool
	DataWorkerPriority   int // Default 90
	EnableService        bool
	RestartService       bool
	MasterOnly           bool
}

// ParseServiceOptions parses command-line arguments into ServiceOptions
func ParseServiceOptions(args []string) (*ServiceOptions, error) {
	opts := &ServiceOptions{
		DataWorkerPriority: 90, // Default
	}

	i := 0
	for i < len(args) {
		arg := args[i]

		switch arg {
		case "--testnet":
			opts.Testnet = true
		case "--debug":
			opts.Debug = true
		case "--skip-sig-check", "--skip-signature-check":
			opts.SkipSignatureCheck = true
		case "--ipfs-debug":
			opts.IPFSDebug = true
		case "--restart-time":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--restart-time requires a value")
			}
			opts.RestartTime = normalizeRestartTime(args[i+1])
			i++
		case "--gogc":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--gogc requires a value")
			}
			opts.GOGC = args[i+1]
			i++
		case "--gomemlimit":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--gomemlimit requires a value")
			}
			opts.GOMEMLimit = args[i+1]
			i++
		case "--enable-cpu-scheduling":
			opts.EnableCPUScheduling = true
		case "--cpu-priority":
			if i+1 >= len(args) {
				return nil, fmt.Errorf("--cpu-priority requires a value")
			}
			priority, err := strconv.Atoi(args[i+1])
			if err != nil {
				return nil, fmt.Errorf("invalid cpu-priority value: %w", err)
			}
			opts.DataWorkerPriority = priority
			i++
		case "--enable":
			opts.EnableService = true
		case "--restart":
			opts.RestartService = true
		case "--master":
			opts.MasterOnly = true
		case "--signature-check=false":
			opts.SkipSignatureCheck = true
		default:
			if strings.HasPrefix(arg, "--signature-check=") {
				value := strings.TrimPrefix(arg, "--signature-check=")
				if value == "false" {
					opts.SkipSignatureCheck = true
				}
			} else {
				return nil, fmt.Errorf("unknown option: %s", arg)
			}
		}
		i++
	}

	return opts, nil
}

// LoadServiceOptionsFromConfig loads service options from config file
func LoadServiceOptionsFromConfig(cfg *config.Config) (*ServiceOptions, error) {
	if cfg == nil || cfg.Service == nil {
		return &ServiceOptions{
			RestartTime:        "60s",
			WorkerRestartTime:  "5s",
			DataWorkerPriority: 90,
		}, nil
	}

	opts := &ServiceOptions{
		Testnet:            cfg.Service.Testnet,
		Debug:              cfg.Service.Debug,
		SkipSignatureCheck: !cfg.Service.SignatureCheck,
		RestartTime:        normalizeRestartTime(cfg.Service.RestartTime),
		DataWorkerPriority: 90, // Default
	}

	// Set defaults if not set
	if opts.RestartTime == "" {
		opts.RestartTime = "60s"
	}

	// Load worker service options
	if cfg.Service.WorkerService != nil {
		opts.WorkerRestartTime = normalizeRestartTime(cfg.Service.WorkerService.RestartTime)
		opts.GOGC = cfg.Service.WorkerService.GOGC
		opts.GOMEMLimit = cfg.Service.WorkerService.GOMEMLimit
	}

	if opts.WorkerRestartTime == "" {
		opts.WorkerRestartTime = opts.RestartTime
		if opts.WorkerRestartTime == "" {
			opts.WorkerRestartTime = "5s"
		}
	}

	// Load clustering options for CPU scheduling
	if cfg.Service.Clustering != nil {
		opts.DataWorkerPriority = cfg.Service.Clustering.DataWorkerPriority
		if opts.DataWorkerPriority == 0 {
			opts.DataWorkerPriority = 90
		}
	}

	return opts, nil
}

// ApplyServiceOptions saves options to config
func ApplyServiceOptions(opts *ServiceOptions, cfg *config.Config) error {
	if cfg.Service == nil {
		cfg.Service = &config.ServiceConfig{}
	}

	cfg.Service.Testnet = opts.Testnet
	cfg.Service.Debug = opts.Debug
	cfg.Service.SignatureCheck = !opts.SkipSignatureCheck

	if opts.RestartTime != "" {
		cfg.Service.RestartTime = opts.RestartTime
	}

	if cfg.Service.WorkerService == nil {
		cfg.Service.WorkerService = &config.WorkerServiceConfig{}
	}

	if opts.WorkerRestartTime != "" {
		cfg.Service.WorkerService.RestartTime = opts.WorkerRestartTime
	}
	if opts.GOGC != "" {
		cfg.Service.WorkerService.GOGC = opts.GOGC
	}
	if opts.GOMEMLimit != "" {
		cfg.Service.WorkerService.GOMEMLimit = opts.GOMEMLimit
	}

	if cfg.Service.Clustering == nil {
		cfg.Service.Clustering = &config.ClusteringConfig{}
	}
	cfg.Service.Clustering.DataWorkerPriority = opts.DataWorkerPriority

	return nil
}

// normalizeRestartTime normalizes restart time to "<int>s" format
func normalizeRestartTime(timeStr string) string {
	if timeStr == "" {
		return ""
	}

	// Remove trailing 's' if present for parsing
	timeStr = strings.TrimSpace(timeStr)
	if strings.HasSuffix(timeStr, "s") {
		timeStr = strings.TrimSuffix(timeStr, "s")
	}

	// Validate it's a number
	if _, err := strconv.Atoi(timeStr); err != nil {
		return "" // Invalid, return empty
	}

	return timeStr + "s"
}
