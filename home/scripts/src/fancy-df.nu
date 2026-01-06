#!/usr/bin/env nu

(
    df -h -P |
    detect columns --combine-columns -2.. |
    where "Filesystem" != "tmpfs" |
    update "Size" { || into filesize } |
    update "Used" { || into filesize } |
    update "Avail" { || into filesize }
)
