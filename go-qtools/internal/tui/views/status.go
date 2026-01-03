package views

import (
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/service"
)

// StatusView represents the status view
type StatusView struct {
	config *config.Config
	status *service.Status
	err    error
}

// NewStatusView creates a new status view
func NewStatusView(cfg *config.Config) *StatusView {
	return &StatusView{
		config: cfg,
	}
}

// Init initializes the view
func (sv *StatusView) Init() tea.Cmd {
	return tea.Batch(
		sv.refreshStatus(),
		sv.autoRefresh(),
	)
}

// Update handles updates
func (sv *StatusView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "r":
			return sv, sv.refreshStatus()
		}

	case statusUpdateMsg:
		sv.status = msg.status
		sv.err = nil
		return sv, sv.autoRefresh()

	case statusErrorMsg:
		sv.err = msg.err
		return sv, sv.autoRefresh()
	}

	return sv, nil
}

// View renders the view
func (sv *StatusView) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("205")).
		MarginBottom(1)

	b.WriteString(titleStyle.Render("Service Status"))
	b.WriteString("\n\n")

	if sv.err != nil {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render(fmt.Sprintf("Error: %v", sv.err)))
		b.WriteString("\n\n")
	}

	if sv.status == nil {
		b.WriteString("Loading status...")
		return b.String()
	}

	// Master status
	b.WriteString("Master Service:\n")
	masterStatus := "Stopped"
	if sv.status.Master != nil && sv.status.Master.Running {
		masterStatus = lipgloss.NewStyle().Foreground(lipgloss.Color("46")).Render("Running")
	} else {
		masterStatus = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render("Stopped")
	}
	b.WriteString(fmt.Sprintf("  Status: %s\n", masterStatus))
	if sv.status.Master != nil {
		b.WriteString(fmt.Sprintf("  Enabled: %v\n", sv.status.Master.Enabled))
		if sv.status.Master.PID > 0 {
			b.WriteString(fmt.Sprintf("  PID: %d\n", sv.status.Master.PID))
		}
	}
	b.WriteString("\n")

	// Worker statuses
	if len(sv.status.Workers) > 0 {
		b.WriteString("Worker Services:\n")
		for i := 1; i <= len(sv.status.Workers); i++ {
			status := "Stopped"
			if workerStatus, ok := sv.status.Workers[i]; ok {
				if workerStatus.Running {
					status = lipgloss.NewStyle().Foreground(lipgloss.Color("46")).Render("Running")
				} else {
					status = lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render("Stopped")
				}
				b.WriteString(fmt.Sprintf("  Worker %d: %s", i, status))
				if workerStatus.PID > 0 {
					b.WriteString(fmt.Sprintf(" (PID: %d)", workerStatus.PID))
				}
				b.WriteString("\n")
			}
		}
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Press 'r' to refresh, Esc to go back"))

	return b.String()
}

// refreshStatus refreshes the status
func (sv *StatusView) refreshStatus() tea.Cmd {
	return func() tea.Msg {
		status, err := service.GetStatus(service.StatusOptions{}, sv.config)
		if err != nil {
			return statusErrorMsg{err: err}
		}
		return statusUpdateMsg{status: status}
	}
}

// autoRefresh sets up auto-refresh
func (sv *StatusView) autoRefresh() tea.Cmd {
	return tea.Tick(5*time.Second, func(time.Time) tea.Msg {
		status, err := service.GetStatus(service.StatusOptions{}, sv.config)
		if err != nil {
			return statusErrorMsg{err: err}
		}
		return statusUpdateMsg{status: status}
	})
}

type statusUpdateMsg struct {
	status *service.Status
}

type statusErrorMsg struct {
	err error
}
