#!/usr/bin/env nu

def main [issue] {
    cd ~/dirac

    let tmp = "buildos-web-tmp"
    gh repo clone diracq/buildos-web -- $tmp
    cd $tmp

    # TEMPORARY
    try { git checkout bweb-3265-script-for-agentic-ticket-work }

    nom develop --command issue $issue start
    let branch_name = (git branch --show-current)
    cd ..
    mv $tmp $branch_name
    cd $branch_name
    nom develop --command issue $issue agent
}
