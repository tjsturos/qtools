package components

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/service"
)

// CoreInput represents a core number input component
type CoreInput struct {
	textinput textinput.Model
	preview  []int
	err      error
}

// NewCoreInput creates a new core input component
func NewCoreInput() *CoreInput {
	ti := textinput.New()
	ti.Placeholder = "e.g., 1-4,6,8 or 5"
	ti.CharLimit = 50
	ti.Width = 30

	return &CoreInput{
		textinput: ti,
	}
}

// Init initializes the component
func (ci *CoreInput) Init() tea.Cmd {
	return textinput.Blink
}

// Update handles updates
func (ci *CoreInput) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			// Parse and validate
			input := ci.textinput.Value()
			if input != "" {
				cores, err := service.ParseCoreNumbers(input)
				if err != nil {
					ci.err = err
					ci.preview = nil
				} else {
					ci.err = nil
					ci.preview = cores
				}
			}
			return ci, nil
		}
	}

	ci.textinput, cmd = ci.textinput.Update(msg)

	// Update preview on change
	input := ci.textinput.Value()
	if input != "" {
		cores, err := service.ParseCoreNumbers(input)
		if err == nil {
			ci.preview = cores
			ci.err = nil
		}
	} else {
		ci.preview = nil
		ci.err = nil
	}

	return ci, cmd
}

// View renders the component
func (ci *CoreInput) View() string {
	var b strings.Builder

	b.WriteString(ci.textinput.View())

	if ci.err != nil {
		b.WriteString("\n")
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("196")).Render(fmt.Sprintf("Error: %v", ci.err)))
	}

	if len(ci.preview) > 0 {
		b.WriteString("\n")
		b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render(fmt.Sprintf("Will affect workers: %v", ci.preview)))
	}

	return b.String()
}

// Value returns the parsed core numbers
func (ci *CoreInput) Value() []int {
	return ci.preview
}
