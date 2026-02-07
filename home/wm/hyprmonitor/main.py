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
from hyprpy import Hyprland


@dataclass(frozen=True)
class MonitorSetting:
    output: str
    mode: str
    position: str
    scale: float

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "MonitorSetting":
        return cls(
            output=str(raw["output"]),
            mode=str(raw["mode"]),
            position=str(raw["position"]),
            scale=float(raw["scale"]),
        )

    def to_hyprctl(self) -> str:
        return f"{self.output},{self.mode},{self.position},{self.scale:g}"


@dataclass(frozen=True)
class MonitorProfile:
    key: str
    label: str
    enabled_outputs: tuple[str, ...]
    use_tablet: bool

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "MonitorProfile":
        enabled_outputs = tuple(
            str(output) for output in raw["enabledOutputs"]
        )
        return cls(
            key=str(raw["key"]),
            label=str(raw["label"]),
            enabled_outputs=enabled_outputs,
            use_tablet=bool(raw["useTablet"]),
        )


@dataclass(frozen=True)
class DeviceConfig:
    default_settings: tuple[MonitorSetting, ...]
    profiles: tuple[MonitorProfile, ...]

    @classmethod
    def from_raw(cls, raw: dict[str, Any]) -> "DeviceConfig":
        default_settings = tuple(
            MonitorSetting.from_raw(setting)
            for setting in raw["defaultSettings"]
        )
        profiles = tuple(
            MonitorProfile.from_raw(profile) for profile in raw["profiles"]
        )
        return cls(default_settings=default_settings, profiles=profiles)


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


def load_config(config_path: Path) -> ProgramConfig:
    raw: dict[str, Any] = json.loads(config_path.read_text(encoding="utf-8"))
    devices = {
        str(name): DeviceConfig.from_raw(device_raw)
        for name, device_raw in raw["devices"].items()
    }
    return ProgramConfig(
        default_label=str(raw["defaultLabel"]),
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


def set_monitor(setting: MonitorSetting) -> None:
    hyprctl("keyword", "monitor", setting.to_hyprctl())


def disable_monitor(output: str) -> None:
    hyprctl("keyword", "monitor", f"{output},disable")


def remove_headless(headless_name: str) -> None:
    hyprctl("output", "remove", headless_name, check=False)


def has_monitor(instance: Hyprland, name: str) -> bool:
    return instance.get_monitor_by_name(name) is not None


def get_current_outputs(instance: Hyprland, headless_name: str) -> set[str]:
    outputs: set[str] = set()
    for monitor in instance.get_monitors():
        if monitor.name == headless_name:
            continue
        outputs.add(f"desc:{monitor.description}")
    return outputs


def should_offer_default(
    instance: Hyprland,
    state: ProgramState,
    device: str,
    device_config: DeviceConfig,
    headless_name: str,
    default_label: str,
) -> bool:
    if state.device == device and state.active_profile not in (
        None,
        default_label,
    ):
        return True
    if has_monitor(instance, headless_name):
        return True
    default_outputs = {
        setting.output for setting in device_config.default_settings
    }
    current_outputs = get_current_outputs(instance, headless_name)
    return bool(current_outputs) and current_outputs != default_outputs


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


def configure_headless(instance: Hyprland, settings: HeadlessConfig) -> int:
    hyprctl("output", "create", "headless", settings.name, check=False)
    hyprctl(
        "keyword",
        "monitor",
        f"{settings.name},{settings.mode},{settings.position},{settings.scale:g}",
    )

    for _ in range(30):
        monitor = instance.get_monitor_by_name(settings.name)
        if monitor is not None:
            return monitor.id
        time.sleep(0.1)

    raise click.ClickException(
        "unable to locate the configured headless monitor"
    )


def start_sunshine(output_name: int) -> int:
    env = os.environ.copy()
    env["output_name"] = str(output_name)
    process = subprocess.Popen(
        ["sunshine"],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    return process.pid


def apply_outputs(
    settings: tuple[MonitorSetting, ...],
    enabled_outputs: set[str],
) -> None:
    for setting in settings:
        if setting.output in enabled_outputs:
            set_monitor(setting)
        else:
            disable_monitor(setting.output)


def apply_configuration(
    instance: Hyprland,
    state: ProgramState,
    state_file: Path,
    device: str,
    device_config: DeviceConfig,
    headless: HeadlessConfig,
    default_label: str,
    profile: MonitorProfile | None,
) -> None:
    stop_owned_sunshine(state.sunshine_pid)
    remove_headless(headless.name)

    if profile is None:
        enabled_outputs = {
            setting.output for setting in device_config.default_settings
        }
        active_profile = default_label
        use_tablet = False
    else:
        enabled_outputs = set(profile.enabled_outputs)
        active_profile = profile.label
        use_tablet = profile.use_tablet

    apply_outputs(device_config.default_settings, enabled_outputs)

    sunshine_pid: int | None = None
    if use_tablet:
        headless_id = configure_headless(instance, headless)
        sunshine_pid = start_sunshine(headless_id)

    state.device = device
    state.active_profile = active_profile
    state.sunshine_pid = sunshine_pid
    save_state(state_file, state)


@click.command()
@click.option(
    "--device",
    help="Override hostname device detection.",
)
def main(device: str | None) -> None:
    config_path_raw = os.environ.get("HYPRMONITOR_CONFIG_PATH")
    if not config_path_raw:
        raise click.ClickException("HYPRMONITOR_CONFIG_PATH is not set")

    config = load_config(Path(config_path_raw))
    current_device = device or os.uname().nodename

    if current_device not in config.devices:
        raise click.ClickException(
            f"no hyprmonitor profiles defined for {current_device}"
        )

    instance = Hyprland()
    device_config = config.devices[current_device]
    state_file = state_path()
    state = load_state(state_file)

    profile_labels = [profile.label for profile in device_config.profiles]
    choices = profile_labels.copy()
    if should_offer_default(
        instance=instance,
        state=state,
        device=current_device,
        device_config=device_config,
        headless_name=config.tablet_headless.name,
        default_label=config.default_label,
    ):
        choices = [config.default_label, *choices]

    selection = pick_profile(choices)
    if selection is None:
        return

    selected_profile = next(
        (
            profile
            for profile in device_config.profiles
            if profile.label == selection
        ),
        None,
    )
    if selection != config.default_label and selected_profile is None:
        raise click.ClickException("invalid profile selected")

    apply_configuration(
        instance=instance,
        state=state,
        state_file=state_file,
        device=current_device,
        device_config=device_config,
        headless=config.tablet_headless,
        default_label=config.default_label,
        profile=selected_profile,
    )


if __name__ == "__main__":
    main()
