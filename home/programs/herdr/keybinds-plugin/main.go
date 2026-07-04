// Package main implements the herdr-keybinds helper CLI.
package main

import (
	"bufio"
	"bytes"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
)

// Direction identifies a directional navigation target.
type Direction uint8

const (
	directionInvalid Direction = iota
	directionDown
	directionLeft
	directionRight
	directionUp
)

const (
	pluginID                  = "drew.herdr-keybinds"
	buildosEntrypoint         = "new-buildos"
	buildosWorkspacePrefix    = "buildos-web-"
	lazygitEntrypoint         = "lazygit"
	workspacePickerEntrypoint = "new-workspace-picker"
	stateFileName             = "state.json"
)

// client sends JSON RPC requests to the Herdr Unix socket.
type client struct {
	nextID     int
	socketPath string
}

// apiError is the error object returned by Herdr RPC responses.
type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// apiCallError wraps a Herdr API error as a Go error.
type apiCallError struct {
	Code    string
	Message string
}

// Error returns the Herdr API error code and message.
func (err *apiCallError) Error() string {
	return fmt.Sprintf("%s: %s", err.Code, err.Message)
}

// response is the common envelope returned by Herdr RPC calls.
type response struct {
	ID     string          `json:"id"`
	Result json.RawMessage `json:"result"`
	Error  *apiError       `json:"error"`
}

// paneInfo is the subset of Herdr pane metadata needed by this helper.
type paneInfo struct {
	CWD           string `json:"cwd"`
	Focused       bool   `json:"focused"`
	ForegroundCWD string `json:"foreground_cwd"`
	Label         string `json:"label"`
	PaneID        string `json:"pane_id"`
	TabID         string `json:"tab_id"`
	Title         string `json:"title"`
	WorkspaceID   string `json:"workspace_id"`
}

// tabInfo is the subset of Herdr tab metadata needed by this helper.
type tabInfo struct {
	Focused     bool   `json:"focused"`
	Label       string `json:"label"`
	Number      int    `json:"number"`
	PaneCount   int    `json:"pane_count"`
	TabID       string `json:"tab_id"`
	WorkspaceID string `json:"workspace_id"`
}

// focusID returns the identifier used by tab.focus.
func (tab tabInfo) focusID() string { return tab.TabID }

// isFocused reports whether the tab is Herdr's current tab.
func (tab tabInfo) isFocused() bool { return tab.Focused }

// number returns the user-visible tab ordering number.
func (tab tabInfo) number() int { return tab.Number }

// workspaceInfo is the subset of Herdr workspace metadata needed here.
type workspaceInfo struct {
	Focused     bool   `json:"focused"`
	Label       string `json:"label"`
	Number      int    `json:"number"`
	WorkspaceID string `json:"workspace_id"`
}

// focusID returns the identifier used by workspace.focus.
func (workspace workspaceInfo) focusID() string { return workspace.WorkspaceID }

// isFocused reports whether the workspace is Herdr's current workspace.
func (workspace workspaceInfo) isFocused() bool { return workspace.Focused }

// number returns the user-visible workspace ordering number.
func (workspace workspaceInfo) number() int { return workspace.Number }

// workspaceChoice is one selectable workspace candidate for the picker.
type workspaceChoice struct {
	Display string
	Path    string
}

// pluginPaneInfo describes a plugin pane returned by plugin.pane.open.
type pluginPaneInfo struct {
	Entrypoint string   `json:"entrypoint"`
	Pane       paneInfo `json:"pane"`
	PluginID   string   `json:"plugin_id"`
}

// pluginPaneOpenResult is the typed result for plugin.pane.open.
type pluginPaneOpenResult struct {
	PluginPane pluginPaneInfo `json:"plugin_pane"`
	Type       string         `json:"type"`
}

// pluginState is persisted across invocations to track helper-owned panes.
type pluginState struct {
	LazygitPanes map[string]string `json:"lazygit_panes"`
}

// paneEdges reports which sides of a pane are at the edge of its tab layout.
type paneEdges struct {
	Down  bool `json:"down"`
	Left  bool `json:"left"`
	Right bool `json:"right"`
	Up    bool `json:"up"`
}

// context stores the active Herdr IDs needed by navigation operations.
type context struct {
	PaneID      string
	TabID       string
	WorkspaceID string
}

// numberedFocusable is implemented by ordered Herdr objects that can be focused.
type numberedFocusable interface {
	focusID() string
	isFocused() bool
	number() int
}

//go:embed buildos-setup.nu
var buildosSetupScript string

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
		&cobra.Command{
			Use:   "setup-workspace",
			Short: "Initialize tabs for a newly-created workspace",
			Args:  cobra.NoArgs,
			RunE: func(_ *cobra.Command, _ []string) error {
				return runWithClient(func(c *client) error {
					return c.setupWorkspace()
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

// newClient resolves the Herdr socket path and returns a ready RPC client.
func newClient() (*client, error) {
	socketPath := os.Getenv("HERDR_SOCKET_PATH")
	if socketPath == "" {
		configHome, err := xdgBaseDir("XDG_CONFIG_HOME", ".config")
		if err != nil {
			return nil, err
		}
		socketPath = filepath.Join(configHome, "herdr", "herdr.sock")
	}

	return &client{socketPath: socketPath}, nil
}

// call sends one JSON RPC request to Herdr and decodes its result into out.
func (c *client) call(method string, params map[string]any, out any) error {
	c.nextID++
	id := fmt.Sprintf("herdr-keybinds-%d", c.nextID)
	if params == nil {
		params = map[string]any{}
	}

	request := map[string]any{
		"id":     id,
		"method": method,
		"params": params,
	}

	payload, err := json.Marshal(request)
	if err != nil {
		return fmt.Errorf("encode %s request: %w", method, err)
	}
	payload = append(payload, '\n')

	dialer := net.Dialer{Timeout: 150 * time.Millisecond}
	conn, err := dialer.Dial("unix", c.socketPath)
	if err != nil {
		return fmt.Errorf("dial Herdr socket %s for %s: %w", c.socketPath, method, err)
	}
	defer conn.Close()

	if _, err := conn.Write(payload); err != nil {
		return fmt.Errorf("write %s request: %w", method, err)
	}

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		return fmt.Errorf("read %s response: %w", method, err)
	}

	var envelope response
	if err := json.Unmarshal(line, &envelope); err != nil {
		return fmt.Errorf("decode %s response: %w", method, err)
	}
	if envelope.Error != nil {
		return &apiCallError{
			Code:    envelope.Error.Code,
			Message: envelope.Error.Message,
		}
	}
	if envelope.ID != id {
		return fmt.Errorf("unexpected response id %q for %q", envelope.ID, id)
	}
	if out == nil {
		return nil
	}
	if err := json.Unmarshal(envelope.Result, out); err != nil {
		return fmt.Errorf("decode %s result: %w", method, err)
	}

	return nil
}

// navigate focuses a pane in dir, falling back to tabs or workspaces at edges.
func (c *client) navigate(dir Direction) error {
	ctx, err := c.resolveContext()
	if err != nil {
		return err
	}
	if active, err := c.isActiveLazygitOverlay(ctx); err != nil {
		return err
	} else if active {
		return nil
	}

	edges, err := c.paneEdges(ctx.PaneID)
	if err != nil {
		return err
	}

	if !edgeValue(edges, dir) {
		params := map[string]any{"direction": dir.String()}
		if ctx.PaneID != "" {
			params["caller_pane_id"] = ctx.PaneID
		}
		return c.call("pane.focus_direction", params, nil)
	}

	switch dir {
	case directionLeft, directionRight:
		return c.fallbackTab(ctx, dir)
	case directionUp, directionDown:
		return c.fallbackWorkspace(ctx, dir)
	default:
		return nil
	}
}

// focusTabLabel focuses the first tab in the current workspace with label.
func (c *client) focusTabLabel(label string) error {
	ctx, err := c.resolveContext()
	if err != nil {
		return err
	}

	tabs, err := c.tabs(ctx.WorkspaceID)
	if err != nil {
		return err
	}

	for _, tab := range tabs {
		if tab.Label == label {
			return c.call("tab.focus", map[string]any{"tab_id": tab.TabID}, nil)
		}
	}

	return nil
}

// toggleLazygit closes an existing workspace overlay or opens a new one.
func (c *client) toggleLazygit() error {
	pane, err := c.currentPane()
	if err != nil {
		return err
	}
	if pane.WorkspaceID == "" {
		return errors.New("could not resolve active workspace for lazygit overlay")
	}

	state, statePath, err := loadPluginState()
	if err != nil {
		return err
	}

	if paneID := state.LazygitPanes[pane.WorkspaceID]; paneID != "" {
		closeErr := c.call("plugin.pane.close", map[string]any{"pane_id": paneID}, nil)
		delete(state.LazygitPanes, pane.WorkspaceID)
		saveErr := savePluginState(statePath, state)
		if closeErr == nil {
			return saveErr
		}
		if !isMissingPluginPane(closeErr) {
			return closeErr
		}
		if saveErr != nil {
			return saveErr
		}
	}

	cwd := activePaneCWD(pane)
	if cwd == "" {
		return errors.New("could not resolve active pane cwd for lazygit overlay")
	}

	var result pluginPaneOpenResult
	if err := c.openPluginOverlay(lazygitEntrypoint, cwd, &result); err != nil {
		return err
	}

	openedPane := result.PluginPane.Pane
	if openedPane.PaneID == "" || openedPane.WorkspaceID == "" {
		return nil
	}
	state.LazygitPanes[openedPane.WorkspaceID] = openedPane.PaneID
	return savePluginState(statePath, state)
}

// openWorkspacePicker opens the workspace picker plugin pane as an overlay.
func (c *client) openWorkspacePicker() error {
	pane, err := c.currentPane()
	if err != nil {
		return err
	}
	return c.openPluginOverlay(workspacePickerEntrypoint, activePaneCWD(pane), nil)
}

// openNewBuildos opens the buildos workspace setup pane as an overlay.
func (c *client) openNewBuildos() error {
	pane, err := c.currentPane()
	if err != nil {
		return err
	}
	return c.openPluginOverlay(buildosEntrypoint, activePaneCWD(pane), nil)
}

// activePaneCWD chooses the best cwd to pass to plugin overlays.
func activePaneCWD(pane paneInfo) string {
	return firstNonEmpty(pane.ForegroundCWD, pane.CWD, firstEnv("HERDR_ACTIVE_PANE_CWD"))
}

// openPluginOverlay opens a helper-owned plugin pane in overlay placement.
func (c *client) openPluginOverlay(entrypoint string, cwd string, out any) error {
	params := map[string]any{
		"entrypoint": entrypoint,
		"focus":      true,
		"placement":  "overlay",
		"plugin_id":  pluginID,
	}
	if cwd != "" {
		params["cwd"] = cwd
	}

	return c.call("plugin.pane.open", params, out)
}

// newWorkspacePicker runs fzf and opens or focuses the selected workspace.
func (c *client) newWorkspacePicker(fzf string) error {
	home, err := homeDir()
	if err != nil {
		return err
	}

	choices, err := workspaceChoicesFor(home, []string{"personal", "dirac"})
	if err != nil {
		return err
	}
	if len(choices) == 0 {
		return nil
	}

	selected, err := chooseWorkspace(fzf, choices)
	if err != nil {
		return err
	}
	if selected == nil {
		return nil
	}

	return c.openOrFocusWorkspace(selected.Path, filepath.Base(selected.Path))
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

	panes, err := c.panes(workspaceID)
	if err != nil {
		return tabInfo{}, paneInfo{}, err
	}
	for _, pane := range panes {
		if pane.TabID == setupTab.TabID {
			return setupTab, pane, nil
		}
	}
	if len(panes) > 0 {
		return setupTab, panes[0], nil
	}

	return tabInfo{}, paneInfo{}, errors.New("created buildos workspace did not have a pane")
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

	if err := c.ensureWorkspaceTab(workspaceID, newDir, "ws", false); err != nil {
		return err
	}
	if err := c.ensureWorkspaceTab(workspaceID, newDir, "1", true); err != nil {
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
	return c.call("pane.run", map[string]any{
		"command": command,
		"pane_id": paneID,
	}, nil)
}

// openOrFocusWorkspace focuses an existing cwd workspace or creates it.
func (c *client) openOrFocusWorkspace(cwd string, label string) error {
	workspaceID, err := c.workspaceIDForCWD(cwd)
	if err != nil {
		return err
	}
	if workspaceID != "" {
		return c.call("workspace.focus", map[string]any{"workspace_id": workspaceID}, nil)
	}

	_, err = c.createWorkspace(cwd, label)
	return err
}

// createWorkspace creates a focused Herdr workspace and returns its metadata.
func (c *client) createWorkspace(cwd string, label string) (workspaceInfo, error) {
	var result struct {
		Type      string        `json:"type"`
		Workspace workspaceInfo `json:"workspace"`
	}
	if err := c.call("workspace.create", map[string]any{
		"cwd":   cwd,
		"focus": true,
		"label": label,
	}, &result); err != nil {
		return workspaceInfo{}, err
	}
	if result.Workspace.WorkspaceID != "" {
		return result.Workspace, nil
	}

	workspaces, err := c.workspaces()
	if err != nil {
		return workspaceInfo{}, err
	}
	for _, workspace := range workspaces {
		if workspace.Focused && workspace.Label == label {
			return workspace, nil
		}
	}
	for _, workspace := range workspaces {
		if workspace.Label == label {
			return workspace, nil
		}
	}

	return workspaceInfo{}, nil
}

// workspaceIDForCWD returns the workspace that already contains cwd.
func (c *client) workspaceIDForCWD(cwd string) (string, error) {
	var result struct {
		Panes []paneInfo `json:"panes"`
		Type  string     `json:"type"`
	}
	if err := c.call("pane.list", nil, &result); err != nil {
		return "", err
	}

	wanted := filepath.Clean(cwd)
	for _, pane := range result.Panes {
		if pane.CWD != "" && filepath.Clean(pane.CWD) == wanted {
			return pane.WorkspaceID, nil
		}
	}

	return "", nil
}

// workspaceChoicesFor scans root directories under home for picker choices.
func workspaceChoicesFor(home string, roots []string) ([]workspaceChoice, error) {
	choices := make([]workspaceChoice, 0)
	for _, rootName := range roots {
		rootPath := filepath.Join(home, rootName)
		entries, err := os.ReadDir(rootPath)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("read %s: %w", rootPath, err)
		}

		for _, entry := range entries {
			if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") {
				continue
			}

			display := filepath.ToSlash(filepath.Join(rootName, entry.Name()))
			choices = append(choices, workspaceChoice{
				Display: display,
				Path:    filepath.Join(rootPath, entry.Name()),
			})
		}
	}

	sort.Slice(choices, func(i, j int) bool {
		return choices[i].Display < choices[j].Display
	})

	return choices, nil
}

// chooseWorkspace asks fzf to select one workspace choice.
func chooseWorkspace(fzf string, choices []workspaceChoice) (*workspaceChoice, error) {
	byDisplay := make(map[string]*workspaceChoice, len(choices))
	lines := make([]string, 0, len(choices))
	for index := range choices {
		choice := &choices[index]
		byDisplay[choice.Display] = choice
		lines = append(lines, choice.Display)
	}

	cmd := exec.Command(fzf, "--prompt=workspace> ")
	cmd.Stdin = strings.NewReader(strings.Join(lines, "\n") + "\n")
	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		var exitError *exec.ExitError
		if errors.As(err, &exitError) {
			return nil, nil
		}
		return nil, fmt.Errorf("run fzf: %w", err)
	}

	selected := strings.TrimRight(stdout.String(), "\r\n")
	if selected == "" {
		return nil, nil
	}

	choice, ok := byDisplay[selected]
	if !ok {
		return nil, nil
	}

	return choice, nil
}

// homeDir returns HOME when set and otherwise falls back to os.UserHomeDir.
func homeDir() (string, error) {
	if home := os.Getenv("HOME"); home != "" {
		return home, nil
	}
	return os.UserHomeDir()
}

// xdgBaseDir returns an XDG base directory or a path under home when unset.
func xdgBaseDir(envName string, fallbackRel string) (string, error) {
	if value := os.Getenv(envName); value != "" {
		return value, nil
	}
	home, err := homeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, fallbackRel), nil
}

// currentPane returns the active pane, honoring caller pane env overrides.
func (c *client) currentPane() (paneInfo, error) {
	return c.currentPaneFor(firstEnv("HERDR_PANE_ID", "HERDR_ACTIVE_PANE_ID"))
}

// currentPaneFor returns the current pane from Herdr, optionally scoped to paneID.
func (c *client) currentPaneFor(paneID string) (paneInfo, error) {
	params := map[string]any{}
	if paneID != "" {
		params["caller_pane_id"] = paneID
	}

	var result struct {
		Pane paneInfo `json:"pane"`
		Type string   `json:"type"`
	}
	if err := c.call("pane.current", params, &result); err != nil {
		return paneInfo{}, err
	}

	return result.Pane, nil
}

// isActiveLazygitOverlay reports whether navigation should stay inside lazygit.
func (c *client) isActiveLazygitOverlay(ctx context) (bool, error) {
	if ctx.WorkspaceID == "" || ctx.PaneID == "" {
		return false, nil
	}
	state, _, err := loadPluginState()
	if err != nil {
		return false, err
	}
	if state.LazygitPanes[ctx.WorkspaceID] != ctx.PaneID {
		return false, nil
	}

	pane, err := c.currentPane()
	if err != nil {
		return false, err
	}
	return pane.PaneID == ctx.PaneID && firstNonEmpty(pane.Label, pane.Title) == lazygitEntrypoint, nil
}

// loadPluginState reads persisted helper state, creating defaults if absent.
func loadPluginState() (pluginState, string, error) {
	statePath, err := pluginStatePath()
	if err != nil {
		return pluginState{}, "", err
	}

	state := pluginState{LazygitPanes: make(map[string]string)}
	data, err := os.ReadFile(statePath)
	if errors.Is(err, os.ErrNotExist) {
		return state, statePath, nil
	}
	if err != nil {
		return pluginState{}, "", fmt.Errorf("read plugin state: %w", err)
	}
	if len(data) == 0 {
		return state, statePath, nil
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return pluginState{}, "", fmt.Errorf("decode plugin state: %w", err)
	}
	if state.LazygitPanes == nil {
		state.LazygitPanes = make(map[string]string)
	}

	return state, statePath, nil
}

// savePluginState atomically writes helper state to disk.
func savePluginState(statePath string, state pluginState) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("encode plugin state: %w", err)
	}

	tmpPath := statePath + ".tmp"
	if err := os.WriteFile(tmpPath, append(data, '\n'), 0o600); err != nil {
		return fmt.Errorf("write plugin state: %w", err)
	}
	if err := os.Rename(tmpPath, statePath); err != nil {
		return fmt.Errorf("replace plugin state: %w", err)
	}

	return nil
}

// pluginStatePath resolves and creates the path for persisted state.
func pluginStatePath() (string, error) {
	stateDir, err := pluginStateDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(stateDir, stateFileName), nil
}

// pluginStateDir resolves and creates the directory for persisted helper state.
func pluginStateDir() (string, error) {
	stateDir := os.Getenv("HERDR_PLUGIN_STATE_DIR")
	if stateDir == "" {
		stateHome, err := xdgBaseDir("XDG_STATE_HOME", filepath.Join(".local", "state"))
		if err != nil {
			return "", err
		}
		stateDir = filepath.Join(stateHome, "herdr-keybinds")
	}
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		return "", fmt.Errorf("create plugin state dir: %w", err)
	}
	return stateDir, nil
}

// isMissingPluginPane recognizes close failures for already-gone plugin panes.
func isMissingPluginPane(err error) bool {
	var apiErr *apiCallError
	if !errors.As(err, &apiErr) {
		return false
	}
	return apiErr.Code == "plugin_pane_not_found" || apiErr.Code == "pane_not_found" || apiErr.Code == "not_found"
}

// isMissingObject recognizes failures for already-gone Herdr objects.
func isMissingObject(err error) bool {
	var apiErr *apiCallError
	if !errors.As(err, &apiErr) {
		return false
	}
	return apiErr.Code == "not_found" || strings.HasSuffix(apiErr.Code, "_not_found")
}

// setupWorkspace renames the starter tab and creates the first work tab.
func (c *client) setupWorkspace() error {
	workspaceID, err := c.workspaceIDForSetup()
	if err != nil {
		return err
	}
	if workspaceID == "" {
		return nil
	}
	if workspaceEventLooksBuildos() {
		return nil
	}
	if label, err := c.workspaceLabel(workspaceID); err != nil {
		return err
	} else if strings.HasPrefix(label, buildosWorkspacePrefix) {
		return nil
	}

	tabs, err := c.tabs(workspaceID)
	if err != nil {
		return err
	}
	if len(tabs) != 1 {
		return nil
	}
	if tabs[0].Label == "ws" {
		return nil
	}
	if tabs[0].PaneCount != 1 {
		return nil
	}

	if err := c.call("tab.rename", map[string]any{
		"label":  "ws",
		"tab_id": tabs[0].TabID,
	}, nil); err != nil {
		return err
	}
	return c.call("tab.create", map[string]any{
		"focus":        true,
		"label":        "1",
		"workspace_id": workspaceID,
	}, nil)
}

// fallbackTab moves left or right by tab number when pane navigation hits an edge.
func (c *client) fallbackTab(ctx context, dir Direction) error {
	tabs, err := c.tabs(ctx.WorkspaceID)
	if err != nil {
		return err
	}

	current, ok := currentItem(tabs, ctx.TabID)
	if !ok {
		return nil
	}
	target, ok := adjacentByNumber(tabs, current, dir == directionRight)
	if !ok {
		return nil
	}

	return c.call("tab.focus", map[string]any{"tab_id": target.focusID()}, nil)
}

// fallbackWorkspace moves up or down by workspace number at pane layout edges.
func (c *client) fallbackWorkspace(ctx context, dir Direction) error {
	workspaces, err := c.workspaces()
	if err != nil {
		return err
	}

	current, ok := currentItem(workspaces, ctx.WorkspaceID)
	if !ok {
		return nil
	}
	target, ok := adjacentByNumber(workspaces, current, dir == directionDown)
	if !ok {
		return nil
	}

	return c.call("workspace.focus", map[string]any{"workspace_id": target.focusID()}, nil)
}

// resolveContext fills active pane, tab, and workspace IDs from env or Herdr.
func (c *client) resolveContext() (context, error) {
	ctx := context{
		PaneID:      firstEnv("HERDR_PANE_ID", "HERDR_ACTIVE_PANE_ID"),
		TabID:       firstEnv("HERDR_TAB_ID", "HERDR_ACTIVE_TAB_ID"),
		WorkspaceID: firstEnv("HERDR_WORKSPACE_ID", "HERDR_ACTIVE_WORKSPACE_ID"),
	}
	if ctx.PaneID != "" && ctx.TabID != "" && ctx.WorkspaceID != "" {
		return ctx, nil
	}

	pane, err := c.currentPaneFor(ctx.PaneID)
	if err != nil {
		return ctx, err
	}

	if ctx.PaneID == "" {
		ctx.PaneID = pane.PaneID
	}
	if ctx.TabID == "" {
		ctx.TabID = pane.TabID
	}
	if ctx.WorkspaceID == "" {
		ctx.WorkspaceID = pane.WorkspaceID
	}

	return ctx, nil
}

// workspaceIDForSetup finds the workspace from the Herdr event or context.
func (c *client) workspaceIDForSetup() (string, error) {
	if workspaceID := workspaceIDFromEvent(); workspaceID != "" {
		return workspaceID, nil
	}

	ctx, err := c.resolveContext()
	if err != nil {
		return "", err
	}
	return ctx.WorkspaceID, nil
}

// paneEdges asks Herdr which layout edges paneID touches.
func (c *client) paneEdges(paneID string) (paneEdges, error) {
	params := map[string]any{}
	if paneID != "" {
		params["pane_id"] = paneID
	}

	var result struct {
		Edges paneEdges `json:"edges"`
		Type  string    `json:"type"`
	}
	if err := c.call("pane.edges", params, &result); err != nil {
		return paneEdges{}, err
	}

	return result.Edges, nil
}

// panes lists panes, optionally scoped to one workspace.
func (c *client) panes(workspaceID string) ([]paneInfo, error) {
	params := map[string]any{}
	if workspaceID != "" {
		params["workspace_id"] = workspaceID
	}

	var result struct {
		Panes []paneInfo `json:"panes"`
		Type  string     `json:"type"`
	}
	if err := c.call("pane.list", params, &result); err != nil {
		return nil, err
	}

	return result.Panes, nil
}

// tabs lists tabs in a workspace sorted by tab number.
func (c *client) tabs(workspaceID string) ([]tabInfo, error) {
	params := map[string]any{}
	if workspaceID != "" {
		params["workspace_id"] = workspaceID
	}

	var result struct {
		Tabs []tabInfo `json:"tabs"`
		Type string    `json:"type"`
	}
	if err := c.call("tab.list", params, &result); err != nil {
		return nil, err
	}

	sortByNumber(result.Tabs)
	return result.Tabs, nil
}

// workspaces lists all workspaces sorted by workspace number.
func (c *client) workspaces() ([]workspaceInfo, error) {
	var result struct {
		Type       string          `json:"type"`
		Workspaces []workspaceInfo `json:"workspaces"`
	}
	if err := c.call("workspace.list", nil, &result); err != nil {
		return nil, err
	}

	sortByNumber(result.Workspaces)
	return result.Workspaces, nil
}

// workspaceLabel returns the label for a workspace ID, if present.
func (c *client) workspaceLabel(workspaceID string) (string, error) {
	workspaces, err := c.workspaces()
	if err != nil {
		return "", err
	}
	for _, workspace := range workspaces {
		if workspace.WorkspaceID == workspaceID {
			return workspace.Label, nil
		}
	}
	return "", nil
}

// sortByNumber orders Herdr entities by their user-visible number.
func sortByNumber[T numberedFocusable](items []T) {
	sort.Slice(items, func(i, j int) bool {
		return items[i].number() < items[j].number()
	})
}

// currentItem returns the focused item, falling back to a matching ID.
func currentItem[T numberedFocusable](items []T, id string) (T, bool) {
	for _, item := range items {
		if item.isFocused() {
			return item, true
		}
	}
	for _, item := range items {
		if id != "" && item.focusID() == id {
			return item, true
		}
	}
	var zero T
	return zero, false
}

// focusedTab returns the focused tab from a list, if present.
func focusedTab(tabs []tabInfo) tabInfo {
	for _, tab := range tabs {
		if tab.Focused {
			return tab
		}
	}
	return tabInfo{}
}

// adjacentByNumber finds the closest item before or after current.
func adjacentByNumber[T numberedFocusable](items []T, current T, forward bool) (T, bool) {
	var target T
	found := false
	for _, item := range items {
		if forward {
			if item.number() > current.number() && (!found || item.number() < target.number()) {
				target = item
				found = true
			}
			continue
		}
		if item.number() < current.number() && (!found || item.number() > target.number()) {
			target = item
			found = true
		}
	}
	return target, found
}

// workspaceIDFromEvent extracts the affected workspace ID from Herdr event JSON.
func workspaceIDFromEvent() string {
	event, ok := pluginEventJSON()
	if !ok {
		return ""
	}

	return firstStringField(event, "workspace_id")
}

// workspaceEventLooksBuildos reports whether the event is for a buildos workspace.
func workspaceEventLooksBuildos() bool {
	event, ok := pluginEventJSON()
	if !ok {
		return false
	}
	if strings.HasPrefix(firstStringField(event, "label"), buildosWorkspacePrefix) {
		return true
	}
	cwd := firstStringField(event, "cwd")
	return strings.HasPrefix(filepath.Base(cwd), buildosWorkspacePrefix)
}

// pluginEventJSON decodes Herdr's current plugin event payload.
func pluginEventJSON() (any, bool) {
	raw := os.Getenv("HERDR_PLUGIN_EVENT_JSON")
	if raw == "" {
		return nil, false
	}

	var event any
	if err := json.Unmarshal([]byte(raw), &event); err != nil {
		return nil, false
	}
	return event, true
}

// firstStringField recursively finds the first non-empty string field named key.
func firstStringField(value any, key string) string {
	switch typed := value.(type) {
	case map[string]any:
		if value, ok := typed[key].(string); ok && value != "" {
			return value
		}
		for _, child := range typed {
			if found := firstStringField(child, key); found != "" {
				return found
			}
		}
	case []any:
		for _, child := range typed {
			if found := firstStringField(child, key); found != "" {
				return found
			}
		}
	}

	return ""
}

// firstEnv returns the first non-empty environment variable value.
func firstEnv(names ...string) string {
	for _, name := range names {
		if value := os.Getenv(name); value != "" {
			return value
		}
	}
	return ""
}

// firstNonEmpty returns the first non-empty string in values.
func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

// edgeValue reports whether edges contains dir.
func edgeValue(edges paneEdges, dir Direction) bool {
	switch dir {
	case directionLeft:
		return edges.Left
	case directionRight:
		return edges.Right
	case directionUp:
		return edges.Up
	case directionDown:
		return edges.Down
	default:
		return false
	}
}

// parseDirection converts a CLI argument into a Direction.
func parseDirection(value string) (Direction, error) {
	switch value {
	case "left":
		return directionLeft, nil
	case "right":
		return directionRight, nil
	case "up":
		return directionUp, nil
	case "down":
		return directionDown, nil
	default:
		return directionInvalid, fmt.Errorf("invalid direction %q", value)
	}
}

// String returns the Herdr API string for dir.
func (dir Direction) String() string {
	switch dir {
	case directionLeft:
		return "left"
	case directionRight:
		return "right"
	case directionUp:
		return "up"
	case directionDown:
		return "down"
	default:
		return "invalid"
	}
}
