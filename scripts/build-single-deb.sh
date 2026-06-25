#!/usr/bin/env bash

set -euxo pipefail

PACKAGE_DIR="$1"
CHANGELOG_FILE="$2"
SIZE="$3"

if [ -z "${PACKAGE_DIR}" ]; then
    >&2 echo "[E] Cannot find folder ${PACKAGE_DIR}"
    exit 1
fi

PACKAGE_JSON="${PACKAGE_DIR}/package.json"
ROOT_DIR="${PACKAGE_DIR}/root"
if [ ! -f "${PACKAGE_JSON}" ]; then
    >&2 echo "[E] Cannot find ${PACKAGE_JSON}"
    exit 1
fi
if [ ! -d "${ROOT_DIR}" ]; then
    >&2 echo "[E] Cannot find ${ROOT_DIR}"
    exit 1
fi

VERSION="$(jq --raw-output --exit-status ".version" "${PACKAGE_JSON}")"
DESCRIPTION="$(jq --raw-output --exit-status ".description" "${PACKAGE_JSON}")"
ARCH="$(jq --raw-output --exit-status ".architecture" "${PACKAGE_JSON}")"
PACKAGE_NAME="$(jq --raw-output --exit-status ".package" "${PACKAGE_JSON}")"

if [ -z "${VERSION}" ] || [ -z "${DESCRIPTION}" ] || [ -z "${ARCH}" ] || [ -z "${PACKAGE_NAME}" ]; then
    >&2 echo "[E] Cannot find required keys within ${PACKAGE_JSON}"
    exit 1
fi

OUTPUT_DIR="/tmp"

fpm -t deb \
    -s dir \
    -C "${ROOT_DIR}" \
    --name "${PACKAGE_NAME}" \
    --architecture "${ARCH}" \
    --deb-installed-size "$(expr "${SIZE}" / 1024)" \
    --license "Postman Terms" \
    --maintainer "Aleksandr Mitin <mitinsoft@gmail.com>" \
    --vendor "https://www.postman.com/" \
    --url "https://www.postman.com/" \
    --version "${VERSION}" \
    --deb-changelog "/tmp/${CHANGELOG_FILE}" \
    --deb-upstream-changelog "/tmp/${CHANGELOG_FILE}" \
    --deb-pre-depends "curl, tar, gzip" \
    --category "devel" \
    --package "${OUTPUT_DIR}" \
    --description "${DESCRIPTION}" \
    --before-install "${PACKAGE_DIR}/preinstall" \
    --after-install "${PACKAGE_DIR}/postinstall" \
    --after-remove "${PACKAGE_DIR}/postremove" \
    --deb-no-default-config-files \
    .
