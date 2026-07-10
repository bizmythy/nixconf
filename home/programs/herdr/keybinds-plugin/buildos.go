package main

import (
	"bufio"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	buildosEntrypoint           = "new-buildos"
	buildosWorkspacePrefix      = "buildos-web-"
	buildosWorkspaceLabelPrefix = "🔩 "
	buildosSetupPaneWait        = 2 * time.Second
	buildosSetupPanePoll        = 50 * time.Millisecond
)

//go:embed buildos-setup.nu
var buildosSetupScript string

// openNewBuildos opens the buildos workspace setup pane as an overlay.
func (c *client) openNewBuildos() error {
	pane, err := c.currentPane()
	if err != nil {
		return err
	}
	return c.openPluginOverlay(buildosEntrypoint, activePaneCWD(pane), nil)
}

// newBuildos prompts for a suffix and schedules buildos setup in a new workspace.
func (c *client) newBuildos(nu string) error {
	suffix, err := promptBuildosName()
	if err != nil {
		return err
	}
	if suffix == "" {
		return nil
	}

	home, err := homeDir()
	if err != nil {
		return err
	}
	diracDir := filepath.Join(home, "dirac")
	workspaceName := buildosWorkspacePrefix + suffix
	newDir := filepath.Join(diracDir, workspaceName)

	setupScript, err := writeBuildosSetupScript()
	if err != nil {
		return err
	}
	exe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("resolve helper executable: %w", err)
	}

	workspace, err := c.createWorkspace(diracDir, workspaceName)
	if err != nil {
		return err
	}
	if workspace.WorkspaceID == "" {
		return errors.New("created buildos workspace did not have an id")
	}

	setupTab, setupPane, err := c.prepareBuildosSetupPane(workspace.WorkspaceID)
	if err != nil {
		return err
	}
	if setupPane.PaneID == "" {
		return errors.New("created buildos setup pane did not have an id")
	}

	return c.runPane(setupPane.PaneID, buildosSetupCommand(
		nu,
		setupScript,
		exe,
		workspaceName,
		workspace.WorkspaceID,
		newDir,
		setupTab.TabID,
	))
}

// promptBuildosName asks for the user-entered buildos workspace suffix.
func promptBuildosName() (string, error) {
	fmt.Fprintf(os.Stdout, "\x1b[36menter workspace name:\x1b[0m %s", buildosWorkspacePrefix)

	scanner := bufio.NewScanner(os.Stdin)
	if !scanner.Scan() {
		return "", scanner.Err()
	}

	suffix := strings.TrimSpace(scanner.Text())
	suffix = strings.TrimPrefix(suffix, buildosWorkspacePrefix)
	if suffix == "" {
		return "", nil
	}
	if strings.ContainsAny(suffix, `/\\`) {
		return "", fmt.Errorf("workspace suffix %q must not contain path separators", suffix)
	}

	return suffix, nil
}

// prepareBuildosSetupPane names the initial tab and returns its only pane.
func (c *client) prepareBuildosSetupPane(workspaceID string) (tabInfo, paneInfo, error) {
	tabs, err := c.tabs(workspaceID)
	if err != nil {
		return tabInfo{}, paneInfo{}, err
	}
	if len(tabs) == 0 {
		return tabInfo{}, paneInfo{}, errors.New("created buildos workspace did not have a tab")
	}

	setupTab := focusedTab(tabs)
	if setupTab.TabID == "" {
		setupTab = tabs[0]
	}
	if setupTab.Label != "setup" {
		if err := c.call("tab.rename", map[string]any{
			"label":  "setup",
			"tab_id": setupTab.TabID,
		}, nil); err != nil {
			return tabInfo{}, paneInfo{}, err
		}
		setupTab.Label = "setup"
	}

	pane, err := c.waitForPaneInTab(workspaceID, setupTab.TabID)
	if err != nil {
		return tabInfo{}, paneInfo{}, err
	}
	return setupTab, pane, nil
}

// waitForPaneInTab waits for Herdr to publish the freshly-created workspace pane.
func (c *client) waitForPaneInTab(workspaceID string, tabID string) (paneInfo, error) {
	deadline := time.Now().Add(buildosSetupPaneWait)
	var fallback paneInfo

	for {
		panes, err := c.panes(workspaceID)
		if err != nil {
			return paneInfo{}, err
		}
		for _, pane := range panes {
			if pane.TabID == tabID {
				return pane, nil
			}
		}
		if len(panes) > 0 && fallback.PaneID == "" {
			fallback = panes[0]
		}
		if time.Now().After(deadline) {
			if fallback.PaneID != "" {
				return fallback, nil
			}
			return paneInfo{}, errors.New("created buildos workspace did not have a pane")
		}
		time.Sleep(buildosSetupPanePoll)
	}
}

// buildosSetupCommand is the nushell command sent into the setup pane.
func buildosSetupCommand(nu string, script string, exe string, workspaceName string, workspaceID string, newDir string, setupTabID string) string {
	setup := nuExternalCommand(nu, script, workspaceName)
	finish := nuExternalCommand(exe, "finish-buildos", workspaceID, newDir, setupTabID)
	failed := nuExternalCommand(exe, "notify-buildos-failed", workspaceName)
	return fmt.Sprintf(
		"try { %s; %s } catch {|err| try { %s } catch {}; error make {msg: ($err.msg? | default ($err | to json --raw))} }",
		setup,
		finish,
		failed,
	)
}

// nuExternalCommand formats an external command invocation for nushell.
func nuExternalCommand(command string, args ...string) string {
	parts := []string{"^" + strconv.Quote(command)}
	for _, arg := range args {
		parts = append(parts, strconv.Quote(arg))
	}
	return strings.Join(parts, " ")
}

// writeBuildosSetupScript writes the embedded setup script into plugin state.
func writeBuildosSetupScript() (string, error) {
	stateDir, err := pluginStateDir()
	if err != nil {
		return "", err
	}

	scriptPath := filepath.Join(stateDir, "buildos-setup.nu")
	if err := os.WriteFile(scriptPath, []byte(buildosSetupScript), 0o600); err != nil {
		return "", fmt.Errorf("write buildos setup script: %w", err)
	}
	return scriptPath, nil
}

// finishBuildos opens normal tabs in the new repo and removes the setup tab.
func (c *client) finishBuildos(workspaceID string, newDir string, setupTabID string) error {
	if info, err := os.Stat(newDir); err != nil {
		return fmt.Errorf("stat buildos workspace directory: %w", err)
	} else if !info.IsDir() {
		return fmt.Errorf("buildos workspace path is not a directory: %s", newDir)
	}

	// Open tabs without focus so a long-running setup does not yank the user
	// away if they already switched back to another workspace.
	if err := c.ensureWorkspaceTab(workspaceID, newDir, "ws", false); err != nil {
		return err
	}
	if err := c.ensureWorkspaceTab(workspaceID, newDir, "1", false); err != nil {
		return err
	}
	if setupTabID != "" {
		if err := c.call("tab.close", map[string]any{"tab_id": setupTabID}, nil); err != nil && !isMissingObject(err) {
			return err
		}
	}

	return nil
}

// ensureWorkspaceTab creates a tab unless one with the same label already exists.
func (c *client) ensureWorkspaceTab(workspaceID string, cwd string, label string, focus bool) error {
	tabs, err := c.tabs(workspaceID)
	if err != nil {
		return err
	}
	for _, tab := range tabs {
		if tab.Label == label {
			if focus {
				return c.call("tab.focus", map[string]any{"tab_id": tab.TabID}, nil)
			}
			return nil
		}
	}

	return c.call("tab.create", map[string]any{
		"cwd":          cwd,
		"focus":        focus,
		"label":        label,
		"workspace_id": workspaceID,
	}, nil)
}

// notifyBuildosFailed sends an in-app notification for a failed setup run.
func (c *client) notifyBuildosFailed(workspaceName string) error {
	return c.notify(
		"buildos setup failed",
		fmt.Sprintf("%s setup failed; leaving the setup tab open", workspaceName),
	)
}

// notify sends a Herdr notification.
func (c *client) notify(title string, body string) error {
	return c.call("notification.show", map[string]any{
		"body":  body,
		"sound": "request",
		"title": title,
	}, nil)
}

// runPane starts a command in an existing pane.
func (c *client) runPane(paneID string, command string) error {
	return c.call("pane.send_input", map[string]any{
		"keys":    []string{"Enter"},
		"pane_id": paneID,
		"text":    command,
	}, nil)
}

// isMissingObject recognizes failures for already-gone Herdr objects.
func isMissingObject(err error) bool {
	var apiErr *apiCallError
	if !errors.As(err, &apiErr) {
		return false
	}
	return apiErr.Code == "not_found" || strings.HasSuffix(apiErr.Code, "_not_found")
}
