# usage: stop
# summary: Stop a site.
# shellcheck shell=bash

prepare_project_vars

kanjuro-docker-compose down
