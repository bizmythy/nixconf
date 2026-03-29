#!/usr/bin/env nu

use std/assert

def get-default-sink-name [] {
    pactl --format=json info | from json | get default_sink_name
}

def get-sinks [] {
    let default_sink_name = (get-default-sink-name)

    pactl --format=json list sinks |
    from json |
    each {|row|
        let properties = ($row | get properties)
        let alsa_name = ($properties | get 'alsa.name' | default $row.name)
        let description = ($row.description | default $row.name)

        {
            id: ($properties | get "object.id" | into int)
            name: $row.name
            alsa_name: $alsa_name
            description: $description
            selected: ($row.name == $default_sink_name)
        }
    }
}

let sinks = get-sinks
let defaults = ($sinks | where selected == true)
assert length $defaults 1

let alsa_width = (
    $sinks
    | get alsa_name
    | each {|name| $name | str length }
    | math max
)

let choices = (
    $sinks |
    each {|row|
        {
            marker: (if $row.selected { "✅" } else { "  " })
            alsa_name: ($row.alsa_name | fill --width $alsa_width)
            description: $row.description
        }
    } |
    format pattern '{marker} {alsa_name} {description}' |
    str join "\n"
)
let selected_idx = ($choices | fuzzel --dmenu --index --use-bold --width=50 | into int)
let selected = ($sinks | get $selected_idx)
print ($selected | reject selected)

wpctl set-default $selected.id

# confirm that selected_id is new default
assert equal (get-default-sink-name) $selected.name
