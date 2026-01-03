package service

import (
	"fmt"
	"runtime"
)

// Platform represents the operating system platform
type Platform string

const (
	PlatformLinux Platform = "linux"
	PlatformDarwin Platform = "darwin" // macOS
	PlatformUnknown Platform = "unknown"
)

// DetectPlatform detects the current platform
func DetectPlatform() Platform {
	switch runtime.GOOS {
	case "linux":
		return PlatformLinux
	case "darwin":
		return PlatformDarwin
	default:
		return PlatformUnknown
	}
}

// ServiceStatus represents the status of a service
type ServiceStatus struct {
	Name        string
	Active      bool
	Running     bool
	Enabled     bool
	PID         int
	StatusText  string
}

// ServiceBackend is the interface for platform-specific service management
type ServiceBackend interface {
	StartService(name string) error
	StopService(name string) error
	RestartService(name string) error
	GetStatus(name string) (*ServiceStatus, error)
	EnableService(name string) error
	DisableService(name string) error
	CreateServiceFile(name string, config *ServiceConfig) error
	UpdateServiceFile(name string, config *ServiceConfig) error
}

// ServiceConfig represents service configuration for file generation
type ServiceConfig struct {
	ServiceOptions *ServiceOptions
	ServiceName    string
	WorkingDir     string
	BinaryPath     string
	User           string
	Group          string
	IsWorker       bool
	WorkerIndex    int // For worker services
}

// GetServiceBackend returns the appropriate service backend for the platform
func GetServiceBackend() (ServiceBackend, error) {
	platform := DetectPlatform()

	switch platform {
	case PlatformLinux:
		return NewSystemdBackend(), nil
	case PlatformDarwin:
		return NewLaunchdBackend(), nil
	default:
		return nil, fmt.Errorf("unsupported platform: %s", platform)
	}
}
