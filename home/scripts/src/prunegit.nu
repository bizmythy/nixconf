#!/usr/bin/env nu

let local = (
    git for-each-ref --format='%(refname:short)' refs/heads/ |
    lines
)
let remote = (
    git ls-remote --heads |
    lines |
    each { |line| $line | split row "\trefs/heads/" | get 1 }
)
let no_upstream = (
    $local |
    where { |branch| not ($branch in $remote) }
)

print "About to remove the following branches:"
print $no_upstream
input "Press enter to continue..."

$no_upstream | each { |branch| git branch -d $branch }
