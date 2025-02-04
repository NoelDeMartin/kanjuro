#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

project_dir=${project_dir:?}
project_name=${project_name:?}

# Check if installing is necessary
if [ -f "$project_dir/.env" ]; then
	echo "Already installed!"
	exit 1
fi

# Abort and clean up on error
trap "clean_up" ERR

function clean_up() {
	if [ -d "$project_dir/nginx-agora" ]; then
		rm "$project_dir"/nginx-agora -rf
	fi

	if [ -f "$project_dir/.env" ]; then
		rm "$project_dir"/.env
	fi

	exit 1
}

function ask_resend_key() {
	echo "If you want to send emails, please introduce your Resend key:"
	read -r RESEND_KEY
}

# Prepare .env
echo "Preparing environment..."

cp .env.example .env

# Prepare resend
if grep -q "DB_CONNECTION=sqlite" .env; then
	ask_resend_key

	if [ -n "$RESEND_KEY" ]; then
		sed -i "s/^RESEND_KEY=.*/RESEND_KEY=$RESEND_KEY/" .env
	fi
fi

# Prepare nginx-agora
echo "Registering nginx-agora site..."

nginx_file=$(find "$project_dir/nginx" -maxdepth 1 -name "*.conf" -printf "%f\n" | head -n 1)

nginx-agora install "$project_dir/nginx/$nginx_file" "$project_dir" "$project_name"
nginx-agora enable "$project_name"

# Prepare Laravel
if [ -d "$project_dir/storage" ]; then
	echo "Initializing Laravel..."

	kanjuro-docker-compose run --rm app php artisan key:generate
	kanjuro-docker-compose run --rm app php artisan config:cache
	kanjuro-docker-compose run --rm app php artisan event:cache
	kanjuro-docker-compose run --rm app php artisan optimize
	kanjuro-docker-compose run --rm app php artisan route:cache
	kanjuro-docker-compose run --rm app php artisan view:cache

	# Prepare Passport
	if kanjuro-docker-compose run --rm app grep -q "laravel/passport" composer.json; then
		kanjuro-docker-compose run --rm app php artisan passport:keys
	fi

	# Prepare Statamic
	if kanjuro-docker-compose run --rm app grep -q "statamic/cms" composer.json; then
		echo "Initializing Statamic..."

		kanjuro-docker-compose run --rm app php artisan statamic:stache:warm
	fi

	# Prepare Database
	if grep -q "DB_CONNECTION=sqlite" .env; then
		touch "$project_dir/database/database.sqlite"

		kanjuro-docker-compose run --rm app php artisan migrate --force
	fi
fi

# Permissions
echo "Setting permissions..."

kanjuro-cli permissions

# Done
echo "$project_name installed successfully!"
