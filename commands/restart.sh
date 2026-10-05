# usage: restart
# summary: Restart a site.
# shellcheck shell=bash

cli_dir=${cli_dir:?}
cli_name=${cli_name:?}

prepare_project_vars

"$cli_dir/$cli_name" stop
"$cli_dir/$cli_name" start
