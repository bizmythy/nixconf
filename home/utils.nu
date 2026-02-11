# make input json and print with syntax highlighting
export def pjp [] {
    $in | to json | bat -l json
}

# yazi "y" with current working directory provided function
def --env y [...args] {
    let tmp = (mktemp -t "yazi-cwd.XXXXXX")
    yazi ...$args --cwd-file $tmp
    let cwd = (open $tmp)
    if $cwd != "" and $cwd != $env.PWD {
        cd $cwd
	}
    rm -fp $tmp
}

def safe-dir-cp [src, dst] {
    assert not ($dst | path exists) "output path already exists"
    print $"Copying ($src) -> ($dst)"
    mkdir $dst
    tar -C $src -cf - . | tar -C $dst -xf -
}

def safe-mv [src, dst] {
    assert not ($dst | path exists) "output path already exists"
    print $"Moving ($src) -> ($dst)"
    mv $src $dst
}

def fzf-list [] {
    str join "\n" | fzf
}

def new-buildos [name: string] {
    cd ~/dirac

    let pristine = ("~/dirac/buildos-web-pristine" | path expand)
    if (not ($pristine | path exists)) {
        gh repo clone diracq/buildos-web -- $pristine
        cd $pristine
        direnv exec . mask test files download
    } else {
        cd $pristine
        git checkout main
        git pull
    }
    cd $pristine
    direnv exec . mask install-web-dependencies

    cd ~/dirac
    let new_dir = ($"./buildos-web-($name)" | path expand)
    safe-dir-cp $pristine $new_dir

    cd $new_dir
}

def open-buildos [] {
    ls ~/dirac |
    where name =~ "buildos-web" |
    get name |
    fzf-list |
    cd $in
}

def tixstart [issue, --agent] {
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

    if ($agent) {
        # start agent workflow
        direnv exec . issue $issue agent
    }
}

def df-fancy [] {
    df -h -P |
    detect columns --guess |
    where "Filesystem" != "tmpfs" |
    update "Size" { || into filesize } |
    update "Used" { || into filesize } |
    update "Avail" { || into filesize }
}

def clogs [] {
    let name = (gh repo view --json name -q ".name")
    if ($name != "buildos-web") {
        error make {msg: $"($name) is not buildos-web repo"}
    }
    mask services savelogs
    let log = (fd .log ./docker_compose_logs/ | fzf)
    nvim $log
}
