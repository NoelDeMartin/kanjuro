# shellcheck shell=bash
# Shared CLI helpers for bash tools.
# Expects: cli_name, cli_dir set by the dispatcher.

cli_name=${cli_name:?}
cli_dir=${cli_dir:?}

# Colours (only when stderr is a TTY)
_cli_color() {
	if [[ -t 2 ]]; then
		tput "$@" 2>/dev/null || true
	fi
}

info() { printf '%s\n' "$*" >&2; }
warn() { printf '%s%s%s\n' "$(_cli_color setaf 3)" "$*" "$(_cli_color sgr0)" >&2; }
error() { printf '%s%s%s\n' "$(_cli_color setaf 1)" "$*" "$(_cli_color sgr0)" >&2; }

# die [code] message...
die() {
	local code=1
	if [[ ${1:-} =~ ^[0-9]+$ ]]; then
		code=$1
		shift
	fi
	error "$@"
	exit "$code"
}

# cli_help: reads "# usage:" / "# summary:" from commands/*.sh and prints the list
cli_help() {
	local file usage summary max_len=0
	local -a usages=() summaries=()

	for file in "$cli_dir/commands"/*.sh; do
		[[ -f "$file" ]] || continue
		usage=$(sed -n 's/^# usage: *//p' "$file" | head -n 1)
		summary=$(sed -n 's/^# summary: *//p' "$file" | head -n 1)
		[[ -n "$usage" ]] || continue
		usages+=("$usage")
		summaries+=("$summary")
		if ((${#usage} > max_len)); then
			max_len=${#usage}
		fi
	done

	printf "Usage: %s <command> [options]\n\nCommands:\n" "$cli_name"
	local i
	for ((i = 0; i < ${#usages[@]}; i++)); do
		printf "  %-${max_len}s  %s\n" "${usages[i]}" "${summaries[i]}"
	done
}
