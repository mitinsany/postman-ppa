#!/usr/bin/env bash

set -euo pipefail

script='scripts/update-packages.sh'

if ! rg -q -- '--keepunreferencedfiles' "${script}"; then
    echo "${script} must retain replaced .deb files for clients with cached APT indexes" >&2
    exit 1
fi
