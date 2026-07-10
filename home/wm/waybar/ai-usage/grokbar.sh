# shellcheck shell=bash
# grokbar — Grok Build (pi grok-cli) plan usage widget for Waybar.
# Companion to mryll/claudebar and mryll/codexbar, matching their output
# contract: {"text": ..., "tooltip": <Pango markup>, "class": low|mid|high|critical}.
#
# Reads the OAuth credentials pi-grok-cli stores in ~/.pi/agent/auth.json,
# refreshes them when close to expiry (writing back atomically like pi does),
# and fetches monthly credit + weekly limit usage from the xAI billing API.
#
# Usage: grokbar [--icon ICON] [--format FORMAT]
#                [--color-low HEX] [--color-mid HEX] [--color-high HEX] [--color-critical HEX]
#
# Format placeholders ({pct}/{reset} track the tighter window — weekly when
# the plan has one, else monthly):
#   {pct}    usage %
#   {reset}  countdown (e.g. "5d 22h")

AUTH_FILE="${GROKBAR_AUTH_FILE:-$HOME/.pi/agent/auth.json}"
AUTH_KEY="grok-cli"
# Same public client id pi-grok-cli uses for its OAuth flow
CLIENT_ID="${PI_GROK_CLI_OAUTH_CLIENT_ID:-b1a00492-073a-47ea-816f-4c329264a828}"
DEFAULT_BASE_URL="https://cli-chat-proxy.grok.com/v1"
DEFAULT_TOKEN_ENDPOINT="https://auth.x.ai/oauth2/token"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/grokbar"
CACHE_TTL=60
REFRESH_GRACE=300 # refresh token when within 5 min of expiry, like pi does

ICON=""
FORMAT="{pct}% · {reset}"
COLOR_LOW="#98c379"
COLOR_MID="#e5c07b"
COLOR_HIGH="#d19a66"
COLOR_CRITICAL="#e06c75"
# One Dark accents, matching claudebar/codexbar defaults
BLUE="#61afef"
DIM="#5c6370"
FG="#abb2bf"
BAR_EMPTY="#3e4451"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --icon)           ICON="${2:-}"; shift 2 ;;
        --format)         FORMAT="${2:-$FORMAT}"; shift 2 ;;
        --color-low)      COLOR_LOW="${2:-$COLOR_LOW}"; shift 2 ;;
        --color-mid)      COLOR_MID="${2:-$COLOR_MID}"; shift 2 ;;
        --color-high)     COLOR_HIGH="${2:-$COLOR_HIGH}"; shift 2 ;;
        --color-critical) COLOR_CRITICAL="${2:-$COLOR_CRITICAL}"; shift 2 ;;
        *) shift ;;
    esac
done

json_out() { # text tooltip class
    jq -cn --arg t "$1" --arg tt "$2" --arg c "$3" '{text: $t, tooltip: $tt, class: $c}'
}

die() {
    local text="⚠"
    [[ -n "$ICON" ]] && text="$ICON ⚠"
    json_out "$text" "$1" "critical"
    exit 0
}

[[ -r "$AUTH_FILE" ]] || die "grokbar: $AUTH_FILE not found — run pi and /login into grok-cli"

auth=$(jq -ce --arg k "$AUTH_KEY" '.[$k] // empty' "$AUTH_FILE" 2>/dev/null) \
    || die "grokbar: no $AUTH_KEY credentials in $AUTH_FILE — run pi and /login into grok-cli"

access=$(jq -r '.access // empty' <<<"$auth")
refresh=$(jq -r '.refresh // empty' <<<"$auth")
expires_ms=$(jq -r '.expires // 0' <<<"$auth")
token_endpoint=$(jq -r '.tokenEndpoint // empty' <<<"$auth")
base_url=$(jq -r '.baseUrl // empty' <<<"$auth")
[[ -n "$token_endpoint" ]] || token_endpoint="$DEFAULT_TOKEN_ENDPOINT"
[[ -n "$base_url" ]] || base_url="$DEFAULT_BASE_URL"
[[ -n "$access" ]] || die "grokbar: empty access token — run pi and /login into grok-cli"

now=$(date +%s)

refresh_token() {
    [[ -n "$refresh" ]] || return 1
    local resp new_access new_refresh expires_in
    resp=$(curl -fsS --max-time 15 -X POST "$token_endpoint" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -H 'Accept: application/json' \
        --data-urlencode "grant_type=refresh_token" \
        --data-urlencode "client_id=$CLIENT_ID" \
        --data-urlencode "refresh_token=$refresh") || return 1
    new_access=$(jq -r '.access_token // empty' <<<"$resp")
    [[ -n "$new_access" ]] || return 1
    new_refresh=$(jq -r '.refresh_token // empty' <<<"$resp")
    expires_in=$(jq -r '.expires_in // 3600' <<<"$resp")
    access="$new_access"
    [[ -n "$new_refresh" ]] && refresh="$new_refresh"
    expires_ms=$(( (now + expires_in) * 1000 ))
    # Write back atomically, preserving the other providers in the file
    local tmp
    tmp=$(mktemp "${AUTH_FILE}.XXXXXX") || return 0
    if jq --arg k "$AUTH_KEY" --arg a "$access" --arg r "$refresh" --argjson e "$expires_ms" \
        '.[$k].access = $a | .[$k].refresh = $r | .[$k].expires = $e' "$AUTH_FILE" >"$tmp" 2>/dev/null; then
        chmod 600 "$tmp" && mv "$tmp" "$AUTH_FILE"
    else
        rm -f "$tmp"
    fi
    return 0
}

if (( expires_ms / 1000 - now < REFRESH_GRACE )); then
    refresh_token || die "grokbar: token refresh failed — run pi and /login into grok-cli"
fi

# ── Fetch (60s cache, single flight via flock) ────────────────────────────────
mkdir -p "$CACHE_DIR"
cache="$CACHE_DIR/usage.json"
fetch_failed=0

cache_mtime=$(stat -c %Y "$cache" 2>/dev/null) || cache_mtime=0
if [[ ! -s "$cache" ]] || (( now - cache_mtime >= CACHE_TTL )); then
    exec 9>"$CACHE_DIR/.lock"
    if flock -w 20 9; then
        # Re-check: another instance may have refreshed while we waited
        cache_mtime=$(stat -c %Y "$cache" 2>/dev/null) || cache_mtime=0
        if [[ ! -s "$cache" ]] || (( now - cache_mtime >= CACHE_TTL )); then
            hdr_auth="authorization: Bearer $access"
            hdr_xai="x-xai-token-auth: xai-grok-cli"
            monthly=$(curl -fsS --max-time 15 -H "$hdr_auth" -H "$hdr_xai" \
                -H 'accept: application/json' "$base_url/billing")
            if [[ -n "$monthly" ]] && jq -e '.config' <<<"$monthly" >/dev/null 2>&1; then
                weekly=$(curl -fsS --max-time 15 -H "$hdr_auth" -H "$hdr_xai" \
                    -H 'accept: application/json' "$base_url/billing?format=credits") || weekly=""
                jq -e . <<<"$weekly" >/dev/null 2>&1 || weekly="null"
                tmp=$(mktemp "$CACHE_DIR/.usage.XXXXXX")
                if jq -cn --argjson m "$monthly" --argjson w "$weekly" \
                    '{monthly: $m, weekly: $w}' >"$tmp" 2>/dev/null; then
                    mv "$tmp" "$cache"
                else
                    rm -f "$tmp"
                    fetch_failed=1
                fi
            else
                fetch_failed=1
            fi
        fi
    fi
    exec 9>&-
fi

[[ -s "$cache" ]] || die "grokbar: billing fetch failed (no cached data)"

# ── Parse ─────────────────────────────────────────────────────────────────────
IFS=$'\t' read -r m_used m_limit m_pct m_end w_pct w_end < <(jq -r '
    (.monthly.config) as $m
    | (if (.weekly.config.currentPeriod.type // "") == "USAGE_PERIOD_TYPE_WEEKLY"
       then .weekly.config else null end) as $w
    | [
        ($m.used.val // 0 | round),
        ($m.monthlyLimit.val // 0 | round),
        (if ($m.monthlyLimit.val // 0) > 0
         then (($m.used.val // 0) / $m.monthlyLimit.val * 100 | round) else 0 end),
        ($m.billingPeriodEnd // ""),
        (if $w then ($w.creditUsagePercent | round) else -1 end),
        (if $w then ($w.billingPeriodEnd // "") else "" end)
      ] | @tsv' "$cache")

pct_color() {
    if   (( $1 >= 90 )); then printf '%s' "$COLOR_CRITICAL"
    elif (( $1 >= 75 )); then printf '%s' "$COLOR_HIGH"
    elif (( $1 >= 50 )); then printf '%s' "$COLOR_MID"
    else printf '%s' "$COLOR_LOW"
    fi
}

bar() { # pct color
    local pct=$1 color=$2 filled i full="" empty=""
    filled=$(( pct * 20 / 100 ))
    (( filled > 20 )) && filled=20
    (( filled < 0 )) && filled=0
    for (( i = 0; i < filled; i++ )); do full+="█"; done
    for (( i = filled; i < 20; i++ )); do empty+="░"; done
    printf "<span foreground='%s'>%s</span><span foreground='%s'>%s</span>" \
        "$color" "$full" "$BAR_EMPTY" "$empty"
}

fmt_reset() { # ISO timestamp -> "3d 4h" / "4h 52m" / "12m"
    local end_s d
    end_s=$(date -d "$1" +%s 2>/dev/null) || { printf '?'; return; }
    d=$(( end_s - now ))
    (( d < 0 )) && d=0
    if (( d >= 86400 )); then
        printf '%dd %dh' $(( d / 86400 )) $(( d % 86400 / 3600 ))
    elif (( d >= 3600 )); then
        printf '%dh %dm' $(( d / 3600 )) $(( d % 3600 / 60 ))
    else
        printf '%dm' $(( d / 60 ))
    fi
}

commafy() { sed ':a;s/\B[0-9]\{3\}\>/,&/;ta' <<<"$1"; }

# ── Render ────────────────────────────────────────────────────────────────────
max_pct=$m_pct
(( w_pct > max_pct )) && max_pct=$w_pct
if   (( max_pct >= 90 )); then class="critical"
elif (( max_pct >= 75 )); then class="high"
elif (( max_pct >= 50 )); then class="mid"
else class="low"
fi

# Bar text tracks the tighter window: weekly when the plan has one, else monthly
if (( w_pct >= 0 )); then
    text_pct=$w_pct; text_reset=$(fmt_reset "$w_end")
else
    text_pct=$m_pct; text_reset=$(fmt_reset "$m_end")
fi
text_body="${FORMAT//\{pct\}/$text_pct}"
text_body="${text_body//\{reset\}/$text_reset}"
text="<span foreground='$(pct_color "$text_pct")'>${text_body}</span>"
[[ -n "$ICON" ]] && text="$ICON $text"

rule="<span foreground='$DIM'>──────────────────────────────</span>"
tooltip=" <span font_weight='bold' foreground='$BLUE'>Grok Build</span>
 $rule
"
if (( w_pct >= 0 )); then
    tooltip+="
 <span foreground='$FG'>  󰔟  Weekly</span>
   $(bar "$w_pct" "$(pct_color "$w_pct")")   <span font_weight='bold' foreground='$(pct_color "$w_pct")'>${w_pct}%</span>
 <span foreground='$DIM'>  󰥔  Resets in $(fmt_reset "$w_end")</span>
"
fi
tooltip+="
 <span foreground='$FG'>  󰃰  Monthly credits</span>
   $(bar "$m_pct" "$(pct_color "$m_pct")")   <span font_weight='bold' foreground='$(pct_color "$m_pct")'>${m_pct}%</span>
 <span foreground='$DIM'>  󰄑  $(commafy "$m_used") / $(commafy "$m_limit") used</span>
 <span foreground='$DIM'>  󰥔  Resets in $(fmt_reset "$m_end")</span>

 $rule"
updated=$(date -d "@$(stat -c %Y "$cache" 2>/dev/null || echo "$now")" +%H:%M)
stale=""
(( fetch_failed )) && stale=" (stale)"
tooltip+="
 <span foreground='$DIM'>  󰅐  Updated ${updated}${stale}</span>"

json_out "$text" "$tooltip" "$class"
