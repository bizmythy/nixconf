import json
import os
import re
import shlex
import shutil
import subprocess
import threading
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import click
from git import Repo
from hyprpy import Hyprland
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.screen import Screen
from textual.widgets import (
    Footer,
    Header,
    Input,
    ListItem,
    ListView,
    Log,
    Static,
)


def env(name: str, default: str) -> str:
    return os.environ.get(name, default)


def run_command_logged(
    command: list[str],
    *,
    cwd: Path | None,
    emit: Callable[[str], None],
) -> None:
    emit(f"$ {' '.join(command)}")
    process = subprocess.Popen(
        command,
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert process.stdout is not None
    for line in process.stdout:
        emit(line.rstrip("\n"))
    code = process.wait()
    if code != 0:
        raise click.ClickException(
            f"command failed ({code}): {' '.join(command)}"
        )


def fuzzy_score(query: str, candidate: str) -> int | None:
    if not query:
        return 0
    q = query.lower().strip()
    c = candidate.lower()

    pos = -1
    spread = 0
    for ch in q:
        idx = c.find(ch, pos + 1)
        if idx == -1:
            return None
        if pos >= 0:
            spread += idx - pos
        pos = idx

    starts_with = 1 if c.startswith(q) else 0
    contains = 1 if q in c else 0
    return spread - (20 * starts_with) - (5 * contains)


@dataclass(slots=True)
class Config:
    repo_root: Path
    repo_prefix: str
    remote: str
    state_path: Path
    terminal_cmd: str
    editor_cmd: str
    terminal_classes: tuple[str, ...]
    editor_classes: tuple[str, ...]


@dataclass(slots=True)
class RepoChoice:
    name: str
    path: Path

    @property
    def terminal_workspace(self) -> str:
        return f"name:buildos-web-{self.name}-terminal"

    @property
    def editor_workspace(self) -> str:
        return f"name:buildos-web-{self.name}-editor"


@dataclass(slots=True)
class State:
    active_repo_name: str | None


def build_config() -> Config:
    config_path_raw = os.environ.get("HYPRREPOSWITCH_CONFIG_PATH")
    if not config_path_raw:
        raise click.ClickException("HYPRREPOSWITCH_CONFIG_PATH is not set")

    config_path = Path(config_path_raw)
    try:
        payload = json.loads(config_path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise click.ClickException(
            f"config file not found: {config_path}"
        ) from error
    except json.JSONDecodeError as error:
        raise click.ClickException(
            f"invalid JSON in config file: {config_path}"
        ) from error

    try:
        repo_root = Path(payload["repoRoot"]).expanduser()
        repo_prefix = str(payload["repoPrefix"])
        remote = str(payload["remote"])
        state_path = Path(payload["statePath"]).expanduser()
        terminal_cmd = str(payload["terminalCommand"])
        editor_cmd = str(payload["editorCommand"])
        terminal_classes = tuple(str(x) for x in payload["terminalClasses"])
        editor_classes = tuple(str(x) for x in payload["editorClasses"])
    except KeyError as error:
        raise click.ClickException(
            f"missing config key in {config_path}: {error}"
        ) from error

    return Config(
        repo_root=repo_root,
        repo_prefix=repo_prefix,
        remote=remote,
        state_path=state_path,
        terminal_cmd=terminal_cmd,
        editor_cmd=editor_cmd,
        terminal_classes=terminal_classes,
        editor_classes=editor_classes,
    )


def sanitize_name(raw: str) -> str:
    name = raw.strip().lower()
    name = re.sub(r"[^a-z0-9._-]", "-", name)
    name = re.sub(r"-+", "-", name).strip("-")
    if not name:
        raise click.ClickException("name cannot be empty")
    return name


def state_exists(config: Config) -> bool:
    return config.state_path.exists()


def load_state(config: Config) -> State:
    if not state_exists(config):
        return State(active_repo_name=None)

    try:
        payload = json.loads(config.state_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return State(active_repo_name=None)

    return State(active_repo_name=payload.get("active_repo_name"))


def save_state(config: Config, state: State) -> None:
    config.state_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"active_repo_name": state.active_repo_name}
    config.state_path.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def resolve_active_repo_name(config: Config, state: State) -> str:
    if state.active_repo_name:
        return state.active_repo_name

    main_path = repo_name_to_path(config, "main")
    if main_path.exists():
        save_state(config, State(active_repo_name="main"))
        return "main"

    raise click.ClickException("no active repository in state")


def repo_name_to_path(config: Config, name: str) -> Path:
    if name == "main":
        return config.repo_root / config.repo_prefix
    return config.repo_root / f"{config.repo_prefix}-{name}"


def discover_repos(config: Config) -> list[RepoChoice]:
    repos: list[RepoChoice] = []
    main_path = config.repo_root / config.repo_prefix
    if main_path.exists():
        repos.append(RepoChoice(name="main", path=main_path))

    prefix = f"{config.repo_prefix}-"
    for path in sorted(config.repo_root.glob(f"{config.repo_prefix}-*")):
        if not path.is_dir():
            continue
        suffix = path.name.removeprefix(prefix)
        if suffix == "pristine":
            continue
        if not suffix:
            continue
        repos.append(RepoChoice(name=suffix, path=path))

    return repos


def ensure_pristine(
    config: Config, emit: Callable[[str], None]
) -> tuple[Path, bool]:
    pristine = config.repo_root / f"{config.repo_prefix}-pristine"
    created = False
    if not pristine.exists():
        emit(f"Cloning pristine repository into {pristine}")
        pristine.parent.mkdir(parents=True, exist_ok=True)
        Repo.clone_from(config.remote, pristine)
        created = True
    else:
        emit("Updating pristine repository")

    repo = Repo(pristine)
    origin = repo.remotes.origin
    origin.fetch()
    branch_name = "main"
    target = f"origin/{branch_name}"
    repo.git.checkout(branch_name)
    repo.git.reset("--hard", target)
    repo.git.clean("-fd")
    return pristine, created


def copy_repo(config: Config, name: str, emit: Callable[[str], None]) -> Path:
    if name == "main":
        target = repo_name_to_path(config, name)
        if not target.exists():
            raise click.ClickException(
                f"main repo does not exist at {target}; refusing to create it"
            )
        return target

    target = repo_name_to_path(config, name)
    if target.exists():
        emit(f"Repository already exists: {target}")
        return target

    pristine, created = ensure_pristine(config, emit)

    emit("Running dependency bootstrap in pristine")
    if created:
        run_command_logged(
            ["direnv", "exec", ".", "mask", "test", "files", "download"],
            cwd=pristine,
            emit=emit,
        )
    run_command_logged(
        ["direnv", "exec", ".", "mask", "install-web-dependencies"],
        cwd=pristine,
        emit=emit,
    )

    emit(f"Copying pristine to {target}")
    shutil.copytree(pristine, target, symlinks=True)
    return target


def hyprctl_json(topic: str) -> list[dict]:
    result = subprocess.run(
        ["hyprctl", "-j", topic],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise click.ClickException(
            f"hyprctl -j {topic} failed: {result.stderr.strip()}"
        )
    data = json.loads(result.stdout)
    if not isinstance(data, list):
        raise click.ClickException(f"unexpected hyprctl payload for {topic}")
    return data


def clients_for_workspace(workspace_name: str) -> list[dict]:
    clients = hyprctl_json("clients")
    return [
        c
        for c in clients
        if c.get("workspace", {}).get("name") == workspace_name
    ]


def workspace_has_class(workspace_name: str, classes: tuple[str, ...]) -> bool:
    class_set = {x.lower() for x in classes}
    for client in clients_for_workspace(workspace_name):
        cls = str(client.get("class", "")).lower()
        if cls in class_set:
            return True
    return False


def dispatch_exec(command: str) -> None:
    Hyprland().dispatch(["exec", command])


def spawn_editor(config: Config, repo: RepoChoice) -> None:
    if workspace_has_class(repo.editor_workspace, config.editor_classes):
        return

    command = (
        f"[workspace {repo.editor_workspace}] "
        f"{config.editor_cmd} {shlex.quote(str(repo.path))}"
    )
    dispatch_exec(command)


def spawn_terminal(config: Config, repo: RepoChoice) -> None:
    if workspace_has_class(repo.terminal_workspace, config.terminal_classes):
        return

    shell_snippet = (
        f"cd {shlex.quote(str(repo.path))} && "
        "exec ${SHELL:-zsh} -l"
    )
    command = (
        f"[workspace {repo.terminal_workspace}] "
        f"{config.terminal_cmd} -e zsh -lc {shlex.quote(shell_snippet)}"
    )
    dispatch_exec(command)


def find_monitors_showing(workspace_name: str) -> list[str]:
    monitors = hyprctl_json("monitors")
    return [
        str(m.get("name"))
        for m in monitors
        if m.get("activeWorkspace", {}).get("name") == workspace_name
    ]


def monitor_to_workspace(monitor_name: str, workspace_name: str) -> None:
    instance = Hyprland()
    instance.dispatch(["focusmonitor", monitor_name])
    instance.dispatch(["workspace", workspace_name])


def focus_workspace(workspace_name: str) -> None:
    Hyprland().dispatch(["focusworkspaceoncurrentmonitor", workspace_name])


def move_active_to_workspace(workspace_name: str) -> None:
    Hyprland().dispatch(["movetoworkspace", workspace_name])


def switch_repo(
    config: Config, repo_name: str, emit: Callable[[str], None]
) -> RepoChoice:
    name = sanitize_name(repo_name)
    repo_path = copy_repo(config, name, emit)
    target = RepoChoice(name=name, path=repo_path)

    state = load_state(config)
    old_name = state.active_repo_name

    if old_name:
        old_repo = RepoChoice(
            name=old_name,
            path=repo_name_to_path(config, old_name),
        )
        old_to_new_map = [
            (old_repo.terminal_workspace, target.terminal_workspace),
            (old_repo.editor_workspace, target.editor_workspace),
        ]
        for old_workspace, new_workspace in old_to_new_map:
            for monitor in find_monitors_showing(old_workspace):
                emit(f"Switching monitor {monitor} to {new_workspace}")
                monitor_to_workspace(monitor, new_workspace)

    spawn_terminal(config, target)
    spawn_editor(config, target)

    save_state(config, State(active_repo_name=name))
    return target


class PickerScreen(Screen[None]):
    BINDINGS = [
        Binding("enter", "accept", "Accept"),
        Binding("escape", "cancel", "Cancel"),
        Binding("up", "cursor_up", "Up"),
        Binding("down", "cursor_down", "Down"),
    ]

    def __init__(self, app_ref: "RepoPickerApp"):
        super().__init__()
        self.app_ref = app_ref

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Vertical():
            yield Static("Select or type repo name", id="title")
            yield Input(placeholder="main | feature-name", id="repo-input")
            yield ListView(id="repo-list")
        yield Footer()

    def on_mount(self) -> None:
        self.app_ref.refresh_choices("")
        self.query_one("#repo-input", Input).focus()

    def on_input_changed(self, event: Input.Changed) -> None:
        self.app_ref.refresh_choices(event.value)

    def action_cursor_up(self) -> None:
        self.query_one("#repo-list", ListView).action_cursor_up()

    def action_cursor_down(self) -> None:
        self.query_one("#repo-list", ListView).action_cursor_down()

    def action_cancel(self) -> None:
        self.app.exit(1)

    def action_accept(self) -> None:
        input_value = self.query_one("#repo-input", Input).value.strip()
        list_view = self.query_one("#repo-list", ListView)
        selected = list_view.highlighted_child
        if input_value:
            chosen = input_value
        elif selected is not None and selected.id:
            chosen = selected.id.removeprefix("repo-")
        else:
            chosen = ""
        if not chosen:
            return
        self.app_ref.begin_apply(chosen)


class ProgressScreen(Screen[None]):
    BINDINGS = [Binding("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            yield Static("Running...", id="status")
        yield Log(id="log")
        yield Footer()

    def append_log(self, message: str) -> None:
        self.query_one("#log", Log).write_line(message)

    def set_status(self, message: str) -> None:
        self.query_one("#status", Static).update(message)

    def action_quit(self) -> None:
        self.app.exit(1)


class RepoPickerApp(App[None]):
    CSS = """
    Screen {
      align: center middle;
    }

    #title {
      margin-bottom: 1;
    }

    Vertical {
      width: 90%;
      height: 90%;
      border: round $accent;
      padding: 1;
      background: $panel;
    }

    #repo-list {
      height: 1fr;
      margin-top: 1;
    }

    #status {
      margin-bottom: 1;
    }

    Log {
      height: 1fr;
      border: tall $accent;
    }
    """

    def __init__(self, config: Config):
        super().__init__()
        self.config = config
        self.all_choices = discover_repos(config)
        self.filtered_choices: list[RepoChoice] = []

    def on_mount(self) -> None:
        self.push_screen(PickerScreen(self))

    def refresh_choices(self, query: str) -> None:
        scores: list[tuple[int, RepoChoice]] = []
        for choice in self.all_choices:
            score = fuzzy_score(query, choice.name)
            if score is None:
                continue
            scores.append((score, choice))

        scores.sort(key=lambda item: (item[0], item[1].name))
        self.filtered_choices = [item[1] for item in scores]

        list_view = self.screen.query_one("#repo-list", ListView)
        list_view.clear()
        for repo in self.filtered_choices:
            list_view.append(
                ListItem(
                    Static(f"{repo.name}  ({repo.path})"),
                    id=f"repo-{repo.name}",
                )
            )
        if self.filtered_choices:
            list_view.index = 0

    def begin_apply(self, repo_name: str) -> None:
        self.push_screen(ProgressScreen())
        progress_screen = self.screen

        assert isinstance(progress_screen, ProgressScreen)
        progress_screen.set_status(f"Preparing repo: {repo_name}")

        def emit(message: str) -> None:
            self.call_from_thread(progress_screen.append_log, message)

        def worker() -> None:
            try:
                target = switch_repo(self.config, repo_name, emit)
            except Exception as error:  # broad by design to keep UI visible
                self.call_from_thread(
                    progress_screen.set_status,
                    f"Failed: {error}",
                )
                emit(f"ERROR: {error}")
                emit("Press q to close")
                return

            self.call_from_thread(
                progress_screen.set_status,
                f"Done: {target.name}",
            )
            emit(f"Switched to {target.name}")
            self.call_from_thread(self.exit, 0)

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()


@click.group()
def cli() -> None:
    pass


@cli.command()
def picker() -> None:
    config = build_config()
    RepoPickerApp(config).run()


@cli.command()
@click.argument("target", type=click.Choice(["terminal", "editor"]))
def goto(target: str) -> None:
    config = build_config()
    state = load_state(config)
    active_name = resolve_active_repo_name(config, state)

    repo = RepoChoice(
        name=active_name,
        path=repo_name_to_path(config, active_name),
    )
    if target == "terminal":
        workspace = repo.terminal_workspace
    else:
        workspace = repo.editor_workspace
    focus_workspace(workspace)


@cli.command()
@click.argument("target", type=click.Choice(["terminal", "editor"]))
def move(target: str) -> None:
    config = build_config()
    state = load_state(config)
    active_name = resolve_active_repo_name(config, state)

    repo = RepoChoice(
        name=active_name,
        path=repo_name_to_path(config, active_name),
    )
    if target == "terminal":
        workspace = repo.terminal_workspace
    else:
        workspace = repo.editor_workspace
    move_active_to_workspace(workspace)


@cli.command()
def status() -> None:
    config = build_config()
    state = load_state(config)
    click.echo(
        json.dumps(
            {
                "active_repo_name": state.active_repo_name,
                "state_path": str(config.state_path),
            },
            indent=2,
        )
    )


@cli.command()
def init() -> None:
    config = build_config()
    repos = discover_repos(config)
    default_name = repos[0].name if repos else "main"
    save_state(config, State(active_repo_name=default_name))
    click.echo(f"initialized active repo to {default_name}")


if __name__ == "__main__":
    cli()
