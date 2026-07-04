package main

import "fmt"

// Direction identifies a directional navigation target.
type Direction uint8

const (
	directionInvalid Direction = iota
	directionDown
	directionLeft
	directionRight
	directionUp
)

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
