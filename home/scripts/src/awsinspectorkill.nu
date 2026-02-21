#!/usr/bin/env nu

let bot_login = "amazon-inspector-n-virginia"

# GraphQL query for the first page of review threads
let threads_query_first = '
query($owner:String!, $name:String!, $pr:Int!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          comments(first:100) {
            nodes {
              id
              author { login }
              url
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}'

# GraphQL query for additional pages of review threads
let threads_query_next = '
query($owner:String!, $name:String!, $pr:Int!, $cursor:String!) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$pr) {
      reviewThreads(first:100, after:$cursor) {
        nodes {
          id
          isResolved
          comments(first:100) {
            nodes {
              id
              author { login }
              url
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}'

let resolve_thread_mutation = '
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread {
      id
      isResolved
    }
  }
}'

def parse-pr [pr_arg: string] {
  if ($pr_arg | str starts-with "http://") or ($pr_arg | str starts-with "https://") {
    let parsed = (
      $pr_arg |
      parse -r 'https?://github.com/(?<owner>[^/]+)/(?<name>[^/]+)/pull/(?<number>[0-9]+)'
    )

    if ($parsed | is-empty) {
      error make { msg: $"Could not parse PR URL: ($pr_arg)" }
    }

    let record = ($parsed | first)
    {
      owner: $record.owner
      name: $record.name
      pr: ($record.number | into int)
    }
  } else {
    let pr_num = (
      try {
        $pr_arg | into int
      } catch {
        error make { msg: $"PR argument must be a GitHub PR URL or PR number. Got: ($pr_arg)" }
      }
    )

    let name_with_owner = (
      try {
        gh repo view --json nameWithOwner |
        from json |
        get nameWithOwner
      } catch {
        error make { msg: "Could not infer repository from current directory. Pass a full PR URL instead." }
      }
    )

    let repo_parts = ($name_with_owner | split row "/")
    {
      owner: ($repo_parts | get 0)
      name: ($repo_parts | get 1)
      pr: $pr_num
    }
  }
}

def fetch-thread-page-first [owner: string, name: string, pr: int] {
  let response = (
    try {
      (gh api graphql -f $"query=($threads_query_first)" -F $"owner=($owner)" -F $"name=($name)" -F $"pr=($pr)") | from json
    } catch { |e|
      error make { msg: ([$"Failed to call GitHub GraphQL API:", ($e | to json)] | str join "\n") }
    }
  )

  if ($response | is-empty) {
    error make { msg: "GitHub GraphQL returned no response. Check network connectivity and gh auth status." }
  }

  if ("errors" in $response) {
    error make { msg: ([$"GraphQL query failed:", ($response.errors | to json)] | str join "\n") }
  }

  $response
}

def fetch-thread-page-next [owner: string, name: string, pr: int, cursor: string] {
  let response = (
    try {
      (gh api graphql -f $"query=($threads_query_next)" -F $"owner=($owner)" -F $"name=($name)" -F $"pr=($pr)" -F $"cursor=($cursor)") | from json
    } catch { |e|
      error make { msg: ([$"Failed to call GitHub GraphQL API:", ($e | to json)] | str join "\n") }
    }
  )

  if ($response | is-empty) {
    error make { msg: "GitHub GraphQL returned no response. Check network connectivity and gh auth status." }
  }

  if ("errors" in $response) {
    error make { msg: ([$"GraphQL query failed:", ($response.errors | to json)] | str join "\n") }
  }

  $response
}

def resolve-thread [thread_id: string] {
  let response = (
    try {
      (gh api graphql -f $"query=($resolve_thread_mutation)" -F $"threadId=($thread_id)") | from json
    } catch { |e|
      error make { msg: ([$"Failed to call GitHub GraphQL API:", ($e | to json)] | str join "\n") }
    }
  )

  if ($response | is-empty) {
    error make { msg: "GitHub GraphQL returned no response while resolving a thread. Check network connectivity and gh auth status." }
  }

  if ("errors" in $response) {
    error make { msg: ([$"Failed to resolve thread ($thread_id):", ($response.errors | to json)] | str join "\n") }
  }

  $response
}

def collect-all-threads [owner: string, name: string, pr: int] {
  mut all_threads = []

  let first_page = (fetch-thread-page-first $owner $name $pr)
  mut review_threads = (
    $first_page |
    get data.repository.pullRequest.reviewThreads
  )

  $all_threads = ($all_threads ++ $review_threads.nodes)

  mut has_next = $review_threads.pageInfo.hasNextPage
  mut cursor = $review_threads.pageInfo.endCursor

  while $has_next {
    let next_page = (fetch-thread-page-next $owner $name $pr $cursor)
    $review_threads = (
      $next_page |
      get data.repository.pullRequest.reviewThreads
    )

    $all_threads = ($all_threads ++ $review_threads.nodes)
    $has_next = $review_threads.pageInfo.hasNextPage
    $cursor = $review_threads.pageInfo.endCursor
  }

  $all_threads
}

def main [pr_arg: string, --dry-run] {
  let pr_info = (parse-pr $pr_arg)
  print $"Inspecting PR ($pr_info.owner)/($pr_info.name)#($pr_info.pr)"

  let threads = (collect-all-threads $pr_info.owner $pr_info.name $pr_info.pr)

  let matching_unresolved = (
    $threads |
    where { |thread|
      (not $thread.isResolved) and (
        $thread.comments.nodes |
        any { |c| (($c.author.login? | default "") == $bot_login) }
      )
    }
  )

  let total_matching = ($matching_unresolved | length)

  if $dry_run {
    print $"[dry-run] Would resolve ($total_matching) unresolved threads containing comments by ($bot_login)."
    $matching_unresolved |
      each { |thread|
        let first_url = (
          $thread.comments.nodes |
          where { |c| (($c.author.login? | default "") == $bot_login) } |
          get url |
          first
        )
        print $"[dry-run] thread=($thread.id) comment=($first_url)"
      }
    return
  }

  $matching_unresolved | par-each { |thread|
    resolve-thread $thread.id | ignore
    print $"Resolved thread ($thread.id)"
  }

  print $"Resolved threads containing comments by ($bot_login)."
}
