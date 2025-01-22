#!/usr/bin/env bash

if [[ $(type -t kanjuro-cli) != function ]]; then
	echo "Don't call scripts directly, use the kanjuro binary!"

	exit 1
fi

if ! kanjuro_project_is_running; then
	echo "Project is not running!"

	exit 1
fi

service=${1:-app}

kanjuro-docker-compose exec "$service" sh
