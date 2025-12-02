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
        --json=number,title,url,author
        --
        -reviewed-by:@me -is:draft
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
        # open each in a new kitty tab in reverse order so that first element is on top
        reverse |
        each {|pr|
            kitty @ launch --type=tab --title $pr.title nvim -c $"Octo ($pr.url)"
        }
    )
}
