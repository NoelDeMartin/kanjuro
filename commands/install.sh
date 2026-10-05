# usage: install
# summary: Install a new site. Honours KANJURO_PROXY, KANJURO_ASK_ENV, and RESEND_KEY.
# shellcheck shell=bash

cli_dir=${cli_dir:?}
cli_name=${cli_name:?}

command -v nginx-agora >/dev/null 2>&1 || die "'nginx-agora' is required but not found in PATH"

validate_project_dir

project_dir=${project_dir:?}
project_name=${project_name:?}

if [[ -f "$project_dir/.env" ]]; then
	die "Already installed!"
fi

clean_up() {
	if [[ -d "$project_dir/nginx-agora" ]]; then
		rm -rf "$project_dir/nginx-agora"
	fi

	if [[ -f "$project_dir/.env" ]]; then
		rm -f "$project_dir/.env"
	fi

	if [[ -f "$project_dir/database/database.sqlite" ]]; then
		warn "Warning: Database file 'database/database.sqlite' may have been created but not removed."
	fi
}
trap clean_up EXIT

prepare_env
prepare_project_vars

project_is_laravel=${project_is_laravel:?}

# Prepare nginx-agora
info "Registering nginx-agora site..."

[[ -d "$project_dir/nginx" ]] || die "No nginx configuration directory found in '$project_dir'"
nginx_file=$(find "$project_dir/nginx" -maxdepth 1 -name "*.conf" -printf "%f\n" 2>/dev/null | head -n 1 || true)
[[ -n "$nginx_file" ]] || die "No nginx configuration file found in '$project_dir/nginx'"

if [[ "${KANJURO_PROXY:-}" == "true" ]]; then
	nginx-agora install-proxy "$project_dir/nginx/$nginx_file" "$project_name"
else
	nginx-agora install "$project_dir/nginx/$nginx_file" "$project_dir" "$project_name"
fi

nginx-agora enable "$project_name"

# Prepare Laravel
if [[ "$project_is_laravel" == "true" ]]; then
	info "Initializing Laravel..."

	kanjuro-docker-compose run --rm app php artisan key:generate
	kanjuro-docker-compose run --rm app php artisan config:cache
	kanjuro-docker-compose run --rm app php artisan event:cache
	kanjuro-docker-compose run --rm app php artisan optimize
	kanjuro-docker-compose run --rm app php artisan route:cache
	kanjuro-docker-compose run --rm app php artisan view:cache

	# Prepare Passport
	if kanjuro-docker-compose run --rm app grep -q "laravel/passport" composer.json; then
		kanjuro-docker-compose run --rm app php artisan passport:keys --force
	fi

	# Prepare Statamic
	if kanjuro-docker-compose run --rm app grep -q "statamic/cms" composer.json; then
		info "Initializing Statamic..."

		kanjuro-docker-compose run --rm app php artisan statamic:stache:warm
	fi

	# Prepare Database
	if grep -q "DB_CONNECTION=sqlite" "$project_dir/.env"; then
		kanjuro-docker-compose run --rm app php artisan migrate --force
	fi
fi

# Permissions
if [[ "${KANJURO_PROXY:-}" != "true" ]]; then
	info "Setting permissions..."

	"$cli_dir/$cli_name" permissions
fi

# Done
trap - EXIT
info "$project_name installed successfully!"
