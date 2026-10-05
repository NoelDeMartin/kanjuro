# shellcheck shell=bash
# Shared Docker and project helpers for kanjuro.
# shellcheck disable=SC2154

# shellcheck disable=SC2034
project_dir=""
# shellcheck disable=SC2034
project_name=""
# shellcheck disable=SC2034
project_is_laravel=false

kanjuro-docker-compose() {
	if [[ ! -f "${project_dir:-$PWD}/.env" ]]; then
		die "The current project has not been configured yet, please run '$cli_name install' to set it up."
	fi

	local network="nginx-agora-${project_name:-$(basename "${project_dir:-$PWD}")}"
	if [[ -z $(docker network ls --quiet --filter "name=^${network}\$") ]]; then
		docker network create "$network" >/dev/null 2>&1 || true
	fi

	if [[ -n $(docker container ls --quiet --filter "name=^nginx-agora\$") ]]; then
		if ! docker network inspect "$network" --format '{{range .Containers}}{{println .Name}}{{end}}' 2>/dev/null | grep -Fxq "nginx-agora"; then
			docker network connect "$network" nginx-agora >/dev/null 2>&1 || true
		fi
	fi

	docker compose -f "${project_dir:-$PWD}/docker-compose.yml" "$@"
}

kanjuro_project_is_running() {
	[[ -n $(kanjuro-docker-compose ps --quiet) ]]
}

ask_resend_key() {
	if ! printenv RESEND_KEY >/dev/null 2>&1; then
		if [[ -t 0 ]]; then
			info "If you want to send emails, please introduce your Resend key:"
			read -r RESEND_KEY || true
		fi
	else
		RESEND_KEY=$(printenv RESEND_KEY)
	fi
}

validate_project_dir() {
	project_dir=$PWD
	project_name=$(basename "$PWD")

	if [[ "$project_dir" == "$cli_dir" ]]; then
		die "Please run this command from the project's directory"
	fi

	if [[ ! -f "$project_dir/.env.example" ]]; then
		die "Couldn't find .env.example, are you sure '$project_dir' is a valid project?"
	fi
}

prepare_env() {
	validate_project_dir

	if [[ -f "$project_dir/.env" ]]; then
		die "Already installed!"
	fi

	# Prepare .env
	info "Preparing environment..."

	cp "$project_dir/.env.example" "$project_dir/.env"

	if [[ -n "${KANJURO_ASK_ENV:-}" ]]; then
		local -a env_vars=()
		IFS=',' read -ra env_vars <<<"$KANJURO_ASK_ENV"

		local var value escaped_value
		for var in "${env_vars[@]}"; do
			var=$(printf '%s' "$var" | xargs)
			[[ -z "$var" ]] && continue
			[[ "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "Invalid variable name '$var' in KANJURO_ASK_ENV"

			if printenv "$var" >/dev/null 2>&1; then
				value=$(printenv "$var")
			elif [[ -t 0 ]]; then
				info "Please enter a value for $var:"
				read -r value || true
			else
				value=""
			fi

			if [[ -n "$value" ]]; then
				escaped_value=$(printf '%s' "$value" | sed -e 's/[\\/&|]/\\&/g')
				sed -i "s|^${var}=.*|${var}=${escaped_value}|" "$project_dir/.env"
			fi
		done
	fi

	# Prepare resend
	if grep -q "RESEND_KEY=" "$project_dir/.env"; then
		ask_resend_key

		if [[ -n "${RESEND_KEY:-}" ]]; then
			local escaped_key
			escaped_key=$(printf '%s' "$RESEND_KEY" | sed -e 's/[\\/&|]/\\&/g')
			sed -i "s|^RESEND_KEY=.*|RESEND_KEY=${escaped_key}|" "$project_dir/.env"
		fi
	fi

	# Prepare sqlite
	if grep -q "DB_CONNECTION=sqlite" "$project_dir/.env"; then
		mkdir -p "$project_dir/database"

		if [[ ! -f "$project_dir/database/database.sqlite" ]]; then
			touch "$project_dir/database/database.sqlite"
		fi
	fi
}

prepare_project_vars() {
	validate_project_dir

	if [[ ! -f "$project_dir/.env" ]]; then
		die "The current project has not been configured yet, please run '$cli_name install' to set it up."
	fi

	local line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line#"${line%%[![:space:]]*}"}"
		[[ -z "$line" || "$line" == \#* ]] && continue
		[[ "$line" == export\ * ]] && line="${line#export }"
		if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			[[ "$key" == KANJURO_* ]] || continue
			val="${BASH_REMATCH[2]}"
			if [[ "$val" =~ ^\"(.*)\"$ ]]; then
				val="${BASH_REMATCH[1]}"
			elif [[ "$val" =~ ^\'(.*)\'$ ]]; then
				val="${BASH_REMATCH[1]}"
			else
				val="${val%%[[:space:]]#*}"
				val="${val%"${val##*[![:space:]]}"}"
			fi
			printf -v "$key" '%s' "$val"
		fi
	done <"$project_dir/.env"

	# shellcheck disable=SC2034
	if kanjuro-docker-compose run --rm app sh -c 'grep -q "laravel/framework" composer.json 2>/dev/null'; then
		project_is_laravel=true
	else
		project_is_laravel=false
	fi
}
