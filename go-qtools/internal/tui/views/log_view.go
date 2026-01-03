package views

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/log"
)

// LogView represents the log view
type LogView struct {
	config      *config.Config
	viewer      *log.LogViewer
	filter      *log.LogFilter
	logType     string // "master", "worker-N", "qtools"
	lines       []string
	paused      bool
	err         error
}

// NewLogView creates a new log view
func NewLogView(cfg *config.Config) *LogView {
	return &LogView{
		config:  cfg,
		viewer:  log.NewLogViewer(cfg),
		logType: "master",
		filter: &log.LogFilter{
			Mode:    "include",
			Filters: make(map[string]bool),
		},
	}
}

// Init initializes the view
func (lv *LogView) Init() tea.Cmd {
	return lv.startTailing()
}

// Update handles updates
func (lv *LogView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "m":
			lv.logType = "master"
			return lv, lv.startTailing()

		case "w":
			lv.logType = "worker-1"
			return lv, lv.startTailing()

		case "q":
			lv.logType = "qtools"
			return lv, lv.startTailing()

		case " ":
			lv.paused = !lv.paused
			return lv, nil

		case "c":
			lv.lines = nil
			return lv, nil
		}

	case logLineMsg:
		if !lv.paused {
			lv.lines = append(lv.lines, msg.line)
			// Keep only last 1000 lines
			if len(lv.lines) > 1000 {
				lv.lines = lv.lines[len(lv.lines)-1000:]
			}
		}
		return lv, nil

	case logErrorMsg:
		lv.err = msg.err
		return lv, nil
	}

	return lv, nil
}

// View renders the view
func (lv *LogView) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("205")).
		MarginBottom(1)

	b.WriteString(titleStyle.Render(fmt.Sprintf("Logs: %s", lv.logType)))
	b.WriteString("\n\n")

	// Controls
	controls := fmt.Sprintf("[m] Master [w] Worker [q] Qtools [Space] Pause [c] Clear")
	if lv.paused {
		controls += " (PAUSED)"
	}
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(controls))
	b.WriteString("\n\n")

	// Log lines
	if len(lv.lines) == 0 {
		b.WriteString("No log lines yet...")
	} else {
		// Show last 50 lines
		start := 0
		if len(lv.lines) > 50 {
			start = len(lv.lines) - 50
		}
		for _, line := range lv.lines[start:] {
			b.WriteString(line)
			b.WriteString("\n")
		}
	}

	if lv.err != nil {
		b.WriteString("\n")
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render(fmt.Sprintf("Error: %v", lv.err)))
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Esc to go back"))

	return b.String()
}

// startTailing starts tailing the log file
func (lv *LogView) startTailing() tea.Cmd {
	return func() tea.Msg {
		var ch <-chan string
		var err error

		switch lv.logType {
		case "master":
			masterPath, _, _, _ := lv.viewer.GetLogFilePaths()
			ch, err = lv.viewer.TailLogFile(masterPath, lv.filter)

		case "qtools":
			_, _, qtoolsPath, _ := lv.viewer.GetLogFilePaths()
			ch, err = lv.viewer.TailLogFile(qtoolsPath, lv.filter)

		default:
			if strings.HasPrefix(lv.logType, "worker-") {
				var workerIndex int
				fmt.Sscanf(lv.logType, "worker-%d", &workerIndex)
				ch, err = lv.viewer.TailWorkerLog(workerIndex, lv.filter)
			}
		}

		if err != nil {
			return logErrorMsg{err: err}
		}

		// Start reading from channel
		// Note: In a real implementation, we'd use a proper message channel
		_ = ch

		return nil
	}
}

type logLineMsg struct {
	line string
}

type logErrorMsg struct {
	err error
}
