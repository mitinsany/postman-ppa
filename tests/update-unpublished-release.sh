#!/usr/bin/env bash

set -euo pipefail

script='scripts/update-packages.sh'

rg -q -- '--retry 3 --retry-all-errors --connect-timeout 15' "${script}"
if rg -q -- '--retry 5' "${script}"; then
    echo 'The release updater must use at most three retries.' >&2
    exit 1
fi

rg -q 'http_status.*404' "${script}"
rg -q -- 'curl -sSIL --connect-timeout 15' "${script}"
if rg -q -- 'Content-Length|content-length' "${script}"; then
    echo "${script} must not inspect archive size" >&2
    exit 1
fi
rg -q 'return 10' "${script}"
rg -q 'download_status.*-eq 10' "${script}"
