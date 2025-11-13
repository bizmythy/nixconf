#!/usr/bin/env nu

def main [issue] {
    cd ~/dirac

    let tmp = "buildos-web-tmp"
    gh repo clone diracq/buildos-web -- $tmp
    cd $tmp

    direnv exec . issue $issue start
    let branch_name = (git branch --show-current)
    cd ..
    mv $tmp $branch_name
    cd $branch_name
    direnv exec . issue $issue agent
}
