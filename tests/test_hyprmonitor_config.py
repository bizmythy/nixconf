from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_hyprmonitor_module():
    module_path = ROOT / "home/wm/hyprmonitor/main.py"
    spec = importlib.util.spec_from_file_location("hyprmonitor_main", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError("unable to load hyprmonitor module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def test_load_config_parses_optional_audio_defaults(
    tmp_path: Path,
) -> None:
    module = load_hyprmonitor_module()
    raw = {
        "outputPath": "~/.config/hypr/hyprmonitor.conf",
        "tabletHeadless": {
            "name": "HEADLESS-TABLET",
            "width": 2560,
            "height": 1600,
            "downsample": 2,
            "scale": 1.0,
            "position": "auto-left",
        },
        "hosts": {
            "igneous": {
                "defaultAudioOutputAlsaName": "USB Audio",
                "monitors": {
                    "main": {
                        "desc": "Microstep MSI MAG322UPF",
                        "settings": {
                            "mode": "3840x2160@160",
                            "position": "0x0",
                            "scale": 1.5,
                        },
                    }
                },
                "profiles": {
                    "tv": {
                        "enabledOutputs": ["main"],
                        "useTablet": False,
                        "defaultAudioOutputAlsaName": "LG TV SSCR2",
                    },
                    "desktop": {
                        "enabledOutputs": ["main"],
                        "useTablet": False,
                    },
                },
            }
        },
    }

    config_path = tmp_path / "config.json"
    config_path.write_text(json.dumps(raw), encoding="utf-8")

    config = module.load_config(config_path)
    device = config.devices["igneous"]
    profiles_by_label = {profile.label: profile for profile in device.profiles}

    assert device.default_audio_output_alsa_name == "USB Audio"
    assert (
        profiles_by_label["tv"].default_audio_output_alsa_name
        == "LG TV SSCR2"
    )
    assert profiles_by_label["desktop"].default_audio_output_alsa_name is None
