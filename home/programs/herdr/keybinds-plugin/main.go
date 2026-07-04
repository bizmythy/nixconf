// Package main implements the herdr-keybinds helper CLI.
package main

import (
	"errors"
	"fmt"
	"log/slog"
	"os"

	"github.com/spf13/cobra"
)

var logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
	ReplaceAttr: func(_ []string, attr slog.Attr) slog.Attr {
		if attr.Key == slog.TimeKey {
			return slog.Attr{}
		}
		return attr
	},
}))

// main builds the CLI and logs any command failure in structured form.
func main() {
	rootCmd := newRootCommand()
	if err := rootCmd.Execute(); err != nil {
		logger.Error("command failed", "error", err)
		os.Exit(1)
	}
}

// newRootCommand wires every keybinding action into the Cobra command tree.
func newRootCommand() *cobra.Command {
	rootCmd := &cobra.Command{
		Use:           "herdr-keybinds",
		Short:         "Herdr keybinding helper plugin",
		Args:          cobra.NoArgs,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, _ []string) error {
			cmd.SilenceUsage = true
			if err := cmd.Help(); err != nil {
				return err
			}
			return errors.New("missing command")
		},
	}

	rootCmd.AddCommand(
		&cobra.Command{
			Use:       "navigate <left|right|up|down>",
			Short:     "Navigate to a neighboring pane, tab, or workspace",
			Args:      cobra.MatchAll(cobra.ExactArgs(1), cobra.OnlyValidArgs),
			ValidArgs: []string{"left", "right", "up", "down"},
			RunE: func(_ *cobra.Command, args []string) error {
				dir, _ := parseDirection(args[0])
				return runWithClient(func(c *client) error {
					return c.navigate(dir)
				})
			},
		},
		&cobra.Command{
			Use:   "focus-tab <label>",
			Short: "Focus the tab with the given label",
			Args:  cobra.ExactArgs(1),
			RunE: func(_ *cobra.Command, args []string) error {
				return runWithClient(func(c *client) error {
					return c.focusTabLabel(args[0])
				})
			},
		},
		&cobra.Command{
			Use:   "toggle-lazygit",
			Short: "Toggle the lazygit overlay pane",
			Args:  cobra.NoArgs,
			RunE: func(_ *cobra.Command, _ []string) error {
				return runWithClient(func(c *client) error {
					return c.toggleLazygit()
				})
			},
		},
		&cobra.Command{
			Use:   "new-workspace-picker [fzf]",
			Short: "Open the workspace picker overlay or run it inside the picker pane",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(_ *cobra.Command, args []string) error {
				fzf := "fzf"
				if len(args) == 1 {
					fzf = args[0]
				}
				return runWithClient(func(c *client) error {
					if os.Getenv("HERDR_WORKSPACE_PICKER_PANE") == "1" {
						return c.newWorkspacePicker(fzf)
					}
					return c.openWorkspacePicker()
				})
			},
		},
		&cobra.Command{
			Use:   "new-buildos [nu]",
			Short: "Create a fresh buildos-web workspace",
			Args:  cobra.MaximumNArgs(1),
			RunE: func(_ *cobra.Command, args []string) error {
				nu := "nu"
				if len(args) == 1 {
					nu = args[0]
				}
				return runWithClient(func(c *client) error {
					if os.Getenv("HERDR_NEW_BUILDOS_PANE") == "1" {
						return c.newBuildos(nu)
					}
					return c.openNewBuildos()
				})
			},
		},
		&cobra.Command{
			Use:    "finish-buildos <workspace-id> <directory> <setup-tab-id>",
			Short:  "Finish buildos workspace setup after repository creation",
			Args:   cobra.ExactArgs(3),
			Hidden: true,
			RunE: func(_ *cobra.Command, args []string) error {
				return runWithClient(func(c *client) error {
					return c.finishBuildos(args[0], args[1], args[2])
				})
			},
		},
		&cobra.Command{
			Use:    "notify-buildos-failed <workspace-name>",
			Short:  "Notify that buildos workspace setup failed",
			Args:   cobra.ExactArgs(1),
			Hidden: true,
			RunE: func(_ *cobra.Command, args []string) error {
				return runWithClient(func(c *client) error {
					return c.notifyBuildosFailed(args[0])
				})
			},
		},
	)

	return rootCmd
}

// runWithClient creates a Herdr client and runs one command action with it.
func runWithClient(action func(*client) error) error {
	c, err := newClient()
	if err != nil {
		return fmt.Errorf("create client: %w", err)
	}
	return action(c)
}
