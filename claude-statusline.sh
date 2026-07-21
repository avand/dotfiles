#!/usr/bin/env bash
# Claude Code status line. Receives session JSON on stdin.
# Left:  <tenant-chip> <name>  ·  <branch (#PR)>
# Right: <Model (effort)>  ·  <ctx% ($cost)>
export LC_ALL="${LC_ALL:-en_US.UTF-8}"   # so ${#var} counts columns, not bytes

input=$(cat)

IFS=$'\t' read -r cwd name model effort pct cost pr transcript ctxtokens < <(
  printf '%s' "$input" | jq -r '
    [ (.cwd // .workspace.current_dir // ""),
      (.session_name // "-"),
      (.model.display_name // "?"),
      (.effort.level // "-"),
      (.context_window.used_percentage // "-"),
      (.cost.total_cost_usd // 0),
      (.pr.number // "-"),
      (.transcript_path // ""),
      ((.context_window.current_usage.cache_read_input_tokens // 0)
        + (.context_window.current_usage.cache_creation_input_tokens // 0)
        + (.context_window.current_usage.input_tokens // 0))
    ] | @tsv'
)

width="${COLUMNS:-}"
[[ -z "$width" ]] && width="$(tput cols 2>/dev/null)"
[[ -z "$width" ]] && width=120

# --- colors ---
ESC=$'\033'
DIM="${ESC}[2m"; RESET="${ESC}[0m"
DOT=" · "

TENANT_BGS=(26 28 91 166 30 127)     # blue green purple orange teal pink
TENANT_LIGHTS=(111 114 140 215 116 176)  # light siblings, same hue order
DEFAULT_BG=240                       # gray, for non-tenant dirs
DEFAULT_LIGHT=252                    # light gray, for non-tenant dirs
BRANCHFG="${ESC}[38;5;${DEFAULT_BG}m"   # branch/PR text in the default-gray

# --- Anthropic pricing — verified 2026-06-24, update from time to time as rates change ---
# https://platform.claude.com/docs/en/about-claude/pricing  (base $/M input, cache rules)
# These are constants, NOT derived: the transcript carries token counts only, no prices.
# Opus 4.5+/Sonnet 4.6/Fable 5 carry NO >200K long-context premium — the full 1M window
# bills at the standard per-token rate, so there is no cliff to anchor anything to.
READ_MULT=0.1                             # cache-read rate as a fraction of base input
OPUS_RATE=5; SONNET_RATE=3; HAIKU_RATE=1  # base $/M input by model family (Opus 4.5+)
DEFAULT_RATE=5                            # fallback when the model name matches none of the above
TTL_5M=300;  WRITE_MULT_5M=1.25           # 5-minute cache: TTL seconds, write-rate multiplier
TTL_1H=3600; WRITE_MULT_1H=2.0            # 1-hour cache:   TTL seconds, write-rate multiplier

# --- bar color policy: tracks % of the context window used (no pricing cliff anymore) ---
WARN_PCT=50                               # bar turns orange at this much of the window
DANGER_PCT=80                             # bar turns red here

EDGE_MARGIN=6                      # Claude's usable width is ~4-6 cols under reported COLUMNS; stay inside it
MIN_GAP=3                          # smallest gap between left and right before the name shrinks
DEV_GLYPH="●"                      # shown when this tenant is running bin/dev
DEV_COLOR="${ESC}[38;5;46m"        # bright green
NAME_CAP=""                        # trailing cap on the name frame ("" to disable)

# --- directory: collapse ~/Code/the-intern/tenant-* to tenant-*, else ~-abbreviate ---
the_intern="$HOME/Code/the-intern"
chip_bg=$DEFAULT_BG
chip_light=$DEFAULT_LIGHT
tenant_num=""
if [[ "$cwd" == "$the_intern/tenant-"* ]]; then
  dir="${cwd#$the_intern/}"
  rest="${cwd#$the_intern/tenant-}"
  tenant_num="${rest%%/*}"
  if [[ "$tenant_num" =~ ^[0-9]+$ ]]; then
    idx=$(( (tenant_num - 1) % ${#TENANT_BGS[@]} ))
    chip_bg=${TENANT_BGS[$idx]}
    chip_light=${TENANT_LIGHTS[$idx]}
  fi
elif [[ "$cwd" == "$HOME" ]]; then
  dir="~"
elif [[ "$cwd" == "$HOME"/* ]]; then
  dir="~${cwd#$HOME}"
else
  dir="$cwd"
fi
DIRCHIP="${ESC}[48;5;${chip_bg};38;2;255;255;255m"   # tenant background + true white text (97 is theme-remapped gray in Ghostty)
NAMECHIP="${ESC}[48;5;${chip_light};38;5;${chip_bg}m"  # light tenant bg + dark-hue text

# --- is THIS tenant running bin/dev? The overmind daemon's CWD is the tenant's
# rails dir, so a live process there is the ground truth. We used to probe
# tenant-N/rails/.overmind.sock, but bin/dev's restart/cleanup path can unlink
# that socket out from under a running daemon (the fd stays open, the file
# vanishes), so the file's absence was a false negative. ---
dev_running=0
if [[ -n "$tenant_num" ]] && \
   lsof -a -c overmind -d cwd -Fn 2>/dev/null \
     | grep -Fxq "n${the_intern}/tenant-${tenant_num}/rails"; then
  dev_running=1
fi

# --- session name (sized dynamically during assembly) ---
name_full=""
[[ "$name" != "-" && -n "$name" ]] && name_full="$name"

# --- branch (+ PR number) ---
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
branch_txt=""
if [[ -n "$branch" ]]; then
  if [[ "$pr" != "-" && -n "$pr" ]]; then
    branch_txt="${branch} (#${pr})"
  else
    branch_txt="${branch}"
  fi
fi

# --- model (+ effort) ---
if [[ "$effort" != "-" && -n "$effort" ]]; then
  model_txt="${model} (${effort})"
else
  model_txt="${model}"
fi

# --- context cost gauge. The bar both FILLS and COLORS by context-window % (orange at
# WARN_PCT, red at DANGER_PCT). Label is "<pct>% · +$/msg": the per-message tax is the
# cost of re-reading the cached prefix (0.1x base) on every turn. The cache clock is a
# SEPARATE segment after the bar with its own color, counting down the next message's
# cache-priming cost ("+$1.20 in 59:46") until the TTL lapses, then showing it as due
# ("+$1.20 to prime"). Tier/TTL come from the transcript's ephemeral_5m/1h writes. ---
costfmt=$(awk -v c="$cost" '
  function money(x,   cents) { cents = int(x*100 + 0.5); return (cents < 100) ? cents "¢" : sprintf("$%.2f", x) }
  BEGIN { printf "%s", money(c) }')

cache_tier="1h"
if [[ -f "$transcript" ]]; then
  detected=$(tail -n 60 "$transcript" 2>/dev/null \
    | jq -rR 'fromjson? | (.message.usage.cache_creation // empty)
        | select(((.ephemeral_5m_input_tokens // 0) + (.ephemeral_1h_input_tokens // 0)) > 0)
        | if (.ephemeral_1h_input_tokens // 0) > 0 then "1h" else "5m" end' \
    | tail -n 1)
  [[ -n "$detected" ]] && cache_tier="$detected"
fi
if [[ "$cache_tier" == "5m" ]]; then CACHE_TTL=$TTL_5M; write_mult=$WRITE_MULT_5M; else CACHE_TTL=$TTL_1H; write_mult=$WRITE_MULT_1H; fi

case "$model" in
  *Opus*)   base=$OPUS_RATE ;;
  *Sonnet*) base=$SONNET_RATE ;;
  *Haiku*)  base=$HAIKU_RATE ;;
  *)        base=$DEFAULT_RATE ;;
esac

permsg=""; coldmsg=""
if [[ "$ctxtokens" =~ ^[0-9]+$ ]] && (( ctxtokens > 0 )); then
  read -r permsg coldmsg < <(awk -v t="$ctxtokens" -v b="$base" -v w="$write_mult" -v rm="$READ_MULT" '
    function money(x,   cents) { cents = int(x*100 + 0.5); return (cents < 100) ? cents "¢" : sprintf("$%.2f", x) }
    BEGIN {
      printf "+%s/msg +%s", money(t * b * rm / 1e6), money(t * b * w / 1e6)
    }')
fi

# --- cache clock: counts down the next message's priming cost ("+$1.20 in 59:46").
# Gray while fresh, amber past 80% of the TTL elapsed, blinking red past 90%. Once the
# TTL lapses the countdown is gone — the cost is now due, shown as a solid red chip
# ("+$1.20"). Hidden whenever the bar is (no context % → no cache to count down). ---
clock_plain=""; clock_color=""
if [[ "$pct" != "-" && -n "$pct" && -f "$transcript" && -n "$coldmsg" ]]; then
  mtime=$(stat -f %m "$transcript" 2>/dev/null)
  if [[ -n "$mtime" ]]; then
    elapsed=$(( $(date +%s) - mtime )); (( elapsed < 0 )) && elapsed=0
    remaining=$(( CACHE_TTL - elapsed ))
    if (( remaining > 0 )); then
      clock_plain=$(printf '%s in %d:%02d' "$coldmsg" "$(( remaining / 60 ))" "$(( remaining % 60 ))")
      expired_pct=$(( elapsed * 100 / CACHE_TTL ))
      if   (( expired_pct >= 90 )); then clk="${ESC}[5m${ESC}[38;5;160m"
      elif (( expired_pct >= 80 )); then clk="${ESC}[38;5;208m"
      else clk="$BRANCHFG"; fi
      clock_color="${clk}${clock_plain}${RESET}"
    else
      clock_plain=" ${coldmsg} "                                  # cache busted: red chip with internal padding, floated one plain space off the bar
      clock_color="${ESC}[48;5;160;38;2;255;255;255m ${coldmsg} ${RESET}"
    fi
  fi
fi

if [[ "$pct" != "-" && -n "$pct" ]]; then
  pctint=$(awk -v p="$pct" 'BEGIN { printf "%d", p+0.5 }')
  read -r fillbg trackbg emptyfg <<<"$(awk -v p="$pct" -v warn="$WARN_PCT" -v danger="$DANGER_PCT" 'BEGIN {
    if (p+0 >= danger) print "160 174 88";
    else if (p+0 >= warn) print "208 215 166";
    else print "28 114 22";
  }')"
  bar_label="${pctint}%"
  [[ -n "$permsg" ]] && bar_label+="${DOT}${permsg}"
  bar_text=" ${bar_label} "
  bar_plain="$bar_text"
  n=${#bar_text}
  filled=$(awk -v n="$n" -v p="$pct" 'BEGIN { f=int(n*p/100 + 0.5); if (f>n) f=n; if (f<0) f=0; print f }')
  pstr="${pctint}%"
  bs=1; be=$(( 1 + ${#pstr} )); (( be > n )) && be=$n   # bold the "NN%" after the leading pad space
  bar_color=""; prev=0
  for b in $(printf '%s\n' "$bs" "$be" "$filled" "$n" | sort -n | uniq); do
    (( b <= prev )) && continue
    seg="${bar_text:prev:b-prev}"
    if (( prev < filled )); then col="${ESC}[48;5;${fillbg};38;2;255;255;255m"; else col="${ESC}[48;5;${trackbg};38;5;${emptyfg}m"; fi
    (( prev >= bs && prev < be )) && bold="${ESC}[1m" || bold=""
    bar_color+="${col}${bold}${seg}${RESET}"
    prev=$b
  done
else
  bar_plain=""
  bar_color=""
fi

# --- assemble RIGHT (model · bar · clock · session-total), skipping empties ---
right_plain=""; right_color=""
rt_add() {
  [[ -z "$1" ]] && return
  local sep="${3:- }"
  [[ -n "$right_plain" ]] && { right_plain+="$sep"; right_color+="$sep"; }
  right_plain+="$1"; right_color+="$2"
}
rt_add "$model_txt" "${BRANCHFG}${model_txt}${RESET}"
rt_add "$bar_plain" "$bar_color"
rt_add "$clock_plain" "$clock_color"
rt_add "$costfmt" "${BRANCHFG}${costfmt}${RESET}" "$DOT"

# --- size the session name: full when it fits, else shrink to keep MIN_GAP ---
target=$(( width - EDGE_MARGIN ))
dev_w=0; (( dev_running )) && dev_w=2          # "● "
chip_w=$(( 2 + ${#dir} ))                      # " dir "
branch_w=0; [[ -n "$branch_txt" ]] && branch_w=$(( 1 + ${#branch_txt} ))
name_block_max=$(( target - dev_w - chip_w - branch_w - ${#right_plain} - MIN_GAP ))

name_txt=""
if [[ -n "$name_full" ]]; then
  if (( name_block_max >= 2 + ${#name_full} )); then
    name_txt="$name_full"                      # fits in full
  else
    namelen_max=$(( name_block_max - 2 ))       # minus the chip's two pad spaces
    if (( namelen_max >= 2 )); then
      name_txt="${name_full:0:namelen_max-1}…"
    elif (( namelen_max == 1 )); then
      name_txt="…"
    fi
  fi
fi

# --- assemble LEFT (plain for width, colored for output) ---
left_plain=""; left_color=""
if (( dev_running )); then
  left_plain+="${DEV_GLYPH} "
  left_color+="${DEV_COLOR}${DEV_GLYPH}${RESET} "
fi
left_plain+=" ${dir} "
if [[ "$tenant_num" =~ ^[0-9]+$ ]]; then
  dir_disp="${ESC}[1m${dir}${ESC}[22m"
else
  dir_disp="$dir"
fi
left_color+="${DIRCHIP} ${dir_disp} ${RESET}"
if [[ -n "$name_txt" ]]; then
  left_plain+=" ${name_txt} "
  left_color+="${NAMECHIP} ${name_txt} ${RESET}"
fi
if [[ -n "$branch_txt" ]]; then
  left_plain+=" ${branch_txt}"
  left_color+=" ${BRANCHFG}${branch_txt}${RESET}"
fi

# --- pad so RIGHT sits just inside the terminal edge ---
gap=$(( width - EDGE_MARGIN - ${#left_plain} - ${#right_plain} ))
(( gap < 1 )) && gap=1
printf '%s%*s%s' "$left_color" "$gap" '' "$right_color"
