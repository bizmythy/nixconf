#!/usr/bin/env nu

def log [] {
    print $"(ansi cyan)($in)(ansi reset)"
}

def configure-monitor [settings] {
    let resolution = $"($settings.width)x($settings.height)"
    let config = [
        $settings.name
        $resolution
        $settings.position
        $settings.scale
    ] | str join ","

    hyprctl keyword monitor $config
}

let name = "HEADLESS-TABLET"

"Creating headless output..." | log

hyprctl output create headless $name

"Configuring new monitor..." | log
let settings = {
    name: $name
    width: 2560
    height: 1600
    position: "auto-left"
    scale: 1
}
configure-monitor $settings

let headless_monitor = (
    hyprctl monitors list -j |
    from json |
    where name == $name |
    first
)

$headless_monitor | compact --empty | print

# configuration options for sunshine
# https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html
let sunshine_opts = {
    output_name: $headless_monitor.id
}

let sunshine_cmd = (
    $sunshine_opts |
    items {|key, value| $'"($key)=($value)"'} |
    prepend "sunshine" |
    str join " "
)

let cleanup_cmd = $"hyprctl output remove ($name)"

let parens = "()"
let script = $'
    #!/usr/bin/env bash
    set -euo pipefail

    child_pid=""

    cleanup_and_exit($parens) {
        # If the child is running, terminate it and wait for it to stop.
        if [[ -n "${child_pid}" ]] && kill -0 "${child_pid}" 2>/dev/null; then
            kill -TERM "${child_pid}" 2>/dev/null || true
            wait "${child_pid}" 2>/dev/null || true
        fi

        ($cleanup_cmd)
        exit 0
    }

    trap cleanup_and_exit TERM

    ($sunshine_cmd) &
    child_pid=$!

    wait "${child_pid}"
'

$script | bat --file-name test.sh

let session = "sunshine-tablet"
zellij attach --create-background $session
zellij --session $session run --close-on-exit --name "sunshine-job" -- bash -c $script
