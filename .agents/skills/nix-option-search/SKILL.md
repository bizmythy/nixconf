---
name: nix-option-search
description: Use manix to search NixOS, Home Manager, nix-darwin, and nixpkgs documentation/options. Use when looking up module option names, meanings, defaults, or examples.
---

# Nix Option Search

Use `manix` before guessing NixOS or Home Manager option names.

Examples:

```bash
manix services.openssh
manix programs.git
manix --source nixos_options services.pipewire
manix --source hm_options wayland.windowManager.hyprland
manix --strict home.sessionVariables
```

Sources include `nixos_options`, `hm_options`, `nd_options`, `nixpkgs_doc`, `nixpkgs_tree`, and `nixpkgs_comments`.

`manix` does not currently provide JSON output; keep searches targeted and copy only the relevant option details. If unsure, run `manix --help` first.
