#!/usr/bin/env nu

def main [name: string] {
    cd ~/dirac

    let pristine = "./buildos-web-pristine"
    if (not ($pristine | path exists)) {
        gh repo clone diracq/buildos-web -- $pristine
        cd $pristine
        direnv exec mask test files download
    } else {
        cd $pristine
        git checkout main
        git pull
    }
    cd $pristine
    direnv exec mask install-web-dependencies

    cd ~/dirac
    let new_dir = $"./buildos-web-($name)"
    safe dir-cp $pristine $new_dir

    cd $new_dir
}
