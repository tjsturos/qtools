package tui

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/tui/views"
)

// ViewType represents the current view
type ViewType int

const (
	ViewMenu ViewType = iota
	ViewNodeSetup
	ViewServiceControl
	ViewStatus
	ViewLogs
	ViewConfig
)

// App represents the main TUI application
type App struct {
	config     *config.Config
	currentView ViewType
	views      map[ViewType]tea.Model
	width      int
	height     int
	quitting   bool
}

// NewApp creates a new TUI application
func NewApp(cfg *config.Config) *App {
	app := &App{
		config:     cfg,
		currentView: ViewMenu,
		views:      make(map[ViewType]tea.Model),
	}

	// Initialize views
	app.views[ViewMenu] = views.NewMenuView()
	app.views[ViewNodeSetup] = views.NewNodeSetupView(cfg)
	app.views[ViewServiceControl] = views.NewServiceControlView(cfg)
	app.views[ViewStatus] = views.NewStatusView(cfg)
	app.views[ViewLogs] = views.NewLogView(cfg)

	return app
}

// Init initializes the TUI
func (a *App) Init() tea.Cmd {
	return tea.Batch(
		tea.EnterAltScreen,
		a.views[a.currentView].Init(),
	)
}

// Update handles updates
func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		a.width = msg.Width
		a.height = msg.Height
		return a, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			a.quitting = true
			return a, tea.Quit

		case "1":
			a.currentView = ViewNodeSetup
			return a, a.views[a.currentView].Init()

		case "2":
			a.currentView = ViewServiceControl
			return a, a.views[a.currentView].Init()

		case "3":
			a.currentView = ViewStatus
			return a, a.views[a.currentView].Init()

		case "4":
			a.currentView = ViewLogs
			return a, a.views[a.currentView].Init()

		case "esc":
			if a.currentView != ViewMenu {
				a.currentView = ViewMenu
				return a, a.views[a.currentView].Init()
			}
			return a, tea.Quit
		}
	}

	// Delegate to current view
	if view, ok := a.views[a.currentView]; ok {
		updatedView, cmd := view.Update(msg)
		a.views[a.currentView] = updatedView
		return a, cmd
	}

	return a, nil
}

// View renders the TUI
func (a *App) View() string {
	if a.quitting {
		return ""
	}

	var content string
	if view, ok := a.views[a.currentView]; ok {
		content = view.View()
	} else {
		content = "Unknown view"
	}

	// Render with status bar
	return lipgloss.JoinVertical(
		lipgloss.Left,
		content,
		renderStatusBar(a.config, a.currentView),
	)
}

// renderStatusBar renders the status bar
func renderStatusBar(cfg *config.Config, currentView ViewType) string {
	statusStyle := lipgloss.NewStyle().
		Width(80).
		BorderTop(true).
		BorderStyle(lipgloss.RoundedBorder()).
		Padding(0, 1)

	var mode string
	if cfg != nil && cfg.Manual != nil && cfg.Manual.Enabled {
		mode = "Manual Mode"
	} else {
		mode = "Automatic Mode"
	}

	viewNames := map[ViewType]string{
		ViewMenu:           "Menu",
		ViewNodeSetup:      "Node Setup",
		ViewServiceControl: "Service Control",
		ViewStatus:          "Status",
		ViewLogs:            "Logs",
		ViewConfig:          "Config",
	}

	status := fmt.Sprintf("%s | Mode: %s | Press 'q' to quit", viewNames[currentView], mode)
	return statusStyle.Render(status)
}

// Run runs the TUI application
func Run(cfg *config.Config) error {
	app := NewApp(cfg)
	p := tea.NewProgram(app, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		return fmt.Errorf("failed to run TUI: %w", err)
	}
	return nil
}

// ConfigType is re-exported from views for convenience
type ConfigType = views.ConfigType

const (
	ConfigTypeQtools = views.ConfigTypeQtools
	ConfigTypeQuil   = views.ConfigTypeQuil
)

// RunConfigView runs the TUI config view directly
func RunConfigView(cfg *config.Config, initialPath string, configType ConfigType) error {
	configView, err := views.NewConfigView(cfg, initialPath, configType)
	if err != nil {
		return fmt.Errorf("failed to create config view: %w", err)
	}

	p := tea.NewProgram(configView, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		return fmt.Errorf("failed to run config view: %w", err)
	}
	return nil
}
