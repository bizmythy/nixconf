from __future__ import annotations

import json
import os
import signal
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import click


@dataclass(frozen=True)
class MonitorSetting:
    output: str
    mode: str
    position: str
    scale: float
    extra: dict[str, Any]

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "MonitorSetting":
        base_keys = {"output", "mode", "position", "scale"}
        extra = {
            str(key): value
            for key, value in raw.items()
            if str(key) not in base_keys
        }
        return cls(
            output=str(raw["output"]),
            mode=str(raw["mode"]),
            position=str(raw["position"]),
            scale=float(raw["scale"]),
            extra=extra,
        )


@dataclass(frozen=True)
class MonitorProfile:
    key: str
    label: str
    enabled_outputs: tuple[str, ...]
    use_tablet: bool
    monitor_overrides: dict[str, dict[str, Any]]

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "MonitorProfile":
        enabled_outputs = tuple(
            str(output) for output in raw["enabledOutputs"]
        )
        monitor_overrides_raw = raw.get("monitorOverrides", {})
        if not isinstance(monitor_overrides_raw, dict):
            raise ValueError("monitorOverrides must be a mapping")

        monitor_overrides: dict[str, dict[str, Any]] = {}
        for output, override in monitor_overrides_raw.items():
            if not isinstance(override, dict):
                raise ValueError("each monitor override must be a mapping")
            monitor_overrides[str(output)] = {
                str(key): value for key, value in override.items()
            }

        return cls(
            key=str(raw["key"]),
            label=str(raw["label"]),
            enabled_outputs=enabled_outputs,
            use_tablet=bool(raw["useTablet"]),
            monitor_overrides=monitor_overrides,
        )


@dataclass(frozen=True)
class DeviceConfig:
    default_settings: tuple[MonitorSetting, ...]
    workspace_rules: tuple[str, ...]
    profiles: tuple[MonitorProfile, ...]

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "DeviceConfig":
        default_settings = tuple(
            MonitorSetting.from_raw(setting)
            for setting in raw["defaultSettings"]
        )
        workspace_rules = tuple(
            str(rule) for rule in raw.get("workspaceRules", [])
        )
        profiles = tuple(
            MonitorProfile.from_raw(profile) for profile in raw["profiles"]
        )
        return cls(
            default_settings=default_settings,
            workspace_rules=workspace_rules,
            profiles=profiles,
        )


@dataclass(frozen=True)
class HeadlessConfig:
    name: str
    width: int
    height: int
    downsample: int
    scale: float
    position: str

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "HeadlessConfig":
        return cls(
            name=str(raw["name"]),
            width=int(raw["width"]),
            height=int(raw["height"]),
            downsample=int(raw["downsample"]),
            scale=float(raw["scale"]),
            position=str(raw["position"]),
        )

    @property
    def mode(self) -> str:
        return (
            f"{self.width // self.downsample}x{self.height // self.downsample}"
        )


@dataclass(frozen=True)
class ProgramConfig:
    default_label: str
    output_path: Path
    tablet_headless: HeadlessConfig
    devices: dict[str, DeviceConfig]


@dataclass
class ProgramState:
    device: str | None = None
    active_profile: str | None = None
    sunshine_pid: int | None = None

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "ProgramState":
        pid = raw.get("sunshine_pid")
        return cls(
            device=raw.get("device"),
            active_profile=raw.get("active_profile"),
            sunshine_pid=pid if isinstance(pid, int) else None,
        )

    def to_raw(self) -> dict[str, Any]:
        return {
            "device": self.device,
            "active_profile": self.active_profile,
            "sunshine_pid": self.sunshine_pid,
        }


@dataclass(frozen=True)
class MonitorDirective:
    output: str
    disabled: bool
    mode: str | None = None
    position: str | None = None
    scale: float | None = None
    extra: dict[str, Any] | None = None


@dataclass(frozen=True)
class HyprMonitorConfig:
    monitors: tuple[MonitorDirective, ...]
    workspace_rules: tuple[str, ...]


def output_from_desc(desc: str) -> str:
    return desc if desc.startswith("desc:") else f"desc:{desc}"


def resolve_output_ref(
    monitors: dict[str, Any], output_ref: Any
) -> str:
    ref = str(output_ref)
    monitor = monitors.get(ref)
    if isinstance(monitor, dict) and "desc" in monitor:
        return output_from_desc(str(monitor["desc"]))
    if ref.startswith("desc:"):
        return ref
    return output_from_desc(ref)


def parse_device_from_hosts_schema(
    device_name: str, host_raw: dict[str, Any]
) -> DeviceConfig:
    if not isinstance(host_raw, dict):
        raise click.ClickException(
            f"host {device_name!r} must be a mapping"
        )

    monitors_raw = host_raw.get("monitors")
    if not isinstance(monitors_raw, dict):
        raise click.ClickException(
            f"host {device_name!r} must define a monitors mapping"
        )

    default_settings: list[MonitorSetting] = []
    workspace_entries: list[tuple[int, str]] = []

    for monitor_key in sorted(monitors_raw):
        monitor_raw = monitors_raw[monitor_key]
        if not isinstance(monitor_raw, dict):
            raise click.ClickException(
                f"monitor {monitor_key!r} on host {device_name!r} must be a mapping"
            )

        settings_raw = monitor_raw.get("settings")
        if not isinstance(settings_raw, dict):
            raise click.ClickException(
                f"monitor {monitor_key!r} on host {device_name!r} must define settings"
            )

        desc_raw = monitor_raw.get("desc")
        if desc_raw is None:
            raise click.ClickException(
                f"monitor {monitor_key!r} on host {device_name!r} is missing desc"
            )
        output = output_from_desc(str(desc_raw))

        raw_setting = dict(settings_raw)
        raw_setting["output"] = output
        default_settings.append(MonitorSetting.from_raw(raw_setting))

        workspace = monitor_raw.get("workspace")
        if workspace is not None:
            try:
                workspace_number = int(workspace)
            except (TypeError, ValueError) as error:
                raise click.ClickException(
                    f"workspace for monitor {monitor_key!r} on host {device_name!r} must be an integer"
                ) from error
            workspace_entries.append((workspace_number, output))

    workspace_entries.sort(key=lambda item: item[0])
    workspace_rules = tuple(
        f"{workspace}, monitor:{output}, default:true"
        for workspace, output in workspace_entries
    )

    profiles_raw = host_raw.get("profiles", {})
    if not isinstance(profiles_raw, dict):
        raise click.ClickException(
            f"profiles for host {device_name!r} must be a mapping"
        )

    profiles: list[MonitorProfile] = []
    for profile_key in sorted(profiles_raw):
        profile_raw = profiles_raw[profile_key]
        if not isinstance(profile_raw, dict):
            raise click.ClickException(
                f"profile {profile_key!r} on host {device_name!r} must be a mapping"
            )

        enabled_outputs_raw = profile_raw.get("enabledOutputs")
        if not isinstance(enabled_outputs_raw, list):
            raise click.ClickException(
                f"profile {profile_key!r} on host {device_name!r} must define enabledOutputs"
            )

        enabled_outputs = tuple(
            resolve_output_ref(monitors_raw, output_ref)
            for output_ref in enabled_outputs_raw
        )

        monitor_overrides_raw = profile_raw.get("monitorOverrides", {})
        if not isinstance(monitor_overrides_raw, dict):
            raise click.ClickException(
                f"monitorOverrides for profile {profile_key!r} must be a mapping"
            )

        monitor_overrides: dict[str, dict[str, Any]] = {}
        for output_ref, override in monitor_overrides_raw.items():
            if not isinstance(override, dict):
                raise click.ClickException(
                    f"monitor override {output_ref!r} for profile {profile_key!r} must be a mapping"
                )
            monitor_overrides[
                resolve_output_ref(monitors_raw, output_ref)
            ] = {str(key): value for key, value in override.items()}

        profiles.append(
            MonitorProfile(
                key=str(profile_key),
                label=str(profile_raw.get("label", profile_key)),
                enabled_outputs=enabled_outputs,
                use_tablet=bool(profile_raw.get("useTablet", False)),
                monitor_overrides=monitor_overrides,
            )
        )

    return DeviceConfig(
        default_settings=tuple(default_settings),
        workspace_rules=workspace_rules,
        profiles=tuple(profiles),
    )


def format_hypr_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return f"{value:g}"
    return str(value)


def render_hyprmonitor_config(config: HyprMonitorConfig) -> str:
    """Render Hyprland syntax for monitor/workspace settings."""
    lines: list[str] = [
        "# Generated by hyprmonitor",
        "# This file is rewritten by hyprmonitor; manual edits may be lost.",
        "",
    ]

    for monitor in config.monitors:
        if monitor.disabled:
            lines.append(f"monitor = {monitor.output},disable")
            lines.append("")
            continue

        if (
            monitor.mode is None
            or monitor.position is None
            or monitor.scale is None
        ):
            raise ValueError(
                "enabled monitor directive is missing required fields"
            )

        lines.append("monitorv2 {")
        lines.append(f"  output = {monitor.output}")
        lines.append(f"  mode = {monitor.mode}")
        lines.append(f"  position = {monitor.position}")
        lines.append(f"  scale = {format_hypr_value(monitor.scale)}")

        for key, value in (monitor.extra or {}).items():
            lines.append(f"  {key} = {format_hypr_value(value)}")

        lines.append("}")
        lines.append("")

    for rule in config.workspace_rules:
        lines.append(f"workspace = {rule}")

    lines.append("")
    return "\n".join(lines)


def load_config(config_path: Path) -> ProgramConfig:
    raw: dict[str, Any] = json.loads(config_path.read_text(encoding="utf-8"))

    hosts_raw = raw.get("hosts")
    if isinstance(hosts_raw, dict):
        devices = {
            str(name): parse_device_from_hosts_schema(str(name), device_raw)
            for name, device_raw in hosts_raw.items()
        }
    else:
        devices_raw = raw.get("devices")
        if not isinstance(devices_raw, dict):
            raise click.ClickException(
                "config must define either a hosts mapping or devices mapping"
            )
        devices = {
            str(name): DeviceConfig.from_raw(device_raw)
            for name, device_raw in devices_raw.items()
        }

    output_path_raw = raw.get("outputPath")
    if output_path_raw is None:
        output_path_raw = "~/.config/hypr/hyprmonitor.conf"

    return ProgramConfig(
        default_label=str(raw.get("defaultLabel", "default")),
        output_path=Path(str(output_path_raw)).expanduser(),
        tablet_headless=HeadlessConfig.from_raw(raw["tabletHeadless"]),
        devices=devices,
    )


def state_path() -> Path:
    runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    return runtime_dir / "hyprmonitor-state.json"


def load_state(path: Path) -> ProgramState:
    if not path.exists():
        return ProgramState()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return ProgramState()
    if not isinstance(raw, dict):
        return ProgramState()
    return ProgramState.from_raw(raw)


def save_state(path: Path, state: ProgramState) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state.to_raw()), encoding="utf-8")


def run_command(
    command: list[str], *, check: bool = True
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command, text=True, capture_output=True, check=False
    )
    if check and result.returncode != 0:
        message = (
            result.stderr.strip() or result.stdout.strip() or "command failed"
        )
        raise click.ClickException(message)
    return result


def hyprctl(
    *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return run_command(["hyprctl", *args], check=check)


def list_monitors() -> list[dict[str, Any]]:
    result = hyprctl("monitors", "-j")
    parsed = json.loads(result.stdout)
    if not isinstance(parsed, list):
        raise click.ClickException("hyprctl returned invalid monitor json")
    return [item for item in parsed if isinstance(item, dict)]


def find_monitor_index(name: str) -> int | None:
    for index, monitor in enumerate(list_monitors()):
        if monitor.get("name") == name:
            return index
    return None


def wait_for_monitor_index(name: str, timeout_seconds: float = 3.0) -> int:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        monitor_index = find_monitor_index(name)
        if monitor_index is not None:
            return monitor_index
        time.sleep(0.1)
    raise click.ClickException(f"unable to find monitor {name!r} after reload")


def create_headless_output(headless_name: str) -> None:
    hyprctl("output", "create", "headless", headless_name, check=False)


def remove_headless(headless_name: str) -> None:
    hyprctl("output", "remove", headless_name, check=False)


def pid_is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def pid_looks_like_sunshine(pid: int) -> bool:
    cmdline_path = Path(f"/proc/{pid}/cmdline")
    try:
        cmdline = cmdline_path.read_bytes().decode("utf-8", errors="ignore")
    except OSError:
        return False
    return "sunshine" in cmdline


def stop_owned_sunshine(pid: int | None) -> None:
    if pid is None or not pid_is_running(pid):
        return

    if not pid_looks_like_sunshine(pid):
        return

    os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if not pid_is_running(pid):
            return
        time.sleep(0.1)


def start_sunshine(output_name: int) -> int:
    process = subprocess.Popen(
        ["sunshine", f"output_name={output_name}"],
        env=os.environ.copy(),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return process.pid


def build_runtime_monitor_config(
    device_config: DeviceConfig,
    enabled_outputs: set[str],
    headless: HeadlessConfig,
    use_tablet: bool,
    monitor_overrides: dict[str, dict[str, Any]] | None = None,
) -> HyprMonitorConfig:
    monitor_directives: list[MonitorDirective] = []
    monitor_overrides = monitor_overrides or {}

    for setting in device_config.default_settings:
        if setting.output in enabled_outputs:
            raw_override = monitor_overrides.get(setting.output, {})
            mode = setting.mode
            position = setting.position
            scale = setting.scale
            extra = dict(setting.extra)

            if "mode" in raw_override:
                mode = str(raw_override["mode"])
            if "position" in raw_override:
                position = str(raw_override["position"])
            if "scale" in raw_override:
                scale = float(raw_override["scale"])

            for key, value in raw_override.items():
                if key in {"mode", "position", "scale"}:
                    continue
                extra[key] = value

            monitor_directives.append(
                MonitorDirective(
                    output=setting.output,
                    disabled=False,
                    mode=mode,
                    position=position,
                    scale=scale,
                    extra=extra,
                )
            )
        else:
            monitor_directives.append(
                MonitorDirective(output=setting.output, disabled=True)
            )

    if use_tablet:
        monitor_directives.append(
            MonitorDirective(
                output=headless.name,
                disabled=False,
                mode=headless.mode,
                position=headless.position,
                scale=headless.scale,
                extra=None,
            )
        )

    return HyprMonitorConfig(
        monitors=tuple(monitor_directives),
        workspace_rules=device_config.workspace_rules,
    )


def write_runtime_config(path: Path, config: HyprMonitorConfig) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_hyprmonitor_config(config), encoding="utf-8")


def reload_hyprland() -> None:
    hyprctl("reload")


def pick_profile(choices: list[str]) -> str | None:
    result = subprocess.run(
        ["fuzzel", "--dmenu", "--index", "--prompt", "Monitors> "],
        input="\n".join(choices),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return None

    selected = result.stdout.strip()
    if not selected:
        return None

    try:
        index = int(selected)
    except ValueError as error:
        raise click.ClickException(
            "fuzzel returned a non-numeric selection"
        ) from error

    if index < 0 or index >= len(choices):
        raise click.ClickException("fuzzel returned an invalid selection")

    return choices[index]


def apply_selection(
    *,
    program_config: ProgramConfig,
    state: ProgramState,
    state_file: Path,
    device: str,
    device_config: DeviceConfig,
    profile: MonitorProfile | None,
) -> None:
    stop_owned_sunshine(state.sunshine_pid)
    remove_headless(program_config.tablet_headless.name)

    if profile is None:
        active_profile = program_config.default_label
        enabled_outputs = {
            setting.output for setting in device_config.default_settings
        }
        use_tablet = False
    else:
        active_profile = profile.label
        enabled_outputs = set(profile.enabled_outputs)
        use_tablet = profile.use_tablet

    runtime_config = build_runtime_monitor_config(
        device_config=device_config,
        enabled_outputs=enabled_outputs,
        headless=program_config.tablet_headless,
        use_tablet=use_tablet,
        monitor_overrides=(
            profile.monitor_overrides if profile is not None else None
        ),
    )
    write_runtime_config(program_config.output_path, runtime_config)
    reload_hyprland()

    sunshine_pid: int | None = None
    if use_tablet:
        create_headless_output(program_config.tablet_headless.name)
        headless_index = wait_for_monitor_index(
            program_config.tablet_headless.name
        )
        sunshine_pid = start_sunshine(headless_index)

    state.device = device
    state.active_profile = active_profile
    state.sunshine_pid = sunshine_pid
    save_state(state_file, state)


@click.command()
@click.option("--device", help="Override hostname device detection.")
@click.option(
    "--apply-default",
    is_flag=True,
    help="Apply the default monitor layout for the current host.",
)
def main(device: str | None, apply_default: bool) -> None:
    config_path_raw = os.environ.get("HYPRMONITOR_CONFIG_PATH")
    if not config_path_raw:
        raise click.ClickException("HYPRMONITOR_CONFIG_PATH is not set")

    config = load_config(Path(config_path_raw))
    current_device = device or os.uname().nodename

    if current_device not in config.devices:
        raise click.ClickException(
            f"no hyprmonitor configuration defined for {current_device}"
        )

    device_config = config.devices[current_device]
    state_file = state_path()
    state = load_state(state_file)

    selected_profile: MonitorProfile | None
    if apply_default:
        selected_profile = None
    else:
        labels = [config.default_label]
        labels.extend(profile.label for profile in device_config.profiles)
        selected_label: str | None

        if len(labels) == 1:
            selected_label = config.default_label
        else:
            selected_label = pick_profile(labels)
            if selected_label is None:
                return

        selected_profile = next(
            (
                profile
                for profile in device_config.profiles
                if profile.label == selected_label
            ),
            None,
        )
        if selected_label != config.default_label and selected_profile is None:
            raise click.ClickException("invalid profile selected")

    apply_selection(
        program_config=config,
        state=state,
        state_file=state_file,
        device=current_device,
        device_config=device_config,
        profile=selected_profile,
    )


if __name__ == "__main__":
    main()
