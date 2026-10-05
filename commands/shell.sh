# usage: shell [service]
# summary: Open a shell in a site container. Service defaults to app.
# shellcheck shell=bash

prepare_project_vars

if ! kanjuro_project_is_running; then
	die "Project is not running"
fi

service=${1:-app}

kanjuro-docker-compose exec "$service" sh
