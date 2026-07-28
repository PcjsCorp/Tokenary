#!/bin/sh

# Shared request-proof key loading for build and release scripts. This file is
# sourced by callers that provide a fail() function or override the
# alchemy_jwt_request_proof_key_fail hook. It intentionally writes neither the
# key nor its fingerprint to stdout or stderr.

# This bootstrap must stay child-free. Imported variables keep their export
# attribute after assignment, so disable tracing and allexport, copy the public
# environment value only after freshly unsetting its private destination, and
# scrub every public/cache variable before a caller can launch a child process.
set +x
set +a
unset _alchemy_jwt_request_proof_key_captured_environment_value \
    _alchemy_jwt_request_proof_key_cache_valid \
    ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE \
    ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT \
    LOGIN_KEYCHAIN_SECRET_VALUE \
    login_keychain_output_with_sentinel \
    login_keychain_output \
    login_keychain_lf \
    login_keychain_service \
    login_keychain_supervisor_file \
    login_keychain_max_output_bytes \
    login_keychain_effective_uid \
    login_keychain_effective_user \
    login_keychain_passwd_record \
    login_keychain_record_user \
    login_keychain_record_password \
    login_keychain_record_uid \
    login_keychain_record_gid \
    login_keychain_record_class \
    login_keychain_record_change \
    login_keychain_record_expire \
    login_keychain_record_gecos \
    login_keychain_record_home \
    login_keychain_record_shell \
    login_keychain_record_remainder \
    login_keychain_colon_count \
    login_keychain_reconstructed_record \
    login_keychain_path \
    alchemy_key_snapshot \
    alchemy_key_public_assignment_present \
    alchemy_keychain_supervisor_file \
    alchemy_key_byte_count \
    alchemy_key_prefix \
    alchemy_final_character \
    alchemy_fingerprint_with_sentinel \
    alchemy_fingerprint_snapshot \
    alchemy_fingerprint_byte_count \
    alchemy_digest_output \
    alchemy_actual_fingerprint \
    resource_with_sentinel \
    bundled_key
_alchemy_jwt_request_proof_key_captured_environment_value=${ALCHEMY_JWT_REQUEST_PROOF_KEY-}
unset ALCHEMY_JWT_REQUEST_PROOF_KEY

alchemy_jwt_request_proof_key_fail() {
    fail "$1"
}

alchemy_jwt_request_proof_key_run_id() {
    (
        [ "$#" -ge 3 ] || exit 1
        alchemy_jwt_request_proof_key_id_supervisor=$1
        alchemy_jwt_request_proof_key_id_maximum=$2
        shift 2
        exec /usr/bin/env -i /usr/bin/perl \
            "$alchemy_jwt_request_proof_key_id_supervisor" \
            --timeout-seconds 30 \
            --term-grace-seconds 2 \
            --max-output-bytes "$alchemy_jwt_request_proof_key_id_maximum" \
            -- \
            /usr/bin/id "$@"
    )
}

alchemy_jwt_request_proof_key_run_keychain_supervisor() {
    /usr/bin/env -i /usr/bin/perl "$@"
}

load_login_keychain_secret() {
    set +x
    set +a

    if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
        alchemy_jwt_request_proof_key_fail "the login Keychain service name and supervisor path are required"
    fi

    # Imported environment variables retain their export attribute. Clear all
    # scratch variables before the first child process, especially variables
    # that can hold password bytes.
    unset LOGIN_KEYCHAIN_SECRET_VALUE \
        login_keychain_output_with_sentinel \
        login_keychain_output \
        login_keychain_lf \
        login_keychain_service \
        login_keychain_supervisor_file \
        login_keychain_max_output_bytes \
        login_keychain_effective_uid \
        login_keychain_effective_user \
        login_keychain_passwd_record \
        login_keychain_record_user \
        login_keychain_record_password \
        login_keychain_record_uid \
        login_keychain_record_gid \
        login_keychain_record_class \
        login_keychain_record_change \
        login_keychain_record_expire \
        login_keychain_record_gecos \
        login_keychain_record_home \
        login_keychain_record_shell \
        login_keychain_record_remainder \
        login_keychain_colon_count \
        login_keychain_reconstructed_record \
        login_keychain_path

    login_keychain_service=$1
    login_keychain_supervisor_file=$2
    case "$login_keychain_service" in
        ALCHEMY_JWT_REQUEST_PROOF_KEY)
            # 43 canonical bytes plus the presentation LF from `security -w`.
            login_keychain_max_output_bytes=44
            ;;
        CLOUDFLARE_API_TOKEN)
            # The shell contract permits 512 bytes plus the presentation LF.
            login_keychain_max_output_bytes=513
            ;;
        *)
            alchemy_jwt_request_proof_key_fail "the login Keychain service name is unsupported"
            ;;
    esac
    if [ -L "$login_keychain_supervisor_file" ] ||
        [ ! -f "$login_keychain_supervisor_file" ]
    then
        alchemy_jwt_request_proof_key_fail "the login Keychain supervisor is missing or invalid"
    fi

    # USER and HOME are presentation environment variables and can be stale
    # under sudo, launch agents, or CI. Resolve one internally consistent passwd
    # record for the process's effective UID instead.
    login_keychain_effective_uid=$(
        alchemy_jwt_request_proof_key_run_id \
            "$login_keychain_supervisor_file" \
            32 \
            -u \
            2>/dev/null
    ) || alchemy_jwt_request_proof_key_fail "the current user could not be identified"
    case "$login_keychain_effective_uid" in
        ''|*[!0123456789]*)
            alchemy_jwt_request_proof_key_fail "the current user could not be identified"
            ;;
    esac
    login_keychain_effective_user=$(
        alchemy_jwt_request_proof_key_run_id \
            "$login_keychain_supervisor_file" \
            257 \
            -un \
            2>/dev/null
    ) || alchemy_jwt_request_proof_key_fail "the current user could not be identified"
    case "$login_keychain_effective_user" in
        ''|*:*|*'
'*)
            alchemy_jwt_request_proof_key_fail "the current user could not be identified"
            ;;
    esac
    login_keychain_passwd_record=$(
        alchemy_jwt_request_proof_key_run_id \
            "$login_keychain_supervisor_file" \
            4097 \
            -P "$login_keychain_effective_user" 2>/dev/null
    ) || alchemy_jwt_request_proof_key_fail "the current user's account record is unavailable"
    case "$login_keychain_passwd_record" in
        ''|*'
'*)
            alchemy_jwt_request_proof_key_fail "the current user's account record is invalid"
            ;;
    esac

    # `read` assigns all surplus fields to its final variable, so count the
    # separators independently before parsing the documented ten-field record.
    login_keychain_record_remainder=$login_keychain_passwd_record
    login_keychain_colon_count=0
    while :; do
        case "$login_keychain_record_remainder" in
            *:*)
                login_keychain_record_remainder=${login_keychain_record_remainder#*:}
                login_keychain_colon_count=$((login_keychain_colon_count + 1))
                ;;
            *)
                break
                ;;
        esac
    done
    [ "$login_keychain_colon_count" -eq 9 ] ||
        alchemy_jwt_request_proof_key_fail "the current user's account record is invalid"

    IFS=: read -r \
        login_keychain_record_user \
        login_keychain_record_password \
        login_keychain_record_uid \
        login_keychain_record_gid \
        login_keychain_record_class \
        login_keychain_record_change \
        login_keychain_record_expire \
        login_keychain_record_gecos \
        login_keychain_record_home \
        login_keychain_record_shell <<EOF
$login_keychain_passwd_record
EOF
    login_keychain_reconstructed_record="${login_keychain_record_user}:${login_keychain_record_password}:${login_keychain_record_uid}:${login_keychain_record_gid}:${login_keychain_record_class}:${login_keychain_record_change}:${login_keychain_record_expire}:${login_keychain_record_gecos}:${login_keychain_record_home}:${login_keychain_record_shell}"
    if [ "$login_keychain_reconstructed_record" != "$login_keychain_passwd_record" ] ||
        [ "$login_keychain_record_user" != "$login_keychain_effective_user" ] ||
        [ "$login_keychain_record_uid" != "$login_keychain_effective_uid" ]
    then
        alchemy_jwt_request_proof_key_fail "the current user's account record is invalid"
    fi
    case "$login_keychain_record_home" in
        /)
            login_keychain_record_home=
            ;;
        /*)
            login_keychain_record_home=${login_keychain_record_home%/}
            ;;
        *)
            alchemy_jwt_request_proof_key_fail "the current user's home directory is unavailable"
            ;;
    esac
    login_keychain_path="${login_keychain_record_home}/Library/Keychains/login.keychain-db"

    # The sentinel prevents command substitution from stripping the newline
    # emitted by `security -w`. Remove exactly that presentation newline below;
    # any newline stored in the password remains for caller validation.
    login_keychain_output_with_sentinel=$(
        alchemy_jwt_request_proof_key_run_keychain_supervisor \
            "$login_keychain_supervisor_file" \
            --timeout-seconds 30 \
            --term-grace-seconds 2 \
            --max-output-bytes "$login_keychain_max_output_bytes" \
            -- \
            /usr/bin/security find-generic-password \
            -a "$login_keychain_effective_user" \
            -s "$login_keychain_service" \
            -w "$login_keychain_path" \
            2>/dev/null ||
            exit 1
        printf '.'
    ) || alchemy_jwt_request_proof_key_fail "$login_keychain_service is unavailable in the environment and login Keychain"
    login_keychain_output=${login_keychain_output_with_sentinel%?}
    login_keychain_lf='
'
    case "$login_keychain_output" in
        *"$login_keychain_lf")
            LOGIN_KEYCHAIN_SECRET_VALUE=${login_keychain_output%"$login_keychain_lf"}
            ;;
        *)
            alchemy_jwt_request_proof_key_fail "$login_keychain_service could not be read safely from the login Keychain"
            ;;
    esac

    unset login_keychain_output_with_sentinel \
        login_keychain_output \
        login_keychain_lf \
        login_keychain_service \
        login_keychain_supervisor_file \
        login_keychain_max_output_bytes \
        login_keychain_effective_uid \
        login_keychain_effective_user \
        login_keychain_passwd_record \
        login_keychain_record_user \
        login_keychain_record_password \
        login_keychain_record_uid \
        login_keychain_record_gid \
        login_keychain_record_class \
        login_keychain_record_change \
        login_keychain_record_expire \
        login_keychain_record_gecos \
        login_keychain_record_home \
        login_keychain_record_shell \
        login_keychain_record_remainder \
        login_keychain_colon_count \
        login_keychain_reconstructed_record \
        login_keychain_path
}

load_alchemy_jwt_request_proof_key() {
    set +x
    set +a

    # Keep tracing disabled after this function returns: callers still use the
    # loaded key to write or compare bundle resources.
    if [ "$#" -ne 1 ] || [ -z "$1" ]; then
        alchemy_jwt_request_proof_key_fail "the request-proof key fingerprint path is required"
    fi

    # A validated cache wins on reload. Otherwise, a public assignment made
    # after this file was sourced has precedence over the captured environment,
    # including an explicitly empty assignment. Always scrub the public value.
    unset alchemy_key_snapshot \
        alchemy_key_byte_count \
        alchemy_key_prefix \
        alchemy_final_character \
        alchemy_key_public_assignment_present \
        alchemy_keychain_supervisor_file
    alchemy_key_snapshot=
    alchemy_key_public_assignment_present=0
    if [ "${_alchemy_jwt_request_proof_key_cache_valid:-}" = 1 ] &&
        [ -n "${ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE:-}" ]
    then
        # A validated cache wins over any newly introduced public value, but it
        # still travels through validation below so hostile exported cache
        # assignments cannot bypass validation or retain their export bit.
        alchemy_key_snapshot=$ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE
        alchemy_key_public_assignment_present=2
    elif [ "${ALCHEMY_JWT_REQUEST_PROOF_KEY+x}" = x ]; then
        alchemy_key_snapshot=$ALCHEMY_JWT_REQUEST_PROOF_KEY
        alchemy_key_public_assignment_present=1
    fi

    # Clear public and cache variables before the first validation child. The
    # freshly unset scratch variable above is non-exported even when the cache
    # or public source was hostile.
    unset ALCHEMY_JWT_REQUEST_PROOF_KEY \
        _alchemy_jwt_request_proof_key_cache_valid \
        ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE \
        ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT

    alchemy_fingerprint_file=$1
    case "$alchemy_fingerprint_file" in
        */*)
            alchemy_keychain_supervisor_file="${alchemy_fingerprint_file%/*}/alchemy_login_keychain_supervisor.pl"
            ;;
        *)
            alchemy_keychain_supervisor_file=alchemy_login_keychain_supervisor.pl
            ;;
    esac

    if [ "$alchemy_key_public_assignment_present" -eq 0 ]; then
        alchemy_key_snapshot=${_alchemy_jwt_request_proof_key_captured_environment_value-}
    fi
    unset _alchemy_jwt_request_proof_key_captured_environment_value

    if [ -z "$alchemy_key_snapshot" ]; then
        load_login_keychain_secret \
            ALCHEMY_JWT_REQUEST_PROOF_KEY \
            "$alchemy_keychain_supervisor_file"
        alchemy_key_snapshot=$LOGIN_KEYCHAIN_SECRET_VALUE
        unset LOGIN_KEYCHAIN_SECRET_VALUE
    fi

    ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE=$alchemy_key_snapshot

    alchemy_key_byte_count=$(
        printf '%s' "$ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE" |
            LC_ALL=C /usr/bin/wc -c |
            /usr/bin/tr -d '[:space:]'
    ) || alchemy_jwt_request_proof_key_fail "the request-proof key length could not be validated"
    [ "$alchemy_key_byte_count" = 43 ] ||
        alchemy_jwt_request_proof_key_fail "the request-proof key must contain exactly 43 characters"
    case "$ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE" in
        *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]*)
            alchemy_jwt_request_proof_key_fail "the request-proof key must use unpadded base64url"
            ;;
    esac

    # A 32-byte value leaves four data bits in the final base64url character.
    # Requiring the low two padding bits to be zero proves this is the canonical
    # unpadded encoding of exactly 32 bytes.
    alchemy_key_prefix=${ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE%?}
    alchemy_final_character=${ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE#"$alchemy_key_prefix"}
    case "$alchemy_final_character" in
        A|E|I|M|Q|U|Y|c|g|k|o|s|w|0|4|8)
            ;;
        *)
            alchemy_jwt_request_proof_key_fail "the request-proof key must use canonical unpadded base64url"
            ;;
    esac

    if [ -L "$alchemy_fingerprint_file" ] ||
        [ ! -f "$alchemy_fingerprint_file" ]
    then
        alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint is missing or invalid"
    fi

    alchemy_lf='
'
    alchemy_fingerprint_with_sentinel=$(
        /bin/cat -- "$alchemy_fingerprint_file" || exit 1
        printf '.'
    ) || alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint could not be read"
    alchemy_fingerprint_snapshot=${alchemy_fingerprint_with_sentinel%?}
    alchemy_fingerprint_byte_count=$(
        printf '%s' "$alchemy_fingerprint_snapshot" |
            LC_ALL=C /usr/bin/wc -c |
            /usr/bin/tr -d '[:space:]'
    ) || alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint length could not be validated"
    case "$alchemy_fingerprint_byte_count" in
        64)
            ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT=$alchemy_fingerprint_snapshot
            ;;
        65)
            case "$alchemy_fingerprint_snapshot" in
                *"$alchemy_lf")
                    ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT=${alchemy_fingerprint_snapshot%"$alchemy_lf"}
                    ;;
                *)
                    alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint may end only with a single LF"
                    ;;
            esac
            ;;
        *)
            alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint must contain one SHA-256 digest"
            ;;
    esac
    case "$ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT" in
        *[!0123456789abcdef]*|'')
            alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint must be lowercase hexadecimal"
            ;;
    esac
    alchemy_fingerprint_byte_count=$(
        printf '%s' "$ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT" |
            LC_ALL=C /usr/bin/wc -c |
            /usr/bin/tr -d '[:space:]'
    ) || alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint length could not be validated"
    [ "$alchemy_fingerprint_byte_count" = 64 ] ||
        alchemy_jwt_request_proof_key_fail "the tracked request-proof key fingerprint must contain one SHA-256 digest"

    alchemy_digest_output=$(
        printf '%s' "$ALCHEMY_JWT_REQUEST_PROOF_KEY_VALUE" |
            LC_ALL=C /usr/bin/shasum -a 256
    ) || alchemy_jwt_request_proof_key_fail "the request-proof key fingerprint could not be computed"
    alchemy_actual_fingerprint=${alchemy_digest_output%% *}
    [ "$alchemy_actual_fingerprint" = "$ALCHEMY_JWT_REQUEST_PROOF_KEY_FINGERPRINT" ] ||
        alchemy_jwt_request_proof_key_fail "the request-proof key does not match the tracked fingerprint"

    _alchemy_jwt_request_proof_key_cache_valid=1
    unset alchemy_key_snapshot \
        alchemy_key_public_assignment_present \
        alchemy_key_byte_count \
        alchemy_key_prefix \
        alchemy_final_character \
        alchemy_keychain_supervisor_file \
        alchemy_lf \
        alchemy_fingerprint_with_sentinel \
        alchemy_fingerprint_snapshot \
        alchemy_fingerprint_byte_count \
        alchemy_digest_output \
        alchemy_actual_fingerprint
}
