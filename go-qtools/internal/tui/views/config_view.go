package views

import (
	"fmt"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/tjsturos/qtools/go-qtools/internal/config"
	"github.com/tjsturos/qtools/go-qtools/internal/node"
)

var (
	configTitleStyle = lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("62")).
		Padding(0, 1)

	configKeyStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("39")).
		Bold(true)

	configValueStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("252"))

	configPathStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("240")).
		Italic(true)

	selectedStyle = lipgloss.NewStyle().
		Background(lipgloss.Color("62")).
		Foreground(lipgloss.Color("230")).
		Padding(0, 1)

	mapIndicatorStyle = lipgloss.NewStyle().
		Foreground(lipgloss.Color("214")).
		Bold(true)
)

// ConfigType represents which config we're browsing
type ConfigType int

const (
	ConfigTypeQtools ConfigType = iota
	ConfigTypeQuil
)

// ConfigEntry represents a config entry (key-value pair or section)
type ConfigEntry struct {
	Key      string
	Value    interface{}
	IsMap    bool
	FullPath string
}

// ConfigView represents the config browsing view
type ConfigView struct {
	qtoolsConfig *config.Config
	nodeConfig   *node.NodeConfig
	configType   ConfigType
	currentPath  string
	entries      []ConfigEntry
	allEntries   []ConfigEntry // All entries at current level (before filtering)
	selectedIdx  int
	searchMode   bool
	searchQuery  string
	width        int
	height       int
}

// NewConfigView creates a new config view
func NewConfigView(qtoolsConfig *config.Config, initialPath string, configType ConfigType) (*ConfigView, error) {
	// Load node config
	mgr, err := node.NewNodeConfigManager("")
	if err != nil {
		return nil, fmt.Errorf("failed to create node config manager: %w", err)
	}

	nodeCfg, err := mgr.Load()
	if err != nil {
		// Non-fatal - node config might not exist
		nodeCfg = &node.NodeConfig{
			Raw: make(map[string]interface{}),
		}
	}

	cv := &ConfigView{
		qtoolsConfig: qtoolsConfig,
		nodeConfig:   nodeCfg,
		configType:   configType,
		currentPath:  initialPath,
		selectedIdx:  0,
		searchMode:   false,
		searchQuery:  "",
	}

	// Load initial entries
	if err := cv.loadEntries(); err != nil {
		return nil, err
	}

	return cv, nil
}

// Init initializes the view
func (cv *ConfigView) Init() tea.Cmd {
	return nil
}

// Update handles updates
func (cv *ConfigView) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		cv.width = msg.Width
		cv.height = msg.Height
		return cv, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc":
			if cv.currentPath == "" {
				return cv, tea.Quit
			}
			// Go back up one level
			parts := strings.Split(cv.currentPath, ".")
			if len(parts) > 1 {
				cv.currentPath = strings.Join(parts[:len(parts)-1], ".")
			} else {
				cv.currentPath = ""
			}
			cv.selectedIdx = 0
			cv.loadEntries()
			return cv, nil

		case "up", "k":
			if cv.selectedIdx > 0 {
				cv.selectedIdx--
			}
			return cv, nil

		case "down", "j":
			if cv.selectedIdx < len(cv.entries)-1 {
				cv.selectedIdx++
			}
			return cv, nil

		case "enter":
			if len(cv.entries) > 0 && cv.selectedIdx < len(cv.entries) {
				entry := cv.entries[cv.selectedIdx]
				if entry.IsMap {
					// Drill down into map
					cv.currentPath = entry.FullPath
					cv.selectedIdx = 0
					cv.loadEntries()
				}
			}
			return cv, nil

		case "/":
			cv.searchMode = true
			cv.searchQuery = ""
			return cv, nil

		case "ctrl+c":
			if cv.searchMode {
				cv.searchMode = false
				cv.searchQuery = ""
				cv.filterEntries() // Reset filter
				return cv, nil
			}
			return cv, tea.Quit

		case "t":
			// Toggle between qtools and quil config
			if cv.configType == ConfigTypeQtools {
				cv.configType = ConfigTypeQuil
			} else {
				cv.configType = ConfigTypeQtools
			}
			cv.currentPath = "" // Reset to root when switching
			cv.selectedIdx = 0
			cv.loadEntries()
			return cv, nil
		}

		// Handle search input
		if cv.searchMode {
			switch msg.String() {
			case "enter":
				// Filter entries by search query
				cv.filterEntries()
				cv.searchMode = false
				return cv, nil
			case "esc":
				cv.searchMode = false
				cv.searchQuery = ""
				cv.filterEntries() // Reset filter
				return cv, nil
			case "backspace":
				if len(cv.searchQuery) > 0 {
					cv.searchQuery = cv.searchQuery[:len(cv.searchQuery)-1]
				}
				return cv, nil
			default:
				if len(msg.Runes) > 0 {
					cv.searchQuery += string(msg.Runes)
				}
				return cv, nil
			}
		}
	}

	return cv, nil
}

// loadEntries loads entries for the current path
func (cv *ConfigView) loadEntries() error {
	var current map[string]interface{}

	if cv.configType == ConfigTypeQtools {
		if cv.qtoolsConfig == nil || cv.qtoolsConfig.Raw == nil {
			return fmt.Errorf("qtools config is nil")
		}
		current = cv.qtoolsConfig.Raw
	} else {
		if cv.nodeConfig == nil || cv.nodeConfig.Raw == nil {
			return fmt.Errorf("quil config is nil")
		}
		current = cv.nodeConfig.Raw
	}

	// Navigate to path
	if cv.currentPath != "" {
		// Handle paths starting with . (e.g., ".p2p.listen-port")
		path := cv.currentPath
		if strings.HasPrefix(path, ".") {
			path = path[1:] // Remove leading dot
		}
		
		keys := strings.Split(path, ".")
		for _, key := range keys {
			if key == "" {
				continue // Skip empty keys from double dots or trailing dots
			}
			if next, ok := current[key].(map[string]interface{}); ok {
				current = next
			} else {
				return fmt.Errorf("path %s does not exist or is not a map", cv.currentPath)
			}
		}
	}

	// List keys
	var entries []ConfigEntry
	for key, value := range current {
		fullPath := key
		if cv.currentPath != "" {
			fullPath = cv.currentPath + "." + key
		}

		_, isMap := value.(map[string]interface{})

		entries = append(entries, ConfigEntry{
			Key:      key,
			Value:    value,
			IsMap:    isMap,
			FullPath: fullPath,
		})
	}

	// Sort by key name
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Key < entries[j].Key
	})

	cv.entries = entries
	if cv.selectedIdx >= len(cv.entries) {
		cv.selectedIdx = 0
	}
	return nil
}

// filterEntries filters entries by search query
func (cv *ConfigView) filterEntries() {
	if cv.searchQuery == "" {
		cv.loadEntries()
		return
	}

	query := strings.ToLower(cv.searchQuery)
	var filtered []ConfigEntry

	for _, entry := range cv.entries {
		if strings.Contains(strings.ToLower(entry.Key), query) {
			filtered = append(filtered, entry)
		}
	}

	cv.entries = filtered
	if cv.selectedIdx >= len(cv.entries) {
		cv.selectedIdx = 0
	}
}

// View renders the view
func (cv *ConfigView) View() string {
	var b strings.Builder

	// Title
	configTypeName := "Qtools Config"
	if cv.configType == ConfigTypeQuil {
		configTypeName = "Quil Node Config"
	}
	b.WriteString(configTitleStyle.Render(configTypeName))
	b.WriteString("\n\n")

	// Path breadcrumb
	if cv.currentPath != "" {
		b.WriteString(configPathStyle.Render("Path: " + cv.currentPath))
		b.WriteString("\n\n")
	}

	// Search mode
	if cv.searchMode {
		b.WriteString(fmt.Sprintf("Search: %s█\n\n", cv.searchQuery))
	}

	// Entries list
	if len(cv.entries) == 0 {
		b.WriteString("No entries found.\n")
	} else {
		// Calculate visible range
		visibleHeight := cv.height - 12 // Reserve space for title, path, search, help, etc.
		if visibleHeight < 1 {
			visibleHeight = 10
		}
		if visibleHeight > len(cv.entries) {
			visibleHeight = len(cv.entries)
		}

		startIdx := 0
		endIdx := len(cv.entries)

		if len(cv.entries) > visibleHeight {
			// Show entries around selected
			startIdx = cv.selectedIdx - visibleHeight/2
			if startIdx < 0 {
				startIdx = 0
			}
			endIdx = startIdx + visibleHeight
			if endIdx > len(cv.entries) {
				endIdx = len(cv.entries)
				startIdx = endIdx - visibleHeight
				if startIdx < 0 {
					startIdx = 0
				}
			}
		}

		for i := startIdx; i < endIdx; i++ {
			entry := cv.entries[i]
			line := ""

			if i == cv.selectedIdx {
				line += "> "
			} else {
				line += "  "
			}

			// Key
			keyText := configKeyStyle.Render(entry.Key)
			if entry.IsMap {
				keyText += " " + mapIndicatorStyle.Render("→")
			}
			line += keyText

			// Value (if not a map)
			if !entry.IsMap {
				valueText := formatConfigValue(entry.Value)
				// Truncate long values
				maxValueLen := cv.width - len(entry.Key) - 20
				if maxValueLen > 0 && len(valueText) > maxValueLen {
					valueText = valueText[:maxValueLen] + "..."
				}
				line += ": " + configValueStyle.Render(valueText)
			}

			if i == cv.selectedIdx {
				line = selectedStyle.Render(line)
			}

			b.WriteString(line)
			b.WriteString("\n")
		}

		if len(cv.entries) > visibleHeight {
			b.WriteString(fmt.Sprintf("\n... showing %d-%d of %d entries ...\n", startIdx+1, endIdx, len(cv.entries)))
		}
	}

	// Help text
	b.WriteString("\n")
	if cv.searchMode {
		b.WriteString("Type to search | Enter: Apply | Esc: Cancel")
	} else {
		helpText := "↑/↓: Navigate | Enter: Drill down | /: Search | t: Toggle config | Esc/q: Back/Quit"
		b.WriteString(helpText)
	}

	return b.String()
}

// formatConfigValue formats a value for display
func formatConfigValue(value interface{}) string {
	if value == nil {
		return "null"
	}

	switch v := value.(type) {
	case bool:
		if v {
			return "true"
		}
		return "false"
	case int:
		return fmt.Sprintf("%d", v)
	case float64:
		return fmt.Sprintf("%g", v)
	case string:
		return v
	case []interface{}:
		return fmt.Sprintf("[array with %d items]", len(v))
	case map[string]interface{}:
		return fmt.Sprintf("{map with %d keys}", len(v))
	default:
		return fmt.Sprintf("%v", v)
	}
}
