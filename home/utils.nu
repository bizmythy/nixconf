# make input json and print with syntax highlighting
export def pjp [] {
    $in | to json | bat -l json
}
