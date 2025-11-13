#!/usr/bin/env nu

def main [issue] {
    cd ~/dirac

    let pristine = "./buildos-web-pristine"
    if (not ($pristine | path exists)) {
        gh repo clone diracq/buildos-web -- $pristine
    }

    let tmp = "buildos-web-tmp"
    rsync -avh --info=progress2 $"($pristine)/" $"($tmp)/"
    cd $tmp

    direnv exec . issue $issue start

    # rename folder to branch name
    let branch = git branch --show-current
    let dir_name = $"buildos-web_($branch)"
    cd ..
    mv $tmp $dir_name
    cd $dir_name

    # rename tab title to the ticket id
    try { kitty @ set-tab-title ($branch | str substring 0..8) }

    # start agent workflow
    direnv exec . issue $issue agent
}
