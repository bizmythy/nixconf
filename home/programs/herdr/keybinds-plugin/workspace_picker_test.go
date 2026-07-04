package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestExtraWorkspaceChoicesUsesTopLevelNixconf(t *testing.T) {
	home := t.TempDir()

	choices := extraWorkspaceChoices(home)
	if len(choices) != 1 {
		t.Fatalf("expected one extra workspace choice, got %d", len(choices))
	}

	wantPath := filepath.Join(home, "nixconf")
	if choices[0].Display != "nixconf" || choices[0].Path != wantPath {
		t.Fatalf("unexpected nixconf choice: %#v, want display nixconf path %s", choices[0], wantPath)
	}
}

func TestWorkspaceChoicesForIncludesExistingNixconfExtraChoice(t *testing.T) {
	home := t.TempDir()
	if err := os.Mkdir(filepath.Join(home, "nixconf"), 0o755); err != nil {
		t.Fatal(err)
	}

	choices, err := workspaceChoicesFor(home, nil, extraWorkspaceChoices(home))
	if err != nil {
		t.Fatal(err)
	}

	wantPath := filepath.Join(home, "nixconf")
	for _, choice := range choices {
		if choice.Display == "nixconf" && choice.Path == wantPath {
			return
		}
	}

	t.Fatalf("nixconf workspace choice not found in %#v", choices)
}

func TestWorkspaceLabelForNixconfUsesNixIcon(t *testing.T) {
	if got := workspaceLabelForPath(filepath.Join(t.TempDir(), "nixconf")); got != " nixconf" {
		t.Fatalf("workspaceLabelForPath(nixconf) = %q", got)
	}
}
