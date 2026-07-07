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

def normalize_pr_ref [raw: string] {
  let ref = ($raw | str replace --regex '#.*$' '' | str trim)

  if ($ref | is-empty) {
    return null
  }

  if ($ref =~ `^(www\.)?github\.com/`) {
    return $"https://($ref)"
  }

  $ref
}

def load_pr [ref: string] {
  let result = (^gh pr view $ref $JSON_FLAG | complete)

  if $result.exit_code == 0 {
    return {
      ok: true
      input: $ref
      pr: ($result.stdout | from json)
    }
  }

  {
    ok: false
    input: $ref
    error: ($result.stderr | str trim)
  }
}

def "main urls" [] {
  cd ~/dirac/buildos-web

  let tempfile = (mktemp --suffix .txt)
  nvim $tempfile
  let refs = (
    open $tempfile
    | lines
    | each {|line| normalize_pr_ref $line }
    | where {|ref| $ref != null }
    | uniq
  )
  rm $tempfile

  if ($refs | is-empty) {
    print -e "no pull request urls entered"
    exit 1
  }

  let results = ($refs | par-each {|ref| load_pr $ref })
  let failures = ($results | where {|result| not $result.ok })
  let prs = ($results | where {|result| $result.ok } | get pr)

  if (not ($failures | is-empty)) {
    print -e "failed to load some pull requests:"
    $failures | each {|failure|
      print -e $"  ($failure.input): ($failure.error)"
    }
  }

  if ($prs | is-empty) {
    exit 1
  }

  $prs | open_prs
}
