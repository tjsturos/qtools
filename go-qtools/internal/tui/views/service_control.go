package views

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/service"
	"github.com/tjsturos/qtools/go-qtools/internal/tui/components"
)

// ServiceControlView represents the service control view
type ServiceControlView struct {
	config          *config.Config
	showAdvanced    bool
	coreInput       *components.CoreInput
	selectedAction  string // "start", "stop", "restart"
	status          *service.Status
	err             error
}

// NewServiceControlView creates a new service control view
func NewServiceControlView(cfg *config.Config) *ServiceControlView {
	return &ServiceControlView{
		config:         cfg,
		coreInput:      components.NewCoreInput(),
		selectedAction: "start",
	}
}

// Init initializes the view
func (sv *ServiceControlView) Init() tea.Cmd {
	return tea.Batch(
		sv.refreshStatus(),
		sv.coreInput.Init(),
	)
}

// Update handles updates
func (sv *ServiceControlView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "tab":
			sv.showAdvanced = !sv.showAdvanced
			return sv, nil

		case "s":
			if !sv.showAdvanced {
				return sv, sv.startAll()
			}
		case "x":
			if !sv.showAdvanced {
				return sv, sv.stopAll()
			}
		case "r":
			if !sv.showAdvanced {
				return sv, sv.restartAll()
			}

		case "esc":
			sv.showAdvanced = false
			return sv, nil
		}

	case serviceControlStatusUpdateMsg:
		sv.status = msg.status
		return sv, nil

	case serviceControlErrorMsg:
		sv.err = msg.err
		return sv, nil
	}

	// Update core input if advanced mode
	if sv.showAdvanced {
		updatedInput, cmd := sv.coreInput.Update(msg)
		sv.coreInput = updatedInput.(*components.CoreInput)
		cmds = append(cmds, cmd)
	}

	return sv, tea.Batch(cmds...)
}

// View renders the view
func (sv *ServiceControlView) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("205")).
		MarginBottom(1)

	buttonStyle := lipgloss.NewStyle().
		Padding(0, 2).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("205")).
		MarginRight(1)

	b.WriteString(titleStyle.Render("Service Control"))
	b.WriteString("\n\n")

	// Status display
	if sv.status != nil {
		b.WriteString(sv.renderStatus())
		b.WriteString("\n\n")
	}

	// Main actions
	if !sv.showAdvanced {
		b.WriteString("Main Actions:\n")
		b.WriteString(buttonStyle.Render("[S] Start All"))
		b.WriteString(buttonStyle.Render("[X] Stop All"))
		b.WriteString(buttonStyle.Render("[R] Restart All"))
		b.WriteString("\n\n")
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Press Tab for advanced controls"))
	} else {
		b.WriteString("Advanced Controls:\n\n")

		// Master only controls
		b.WriteString("Master Only:\n")
		b.WriteString(buttonStyle.Render("Start Master"))
		b.WriteString(buttonStyle.Render("Stop Master"))
		b.WriteString(buttonStyle.Render("Restart Master"))
		b.WriteString("\n\n")

		// Worker controls
		b.WriteString("Workers:\n")
		b.WriteString("Core numbers: ")
		b.WriteString(sv.coreInput.View())
		b.WriteString("\n")
		b.WriteString(buttonStyle.Render("Start Workers"))
		b.WriteString(buttonStyle.Render("Stop Workers"))
		b.WriteString(buttonStyle.Render("Restart Workers"))
		b.WriteString("\n\n")
	}

	if sv.err != nil {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render(fmt.Sprintf("Error: %v", sv.err)))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Tab to toggle advanced, Esc to go back"))

	return b.String()
}

// renderStatus renders the service status
func (sv *ServiceControlView) renderStatus() string {
	if sv.status == nil {
		return "Loading status..."
	}

	var b strings.Builder
	b.WriteString("Status:\n")

	// Master status
	masterStatus := "●"
	if sv.status.Master != nil && sv.status.Master.Running {
		masterStatus = lipgloss.NewStyle().Foreground(lipgloss.Color("46")).Render("●")
	} else {
		masterStatus = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render("●")
	}
	b.WriteString(fmt.Sprintf("  Master: %s\n", masterStatus))

	// Worker statuses
	if len(sv.status.Workers) > 0 {
		b.WriteString("  Workers:\n")
		for i := 1; i <= len(sv.status.Workers); i++ {
			status := "●"
			if workerStatus, ok := sv.status.Workers[i]; ok && workerStatus.Running {
				status = lipgloss.NewStyle().Foreground(lipgloss.Color("46")).Render("●")
			} else {
				status = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render("●")
			}
			b.WriteString(fmt.Sprintf("    Worker %d: %s\n", i, status))
		}
	}

	return b.String()
}

// refreshStatus refreshes the service status
func (sv *ServiceControlView) refreshStatus() tea.Cmd {
	return func() tea.Msg {
		status, err := service.GetStatus(service.StatusOptions{}, sv.config)
		if err != nil {
			return serviceControlErrorMsg{err: err}
		}
		return serviceControlStatusUpdateMsg{status: status}
	}
}

// startAll starts all services
func (sv *ServiceControlView) startAll() tea.Cmd {
	return func() tea.Msg {
		err := service.StartService(service.StartOptions{}, sv.config)
		if err != nil {
			return serviceControlErrorMsg{err: err}
		}
		return refreshStatusMsg{}
	}
}

// stopAll stops all services
func (sv *ServiceControlView) stopAll() tea.Cmd {
	return func() tea.Msg {
		err := service.StopService(service.StopOptions{}, sv.config)
		if err != nil {
			return serviceControlErrorMsg{err: err}
		}
		return refreshStatusMsg{}
	}
}

// restartAll restarts all services
func (sv *ServiceControlView) restartAll() tea.Cmd {
	return func() tea.Msg {
		err := service.RestartService(service.RestartOptions{}, sv.config)
		if err != nil {
			return serviceControlErrorMsg{err: err}
		}
		return refreshStatusMsg{}
	}
}

type serviceControlStatusUpdateMsg struct {
	status *service.Status
}

type serviceControlErrorMsg struct {
	err error
}

type refreshStatusMsg struct{}
