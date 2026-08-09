#!/usr/bin/env bash

set -euo pipefail

for postinstall in packages/latest/postman/*/postinstall; do
    if ! rg -q -- '--retry 5 --retry-all-errors --connect-timeout 15' "${postinstall}"; then
        echo "${postinstall} must retry transient download failures" >&2
        exit 1
    fi
done
