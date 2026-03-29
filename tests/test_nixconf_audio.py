from __future__ import annotations

import subprocess
import unittest

from nixconf_audio import AudioCommandError, get_sink_by_alsa_name, list_sinks


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


class NixconfAudioTests(unittest.TestCase):
    def test_list_sinks_marks_selected_default(self) -> None:
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

        sinks = list_sinks(run=run)

        self.assertEqual(len(sinks), 2)
        self.assertTrue(sinks[0].selected)
        self.assertFalse(sinks[1].selected)
        self.assertEqual(sinks[0].alsa_name, "USB Audio")

    def test_get_sink_by_alsa_name_returns_exact_match(self) -> None:
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

        sink = get_sink_by_alsa_name("USB Audio", run=run)

        self.assertEqual(sink.id, 51)
        self.assertEqual(sink.name, "sink.usb")

    def test_get_sink_by_alsa_name_errors_without_match(self) -> None:
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

        with self.assertRaisesRegex(AudioCommandError, "no audio sink found"):
            get_sink_by_alsa_name("LG TV SSCR2", run=run)

    def test_get_sink_by_alsa_name_errors_with_duplicates(self) -> None:
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

        with self.assertRaisesRegex(
            AudioCommandError, "multiple audio sinks matched"
        ):
            get_sink_by_alsa_name("USB Audio", run=run)


if __name__ == "__main__":
    unittest.main()
