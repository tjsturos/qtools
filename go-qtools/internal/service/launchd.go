package service

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// LaunchdBackend implements ServiceBackend for macOS launchd
type LaunchdBackend struct{}

// NewLaunchdBackend creates a new launchd backend
func NewLaunchdBackend() *LaunchdBackend {
	return &LaunchdBackend{}
}

// StartService starts a launchd service
func (lb *LaunchdBackend) StartService(name string) error {
	cmd := exec.Command("launchctl", "start", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to start service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// StopService stops a launchd service
func (lb *LaunchdBackend) StopService(name string) error {
	cmd := exec.Command("launchctl", "stop", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to stop service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// RestartService restarts a launchd service
func (lb *LaunchdBackend) RestartService(name string) error {
	if err := lb.StopService(name); err != nil {
		return err
	}
	return lb.StartService(name)
}

// GetStatus gets the status of a launchd service
func (lb *LaunchdBackend) GetStatus(name string) (*ServiceStatus, error) {
	cmd := exec.Command("launchctl", "list", name)
	output, err := cmd.CombinedOutput()
	
	status := &ServiceStatus{
		Name: name,
	}

	if err != nil {
		// Service might not be loaded
		status.Active = false
		status.Running = false
		return status, nil
	}

	// Parse output to determine if service is running
	// launchctl list returns PID if running, or empty if not
	outputStr := string(output)
	if outputStr != "" && !strings.Contains(outputStr, "Could not find service") {
		status.Active = true
		status.Running = true
		status.StatusText = outputStr
	}

	return status, nil
}

// EnableService enables a launchd service (loads the plist)
func (lb *LaunchdBackend) EnableService(name string) error {
	plistPath := lb.getPlistPath(name)
	cmd := exec.Command("launchctl", "load", plistPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to enable service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// DisableService disables a launchd service (unloads the plist)
func (lb *LaunchdBackend) DisableService(name string) error {
	plistPath := lb.getPlistPath(name)
	cmd := exec.Command("launchctl", "unload", plistPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to disable service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// CreateServiceFile creates a launchd plist file
func (lb *LaunchdBackend) CreateServiceFile(name string, config *ServiceConfig) error {
	return lb.UpdateServiceFile(name, config)
}

// UpdateServiceFile updates a launchd plist file
func (lb *LaunchdBackend) UpdateServiceFile(name string, config *ServiceConfig) error {
	plistPath := lb.getPlistPath(name)

	content, err := GeneratePlist(config)
	if err != nil {
		return fmt.Errorf("failed to generate plist: %w", err)
	}

	// Ensure directory exists
	dir := filepath.Dir(plistPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create plist directory: %w", err)
	}

	// Write plist file
	if err := os.WriteFile(plistPath, content, 0644); err != nil {
		return fmt.Errorf("failed to write plist file: %w", err)
	}

	return nil
}

// getPlistPath gets the plist file path for a service
func (lb *LaunchdBackend) getPlistPath(name string) string {
	// Use user LaunchAgents directory
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, "Library", "LaunchAgents", fmt.Sprintf("com.quilibrium.%s.plist", name))
}
