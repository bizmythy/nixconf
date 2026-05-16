#!/usr/bin/env nu

def parse-aliases [text: string] {
  mut aliases = {}
  mut current = ""

  for line in ($text | lines) {
    let alias = ($line | parse -r '^---@alias (?P<name>\S+)')
    if not ($alias | is-empty) {
      $current = $alias.0.name
      $aliases = ($aliases | upsert $current {values: []})
      continue
    }

    let value = ($line | parse -r '^---\| (?P<value>.+)$')
    if $current != "" and not ($value | is-empty) {
      let cleaned = (
        $value.0.value
        | str trim
        | str replace -r '^"' ''
        | str replace -r '"$' ''
      )
      let old = (try { ($aliases | get $current).values } catch { [] })
      $aliases = ($aliases | upsert $current {values: ($old | append $cleaned)})
      continue
    }

    if ($line | str starts-with "---@") {
      $current = ""
    }
  }

  $aliases
}

def parse-classes [text: string] {
  mut classes = {}
  mut current = ""

  for line in ($text | lines) {
    let class = ($line | parse -r '^---@class (?P<name>\S+)')
    if not ($class | is-empty) {
      $current = $class.0.name
      $classes = ($classes | upsert $current {fields: []})
      continue
    }

    let field = ($line | parse -r '^---@field (?P<name>.+?) (?P<signature>.+)$')
    if $current != "" and not ($field | is-empty) {
      let old = (try { ($classes | get $current).fields } catch { [] })
      $classes = (
        $classes
        | upsert $current {
          fields: (
            $old
            | append {
              name: ($field.0.name | str trim)
              signature: ($field.0.signature | str trim)
            }
          )
        }
      )
    }
  }

  $classes
}

def collect-functions [classes: record class_name: string prefix: string] {
  mut out = []
  let class = (try { $classes | get $class_name } catch { null })

  if $class == null {
    return $out
  }

  for field in $class.fields {
    if ($field.signature | str starts-with "fun") {
      $out = (
        $out
        | append {
          name: $"($prefix).($field.name)"
          signature: $field.signature
          source_class: $class_name
        }
      )
      continue
    }

    let child = ($field.signature | parse -r '^(?P<class>HL\.[A-Za-z0-9_]+Namespace)$')
    if not ($child | is-empty) {
      for item in (collect-functions $classes $child.0.class $"($prefix).($field.name)") {
        $out = ($out | append $item)
      }
    }
  }

  $out
}

def config-value-types [classes: record] {
  let fields = (try { ($classes | get "HL.ConfigValueTypes").fields } catch { [] })

  $fields
  | where {|field| $field.name | str starts-with "[" }
  | each {|field|
    {
      key: ($field.name | str substring 2..-3)
      type: $field.signature
    }
  }
}

def file-info [path: path] {
  let text = (open --raw $path)
  {
    path: ($path | path expand)
    sha256: ($text | hash sha256)
    bytes: ($text | str length)
  }
}

def main [
  --hyprland-dir: path = "~/personal/Hyprland"
  --out: path = ".agents/skills/hyprland-lua-config/references/hyprland-lua-docs.json"
  --repo-url: string = "https://github.com/hyprwm/Hyprland.git"
] {
  let checkout = ($hyprland_dir | path expand)

  if not ($checkout | path exists) {
    mkdir ($checkout | path dirname)
    git clone $repo_url $checkout
  }

  let meta_path = ($checkout | path join "meta/hl.meta.lua")
  let example_path = ($checkout | path join "example/hyprland.lua")

  if not ($meta_path | path exists) {
    error make {msg: $"missing Hyprland Lua stubs: ($meta_path)"}
  }

  if not ($example_path | path exists) {
    error make {msg: $"missing Hyprland example config: ($example_path)"}
  }

  let meta = (open --raw $meta_path)
  let example = (open --raw $example_path)
  let classes = (parse-classes $meta)
  let output_path = ($out | path expand)

  mkdir ($output_path | path dirname)

  {
    schema_version: 1
    source: {
      repo_url: $repo_url
      checkout: $checkout
      commit: (git -C $checkout rev-parse HEAD | str trim)
      dirty: (not ((git -C $checkout status --porcelain | str trim) | is-empty))
      files: {
        lua_stubs: (file-info $meta_path)
        example_config: (file-info $example_path)
      }
    }
    aliases: (parse-aliases $meta)
    classes: $classes
    config_value_types: (config-value-types $classes)
    globals: (collect-functions $classes "HL.API" "hl")
    example_config: $example
  }
  | to json
  | save --force $output_path

  print $output_path
}
