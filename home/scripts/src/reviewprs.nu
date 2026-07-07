#!/usr/bin/env nu

const JSON_FLAG = "--json=number,title,url,author"

def open_prs []: list<any> -> nothing {
  if (($env.HERDR_ENV? | default "0") != "1") {
    error make {msg: "reviewprs.nu must be run inside Herdr (HERDR_ENV=1)"}
  }

  # Open each PR in a new Herdr tab.
  $in | each {|pr|
    let tab = (herdr tab create --label $pr.title --no-focus | from json)
    let pane_id = $tab.result.root_pane.pane_id
    herdr pane run $pane_id $"tuicr pr ($pr.url)"
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
    input list --multi --display "display" | reverse | open_prs
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
