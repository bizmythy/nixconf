#!/usr/bin/env nu

def log [] {
    print $"(ansi cyan)($in)(ansi reset)"
}

let name = "HEADLESS-TABLET"
let resolution = {
    width: 2560
    height: 1600
}

"Creating headless output..." | log

hyprctl output create headless $name

"Configuring new monitor..." | log
hyprctl keyword monitor $"($name),($resolution.width)x($resolution.height),auto-left,1"

let headless_monitor = (
    hyprctl monitors list -j |
    from json |
    where name == $name |
    first
)

$headless_monitor | compact --empty | print

let sunshine_opts = (
    {
        output_name: $headless_monitor.id
    } |
    items {|key, value| $"($key)=($value)"}
)

try { sunshine ...$sunshine_opts }

"Removing headless monitor..." | log
hyprctl output remove $name
