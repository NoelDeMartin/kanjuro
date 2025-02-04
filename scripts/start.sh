#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit
fi

project_dir=${project_dir:?}

kanjuro-docker-compose up -d

if ! kanjuro_project_is_running; then
	exit
fi

# Link storage
kanjuro-docker-compose exec app php artisan storage:unlink
kanjuro-docker-compose exec app php artisan storage:link --relative

# Publish assets
rm "$project_dir"/public -rf
kanjuro-docker-compose cp "app:/app/public/." "$project_dir/public"
