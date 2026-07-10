# shellcheck shell=bash
# ai-usagebar — single Waybar button aggregating claudebar, codexbar, and
# grokbar into one module: compact per-agent percents in the bar, all three
# full breakdowns stacked in the hover popup, class = worst of the three.
#
# Usage: ai-usagebar [--color-low HEX] [--color-mid HEX] [--color-high HEX] [--color-critical HEX]

common_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --color-low | --color-mid | --color-high | --color-critical)
            common_args+=("$1" "${2:-}")
            shift 2
            ;;
        *) shift ;;
    esac
done

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

claudebar --format '{session_pct}%' "${common_args[@]}" >"$tmp/claude" 2>/dev/null &
codexbar --format '{session_pct}%' "${common_args[@]}" >"$tmp/codex" 2>/dev/null &
grokbar --format '{pct}%' "${common_args[@]}" >"$tmp/grok" 2>/dev/null &
wait

rank_of() {
    case "$1" in
        critical) echo 3 ;;
        high) echo 2 ;;
        mid) echo 1 ;;
        *) echo 0 ;;
    esac
}

text=""
tooltip=""
worst=0
for agent in claude codex grok; do
    case "$agent" in
        claude) icon="✳" ;;
        codex)  icon="⬡" ;;
        grok)   icon="𝕏" ;;
    esac
    if jq -e .text "$tmp/$agent" >/dev/null 2>&1; then
        a_text=$(jq -r '.text' "$tmp/$agent")
        a_tooltip=$(jq -r '.tooltip // ""' "$tmp/$agent")
        a_class=$(jq -r '.class // "critical"' "$tmp/$agent")
    else
        a_text="⚠"
        a_tooltip="$agent widget produced no output"
        a_class="critical"
    fi
    [[ -n "$text" ]] && text+="  "
    text+="$icon $a_text"
    [[ -n "$tooltip" ]] && tooltip+=$'\n\n'
    tooltip+="$a_tooltip"
    rank=$(rank_of "$a_class")
    (( rank > worst )) && worst=$rank
done

case "$worst" in
    3) class="critical" ;;
    2) class="high" ;;
    1) class="mid" ;;
    *) class="low" ;;
esac

jq -cn --arg t "$text" --arg tt "$tooltip" --arg c "$class" '{text: $t, tooltip: $tt, class: $c}'
