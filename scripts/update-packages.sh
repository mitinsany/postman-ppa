#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_NOTES_URL="https://mkt.cdn.postman.com/www-next/release-notes/app-release-notes.json"
CHANGELOGS_DIR="${ROOT_DIR}/changelogs/main/p/postman"
CHANNEL="latest"

download_key_for_arch() {
    case "$1" in
        amd64) printf "%s\n" "linux64" ;;
        arm64) printf "%s\n" "linux_arm64" ;;
        *)
            >&2 echo "[E] Unsupported architecture: $1"
            return 1
            ;;
    esac
}

download_url_for_arch() {
    local version="$1"
    local arch="$2"
    printf "https://dl.pstmn.io/download/version/%s/%s\n" "${version}" "$(download_key_for_arch "${arch}")"
}

content_length_for_url() {
    local url="$1"
    curl -fsSIL "${url}" | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {print $2}' | tr -d '\r' | tail -n 1
}

update_package_template() {
    local package_dir="$1"
    local version="$2"
    local download_url="$3"
    local package_json="${package_dir}/package.json"
    local preinstall="${package_dir}/preinstall"

    jq ".version = \"${version}\" | .download_url = \"${download_url}\"" "${package_json}" > version-update.json
    mv version-update.json "${package_json}"

    sed -i "s|^POSTMAN_DOWNLOAD_URL=.*|POSTMAN_DOWNLOAD_URL=\"${download_url}\"|" "${preinstall}"
}

compare_version() {
    dpkg --compare-versions "$1" lt "$2"
}

require_non_empty_release_body() {
    local release_body="$1"
    grep -q '[^[:space:]]' <<< "${release_body}"
}

write_public_changelog() {
    local version="$1"
    local release_body="$2"
    mkdir -p "${CHANGELOGS_DIR}"
    printf "%s\n" "${release_body}" > "${CHANGELOGS_DIR}/postman_${version}"
}

cd "${ROOT_DIR}"

release_json="$(mktemp)"
curl -fsSL "${RELEASE_NOTES_URL}" > "${release_json}"

remote_version="$(jq --raw-output --exit-status '.notes[0].version' "${release_json}")"
release_body="$(jq --raw-output --exit-status '.notes[0].content // ""' "${release_json}")"
rm -f "${release_json}"

if [ -z "${remote_version}" ] || [ "${remote_version}" = "null" ]; then
    >&2 echo "[E] Cannot read Postman version from ${RELEASE_NOTES_URL}"
    exit 1
fi
if ! require_non_empty_release_body "${release_body}"; then
    >&2 echo "[E] Release notes are empty for ${remote_version}."
    exit 1
fi

[ -f "commit.txt" ] && rm -f "commit.txt"

find "packages/${CHANNEL}/postman" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z | while read -r -d $'\0' package_dir; do
    package_json="${package_dir}/package.json"
    local_version="$(jq --raw-output --exit-status '.version' "${package_json}")"
    arch="$(jq --raw-output --exit-status '.architecture' "${package_json}")"
    code="$(jq --raw-output --exit-status '.code' "${package_json}")"
    download_url="$(download_url_for_arch "${remote_version}" "${arch}")"
    size="$(content_length_for_url "${download_url}")"

    if [ -z "${size}" ] || ! [[ "${size}" =~ ^[0-9]+$ ]] || [ "${size}" -le 0 ]; then
        >&2 echo "[E] Cannot read content length for ${download_url}"
        exit 1
    fi

    if ! compare_version "${local_version}" "${remote_version}"; then
        >&2 printf "[I] %s: Local (%s) >= Remote (%s). Skipped.\n" "${code}" "${local_version}" "${remote_version}"
        continue
    fi

    printf "[I] %s: Local (%s) -> Remote (%s). Updating.\n" "${code}" "${local_version}" "${remote_version}"
    write_public_changelog "${remote_version}" "${release_body}"
    update_package_template "${package_dir}" "${remote_version}" "${download_url}"

    changelog_filename="changelog-postman-${remote_version}-${arch}.dsc"
    printf "%s\n" "${release_body}" > "/tmp/${changelog_filename}"
    rm -f /tmp/postman_"${remote_version}"_"${arch}".deb
    "${ROOT_DIR}/scripts/build-single-deb.sh" "${package_dir}" "${changelog_filename}" "${size}"
    deb_file="/tmp/postman_${remote_version}_${arch}.deb"
    reprepro --outdir ./deb --ignore=unknownfield -C main includedeb "${CHANNEL}" "${deb_file}"
    echo "Upgrade ${code}: ${local_version} -> ${remote_version}" >> "commit.txt"
done

if [ -s "commit.txt" ]; then
    reprepro --outdir ./deb --ignore=unknownfield export "${CHANNEL}"
    "${ROOT_DIR}/scripts/update-release-changelogs.sh"
else
    echo "[I] No package updates detected. Skipping repository metadata export/sign."
fi

