package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type Direction uint8

const (
	directionInvalid Direction = iota
	directionDown
	directionLeft
	directionRight
	directionUp
)

type client struct {
	nextID     int
	socketPath string
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type response struct {
	ID     string          `json:"id"`
	Result json.RawMessage `json:"result"`
	Error  *apiError       `json:"error"`
}

type paneInfo struct {
	CWD         string `json:"cwd"`
	Focused     bool   `json:"focused"`
	PaneID      string `json:"pane_id"`
	TabID       string `json:"tab_id"`
	WorkspaceID string `json:"workspace_id"`
}

type tabInfo struct {
	Focused     bool   `json:"focused"`
	Label       string `json:"label"`
	Number      int    `json:"number"`
	PaneCount   int    `json:"pane_count"`
	TabID       string `json:"tab_id"`
	WorkspaceID string `json:"workspace_id"`
}

type workspaceInfo struct {
	Focused     bool   `json:"focused"`
	Label       string `json:"label"`
	Number      int    `json:"number"`
	WorkspaceID string `json:"workspace_id"`
}

type workspaceChoice struct {
	Display string
	Path    string
}

type paneEdges struct {
	Down  bool `json:"down"`
	Left  bool `json:"left"`
	Right bool `json:"right"`
	Up    bool `json:"up"`
}

type context struct {
	PaneID      string
	TabID       string
	WorkspaceID string
}

func main() {
	if len(os.Args) < 2 {
		fatalf("usage: %s navigate <left|right|up|down>|focus-tab <label>|new-workspace-picker [fuzzel]|setup-workspace", filepath.Base(os.Args[0]))
	}

	c, err := newClient()
	if err != nil {
		fatalf("%v", err)
	}

	switch os.Args[1] {
	case "navigate":
		if len(os.Args) != 3 {
			fatalf("usage: %s navigate <left|right|up|down>", filepath.Base(os.Args[0]))
		}
		dir, err := parseDirection(os.Args[2])
		if err != nil {
			fatalf("%v", err)
		}
		must(c.navigate(dir))
	case "focus-tab":
		if len(os.Args) != 3 {
			fatalf("usage: %s focus-tab <label>", filepath.Base(os.Args[0]))
		}
		must(c.focusTabLabel(os.Args[2]))
	case "new-workspace-picker":
		if len(os.Args) > 3 {
			fatalf("usage: %s new-workspace-picker [fuzzel]", filepath.Base(os.Args[0]))
		}
		fuzzel := "fuzzel"
		if len(os.Args) == 3 {
			fuzzel = os.Args[2]
		}
		must(c.newWorkspacePicker(fuzzel))
	case "setup-workspace":
		must(c.setupWorkspace())
	default:
		fatalf("unknown subcommand %q", os.Args[1])
	}
}

func newClient() (*client, error) {
	socketPath := os.Getenv("HERDR_SOCKET_PATH")
	if socketPath == "" {
		configHome := os.Getenv("XDG_CONFIG_HOME")
		if configHome == "" {
			home := os.Getenv("HOME")
			if home == "" {
				return nil, errors.New("HERDR_SOCKET_PATH and HOME are both unset")
			}
			configHome = filepath.Join(home, ".config")
		}
		socketPath = filepath.Join(configHome, "herdr", "herdr.sock")
	}

	return &client{socketPath: socketPath}, nil
}

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
		return fmt.Errorf("%s: %s", envelope.Error.Code, envelope.Error.Message)
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

func (c *client) navigate(dir Direction) error {
	ctx, err := c.resolveContext()
	if err != nil {
		return err
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

func (c *client) newWorkspacePicker(fuzzel string) error {
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

	selected, err := chooseWorkspace(fuzzel, choices)
	if err != nil {
		return err
	}
	if selected == nil {
		return nil
	}

	return c.openOrFocusWorkspace(selected.Path, filepath.Base(selected.Path))
}

func (c *client) openOrFocusWorkspace(cwd string, label string) error {
	workspaceID, err := c.workspaceIDForCWD(cwd)
	if err != nil {
		return err
	}
	if workspaceID != "" {
		return c.call("workspace.focus", map[string]any{"workspace_id": workspaceID}, nil)
	}

	return c.call("workspace.create", map[string]any{
		"cwd":   cwd,
		"focus": true,
		"label": label,
	}, nil)
}

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

func chooseWorkspace(fuzzel string, choices []workspaceChoice) (*workspaceChoice, error) {
	byDisplay := make(map[string]*workspaceChoice, len(choices))
	lines := make([]string, 0, len(choices))
	for index := range choices {
		choice := &choices[index]
		byDisplay[choice.Display] = choice
		lines = append(lines, choice.Display)
	}

	cmd := exec.Command(fuzzel, "--dmenu", "--prompt", "workspace> ")
	cmd.Stdin = strings.NewReader(strings.Join(lines, "\n") + "\n")
	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		var exitError *exec.ExitError
		if errors.As(err, &exitError) {
			return nil, nil
		}
		return nil, fmt.Errorf("run fuzzel: %w", err)
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

func homeDir() (string, error) {
	if home := os.Getenv("HOME"); home != "" {
		return home, nil
	}
	return os.UserHomeDir()
}

func (c *client) setupWorkspace() error {
	workspaceID, err := c.workspaceIDForSetup()
	if err != nil {
		return err
	}
	if workspaceID == "" {
		return nil
	}

	tabs, err := c.tabs(workspaceID)
	if err != nil {
		return err
	}
	if len(tabs) != 1 {
		return nil
	}
	if tabs[0].Label == "git" {
		return nil
	}
	if tabs[0].PaneCount != 1 {
		return nil
	}

	var panesResult struct {
		Panes []paneInfo `json:"panes"`
		Type  string     `json:"type"`
	}
	if err := c.call("pane.list", map[string]any{"workspace_id": workspaceID}, &panesResult); err != nil {
		return err
	}
	if len(panesResult.Panes) != 1 {
		return nil
	}

	if err := c.call("tab.rename", map[string]any{
		"label":  "git",
		"tab_id": tabs[0].TabID,
	}, nil); err != nil {
		return err
	}
	if err := c.call("pane.send_text", map[string]any{
		"pane_id": panesResult.Panes[0].PaneID,
		"text":    "lazygit\r",
	}, nil); err != nil {
		return err
	}
	if err := c.call("tab.create", map[string]any{
		"focus":        false,
		"label":        "ws",
		"workspace_id": workspaceID,
	}, nil); err != nil {
		return err
	}
	return c.call("tab.create", map[string]any{
		"focus":        true,
		"label":        "1",
		"workspace_id": workspaceID,
	}, nil)
}

func (c *client) fallbackTab(ctx context, dir Direction) error {
	tabs, err := c.tabs(ctx.WorkspaceID)
	if err != nil {
		return err
	}

	current, ok := currentTab(tabs, ctx.TabID)
	if !ok {
		return nil
	}

	var target *tabInfo
	for index := range tabs {
		tab := &tabs[index]
		if dir == directionRight {
			if tab.Number > current.Number && (target == nil || tab.Number < target.Number) {
				target = tab
			}
			continue
		}
		if tab.Number < current.Number && (target == nil || tab.Number > target.Number) {
			target = tab
		}
	}
	if target == nil {
		return nil
	}

	return c.call("tab.focus", map[string]any{"tab_id": target.TabID}, nil)
}

func (c *client) fallbackWorkspace(ctx context, dir Direction) error {
	var result struct {
		Type       string          `json:"type"`
		Workspaces []workspaceInfo `json:"workspaces"`
	}
	if err := c.call("workspace.list", nil, &result); err != nil {
		return err
	}

	sort.Slice(result.Workspaces, func(i, j int) bool {
		return result.Workspaces[i].Number < result.Workspaces[j].Number
	})

	current, ok := currentWorkspace(result.Workspaces, ctx.WorkspaceID)
	if !ok {
		return nil
	}

	var target *workspaceInfo
	for index := range result.Workspaces {
		workspace := &result.Workspaces[index]
		if dir == directionUp {
			if workspace.Number < current.Number && (target == nil || workspace.Number > target.Number) {
				target = workspace
			}
			continue
		}
		if workspace.Number > current.Number && (target == nil || workspace.Number < target.Number) {
			target = workspace
		}
	}
	if target == nil {
		return nil
	}

	return c.call("workspace.focus", map[string]any{"workspace_id": target.WorkspaceID}, nil)
}

func (c *client) resolveContext() (context, error) {
	ctx := context{
		PaneID:      firstEnv("HERDR_PANE_ID", "HERDR_ACTIVE_PANE_ID"),
		TabID:       firstEnv("HERDR_TAB_ID", "HERDR_ACTIVE_TAB_ID"),
		WorkspaceID: firstEnv("HERDR_WORKSPACE_ID", "HERDR_ACTIVE_WORKSPACE_ID"),
	}
	if ctx.PaneID != "" && ctx.TabID != "" && ctx.WorkspaceID != "" {
		return ctx, nil
	}

	var result struct {
		Pane paneInfo `json:"pane"`
		Type string   `json:"type"`
	}
	params := map[string]any{}
	if ctx.PaneID != "" {
		params["caller_pane_id"] = ctx.PaneID
	}
	if err := c.call("pane.current", params, &result); err != nil {
		return ctx, err
	}

	if ctx.PaneID == "" {
		ctx.PaneID = result.Pane.PaneID
	}
	if ctx.TabID == "" {
		ctx.TabID = result.Pane.TabID
	}
	if ctx.WorkspaceID == "" {
		ctx.WorkspaceID = result.Pane.WorkspaceID
	}

	return ctx, nil
}

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

	sort.Slice(result.Tabs, func(i, j int) bool {
		return result.Tabs[i].Number < result.Tabs[j].Number
	})

	return result.Tabs, nil
}

func currentTab(tabs []tabInfo, tabID string) (tabInfo, bool) {
	for _, tab := range tabs {
		if tab.Focused {
			return tab, true
		}
	}
	for _, tab := range tabs {
		if tabID != "" && tab.TabID == tabID {
			return tab, true
		}
	}
	return tabInfo{}, false
}

func currentWorkspace(workspaces []workspaceInfo, workspaceID string) (workspaceInfo, bool) {
	for _, workspace := range workspaces {
		if workspace.Focused {
			return workspace, true
		}
	}
	for _, workspace := range workspaces {
		if workspaceID != "" && workspace.WorkspaceID == workspaceID {
			return workspace, true
		}
	}
	return workspaceInfo{}, false
}

func workspaceIDFromEvent() string {
	raw := os.Getenv("HERDR_PLUGIN_EVENT_JSON")
	if raw == "" {
		return ""
	}

	var event any
	if err := json.Unmarshal([]byte(raw), &event); err != nil {
		return ""
	}

	return firstStringField(event, "workspace_id")
}

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

func firstEnv(names ...string) string {
	for _, name := range names {
		if value := os.Getenv(name); value != "" {
			return value
		}
	}
	return ""
}

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

func must(err error) {
	if err != nil {
		fatalf("%v", err)
	}
}

func fatalf(format string, args ...any) {
	message := fmt.Sprintf(format, args...)
	fmt.Fprintln(os.Stderr, strings.TrimSpace(message))
	os.Exit(1)
}
