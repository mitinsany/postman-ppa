#!/usr/bin/env bash

set -euo pipefail

postinstall_template='packages/latest/postman/common/postinstall.in'

if ! rg -q -- '--retry 3 --retry-all-errors --connect-timeout 15' "${postinstall_template}"; then
    echo "${postinstall_template} must retry transient download failures" >&2
    exit 1
fi
