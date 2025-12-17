#!/usr/bin/env nu

let repo = "diracq/buildos-web"

def main [pr: int, --dry-run] {
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

    # get user selected comments to address
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
    
    # construct printout for each comment
    let comment_prompts = $chosen_comments | each {|c|
        def get-lines [line_field: string, start_line_field: string] {
            let bottom_line = ($c | get $line_field)
            let top_line = ($c | get $start_line_field -o | default ($bottom_line - 5))
            return ($bottom_line - $top_line)
        }
        let diff_size = (get-lines "line" "startLine") + (get-lines "originalLine" "originalStartLine")
        let diff = (
            $c |
            get diffHunk |
            lines |
            last $diff_size |
            str join "\n"
        )

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
($diff)
```
($body)
'
    }
    
    # concat to full prompt
    let prompt = [
        "**I have received the following code review feedback:**"
        "---"
        ...$comment_prompts
        "---"
        "Address this feedback. Follow existing patterns in the codebase."
    ] | str join "\n"
    
    if ($dry_run) {
        print $prompt
    } else {
        codex $prompt
    }
}
