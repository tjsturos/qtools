package views

import (
	tea "github.com/charmbracelet/bubbletea"
	"github.com/tjsturos/qtools/go-qtools/internal/tui/components"
)

// MenuView wraps the menu component
type MenuView struct {
	menu *components.Menu
}

// NewMenuView creates a new menu view
func NewMenuView() *MenuView {
	return &MenuView{
		menu: components.NewMenu(),
	}
}

// Init initializes the view
func (mv *MenuView) Init() tea.Cmd {
	return mv.menu.Init()
}

// Update handles updates
func (mv *MenuView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	return mv.menu.Update(msg)
}

// View renders the view
func (mv *MenuView) View() string {
	return mv.menu.View()
}
