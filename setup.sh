#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  WordPress Block Theme — Project Setup                               ║
# ║  Run this once after copying the boilerplate into wp-content/ to     ║
# ║  configure your new project. It renames slugs, text domains and      ║
# ║  prefixes, writes design tokens, and scaffolds optional components.  ║
# ╚══════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./setup.sh              Interactive setup
#   ./setup.sh --dry-run    Show what would change without writing anything
#   ./setup.sh --help       Usage plus a troubleshooting guide
#
# At any prompt, type "b" (or "back") to return to the previous question.
#
# Environment overrides:
#   SETUP_ALLOW_NONINTERACTIVE=1   Skip the "stdin is a terminal" guard
#   NO_COLOR=1                     Disable ANSI colors
#

set -uo pipefail
set -E    # propagate the ERR trap into functions and subshells

# ══════════════════════════════════════════════════════════════════════════
#  Terminal capabilities, colors, symbols
# ══════════════════════════════════════════════════════════════════════════

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
	IS_TTY=true
	BOLD=$'\033[1m'; DIM=$'\033[2m'
	GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; YELLOW=$'\033[0;33m'
	RED=$'\033[0;31m'; BLUE=$'\033[0;34m'; MAGENTA=$'\033[0;35m'
	RESET=$'\033[0m'
	HIDE_CURSOR=$'\033[?25l'; SHOW_CURSOR=$'\033[?25h'
	CLEAR_LINE=$'\033[2K'
else
	IS_TTY=false
	BOLD=''; DIM=''; GREEN=''; CYAN=''; YELLOW=''
	RED=''; BLUE=''; MAGENTA=''; RESET=''
	HIDE_CURSOR=''; SHOW_CURSOR=''; CLEAR_LINE=''
fi

CHECK="${GREEN}✓${RESET}"
ARROW="${CYAN}❯${RESET}"
WARN_SYM="${YELLOW}!${RESET}"
CROSS="${RED}✗${RESET}"
SKIP_SYM="${DIM}·${RESET}"

TERM_WIDTH=80
detect_width() {
	local w
	w=$(tput cols 2>/dev/null || echo 80)
	[[ "$w" =~ ^[0-9]+$ ]] || w=80
	if (( w < 64 )); then w=64; fi
	if (( w > 110 )); then w=110; fi
	TERM_WIDTH=$w
}
detect_width

# ══════════════════════════════════════════════════════════════════════════
#  Output helpers
# ══════════════════════════════════════════════════════════════════════════

print_header() {
	echo ""
	printf '%s\n' "${BOLD}${CYAN}  ┌─────────────────────────────────────────────┐${RESET}"
	printf '%s\n' "${BOLD}${CYAN}  │   WordPress Block Theme Setup                │${RESET}"
	printf '%s\n' "${BOLD}${CYAN}  │   Configure your new project                 │${RESET}"
	printf '%s\n' "${BOLD}${CYAN}  └─────────────────────────────────────────────┘${RESET}"
	echo ""
}

print_section() {
	# Built with a loop, not `printf … | tr ' ' '─'`: tr works on bytes and
	# ─ is three bytes in UTF-8, which produces mojibake.
	local line='' i
	for (( i = 0; i < ${#1}; i++ )); do line+='─'; done
	echo ""
	printf '  %s%s%s%s\n' "$BOLD" "$BLUE" "$1" "$RESET"
	printf '  %s%s%s\n' "$DIM" "$line" "$RESET"
	echo ""
}

print_warn()  { printf '  %s  %s%s%s\n' "$WARN_SYM" "$YELLOW" "$1" "$RESET"; }
print_error() { printf '  %s  %s%s%s\n' "$CROSS" "$RED" "$1" "$RESET" >&2; }
print_info()  { printf '  %s%s%s\n' "$DIM" "$1" "$RESET"; }
print_ok()    { printf '  %s  %s\n' "$CHECK" "$1"; }

# ══════════════════════════════════════════════════════════════════════════
#  Failure handling
# ══════════════════════════════════════════════════════════════════════════
#
# FAIL_CONTEXT and FAIL_HINT are set immediately before each risky operation.
# If the script dies anywhere, the ERR trap prints what was being attempted
# plus a targeted remediation, rather than a bare exit code on a stray line.
#
# There is deliberately no `set -e`: the ERR trap already gives us
# fail-fast behaviour, and it can report *why* before exiting.

FAIL_CONTEXT="starting up"
FAIL_HINT=""
MUTATED=false                # true once anything on disk has changed
ROLLBACK_THEME_RENAME=""     # "old|new" once the theme dir has been renamed
SPINNER_PID=""

set_context() {
	FAIL_CONTEXT="$1"
	FAIL_HINT="${2:-}"
}

stop_spinner() {
	if [[ -n "$SPINNER_PID" ]]; then
		kill "$SPINNER_PID" 2>/dev/null || true
		wait "$SPINNER_PID" 2>/dev/null || true
		SPINNER_PID=""
	fi
	return 0
}

cleanup_terminal() {
	stop_spinner
	if $IS_TTY; then printf '%s' "$SHOW_CURSOR"; fi
	return 0
}

on_error() {
	local code=$1 line=$2 cmd=${3:-}
	trap - ERR
	cleanup_terminal
	echo ""
	echo ""
	printf '  %s%s━━━ Setup failed ━━━%s\n' "$BOLD" "$RED" "$RESET"
	echo ""
	printf '  %sWhile:%s   %s\n' "$BOLD" "$RESET" "$FAIL_CONTEXT"
	printf '  %sCommand:%s %s%s%s\n' "$BOLD" "$RESET" "$DIM" "${cmd:0:110}" "$RESET"
	printf '  %sExit:%s    %s  %s(setup.sh line %s)%s\n' "$BOLD" "$RESET" "$code" "$DIM" "$line" "$RESET"
	echo ""

	if [[ -n "$FAIL_HINT" ]]; then
		printf '  %s%sHow to fix:%s\n' "$BOLD" "$YELLOW" "$RESET"
		printf '%s\n' "$FAIL_HINT" | while IFS= read -r l; do
			printf '    %s\n' "$l"
		done
		echo ""
	fi

	if $MUTATED; then
		print_warn "Files were already modified before the failure."
		echo ""
		print_info "To get back to a clean slate:"
		if [[ -n "$ROLLBACK_THEME_RENAME" ]]; then
			print_info "  mv \"${ROLLBACK_THEME_RENAME##*|}\" \"${ROLLBACK_THEME_RENAME%%|*}\"   # undo the theme rename"
		fi
		print_info "  Then re-copy the pristine boilerplate and run ./setup.sh again."
		echo ""
	else
		print_info "Nothing was written to disk."
		echo ""
	fi

	print_info "More troubleshooting: ./setup.sh --help"
	echo ""
	exit "$code"
}

on_interrupt() {
	trap - ERR INT TERM
	cleanup_terminal
	echo ""
	echo ""
	print_warn "Setup interrupted."
	if $MUTATED; then
		print_info "Some files were already changed. Re-copy the boilerplate before retrying."
	else
		print_info "No files were changed."
	fi
	echo ""
	exit 130
}

trap 'on_error $? $LINENO "$BASH_COMMAND"' ERR
trap on_interrupt INT TERM
trap cleanup_terminal EXIT

# ══════════════════════════════════════════════════════════════════════════
#  Progress reporting
# ══════════════════════════════════════════════════════════════════════════
#
# Two mechanisms, both driven by real work rather than decoration:
#
#   1. A step counter — [ 4/11] — whose total is computed from the answers
#      you gave, so it describes the run you actually asked for.
#   2. A per-step bar fed by real counts: files rewritten, scaffold files
#      written, build phases finished. Where a duration genuinely cannot be
#      measured (npm reaching out to the registry) the bar is replaced by a
#      live elapsed-seconds counter, so a stalled step is obvious instead of
#      being disguised as a smooth animation.

TOTAL_STEPS=0
STEP_NUM=0
STEP_LABEL=""
STEP_START_MS=0

now_ms() {
	if [[ -n "${EPOCHREALTIME:-}" ]]; then
		local t="${EPOCHREALTIME/,/.}"
		echo $(( ${t%%.*} * 1000 + 10#${t##*.} / 1000 ))
	else
		echo $(( $(date +%s) * 1000 ))
	fi
}

fmt_elapsed() {
	local ms=$1
	if (( ms < 1000 )); then
		printf '%dms' "$ms"
	else
		printf '%d.%01ds' $(( ms / 1000 )) $(( (ms % 1000) / 100 ))
	fi
}

# Truncate/pad a label to a fixed width so the bar never wraps.
_label_field() {
	local w=$(( TERM_WIDTH - 34 ))
	if (( w < 16 )); then w=16; fi
	printf '%-*.*s' "$w" "$w" "$1"
}

step_start() {
	STEP_NUM=$(( STEP_NUM + 1 ))
	STEP_LABEL="$1"
	STEP_START_MS=$(now_ms)
	set_context "$1"
	if $IS_TTY; then
		printf '%s' "$HIDE_CURSOR"
		step_render 0 0 ""
	else
		printf '  [%2d/%2d] %s …\n' "$STEP_NUM" "$TOTAL_STEPS" "$STEP_LABEL"
	fi
	return 0
}

step_render() {
	if ! $IS_TTY; then return 0; fi
	local done=$1 total=$2 suffix=${3:-}
	local width=14 pct=0 filled=0 bar='' i
	if (( total > 0 )); then
		pct=$(( done * 100 / total ))
		filled=$(( width * done / total ))
	fi
	for (( i = 0; i < width; i++ )); do
		if (( i < filled )); then bar+='█'; else bar+='░'; fi
	done
	printf '\r%s  [%2d/%2d] %s%s%s %3d%%  %s %s%s%s' \
		"$CLEAR_LINE" "$STEP_NUM" "$TOTAL_STEPS" \
		"$CYAN" "$bar" "$RESET" "$pct" \
		"$(_label_field "$STEP_LABEL")" "$DIM" "$suffix" "$RESET"
	return 0
}

step_progress() { step_render "$1" "$2" "${3:-}"; }

step_ok() {
	local detail=${1:-} elapsed
	elapsed=$(fmt_elapsed $(( $(now_ms) - STEP_START_MS )))
	if $IS_TTY; then
		printf '\r%s  %s  %s %s%s%s\n' \
			"$CLEAR_LINE" "$CHECK" "$(_label_field "$STEP_LABEL")" \
			"$DIM" "${detail:+$detail · }$elapsed" "$RESET"
		printf '%s' "$SHOW_CURSOR"
	else
		printf '  [%2d/%2d] done — %s (%s)\n' "$STEP_NUM" "$TOTAL_STEPS" "${detail:-ok}" "$elapsed"
	fi
	return 0
}

step_skip() {
	if $IS_TTY; then
		printf '\r%s  %s  %s%s%s %s(%s)%s\n' \
			"$CLEAR_LINE" "$SKIP_SYM" "$DIM" "$(_label_field "$STEP_LABEL")" "$RESET" \
			"$DIM" "$1" "$RESET"
		printf '%s' "$SHOW_CURSOR"
	else
		printf '  [%2d/%2d] skipped — %s\n' "$STEP_NUM" "$TOTAL_STEPS" "$1"
	fi
	return 0
}

step_warn() {
	if $IS_TTY; then
		printf '\r%s  %s  %s %s%s%s\n' \
			"$CLEAR_LINE" "$WARN_SYM" "$(_label_field "$STEP_LABEL")" \
			"$YELLOW" "$1" "$RESET"
		printf '%s' "$SHOW_CURSOR"
	else
		printf '  [%2d/%2d] warning — %s\n' "$STEP_NUM" "$TOTAL_STEPS" "$1"
	fi
	return 0
}

# Live elapsed-seconds indicator for work whose duration we cannot know.
start_spinner() {
	local note=${1:-}
	if ! $IS_TTY; then return 0; fi
	local num="$STEP_NUM" tot="$TOTAL_STEPS" label="$STEP_LABEL"
	local field
	field=$(_label_field "$label")
	(
		trap 'exit 0' TERM INT
		local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
		local start=$SECONDS i=0
		while true; do
			printf '\r%s  [%2d/%2d] %s%s%s      %s %s(%ds%s)%s' \
				"$CLEAR_LINE" "$num" "$tot" \
				"$CYAN" "${frames:i%10:1}" "$RESET" \
				"$field" "$DIM" "$(( SECONDS - start ))" "${note:+ · $note}" "$RESET"
			i=$(( i + 1 ))
			sleep 0.12
		done
	) &
	SPINNER_PID=$!
	return 0
}

# ══════════════════════════════════════════════════════════════════════════
#  String helpers
# ══════════════════════════════════════════════════════════════════════════

slugify()   { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'; }
prefixify() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g'; }
upper()     { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

# Title Case With The Spaces Kept.
#
# The previous implementation used `s/(^| )(\w)/\U\2/g`, which discarded
# capture group 1 — the space — from the replacement. That is exactly what
# turned "My Client Site" into "MyClientSite" in the style.css theme header.
titlecase() {
	printf '%s' "$1" | sed -E 's/[-_]+/ /g; s/(^|[[:space:]])([[:alnum:]])/\1\u\2/g'
}

# ── sed escaping ─────────────────────────────────────────────────────────
#
# Substitutions use \001 as the s/// delimiter rather than / or |. User
# input (theme name, author, description) can legitimately contain both of
# those, and escaping | inside a BRE pattern turns it into GNU sed's
# alternation operator — a subtle way to corrupt files. \001 cannot appear
# in anything typed at a prompt.

SD=$'\001'

esc_pat() { printf '%s' "$1" | sed -e 's/[][\.*^$]/\\&/g'; }
esc_rep() { printf '%s' "$1" | sed -e 's/[\\&]/\\&/g'; }

# ══════════════════════════════════════════════════════════════════════════
#  sed portability
# ══════════════════════════════════════════════════════════════════════════
#
# GNU sed wants `sed -i`; BSD/macOS sed wants `sed -i ''`. Ask sed itself
# rather than sniffing uname, which is wrong on any machine with GNU
# coreutils installed over a BSD userland.

SED_INPLACE=()
detect_sed() {
	if sed --version >/dev/null 2>&1; then
		SED_INPLACE=(sed -i)
	else
		SED_INPLACE=(sed -i '')
	fi
	return 0
}

do_sed() { "${SED_INPLACE[@]}" "$@"; }

# ══════════════════════════════════════════════════════════════════════════
#  Prompts, with go-back support
# ══════════════════════════════════════════════════════════════════════════

readonly BACK_RC=10

is_back() {
	local v
	v=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	[[ "$v" == "b" || "$v" == "back" || "$v" == ":b" ]]
}

read_line() {
	local __var="$1" __result
	if ! IFS= read -r __result; then
		echo ""
		print_error "Input stream closed unexpectedly (EOF on stdin)."
		print_info "setup.sh needs an interactive terminal. Run it directly:"
		print_info "  cd wp-content && ./setup.sh"
		exit 1
	fi
	printf -v "$__var" '%s' "$__result"
	return 0
}

# prompt <label> <default> <var> [validator] [hint]
prompt() {
	local label="$1" default="$2" var_name="$3"
	local validator="${4:-}" hint="${5:-}"
	local result
	while true; do
		if [[ -n "$default" ]]; then
			printf '  %s %s%s%s %s(%s)%s: ' "$ARROW" "$BOLD" "$label" "$RESET" "$DIM" "$default" "$RESET"
		else
			printf '  %s %s%s%s: ' "$ARROW" "$BOLD" "$label" "$RESET"
		fi
		read_line result
		if is_back "$result"; then return $BACK_RC; fi
		result="${result:-$default}"
		if [[ -n "$validator" ]] && ! "$validator" "$result"; then
			print_warn "${hint:-That value is not valid.}"
			continue
		fi
		printf -v "$var_name" '%s' "$result"
		return 0
	done
}

# prompt_yn <label> <default: y|n> <var>
prompt_yn() {
	local label="$1" default="$2" var_name="$3" hint result
	if [[ "$default" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
	while true; do
		printf '  %s %s%s%s %s[%s]%s: ' "$ARROW" "$BOLD" "$label" "$RESET" "$DIM" "$hint" "$RESET"
		read_line result
		if is_back "$result"; then return $BACK_RC; fi
		result="${result:-$default}"
		result=$(printf '%s' "$result" | tr '[:upper:]' '[:lower:]')
		case "$result" in
			y|yes) printf -v "$var_name" '%s' "true";  return 0 ;;
			n|no)  printf -v "$var_name" '%s' "false"; return 0 ;;
			*)     print_warn "Please answer y or n (or 'b' to go back)." ;;
		esac
	done
}

# prompt_select <label> <var> <option>...
#
# Numbered list. The stored value is the option string itself, so re-showing
# the prompt after a "back" defaults to whatever was chosen last time.
prompt_select() {
	local label="$1" var_name="$2"
	shift 2
	local options=( "$@" )
	local current="${!var_name:-}"
	local default_idx=1 i choice

	for i in "${!options[@]}"; do
		if [[ "${options[$i]}" == "$current" ]]; then
			default_idx=$(( i + 1 ))
		fi
	done

	while true; do
		printf '  %s %s%s%s\n' "$ARROW" "$BOLD" "$label" "$RESET"
		for i in "${!options[@]}"; do
			if (( i + 1 == default_idx )); then
				printf '    %s>%s %s%d%s  %s %s(current)%s\n' \
					"$GREEN" "$RESET" "$BOLD" "$(( i + 1 ))" "$RESET" "${options[$i]}" "$DIM" "$RESET"
			else
				printf '      %s%d%s  %s\n' "$BOLD" "$(( i + 1 ))" "$RESET" "${options[$i]}"
			fi
		done
		printf '    %sNumber:%s ' "$DIM" "$RESET"
		read_line choice
		if is_back "$choice"; then return $BACK_RC; fi
		choice="${choice:-$default_idx}"
		if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
			printf -v "$var_name" '%s' "${options[$(( choice - 1 ))]}"
			return 0
		fi
		print_warn "Enter a number between 1 and ${#options[@]} (or 'b' to go back)."
	done
}

# Turn a stored true/false back into the y/n default for a re-shown prompt.
yn_default() {
	case "${1:-}" in
		true)  printf 'y' ;;
		false) printf 'n' ;;
		*)     printf '%s' "${2:-y}" ;;
	esac
}

# ══════════════════════════════════════════════════════════════════════════
#  Validators
# ══════════════════════════════════════════════════════════════════════════

v_nonempty() { [[ -n "${1// /}" ]]; }
v_slug()     { [[ "$1" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; }
v_port()     { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1024 && $1 <= 65535 )); }
v_px()       { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 320 && $1 <= 3840 )); }
v_hex_opt()  { [[ -z "$1" ]] || [[ "$1" =~ ^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$ ]]; }
v_url()      { [[ "$1" =~ ^https?://[^[:space:]]+$ ]]; }
v_uri_opt()  { [[ -z "$1" ]] || [[ "$1" =~ ^https?://[^[:space:]]+$ ]]; }

normalize_hex() {
	local h="$1"
	if [[ -z "$h" ]]; then printf ''; return 0; fi
	if [[ "$h" != \#* ]]; then h="#${h}"; fi
	if (( ${#h} == 4 )); then
		h="#${h:1:1}${h:1:1}${h:2:1}${h:2:1}${h:3:1}${h:3:1}"
	fi
	printf '%s' "$h" | tr '[:upper:]' '[:lower:]'
}

# ══════════════════════════════════════════════════════════════════════════
#  --help
# ══════════════════════════════════════════════════════════════════════════

show_help() {
	cat <<'HELPEOF'

  WordPress Block Theme — Project Setup

  USAGE
    ./setup.sh                Interactive setup
    ./setup.sh --dry-run      Report what would change; write nothing
    ./setup.sh --help         This message

  NAVIGATION
    Type "b" (or "back") at any prompt to return to the previous question.
    Ctrl-C aborts. Nothing is written to disk until you confirm at the
    review screen, so backing out early is always safe.

  ENVIRONMENT
    SETUP_ALLOW_NONINTERACTIVE=1   Skip the interactive-terminal guard
    NO_COLOR=1                     Disable ANSI colors

  TROUBLESHOOTING

    bad interpreter: /usr/bin/env bash^M
        The file has Windows (CRLF) line endings, which is common when the
        boilerplate is synced through Dropbox or OneDrive. Fix:
          sed -i 's/\r$//' setup.sh
        The included .gitattributes prevents this recurring under git.

    Permission denied running ./setup.sh
          chmod +x setup.sh

    The script seems to hang with no output
        Almost always npm reaching the registry on a slow link. This version
        shows a live elapsed-seconds counter during npm install so a real
        hang is distinguishable from slow progress. If it is genuinely
        stuck: Ctrl-C, then run `npm install` alone to see the error.
        Older versions could also stall for minutes scanning a pre-existing
        node_modules/ during find-and-replace; that directory is now pruned
        from every scan.

    This script must be run from the wp-content directory
        cd into the folder containing CLAUDE.md and themes/starter, then run
        ./setup.sh from there.

    themes/<slug> already exists
        A theme with that slug is already installed. Pick another slug or
        remove the existing directory.

    themes/starter not found
        Setup has already run in this folder. Copy the pristine boilerplate
        into a fresh wp-content/ and run setup.sh there.

    npm install fails with EACCES or EPERM
        Do not run setup.sh with sudo. Fix npm cache ownership instead:
          sudo chown -R "$(id -u):$(id -g)" ~/.npm

    npm install fails behind a corporate proxy
          npm config set proxy http://your-proxy:port
          npm config set https-proxy http://your-proxy:port

    npm install fails with EBADENGINE
        The build requires Node 20+.  nvm install 20 && nvm use 20

    git commit fails during setup
        No git identity configured:
          git config --global user.name  "Your Name"
          git config --global user.email "you@example.com"

    npm run dev starts but never reloads on save
        On WSL2 with the project on the Windows partition (/mnt/c/), file
        watching needs polling — already configured. If it is still silent,
        check LOCAL_URL in build/dev-server.mjs matches your Local by
        Flywheel site exactly, http vs https included.

HELPEOF
	return 0
}

# ══════════════════════════════════════════════════════════════════════════
#  Arguments
# ══════════════════════════════════════════════════════════════════════════

DRY_RUN=false
for arg in "$@"; do
	case "$arg" in
		--help|-h) show_help; exit 0 ;;
		--dry-run) DRY_RUN=true ;;
		*)
			print_error "Unknown option: $arg"
			print_info "Run ./setup.sh --help for usage."
			exit 2
			;;
	esac
done

# ══════════════════════════════════════════════════════════════════════════
#  Preflight
# ══════════════════════════════════════════════════════════════════════════
#
# Everything checkable before touching the disk is checked here, so a
# misconfigured machine fails in the first two seconds with an actionable
# message instead of halfway through a directory rename.

PREFLIGHT_WARNINGS=()
HAVE_NODE=false
HAVE_NPM=false
HAVE_GIT=false

preflight_fail() {
	local msg="$1"; shift
	trap - ERR
	echo ""
	print_error "$msg"
	echo ""
	local l
	for l in "$@"; do print_info "  $l"; done
	echo ""
	exit 1
}

preflight() {
	set_context "running preflight checks"

	# ── Bash version ──────────────────────────────────────────────────
	if (( BASH_VERSINFO[0] < 4 )); then
		preflight_fail \
			"Bash 4.0 or newer is required (found ${BASH_VERSION})." \
			"macOS ships bash 3.2 for licensing reasons. Install a current bash:" \
			"  brew install bash" \
			"then run:  /opt/homebrew/bin/bash ./setup.sh" \
			"On WSL or Ubuntu this should not happen — check you are not running" \
			"the script with 'sh setup.sh', which invokes dash, not bash."
	fi

	# ── Interactive stdin ─────────────────────────────────────────────
	if [[ ! -t 0 ]] && [[ -z "${SETUP_ALLOW_NONINTERACTIVE:-}" ]]; then
		preflight_fail \
			"setup.sh needs an interactive terminal, but stdin is not a TTY." \
			"This happens when the script is piped, redirected, or launched by a" \
			"task runner — the prompts would block forever waiting for input." \
			"Run it directly in a terminal:" \
			"  cd wp-content && ./setup.sh" \
			"To bypass this guard for scripted runs: SETUP_ALLOW_NONINTERACTIVE=1"
	fi

	# ── Correct working directory ─────────────────────────────────────
	if [[ ! -f "CLAUDE.md" ]] || [[ ! -d "themes" ]]; then
		preflight_fail \
			"This script must be run from the wp-content directory of the boilerplate." \
			"Expected CLAUDE.md and themes/ in:" \
			"  $(pwd)" \
			"cd into the boilerplate root and try again."
	fi

	if [[ ! -d "themes/starter" ]]; then
		local existing
		existing=$(find themes -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sed 's|themes/||' | tr '\n' ' ')
		preflight_fail \
			"themes/starter/ not found — setup has probably already run in this folder." \
			"Themes present: ${existing:-none}" \
			"To configure a new project, copy the pristine boilerplate into a fresh" \
			"wp-content/ and run setup.sh there."
	fi

	# ── Writable working directory ────────────────────────────────────
	local probe=".setup-write-probe.$$"
	if ! touch "$probe" 2>/dev/null; then
		preflight_fail \
			"Cannot write to $(pwd)." \
			"The filesystem is read-only, or you do not have permission." \
			"On WSL, check the Windows folder is not marked read-only and that the" \
			"path is not owned by another user."
	fi
	rm -f "$probe"

	# ── Required commands ─────────────────────────────────────────────
	local missing=() cmd
	for cmd in sed find grep tr awk mv mkdir cat; do
		if ! command -v "$cmd" >/dev/null 2>&1; then missing+=("$cmd"); fi
	done
	if (( ${#missing[@]} > 0 )); then
		preflight_fail \
			"Missing required commands: ${missing[*]}" \
			"Install core utilities for your distribution, e.g.:" \
			"  sudo apt-get install -y coreutils findutils sed grep gawk"
	fi

	detect_sed

	# ── CRLF contamination ────────────────────────────────────────────
	if grep -rlq $'\r' --include='*.sh' --include='*.mjs' --include='*.json' . 2>/dev/null; then
		PREFLIGHT_WARNINGS+=("Some files have Windows (CRLF) line endings. If the build misbehaves: find . -name '*.mjs' -o -name '*.sh' | xargs sed -i 's/\\r\$//'")
	fi

	# ── Pre-existing node_modules ─────────────────────────────────────
	if [[ -d "node_modules" ]]; then
		PREFLIGHT_WARNINGS+=("node_modules/ already exists — it is pruned from every find-and-replace scan.")
	fi

	# ── Node / npm ────────────────────────────────────────────────────
	if command -v node >/dev/null 2>&1; then
		HAVE_NODE=true
		local nodemajor
		nodemajor=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
		if [[ "$nodemajor" =~ ^[0-9]+$ ]] && (( nodemajor < 20 )); then
			PREFLIGHT_WARNINGS+=("Node $(node -v) is older than the required v20. Run 'nvm install 20 && nvm use 20' before building.")
		fi
	else
		PREFLIGHT_WARNINGS+=("node not found — dependency install and first build will be skipped. Install Node 20+, then run 'npm install'.")
	fi
	if command -v npm >/dev/null 2>&1; then HAVE_NPM=true; fi

	# ── Git ───────────────────────────────────────────────────────────
	if command -v git >/dev/null 2>&1; then
		HAVE_GIT=true
		if ! git config user.email >/dev/null 2>&1 && ! git config --global user.email >/dev/null 2>&1; then
			PREFLIGHT_WARNINGS+=("No git identity configured. Set user.name and user.email or the initial commit will fail.")
		fi
	else
		PREFLIGHT_WARNINGS+=("git not found — repository initialization will be skipped.")
	fi

	# ── Disk space ────────────────────────────────────────────────────
	if command -v df >/dev/null 2>&1; then
		local avail_kb
		avail_kb=$(df -Pk . 2>/dev/null | awk 'NR==2 {print $4}')
		if [[ "$avail_kb" =~ ^[0-9]+$ ]] && (( avail_kb < 500000 )); then
			PREFLIGHT_WARNINGS+=("Under 500 MB free on this volume; npm install needs roughly 300 MB.")
		fi
	fi
	return 0
}

preflight
print_header

if (( ${#PREFLIGHT_WARNINGS[@]} > 0 )); then
	print_section "Preflight notes"
	for w in "${PREFLIGHT_WARNINGS[@]}"; do print_warn "$w"; done
	echo ""
fi

if $DRY_RUN; then
	print_warn "DRY RUN — nothing will be written."
fi
print_info "Type 'b' at any prompt to go back to the previous question."

# ══════════════════════════════════════════════════════════════════════════
#  Configuration — step machine with go-back
# ══════════════════════════════════════════════════════════════════════════
#
# Each question is a step function returning 0 to advance or BACK_RC to
# retreat. Answers live in globals, so moving backward and forward again
# preserves everything already typed.

PROJECT_NAME=""; THEME_NAME=""; THEME_SLUG=""; TEXT_DOMAIN=""; FUNC_PREFIX=""
THEME_DESCRIPTION=""; AUTHOR_NAME=""; AUTHOR_URI=""
LOCAL_URL=""; BROWSERSYNC_PORT=""
USE_ACF=""; CREATE_PLUGIN=""; PLUGIN_SLUG=""; INIT_GIT=""
DATA_STRATEGY=""; SCAFFOLD_BINDINGS=""; SCAFFOLD_ABILITY=""
PRIMARY_COLOR=""; SECONDARY_COLOR=""; TERTIARY_COLOR=""; DERIVE_SHADES=""
CONTENT_WIDTH=""; WIDE_WIDTH=""
INSTALL_DEPS=""; REMOVE_SCRIPT=""

_LAST_PROJECT_NAME=""

step_project_name() {
	print_section "Project Identity"
	prompt "Project name" "${PROJECT_NAME:-My Client Site}" PROJECT_NAME \
		v_nonempty "Project name cannot be empty." || return $?

	# If the project name changed, clear the values derived from it so their
	# defaults regenerate. Without this, going back to rename the project
	# would silently keep the old slug and prefix.
	if [[ "$PROJECT_NAME" != "$_LAST_PROJECT_NAME" ]]; then
		THEME_NAME=""; THEME_SLUG=""; TEXT_DOMAIN=""; FUNC_PREFIX=""; LOCAL_URL=""
		_LAST_PROJECT_NAME="$PROJECT_NAME"
	fi
	return 0
}

step_theme_name() {
	print_info "Shown in WordPress under Appearance → Themes. Spaces and capitals are kept exactly as typed."
	prompt "Theme display name" "${THEME_NAME:-$PROJECT_NAME}" THEME_NAME \
		v_nonempty "Theme name cannot be empty." || return $?
	return 0
}

step_theme_slug() {
	local default="${THEME_SLUG:-$(slugify "$PROJECT_NAME")}"
	prompt "Theme slug (directory name)" "$default" THEME_SLUG v_slug \
		"Lowercase letters, numbers and hyphens only, e.g. acme-clinic." || return $?

	if [[ -d "themes/${THEME_SLUG}" && "$THEME_SLUG" != "starter" ]]; then
		print_warn "themes/${THEME_SLUG}/ already exists. Pick another slug or remove that directory."
		THEME_SLUG=""
		return $BACK_RC
	fi
	case "$THEME_SLUG" in
		twentytwenty*|index|assets|node_modules|plugins|themes)
			print_warn "'${THEME_SLUG}' collides with a reserved or default WordPress name."
			THEME_SLUG=""
			return $BACK_RC
			;;
	esac
	return 0
}

step_text_domain() {
	prompt "Text domain" "${TEXT_DOMAIN:-$THEME_SLUG}" TEXT_DOMAIN v_slug \
		"Lowercase letters, numbers and hyphens only." || return $?
	return 0
}

step_func_prefix() {
	local default="${FUNC_PREFIX:-$(prefixify "$PROJECT_NAME")_}"
	prompt "PHP function prefix" "$default" FUNC_PREFIX || return $?
	# Normalize to a valid PHP identifier prefix ending in one underscore.
	FUNC_PREFIX=$(printf '%s' "$FUNC_PREFIX" | sed -E 's/[^a-zA-Z0-9_]/_/g; s/_+/_/g; s/^_+|_+$//g')
	if [[ -z "$FUNC_PREFIX" ]]; then FUNC_PREFIX="theme"; fi
	if [[ "$FUNC_PREFIX" =~ ^[0-9] ]]; then FUNC_PREFIX="t${FUNC_PREFIX}"; fi
	FUNC_PREFIX="${FUNC_PREFIX}_"
	return 0
}

step_description() {
	prompt "Theme description" "${THEME_DESCRIPTION:-A custom WordPress block theme.}" THEME_DESCRIPTION || return $?
	return 0
}

step_author() {
	print_section "Author"
	prompt "Author name" "${AUTHOR_NAME:-}" AUTHOR_NAME || return $?
	prompt "Author URI" "${AUTHOR_URI:-}" AUTHOR_URI v_uri_opt \
		"Leave blank, or enter a full URL starting with http:// or https://." || return $?
	return 0
}

step_local_url() {
	print_section "Local Development"
	prompt "Local site URL (Local by Flywheel)" "${LOCAL_URL:-http://${THEME_SLUG}.local}" LOCAL_URL v_url \
		"Include the scheme, e.g. http://acme-clinic.local" || return $?
	return 0
}

step_port() {
	prompt "BrowserSync port" "${BROWSERSYNC_PORT:-3000}" BROWSERSYNC_PORT v_port \
		"A number between 1024 and 65535." || return $?

	# Best-effort in-use check. Not fatal — the port may free up before you
	# run `npm run dev` — but better flagged now than at first launch.
	if command -v ss >/dev/null 2>&1; then
		if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${BROWSERSYNC_PORT}\$"; then
			print_warn "Port ${BROWSERSYNC_PORT} looks like it is already in use."
		fi
	elif command -v lsof >/dev/null 2>&1; then
		if lsof -iTCP:"${BROWSERSYNC_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
			print_warn "Port ${BROWSERSYNC_PORT} looks like it is already in use."
		fi
	fi
	return 0
}

step_acf() {
	print_section "Features"
	prompt_yn "Will this project use ACF PRO?" "$(yn_default "$USE_ACF" y)" USE_ACF || return $?
	return 0
}

step_plugin() {
	prompt_yn "Create a companion plugin?" "$(yn_default "$CREATE_PLUGIN" n)" CREATE_PLUGIN || return $?
	if [[ "$CREATE_PLUGIN" == "true" ]]; then
		prompt "Plugin slug" "${PLUGIN_SLUG:-${THEME_SLUG}-plugin}" PLUGIN_SLUG v_slug \
			"Lowercase letters, numbers and hyphens only." || return $?
		if [[ -d "plugins/${PLUGIN_SLUG}" ]]; then
			print_warn "plugins/${PLUGIN_SLUG}/ already exists. Pick another slug."
			PLUGIN_SLUG=""
			return $BACK_RC
		fi
	else
		PLUGIN_SLUG=""
	fi
	return 0
}

step_data_strategy() {
	print_section "Dynamic Content"
	print_info "WordPress 7.0 can pull custom field values straight into core blocks"
	print_info "through Block Bindings, which removes much of the historic reason to"
	print_info "build a custom ACF block. This choice is written into CLAUDE.md so"
	print_info "Claude reaches for the right tool first. It changes documentation and"
	print_info "scaffolding only — nothing is locked in."
	echo ""
	prompt_select "How should dynamic content be built by default?" DATA_STRATEGY \
		"Bindings first — core blocks + Block Bindings, custom blocks only when needed" \
		"ACF blocks first — reach for a custom ACF block by default" \
		"Decide per component — document both, no default" || return $?
	return 0
}

step_scaffold() {
	if [[ "$CREATE_PLUGIN" != "true" ]]; then
		SCAFFOLD_BINDINGS="false"
		SCAFFOLD_ABILITY="false"
		return 0
	fi

	print_section "Plugin Scaffolding"
	print_info "Optional starting points in the companion plugin. Both are working"
	print_info "code with the registration wired up, not empty files."
	echo ""
	prompt_yn "Add a Block Bindings source (reads an ACF field into core blocks)?" \
		"$(yn_default "$SCAFFOLD_BINDINGS" y)" SCAFFOLD_BINDINGS || return $?
	prompt_yn "Add a WordPress Abilities API stub (7.0 AI/agent integration)?" \
		"$(yn_default "$SCAFFOLD_ABILITY" n)" SCAFFOLD_ABILITY || return $?
	return 0
}

step_git() {
	prompt_yn "Initialize a git repository?" "$(yn_default "$INIT_GIT" y)" INIT_GIT || return $?
	if [[ "$INIT_GIT" == "true" ]] && ! $HAVE_GIT; then
		print_warn "git is not installed, so this step will be skipped."
	fi
	return 0
}

step_colors() {
	print_section "Brand Colors"
	print_info "All optional — press Enter to skip any of them. These map to the"
	print_info "primary / secondary / tertiary slugs in theme.json and are available"
	print_info "as var(--wp--preset--color--primary) etc. Change them later any time."
	echo ""
	prompt "Primary color (hex)"   "${PRIMARY_COLOR:-}"   PRIMARY_COLOR   v_hex_opt \
		"A hex color like #1a3a5c or 1a3a5c (3 or 6 digits), or blank to skip." || return $?
	prompt "Secondary color (hex)" "${SECONDARY_COLOR:-}" SECONDARY_COLOR v_hex_opt \
		"A hex color like #c0392b or c0392b (3 or 6 digits), or blank to skip." || return $?
	prompt "Tertiary color (hex)"  "${TERTIARY_COLOR:-}"  TERTIARY_COLOR  v_hex_opt \
		"A hex color like #e67e22 or e67e22 (3 or 6 digits), or blank to skip." || return $?

	PRIMARY_COLOR=$(normalize_hex "$PRIMARY_COLOR")
	SECONDARY_COLOR=$(normalize_hex "$SECONDARY_COLOR")
	TERTIARY_COLOR=$(normalize_hex "$TERTIARY_COLOR")

	# The palette also ships primary-dark, primary-light and secondary-dark.
	# Leaving those at the boilerplate navy next to a brand-new primary looks
	# broken, so offer to regenerate them from what was just entered.
	if [[ -n "$PRIMARY_COLOR" || -n "$SECONDARY_COLOR" ]]; then
		echo ""
		print_info "theme.json also defines primary-dark, primary-light and secondary-dark."
		prompt_yn "Derive those shades from the colors above?" "$(yn_default "$DERIVE_SHADES" y)" DERIVE_SHADES || return $?
	else
		DERIVE_SHADES="false"
	fi
	return 0
}

step_widths() {
	print_section "Layout"
	prompt "Content max-width (px)" "${CONTENT_WIDTH:-1170}" CONTENT_WIDTH v_px \
		"A pixel value between 320 and 3840." || return $?
	prompt "Wide max-width (px)" "${WIDE_WIDTH:-1440}" WIDE_WIDTH v_px \
		"A pixel value between 320 and 3840." || return $?
	if (( WIDE_WIDTH < CONTENT_WIDTH )); then
		print_warn "Wide width (${WIDE_WIDTH}px) is narrower than content width (${CONTENT_WIDTH}px), which is backwards."
		return $BACK_RC
	fi
	return 0
}

step_install() {
	print_section "Finishing"
	if $HAVE_NPM; then
		prompt_yn "Install npm dependencies and run the first build?" "$(yn_default "$INSTALL_DEPS" y)" INSTALL_DEPS || return $?
	else
		INSTALL_DEPS="false"
		print_warn "npm not found — dependency install will be skipped."
	fi
	prompt_yn "Remove setup.sh when finished?" "$(yn_default "$REMOVE_SCRIPT" y)" REMOVE_SCRIPT || return $?
	return 0
}

step_review() {
	local yn
	echo ""
	printf '  %s%s━━━ Review ━━━%s\n' "$BOLD" "$MAGENTA" "$RESET"
	echo ""
	printf '  Theme name:    %s%s%s\n' "$BOLD" "$THEME_NAME" "$RESET"
	printf '  Theme slug:    %s%s%s\n' "$BOLD" "$THEME_SLUG" "$RESET"
	printf '  Text domain:   %s%s%s\n' "$BOLD" "$TEXT_DOMAIN" "$RESET"
	printf '  PHP prefix:    %s%s%s\n' "$BOLD" "$FUNC_PREFIX" "$RESET"
	printf '  Description:   %s%s%s\n' "$BOLD" "$THEME_DESCRIPTION" "$RESET"
	printf '  Author:        %s%s%s\n' "$BOLD" "${AUTHOR_NAME:-—}" "$RESET"
	printf '  Local URL:     %s%s%s\n' "$BOLD" "$LOCAL_URL" "$RESET"
	printf '  BrowserSync:   %slocalhost:%s%s\n' "$BOLD" "$BROWSERSYNC_PORT" "$RESET"
	printf '  ACF PRO:       %s%s%s\n' "$BOLD" "$([[ "$USE_ACF" == "true" ]] && echo Yes || echo No)" "$RESET"
	printf '  Plugin:        %s%s%s\n' "$BOLD" "${PLUGIN_SLUG:-No}" "$RESET"
	printf '  Dynamic data:  %s%s%s\n' "$BOLD" "${DATA_STRATEGY%% —*}" "$RESET"
	if [[ "$CREATE_PLUGIN" == "true" ]]; then
		printf '  Scaffolds:     %sbindings %s · ability stub %s%s\n' "$BOLD" \
			"$([[ "$SCAFFOLD_BINDINGS" == "true" ]] && echo Yes || echo No)" \
			"$([[ "$SCAFFOLD_ABILITY" == "true" ]] && echo Yes || echo No)" "$RESET"
	fi
	printf '  Primary:       %s%s%s\n' "$BOLD" "${PRIMARY_COLOR:-— (unchanged)}" "$RESET"
	printf '  Secondary:     %s%s%s\n' "$BOLD" "${SECONDARY_COLOR:-— (unchanged)}" "$RESET"
	printf '  Tertiary:      %s%s%s\n' "$BOLD" "${TERTIARY_COLOR:-— (unchanged)}" "$RESET"
	printf '  Derive shades: %s%s%s\n' "$BOLD" "$([[ "$DERIVE_SHADES" == "true" ]] && echo Yes || echo No)" "$RESET"
	printf '  Widths:        %scontent %spx · wide %spx%s\n' "$BOLD" "$CONTENT_WIDTH" "$WIDE_WIDTH" "$RESET"
	printf '  Git init:      %s%s%s\n' "$BOLD" "$([[ "$INIT_GIT" == "true" ]] && echo Yes || echo No)" "$RESET"
	printf '  npm install:   %s%s%s\n' "$BOLD" "$([[ "$INSTALL_DEPS" == "true" ]] && echo Yes || echo No)" "$RESET"
	echo ""

	prompt_yn "Proceed with setup?" "y" yn || return $?
	if [[ "$yn" != "true" ]]; then
		echo ""
		print_warn "Setup cancelled. No files were changed."
		echo ""
		exit 0
	fi
	return 0
}

CONFIG_STEPS=(
	step_project_name
	step_theme_name
	step_theme_slug
	step_text_domain
	step_func_prefix
	step_description
	step_author
	step_local_url
	step_port
	step_acf
	step_plugin
	step_data_strategy
	step_scaffold
	step_git
	step_colors
	step_widths
	step_install
	step_review
)

run_config() {
	local idx=0 rc
	while (( idx < ${#CONFIG_STEPS[@]} )); do
		rc=0
		"${CONFIG_STEPS[$idx]}" || rc=$?
		if (( rc == BACK_RC )); then
			if (( idx > 0 )); then
				idx=$(( idx - 1 ))
				echo ""
				print_info "← back"
			else
				print_warn "Already at the first question."
			fi
		elif (( rc != 0 )); then
			return "$rc"
		else
			idx=$(( idx + 1 ))
		fi
	done
	return 0
}

run_config

# ══════════════════════════════════════════════════════════════════════════
#  Derived values
# ══════════════════════════════════════════════════════════════════════════

THEME_DIR="themes/${THEME_SLUG}"
THEME_JSON="${THEME_DIR}/theme.json"
VARS_SCSS="${THEME_DIR}/src/scss/abstracts/_variables.scss"

if [[ -n "$PLUGIN_SLUG" ]]; then
	PLUGIN_PREFIX=$(prefixify "$PLUGIN_SLUG")
	PLUGIN_CONST=$(upper "$PLUGIN_PREFIX")
	PLUGIN_TITLE=$(titlecase "$PLUGIN_SLUG")
else
	PLUGIN_PREFIX=""; PLUGIN_CONST=""; PLUGIN_TITLE=""
fi

# ══════════════════════════════════════════════════════════════════════════
#  Plan the run — this is what drives the progress totals
# ══════════════════════════════════════════════════════════════════════════

TOTAL_STEPS=0
plan() { TOTAL_STEPS=$(( TOTAL_STEPS + 1 )); return 0; }

if [[ "$THEME_SLUG" != "starter" ]]; then plan; fi   # rename theme dir
plan                                                  # find-and-replace sweep
plan                                                  # style.css header
plan                                                  # package.json
plan                                                  # dev server config
plan                                                  # design tokens
plan                                                  # Claude Code config
if [[ "$CREATE_PLUGIN" == "true" ]]; then
	plan                                              # scaffold plugin
	plan                                              # wire into build
	plan                                              # .gitignore
fi
if [[ "$INSTALL_DEPS" == "true" ]]; then plan; plan; fi   # npm install + build
if [[ "$INIT_GIT" == "true" ]]; then plan; fi             # git init

echo ""
print_section "Setting up your project"

if $DRY_RUN; then
	print_warn "Dry run — reporting ${TOTAL_STEPS} planned steps, writing nothing."
	echo ""
fi

# ══════════════════════════════════════════════════════════════════════════
#  1 — Rename the theme directory
# ══════════════════════════════════════════════════════════════════════════

if [[ "$THEME_SLUG" != "starter" ]]; then
	step_start "Renaming themes/starter → themes/${THEME_SLUG}"
	set_context "renaming the theme directory" \
"The rename failed. Usual causes:
  • A file inside themes/starter is locked by an open editor (common on Windows).
  • themes/${THEME_SLUG} already exists.
Close any editor holding the folder, then run setup.sh again on a fresh copy."
	if ! $DRY_RUN; then
		mv "themes/starter" "$THEME_DIR"
		MUTATED=true
		ROLLBACK_THEME_RENAME="themes/starter|${THEME_DIR}"
	fi
	step_ok
fi

# ══════════════════════════════════════════════════════════════════════════
#  2 — Find-and-replace sweep
# ══════════════════════════════════════════════════════════════════════════
#
# The previous version ran eight separate `find` traversals, each piping into
# `xargs -I {} sh -c "grep … && sed …"` — one or two process spawns per file
# per pattern. `find` also descended into node_modules/ before the -path
# filter rejected anything, so with dependencies already installed this could
# mean tens of thousands of spawns and many minutes of apparent hang.
#
# Now: enumerate the file list once with -prune, build every substitution as
# a single sed expression list, and apply them in one pass per file. sed
# applies -e expressions in order per line, so ordering semantics are
# unchanged — but the work is a fraction of what it was, and the file counter
# reflects genuine progress.

step_start "Rewriting slugs, prefixes and text domains"
set_context "rewriting project identifiers" \
"A find-and-replace pass failed. Check that no project file is read-only and
that you have write access to everything under:
  $(pwd)
On Windows, Dropbox and OneDrive can briefly lock files mid-sync — wait for
the sync to finish and try again on a fresh copy."

SED_EXPRS=()
add_replace() {
	SED_EXPRS+=(-e "s${SD}$(esc_pat "$1")${SD}$(esc_rep "$2")${SD}g")
	return 0
}

# Order matters: most specific first, broadest last.

# 1. Companion plugin placeholder paths, before the hyphen sweep can
#    half-rewrite "starter-plugin" and leave a stale directory path.
if [[ "$CREATE_PLUGIN" == "true" && -n "$PLUGIN_SLUG" ]]; then
	add_replace "starter-plugin" "$PLUGIN_SLUG"
else
	add_replace "starter-plugin" "${THEME_SLUG}-plugin"
fi

# 2. PHP function prefix.
if [[ "$FUNC_PREFIX" != "starter_" ]]; then
	add_replace "starter_" "$FUNC_PREFIX"
fi

# 3. Theme directory paths.
if [[ "$THEME_SLUG" != "starter" ]]; then
	add_replace "themes/starter" "themes/${THEME_SLUG}"
	# 4. Hyphenated prefixes: BEM classes, asset handles, pattern slugs,
	#    block namespaces, quoted slug references.
	add_replace ".starter-"   ".${THEME_SLUG}-"
	add_replace "\"starter-"  "\"${THEME_SLUG}-"
	add_replace "'starter-"   "'${THEME_SLUG}-"
	add_replace "starter/"    "${THEME_SLUG}/"
	add_replace "'starter'"   "'${THEME_SLUG}'"
	add_replace "\"starter\"" "\"${THEME_SLUG}\""
fi

# 5. Capitalized references: @package Starter, "Starter Components", etc.
if [[ "$THEME_NAME" != "Starter" ]]; then
	add_replace "Starter" "$THEME_NAME"
fi

# 6. Broad sweep last, for anything still unqualified.
if [[ "$TEXT_DOMAIN" != "starter" ]]; then
	add_replace "starter" "$TEXT_DOMAIN"
elif [[ "$THEME_SLUG" != "starter" ]]; then
	add_replace "starter" "$THEME_SLUG"
fi

# Enumerate target files once. -prune stops find descending into
# node_modules/.git/vendor at all — the difference between a sub-second scan
# and a multi-minute one.
TARGET_FILES=()
if (( ${#SED_EXPRS[@]} > 0 )); then
	while IFS= read -r -d '' f; do
		TARGET_FILES+=("$f")
	done < <(find . \
		\( -name node_modules -o -name .git -o -name vendor -o -name .playwright-mcp \) -prune -o \
		-type f \( \
			-name '*.php'  -o -name '*.scss' -o -name '*.css'  -o -name '*.js'  \
			-o -name '*.mjs' -o -name '*.json' -o -name '*.html' -o -name '*.md' \
			-o -name '*.txt' -o -name '.gitignore' \
		\) -print0 2>/dev/null)
fi

REPLACED_COUNT=0
TOTAL_FILES=${#TARGET_FILES[@]}
if (( TOTAL_FILES > 0 )); then
	scan_i=0
	for f in "${TARGET_FILES[@]}"; do
		scan_i=$(( scan_i + 1 ))
		# Redraw every file for small sets, every fifth for large ones, so
		# the redraw cost never outweighs the actual work.
		if (( TOTAL_FILES < 60 || scan_i % 5 == 0 || scan_i == TOTAL_FILES )); then
			step_progress "$scan_i" "$TOTAL_FILES" "${scan_i}/${TOTAL_FILES} files"
		fi
		if $DRY_RUN; then continue; fi
		# Only touch files that actually mention "starter" — keeps mtimes
		# stable across the rest of the tree.
		if grep -qi 'starter' "$f" 2>/dev/null; then
			if do_sed "${SED_EXPRS[@]}" "$f" 2>/dev/null; then
				REPLACED_COUNT=$(( REPLACED_COUNT + 1 ))
			else
				print_warn "Could not rewrite ${f} — skipped. Check its permissions."
			fi
		fi
	done
	if ! $DRY_RUN; then MUTATED=true; fi
fi
step_ok "${REPLACED_COUNT} of ${TOTAL_FILES} files changed"

# ══════════════════════════════════════════════════════════════════════════
#  3 — style.css theme header
# ══════════════════════════════════════════════════════════════════════════
#
# Written *after* the sweep, so the blanket "starter" replacement can never
# reach back into the values we just rendered. THEME_NAME goes in verbatim —
# spaces, capitals and punctuation exactly as typed.

step_start "Writing style.css theme header"
set_context "writing the theme header" \
"Could not write ${THEME_DIR}/style.css.
Check the file is not read-only and that the theme directory exists."

if ! $DRY_RUN; then
	{
		printf '/*\n'
		printf 'Theme Name: %s\n'  "$THEME_NAME"
		printf 'Theme URI:\n'
		printf 'Author: %s\n'      "$AUTHOR_NAME"
		printf 'Author URI: %s\n'  "$AUTHOR_URI"
		printf 'Description: %s\n' "$THEME_DESCRIPTION"
		printf 'Version: 1.0.0\n'
		printf 'Requires at least: 7.0\n'
		printf 'Tested up to: 7.0\n'
		printf 'Requires PHP: 8.1\n'
		printf 'License: GNU General Public License v2 or later\n'
		printf 'License URI: https://www.gnu.org/licenses/gpl-2.0.html\n'
		printf 'Text Domain: %s\n' "$TEXT_DOMAIN"
		printf '*/\n'
	} > "${THEME_DIR}/style.css"
	MUTATED=true
fi
step_ok "Theme Name: ${THEME_NAME}"

# ══════════════════════════════════════════════════════════════════════════
#  4 — package.json
# ══════════════════════════════════════════════════════════════════════════

step_start "Updating package.json"
set_context "updating package.json" \
"Could not update package.json. If it is now malformed, restore it from the
pristine boilerplate and re-run setup.sh."

if ! $DRY_RUN; then
	do_sed \
		-e "s${SD}\"name\": \"[^\"]*\"${SD}$(esc_rep "\"name\": \"${THEME_SLUG}-build\"")${SD}" \
		-e "s${SD}\"description\": \"[^\"]*\"${SD}$(esc_rep "\"description\": \"Build tooling for ${THEME_NAME}\"")${SD}" \
		package.json
	MUTATED=true
	# A malformed package.json is a confusing failure three steps later, at
	# npm install. Catch it here instead.
	if $HAVE_NODE && ! node -e 'JSON.parse(require("fs").readFileSync("package.json","utf8"))' 2>/dev/null; then
		step_warn "package.json no longer parses as JSON — open it and check."
	else
		step_ok "${THEME_SLUG}-build"
	fi
else
	step_ok
fi

# ══════════════════════════════════════════════════════════════════════════
#  5 — Dev server configuration
# ══════════════════════════════════════════════════════════════════════════

step_start "Configuring the dev server"
set_context "configuring build/dev-server.mjs" \
"Could not update build/dev-server.mjs. Set these by hand:
  const LOCAL_URL = '${LOCAL_URL}';
  port: ${BROWSERSYNC_PORT}
  ui: { port: $(( BROWSERSYNC_PORT + 1 )) }"

if ! $DRY_RUN; then
	do_sed \
		-e "s${SD}const LOCAL_URL = '[^']*';${SD}$(esc_rep "const LOCAL_URL = '${LOCAL_URL}';")${SD}" \
		-e "s${SD}port: 3000${SD}port: ${BROWSERSYNC_PORT}${SD}" \
		-e "s${SD}port: 3001${SD}port: $(( BROWSERSYNC_PORT + 1 ))${SD}" \
		-e "s${SD}http://localhost:3000${SD}http://localhost:${BROWSERSYNC_PORT}${SD}" \
		build/dev-server.mjs
	MUTATED=true
fi
step_ok "${LOCAL_URL} → localhost:${BROWSERSYNC_PORT}"

# ══════════════════════════════════════════════════════════════════════════
#  6 — Design tokens
# ══════════════════════════════════════════════════════════════════════════
#
# theme.json is patched with a JSON-aware Node pass when Node is available,
# which is immune to key ordering and whitespace. Without Node we fall back
# to an awk pass keyed on the palette slug.
#
# Shades are derived in HSL: dark multiplies lightness by 0.62, light moves
# it 28% of the way toward white. That keeps hue and saturation, which a
# straight mix toward black/white does not.

TOKEN_NOTES=()
TOKEN_PROBLEMS=()

set_palette_color_node() {
	local slug="$1" hex="$2" derive="$3"
	SLUG="$slug" HEX="$hex" DERIVE="$derive" FILE="$THEME_JSON" node -e '
const fs = require("fs");
const { FILE, SLUG, HEX, DERIVE } = process.env;

const toRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const toHex = (rgb) =>
	"#" + rgb.map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");

function rgbToHsl([r, g, b]) {
	r /= 255; g /= 255; b /= 255;
	const max = Math.max(r, g, b), min = Math.min(r, g, b);
	const l = (max + min) / 2;
	if (max === min) return [0, 0, l];
	const d = max - min;
	const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
	let h;
	if (max === r) h = ((g - b) / d + (g < b ? 6 : 0));
	else if (max === g) h = (b - r) / d + 2;
	else h = (r - g) / d + 4;
	return [h / 6, s, l];
}

function hslToRgb([h, s, l]) {
	if (s === 0) return [l * 255, l * 255, l * 255];
	const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
	const p = 2 * l - q;
	const f = (t) => {
		if (t < 0) t += 1;
		if (t > 1) t -= 1;
		if (t < 1 / 6) return p + (q - p) * 6 * t;
		if (t < 1 / 2) return q;
		if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
		return p;
	};
	return [f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255];
}

const shade = (hex, fn) => {
	const [h, s, l] = rgbToHsl(toRgb(hex));
	return toHex(hslToRgb([h, s, Math.max(0, Math.min(1, fn(l)))]));
};
const darker  = (hex) => shade(hex, (l) => l * 0.62);
const lighter = (hex) => shade(hex, (l) => l + (1 - l) * 0.28);

const json = JSON.parse(fs.readFileSync(FILE, "utf8"));
const palette = json?.settings?.color?.palette;
if (!Array.isArray(palette)) process.exit(3);

const set = (slug, color) => {
	const entry = palette.find((c) => c.slug === slug);
	if (!entry) return false;
	entry.color = color;
	return true;
};

if (!set(SLUG, HEX)) process.exit(4);

if (DERIVE === "true") {
	set(SLUG + "-dark", darker(HEX));
	set(SLUG + "-light", lighter(HEX));
}

fs.writeFileSync(FILE, JSON.stringify(json, null, "\t") + "\n");
'
}

set_palette_color_awk() {
	local slug="$1" hex="$2" tmp="${THEME_JSON}.setup.tmp"
	awk -v slug="$slug" -v hex="$hex" '
		$0 ~ "\"slug\"[[:space:]]*:[[:space:]]*\"" slug "\"" { armed = 1 }
		armed && /"color"[[:space:]]*:/ {
			sub(/"color"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"color\": \"" hex "\"")
			armed = 0
		}
		{ print }
	' "$THEME_JSON" > "$tmp" && mv "$tmp" "$THEME_JSON"
}

apply_palette_color() {
	local slug="$1" hex="$2"
	if [[ -z "$hex" || ! -f "$THEME_JSON" ]]; then return 0; fi
	if $HAVE_NODE; then
		local rc=0
		set_palette_color_node "$slug" "$hex" "$DERIVE_SHADES" || rc=$?
		case "$rc" in
			0) TOKEN_NOTES+=("${slug} ${hex}"); return 0 ;;
			4) TOKEN_PROBLEMS+=("theme.json has no '${slug}' palette slug — set it manually."); return 0 ;;
			*) : ;;   # fall through to awk
		esac
	fi
	if set_palette_color_awk "$slug" "$hex"; then
		TOKEN_NOTES+=("${slug} ${hex}")
	else
		TOKEN_PROBLEMS+=("Could not set '${slug}' in theme.json — set it manually.")
	fi
	return 0
}

step_start "Applying design tokens"
set_context "writing design tokens into theme.json" \
"Could not update ${THEME_JSON}. Set the palette colors and layout widths by
hand in that file — nothing else in the setup depends on this step."

if ! $DRY_RUN; then
	TOKEN_TOTAL=5
	TOKEN_DONE=0

	for pair in "primary:${PRIMARY_COLOR}" "secondary:${SECONDARY_COLOR}" "tertiary:${TERTIARY_COLOR}"; do
		TOKEN_DONE=$(( TOKEN_DONE + 1 ))
		step_progress "$TOKEN_DONE" "$TOKEN_TOTAL" "${pair%%:*}"
		apply_palette_color "${pair%%:*}" "${pair#*:}"
	done

	TOKEN_DONE=$(( TOKEN_DONE + 1 ))
	step_progress "$TOKEN_DONE" "$TOKEN_TOTAL" "content width"
	if [[ "$CONTENT_WIDTH" != "1170" ]]; then
		do_sed -e "s${SD}\"contentSize\": \"1170px\"${SD}\"contentSize\": \"${CONTENT_WIDTH}px\"${SD}" "$THEME_JSON" 2>/dev/null || true
		if [[ -f "$VARS_SCSS" ]]; then
			do_sed -e "s${SD}\$content-width: 1170px${SD}\$content-width: ${CONTENT_WIDTH}px${SD}" "$VARS_SCSS" 2>/dev/null || true
		fi
		TOKEN_NOTES+=("content ${CONTENT_WIDTH}px")
	fi

	TOKEN_DONE=$(( TOKEN_DONE + 1 ))
	step_progress "$TOKEN_DONE" "$TOKEN_TOTAL" "wide width"
	if [[ "$WIDE_WIDTH" != "1440" ]]; then
		do_sed -e "s${SD}\"wideSize\": \"1440px\"${SD}\"wideSize\": \"${WIDE_WIDTH}px\"${SD}" "$THEME_JSON" 2>/dev/null || true
		if [[ -f "$VARS_SCSS" ]]; then
			do_sed -e "s${SD}\$wide-width: 1440px${SD}\$wide-width: ${WIDE_WIDTH}px${SD}" "$VARS_SCSS" 2>/dev/null || true
		fi
		TOKEN_NOTES+=("wide ${WIDE_WIDTH}px")
	fi
	MUTATED=true

	# "${arr[*]}" with IFS=', ' joins on the first IFS character only, so
	# build the separator explicitly.
	TOKEN_SUMMARY="defaults kept"
	if (( ${#TOKEN_NOTES[@]} > 0 )); then
		TOKEN_SUMMARY="${TOKEN_NOTES[0]}"
		for (( ti = 1; ti < ${#TOKEN_NOTES[@]}; ti++ )); do
			TOKEN_SUMMARY+=", ${TOKEN_NOTES[$ti]}"
		done
	fi

	if $HAVE_NODE && ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$THEME_JSON" 2>/dev/null; then
		step_warn "theme.json no longer parses as JSON — open it and check."
	else
		step_ok "$TOKEN_SUMMARY"
	fi

	if (( ${#TOKEN_PROBLEMS[@]} > 0 )); then
		for p in "${TOKEN_PROBLEMS[@]}"; do print_warn "$p"; done
	fi
else
	step_ok
fi

# ══════════════════════════════════════════════════════════════════════════
#  7 — Claude Code configuration
# ══════════════════════════════════════════════════════════════════════════
#
# Two things need doing that copying files cannot: the hook scripts must be
# executable (Dropbox and Windows filesystems do not preserve the bit), and
# the dynamic-content default chosen above needs writing into CLAUDE.md so
# Claude reaches for the right tool without being told each session.

step_start "Preparing Claude Code configuration"
set_context "preparing the .claude directory" \
"Could not finish configuring .claude/. This does not affect the build.
If the hooks do not fire, make them executable by hand:
  chmod +x .claude/hooks/*.sh"

if ! $DRY_RUN; then
	CLAUDE_STEPS_TOTAL=2
	step_progress 1 "$CLAUDE_STEPS_TOTAL" "hooks"

	HOOK_COUNT=0
	if [[ -d ".claude/hooks" ]]; then
		for hook in .claude/hooks/*.sh; do
			[[ -e "$hook" ]] || continue
			chmod +x "$hook" 2>/dev/null || true
			HOOK_COUNT=$(( HOOK_COUNT + 1 ))
		done
	fi

	step_progress 2 "$CLAUDE_STEPS_TOTAL" "CLAUDE.md"

	case "$DATA_STRATEGY" in
		Bindings*)
			STRATEGY_LINE="**Default for this project:** bindings first. Reach for core blocks plus Block Bindings before building a custom block. Build a block only when the component has structure that bindings and patterns cannot carry." ;;
		ACF*)
			STRATEGY_LINE="**Default for this project:** ACF blocks first. Custom ACF blocks are the normal unit of work here. Still prefer a binding for a single field dropped into an existing core block." ;;
		*)
			STRATEGY_LINE="**Default for this project:** decide per component. Weigh a binding against a custom block each time using the list above, and record the reasoning in the component's own notes." ;;
	esac

	if [[ -f "CLAUDE.md" ]]; then
		do_sed -e "s${SD}^<!-- DATA_STRATEGY -->\$${SD}<!-- DATA_STRATEGY -->${SD}" CLAUDE.md 2>/dev/null || true
		# Replace the line following the marker with the chosen strategy.
		awk -v line="$STRATEGY_LINE" '
			/^<!-- DATA_STRATEGY -->$/ { print; getline; print line; next }
			{ print }
		' CLAUDE.md > CLAUDE.md.setup.tmp && mv CLAUDE.md.setup.tmp CLAUDE.md
	fi
	MUTATED=true
fi
step_ok "${HOOK_COUNT:-0} hooks executable"

# ══════════════════════════════════════════════════════════════════════════
#  8–10 — Companion plugin
# ══════════════════════════════════════════════════════════════════════════

if [[ "$CREATE_PLUGIN" == "true" && -n "$PLUGIN_SLUG" ]]; then

	step_start "Scaffolding plugins/${PLUGIN_SLUG}"
	set_context "scaffolding the companion plugin" \
"Could not create plugins/${PLUGIN_SLUG}/. Check that plugins/ is writable
and that no directory with that name already exists."

	if ! $DRY_RUN; then
		PLUGIN_FILES_TOTAL=9
		if [[ "$SCAFFOLD_BINDINGS" == "true" ]]; then PLUGIN_FILES_TOTAL=$(( PLUGIN_FILES_TOTAL + 1 )); fi
		if [[ "$SCAFFOLD_ABILITY" == "true" ]]; then PLUGIN_FILES_TOTAL=$(( PLUGIN_FILES_TOTAL + 1 )); fi
		PLUGIN_FILES_DONE=0
		pfile() {
			PLUGIN_FILES_DONE=$(( PLUGIN_FILES_DONE + 1 ))
			step_progress "$PLUGIN_FILES_DONE" "$PLUGIN_FILES_TOTAL" "$1"
			return 0
		}

		pfile "directories"
		mkdir -p "plugins/${PLUGIN_SLUG}"/{includes,blocks,acf-json,assets/css,assets/js,src/scss,src/js}
		MUTATED=true

		# ACF Local JSON. ACF writes one file per field group here on every save
		# in wp-admin and loads from them on init, which makes field definitions
		# reviewable in a pull request instead of trapped in the database.
		pfile "acf-json/"
		cat > "plugins/${PLUGIN_SLUG}/acf-json/.gitkeep" << 'ACFJSONEOF'
ACF Local JSON lives here.

ACF writes a JSON file per field group, post type, taxonomy and options page
every time you save one in wp-admin, then loads settings from these files
instead of the database. Commit this directory: it is what makes field
definitions reviewable and deployable.

If the sync UI shows groups as out of date, ACF > Field Groups > Sync.
WP-CLI equivalents are available as `wp acf json` (ACF 6.8+).

This placeholder can be deleted once the directory has real content.
ACFJSONEOF

		# Build the require list for the main plugin file.
		PLUGIN_REQUIRES="require_once ${PLUGIN_CONST}_PATH . 'includes/helpers.php';"
		if [[ "$SCAFFOLD_BINDINGS" == "true" ]]; then
			PLUGIN_REQUIRES="${PLUGIN_REQUIRES}
require_once ${PLUGIN_CONST}_PATH . 'includes/block-bindings.php';"
		fi
		if [[ "$SCAFFOLD_ABILITY" == "true" ]]; then
			PLUGIN_REQUIRES="${PLUGIN_REQUIRES}
require_once ${PLUGIN_CONST}_PATH . 'includes/abilities.php';"
		fi

		pfile "${PLUGIN_SLUG}.php"
		cat > "plugins/${PLUGIN_SLUG}/${PLUGIN_SLUG}.php" << PLUGINEOF
<?php
/**
 * Plugin Name: ${PLUGIN_TITLE}
 * Description: Data layer and custom functionality for the ${THEME_NAME} theme.
 * Version: 1.0.0
 * Author: ${AUTHOR_NAME}
 * Author URI: ${AUTHOR_URI}
 * Text Domain: ${PLUGIN_SLUG}
 * Requires at least: 6.7
 * Requires PHP: 8.0
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

define( '${PLUGIN_CONST}_VERSION', '1.0.0' );
define( '${PLUGIN_CONST}_PATH', plugin_dir_path( __FILE__ ) );
define( '${PLUGIN_CONST}_URL', plugin_dir_url( __FILE__ ) );

/**
 * Include plugin files.
 * Uncomment as you add functionality.
 */
// require_once ${PLUGIN_CONST}_PATH . 'includes/post-types.php';
// require_once ${PLUGIN_CONST}_PATH . 'includes/acf-field-groups.php';
// require_once ${PLUGIN_CONST}_PATH . 'includes/acf-options-page.php';
${PLUGIN_REQUIRES}

/**
 * Point ACF Local JSON at this plugin.
 *
 * Field groups are then written to and loaded from plugins/${PLUGIN_SLUG}/acf-json/,
 * which keeps field definitions in version control with the code that uses them
 * rather than in the database.
 */
function ${PLUGIN_PREFIX}_acf_json_save_point( \$path ) {
	return ${PLUGIN_CONST}_PATH . 'acf-json';
}
add_filter( 'acf/settings/save_json', '${PLUGIN_PREFIX}_acf_json_save_point' );

function ${PLUGIN_PREFIX}_acf_json_load_point( \$paths ) {
	\$paths[] = ${PLUGIN_CONST}_PATH . 'acf-json';
	return \$paths;
}
add_filter( 'acf/settings/load_json', '${PLUGIN_PREFIX}_acf_json_load_point' );

/**
 * Enable the ACF block editor data store (ACF 6.8.1+, WordPress 6.7+).
 *
 * Routes ACF field values through Gutenberg's native REST save instead of the
 * legacy metabox AJAX save. That gives revisions, autosave and undo over field
 * data, and is required for live preview and editing of ACF values through the
 * core Block Bindings UI.
 *
 * Commented out because it changes the save path for every field on the site —
 * enable it deliberately and retest any custom JS hooked into ACF save events.
 */
// add_filter( 'acf/settings/enable_datastore', '__return_true' );

/**
 * Register plugin blocks.
 */
function ${PLUGIN_PREFIX}_register_blocks() {
	\$blocks_dir = ${PLUGIN_CONST}_PATH . 'blocks';
	if ( ! is_dir( \$blocks_dir ) ) {
		return;
	}

	\$blocks = glob( \$blocks_dir . '/*/block.json' );
	if ( empty( \$blocks ) ) {
		return;
	}

	foreach ( \$blocks as \$block_json ) {
		register_block_type( dirname( \$block_json ) );
	}
}
add_action( 'init', '${PLUGIN_PREFIX}_register_blocks' );
PLUGINEOF

		pfile "includes/helpers.php"
		cat > "plugins/${PLUGIN_SLUG}/includes/helpers.php" << HELPEOF
<?php
/**
 * Plugin Helper Functions
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
HELPEOF

		pfile "includes/post-types.php"
		cat > "plugins/${PLUGIN_SLUG}/includes/post-types.php" << CPTEOF
<?php
/**
 * Custom Post Types and Taxonomies
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register custom post types.
 */
function ${PLUGIN_PREFIX}_register_post_types() {
	// Example:
	// register_post_type( '${PLUGIN_PREFIX}_example', array(
	// 	'labels'       => array( 'name' => 'Examples', 'singular_name' => 'Example' ),
	// 	'public'       => true,
	// 	'has_archive'  => true,
	// 	'show_in_rest' => true,
	// 	'supports'     => array( 'title', 'editor', 'thumbnail', 'custom-fields' ),
	// 	'menu_icon'    => 'dashicons-admin-post',
	// ) );
}
add_action( 'init', '${PLUGIN_PREFIX}_register_post_types' );
CPTEOF

		pfile "includes/acf-field-groups.php"
		cat > "plugins/${PLUGIN_SLUG}/includes/acf-field-groups.php" << ACFEOF
<?php
/**
 * ACF Field Group Registrations
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'acf_add_local_field_group' ) ) {
	return;
}

/**
 * Register ACF field groups.
 * Add acf_add_local_field_group() calls here.
 */
ACFEOF

		pfile "includes/acf-options-page.php"
		cat > "plugins/${PLUGIN_SLUG}/includes/acf-options-page.php" << OPTEOF
<?php
/**
 * ACF Options Page
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

if ( ! function_exists( 'acf_add_options_page' ) ) {
	return;
}

/**
 * Register ACF options pages.
 */
function ${PLUGIN_PREFIX}_register_options_pages() {
	acf_add_options_page( array(
		'page_title' => '${THEME_NAME} Settings',
		'menu_title' => 'Site Settings',
		'menu_slug'  => '${PLUGIN_PREFIX}-settings',
		'capability' => 'manage_options',
		'redirect'   => false,
	) );
}
add_action( 'acf/init', '${PLUGIN_PREFIX}_register_options_pages' );
OPTEOF

		if [[ "$SCAFFOLD_BINDINGS" == "true" ]]; then
			pfile "includes/block-bindings.php"
			cat > "plugins/${PLUGIN_SLUG}/includes/block-bindings.php" << BINDEOF
<?php
/**
 * Block Bindings Source
 *
 * Lets a core block pull its value from an ACF field, with no custom block.
 * Bind a heading, paragraph, image, button, post-date or navigation link to a
 * field and WordPress renders the field value in its place:
 *
 *   <!-- wp:heading {"metadata":{"bindings":{"content":{
 *          "source":"${PLUGIN_SLUG}/acf-field","args":{"key":"page_subtitle"}}}}} -->
 *   <h2 class="wp-block-heading"></h2>
 *   <!-- /wp:heading -->
 *
 * ACF ships its own source, "acf/field", from 6.8.1 — including editor-side
 * editing of the bound value. Prefer it when it fits. Register your own, as
 * here, when you need a source name you control, an argument shape ACF's does
 * not offer, a value that is computed rather than stored, or a binding that
 * must keep working if ACF is not installed.
 *
 * Note on the API: register_block_bindings_source() accepts exactly three
 * properties — label, get_value_callback and uses_context. There is no PHP
 * write path. Making a bound value editable in the editor additionally
 * requires a JavaScript registerBlockBindingsSource() implementing getValues,
 * setValues and canUserEditValue.
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register the bindings source.
 */
function ${PLUGIN_PREFIX}_register_block_bindings() {
	if ( ! function_exists( 'register_block_bindings_source' ) ) {
		return;
	}

	register_block_bindings_source(
		'${PLUGIN_SLUG}/acf-field',
		array(
			'label'              => __( '${PLUGIN_TITLE} field', '${PLUGIN_SLUG}' ),
			'get_value_callback' => '${PLUGIN_PREFIX}_get_binding_value',
			'uses_context'       => array( 'postId', 'postType' ),
		)
	);
}
add_action( 'init', '${PLUGIN_PREFIX}_register_block_bindings' );

/**
 * Resolve a bound attribute to an ACF field value.
 *
 * @param array     \$source_args    Args from the block's metadata.bindings entry.
 * @param WP_Block  \$block_instance The block being rendered.
 * @param string    \$attribute_name The attribute being bound.
 * @return string|null Value, or null to leave the block's fallback content.
 */
function ${PLUGIN_PREFIX}_get_binding_value( \$source_args, \$block_instance, \$attribute_name ) {
	if ( empty( \$source_args['key'] ) ) {
		return null;
	}

	if ( ! function_exists( 'get_field' ) ) {
		return null;
	}

	\$post_id = \$block_instance->context['postId'] ?? get_the_ID();

	if ( ! \$post_id ) {
		return null;
	}

	\$value = get_field( \$source_args['key'], \$post_id );

	// Bindings render into a text or attribute slot, so hand back a scalar.
	if ( is_array( \$value ) || is_object( \$value ) ) {
		return null;
	}

	return null === \$value || '' === \$value ? null : (string) \$value;
}

/**
 * Make a custom block's attributes bindable.
 *
 * Core's bindable set covers paragraph, heading, image, button, post-date and
 * the two navigation link blocks. Custom blocks opt in per attribute. Since
 * WordPress 7.0 anything bindable is automatically overridable in patterns too.
 *
 * add_filter(
 *     'block_bindings_supported_attributes_${PLUGIN_SLUG}/example',
 *     function ( \$supported_attributes ) {
 *         \$supported_attributes[] = 'title';
 *         return \$supported_attributes;
 *     }
 * );
 */
BINDEOF
		fi

		if [[ "$SCAFFOLD_ABILITY" == "true" ]]; then
			pfile "includes/abilities.php"
			cat > "plugins/${PLUGIN_SLUG}/includes/abilities.php" << ABILEOF
<?php
/**
 * WordPress Abilities API
 *
 * An "ability" is a named, schema-described capability this site exposes to
 * other tools — REST clients, the JavaScript command palette, and AI agents
 * over MCP. The server-side API landed in WordPress 6.9; 7.0 added the
 * client-side counterpart and the AI Client that consumes it.
 *
 * Two hooks matter and both are mandatory:
 *   wp_abilities_api_categories_init  register categories
 *   wp_abilities_api_init             register abilities
 * Registering outside them triggers _doing_it_wrong() and the ability is
 * silently absent.
 *
 * The example below is deliberately trivial and read-only. Replace it, or
 * delete this file — nothing else depends on it.
 *
 * @package ${PLUGIN_TITLE}
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Register the ability category. Abilities can only reference a category that
 * already exists.
 */
function ${PLUGIN_PREFIX}_register_ability_categories() {
	if ( ! function_exists( 'wp_register_ability_category' ) ) {
		return;
	}

	wp_register_ability_category(
		'${PLUGIN_SLUG}',
		array(
			'label'       => __( '${PLUGIN_TITLE}', '${PLUGIN_SLUG}' ),
			'description' => __( 'Capabilities exposed by ${PLUGIN_TITLE}.', '${PLUGIN_SLUG}' ),
		)
	);
}
add_action( 'wp_abilities_api_categories_init', '${PLUGIN_PREFIX}_register_ability_categories' );

/**
 * Register abilities.
 */
function ${PLUGIN_PREFIX}_register_abilities() {
	if ( ! function_exists( 'wp_register_ability' ) ) {
		return;
	}

	wp_register_ability(
		'${PLUGIN_SLUG}/site-summary',
		array(
			'label'         => __( 'Get site summary', '${PLUGIN_SLUG}' ),
			'description'   => __( 'Returns the site name, tagline and published post count.', '${PLUGIN_SLUG}' ),
			'category'      => '${PLUGIN_SLUG}',
			'input_schema'  => array(
				'type'                 => 'object',
				'properties'           => array(),
				'additionalProperties' => false,
			),
			'output_schema' => array(
				'type'       => 'object',
				'properties' => array(
					'name'        => array( 'type' => 'string' ),
					'description' => array( 'type' => 'string' ),
					'posts'       => array( 'type' => 'integer' ),
				),
			),
			'execute_callback'    => function () {
				return array(
					'name'        => get_bloginfo( 'name' ),
					'description' => get_bloginfo( 'description' ),
					'posts'       => (int) wp_count_posts()->publish,
				);
			},
			// Required. Never __return_true for anything with side effects or
			// privileged data — an ability is reachable by agents, not just by
			// a logged-in human clicking through wp-admin.
			'permission_callback' => function () {
				return current_user_can( 'edit_posts' );
			},
			'meta'                => array( 'show_in_rest' => true ),
		)
	);
}
add_action( 'wp_abilities_api_init', '${PLUGIN_PREFIX}_register_abilities' );

/**
 * Calling a model from PHP, for reference.
 *
 * WordPress 7.0 ships a provider-agnostic client. Nothing is guaranteed to be
 * configured, so feature-detect twice: wp_supports_ai() for the site-wide kill
 * switch (the WP_AI_SUPPORT constant and the wp_supports_ai filter), then the
 * per-capability check, then handle WP_Error from the call itself.
 *
 * function ${PLUGIN_PREFIX}_summarize( \$text ) {
 *     if ( ! function_exists( 'wp_supports_ai' ) || ! wp_supports_ai() ) {
 *         return new WP_Error( 'ai_unavailable', __( 'No AI provider is configured.', '${PLUGIN_SLUG}' ) );
 *     }
 *
 *     \$result = wp_ai_client_prompt( 'Summarize the following in two sentences: ' . \$text )
 *         ->using_temperature( 0.3 )
 *         ->generate_text();
 *
 *     return is_wp_error( \$result ) ? \$result : \$result;
 * }
 */
ABILEOF
		fi

		pfile "src/scss/plugin.scss"
		cat > "plugins/${PLUGIN_SLUG}/src/scss/plugin.scss" << PSCSSEOF
// ==========================================================================
// ${PLUGIN_TITLE} — Plugin Styles
// ==========================================================================
// Styles for plugin blocks and components.
// Compiled to assets/css/plugin.css by the build system.
PSCSSEOF

		pfile "src/js/plugin.js"
		cat > "plugins/${PLUGIN_SLUG}/src/js/plugin.js" << PJSEOF
/**
 * ${PLUGIN_TITLE} — Plugin Scripts
 *
 * Entry point for plugin-specific JavaScript.
 * Bundled to assets/js/plugin.js by the build system.
 */
PJSEOF
	fi
	step_ok "${PLUGIN_FILES_DONE:-0} items"

	# ── Wire the plugin into the build ────────────────────────────────
	step_start "Wiring the plugin into the build system"
	set_context "wiring the plugin into build/*.mjs" \
"Could not update the build scripts. Open build/compile-scss.mjs,
build/bundle-js.mjs and build/dev-server.mjs and, in each, uncomment the
PLUGIN_DIR constant and the plugin entry and watch-path lines."

	if ! $DRY_RUN; then
		WIRE_TOTAL=3
		WIRE_DONE=0
		for f in build/bundle-js.mjs build/dev-server.mjs build/compile-scss.mjs; do
			WIRE_DONE=$(( WIRE_DONE + 1 ))
			step_progress "$WIRE_DONE" "$WIRE_TOTAL" "$(basename "$f")"
			do_sed \
				-e "s${SD}// const PLUGIN_DIR = .*${SD}$(esc_rep "const PLUGIN_DIR = 'plugins/${PLUGIN_SLUG}';")${SD}" \
				-e "s${SD}// \`\${ PLUGIN_DIR }${SD}\`\${ PLUGIN_DIR }${SD}g" \
				-e "s${SD} // Uncomment when plugin exists\.${SD}${SD}g" \
				"$f"
		done

		do_sed 's|// PLUGIN_SCSS_ENTRY|{\
		input: `${ PLUGIN_DIR }/src/scss/plugin.scss`,\
		output: `${ PLUGIN_DIR }/assets/css/plugin.css`,\
	},|' build/compile-scss.mjs

		do_sed 's|// PLUGIN_JS_ENTRY|{\
		input: `${ PLUGIN_DIR }/src/js/plugin.js`,\
		output: `${ PLUGIN_DIR }/assets/js/plugin.js`,\
	},|' build/bundle-js.mjs
	fi
	step_ok "SCSS entry, JS entry and watchers"

	# ── .gitignore ────────────────────────────────────────────────────
	step_start "Updating .gitignore for the plugin"
	set_context "updating .gitignore" \
"Could not update .gitignore. Add these lines by hand:
  !plugins/${PLUGIN_SLUG}/
  plugins/${PLUGIN_SLUG}/assets/css/*.css
  plugins/${PLUGIN_SLUG}/assets/js/*.js"

	if ! $DRY_RUN && [[ -f .gitignore ]]; then
		do_sed \
			-e "s${SD}^# Uncomment and rename when you create a companion plugin:${SD}# Companion plugin (tracked):${SD}" \
			-e "s${SD}^# !plugins/.*${SD}!plugins/${PLUGIN_SLUG}/${SD}" \
			-e "s${SD}^# PLUGIN_COMPILED_START.*${SD}# Companion plugin compiled assets (built from src/):${SD}" \
			-e "s${SD}^# PLUGIN_COMPILED_END${SD}${SD}" \
			-e "s${SD}^# plugins/.*assets/css/\*\.css\$${SD}plugins/${PLUGIN_SLUG}/assets/css/*.css${SD}" \
			-e "s${SD}^# plugins/.*assets/css/\*\.css\.map\$${SD}plugins/${PLUGIN_SLUG}/assets/css/*.css.map${SD}" \
			-e "s${SD}^# plugins/.*assets/js/\*\.js\$${SD}plugins/${PLUGIN_SLUG}/assets/js/*.js${SD}" \
			-e "s${SD}^# plugins/.*assets/js/\*\.js\.map\$${SD}plugins/${PLUGIN_SLUG}/assets/js/*.js.map${SD}" \
			.gitignore
	fi
	step_ok
fi

# ══════════════════════════════════════════════════════════════════════════
#  10 — npm install and first build
# ══════════════════════════════════════════════════════════════════════════

mk_log() {
	mktemp "${TMPDIR:-/tmp}/setup-$1-XXXXXX" 2>/dev/null || printf '/tmp/setup-%s-%s.log' "$1" "$$"
}

if [[ "$INSTALL_DEPS" == "true" ]]; then
	step_start "Installing npm dependencies"
	set_context "running npm install" \
"npm install failed. The log excerpt is above. Common causes:
  • EACCES / EPERM        Do not run setup.sh with sudo. Instead:
                            sudo chown -R \"\$(id -u):\$(id -g)\" ~/.npm
  • ETIMEDOUT / ENOTFOUND Check connectivity, or configure a proxy:
                            npm config set proxy http://your-proxy:port
  • EBADENGINE            Install Node 20+:  nvm install 20 && nvm use 20
Setup continues regardless — you can run 'npm install' yourself afterwards."

	NPM_FAILED=false
	if $DRY_RUN; then
		step_skip "dry run"
	else
		NPM_LOG=$(mk_log npm)
		start_spinner "usually 30-90s"
		if npm install --no-audit --no-fund > "$NPM_LOG" 2>&1; then
			stop_spinner
			pkgcount=$(find node_modules -maxdepth 1 -mindepth 1 -type d 2>/dev/null | grep -vc '^node_modules/\.' || echo '?')
			step_ok "${pkgcount} top-level packages"
		else
			stop_spinner
			NPM_FAILED=true
			step_warn "npm install failed"
			echo ""
			print_info "Last 12 lines of the npm log:"
			tail -12 "$NPM_LOG" 2>/dev/null | while IFS= read -r l; do print_info "  $l"; done
			echo ""
			print_info "Full log: ${NPM_LOG}"
			print_info "Fix the cause, then run 'npm install' from $(pwd)."
			echo ""
		fi
	fi

	step_start "Running the first build"
	set_context "running the initial SCSS and JS build" \
"The first build failed. Run the two halves separately to see the error:
  npm run scss
  npm run js
A SCSS syntax error in one of the partials is the usual cause."

	if $DRY_RUN; then
		step_skip "dry run"
	elif $NPM_FAILED; then
		step_skip "dependencies not installed"
	else
		BUILD_LOG=$(mk_log build)
		BUILD_OK=true
		step_progress 0 2 "scss"
		npm run scss > "$BUILD_LOG" 2>&1 || BUILD_OK=false
		step_progress 1 2 "js"
		npm run js >> "$BUILD_LOG" 2>&1 || BUILD_OK=false
		step_progress 2 2 ""
		if $BUILD_OK; then
			step_ok "CSS and JS compiled"
		else
			step_warn "the build reported errors"
			echo ""
			tail -15 "$BUILD_LOG" 2>/dev/null | while IFS= read -r l; do print_info "  $l"; done
			echo ""
			print_info "Full log: ${BUILD_LOG}"
			echo ""
		fi
	fi
fi

# ══════════════════════════════════════════════════════════════════════════
#  11 — git init
# ══════════════════════════════════════════════════════════════════════════

if [[ "$INIT_GIT" == "true" ]]; then
	step_start "Initializing the git repository"
	set_context "initializing the git repository" \
"git init or the first commit failed. Common causes:
  • No git identity configured:
      git config --global user.name  \"Your Name\"
      git config --global user.email \"you@example.com\"
  • This directory is already inside another repository.
Nothing else depends on this step — you can run git init yourself."

	if $DRY_RUN; then
		step_skip "dry run"
	elif ! $HAVE_GIT; then
		step_skip "git not installed"
	elif [[ -d ".git" ]]; then
		step_skip "repository already exists"
	else
		GIT_OK=true
		step_progress 0 3 "init"
		git init -q -b main >/dev/null 2>&1 || git init -q >/dev/null 2>&1 || GIT_OK=false
		if $GIT_OK; then
			step_progress 1 3 "add"
			git add -A >/dev/null 2>&1 || GIT_OK=false
		fi
		if $GIT_OK; then
			step_progress 2 3 "commit"
			git commit -q -m "Initial commit from WordPress block theme boilerplate

Configured for: ${THEME_NAME}
Theme slug: ${THEME_SLUG}
Text domain: ${TEXT_DOMAIN}" >/dev/null 2>&1 || GIT_OK=false
		fi
		step_progress 3 3 ""
		if $GIT_OK; then
			step_ok "branch main, 1 commit"
		else
			step_warn "repository created but the commit failed"
			print_info "  Usually a missing git identity:"
			print_info "    git config --global user.name  \"Your Name\""
			print_info "    git config --global user.email \"you@example.com\""
			print_info "  Then: git add -A && git commit -m \"Initial commit\""
		fi
	fi
fi

# ══════════════════════════════════════════════════════════════════════════
#  Done
# ══════════════════════════════════════════════════════════════════════════

echo ""
printf '  %s%s━━━ Setup complete ━━━%s\n' "$BOLD" "$GREEN" "$RESET"
echo ""
printf '  %sTheme%s        %s  %s(themes/%s/)%s\n' "$BOLD" "$RESET" "$THEME_NAME" "$DIM" "$THEME_SLUG" "$RESET"
if [[ "$CREATE_PLUGIN" == "true" ]]; then
	printf '  %sPlugin%s       %s  %s(plugins/%s/)%s\n' "$BOLD" "$RESET" "$PLUGIN_TITLE" "$DIM" "$PLUGIN_SLUG" "$RESET"
fi
printf '  %sLocal site%s   %s\n' "$BOLD" "$RESET" "$LOCAL_URL"
printf '  %sDev server%s   http://localhost:%s\n' "$BOLD" "$RESET" "$BROWSERSYNC_PORT"
echo ""
print_info "Next:"
if [[ "$INSTALL_DEPS" != "true" ]]; then
	printf '    %snpm install%s     %sInstall build dependencies%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
fi
printf '    %snpm run dev%s     %sWatch mode with BrowserSync%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
printf '    %snpm run build%s   %sProduction build%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
printf '    %snpm run lint%s    %sStylelint and ESLint%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
echo ""
print_info "Activate it in WordPress under Appearance → Themes → ${THEME_NAME}"
echo ""

# Self-removal last, so a failure anywhere above never deletes the script.
if [[ "$REMOVE_SCRIPT" == "true" ]] && ! $DRY_RUN; then
	if rm -f -- "${BASH_SOURCE[0]}" 2>/dev/null; then
		print_ok "Removed setup.sh"
	else
		print_warn "Could not remove setup.sh — delete it manually."
	fi
	echo ""
fi

exit 0
