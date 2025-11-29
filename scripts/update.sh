#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

project_dir=${project_dir:?}
project_name=${project_name:?}
project_is_laravel=${project_is_laravel:?}

# Abort on errors
set -e

# Pull new code
git -C "$project_dir" pull

# Update containers
kanjuro-docker-compose pull

if kanjuro_project_is_running; then
	kanjuro-cli restart

	# Update Laravel
	if [[ "$project_is_laravel" == "true" ]]; then
		kanjuro-docker-compose exec app php artisan config:cache
		kanjuro-docker-compose exec app php artisan event:cache
		kanjuro-docker-compose exec app php artisan optimize
		kanjuro-docker-compose exec app php artisan route:cache
		kanjuro-docker-compose exec app php artisan view:cache

		# Update Statamic
		if kanjuro-docker-compose exec app grep -q "statamic/cms" composer.json; then
			kanjuro-docker-compose exec app php artisan statamic:stache:refresh
		fi

		# Update Database
		if [ -f "$project_dir/database/database.sqlite" ]; then
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

		# Update Statamic
		if kanjuro-docker-compose run --rm app grep -q "statamic/cms" composer.json; then
			kanjuro-docker-compose run --rm app php artisan statamic:stache:refresh
		fi

		# Update Database
		if [ -f "$project_dir/database/database.sqlite" ]; then
			kanjuro-docker-compose run --rm app php artisan migrate --force
		fi
	fi
fi

if [[ "$KANJURO_PROXY" != "true" ]]; then
	echo "Setting permissions..."

	kanjuro-cli permissions
fi

echo "Updated successfully!"
