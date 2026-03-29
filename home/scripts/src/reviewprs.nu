#!/usr/bin/env nu

const JSON_FLAG = "--json=number,title,url,author"

def open_prs [] {
  # open each pr in a new kitty tab in reverse order so that first element is on top
  reverse | each {|pr|
    kitty @ launch --type=tab --title $pr.title nvim -c $"Octo ($pr.url)"
  }
}

def main [count: int = 30 --noslop] {
  cd ~/dirac/buildos-web

  let search_results = (
    gh search prs
    --repo=diracq/buildos-web
    --limit=30
    --sort=updated
    --state=open
    $JSON_FLAG
    --
    -reviewed-by:@me -author:@me -is:draft
  )

  (
    $search_results | from json | where {|pr|
      if (not $noslop) {
        return true
      }
      $pr.author.login =~ `(sean|mihai)` | not $in
    } |
    # format for input display
    upsert "display" {|pr|
      $"@($pr.author.login | fill --alignment left --width 20)($pr.title)"
    } |
    # get user selection ("a" for all)
    input list --multi --display "display" | open_prs
  )
}

def "main urls" [] {
  cd ~/dirac/buildos-web

  let tempfile = (mktemp --suffix .txt)
  nvim $tempfile
  let urls = (open $tempfile | lines)
  rm $tempfile

  (
    $urls | par-each {|url|
      gh pr view $url $JSON_FLAG | from json
    } | open_prs
  )
}
