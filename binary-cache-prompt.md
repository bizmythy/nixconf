i want a binary cachix cache configured for my system builds.

this way, things like `whiskers` (downstream of catppuccin-nix), `tuicr`, etc. won't rebuild after i build/push that version.

you have `cachix` available (already authenticated) and i already created a binary cache for this: https://app.cachix.org/cache/bizmythy-nixconf

if possible, you should do the following:
- make it so that `nh os ...` commands automatically push to cachix binary cache once built
    - failure here should be non-fatal, just a warning if the push fails
- add the binary cache at highest priority (i think?) to configured caches
- any other config needed to get required effect

