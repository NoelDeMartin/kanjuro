# usage: permissions
# summary: Fix site permissions.
# shellcheck shell=bash

prepare_project_vars

project_dir=${project_dir:?}
project_is_laravel=${project_is_laravel:?}

wwwdata_uid=$(kanjuro-docker-compose run --rm app id -u www-data | tail -n 1 | sed 's/\r$//' || true)

if [[ -z "$wwwdata_uid" ]]; then
	die "Could not set permissions"
fi

if [[ "$project_is_laravel" == "true" ]]; then
	sudo chown -R "$wwwdata_uid":docker "$project_dir/storage"
fi

# Database
if grep -q "DB_CONNECTION=sqlite" "$project_dir/.env"; then
	sudo chown -R "$wwwdata_uid":docker "$project_dir/database"
fi
