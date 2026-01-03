package node

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"

	"github.com/tjsturos/qtools/go-qtools/internal/config"
)

// InstallOptions represents options for complete installation
type InstallOptions struct {
	PeerID        string
	ListenPort    int
	StreamPort    int
	BaseP2PPort   int
	BaseStreamPort int
}

// CompleteInstall performs a complete installation of the node
// Equivalent to complete-install.sh
func CompleteInstall(opts InstallOptions, cfg *config.Config) error {
	// Create qtools group if it doesn't exist
	if err := ensureQtoolsGroup(); err != nil {
		return fmt.Errorf("failed to ensure qtools group: %w", err)
	}

	// Create quilibrium user (Linux only)
	if err := ensureQuilibriumUser(); err != nil {
		return fmt.Errorf("failed to ensure quilibrium user: %w", err)
	}

	// Add installing user to qtools group (if non-root)
	if err := addUserToQtoolsGroup(); err != nil {
		return fmt.Errorf("failed to add user to qtools group: %w", err)
	}

	// Setup directory structure
	if err := setupDirectories(); err != nil {
		return fmt.Errorf("failed to setup directories: %w", err)
	}

	// Download node binary
	if err := downloadNodeBinary(cfg); err != nil {
		return fmt.Errorf("failed to download node binary: %w", err)
	}

	// Download qclient binary
	if err := downloadQClientBinary(cfg); err != nil {
		return fmt.Errorf("failed to download qclient binary: %w", err)
	}

	// Create symlinks
	if err := createSymlinks(cfg); err != nil {
		return fmt.Errorf("failed to create symlinks: %w", err)
	}

	// Generate default config
	if err := generateDefaultConfig(cfg); err != nil {
		return fmt.Errorf("failed to generate default config: %w", err)
	}

	// Enable manual mode by default (opinionated default for reliability)
	if cfg.Manual == nil {
		cfg.Manual = &config.ManualConfig{}
	}
	cfg.Manual.Enabled = true
	cfg.Manual.WorkerCount = GetWorkerCount(cfg)
	cfg.Manual.LocalOnly = true

	// Enable custom logging by default
	nodeConfigPath := config.GetNodeConfigPath()
	if err := EnableCustomLogging(nodeConfigPath, DefaultLoggingOptions()); err != nil {
		return fmt.Errorf("failed to enable custom logging: %w", err)
	}

	// Setup node configuration
	setupOpts := SetupOptions{
		WorkerCount:   cfg.Manual.WorkerCount,
		ListenPort:    opts.ListenPort,
		StreamPort:    opts.StreamPort,
		BaseP2PPort:   opts.BaseP2PPort,
		BaseStreamPort: opts.BaseStreamPort,
	}
	if err := SetupManualMode(cfg, cfg.Manual.WorkerCount, setupOpts); err != nil {
		return fmt.Errorf("failed to setup manual mode: %w", err)
	}

	// Note: Authentication will use public/private key encryption via Quilibrium Messaging layer
	// This will be implemented when Quilibrium Messaging integration is added.
	// Authentication will be required for:
	// - Desktop app connections
	// - gRPC API access (port 8337)
	// - REST API access (port 8338)

	// Optional: Setup firewall (non-fatal)
	if err := setupFirewall(); err != nil {
		fmt.Printf("Warning: failed to setup firewall: %v\n", err)
		fmt.Println("You may need to configure firewall rules manually")
	}

	// Optional: Install dependencies (non-fatal)
	if err := installDependencies(); err != nil {
		fmt.Printf("Warning: failed to install dependencies: %v\n", err)
		fmt.Println("You may need to install Go and grpcurl manually")
	}

	return nil
}

// ensureQtoolsGroup ensures the qtools group exists
func ensureQtoolsGroup() error {
	_, err := user.LookupGroup("qtools")
	if err == nil {
		return nil // Group already exists
	}

	// Group doesn't exist - create it with sudo
	fmt.Println("Creating qtools group...")
	cmd := exec.Command("sudo", "groupadd", "qtools")
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Check if group was created by another process
		_, checkErr := user.LookupGroup("qtools")
		if checkErr == nil {
			return nil // Group exists now
		}
		return fmt.Errorf("failed to create qtools group: %w\nOutput: %s", err, string(output))
	}

	fmt.Println("✓ Qtools group created successfully")
	return nil
}

// ensureQuilibriumUser ensures the quilibrium user exists
func ensureQuilibriumUser() error {
	// Only create on Linux
	if runtime.GOOS != "linux" {
		return nil
	}

	_, err := user.Lookup("quilibrium")
	if err == nil {
		// User exists - ensure it's in qtools group
		return ensureUserInGroup("quilibrium", "qtools")
	}

	// User doesn't exist - create it with sudo
	fmt.Println("Creating quilibrium system user...")
	homeDir := "/home/quilibrium"
	cmd := exec.Command("sudo", "useradd", "-r", "-s", "/usr/sbin/nologin", "-d", homeDir, "-m", "quilibrium")
	output, err := cmd.CombinedOutput()
	if err != nil {
		// Check if user was created by another process
		_, checkErr := user.Lookup("quilibrium")
		if checkErr == nil {
			// User exists now, ensure group membership
			return ensureUserInGroup("quilibrium", "qtools")
		}
		return fmt.Errorf("failed to create quilibrium user: %w\nOutput: %s", err, string(output))
	}

	fmt.Println("✓ Quilibrium user created successfully")

	// Add quilibrium user to qtools group
	return ensureUserInGroup("quilibrium", "qtools")
}

// ensureUserInGroup ensures a user is in the specified group
func ensureUserInGroup(username, groupname string) error {
	_, err := user.Lookup(username)
	if err != nil {
		return fmt.Errorf("user %s not found: %w", username, err)
	}

	// Get groups for user
	cmd := exec.Command("id", "-Gn", username)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to get groups for user %s: %w", username, err)
	}

	groups := strings.Fields(string(output))
	for _, g := range groups {
		if g == groupname {
			return nil // Already in group
		}
	}

	// Add user to group
	fmt.Printf("Adding %s to %s group...\n", username, groupname)
	cmd = exec.Command("sudo", "usermod", "-a", "-G", groupname, username)
	output, err = cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to add %s to %s group: %w\nOutput: %s", username, groupname, err, string(output))
	}

	// Also ensure root is in qtools group
	if username != "root" {
		_ = ensureUserInGroup("root", groupname) // Non-fatal
	}

	fmt.Printf("✓ Added %s to %s group\n", username, groupname)
	return nil
}

// addUserToQtoolsGroup adds the current user to the qtools group
func addUserToQtoolsGroup() error {
	currentUser, err := user.Current()
	if err != nil {
		return fmt.Errorf("failed to get current user: %w", err)
	}

	if currentUser.Username == "root" {
		return nil // Root doesn't need to be added
	}

	// Add current user to qtools group
	return ensureUserInGroup(currentUser.Username, "qtools")
}

// setupDirectories creates the directory structure with proper ownership
func setupDirectories() error {
	qtoolsPath := config.GetQtoolsPath()
	nodePath := config.GetNodePath()
	clientPath := config.GetClientPath()

	dirs := []string{
		qtoolsPath,
		nodePath,
		clientPath,
		filepath.Join(nodePath, ".config"),
		filepath.Join(nodePath, ".logs"),
	}

	fmt.Println("Setting up directory structure...")
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}

		// Set ownership to quilibrium:qtools if user exists
		if err := setDirectoryOwnership(dir); err != nil {
			// Non-fatal - user/group might not exist yet
			fmt.Printf("Warning: failed to set ownership for %s: %v\n", dir, err)
		}
	}

	fmt.Println("✓ Directory structure created")
	return nil
}

// setDirectoryOwnership sets directory ownership to quilibrium:qtools
func setDirectoryOwnership(path string) error {
	// Check if quilibrium user exists
	_, err := user.Lookup("quilibrium")
	if err != nil {
		return nil // User doesn't exist, skip ownership change
	}

	cmd := exec.Command("sudo", "chown", "-R", "quilibrium:qtools", path)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("chown failed: %w", err)
	}

	cmd = exec.Command("sudo", "chmod", "-R", "g+rwx", path)
	return cmd.Run()
}

// downloadNodeBinary downloads the latest node binary
func downloadNodeBinary(cfg *config.Config) error {
	fmt.Println("Downloading node binary...")

	// Get latest version
	version, err := FetchNodeReleaseVersion()
	if err != nil {
		return fmt.Errorf("failed to fetch node version: %w", err)
	}

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
		fmt.Printf("Node binary %s already exists\n", binaryName)
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

	// Set ownership
	if err := setFileOwnership(binaryPath); err != nil {
		fmt.Printf("Warning: failed to set ownership: %v\n", err)
	}

	fmt.Printf("✓ Node binary downloaded: %s\n", binaryName)
	return nil
}

// downloadQClientBinary downloads the latest qclient binary
func downloadQClientBinary(cfg *config.Config) error {
	fmt.Println("Downloading qclient binary...")

	// Get latest version from qclient release page
	version, err := fetchQClientReleaseVersion()
	if err != nil {
		return fmt.Errorf("failed to fetch qclient version: %w", err)
	}

	osArch := getOSArch()
	clientPath := config.GetClientPath()

	// Ensure directory exists
	if err := os.MkdirAll(clientPath, 0755); err != nil {
		return fmt.Errorf("failed to create client directory: %w", err)
	}

	binaryName := fmt.Sprintf("qclient-%s-%s", version, osArch)
	binaryPath := filepath.Join(clientPath, binaryName)

	// Check if binary already exists
	if _, err := os.Stat(binaryPath); err == nil {
		fmt.Printf("QClient binary %s already exists\n", binaryName)
	} else {
		// Download binary
		url := fmt.Sprintf("https://releases.quilibrium.com/qclient-release/%s", binaryName)
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

	// Set ownership
	if err := setFileOwnership(binaryPath); err != nil {
		fmt.Printf("Warning: failed to set ownership: %v\n", err)
	}

	fmt.Printf("✓ QClient binary downloaded: %s\n", binaryName)
	return nil
}

// fetchQClientReleaseVersion fetches the latest qclient release version
func fetchQClientReleaseVersion() (string, error) {
	resp, err := http.Get("https://releases.quilibrium.com/qclient-release")
	if err != nil {
		return "", fmt.Errorf("failed to fetch release page: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	// Parse version from HTML
	re := regexp.MustCompile(`qclient-([0-9]+\.[0-9]+(?:\.[0-9]+)?)-`)
	matches := re.FindAllStringSubmatch(string(body), -1)
	if len(matches) == 0 {
		return "", fmt.Errorf("could not find version in release page")
	}

	// Get first match and extract version
	version := strings.Trim(matches[0][1], "-")
	return version, nil
}

// createSymlinks creates symlinks for node and qtools binaries
func createSymlinks(cfg *config.Config) error {
	fmt.Println("Creating symlinks...")

	nodePath := config.GetNodePath()
	osArch := getOSArch()

	// Find latest node binary
	nodeBinary, err := findLatestNodeBinary(nodePath, osArch)
	if err != nil {
		return fmt.Errorf("failed to find node binary: %w", err)
	}

	// Create node symlink
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
	cmd := exec.Command("sudo", "ln", "-sf", nodeBinary, symlinkPath)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to create node symlink: %w", err)
	}

	fmt.Printf("✓ Created symlink: %s -> %s\n", symlinkPath, nodeBinary)

	// Create qclient symlink to qtools binary
	// This allows "qclient" command to route to "qtools qclient"
	qtoolsBinaryPath, err := os.Executable()
	if err != nil {
		// Fallback to os.Args[0]
		qtoolsBinaryPath = os.Args[0]
		// Resolve if it's a relative path
		if !filepath.IsAbs(qtoolsBinaryPath) {
			cwd, _ := os.Getwd()
			qtoolsBinaryPath = filepath.Join(cwd, qtoolsBinaryPath)
		}
	}
	
	// Resolve symlinks to get the actual binary path
	if linkTarget, err := os.Readlink(qtoolsBinaryPath); err == nil {
		if filepath.IsAbs(linkTarget) {
			qtoolsBinaryPath = linkTarget
		} else {
			qtoolsBinaryPath = filepath.Join(filepath.Dir(qtoolsBinaryPath), linkTarget)
		}
	}

	qclientSymlinkPath := "/usr/local/bin/qclient"
	if cfg != nil && cfg.Service != nil && cfg.Service.LinkDirectory != "" {
		qclientSymlinkPath = filepath.Join(cfg.Service.LinkDirectory, "qclient")
	}

	// Remove old symlink if exists
	if _, err := os.Lstat(qclientSymlinkPath); err == nil {
		if err := os.Remove(qclientSymlinkPath); err != nil {
			return fmt.Errorf("failed to remove old qclient symlink: %w", err)
		}
	}

	// Create qclient symlink pointing to qtools binary
	qclientCmd := exec.Command("sudo", "ln", "-sf", qtoolsBinaryPath, qclientSymlinkPath)
	if err := qclientCmd.Run(); err != nil {
		return fmt.Errorf("failed to create qclient symlink: %w", err)
	}

	fmt.Printf("✓ Created symlink: %s -> %s\n", qclientSymlinkPath, qtoolsBinaryPath)
	fmt.Println("  (qclient command will route to qtools qclient)")

	return nil
}

// findLatestNodeBinary finds the latest node binary in the directory
func findLatestNodeBinary(dir, osArch string) (string, error) {
	files, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}

	var latestBinary string
	var latestVersion string

	re := regexp.MustCompile(`node-([0-9]+\.[0-9]+(?:\.[0-9]+)?)-` + regexp.QuoteMeta(osArch))

	for _, file := range files {
		if file.IsDir() {
			continue
		}

		filename := file.Name()
		matches := re.FindStringSubmatch(filename)
		if len(matches) > 1 {
			version := matches[1]
			if latestVersion == "" || version > latestVersion {
				latestVersion = version
				latestBinary = filepath.Join(dir, filename)
			}
		}
	}

	if latestBinary == "" {
		return "", fmt.Errorf("no node binary found for %s", osArch)
	}

	return latestBinary, nil
}


// setupFirewall sets up firewall rules for node ports
func setupFirewall() error {
	if runtime.GOOS != "linux" {
		return nil // Only setup firewall on Linux
	}

	fmt.Println("Setting up firewall rules...")

	// Check if ufw is available
	cmd := exec.Command("which", "ufw")
	if err := cmd.Run(); err != nil {
		// ufw not available, try firewalld
		cmd = exec.Command("which", "firewall-cmd")
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("no supported firewall found (ufw or firewalld)")
		}
		return setupFirewalld()
	}

	return setupUFW()
}

// setupUFW sets up UFW firewall rules
func setupUFW() error {
	// Default ports for Quilibrium node
	ports := []string{
		"8336/tcp",  // P2P listen port
		"8337/tcp",  // gRPC port
		"8338/tcp",  // REST port
		"8340/tcp",  // Stream port
	}

	for _, port := range ports {
		cmd := exec.Command("sudo", "ufw", "allow", port)
		if err := cmd.Run(); err != nil {
			fmt.Printf("Warning: failed to allow port %s: %v\n", port, err)
		}
	}

	fmt.Println("✓ Firewall rules configured (UFW)")
	return nil
}

// setupFirewalld sets up firewalld firewall rules
func setupFirewalld() error {
	// Default ports for Quilibrium node
	ports := []string{
		"8336/tcp",  // P2P listen port
		"8337/tcp",  // gRPC port
		"8338/tcp",  // REST port
		"8340/tcp",  // Stream port
	}

	for _, port := range ports {
		cmd := exec.Command("sudo", "firewall-cmd", "--permanent", "--add-port", port)
		if err := cmd.Run(); err != nil {
			fmt.Printf("Warning: failed to add port %s: %v\n", port, err)
		}
	}

	// Reload firewall
	cmd := exec.Command("sudo", "firewall-cmd", "--reload")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to reload firewall: %w", err)
	}

	fmt.Println("✓ Firewall rules configured (firewalld)")
	return nil
}

// installDependencies installs required dependencies (Go, grpcurl)
func installDependencies() error {
	fmt.Println("Installing dependencies...")

	// Check if Go is installed
	cmd := exec.Command("go", "version")
	if err := cmd.Run(); err != nil {
		fmt.Println("Go not found, skipping Go installation (install manually if needed)")
	} else {
		fmt.Println("✓ Go is already installed")
	}

	// Check if grpcurl is installed
	cmd = exec.Command("grpcurl", "--version")
	if err := cmd.Run(); err != nil {
		fmt.Println("grpcurl not found, attempting to install...")
		if err := installGrpcurl(); err != nil {
			return fmt.Errorf("failed to install grpcurl: %w", err)
		}
	} else {
		fmt.Println("✓ grpcurl is already installed")
	}

	return nil
}

// installGrpcurl installs grpcurl using go install
func installGrpcurl() error {
	// Check if Go is available
	cmd := exec.Command("go", "version")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Go is required to install grpcurl")
	}

	fmt.Println("Installing grpcurl...")
	cmd = exec.Command("go", "install", "github.com/fullstorydev/grpcurl/cmd/grpcurl@latest")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to install grpcurl: %w\nOutput: %s", err, string(output))
	}

	fmt.Println("✓ grpcurl installed successfully")
	return nil
}

// generateDefaultConfig generates default config files
func generateDefaultConfig(cfg *config.Config) error {
	configPath := config.GetConfigPath()

	// Ensure config directory exists
	if err := config.EnsureConfigDirectory(); err != nil {
		return fmt.Errorf("failed to ensure config directory: %w", err)
	}

	// Save config
	if err := config.SaveConfig(cfg, configPath); err != nil {
		return fmt.Errorf("failed to save config: %w", err)
	}

	return nil
}
