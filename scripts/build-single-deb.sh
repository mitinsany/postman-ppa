#!/usr/bin/env bash

set -euxo pipefail

PACKAGE_DIR="$1"
CHANGELOG_FILE="$2"
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../packages/latest/postman/common" && pwd)"

if [ -z "${PACKAGE_DIR}" ]; then
    >&2 echo "[E] Cannot find folder ${PACKAGE_DIR}"
    exit 1
fi

PACKAGE_JSON="${PACKAGE_DIR}/package.json"
ROOT_DIR="${COMMON_DIR}/root"
POSTINSTALL_TEMPLATE="${COMMON_DIR}/postinstall.in"
POSTREMOVE_SCRIPT="${COMMON_DIR}/postremove"
if [ ! -f "${PACKAGE_JSON}" ]; then
    >&2 echo "[E] Cannot find ${PACKAGE_JSON}"
    exit 1
fi
if [ ! -d "${ROOT_DIR}" ]; then
    >&2 echo "[E] Cannot find ${ROOT_DIR}"
    exit 1
fi
if [ ! -f "${POSTINSTALL_TEMPLATE}" ] || [ ! -f "${POSTREMOVE_SCRIPT}" ]; then
    >&2 echo "[E] Cannot find common package scripts"
    exit 1
fi

VERSION="$(jq --raw-output --exit-status ".version" "${PACKAGE_JSON}")"
DESCRIPTION="$(jq --raw-output --exit-status ".description" "${PACKAGE_JSON}")"
ARCH="$(jq --raw-output --exit-status ".architecture" "${PACKAGE_JSON}")"
PACKAGE_NAME="$(jq --raw-output --exit-status ".package" "${PACKAGE_JSON}")"
DOWNLOAD_URL="$(jq --raw-output --exit-status ".download_url" "${PACKAGE_JSON}")"
DOWNLOAD_SHA256="$(jq --raw-output --exit-status ".download_sha256" "${PACKAGE_JSON}")"

if [ -z "${VERSION}" ] || [ -z "${DESCRIPTION}" ] || [ -z "${ARCH}" ] || [ -z "${PACKAGE_NAME}" ] || [ -z "${DOWNLOAD_URL}" ] || ! [[ "${DOWNLOAD_SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
    >&2 echo "[E] Cannot find required keys within ${PACKAGE_JSON}"
    exit 1
fi

OUTPUT_DIR="/tmp"
postinstall_script="$(mktemp)"
trap 'rm -f "${postinstall_script}"' EXIT

sed \
    -e "s|@DOWNLOAD_URL@|${DOWNLOAD_URL}|" \
    -e "s|@DOWNLOAD_SHA256@|${DOWNLOAD_SHA256}|" \
    "${POSTINSTALL_TEMPLATE}" > "${postinstall_script}"
chmod 0755 "${postinstall_script}"

fpm -t deb \
    -s dir \
    -C "${ROOT_DIR}" \
    --name "${PACKAGE_NAME}" \
    --architecture "${ARCH}" \
    --license "Postman Terms" \
    --maintainer "Aleksandr Mitin <mitinsoft@gmail.com>" \
    --vendor "https://www.postman.com/" \
    --url "https://www.postman.com/" \
    --version "${VERSION}" \
    --deb-changelog "/tmp/${CHANGELOG_FILE}" \
    --deb-upstream-changelog "/tmp/${CHANGELOG_FILE}" \
    --depends "curl, tar, gzip" \
    --category "devel" \
    --package "${OUTPUT_DIR}" \
    --description "${DESCRIPTION}" \
    --after-install "${postinstall_script}" \
    --after-remove "${POSTREMOVE_SCRIPT}" \
    --deb-no-default-config-files \
    .
