---
name: nix-option-search
description: Use manix to search NixOS, Home Manager, nix-darwin, and nixpkgs documentation/options. Use when looking up module option names, meanings, defaults, or examples.
---

# Nix Option Search

Use `manix` before guessing NixOS or Home Manager option names.

Always use manix's JSON output (`--json`/`-j`); do not use the human-readable output. The JSON result has an `entries` array. Each entry includes `kind`, `source`, `name`, and a `documentation` object (commonly containing `description`, `type`, `default`, `example`, and `readOnly`). Inspect or filter that structured output as needed.

Examples:

```bash
manix --json services.openssh
manix --json programs.git
manix --json --source nixos-options services.pipewire
manix --json --source hm-options wayland.windowManager.hyprland
manix --json --strict home.sessionVariables
```

Sources include `nixos-options`, `hm-options`, `nd-options`, `nixpkgs-doc`, `nixpkgs-tree`, and `nixpkgs-comments`. Combine `--strict` with `--json` when looking up an exact option. If unsure about flags or output, run `manix --help` first (and retain `--json` for the actual search).
