#!/usr/bin/env nu

def main [] {
  let attr = ".#nixosConfigurations.igneous.pkgs.linuxPackages_latest.kernel.version"
  let result = (nix eval --raw $attr | complete)

  if $result.exit_code != 0 {
    print -e ($result.stderr | str trim)
    exit $result.exit_code
  }

  let version = ($result.stdout | str trim)
  print $"linuxPackages_latest kernel: ($version)"

  if ($version | str starts-with "7.2") {
    print "linuxPackages_latest is on 7.2"
    exit 0
  }

  print "linuxPackages_latest is not on 7.2 yet"
  exit 1
}
