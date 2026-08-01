inpage_provider_append_tool_path() {
    if [ -d "$1" ]; then
        if [ -n "${inpage_provider_tool_path:-}" ]; then
            inpage_provider_tool_path="$inpage_provider_tool_path:$1"
        else
            inpage_provider_tool_path="$1"
        fi
    fi
}

inpage_provider_matching_node_directory() {
    inpage_provider_node_directory="$1"
    inpage_provider_expected_node_version="$2"

    if [ ! -x "$inpage_provider_node_directory/node" ] ||
        [ ! -x "$inpage_provider_node_directory/npm" ]; then
        return 1
    fi

    inpage_provider_actual_node_version=$("$inpage_provider_node_directory/node" --version 2>/dev/null) || return 1
    inpage_provider_actual_node_version=${inpage_provider_actual_node_version#v}
    if [ "$inpage_provider_actual_node_version" != "$inpage_provider_expected_node_version" ]; then
        return 1
    fi

    printf '%s\n' "$inpage_provider_node_directory"
}

inpage_provider_run_node() {
    if [ -n "${inpage_provider_pinned_node_directory:-}" ]; then
        PATH="$inpage_provider_pinned_node_directory:${PATH:-}" \
            "$inpage_provider_pinned_node_directory/node" "$@"
    else
        command node "$@"
    fi
}

inpage_provider_run_npm() {
    if [ -n "${inpage_provider_pinned_node_directory:-}" ]; then
        PATH="$inpage_provider_pinned_node_directory:${PATH:-}" \
            "$inpage_provider_pinned_node_directory/npm" "$@"
    else
        command npm "$@"
    fi
}

inpage_provider_find_pinned_node_directory() {
    inpage_provider_repository_directory="$1"
    inpage_provider_node_version_file="$inpage_provider_repository_directory/Workers/alchemy-jwt/.nvmrc"

    if [ ! -f "$inpage_provider_node_version_file" ]; then
        return 1
    fi

    inpage_provider_expected_node_version=$(/usr/bin/tr -d '[:space:]' <"$inpage_provider_node_version_file")
    case "$inpage_provider_expected_node_version" in
        ""|*[!0-9.]*|.*|*.) return 1 ;;
    esac
    inpage_provider_expected_node_major=${inpage_provider_expected_node_version%%.*}

    if command -v node >/dev/null 2>&1 &&
        command -v npm >/dev/null 2>&1; then
        inpage_provider_actual_node_version=$(node --version 2>/dev/null) || inpage_provider_actual_node_version=""
        inpage_provider_actual_node_version=${inpage_provider_actual_node_version#v}
        if [ "$inpage_provider_actual_node_version" = "$inpage_provider_expected_node_version" ]; then
            return 1
        fi
    fi

    if [ -n "${HOME:-}" ]; then
        for inpage_provider_node_directory in \
            "$HOME/.nvm/versions/node/v$inpage_provider_expected_node_version/bin" \
            "$HOME/.nvm/versions/node/$inpage_provider_expected_node_version/bin" \
            "$HOME/.asdf/installs/nodejs/$inpage_provider_expected_node_version/bin" \
            "$HOME/.local/share/mise/installs/node/$inpage_provider_expected_node_version/bin" \
            "$HOME/.volta/tools/image/node/$inpage_provider_expected_node_version/bin"
        do
            if inpage_provider_matching_node_directory \
                "$inpage_provider_node_directory" \
                "$inpage_provider_expected_node_version"
            then
                return 0
            fi
        done
    fi

    if [ -n "${HOMEBREW_PREFIX:-}" ]; then
        if inpage_provider_matching_node_directory \
            "$HOMEBREW_PREFIX/opt/node@$inpage_provider_expected_node_major/bin" \
            "$inpage_provider_expected_node_version"
        then
            return 0
        fi
    fi

    for inpage_provider_node_directory in \
        "/opt/homebrew/opt/node@$inpage_provider_expected_node_major/bin" \
        "/usr/local/opt/node@$inpage_provider_expected_node_major/bin"
    do
        if inpage_provider_matching_node_directory \
            "$inpage_provider_node_directory" \
            "$inpage_provider_expected_node_version"
        then
            return 0
        fi
    done

    return 1
}

inpage_provider_prepare_tool_path() {
    inpage_provider_tool_path=""
    inpage_provider_repository_directory="${1:-}"
    inpage_provider_pinned_node_directory=""

    if [ -n "$inpage_provider_repository_directory" ]; then
        if ! inpage_provider_pinned_node_directory=$(
            inpage_provider_find_pinned_node_directory \
                "$inpage_provider_repository_directory"
        ); then
            inpage_provider_pinned_node_directory=""
        fi
    fi

    if [ -n "${HOME:-}" ]; then
        inpage_provider_append_tool_path "$HOME/.volta/bin"
        inpage_provider_append_tool_path "$HOME/.asdf/shims"
        inpage_provider_append_tool_path "$HOME/.local/bin"
    fi

    inpage_provider_append_tool_path /opt/homebrew/bin
    inpage_provider_append_tool_path /usr/local/bin

    if [ -n "$inpage_provider_tool_path" ]; then
        PATH="$PATH:$inpage_provider_tool_path"
    fi
    export PATH
}

require_inpage_provider_toolchain() {
    if [ -z "${inpage_provider_pinned_node_directory:-}" ] &&
        ! command -v node >/dev/null 2>&1; then
        echo "error: Node.js 18 or newer is required to build the inpage script" >&2
        return 1
    fi

    if ! inpage_provider_run_node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)'; then
        echo "error: Node.js 18 or newer is required to build the inpage script" >&2
        return 1
    fi

    if [ -z "${inpage_provider_pinned_node_directory:-}" ] &&
        ! command -v npm >/dev/null 2>&1; then
        echo "error: npm 9 or newer is required to build the inpage script" >&2
        return 1
    fi

    inpage_provider_npm_version=$(inpage_provider_run_npm --version) || {
        echo "error: npm 9 or newer is required to build the inpage script" >&2
        return 1
    }
    inpage_provider_npm_major=${inpage_provider_npm_version%%.*}
    case "$inpage_provider_npm_major" in
        ""|*[!0-9]*)
            echo "error: npm 9 or newer is required to build the inpage script" >&2
            return 1
            ;;
    esac

    if [ "$inpage_provider_npm_major" -lt 9 ]; then
        echo "error: npm 9 or newer is required to build the inpage script" >&2
        return 1
    fi
}
