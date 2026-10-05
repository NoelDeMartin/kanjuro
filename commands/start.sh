# usage: start
# summary: Start a site. Honours KANJURO_PROXY.
# shellcheck shell=bash

prepare_project_vars

project_dir=${project_dir:?}
project_is_laravel=${project_is_laravel:?}

kanjuro-docker-compose up -d

if ! kanjuro_project_is_running; then
	die "Project failed to start"
fi

# Link storage
if [[ "$project_is_laravel" == "true" ]]; then
	kanjuro-docker-compose exec app php artisan storage:unlink
	kanjuro-docker-compose exec app php artisan storage:link --relative
fi

# Publish assets
if [[ "${KANJURO_PROXY:-}" != "true" ]]; then
	rm -rf "$project_dir/public"
	kanjuro-docker-compose cp "app:/app/public/." "$project_dir/public"
fi
