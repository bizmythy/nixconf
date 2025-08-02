from hyprpy import Hyprland
# from hyprpy.utils.shell import run_or_fail


def main():
    instance = Hyprland()
    # Fetch active window and display information:
    window = instance.get_active_window()
    print(window.wm_class)
    print(window.width)
    print(window.position_x)

    # Print information about the windows on the active workspace
    workspace = instance.get_active_workspace()
    for window in workspace.windows:
        print(f"{window.address}: {window.title} [{window.wm_class}]")

    # Get the resolution of the first monitor
    monitor = instance.get_monitor_by_id(0)
    if monitor:
        print(f"{monitor.width} x {monitor.height}")

    # Get all windows currently on the special workspace
    main_ws = instance.get_workspace_by_id(1)
    if main_ws:
        windows = main_ws.windows
        for window in windows:
            print(window.title)

    # # Show a desktop notification every time we switch to workspace 6
    # def on_workspace_changed(sender, **kwargs):
    #     workspace_id = kwargs.get("workspace_id")
    #     print(f"We are on workspace {workspace_id}.")

    # instance.signals.workspacev2.connect(on_workspace_changed)
    # instance.watch()


if __name__ == "__main__":
    main()
