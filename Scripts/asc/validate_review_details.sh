#!/usr/bin/env bash
set +x
set +a
set -euo pipefail

unset _asc_entrypoint_source _asc_entrypoint_directory
_asc_entrypoint_source="${BASH_SOURCE[0]}"
case "$_asc_entrypoint_source" in
  */*) _asc_entrypoint_directory="${_asc_entrypoint_source%/*}" ;;
  *) _asc_entrypoint_directory="." ;;
esac
source "$_asc_entrypoint_directory/common.sh"
unset _asc_entrypoint_source _asc_entrypoint_directory

require_cmd jq

load_review_details
require_complete_review_details

log "App Review details preflight ok"
