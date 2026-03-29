#!/usr/bin/env nu

use std/assert

def get_default_sink_name [] {
    pactl --format=json info | from json | get default_sink_name
}

def get_sinks [] {
    let default_sink_name = (get_default_sink_name)

    pactl --format=json list sinks |
    from json |
    each {|row|
        let properties = ($row | get properties)
        let description = ($row.description | default $row.name)

        {
            id: ($properties | get "object.id" | into int)
            name: $row.name
            label: $"($properties | get 'alsa.name')\t($description)"
            selected: ($row.name == $default_sink_name)
        }
    }
}

let sinks = get_sinks
let defaults = ($sinks | where selected == true)
assert length $defaults 1

let choices = (
    $sinks |
    each {|row| if $row.selected { "✅ " + $row.label } else { $row.label }} |
    str join "\n"
)
let selected_idx = ($choices | fuzzel --dmenu --index --use-bold --width=60 | into int)
let selected = ($sinks | get $selected_idx)
print ($selected | reject selected)

wpctl set-default $selected.id

# confirm that selected_id is new default
assert equal (get_default_sink_name) $selected.name
