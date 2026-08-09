#!/usr/bin/env bash

set -euo pipefail

common_dir="packages/latest/postman/common"
postinstall_template="${common_dir}/postinstall.in"

for arch in amd64 arm64; do
    package_dir="packages/latest/postman/${arch}"
    package_json="${package_dir}/package.json"

    jq -e '
        (.version | test("^[0-9]+(\\.[0-9]+)+-[0-9]+$")) and
        (.upstream_version | test("^[0-9]+(\\.[0-9]+)+$")) and
        (.download_sha256 | test("^[0-9a-f]{64}$"))
    ' "${package_json}" >/dev/null

    test ! -e "${package_dir}/preinstall"
    test ! -e "${package_dir}/postinstall"
    test ! -e "${package_dir}/postremove"
    test ! -e "${package_dir}/root"
done

test -x "${common_dir}/root/usr/local/bin/postman"
test -f "${common_dir}/root/usr/share/applications/postman.desktop"
rg -q '^Exec=/opt/Postman/app/Postman %U$' "${common_dir}/root/usr/share/applications/postman.desktop"
rg -q '^Icon=/opt/Postman/app/resources/app/assets/icon.png$' "${common_dir}/root/usr/share/applications/postman.desktop"

rg -q 'sha256sum --check --status' "${postinstall_template}"
rg -q 'mktemp -d /opt/.postman-install' "${postinstall_template}"
rg -q 'mv "\$\{staged_app\}" /opt/Postman' "${postinstall_template}"
if rg -q '^rm -rf /opt/Postman$' "${postinstall_template}"; then
    echo "Postman must not be removed before the replacement is ready" >&2
    exit 1
fi

test -f "${common_dir}/postremove"
rg -q 'rm -rf /opt/Postman' "${common_dir}/postremove"
if rg -q '/usr/(local/bin/postman|share/applications/postman.desktop|share/pixmaps/postman.png)' "${common_dir}/postremove"; then
    echo "dpkg-owned files must not be removed by postremove" >&2
    exit 1
fi
