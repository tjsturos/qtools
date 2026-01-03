package service

import (
	"fmt"
	"strconv"
	"strings"
)

// PlistConfig represents configuration for plist generation
type PlistConfig struct {
	Label                string
	ProgramArguments     []string
	RunAtLoad            bool
	KeepAlive            interface{} // bool or dict
	WorkingDirectory     string
	StandardOutPath      string
	StandardErrorPath    string
	EnvironmentVariables map[string]string
	ThrottleInterval     int // in seconds
	UserName             string // for system daemon
}

// GeneratePlist generates a plist XML file for macOS launchd
func GeneratePlist(config *ServiceConfig) ([]byte, error) {
	opts := config.ServiceOptions
	if opts == nil {
		return nil, fmt.Errorf("service options are required")
	}

	plistConfig := &PlistConfig{
		Label:            fmt.Sprintf("com.quilibrium.%s", config.ServiceName),
		WorkingDirectory: config.WorkingDir,
		RunAtLoad:        true,
	}

	// Build program arguments
	plistConfig.ProgramArguments = buildProgramArguments(config)

	// Set KeepAlive based on service type
	if config.IsWorker {
		// Workers restart on failure
		plistConfig.KeepAlive = map[string]bool{
			"SuccessfulExit": false,
		}
	} else {
		// Master always restarts
		plistConfig.KeepAlive = true
	}

	// Set throttle interval (restart delay)
	if config.IsWorker {
		plistConfig.ThrottleInterval = parseRestartTime(opts.WorkerRestartTime)
	} else {
		plistConfig.ThrottleInterval = parseRestartTime(opts.RestartTime)
	}

	// Build environment variables
	plistConfig.EnvironmentVariables = buildEnvironmentMap(config)

	// Set user name for system daemon
	if config.User != "" {
		plistConfig.UserName = config.User
	}

	// Generate XML
	return generatePlistXML(plistConfig)
}

// buildProgramArguments builds the program arguments array
func buildProgramArguments(config *ServiceConfig) []string {
	args := []string{config.BinaryPath}

	if config.ServiceOptions.Testnet {
		args = append(args, "--network=1")
	}
	if config.ServiceOptions.Debug {
		args = append(args, "--debug")
	}
	if config.ServiceOptions.SkipSignatureCheck {
		args = append(args, "--signature-check=false")
	}
	if config.IsWorker {
		args = append(args, "--core", fmt.Sprintf("%%i"))
	}

	return args
}

// buildEnvironmentMap builds environment variables map
func buildEnvironmentMap(config *ServiceConfig) map[string]string {
	env := make(map[string]string)
	opts := config.ServiceOptions

	if opts.IPFSDebug {
		env["IPFS_LOGGING"] = "debug"
	}
	if opts.GOGC != "" {
		env["GOGC"] = opts.GOGC
	}
	if opts.GOMEMLimit != "" {
		env["GOMEMLIMIT"] = opts.GOMEMLimit
	}

	return env
}

// parseRestartTime parses restart time string (e.g., "60s") to seconds
func parseRestartTime(timeStr string) int {
	timeStr = strings.TrimSpace(timeStr)
	if strings.HasSuffix(timeStr, "s") {
		timeStr = strings.TrimSuffix(timeStr, "s")
	}

	seconds, err := strconv.Atoi(timeStr)
	if err != nil {
		return 60 // Default
	}

	return seconds
}

// generatePlistXML generates the plist XML content
// This is a simplified implementation - for production, consider using github.com/DHowett/go-plist
func generatePlistXML(config *PlistConfig) ([]byte, error) {
	var buf strings.Builder
	
	buf.WriteString(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
`)
	
	// Add key-value pairs
	writePlistKeyValue(&buf, "Label", config.Label)
	writePlistKeyValue(&buf, "RunAtLoad", config.RunAtLoad)
	writePlistKeyValue(&buf, "WorkingDirectory", config.WorkingDirectory)
	
	// ProgramArguments
	buf.WriteString("    <key>ProgramArguments</key>\n")
	buf.WriteString("    <array>\n")
	for _, arg := range config.ProgramArguments {
		buf.WriteString(fmt.Sprintf("        <string>%s</string>\n", escapeXML(arg)))
	}
	buf.WriteString("    </array>\n")
	
	// KeepAlive
	buf.WriteString("    <key>KeepAlive</key>\n")
	if keepAliveDict, ok := config.KeepAlive.(map[string]bool); ok {
		buf.WriteString("    <dict>\n")
		for k, v := range keepAliveDict {
			buf.WriteString(fmt.Sprintf("        <key>%s</key>\n", escapeXML(k)))
			buf.WriteString(fmt.Sprintf("        <%t/>\n", v))
		}
		buf.WriteString("    </dict>\n")
	} else if keepAliveBool, ok := config.KeepAlive.(bool); ok {
		buf.WriteString(fmt.Sprintf("    <%t/>\n", keepAliveBool))
	}
	
	if config.ThrottleInterval > 0 {
		writePlistKeyValue(&buf, "ThrottleInterval", config.ThrottleInterval)
	}
	
	if config.UserName != "" {
		writePlistKeyValue(&buf, "UserName", config.UserName)
	}
	
	// EnvironmentVariables
	if len(config.EnvironmentVariables) > 0 {
		buf.WriteString("    <key>EnvironmentVariables</key>\n")
		buf.WriteString("    <dict>\n")
		for k, v := range config.EnvironmentVariables {
			buf.WriteString(fmt.Sprintf("        <key>%s</key>\n", escapeXML(k)))
			buf.WriteString(fmt.Sprintf("        <string>%s</string>\n", escapeXML(v)))
		}
		buf.WriteString("    </dict>\n")
	}
	
	buf.WriteString("</dict>\n")
	buf.WriteString("</plist>\n")
	
	return []byte(buf.String()), nil
}

// writePlistKeyValue writes a key-value pair to the plist
func writePlistKeyValue(buf *strings.Builder, key string, value interface{}) {
	buf.WriteString(fmt.Sprintf("    <key>%s</key>\n", escapeXML(key)))
	
	switch v := value.(type) {
	case string:
		buf.WriteString(fmt.Sprintf("    <string>%s</string>\n", escapeXML(v)))
	case bool:
		buf.WriteString(fmt.Sprintf("    <%t/>\n", v))
	case int:
		buf.WriteString(fmt.Sprintf("    <integer>%d</integer>\n", v))
	default:
		buf.WriteString(fmt.Sprintf("    <string>%v</string>\n", escapeXML(fmt.Sprintf("%v", v))))
	}
}

// escapeXML escapes XML special characters
func escapeXML(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&apos;")
	return s
}
