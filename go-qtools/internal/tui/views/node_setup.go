package views

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/node"
)

// NodeSetupView represents the node setup view
type NodeSetupView struct {
	config      *config.Config
	mode        string // "manual" or "automatic"
	workerCount int
	focused     string
	err         error
}

// NewNodeSetupView creates a new node setup view
func NewNodeSetupView(cfg *config.Config) *NodeSetupView {
	mode := "manual"
	if cfg != nil && cfg.Manual != nil && !cfg.Manual.Enabled {
		mode = "automatic"
	}

	workerCount := node.GetWorkerCount(cfg)

	return &NodeSetupView{
		config:      cfg,
		mode:        mode,
		workerCount: workerCount,
		focused:     "mode",
	}
}

// Init initializes the view
func (nv *NodeSetupView) Init() tea.Cmd {
	return nil
}

// Update handles updates
func (nv *NodeSetupView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "tab":
			if nv.focused == "mode" {
				nv.focused = "workers"
			} else {
				nv.focused = "mode"
			}
			return nv, nil

		case "enter":
			if nv.focused == "mode" {
				// Toggle mode
				if nv.mode == "manual" {
					nv.mode = "automatic"
				} else {
					nv.mode = "manual"
				}
				return nv, nil
			} else if nv.focused == "setup" {
				// Perform setup
				return nv, nv.setupNode()
			}
			return nv, nil

		case "up", "down":
			if nv.focused == "workers" {
				if msg.String() == "up" {
					nv.workerCount++
				} else if nv.workerCount > 1 {
					nv.workerCount--
				}
				return nv, nil
			}

		case "r":
			// Reset to defaults
			nv.mode = "manual"
			nv.workerCount = node.GetWorkerCount(nv.config)
			return nv, nil
		}
	}

	return nv, nil
}

// View renders the view
func (nv *NodeSetupView) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("205")).
		MarginBottom(1)

	sectionStyle := lipgloss.NewStyle().
		MarginBottom(1)

	focusedStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("205")).
		Bold(true)

	buttonStyle := lipgloss.NewStyle().
		Padding(0, 2).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("205"))

	b.WriteString(titleStyle.Render("Node Setup"))
	b.WriteString("\n\n")

	// Mode selection
	b.WriteString(sectionStyle.Render("Mode:"))
	if nv.focused == "mode" {
		b.WriteString(focusedStyle.Render(" ▶ "))
	} else {
		b.WriteString("   ")
	}

	if nv.mode == "manual" {
		b.WriteString(buttonStyle.Render("Manual Mode (Recommended)"))
		b.WriteString("  ")
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Automatic Mode"))
	} else {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Manual Mode"))
		b.WriteString("  ")
		b.WriteString(buttonStyle.Render("Automatic Mode"))
	}
	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("    Manual = separate services (more reliable)"))
	b.WriteString("\n\n")

	// Worker count (only for manual mode)
	if nv.mode == "manual" {
		b.WriteString(sectionStyle.Render("Worker Count:"))
		if nv.focused == "workers" {
			b.WriteString(focusedStyle.Render(" ▶ "))
		} else {
			b.WriteString("   ")
		}
		b.WriteString(fmt.Sprintf("%d workers", nv.workerCount))
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(" (↑/↓ to adjust)"))
		b.WriteString("\n\n")
	}

	// Setup button
	if nv.focused == "setup" {
		b.WriteString(focusedStyle.Render("▶ "))
	} else {
		b.WriteString("  ")
	}
	b.WriteString(buttonStyle.Render("Setup Node"))
	b.WriteString("\n\n")

	if nv.err != nil {
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render(fmt.Sprintf("Error: %v", nv.err)))
		b.WriteString("\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Tab to switch fields, Enter to toggle/execute, r to reset, Esc to go back"))

	return b.String()
}

// setupNode performs the node setup
func (nv *NodeSetupView) setupNode() tea.Cmd {
	return func() tea.Msg {
		opts := node.SetupOptions{
			AutomaticMode: nv.mode == "automatic",
			WorkerCount:   nv.workerCount,
		}

		err := node.SetupNode(opts, nv.config)
		if err != nil {
			return setupErrorMsg{err: err}
		}

		return setupSuccessMsg{}
	}
}

type setupErrorMsg struct {
	err error
}

type setupSuccessMsg struct{}
