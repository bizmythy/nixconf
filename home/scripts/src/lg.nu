#!/usr/bin/env nu

let dir = (pwd)

let is_git_dir = ($dir | path join ".git" | path exists)
if (not $is_git_dir) {
    print "not a git directory"
    exit 1
}

if ($dir == "/home/drew/dirac") {
    print "tried to open ~/dirac git dir, should not edit this git folder."
    exit 1
}

# problematic library path causing issues
hide-env LD_LIBRARY_PATH
lazygit -p $dir
