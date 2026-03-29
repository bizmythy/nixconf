#!/usr/bin/env nu

# get the original location for the template repo and make sure it is up to date
def setup-template [] {
  let user = "bizmythy"
  gh auth switch --user $user

  let template_repo = "nix-project-template"
  let template_path = ("~/personal/" | path expand | path join $template_repo)

  if ($template_path | path exists) {
    cd $template_path
    git fetch
    git checkout main
    git pull
    cd -
  } else {
    print $"Cloning ($template_repo)"
    ^mkdir -p $template_path
    gh repo clone $"($user)/($template_repo)"
  }
  return $template_path
}

def make-template-copy [repo_path: string] {
  let template_path = (setup-template)

  mkdir $repo_path

  let exclude_args = [
    .git
    .gitmodules
    .direnv
    flake.lock
    README.md
    LICENSE
  ] | each {|path| $"--exclude=($path)" }

  rsync -a ...$exclude_args ($template_path + "/") ($repo_path + "/")

  return $repo_path
}

def main [repo_name: string] {
  let repo_path = (pwd | path join $repo_name)
  make-template-copy $repo_path

  cd $repo_path
  git init

  git add -A
  git commit -m "init: copy template"

  nix flake update
  git add flake.lock
  git commit -m "init: update flake.lock"

  print $"(ansi green)new repo configured:\n($repo_path)(ansi reset)"
}
