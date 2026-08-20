#!/usr/bin/env bash

list_github_subfolders() (
    set -euo pipefail

    if [[ $# -lt 1 || $# -gt 2 ]]; then
        cat >&2 <<EOF
Usage: list_github_subfolders <github-tree-url> [glob-filter]

Lists immediate subfolder names at the given path in a GitHub repo.
Optional second argument filters names via a shell glob (e.g. '*crossplane*').

Examples:
  list_github_subfolders https://github.com/twplatformlabs/psk-aws-control-plane-configuration/tree/main/roles/sandbox
  list_github_subfolders https://github.com/twplatformlabs/psk-aws-control-plane-configuration/tree/main/roles/sandbox '*crossplane*'

Requires: gh CLI, authenticated (GH_TOKEN or gh auth login).
Assumes branch names contain no '/'.
EOF
        exit 1
    fi

    local url="$1"
    local filter="${2:-*}"
    [[ -z "$filter" ]] && filter="*"

    if [[ ! "$url" =~ ^https://github\.com/([^/]+)/([^/]+)/tree/([^/]+)(/(.*))?$ ]]; then
        echo "Error: URL must match https://github.com/OWNER/REPO/tree/BRANCH[/PATH]" >&2
        exit 1
    fi

    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local branch="${BASH_REMATCH[3]}"
    local path="${BASH_REMATCH[5]:-}"
    path="${path%/}"

    gh api "repos/${owner}/${repo}/contents/${path}?ref=${branch}" \
        --jq '.[] | select(.type == "dir") | .name' \
        | while IFS= read -r name; do
            if [[ "$name" == $filter ]]; then
                printf '%s\n' "$name"
            fi
        done
)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    list_github_subfolders "$@"
fi


# =============== filter for results
source "$(dirname "$0")/list-github-subfolders.sh"
extract_versions() {
    local input="$1"
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        echo "${name#istio-}" | tr '-' '.'
    done <<< "$input"
}
