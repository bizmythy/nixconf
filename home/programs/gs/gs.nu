#!/usr/bin/env nu

# tables are injected at nix eval time, see ./default.nix
const commands = "@commands@"
const aliases = "@aliases@"

def pick-subcommand [] {
  let selection = (
    $commands
    | each {|command| $"($command.name)(char tab)($command.description)" }
    | str join "\n"
    | (
      ^fzf
      --prompt "gh stack > "
      --delimiter (char tab)
      --with-nth 1
      --preview "echo {2}"
      --preview-window "right,60%,wrap"
    )
    | complete
  )

  if ($selection.exit_code != 0) {
    exit $selection.exit_code
  }

  $selection.stdout | str trim | split row (char tab) | first
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
