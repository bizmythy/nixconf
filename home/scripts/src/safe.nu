#!/usr/bin/env nu

use std/assert

def "main dir-cp" [src, dst] {
    assert not ($dst | path exists) "output path already exists"
    mkdir $dst
    tar -C $src -cf - . | tar -C $dst -xf -
}

def "main mv" [src, dst] {
    assert not ($dst | path exists) "output path already exists"
}

def main [] {
    print "Must choose a sub-command"
}
