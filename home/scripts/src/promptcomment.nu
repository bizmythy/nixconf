#!/usr/bin/env nu

let repo = "diracq/buildos-web"

def main [pr: int] {
    let comments = (
        gh api
        --paginate
        -H "Accept: application/vnd.github+json"
        $"repos/($repo)/pulls/($pr)/comments?per_page=100"
    ) | from json

    let chosen_comments = (
        $comments |
        upsert display {|c|
            let width = ((term size).columns * 2 // 3)
            let body = (
                $c.body |
                str replace --all "\n" " " |
                str trim -c " " |
                str substring 0..$width |
                str trim
            )
            $"[($c.user.login)]($body)" | str substring 0..$width
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
($c.diff_hunk)
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
