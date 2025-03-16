export def pjp [] {
    $in | to json | bat -l json
}