#!/usr/bin/env bash

set -euo pipefail

script_path="${1:-scripts/update-packages.sh}"

if rg -q 'content_length_for_url|Cannot read content length' "${script_path}"; then
    echo "update-packages.sh must not query tarball Content-Length before building packages" >&2
    exit 1
fi

if rg -q 'build-single-deb\.sh.*\$\{size\}' "${script_path}"; then
    echo "update-packages.sh must not pass a remote tarball size to the package builder" >&2
    exit 1
fi
