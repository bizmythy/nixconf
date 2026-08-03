#!/usr/bin/env nu

const games = [
  {
    app_id: "210970"
    name: "The Witness"
    save_path: "AppData/Roaming/The Witness"
    links: [
      {path: "Application Data", target: "AppData/Roaming"}
    ]
  }
  {
    app_id: "268910"
    name: "Cuphead"
    save_path: "AppData/Roaming/Cuphead"
    links: [
      {path: "Application Data", target: "AppData/Roaming"}
    ]
  }
  {
    app_id: "2129530"
    name: "REANIMAL"
    save_path: "AppData/Local/REANIMAL/Saved/SaveGames"
    links: [
      {
        path: "Local Settings/Application Data"
        target: "../AppData/Local"
      }
    ]
  }
]

def steamuser-dir [steam_library: path, app_id: string] {
  $steam_library
  | path join "steamapps" "compatdata" $app_id "pfx" "drive_c" "users" "steamuser"
}

def link-state [link_path: path, expected_target: string] {
  if not ($link_path | path exists) {
    return "missing"
  }

  let kind = ($link_path | path type)
  if $kind == "symlink" {
    let actual_target = (^readlink $link_path | str trim)
    if $actual_target == $expected_target {
      return "fixed"
    }
    return $"wrong-symlink:($actual_target)"
  }

  if $kind != "file" {
    return $"unexpected-($kind)"
  }

  let magic = (try {
    open --raw $link_path | bytes at 0..6 | decode
  } catch {
    ""
  })

  if $magic == "IntxLNK" {
    "legacy-intxlnk"
  } else {
    "unexpected-file"
  }
}

def checks [steam_library: path] {
  $games | each {|game|
    let user_dir = (steamuser-dir $steam_library $game.app_id)
    $game.links | each {|link|
      let link_path = ($user_dir | path join $link.path)
      {
        app_id: $game.app_id
        game: $game.name
        link: $link_path
        target: $link.target
        state: (link-state $link_path $link.target)
      }
    }
  } | flatten
}

def main [
  --apply
  --backup-dir: path
  --steam-library: path = "/mnt/storage/SteamLibrary"
] {
  let steam_library = ($steam_library | path expand)
  let inspection = (checks $steam_library)
  print ($inspection | select app_id game state link target | table)

  let invalid = ($inspection | where state not-in ["legacy-intxlnk" "fixed"])
  if ($invalid | is-not-empty) {
    error make {
      msg: "Refusing to continue: one or more paths do not match a known safe state."
    }
  }

  if not $apply {
    print ""
    print "Validation only: no files were changed."
    print "Run again with --apply to back up saves and replace legacy IntxLNK records."
    return
  }

  let steam_processes = (ps | where name =~ "(?i)steam")
  if ($steam_processes | is-not-empty) {
    print ($steam_processes | select pid name | table)
    error make {msg: "Steam is running. Exit Steam before applying repairs."}
  }

  let backup_parent = if $backup_dir == null {
    $env.HOME | path join "steam-cloud-repair-backups"
  } else {
    $backup_dir | path expand
  }
  let timestamp = (date now | format date "%Y%m%d-%H%M%S")
  let run_backup = ($backup_parent | path join $timestamp)
  mkdir $run_backup

  for game in $games {
    let user_dir = (steamuser-dir $steam_library $game.app_id)
    let game_backup = ($run_backup | path join $game.app_id)
    mkdir $game_backup

    let save_path = ($user_dir | path join $game.save_path)
    if ($save_path | path exists) {
      cp --recursive $save_path ($game_backup | path join "save-data")
    }

    for link in $game.links {
      let link_path = ($user_dir | path join $link.path)
      let state = (link-state $link_path $link.target)
      if $state == "fixed" {
        continue
      }

      let safe_name = ($link.path | str replace --all "/" "_" | str replace --all " " "_")
      let external_backup = ($game_backup | path join $"($safe_name).intxlnk")
      let adjacent_backup = $"($link_path).intxlnk-backup-($timestamp)"

      cp $link_path $external_backup
      mv $link_path $adjacent_backup

      ^ln -s -- $link.target $link_path
      if $env.LAST_EXIT_CODE != 0 {
        mv $adjacent_backup $link_path
        error make {msg: $"Failed to create symlink for ($game.name); original restored."}
      }

      if (link-state $link_path $link.target) != "fixed" {
        error make {
          msg: $"Created link for ($game.name), but validation failed. Original remains at ($adjacent_backup)."
        }
      }
    }
  }

  print ""
  print $"Repair complete. Backups: ($run_backup)"
  print "Start Steam and retry Cloud Sync for REANIMAL, Cuphead, and The Witness."
}
