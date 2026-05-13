---
name: nixos-build
description: Use nh os build to build the NixOS configuration for the current host or a specified host. Use before switching/rebuilding to validate system config changes.
---

# NixOS Build

Use `nh os build` for NixOS system builds in this flake.

Current hostname:

```bash
nh os build
```

Explicit host from this repo's flake:

```bash
nh os build .#<hostname>
```

Useful flags:

```bash
nh os build --show-trace .#<hostname>
nh os build --keep-going .#<hostname>
nh os build --print-build-logs .#<hostname>
nh os build --dry .#<hostname>
```

Prefer structured/machine output where the underlying command supports it, but `nh os build` itself is primarily human-readable. If unsure about flags, run `nh os build --help`.
