package service

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
)

// SystemdBackend implements ServiceBackend for Linux systemd
type SystemdBackend struct{}

// NewSystemdBackend creates a new systemd backend
func NewSystemdBackend() *SystemdBackend {
	return &SystemdBackend{}
}

// StartService starts a systemd service
func (sb *SystemdBackend) StartService(name string) error {
	cmd := exec.Command("sudo", "systemctl", "start", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to start service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// StopService stops a systemd service
func (sb *SystemdBackend) StopService(name string) error {
	cmd := exec.Command("sudo", "systemctl", "stop", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to stop service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// RestartService restarts a systemd service
func (sb *SystemdBackend) RestartService(name string) error {
	cmd := exec.Command("sudo", "systemctl", "restart", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to restart service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// GetStatus gets the status of a systemd service
func (sb *SystemdBackend) GetStatus(name string) (*ServiceStatus, error) {
	cmd := exec.Command("systemctl", "is-active", name)
	activeOutput, _ := cmd.Output()
	active := strings.TrimSpace(string(activeOutput)) == "active"

	cmd = exec.Command("systemctl", "is-enabled", name)
	enabledOutput, _ := cmd.Output()
	enabled := strings.TrimSpace(string(enabledOutput)) == "enabled"

	cmd = exec.Command("systemctl", "show", name, "--property=MainPID,ActiveState,SubState")
	statusOutput, _ := cmd.Output()
	statusText := strings.TrimSpace(string(statusOutput))

	status := &ServiceStatus{
		Name:       name,
		Active:     active,
		Running:    active,
		Enabled:    enabled,
		StatusText: statusText,
	}

	return status, nil
}

// EnableService enables a systemd service
func (sb *SystemdBackend) EnableService(name string) error {
	cmd := exec.Command("sudo", "systemctl", "enable", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to enable service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// DisableService disables a systemd service
func (sb *SystemdBackend) DisableService(name string) error {
	cmd := exec.Command("sudo", "systemctl", "disable", name)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to disable service %s: %w\nOutput: %s", name, err, string(output))
	}
	return nil
}

// CreateServiceFile creates a systemd service file
func (sb *SystemdBackend) CreateServiceFile(name string, config *ServiceConfig) error {
	return sb.UpdateServiceFile(name, config)
}

// UpdateServiceFile updates a systemd service file
func (sb *SystemdBackend) UpdateServiceFile(name string, config *ServiceConfig) error {
	serviceFilePath := filepath.Join("/etc/systemd/system", name+".service")

	content, err := sb.generateSystemdServiceFile(config)
	if err != nil {
		return fmt.Errorf("failed to generate service file content: %w", err)
	}

	// Write to temp file first
	tmpFile := serviceFilePath + ".tmp"
	if err := os.WriteFile(tmpFile, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write temp service file: %w", err)
	}

	// Move to final location with sudo
	cmd := exec.Command("sudo", "mv", tmpFile, serviceFilePath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to move service file: %w", err)
	}

	// Reload systemd
	cmd = exec.Command("sudo", "systemctl", "daemon-reload")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to reload systemd: %w", err)
	}

	return nil
}

// generateSystemdServiceFile generates the systemd service file content
func (sb *SystemdBackend) generateSystemdServiceFile(config *ServiceConfig) (string, error) {
	opts := config.ServiceOptions
	if opts == nil {
		return "", fmt.Errorf("service options are required")
	}

	// Build ExecStart command
	execStart := sb.buildExecStart(config)
	execReload := fmt.Sprintf("/bin/kill -s SIGINT $MAINPID && %s", execStart)

	// Build environment variables
	envVars := sb.buildEnvironment(config)

	// Create template data
	type templateData struct {
		ServiceConfig
		ExecStart  string
		ExecReload string
		EnvVars    []string
	}

	data := templateData{
		ServiceConfig: *config,
		ExecStart:     execStart,
		ExecReload:    execReload,
		EnvVars:       envVars,
	}

	var tmpl *template.Template
	var err error

	if config.IsWorker {
		tmpl, err = template.New("worker").Parse(systemdWorkerServiceTemplate)
	} else {
		tmpl, err = template.New("master").Parse(systemdMasterServiceTemplate)
	}

	if err != nil {
		return "", err
	}

	var buf strings.Builder
	if err := tmpl.Execute(&buf, data); err != nil {
		return "", err
	}

	return buf.String(), nil
}

// buildExecStart builds the ExecStart command with flags
func (sb *SystemdBackend) buildExecStart(config *ServiceConfig) string {
	var parts []string
	parts = append(parts, config.BinaryPath)

	if config.ServiceOptions.Testnet {
		parts = append(parts, "--network=1")
	}
	if config.ServiceOptions.Debug {
		parts = append(parts, "--debug")
	}
	if config.ServiceOptions.SkipSignatureCheck {
		parts = append(parts, "--signature-check=false")
	}
	if config.IsWorker {
		parts = append(parts, "--core", "%i")
	}

	return strings.Join(parts, " ")
}

// buildEnvironment builds environment variables
func (sb *SystemdBackend) buildEnvironment(config *ServiceConfig) []string {
	var env []string
	opts := config.ServiceOptions

	if opts.IPFSDebug {
		env = append(env, "IPFS_LOGGING=debug")
	}
	if opts.GOGC != "" {
		env = append(env, fmt.Sprintf("GOGC=%s", opts.GOGC))
	}
	if opts.GOMEMLimit != "" {
		env = append(env, fmt.Sprintf("GOMEMLIMIT=%s", opts.GOMEMLimit))
	}

	return env
}

const systemdMasterServiceTemplate = `[Unit]
Description=Quilibrium Ceremony Client Service

[Service]
Type=simple
Restart=always
RestartSec={{.ServiceOptions.RestartTime}}
User={{.User}}
Group={{.Group}}
WorkingDirectory={{.WorkingDir}}
{{range .EnvVars}}
Environment={{.}}
{{end}}
ExecStart={{.ExecStart}}
ExecStop=/bin/kill -s SIGINT $MAINPID
ExecReload={{.ExecReload}}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStopSec=240

[Install]
WantedBy=multi-user.target
`

const systemdWorkerServiceTemplate = `[Unit]
Description=Quilibrium Worker Service %i
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory={{.WorkingDir}}
Restart=on-failure
RestartSec={{.ServiceOptions.WorkerRestartTime}}
StartLimitBurst=5
User={{.User}}
Group={{.Group}}
{{range .EnvVars}}
Environment={{.}}
{{end}}
{{if .ServiceOptions.EnableCPUScheduling}}
CPUSchedulingPolicy=rr
CPUSchedulingPriority={{.ServiceOptions.DataWorkerPriority}}
{{end}}
ExecStart={{.ExecStart}}
ExecStop=/bin/kill -s SIGINT $MAINPID
ExecReload={{.ExecReload}}
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStopSec=240

[Install]
WantedBy=multi-user.target
`
