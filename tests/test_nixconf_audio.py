from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]


def load_nixconf_audio_module():
    module_path = ROOT / "nixconf_audio/__init__.py"
    spec = importlib.util.spec_from_file_location("nixconf_audio_module", module_path)
    if spec is None or spec.loader is None:
        raise AssertionError("unable to load nixconf_audio module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def make_completed_process(stdout: str) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout)


def run_with_sinks(sinks_json: str):
    def run(command: list[str]) -> subprocess.CompletedProcess[str]:
        if command == ["pactl", "--format=json", "info"]:
            return make_completed_process('{"default_sink_name":"sink.usb"}')
        if command == ["pactl", "--format=json", "list", "sinks"]:
            return make_completed_process(sinks_json)
        raise AssertionError(f"unexpected command: {command}")

    return run


def test_list_sinks_marks_selected_default() -> None:
    module = load_nixconf_audio_module()
    run = run_with_sinks(
        """
        [
          {
            "name": "sink.usb",
            "description": "USB Headset",
            "properties": {
              "object.id": "51",
              "alsa.name": "USB Audio"
            }
          },
          {
            "name": "sink.tv",
            "description": "TV",
            "properties": {
              "object.id": "77",
              "alsa.name": "LG TV SSCR2"
            }
          }
        ]
        """
    )

    sinks = module.list_sinks(run=run)

    assert len(sinks) == 2
    assert sinks[0].selected is True
    assert sinks[1].selected is False
    assert sinks[0].alsa_name == "USB Audio"


def test_get_sink_by_alsa_name_returns_exact_match() -> None:
    module = load_nixconf_audio_module()
    run = run_with_sinks(
        """
        [
          {
            "name": "sink.usb",
            "description": "USB Headset",
            "properties": {
              "object.id": "51",
              "alsa.name": "USB Audio"
            }
          }
        ]
        """
    )

    sink = module.get_sink_by_alsa_name("USB Audio", run=run)

    assert sink.id == 51
    assert sink.name == "sink.usb"


def test_get_sink_by_alsa_name_errors_without_match() -> None:
    module = load_nixconf_audio_module()
    run = run_with_sinks(
        """
        [
          {
            "name": "sink.usb",
            "description": "USB Headset",
            "properties": {
              "object.id": "51",
              "alsa.name": "USB Audio"
            }
          }
        ]
        """
    )

    with pytest.raises(module.AudioCommandError, match="no audio sink found"):
        module.get_sink_by_alsa_name("LG TV SSCR2", run=run)


def test_get_sink_by_alsa_name_errors_with_duplicates() -> None:
    module = load_nixconf_audio_module()
    run = run_with_sinks(
        """
        [
          {
            "name": "sink.usb.1",
            "description": "USB Headset",
            "properties": {
              "object.id": "51",
              "alsa.name": "USB Audio"
            }
          },
          {
            "name": "sink.usb.2",
            "description": "USB DAC",
            "properties": {
              "object.id": "52",
              "alsa.name": "USB Audio"
            }
          }
        ]
        """
    )

    with pytest.raises(
        module.AudioCommandError,
        match="multiple audio sinks matched",
    ):
        module.get_sink_by_alsa_name("USB Audio", run=run)
