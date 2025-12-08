#!/usr/bin/env nu

let json_flag = "--json=number,title,url,author"

def open_prs [] {
    # open each pr in a new kitty tab in reverse order so that first element is on top
    reverse |
    each {|pr|
        kitty @ launch --type=tab --title $pr.title nvim -c $"Octo ($pr.url)"
    }
}

def main [count: int = 30] {
    cd ~/dirac/buildos-web

    let search_results = (
        gh search prs
        --repo=diracq/buildos-web
        --limit=30
        --sort=updated
        --review=required
        --state=open
        --base=main
        $json_flag
        --
        -reviewed-by:@me -author:@me -is:draft
    )

    (
        $search_results |
        from json |
        # format for input display
        upsert "display" {|pr|
            $"@($pr.author.login | fill --alignment left --width 20)($pr.title)"
        } |
        # get user selection ("a" for all)
        input list --multi --display "display" |
        open_prs
    )
}

def "main urls" [] {
    cd ~/dirac/buildos-web

    let tempfile = (mktemp --suffix .txt)
    nvim $tempfile
    let urls = (open $tempfile | lines)
    rm $tempfile

    (
        $urls |
        par-each {|url|
            gh pr view $url $json_flag | from json
        } |
        open_prs
    )
}
