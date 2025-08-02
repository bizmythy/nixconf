import click

from time import sleep
from hyprpy import Hyprland
from collections import Counter


@click.command()
@click.argument("directives", nargs=-1)
@click.option(
    "-r",
    "--restore",
    is_flag=True,
    default=False,
    help="Restore the initial workspace after launching applications",
)
def main(directives: list[str], restore: bool):
    instance = Hyprland()

    initial_workspace = instance.get_active_workspace()

    def get_window_classes() -> Counter[str]:
        workspace = instance.get_active_workspace()
        return Counter(window.initial_wm_class for window in workspace.windows)

    def switch_workspace(ws):
        instance.dispatch(["workspace", str(ws)])

    for directive in directives:
        command, workspace = directive.rsplit(":", maxsplit=1)
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
