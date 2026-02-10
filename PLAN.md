## Buildos Repo Context Switcher for Hyprland

### Summary
Implement a new Python-based Hyprland tool that:
1. Opens a floating terminal TUI on `SUPER+SHIFT+O`.
2. Fuzzy-selects existing `~/dirac/buildos-web-*` repo copies (plus base `~/dirac/buildos-web`).
3. Creates a new repo copy when missing (using `buildos-web-pristine`, managed with `gitpython`).
4. Treats repo workspaces as named Hyprland workspaces (`...-editor` / `...-terminal`).
5. Keeps old repo workspaces/apps alive, but switches `SUPER+1/2` and `SUPER+SHIFT+1/2` behavior to the active repo via command dispatch (not static numeric binds).

---

## Scope of Changes

### 1) New Python program (packaged via Nix writer)
Add a new module, e.g. `home/wm/hyprreposwitch/`:
- `main.py`: CLI entrypoint and subcommands.
- `default.nix`: package with `pkgs.writers.writePython3Bin`.
- Optional `lib/` package for repo creation and workspace/session logic.

Suggested command surface:
- `hyprreposwitch picker`
  Opens TUI selector + in-window progress/logs, then switches context.
- `hyprreposwitch goto editor|terminal`
  Focus active repo’s named workspace.
- `hyprreposwitch move editor|terminal`
  Move active window to active repo’s named workspace.
- `hyprreposwitch status` (debug/info)
- `hyprreposwitch init` (optional state bootstrap)

### 2) Hyprland keybind integration
Update `home/wm/hyprland.nix`:
- Add launcher bind:
  - `SUPER+SHIFT+O` -> `exec` floating terminal running `hyprreposwitch picker`.
  - Use Hyprland exec rules so this is always floating/centered/sized (same window for fuzzy input + loading logs).
- Replace static workspace binds for `1/2` and `SHIFT+1/2`:
  - `SUPER+1` -> `exec, hyprreposwitch goto terminal`
  - `SUPER+2` -> `exec, hyprreposwitch goto editor`
  - `SUPER+SHIFT+1` -> `exec, hyprreposwitch move terminal`
  - `SUPER+SHIFT+2` -> `exec, hyprreposwitch move editor`
- Leave other numeric binds (`3..0`) unchanged.

### 3) Home module wiring
Update `home/wm/default.nix` imports to include the new module, similar to `hyprlaunch`/`hyprmonitor`.

### 4) Python dependencies
Add dependencies to repo-level Python project:
- `gitpython` (required by your preference)
- TUI deps (chosen default): `textual` (and `rapidfuzz` only if needed for matching quality)
- Reuse existing `click`, `hyprpy`

Then mirror these in Nix writer `libraries` so runtime executable is complete.

---

## Runtime Design (Decision Complete)

### Repo naming + discovery
- Repo root: `~/dirac`
- Canonical project prefix: `buildos-web`
- Discover candidates:
  - `~/dirac/buildos-web` (label as `main`)
  - `~/dirac/buildos-web-*` (excluding `buildos-web-pristine`)
- Selector entry value is workspace suffix name (`main` or `<suffix>`).

### Workspace naming strategy (named workspaces, no hashing)
For selected repo token `<name>`:
- Terminal workspace name: `name:buildos-web-<name>-terminal`
- Editor workspace name: `name:buildos-web-<name>-editor`

These are passed directly to Hyprland workspace dispatchers.

### Active-repo state
Persist to JSON (e.g. `~/.local/state/hyprreposwitch/state.json`):
- `active_repo_name`
- `repo_path`
- `terminal_workspace_name`
- `editor_workspace_name`
- `last_switched_at` (optional)
- version field for forward compatibility

### Picker behavior
Inside one floating terminal TUI:
1. Show fuzzy list of discovered repos.
2. Accept freeform input for new name.
3. On submit:
   - If existing repo: skip creation.
   - If new: run creation pipeline with live logs/progress in same window.
4. Switch active context and ensure app/workspace behavior.
5. Exit picker window on success; keep window open on failure with error logs.

### New repo creation pipeline (Python + gitpython)
Mirror `new-buildos.nu` semantics in Python:
1. Ensure `~/dirac/buildos-web-pristine` exists:
   - If missing: clone `diracq/buildos-web` into pristine.
   - If present: checkout/reset to `origin/main` (pristine should be disposable baseline).
2. Run setup in pristine:
   - first-time/bootstrap step equivalent to `direnv exec mask test files download` (only when needed)
   - always run `direnv exec mask install-web-dependencies`
3. Copy pristine -> `~/dirac/buildos-web-<name>` (explicit directory copy; not git worktree).
4. Return target path.

### Context switch + workspace behavior
Given old active repo and new active repo:
1. Compute old/new editor+terminal workspace names.
2. Detect monitors currently displaying old terminal/editor workspace.
3. For each such monitor, switch that monitor to corresponding new workspace.
4. Ensure new repo apps exist:
   - Editor workspace has Zed opened on repo path.
   - Terminal workspace has terminal opened in repo path.
   - If already present on those named workspaces, reuse and do not respawn.
5. Persist new active-repo state.

### App identification
- Editor detection: window class/title match for Zed (`Zed` / `dev.zed.Zed`, configurable constants).
- Terminal detection: class match for your default terminal (configurable list).
- Spawn commands are configured from Nix defaults:
  - terminal command from `${vars.defaults.tty}`
  - editor command from `${vars.defaults.editor}`

---

## Public Interfaces / Config Additions

### New executable
- `hyprreposwitch` with subcommands above.

### Nix module options (recommended)
Expose minimal options in new module:
- `wm.hyprreposwitch.enable` (bool)
- `wm.hyprreposwitch.repoRoot` (default `~/dirac`)
- `wm.hyprreposwitch.repoPrefix` (default `buildos-web`)
- `wm.hyprreposwitch.remote` (default `git@github.com:diracq/buildos-web.git` or HTTPS equivalent)
- `wm.hyprreposwitch.statePath` (default under `~/.local/state`)
- `wm.hyprreposwitch.launcherTerminalCommand` (default `${vars.defaults.tty}`)
- `wm.hyprreposwitch.editorCommand` (default `${vars.defaults.editor}`)

Pass these into wrapper env vars, similar to `hyprmonitor` pattern.

---

## Test Cases and Validation

### Automated (non-graphical unit tests)
- Workspace name generation from repo name (`main`, custom names, edge chars).
- Repo discovery filtering (`pristine` excluded, main included).
- State read/write and migration/version handling.
- Selector input normalization and path safety.

### Integration/manual scenarios
1. Existing repo switch:
   - Picker select existing `buildos-web-foo`.
   - `SUPER+1` goes terminal ws, `SUPER+2` goes editor ws for `foo`.
2. New repo creation:
   - Enter new name.
   - Same picker window shows progress/logs.
   - Repo created, windows opened, hotkeys retargeted.
3. Re-switch with old apps retained:
   - Switch from `foo` to `bar`.
   - `foo` workspaces/windows remain alive.
   - Hotkeys now target `bar`.
4. Monitor handoff:
   - If monitor A shows old terminal ws and monitor B old editor ws, after switch they show new terminal/editor ws respectively.
5. Reuse behavior:
   - Switch back to repo with existing Zed/terminal; no duplicate windows spawned.
6. Move binds:
   - `SUPER+SHIFT+1/2` moves active window to active repo terminal/editor named ws.

### Failure-path checks
- Clone/pull failure.
- `direnv`/`mask` command failure.
- Copy destination already exists.
- Hyprland IPC unavailable.
- TUI cancelled (`Esc`/close) with no state changes.

---

## Assumptions and Defaults Chosen
- Use named workspaces (`name:...`) rather than numeric allocation.
- Use custom terminal TUI (not fuzzel/rofi/GTK).
- Keep fuzzy input and progress/logging in the same floating window.
- New repo creation source is `buildos-web-pristine`.
- Reuse existing app windows when present.
- `SUPER+SHIFT+1/2` should follow active repo mapping.
- Python implementation uses `gitpython`.
