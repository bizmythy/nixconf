# --------- CONSTS ---------

const PROMPTS = {
  rust_lint: "
run `mask lint rust` and fix all warnings and errors.

we want to generally avoid panics. if possible, errors should be propogated up.
if impossible or if errors are truly certain to never occurr, you should use .expect() with an explicit nolint comment with an explanation comment explaining why this is safe to use
> in test files, do not panic. use `assertables` properly to assert what you need to check.

do not attempt to circumvent with inlined panic calls.
"
  git_conflicts: "
view the git context for the current repository branch and main.
then, resolve all conflicts and proceed with the current operation (rebase, cherry pick, merge, etc.) until fully complete and all conflicts are resolved.

when resolving conflicts, ALWAYS analyze semantically and preserve the intention of BOTH sides of the conflict whenever possible.
if it is unclear, you should read commit messages and understand the contextual info such that you can safely resolve without deleting crucial work.
"
}

# --------- COMMANDS ---------

# make input json and print with syntax highlighting
export def pjp [] {
  $in | to json | bat -l json
}

def safe-dir-cp [src dst] {
  use std/assert
  assert not ($dst | path exists) "output path already exists"
  print $"Copying ($src) -> ($dst)"
  mkdir $dst
  tar -C $src -cf - . | tar -C $dst -xf -
}

def safe-mv [src dst] {
  use std/assert
  assert not ($dst | path exists) "output path already exists"

  print $"Moving ($src) -> ($dst)"
  mv $src $dst
}

def fzf-list [] {
  str join "\n" | fzf
}

def --env new-buildos [name: string] {
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

def --env open-buildos [] {
  ls ~/dirac | where name =~ "buildos-web" | sort-by modified | get name | fzf-list | cd $in
}

def tixstart [issue --agent] {
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
  df -h -P | detect columns --guess | where "Filesystem" != "tmpfs" | update "Size" {|| into filesize } | update "Used" {|| into filesize } | update "Avail" {|| into filesize }
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

def fopen [search: string] {
  fd $search ./ | fzf | nvim $in
}

# Compress a directory as a tarball using zst compression
def "tarzst compress" [directory: string] {
  use std/assert
  assert equal ($directory | path type) "dir" "Directiory to compress is not a directory!"
  let basename = ($directory | path basename | $in + ".tar.zst")
  tar -I zstd -cf $basename $directory
}

# Decompress a zst compressed tarball
def "tarzst decompress" [file: string] {
  use std/assert
  assert equal ($file | path type) "file" "Path to decompress is not a file!"
  assert ($file | str ends-with ".tar.zst") "File is not a zst compressed tarball!"
  tar -I zstd -xf $file
}
