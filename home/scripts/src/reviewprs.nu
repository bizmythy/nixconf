#!/usr/bin/env nu

cd ~/dirac/buildos-web

let tempfile = (mktemp --suffix .txt)
nvim $tempfile
let urls = (open $tempfile | lines)
rm $tempfile

let prs = $urls | par-each {|url| {
    url: $url,
    title: (
        gh pr view $url --json title |
        from json |
        get title
    )
}}

$prs | each {|pr| kitty @ launch --type=tab --title $pr.title nvim -c $"Octo ($pr.url)"}
