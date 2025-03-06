# get table of monitor ids and workspace ids
def main [] {
    hyprctl monitors -j
    | from json
    | select id activeWorkspace.id
    | rename monitor workspace
}
