---
name: nix-package-search
description: Use nix-search to find Nix packages in nixpkgs or indexed flakes. Use when selecting package attribute names, checking versions, or finding which package provides a program.
---

# Nix Package Search

Use `nix-search` instead of guessing package names.

Prefer machine-readable output when available:

```bash
nix-search --json --max-results 10 <terms>
nix-search --json --name '<attr-or-pattern>'
nix-search --json --program <binary>
nix-search --json --channel unstable <terms>
nix-search --json --flakes <terms>
```

Useful flags:
- `--name`: package attribute/name search
- `--program`: search installed/provided program names
- `--version`: filter by version
- `--details`: expanded human-readable results
- `--query-string`: ElasticSearch query syntax

If unsure, run `nix-search --help` first.
