#!/usr/bin/env nu

def launch [app: string, workspace: int] {
    # Switch to the specified workspace
    hyprctl dispatch workspace $workspace

    # Give a short delay to ensure workspace switching completes
    sleep 500ms

    # Launch the application
    hyprctl dispatch exec $app

    # Give time for the application to start before switching to another workspace
    sleep 2sec
}

def main [] {
    # Start applications in their respective workspaces
    launch "alacritty" 1
    launch "slack" 8
    launch "zeditor ~/dirac/buildos-web" 2
    launch "firefox" 3
}
