package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

// detectShell detects the current shell from environment variables
func detectShell() string {
	// Check shell-specific environment variables
	if zsh := os.Getenv("ZSH_VERSION"); zsh != "" {
		return "zsh"
	}
	if bash := os.Getenv("BASH_VERSION"); bash != "" {
		return "bash"
	}
	if fish := os.Getenv("FISH_VERSION"); fish != "" {
		return "fish"
	}

	// Check SHELL environment variable
	shell := os.Getenv("SHELL")
	if shell != "" {
		shellName := filepath.Base(shell)
		switch shellName {
		case "bash", "zsh", "fish":
			return shellName
		case "sh":
			// On some systems, sh might be bash
			// Try to detect by checking if bash is available
			if _, err := exec.LookPath("bash"); err == nil {
				return "bash"
			}
		}
	}

	// Check parent process (ps -p $PPID -o comm=)
	if ppid := os.Getppid(); ppid > 0 {
		cmd := exec.Command("ps", "-p", fmt.Sprintf("%d", ppid), "-o", "comm=")
		if output, err := cmd.Output(); err == nil {
			comm := strings.TrimSpace(string(output))
			if comm == "bash" || comm == "zsh" || comm == "fish" {
				return comm
			}
		}
	}

	return ""
}

// promptShell prompts the user to select a shell
func promptShell() (string, error) {
	shells := []string{"bash", "zsh", "fish"}
	
	fmt.Println("Could not auto-detect your shell. Please select one:")
	for i, shell := range shells {
		fmt.Printf("  %d) %s\n", i+1, shell)
	}
	fmt.Print("Select shell (1-3): ")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("failed to read input: %w", err)
	}

	input = strings.TrimSpace(input)
	switch input {
	case "1":
		return "bash", nil
	case "2":
		return "zsh", nil
	case "3":
		return "fish", nil
	default:
		return "", fmt.Errorf("invalid selection: %s", input)
	}
}

// installCompletion installs the completion script for the given shell
func installCompletion(rootCmd *cobra.Command, shell string) error {
	var completionDir string
	var filename string
	var generateFunc func() error

	switch shell {
	case "bash":
		// Try system-wide first if writable, otherwise user directory
		if info, err := os.Stat("/etc/bash_completion.d"); err == nil && info.IsDir() {
			if _, err := os.Create("/etc/bash_completion.d/.qtools-test"); err == nil {
				os.Remove("/etc/bash_completion.d/.qtools-test")
				completionDir = "/etc/bash_completion.d"
			}
		}
		if completionDir == "" {
			// Try user directory
			userDir := filepath.Join(os.Getenv("HOME"), ".local", "share", "bash-completion", "completions")
			if err := os.MkdirAll(userDir, 0755); err == nil {
				completionDir = userDir
			} else {
				// Fallback to ~/.bash_completion.d
				userDir = filepath.Join(os.Getenv("HOME"), ".bash_completion.d")
				if err := os.MkdirAll(userDir, 0755); err == nil {
					completionDir = userDir
				}
			}
		}
		filename = "qtools"
		generateFunc = func() error {
			return rootCmd.GenBashCompletionFile(filepath.Join(completionDir, filename))
		}

	case "zsh":
		// Try to use fpath[1] if available, otherwise default location
		cmd := exec.Command("zsh", "-c", "echo $fpath[1]")
		if output, err := cmd.Output(); err == nil {
			zshPath := strings.TrimSpace(string(output))
			if zshPath != "" && zshPath != "$fpath[1]" {
				completionDir = zshPath
			}
		}
		if completionDir == "" {
			completionDir = filepath.Join(os.Getenv("HOME"), ".zsh", "completions")
		}
		if err := os.MkdirAll(completionDir, 0755); err != nil {
			return fmt.Errorf("failed to create zsh completion directory: %w", err)
		}
		filename = "_qtools"
		generateFunc = func() error {
			return rootCmd.GenZshCompletionFile(filepath.Join(completionDir, filename))
		}

	case "fish":
		completionDir = filepath.Join(os.Getenv("HOME"), ".config", "fish", "completions")
		if err := os.MkdirAll(completionDir, 0755); err != nil {
			return fmt.Errorf("failed to create fish completion directory: %w", err)
		}
		filename = "qtools.fish"
		generateFunc = func() error {
			file, err := os.Create(filepath.Join(completionDir, filename))
			if err != nil {
				return err
			}
			defer file.Close()
			return rootCmd.GenFishCompletion(file, true)
		}

	default:
		return fmt.Errorf("unsupported shell: %s", shell)
	}

	// Generate and write completion file
	if err := generateFunc(); err != nil {
		return fmt.Errorf("failed to generate completion script: %w", err)
	}

	// Make executable for bash
	if shell == "bash" {
		filePath := filepath.Join(completionDir, filename)
		if err := os.Chmod(filePath, 0755); err != nil {
			return fmt.Errorf("failed to make completion script executable: %w", err)
		}
	}

	fmt.Printf("✓ Completion installed for %s to %s\n", shell, filepath.Join(completionDir, filename))
	fmt.Printf("\nTo use completions in your current session, run:\n")
	switch shell {
	case "bash":
		fmt.Printf("  source %s\n", filepath.Join(completionDir, filename))
	case "zsh":
		fmt.Printf("  source %s\n", filepath.Join(completionDir, filename))
		fmt.Printf("  Or add '%s' to your fpath in ~/.zshrc\n", completionDir)
	case "fish":
		fmt.Printf("  Restart your shell or run: source %s\n", filepath.Join(completionDir, filename))
	}
	fmt.Println("\nCompletions will be available automatically in new shell sessions.")

	return nil
}
