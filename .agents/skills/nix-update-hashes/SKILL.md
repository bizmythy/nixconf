---
name: nix-update-hashes
description: Build Nix derivations and update fixed-output hashes from mismatch errors. Use when package sources, vendored dependencies, npm/cargo/vendor hashes, or fetcher hashes need refreshing.
---

# Nix Update Hashes

Common workflow:

1. Replace the stale hash with `lib.fakeHash` when possible.
   - Also works for fields like `hash`, `sha256`, `vendorHash`, `cargoHash`, `npmDepsHash`, etc. when accepted by the builder.
2. Build the narrowest target that exercises the hash.
3. Read the mismatch error and copy the `got:` / recommended hash.
4. Replace `lib.fakeHash` or the old hash with the reported SRI hash.
5. Rebuild to confirm.

Examples:

```bash
nix build .#<package> --print-build-logs
nix build .#<package> --keep-going --show-trace
nix flake check --keep-going --print-build-logs
```

Typical error shape:

```text
hash mismatch in fixed-output derivation ...
specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
got:       sha256-...
```

Prefer machine-readable output when available for surrounding inspection, but hash mismatch diagnostics are usually human-readable build logs.
