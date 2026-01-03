package node

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// UpdateOptions represents options for node update
type UpdateOptions struct {
	Force    bool
	SkipClean bool
	Auto     bool
}

// UpdateNode updates the node binary to the latest version
func UpdateNode(opts UpdateOptions, cfg *config.Config) error {
	// Check auto-update setting
	if opts.Auto {
		if cfg.ScheduledTasks == nil || cfg.ScheduledTasks.Updates == nil {
			return fmt.Errorf("auto-update is disabled")
		}
		// Check if node auto-update is enabled
		// This would need to be checked from config
	}

	// Get current version
	currentVersion, err := GetCurrentNodeVersion(cfg)
	if err != nil {
		return fmt.Errorf("failed to get current version: %w", err)
	}

	// Fetch release version
	releaseVersion, err := FetchNodeReleaseVersion()
	if err != nil {
		return fmt.Errorf("failed to fetch release version: %w", err)
	}

	// Check skip version
	skipVersion := getSkipVersion(cfg)
	if skipVersion != "" && releaseVersion == skipVersion {
		return fmt.Errorf("skipping update for version %s", skipVersion)
	}

	// Check if already up to date
	if currentVersion == releaseVersion && !opts.Force {
		return fmt.Errorf("node is already up to date (version %s)", currentVersion)
	}

	// Download and install new version
	if err := downloadAndInstallNode(releaseVersion, cfg); err != nil {
		return fmt.Errorf("failed to download/install node: %w", err)
	}

	// Update config with new version
	if err := SetCurrentNodeVersion(releaseVersion, cfg); err != nil {
		return fmt.Errorf("failed to update version in config: %w", err)
	}

	// Clean old files
	if !opts.SkipClean {
		if err := cleanOldNodeFiles(releaseVersion, cfg); err != nil {
			// Non-fatal error
			fmt.Printf("Warning: failed to clean old files: %v\n", err)
		}
	}

	return nil
}

// GetCurrentNodeVersion gets the current node version
func GetCurrentNodeVersion(cfg *config.Config) (string, error) {
	// Try to get from config first
	if cfg != nil && cfg.CurrentNodeVersion != "" {
		return cfg.CurrentNodeVersion, nil
	}

	// Try to get from symlink
	symlinkPath := "/usr/local/bin/node"
	if cfg != nil && cfg.Service != nil && cfg.Service.LinkName != "" {
		symlinkPath = cfg.Service.LinkName
	}

	linkTarget, err := os.Readlink(symlinkPath)
	if err == nil {
		// Extract version from filename
		re := regexp.MustCompile(`node-([0-9]+\.[0-9]+(?:\.[0-9]+)?)`)
		matches := re.FindStringSubmatch(linkTarget)
		if len(matches) > 1 {
			version := matches[1]
			// Update config with this version
			if cfg != nil {
				cfg.CurrentNodeVersion = version
			}
			return version, nil
		}
	}

	// Default fallback
	return "0.0.0", nil
}

// SetCurrentNodeVersion sets the current node version in config
func SetCurrentNodeVersion(version string, cfg *config.Config) error {
	if cfg == nil {
		return fmt.Errorf("config is nil")
	}
	cfg.CurrentNodeVersion = version
	return nil
}

// FetchNodeReleaseVersion fetches the latest node release version
func FetchNodeReleaseVersion() (string, error) {
	resp, err := http.Get("https://releases.quilibrium.com/release")
	if err != nil {
		return "", fmt.Errorf("failed to fetch release page: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Parse version from HTML (similar to bash script)
	re := regexp.MustCompile(`-([0-9]+\.[0-9]+(?:\.[0-9]+)?)-`)
	matches := re.FindAllStringSubmatch(string(body), -1)
	if len(matches) == 0 {
		return "", fmt.Errorf("could not find version in release page")
	}

	// Get first match and extract version
	version := strings.Trim(matches[0][1], "-")
	return version, nil
}

// downloadAndInstallNode downloads and installs the node binary
func downloadAndInstallNode(version string, cfg *config.Config) error {
	osArch := getOSArch()
	nodePath := config.GetNodePath()

	// Ensure directory exists
	if err := os.MkdirAll(nodePath, 0755); err != nil {
		return fmt.Errorf("failed to create node directory: %w", err)
	}

	binaryName := fmt.Sprintf("node-%s-%s", version, osArch)
	binaryPath := filepath.Join(nodePath, binaryName)

	// Check if binary already exists
	if _, err := os.Stat(binaryPath); err == nil {
		fmt.Printf("Binary %s already exists\n", binaryName)
	} else {
		// Download binary
		url := fmt.Sprintf("https://releases.quilibrium.com/%s", binaryName)
		fmt.Printf("Downloading %s...\n", url)

		resp, err := http.Get(url)
		if err != nil {
			return fmt.Errorf("failed to download binary: %w", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("failed to download binary: status %d", resp.StatusCode)
		}

		// Create file
		out, err := os.Create(binaryPath)
		if err != nil {
			return fmt.Errorf("failed to create binary file: %w", err)
		}
		defer out.Close()

		// Copy to file
		if _, err := io.Copy(out, resp.Body); err != nil {
			return fmt.Errorf("failed to write binary: %w", err)
		}

		// Make executable
		if err := os.Chmod(binaryPath, 0755); err != nil {
			return fmt.Errorf("failed to make binary executable: %w", err)
		}
	}

	// Set ownership if quilibrium user exists
	if err := setFileOwnership(binaryPath); err != nil {
		// Non-fatal
		fmt.Printf("Warning: failed to set ownership: %v\n", err)
	}

	// Create symlink
	symlinkPath := "/usr/local/bin/node"
	if cfg != nil && cfg.Service != nil && cfg.Service.LinkName != "" {
		symlinkPath = cfg.Service.LinkName
	}

	// Remove old symlink if exists
	if _, err := os.Lstat(symlinkPath); err == nil {
		if err := os.Remove(symlinkPath); err != nil {
			return fmt.Errorf("failed to remove old symlink: %w", err)
		}
	}

	// Create new symlink (requires sudo)
	cmd := exec.Command("sudo", "ln", "-sf", binaryPath, symlinkPath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create symlink: %w", err)
	}

	return nil
}

// cleanOldNodeFiles removes old node files
func cleanOldNodeFiles(currentVersion string, cfg *config.Config) error {
	nodePath := config.GetNodePath()
	clientPath := config.GetClientPath()

	// Clean node files
	files, err := os.ReadDir(nodePath)
	if err != nil {
		return err
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		filename := file.Name()
		// Skip current version and digest files
		if strings.Contains(filename, currentVersion) || strings.Contains(filename, ".dgst") {
			continue
		}

		// Remove old file
		filePath := filepath.Join(nodePath, filename)
		if err := os.Remove(filePath); err != nil {
			fmt.Printf("Warning: failed to remove %s: %v\n", filePath, err)
		}
	}

	// Clean qclient files (similar logic)
	files, err = os.ReadDir(clientPath)
	if err == nil {
		for _, file := range files {
			if file.IsDir() {
				continue
			}

			filename := file.Name()
			if strings.Contains(filename, ".dgst") {
				continue
			}

			filePath := filepath.Join(clientPath, filename)
			if err := os.Remove(filePath); err != nil {
				fmt.Printf("Warning: failed to remove %s: %v\n", filePath, err)
			}
		}
	}

	return nil
}

// getSkipVersion gets the skip version from config
func getSkipVersion(cfg *config.Config) string {
	if cfg == nil || cfg.ScheduledTasks == nil || cfg.ScheduledTasks.Updates == nil {
		return ""
	}

	// This would need to be extracted from the nested map structure
	// For now, return empty
	return ""
}

// getOSArch gets the OS architecture string
func getOSArch() string {
	os := runtime.GOOS
	arch := runtime.GOARCH

	archMap := map[string]string{
		"amd64": "amd64",
		"arm64": "arm64",
		"386":   "386",
	}

	mappedArch := archMap[arch]
	if mappedArch == "" {
		mappedArch = arch
	}

	return fmt.Sprintf("%s-%s", os, mappedArch)
}


// setFileOwnership sets file ownership to quilibrium:qtools
func setFileOwnership(path string) error {
	// This would use os.Chown with appropriate permissions
	// For now, use sudo chown
	cmd := exec.Command("sudo", "chown", "quilibrium:qtools", path)
	if err := cmd.Run(); err != nil {
		// Non-fatal - user/group might not exist
		return nil
	}

	cmd = exec.Command("sudo", "chmod", "g+rwx", path)
	return cmd.Run()
}
