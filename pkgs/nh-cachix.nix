{
  bash,
  cachix,
  coreutils,
  lib,
  nh,
  writeShellApplication,
}:

writeShellApplication {
  name = "nh";
  excludeShellChecks = [ "SC2016" ];
  text = ''
    if [[ "''${1-}" != "os" ]]; then
      exec ${lib.getExe nh} "$@"
    fi

    status_file="$(${lib.getExe' coreutils "mktemp"})"
    cleanup() {
      ${lib.getExe' coreutils "rm"} -f "$status_file"
    }
    trap cleanup EXIT

    set +e
    NH_CACHIX_STATUS_FILE="$status_file" \
      ${lib.getExe cachix} watch-exec \
        --watch-mode post-build-hook \
        bizmythy-nixconf -- \
        ${lib.getExe bash} -c '
          "$@"
          status=$?
          printf "%s\n" "$status" > "$NH_CACHIX_STATUS_FILE"
          exit "$status"
        ' bash ${lib.getExe nh} "$@"
    cachix_status=$?
    set -e

    nh_status=""
    if [[ -s "$status_file" ]]; then
      read -r nh_status < "$status_file"
    fi

    if [[ -n "$nh_status" ]]; then
      if ((nh_status != 0)); then
        exit "$nh_status"
      fi

      if ((cachix_status != 0)); then
        printf \
          'warning: nh succeeded, but pushing to Cachix failed (exit %s)\n' \
          "$cachix_status" >&2
      fi
      exit 0
    fi

    printf \
      'warning: Cachix failed before nh started; continuing without upload\n' \
      >&2
    exec ${lib.getExe nh} "$@"
  '';

  meta = {
    description = "nh with automatic Cachix uploads for NixOS commands";
    inherit (nh.meta) homepage license;
    mainProgram = "nh";
  };
}
