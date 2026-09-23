#!/usr/bin/env bash
#
# PostToolUse hook — lint whatever file was just written.
#
# Catches syntax errors at the moment they are introduced, while Claude still
# has the full context of what it was doing, instead of at the next build.
#
# Contract (https://code.claude.com/docs/en/hooks):
#   stdin  : JSON with .tool_input.file_path
#   exit 0 : silent success
#   exit 2 : blocking error — stderr is fed back to Claude to fix
#
# Deliberately quiet on success. Deliberately non-fatal when a linter is not
# installed: a fresh clone before `npm install` should not produce a wall of
# hook errors.
#
set -uo pipefail

INPUT="$(cat)"

if command -v jq >/dev/null 2>&1; then
	FILE_PATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')"
else
	FILE_PATH="$(printf '%s' "$INPUT" \
		| tr ',' '\n' \
		| grep -m1 '"file_path"' \
		| sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"(.*)".*/\1/')"
fi

# Native Windows sends C:\Users\... paths (doubled by the fallback's JSON
# escaping). Forward slashes work for every tool below under Git Bash.
FILE_PATH="$(printf '%s' "$FILE_PATH" | sed -E 's#\\+#/#g')"

[[ -z "${FILE_PATH:-}" ]] && exit 0
[[ -f "$FILE_PATH" ]] || exit 0

PROJECT_DIR="$(printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}" | sed -E 's#\\+#/#g')"

fail() {
	printf '%s\n' "$1" >&2
	exit 2
}

case "$FILE_PATH" in
	*.php)
		command -v php >/dev/null 2>&1 || exit 0
		if ! OUT="$(php -l "$FILE_PATH" 2>&1)"; then
			fail "PHP syntax error in ${FILE_PATH}:
${OUT}"
		fi
		;;

	*.scss)
		[[ -x "${PROJECT_DIR}/node_modules/.bin/stylelint" ]] || exit 0
		if ! OUT="$( "${PROJECT_DIR}/node_modules/.bin/stylelint" "$FILE_PATH" 2>&1 )"; then
			fail "Stylelint reported problems in ${FILE_PATH}:
${OUT}

Fix them, or if the rule is wrong for this project, adjust .stylelintrc.json."
		fi
		;;

	*.js|*.mjs)
		[[ -x "${PROJECT_DIR}/node_modules/.bin/eslint" ]] || exit 0
		if ! OUT="$( "${PROJECT_DIR}/node_modules/.bin/eslint" "$FILE_PATH" 2>&1 )"; then
			fail "ESLint reported problems in ${FILE_PATH}:
${OUT}"
		fi
		;;

	*.json)
		# theme.json, block.json and package.json breaking is a slow, confusing
		# failure downstream. Catch it here.
		if command -v node >/dev/null 2>&1; then
			if ! OUT="$( node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$FILE_PATH" 2>&1 )"; then
				fail "Invalid JSON in ${FILE_PATH}:
${OUT}"
			fi
		elif command -v python3 >/dev/null 2>&1; then
			if ! OUT="$( python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$FILE_PATH" 2>&1 )"; then
				fail "Invalid JSON in ${FILE_PATH}:
${OUT}"
			fi
		fi
		;;
esac

exit 0
