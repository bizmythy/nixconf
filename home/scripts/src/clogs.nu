#!/usr/bin/env nu

cd ~/dirac/buildos-web
mask services savelogs
let log = (fd .log docker_compose_logs/ | fzf)
nvim $log
