let monitorsInfo = hyprctl monitors -j | from json

let monToWS = (
    $monitorsInfo
    | select id activeWorkspace.id
    | rename monitor workspace
)
print $monToWS

let activeWS = (
    hyprctl activeworkspace -j
    | from json
    | get id
)
print $activeWS

