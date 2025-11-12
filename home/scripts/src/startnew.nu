#!/usr/bin/env nu

def main [issue] {
    cd ~/dirac

    let tmp = "buildos-web-tmp"
    gh repo clone diracq/buildos-web -- $tmp
    cd $tmp

    # TEMPORARY
    git checkout bweb-3265-script-for-agentic-ticket-work

    nom develop --command issue $issue start agent
}
