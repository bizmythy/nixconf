#!/usr/bin/env nu

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
        --json=number,title,url
        --
        -reviewed-by:@me -is:draft
    )

    (
        $search_results |
        from json |
        input list --multi --display "title" |
        each {|pr|
            kitty @ launch --type=tab --title $pr.title nvim -c $"Octo ($pr.url)"
        }
    )
}
