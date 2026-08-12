package main

import (
	"os"
	"path/filepath"
	"sort"
)

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

// sortByNumber orders Herdr entities by their user-visible number.
func sortByNumber[T numberedFocusable](items []T) {
	sort.Slice(items, func(i, j int) bool {
		return items[i].number() < items[j].number()
	})
}

// orderWorkspacesForNavigation matches the sidebar's repository grouping. Herdr
// numbers workspaces globally, but renders linked worktrees immediately after
// their main checkout rather than at that global position.
func orderWorkspacesForNavigation(items []workspaceInfo) []workspaceInfo {
	sorted := append([]workspaceInfo(nil), items...)
	sortByNumber(sorted)

	roots := make(map[string]workspaceInfo)
	for _, workspace := range sorted {
		if workspace.Worktree != nil &&
			workspace.Worktree.RepoKey != "" &&
			!workspace.Worktree.IsLinkedWorktree {
			roots[workspace.Worktree.RepoKey] = workspace
		}
	}

	ordered := make([]workspaceInfo, 0, len(sorted))
	emittedRepos := make(map[string]bool)
	for _, workspace := range sorted {
		if workspace.Worktree == nil || workspace.Worktree.RepoKey == "" {
			ordered = append(ordered, workspace)
			continue
		}

		repoKey := workspace.Worktree.RepoKey
		if emittedRepos[repoKey] {
			continue
		}
		if root, ok := roots[repoKey]; ok {
			if root.WorkspaceID != workspace.WorkspaceID {
				continue
			}
			ordered = append(ordered, root)
		}
		emittedRepos[repoKey] = true
		for _, candidate := range sorted {
			if candidate.Worktree != nil &&
				candidate.Worktree.RepoKey == repoKey &&
				candidate.Worktree.IsLinkedWorktree {
				ordered = append(ordered, candidate)
			}
		}
	}

	return ordered
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

// adjacentInOrder returns the neighboring item in an already ordered slice.
func adjacentInOrder[T numberedFocusable](items []T, current T, forward bool) (T, bool) {
	for index, item := range items {
		if item.focusID() != current.focusID() {
			continue
		}

		targetIndex := index - 1
		if forward {
			targetIndex = index + 1
		}
		if targetIndex >= 0 && targetIndex < len(items) {
			return items[targetIndex], true
		}
		break
	}

	var zero T
	return zero, false
}
