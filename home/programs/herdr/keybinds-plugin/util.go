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
