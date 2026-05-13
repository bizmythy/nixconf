---
name: nix-flake-check
description: Run nix flake check to evaluate and build flake checks. Use after Nix changes to verify formatting/check outputs and catch evaluation/build errors.
---

# Nix Flake Check

Run from the repository root:

```bash
nix flake check
```

Useful variants:

```bash
nix flake check --no-build        # evaluate only
nix flake check --keep-going      # report more failures
nix flake check --show-trace      # detailed eval traces
nix flake check --all-systems     # broader validation, slower
```

For this repo, `nix flake check` includes the treefmt formatting check. Run `nix fmt` if formatting fails.

Nix flake check output is mostly human-readable; use targeted commands with JSON where available when inspecting sub-results. If unsure, run `nix flake check --help`.
