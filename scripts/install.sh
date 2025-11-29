#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

project_dir=${project_dir:?}
project_name=${project_name:?}
project_is_laravel=${project_is_laravel:?}

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

if [ -n "$KANJURO_ASK_ENV" ]; then
	IFS=',' read -ra env_vars <<<"$KANJURO_ASK_ENV"

	for var in "${env_vars[@]}"; do
		var=$(echo "$var" | xargs)

		if [ -z "$var" ]; then
			continue
		fi

		echo "Please enter a value for $var:"
		read -r value

		if [ -n "$value" ]; then
			sed -i "s/^${var}=.*/${var}=${value}/" .env
		fi
	done
fi

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

if [[ "$KANJURO_PROXY" == "true" ]]; then
	nginx-agora install-proxy "$project_dir/nginx/$nginx_file" "$project_name"
else
	nginx-agora install "$project_dir/nginx/$nginx_file" "$project_dir" "$project_name"
fi

nginx-agora enable "$project_name"

# Prepare Laravel
if [[ "$project_is_laravel" == "true" ]]; then
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
if [[ "$KANJURO_PROXY" != "true" ]]; then
	echo "Setting permissions..."

	kanjuro-cli permissions
fi

# Done
echo "$project_name installed successfully!"
