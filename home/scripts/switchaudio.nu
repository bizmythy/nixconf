#!/usr/bin/env nu

use std/assert

let pw_ports = (pw-dump | from json | where type == "PipeWire:Interface:Port")
let ports_info = ($pw_ports | get info | reject params change-mask)

# crazy parse of wpctl status to extract the audio sink devices
def get_sinks [] {
    wpctl status |
    split row "Sinks:" | get 1 |
    split row "Sources" | get 0 |
    lines |
    drop 2 |
    split column "[" |
    skip 1 |
    get column1 |
    str trim |
    split column --number 2 ". " id name |
    upsert selected {|row| $row.id | str contains "*"} | 
    upsert id {|row| $row.id | str substring 7.. | str trim | into int}
}

let sinks = get_sinks
let choices = (
    $sinks |
    each {|row| if $row.selected { "✅ " + $row.name } else { $row.name }} |
    str join "\n"
)
let selected_idx = ($choices | fuzzel --dmenu --index --use-bold | into int)
let selected = ($sinks | get $selected_idx | reject selected)
print $selected

wpctl set-default $selected.id

# confirm that selected_id is new default
let defaults = (get_sinks | where selected == true)
assert length $defaults 1
assert equal ($defaults | get 0 | get id) $selected.id
