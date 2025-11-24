#!/usr/bin/env nu

let dirname = "ftbskies"
let dirpath = ("/home/drew/minecraft" | path join $dirname)

let now = (date now | format date "%Y-%m-%d-%H-%M-%S")

let filename = $"($dirname)_($now).tar.zst"

let workdir = (mktemp --directory)
cd $workdir

let output = (
    do {
        tar --zstd -cvf $filename $dirpath
        rclone copy $filename "pcloud-personal:minecraft_backups"
    } | complete
)

if ($output.exit_code != 0) {
    print "Backup command exited with error code."
    print $output
}

cd
rm -r $workdir
exit $output.exit_code
