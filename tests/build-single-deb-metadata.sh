#!/usr/bin/env bash

set -euo pipefail

builder='scripts/build-single-deb.sh'

rg -q -- '--depends "curl, tar, gzip"' "${builder}"
if rg -q -- '--deb-pre-depends' "${builder}"; then
    echo 'Postman runtime tools must be regular dependencies, not Pre-Depends.' >&2
    exit 1
fi

if rg -q -- '--deb-installed-size|INSTALLED_SIZE_KB' "${builder}"; then
    echo 'Installed-Size must be left to fpm instead of being set manually.' >&2
    exit 1
fi
