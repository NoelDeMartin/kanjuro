#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

project_dir=${project_dir:?}
wwwdata_uid=$(kanjuro-docker-compose run --rm app id -u www-data | tail -n 1 | sed 's/\r$//')

if [ -z "$wwwdata_uid" ]; then
	echo "Could not set permissions"

	exit 1
fi

sudo chown -R "$wwwdata_uid":docker "$project_dir/storage"

# Database
if grep -q "DB_CONNECTION=sqlite" .env; then
	sudo chown -R "$wwwdata_uid":docker database
fi
