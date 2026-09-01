{ platform, vars, ... }:

let
  cache = "${vars.home}/.cache/bazel";
  # Time Machine skips /var/tmp, so macOS keeps the large output_base there.
  outputBaseRoot = if platform.isDarwin then "/private/var/tmp" else "/var/tmp";
in
{
  # Bazel does not expand ~ or $HOME in .bazelrc, so every path is absolute.
  home.file.".bazelrc".text = ''
    # One output_base reused by every worktree. Bazel locks the output_base, so
    # concurrent invocations from different worktrees block on each other.
    startup --output_base=${outputBaseRoot}/_bazel_${vars.user}/shared

    common --repository_cache=${cache}/repo-cache
    common --experimental_repository_cache_hardlinks
    common --repo_contents_cache=${cache}/repo-contents-cache

    build --disk_cache=${cache}/disk-cache
    test  --disk_cache=${cache}/disk-cache
  '';
}
