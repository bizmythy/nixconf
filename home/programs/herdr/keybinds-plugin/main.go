package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type client struct {
	conn   net.Conn
	reader *bufio.Reader
	nextID int
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
	Number      int    `json:"number"`
	WorkspaceID string `json:"workspace_id"`
}

type context struct {
	PaneID      string
	TabID       string
	WorkspaceID string
}

func main() {
	if len(os.Args) < 2 {
		fatalf("usage: %s navigate <left|right|up|down>|focus-tab <label>|setup-workspace", filepath.Base(os.Args[0]))
	}

	c, err := newClient()
	if err != nil {
		fatalf("%v", err)
	}
	defer c.conn.Close()

	switch os.Args[1] {
	case "navigate":
		if len(os.Args) != 3 {
			fatalf("usage: %s navigate <left|right|up|down>", filepath.Base(os.Args[0]))
		}
		must(c.navigate(os.Args[2]))
	case "focus-tab":
		if len(os.Args) != 3 {
			fatalf("usage: %s focus-tab <label>", filepath.Base(os.Args[0]))
		}
		must(c.focusTabLabel(os.Args[2]))
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

	dialer := net.Dialer{Timeout: 150 * time.Millisecond}
	conn, err := dialer.Dial("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("dial Herdr socket %s: %w", socketPath, err)
	}

	return &client{conn: conn, reader: bufio.NewReader(conn)}, nil
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

	if _, err := c.conn.Write(payload); err != nil {
		return fmt.Errorf("write %s request: %w", method, err)
	}

	line, err := c.reader.ReadBytes('\n')
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

func (c *client) navigate(direction string) error {
	if !validDirection(direction) {
		return fmt.Errorf("invalid direction %q", direction)
	}

	ctx, err := c.resolveContext()
	if err != nil {
		return err
	}

	edges, err := c.paneEdges(ctx.PaneID)
	if err != nil {
		return err
	}

	if !edgeValue(edges, direction) {
		params := map[string]any{"direction": direction}
		if ctx.PaneID != "" {
			params["pane_id"] = ctx.PaneID
		}
		return c.call("pane.focus_direction", params, nil)
	}

	switch direction {
	case "left", "right":
		return c.fallbackTab(ctx, direction)
	case "up", "down":
		return c.fallbackWorkspace(ctx, direction)
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

	if err := c.call("layout.apply", map[string]any{
		"focus":        true,
		"tab_id":       tabs[0].TabID,
		"tab_label":    "git",
		"workspace_id": workspaceID,
		"root": map[string]any{
			"type":    "pane",
			"command": []string{"lazygit"},
		},
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

func (c *client) fallbackTab(ctx context, direction string) error {
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
		if direction == "right" {
			if tab.Number < current.Number && (target == nil || tab.Number > target.Number) {
				target = tab
			}
			continue
		}
		if tab.Number > current.Number && (target == nil || tab.Number < target.Number) {
			target = tab
		}
	}
	if target == nil {
		return nil
	}

	return c.call("tab.focus", map[string]any{"tab_id": target.TabID}, nil)
}

func (c *client) fallbackWorkspace(ctx context, direction string) error {
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
		if direction == "up" {
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
		PaneID:      os.Getenv("HERDR_PANE_ID"),
		TabID:       os.Getenv("HERDR_TAB_ID"),
		WorkspaceID: os.Getenv("HERDR_WORKSPACE_ID"),
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

func (c *client) paneEdges(paneID string) (map[string]bool, error) {
	params := map[string]any{}
	if paneID != "" {
		params["pane_id"] = paneID
	}

	var result struct {
		Edges map[string]bool `json:"edges"`
		Type  string          `json:"type"`
	}
	if err := c.call("pane.edges", params, &result); err != nil {
		return nil, err
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
		if tabID != "" && tab.TabID == tabID {
			return tab, true
		}
	}
	for _, tab := range tabs {
		if tab.Focused {
			return tab, true
		}
	}
	return tabInfo{}, false
}

func currentWorkspace(workspaces []workspaceInfo, workspaceID string) (workspaceInfo, bool) {
	for _, workspace := range workspaces {
		if workspaceID != "" && workspace.WorkspaceID == workspaceID {
			return workspace, true
		}
	}
	for _, workspace := range workspaces {
		if workspace.Focused {
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

func edgeValue(edges map[string]bool, direction string) bool {
	return edges[direction]
}

func validDirection(direction string) bool {
	switch direction {
	case "left", "right", "up", "down":
		return true
	default:
		return false
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
