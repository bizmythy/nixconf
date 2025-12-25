#!/usr/bin/env nu

let name = "HEADLESS-TABLET"
let resolution = {
    width: 2560
    height: 1600
}

print "Creating headless output..."

hyprctl output create headless $name

print "Configuring new monitor..."
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

print "Removing headless monitor..."
hyprctl output remove $name
