package main

import (
	"errors"
	"sort"
)

const lazygitEntrypoint = "lazygit"

// toggleLazygit closes the active lazygit overlay, or replaces all other
// lazygit overlays with one at the active pane.
func (c *client) toggleLazygit() error {
	pane, err := c.currentPane()
	if err != nil {
		return err
	}

	state, statePath, err := loadPluginState()
	if err != nil {
		return err
	}

	if isLazygitPane(pane) {
		closeErr := c.closeTrackedLazygitPanes(state, []string{pane.PaneID})
		saveErr := savePluginState(statePath, state)
		if closeErr != nil {
			return closeErr
		}
		return saveErr
	}

	paneIDs, err := c.lazygitPaneIDs(state)
	if err != nil {
		return err
	}
	closeErr := c.closeTrackedLazygitPanes(state, paneIDs)
	saveErr := savePluginState(statePath, state)
	if closeErr != nil {
		return closeErr
	}
	if saveErr != nil {
		return saveErr
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
	if openedPane.PaneID == "" {
		return savePluginState(statePath, state)
	}
	state.LazygitPanes = map[string]string{openedPane.PaneID: openedPane.PaneID}
	return savePluginState(statePath, state)
}

func (c *client) lazygitPaneIDs(state pluginState) ([]string, error) {
	ids := make(map[string]struct{}, len(state.LazygitPanes))
	for _, paneID := range state.LazygitPanes {
		if paneID != "" {
			ids[paneID] = struct{}{}
		}
	}

	panes, err := c.panes("")
	if err != nil {
		return nil, err
	}
	for _, pane := range panes {
		if isLazygitPane(pane) && pane.PaneID != "" {
			ids[pane.PaneID] = struct{}{}
		}
	}

	paneIDs := make([]string, 0, len(ids))
	for paneID := range ids {
		paneIDs = append(paneIDs, paneID)
	}
	sort.Strings(paneIDs)
	return paneIDs, nil
}

func (c *client) closeTrackedLazygitPanes(state pluginState, paneIDs []string) error {
	var firstErr error
	for _, paneID := range paneIDs {
		if paneID == "" {
			continue
		}
		if err := c.call("plugin.pane.close", map[string]any{"pane_id": paneID}, nil); err != nil {
			if !isMissingPluginPane(err) && firstErr == nil {
				firstErr = err
			}
		}
		removeLazygitPaneID(state, paneID)
	}
	return firstErr
}

func removeLazygitPaneID(state pluginState, paneID string) {
	for key, value := range state.LazygitPanes {
		if key == paneID || value == paneID {
			delete(state.LazygitPanes, key)
		}
	}
}

func isLazygitPane(pane paneInfo) bool {
	return firstNonEmpty(pane.Label, pane.Title) == lazygitEntrypoint
}

// isActiveLazygitOverlay reports whether navigation should stay inside lazygit.
func (c *client) isActiveLazygitOverlay(ctx context) (bool, error) {
	if ctx.PaneID == "" {
		return false, nil
	}

	pane, err := c.currentPane()
	if err != nil {
		return false, err
	}
	return pane.PaneID == ctx.PaneID && isLazygitPane(pane), nil
}

// isMissingPluginPane recognizes close failures for already-gone plugin panes.
func isMissingPluginPane(err error) bool {
	var apiErr *apiCallError
	if !errors.As(err, &apiErr) {
		return false
	}
	return apiErr.Code == "plugin_pane_not_found" || apiErr.Code == "pane_not_found" || apiErr.Code == "not_found"
}
