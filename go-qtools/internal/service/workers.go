package service

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/node"
)

// StartWorkers starts all workers
func StartWorkers(count int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	for i := 1; i <= count; i++ {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, i)
		if err := backend.StartService(workerName); err != nil {
			return fmt.Errorf("failed to start worker %d: %w", i, err)
		}
	}
	return nil
}

// StartWorker starts a specific worker by core index
func StartWorker(coreIndex int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	workerName := fmt.Sprintf("%s-worker@%d", serviceName, coreIndex)
	return backend.StartService(workerName)
}

// StartWorkersByCores starts specific workers by core numbers
func StartWorkersByCores(coreNumbers []int, cfg *config.Config) error {
	for _, coreNum := range coreNumbers {
		if err := StartWorker(coreNum, cfg); err != nil {
			return fmt.Errorf("failed to start worker %d: %w", coreNum, err)
		}
	}
	return nil
}

// StopWorkers stops all workers
func StopWorkers(count int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	for i := 1; i <= count; i++ {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, i)
		if err := backend.StopService(workerName); err != nil {
			return fmt.Errorf("failed to stop worker %d: %w", i, err)
		}
	}
	return nil
}

// StopWorker stops a specific worker by core index
func StopWorker(coreIndex int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	workerName := fmt.Sprintf("%s-worker@%d", serviceName, coreIndex)
	return backend.StopService(workerName)
}

// StopWorkersByCores stops specific workers by core numbers
func StopWorkersByCores(coreNumbers []int, cfg *config.Config) error {
	for _, coreNum := range coreNumbers {
		if err := StopWorker(coreNum, cfg); err != nil {
			return fmt.Errorf("failed to stop worker %d: %w", coreNum, err)
		}
	}
	return nil
}

// RestartWorkers restarts all workers
func RestartWorkers(count int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	for i := 1; i <= count; i++ {
		workerName := fmt.Sprintf("%s-worker@%d", serviceName, i)
		if err := backend.RestartService(workerName); err != nil {
			return fmt.Errorf("failed to restart worker %d: %w", i, err)
		}
	}
	return nil
}

// RestartWorker restarts a specific worker by core index
func RestartWorker(coreIndex int, cfg *config.Config) error {
	backend, err := GetServiceBackend()
	if err != nil {
		return err
	}

	serviceName := getServiceName(cfg)
	workerName := fmt.Sprintf("%s-worker@%d", serviceName, coreIndex)
	return backend.RestartService(workerName)
}

// RestartWorkersByCores restarts specific workers by core numbers
func RestartWorkersByCores(coreNumbers []int, cfg *config.Config) error {
	for _, coreNum := range coreNumbers {
		if err := RestartWorker(coreNum, cfg); err != nil {
			return fmt.Errorf("failed to restart worker %d: %w", coreNum, err)
		}
	}
	return nil
}

// ParseCoreNumbers parses core number input into a slice of integers
// Supports: "5", "1-4", "1,3,5", "1-3,5,7-9"
func ParseCoreNumbers(input string) ([]int, error) {
	if input == "" {
		return nil, fmt.Errorf("empty core numbers input")
	}

	var cores []int
	parts := strings.Split(input, ",")

	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}

		// Check if it's a range
		if strings.Contains(part, "-") {
			rangeParts := strings.Split(part, "-")
			if len(rangeParts) != 2 {
				return nil, fmt.Errorf("invalid range format: %s", part)
			}

			start, err := strconv.Atoi(strings.TrimSpace(rangeParts[0]))
			if err != nil {
				return nil, fmt.Errorf("invalid start of range: %s", rangeParts[0])
			}

			end, err := strconv.Atoi(strings.TrimSpace(rangeParts[1]))
			if err != nil {
				return nil, fmt.Errorf("invalid end of range: %s", rangeParts[1])
			}

			if start > end {
				return nil, fmt.Errorf("range start (%d) must be <= end (%d)", start, end)
			}

			for i := start; i <= end; i++ {
				cores = append(cores, i)
			}
		} else {
			// Single number
			num, err := strconv.Atoi(part)
			if err != nil {
				return nil, fmt.Errorf("invalid core number: %s", part)
			}
			cores = append(cores, num)
		}
	}

	// Remove duplicates and sort
	seen := make(map[int]bool)
	var uniqueCores []int
	for _, core := range cores {
		if !seen[core] {
			seen[core] = true
			uniqueCores = append(uniqueCores, core)
		}
	}

	// Sort
	sort.Ints(uniqueCores)

	return uniqueCores, nil
}

// GetWorkerStatus gets the status of a specific worker
func GetWorkerStatus(workerIndex int, cfg *config.Config) (*ServiceStatus, error) {
	backend, err := GetServiceBackend()
	if err != nil {
		return nil, err
	}

	serviceName := getServiceName(cfg)
	workerName := fmt.Sprintf("%s-worker@%d", serviceName, workerIndex)
	return backend.GetStatus(workerName)
}

// GetAllWorkerStatus gets the status of all workers
func GetAllWorkerStatus(cfg *config.Config) (map[int]*ServiceStatus, error) {
	workerCount := node.GetWorkerCount(cfg)
	statuses := make(map[int]*ServiceStatus)

	for i := 1; i <= workerCount; i++ {
		status, err := GetWorkerStatus(i, cfg)
		if err == nil {
			statuses[i] = status
		}
	}

	return statuses, nil
}
