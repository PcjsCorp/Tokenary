#!/bin/sh

set +x
set +a
set -eu

unset alchemy_jwt_entrypoint_source \
    alchemy_jwt_entrypoint_directory
alchemy_jwt_entrypoint_source=$0
case "$alchemy_jwt_entrypoint_source" in
    */*) alchemy_jwt_entrypoint_directory=${alchemy_jwt_entrypoint_source%/*} ;;
    *) alchemy_jwt_entrypoint_directory=. ;;
esac
. "$alchemy_jwt_entrypoint_directory/alchemy_jwt_request_proof_key_common.sh"
unset alchemy_jwt_entrypoint_source \
    alchemy_jwt_entrypoint_directory

fail() {
    printf '%s\n' "error: $1" >&2
    exit 1
}

if [ "$#" -ne 0 ]; then
    fail "the request-proof key validator accepts no arguments"
fi

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && /bin/pwd -P)

load_alchemy_jwt_request_proof_key \
    "$script_directory/alchemy_jwt_request_proof_key.sha256"
