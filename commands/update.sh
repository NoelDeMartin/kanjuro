# usage: update
# summary: Update a site. Honours KANJURO_PROXY.
# shellcheck shell=bash

cli_dir=${cli_dir:?}
cli_name=${cli_name:?}

prepare_project_vars

project_dir=${project_dir:?}
project_name=${project_name:?}
project_is_laravel=${project_is_laravel:?}

# Pull new code
git -C "$project_dir" pull

# Update nginx-agora
if [[ -d "$project_dir/nginx" ]]; then
	nginx_file=$(find "$project_dir/nginx" -maxdepth 1 -name "*.conf" -printf "%f\n" 2>/dev/null | head -n 1 || true)

	if [[ -n "$nginx_file" ]] && command -v nginx-agora >/dev/null 2>&1; then
		nginx-agora update "$project_dir/nginx/$nginx_file" "$project_name"
	fi
fi

# Update containers
kanjuro-docker-compose pull

if kanjuro_project_is_running; then
	"$cli_dir/$cli_name" restart

	# Update Laravel
	if [[ "$project_is_laravel" == "true" ]]; then
		kanjuro-docker-compose exec app php artisan config:cache
		kanjuro-docker-compose exec app php artisan event:cache
		kanjuro-docker-compose exec app php artisan optimize
		kanjuro-docker-compose exec app php artisan route:cache
		kanjuro-docker-compose exec app php artisan view:cache
		kanjuro-docker-compose exec app php artisan cache:clear

		# Update Statamic
		if kanjuro-docker-compose exec app grep -q "statamic/cms" composer.json; then
			kanjuro-docker-compose exec app php artisan statamic:stache:refresh
		fi

		# Update Database
		if [[ -f "$project_dir/database/database.sqlite" ]]; then
			kanjuro-docker-compose exec app php artisan migrate --force
		fi
	fi
else
	# Update Laravel
	if [[ "$project_is_laravel" == "true" ]]; then
		kanjuro-docker-compose run --rm app php artisan config:cache
		kanjuro-docker-compose run --rm app php artisan event:cache
		kanjuro-docker-compose run --rm app php artisan optimize
		kanjuro-docker-compose run --rm app php artisan route:cache
		kanjuro-docker-compose run --rm app php artisan view:cache
		kanjuro-docker-compose run --rm app php artisan cache:clear

		# Update Statamic
		if kanjuro-docker-compose run --rm app grep -q "statamic/cms" composer.json; then
			kanjuro-docker-compose run --rm app php artisan statamic:stache:refresh
		fi

		# Update Database
		if [[ -f "$project_dir/database/database.sqlite" ]]; then
			kanjuro-docker-compose run --rm app php artisan migrate --force
		fi
	fi
fi

if [[ "${KANJURO_PROXY:-}" != "true" ]]; then
	info "Setting permissions..."

	"$cli_dir/$cli_name" permissions
fi

info "Updated successfully!"
