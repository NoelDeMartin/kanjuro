# usage: compose <args>...
# summary: Run docker compose commands for a site.
# shellcheck shell=bash

prepare_project_vars

kanjuro-docker-compose "$@"
