#!/usr/bin/env nu

# fast dir copy using tar archive
def dir-cp [src, dst] {
    try { mkdir $dst }
    tar -C $src -cf - . | tar -C $dst -xf -
}

def main [issue] {
    cd ~/dirac

    let tmp = "buildos-web-tmp"
    new-buildos "tmp"
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
