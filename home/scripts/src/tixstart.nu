#!/usr/bin/env nu

def main [issue] {
    cd ~/dirac

    let pristine = "./buildos-web-pristine"
    if (not ($pristine | path exists)) {
        gh repo clone diracq/buildos-web -- $pristine
        cd $pristine
        direnv exec mask test files download
        direnv exec mask install-web-dependencies
        cd ~/dirac
    }

    let tmp = "buildos-web-tmp"
    rsync -avh --info=progress2 $"($pristine)/" $"($tmp)/"
    cd $tmp

    direnv exec . issue $issue start

    # rename folder to branch name
    let dir_name = $"buildos-web_(git branch --show-current)"
    cd ..
    mv $tmp $dir_name
    cd $dir_name

    # rename tab title to the issue name
    try { kitty @ set-tab-title $issue }

    # start agent workflow
    direnv exec . issue $issue agent
}
