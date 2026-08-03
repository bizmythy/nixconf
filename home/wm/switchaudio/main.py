from __future__ import annotations

import argparse
import subprocess
import sys

from nixconf_audio import (
    AudioCommandError,
    AudioSink,
    get_default_sink_name,
    list_sinks,
    set_default_sink,
    switch_default_sink_by_alsa_name,
)


def format_choices() -> tuple[list[str], list[AudioSink]]:
    sinks = list_sinks()
    defaults = [sink for sink in sinks if sink.selected]
    if len(defaults) != 1:
        raise AudioCommandError("expected exactly one selected default sink")

    alsa_width = max(len(sink.alsa_name) for sink in sinks)
    choices = [
        (
            f"{'✅' if sink.selected else '  '} "
            f"{sink.alsa_name.ljust(alsa_width)} {sink.description}"
        )
        for sink in sinks
    ]
    return choices, sinks


def pick_sink() -> int | None:
    choices, sinks = format_choices()
    result = subprocess.run(
        ["fuzzel", "--dmenu", "--index", "--use-bold", "--width=50"],
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
        raise AudioCommandError(
            "fuzzel returned a non-numeric selection"
        ) from error

    if index < 0 or index >= len(sinks):
        raise AudioCommandError("fuzzel returned an invalid selection")

    selected_sink = sinks[index]
    set_default_sink(selected_sink.id)

    if get_default_sink_name() != selected_sink.name:
        raise AudioCommandError("failed to update the default audio sink")

    print(
        {
            "id": selected_sink.id,
            "name": selected_sink.name,
            "alsa_name": selected_sink.alsa_name,
            "description": selected_sink.description,
        }
    )
    return index


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--alsa-name",
        help="Switch to the sink whose PipeWire ALSA name matches.",
    )
    parser.add_argument(
        "--card-name",
        help="Activate this PipeWire card before selecting the sink.",
    )
    parser.add_argument(
        "--card-profile",
        help="Activate this PipeWire card profile before selecting the sink.",
    )
    args = parser.parse_args()

    try:
        if args.alsa_name is not None:
            switch_default_sink_by_alsa_name(
                args.alsa_name,
                card_name=args.card_name,
                card_profile=args.card_profile,
            )
        else:
            pick_sink()
    except AudioCommandError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
