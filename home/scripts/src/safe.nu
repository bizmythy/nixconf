#!/usr/bin/env nu

use std/assert

def "main dir-cp" [src, dst] {
    assert not ($dst | path exists) "output path already exists"
    print $"Copying ($src) -> ($dst)"
    mkdir $dst
    tar -C $src -cf - . | tar -C $dst -xf -
}

def "main mv" [src, dst] {
    assert not ($dst | path exists) "output path already exists"
    print $"Moving ($src) -> ($dst)"
    mv $src $dst
}

def main [] {
    print "Must choose a sub-command"
}
