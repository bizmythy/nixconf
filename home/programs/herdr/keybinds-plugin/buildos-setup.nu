#!/usr/bin/env nu

# Prepare a fresh buildos-web workspace directory.
def run-step [description: string block: closure] {
  try {
    do $block
  } catch {|err|
    error make {msg: $"($description) failed: ($err.msg? | default ($err | to json --raw))"}
  }
}

def safe-dir-cp [src: path dst: path] {
  use std/assert
  assert not ($dst | path exists) "output path already exists"

  print $"Copying ($src) -> ($dst)"
  mkdir $dst
  run-step "copy pristine repository" { tar -C $src -cf - . | tar -C $dst -xf - }
}

def main [workspace_name: string] {
  let dirac_dir = ("~/dirac" | path expand)
  let pristine = ($"($dirac_dir)/buildos-web-pristine" | path expand)
  let new_dir = ($"($dirac_dir)/($workspace_name)" | path expand)

  cd $dirac_dir

  if not ($pristine | path exists) {
    run-step "clone pristine buildos-web" { gh repo clone diracq/buildos-web -- $pristine }
    cd $pristine
    run-step "download test files" { direnv exec . mask test files download }
  } else {
    cd $pristine
    run-step "checkout pristine main" { git checkout main }
    run-step "update pristine buildos-web" { git pull }
  }

  cd $pristine
  run-step "install web dependencies" { direnv exec . mask install-web-dependencies }

  safe-dir-cp $pristine $new_dir
  cd $new_dir
}
