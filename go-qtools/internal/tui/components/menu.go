package components

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Menu represents a navigation menu
type Menu struct {
	items    []MenuItem
	selected int
}

// MenuItem represents a menu item
type MenuItem struct {
	Label string
	Key   string
	Desc  string
}

// NewMenu creates a new menu
func NewMenu() *Menu {
	return &Menu{
		items: []MenuItem{
			{Label: "Node Setup", Key: "1", Desc: "Configure and setup node"},
			{Label: "Service Control", Key: "2", Desc: "Start, stop, restart services"},
			{Label: "Status", Key: "3", Desc: "View service status"},
			{Label: "Logs", Key: "4", Desc: "View logs"},
		},
		selected: 0,
	}
}

// Init initializes the menu
func (m *Menu) Init() tea.Cmd {
	return nil
}

// Update handles updates
func (m *Menu) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.selected > 0 {
				m.selected--
			}
			return m, nil

		case "down", "j":
			if m.selected < len(m.items)-1 {
				m.selected++
			}
			return m, nil

		case "enter":
			// Return the selected item's key
			return m, tea.Quit // Will be handled by parent
		}
	}
	return m, nil
}

// View renders the menu
func (m *Menu) View() string {
	var b strings.Builder

	titleStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("205")).
		MarginBottom(1)

	itemStyle := lipgloss.NewStyle().
		PaddingLeft(2).
		MarginBottom(1)

	selectedStyle := itemStyle.Copy().
		Foreground(lipgloss.Color("205")).
		Bold(true).
		PaddingLeft(1).
		BorderLeft(true).
		BorderStyle(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("205"))

	b.WriteString(titleStyle.Render("Quilibrium Tools"))
	b.WriteString("\n\n")

	for i, item := range m.items {
		if i == m.selected {
			b.WriteString(selectedStyle.Render(fmt.Sprintf("▶ %s [%s]", item.Label, item.Key)))
		} else {
			b.WriteString(itemStyle.Render(fmt.Sprintf("  %s [%s]", item.Label, item.Key)))
		}
		b.WriteString("\n")
		b.WriteString(itemStyle.Copy().Foreground(lipgloss.Color("240")).Render(fmt.Sprintf("    %s", item.Desc)))
		b.WriteString("\n\n")
	}

	b.WriteString("\n")
	b.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("240")).Render("Use arrow keys to navigate, Enter to select, q to quit"))

	return b.String()
}

// Selected returns the selected menu item key
func (m *Menu) Selected() string {
	if m.selected >= 0 && m.selected < len(m.items) {
		return m.items[m.selected].Key
	}
	return ""
}
