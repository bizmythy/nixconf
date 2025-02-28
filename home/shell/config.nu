# get environment variables from .env file
def read-env-file [file_path: string] {
    open $file_path
    | parse "{key}={value}"
    | reduce -f {} {|row, acc|
        $acc | merge { ($row.key): $row.value }
    }
}

# load environment variables from secrets.env
let secrets_file = "/home/drew/.config/secrets.env"
try {
    read-env-file $secrets_file | load-env
} catch {
    echo "Error loading environment variables from " + $secrets_file
}

$env.config.show_banner = false
$env.config.buffer_editor = "nvim"