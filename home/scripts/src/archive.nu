#!/usr/bin/env nu

def usage-help [] {
  "use `archive compress` or `archive decompress`"
}

def fail [msg: string, help?: string] {
  error make {
    msg: $msg
    help: ($help | default (usage-help))
  }
}

def ensure-path-type [path: string, expected: string, label: string] {
  let actual = ($path | path type)

  if $actual == null {
    fail $"($label) does not exist: ($path)"
  }

  if $actual != $expected {
    fail $"($label) must be a ($expected): ($path)"
  }
}

def infer-format [path: string] {
  match $path {
    $value if ($value | str ends-with ".tar.gz") => { "tar.gz" }
    $value if ($value | str ends-with ".tar.zst") => { "tar.zst" }
    $value if ($value | str ends-with ".zip") => { "zip" }
    $value if ($value | str ends-with ".7z") => { "7z" }
    _ => {
      fail (
        $"unsupported archive format for `($path)`; expected one of .zip, .7z, .tar.gz, .tar.zst"
      )
    }
  }
}

def format-extension [format: string] {
  match $format {
    "tar.gz" => { "tar.gz" }
    "tar.zst" => { "tar.zst" }
    "zip" => { "zip" }
    "7z" => { "7z" }
    _ => { fail $"unsupported archive format: ($format)" }
  }
}

def archive-stem [archive: string] {
  let format = (infer-format $archive)
  $archive | path parse --extension (format-extension $format) | get stem
}

def resolve-output-path [
  mode: string
  primary: string
  destination?: string
] {
  match [$mode $destination] {
    ["compress" _] => { $primary | path expand }
    ["decompress" $target] if ($target | is-not-empty) => {
      $target | path expand
    }
    ["decompress" _] => {
      let archive = ($primary | path expand)
      let parent = ($archive | path parse | get parent)
      let stem = (archive-stem $archive)

      $parent | path join $stem
    }
    _ => { fail $"unsupported mode: ($mode)" }
  }
}

def assert-output-absent [output: string, --force(-f)] {
  if ($output | path exists) {
    if $force {
      rm -r -f $output
      return
    }

    fail $"output path already exists: ($output)" "choose a different output path or rerun with --force"
  }
}

def resolve-command [name: string] {
  let matches = (which $name | where type == "external" and path != "")

  if ($matches | is-empty) {
    fail $"required command not found on PATH: ($name)"
  }

  $matches | get 0.path
}

def resolve-7z-command [] {
  let seven_zz = (which 7zz | where type == "external" and path != "")
  if not ($seven_zz | is-empty) {
    return ($seven_zz | get 0.path)
  }

  let seven = (which 7z | where type == "external" and path != "")
  if not ($seven | is-empty) {
    return ($seven | get 0.path)
  }

  fail "required command not found on PATH: 7zz or 7z"
}

def ensure-compress-output-safe [input_path: string, output_path: string] {
  if $input_path == $output_path {
    fail "output archive path must be different from the input path"
  }

  let input_type = ($input_path | path type)
  if $input_type == "dir" {
    let prefix = $"($input_path)/"
    if (($output_path | str starts-with $prefix) or ($output_path == $input_path)) {
      fail "output archive cannot be created inside the directory being archived"
    }
  }
}

def --env run-from [dir: string, block: closure] {
  do --env {
    cd $dir
    do $block
  }
}

def dispatch [
  mode: string
  format: string
  input_path: string
  output_path: string
] {
  let source = ($input_path | path expand)
  let source_type = ($source | path type)
  let source_parent = ($source | path parse | get parent)
  let source_name = ($source | path basename)
  let work_dir = if $source_type == "dir" { $source } else { $source_parent }
  let archive_target = if $source_type == "dir" { "." } else { $source_name }

  match [$mode $format] {
    ["compress" "zip"] => {
      let zip = (resolve-command "zip")
      run-from $work_dir {||
        run-external $zip "-r" $output_path $archive_target
      }
    }
    ["compress" "7z"] => {
      let seven = (resolve-7z-command)
      run-from $work_dir {||
        run-external $seven "a" $output_path $archive_target
      }
    }
    ["compress" "tar.gz"] => {
      let tar = (resolve-command "tar")
      run-external $tar "-czf" $output_path "-C" $work_dir $archive_target
    }
    ["compress" "tar.zst"] => {
      let tar = (resolve-command "tar")
      let zstd = (resolve-command "zstd")
      run-external $tar "-I" $zstd "-cf" $output_path "-C" $work_dir $archive_target
    }
    ["decompress" "zip"] => {
      let unzip = (resolve-command "unzip")
      run-external $unzip $source "-d" $output_path
    }
    ["decompress" "7z"] => {
      let seven = (resolve-7z-command)
      run-external $seven "x" $source $"-o($output_path)"
    }
    ["decompress" "tar.gz"] => {
      let tar = (resolve-command "tar")
      run-external $tar "-xzf" $source "-C" $output_path
    }
    ["decompress" "tar.zst"] => {
      let tar = (resolve-command "tar")
      let zstd = (resolve-command "zstd")
      run-external $tar "-I" $zstd "-xf" $source "-C" $output_path
    }
    _ => {
      fail $"unsupported archive flow: ($mode) / ($format)"
    }
  }
}

def main [] {
  print (usage-help)
}

def "main compress" [
  --force(-f)
  input: string
  output_archive: string
] {
  let input_type = ($input | path type)
  match $input_type {
    "file" | "dir" => { null }
    null => { fail $"input does not exist: ($input)" }
    _ => { fail $"input must be a file or directory: ($input)" }
  }

  let input_path = ($input | path expand)
  let output_path = (resolve-output-path "compress" $output_archive)
  let format = (infer-format $output_path)

  ensure-compress-output-safe $input_path $output_path
  assert-output-absent --force=$force $output_path
  dispatch "compress" $format $input_path $output_path
}

def "main decompress" [
  --force(-f)
  archive: string
  destination?: string
] {
  ensure-path-type $archive "file" "archive"

  let archive_path = ($archive | path expand)
  let format = (infer-format $archive_path)
  let output_path = (resolve-output-path "decompress" $archive_path $destination)

  assert-output-absent --force=$force $output_path
  mkdir $output_path
  dispatch "decompress" $format $archive_path $output_path
}
