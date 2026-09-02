#!/usr/bin/env nu

# tables are injected at nix eval time, see ./default.nix
const commands = "@commands@"
const aliases = "@aliases@"

def pick-subcommand [] {
  let width = ($commands | get name | each {|name| $name | str length } | math max)
  let selection = (
    $commands
    | each {|command| $"($command.name | fill -a left -w $width)  ($command.description)" }
    | str join "\n"
    | ^fzf --prompt "gh stack > "
    | complete
  )

  if ($selection.exit_code != 0) {
    exit $selection.exit_code
  }

  $selection.stdout | str trim | split row " " | first
}

def main [...args: string] {
  if ($args | is-empty) {
    ^gh stack (pick-subcommand)
    return
  }

  let subcommand = ($args | first)
  let rest = ($args | skip 1)

  if ($subcommand == "P") {
    ^gh stack rebase
    ^gh stack push
    return
  }

  ^gh stack ($aliases | get -o $subcommand | default $subcommand) ...$rest
}
