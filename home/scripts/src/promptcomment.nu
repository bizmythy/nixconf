#!/usr/bin/env nu

let repo = "diracq/buildos-web"

def main [pr: int] {
    let me = (
        gh api user |
        from json |
        get login
    )

    let query = '
        query($owner:String!, $name:String!, $pr:Int!) {
            repository(owner:$owner, name:$name) {
            pullRequest(number:$pr) {
                reviewThreads(first:100) {
                nodes {
                    isResolved
                    comments(first:100) {
                    nodes {
                        author { login }
                        path
                        line
                        startLine
                        originalLine
                        originalStartLine
                        createdAt
                        updatedAt
                        body
                        diffHunk
                        url
                    }
                    }
                }
                }
            }
            }
        }'
    # execute graphql query using `gh`
    let response = (
        gh api graphql
        -f $"query=($query)"
        -F owner=diracq
        -F name=buildos-web
        -F $"pr=($pr)"
    ) | from json

    # check for errors in response
    let err_key = "errors"
    if ($err_key in $response) {
        print "Error:"
        $response | get $err_key | print
        exit 1
    }

    # parse response into comments, filter out resolved
    let comments = (
        $response |
        get data |
        get repository |
        get pullRequest |
        get reviewThreads |
        get nodes |
        where { not $in.isResolved } |
        get comments |
        flatten |
        get nodes |
        where { $in.author.login != $me }
    )

    let chosen_comments = (
        $comments |
        upsert display {|c|
            let width = ((term size).columns * 2 // 3)
            let body = (
                $c.body |
                str trim |
                lines |
                where { ($in | str length) > 3 } |
                first |
                str trim
            )
            $"[($c.author.login)] ($body)" | str substring 0..$width
        } |
        input list --multi --display "display"
    )
    
    let comment_prompts = $chosen_comments | each {|c|
        # let line_range = if ($c.start_line | is-empty) {
        #     $"line ($c.line)"
        # } else {
        #     $"lines ($c.start_line)-($c.line)"
        # }
        let body = (
            $c |
            get body |
            lines |
            each { $"> ($in)" } |
            str join "\n"
        )
$'
Feedback on ($c.path)
```diff
($c.diffHunk)
```
($body)
'
    }
    
    let prompt = [
        "**I have received the following code review feedback:**"
        "---"
        ...$comment_prompts
        "---"
        "Address this feedback. Follow existing patterns in the codebase."
    ] | str join "\n"
    
    codex $prompt
}
