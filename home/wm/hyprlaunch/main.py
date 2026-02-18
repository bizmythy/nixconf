import json
from collections import Counter
from time import sleep

import click
from hyprpy import Hyprland


@click.command()
@click.argument("config", type=click.Path(exists=True))
@click.option(
    "-r",
    "--restore",
    is_flag=True,
    default=False,
    help="Restore the initial workspace after launching applications",
)
def main(config: str, restore: bool):
    with open(config) as f:
        directives = json.load(f)

    instance = Hyprland()

    initial_workspace = instance.get_active_workspace()

    def get_window_classes() -> Counter[str]:
        workspace = instance.get_active_workspace()
        return Counter(window.initial_wm_class for window in workspace.windows)

    def switch_workspace(ws):
        instance.dispatch(["workspace", str(ws)])

    for directive in directives:
        command = directive["command"]
        workspace = directive["workspace"]
        switch_workspace(workspace)
        initial_window_classes = get_window_classes()

        instance.dispatch(["exec", command])
        while get_window_classes() == initial_window_classes:
            sleep(0.1)
        click.secho(f"{command} opened in workspace {workspace}", fg="blue")

    if restore:
        switch_workspace(initial_workspace.id)


if __name__ == "__main__":
    main()
