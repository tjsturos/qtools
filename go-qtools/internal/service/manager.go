package service

import (
	"fmt"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/node"
)

// StartOptions represents options for starting services
type StartOptions struct {
	MasterOnly bool
	CoreIndex   int
	Cores       string // e.g., "1-4,6,8"
}

// StopOptions represents options for stopping services
type StopOptions struct {
	MasterOnly bool
	CoreIndex   int
	Cores       string
	Kill        bool
}

// RestartOptions represents options for restarting services
type RestartOptions struct {
	MasterOnly bool
	CoreIndex   int
	Cores       string
	Wait        bool
}

// StatusOptions represents options for getting service status
type StatusOptions struct {
	WorkerIndex int
}

// StartService starts the service(s) based on options
func StartService(opts StartOptions, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)

	if opts.MasterOnly {
		return backend.StartService(serviceName)
	}

	if opts.CoreIndex > 0 {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, opts.CoreIndex)
		return backend.StartService(workerName)
	}

	if opts.Cores != "" {
		cores, err := ParseCoreNumbers(opts.Cores)
		if err != nil {
			return err
		}
		return StartWorkersByCores(cores, cfg)
	}

	// Start all (master + workers in manual mode)
	if node.IsManualMode(cfg) {
		// Start master
		if err := backend.StartService(serviceName); err != nil {
			return fmt.Errorf("failed to start master: %w", err)
		}

		// Start all workers
		workerCount := node.GetWorkerCount(cfg)
		return StartWorkers(workerCount, cfg)
	}

	// Automatic mode - just start master
	return backend.StartService(serviceName)
}

// StopService stops the service(s) based on options
func StopService(opts StopOptions, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)

	if opts.MasterOnly {
		return backend.StopService(serviceName)
	}

	if opts.CoreIndex > 0 {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, opts.CoreIndex)
		return backend.StopService(workerName)
	}

	if opts.Cores != "" {
		cores, err := ParseCoreNumbers(opts.Cores)
		if err != nil {
			return err
		}
		return StopWorkersByCores(cores, cfg)
	}

	// Stop all (master + workers in manual mode)
	if node.IsManualMode(cfg) {
		// Stop all workers first
		workerCount := node.GetWorkerCount(cfg)
		if err := StopWorkers(workerCount, cfg); err != nil {
			return fmt.Errorf("failed to stop workers: %w", err)
		}

		// Stop master
		return backend.StopService(serviceName)
	}

	// Automatic mode - just stop master
	return backend.StopService(serviceName)
}

// RestartService restarts the service(s) based on options
func RestartService(opts RestartOptions, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)

	if opts.MasterOnly {
		return backend.RestartService(serviceName)
	}

	if opts.CoreIndex > 0 {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, opts.CoreIndex)
		return backend.RestartService(workerName)
	}

	if opts.Cores != "" {
		cores, err := ParseCoreNumbers(opts.Cores)
		if err != nil {
			return err
		}
		return RestartWorkersByCores(cores, cfg)
	}

	// Restart all (master + workers in manual mode)
	if node.IsManualMode(cfg) {
		// Restart all workers first
		workerCount := node.GetWorkerCount(cfg)
		if err := RestartWorkers(workerCount, cfg); err != nil {
			return fmt.Errorf("failed to restart workers: %w", err)
		}

		// Restart master
		return backend.RestartService(serviceName)
	}

	// Automatic mode - just restart master
	return backend.RestartService(serviceName)
}

// GetStatus gets the status of services
func GetStatus(opts StatusOptions, cfg *config.Config) (*Status, error) {
	backend, err := GetServiceBackend()
	if err != nil {
		return nil, err
	}

	serviceName := getServiceName(cfg)
	status := &Status{
		Master: &ServiceStatus{},
		Workers: make(map[int]*ServiceStatus),
	}

	// Get master status
	masterStatus, err := backend.GetStatus(serviceName)
	if err == nil {
		status.Master = masterStatus
	}

	// Get worker statuses
	if node.IsManualMode(cfg) {
		workerCount := node.GetWorkerCount(cfg)
		for i := 1; i <= workerCount; i++ {
			if opts.WorkerIndex > 0 && opts.WorkerIndex != i {
				continue
			}
			workerName := fmt.Sprintf("%s-worker@%d", serviceName, i)
			workerStatus, err := backend.GetStatus(workerName)
			if err == nil {
				status.Workers[i] = workerStatus
			}
		}
	}

	return status, nil
}

// Status represents the status of master and workers
type Status struct {
	Master  *ServiceStatus
	Workers map[int]*ServiceStatus
}

// getServiceName gets the service name from config
func getServiceName(cfg *config.Config) string {
	if cfg != nil && cfg.Service != nil && cfg.Service.FileName != "" {
		return cfg.Service.FileName
	}
	return "ceremonyclient"
}

// CreateServiceFile creates a service file
func CreateServiceFile(name string, config *ServiceConfig) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}
	return backend.CreateServiceFile(name, config)
}

// UpdateServiceFile updates a service file
func UpdateServiceFile(name string, config *ServiceConfig) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}
	return backend.UpdateServiceFile(name, config)
}
