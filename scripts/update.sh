#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

project_dir=${project_dir:?}

# Abort on errors
set -e

# Pull new code
git -C "$project_dir" pull

# Update containers
kanjuro-docker-compose pull

if kanjuro_project_is_running; then
	kanjuro-cli restart
	kanjuro-docker-compose exec app php artisan config:cache
	kanjuro-docker-compose exec app php artisan event:cache
	kanjuro-docker-compose exec app php artisan optimize
	kanjuro-docker-compose exec app php artisan route:cache
	kanjuro-docker-compose exec app php artisan view:cache
else
	kanjuro-docker-compose run --rm app php artisan config:cache
	kanjuro-docker-compose run --rm app php artisan event:cache
	kanjuro-docker-compose run --rm app php artisan optimize
	kanjuro-docker-compose run --rm app php artisan route:cache
	kanjuro-docker-compose run --rm app php artisan view:cache
fi

echo "Updated successfully!"
