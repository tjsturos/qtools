package main

import (
	"github.com/spf13/cobra"
)

// registerCompletions registers custom completions for flags
func registerCompletions(rootCmd *cobra.Command) {
	// Register completion for --config flag in node config commands
	registerConfigTypeCompletion(rootCmd)
}

func registerConfigTypeCompletion(rootCmd *cobra.Command) {
	// Find node config commands
	nodeCmd := findCommand(rootCmd, "node")
	if nodeConfigCmd := findCommand(nodeCmd, "config"); nodeConfigCmd != nil {
		// Register for get and set subcommands
		if getCmd := findCommand(nodeConfigCmd, "get"); getCmd != nil {
			if flag := getCmd.Flags().Lookup("config"); flag != nil {
				flag.NoOptDefVal = "qtools"
				getCmd.RegisterFlagCompletionFunc("config", func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
					return []string{"qtools", "quil"}, cobra.ShellCompDirectiveNoFileComp
				})
			}
		}
		if setCmd := findCommand(nodeConfigCmd, "set"); setCmd != nil {
			if flag := setCmd.Flags().Lookup("config"); flag != nil {
				flag.NoOptDefVal = "qtools"
				setCmd.RegisterFlagCompletionFunc("config", func(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
					return []string{"qtools", "quil"}, cobra.ShellCompDirectiveNoFileComp
				})
			}
		}
	}
}

// findCommand recursively finds a command by name
func findCommand(cmd *cobra.Command, name string) *cobra.Command {
	if cmd.Name() == name {
		return cmd
	}
	for _, subCmd := range cmd.Commands() {
		if found := findCommand(subCmd, name); found != nil {
			return found
		}
	}
	return nil
}
