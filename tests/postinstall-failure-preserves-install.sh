#!/usr/bin/env bash

set -euo pipefail

deb_file="deb/pool/main/p/postman/postman_12.22.8-1_amd64.deb"

docker run --rm --network none -v "$(pwd):/repo:ro" ubuntu:26.04 bash -lc '
    set -euo pipefail
    mkdir -p /work/bin /opt/Postman
    printf old > /opt/Postman/marker
    dpkg-deb --ctrl-tarfile /repo/'"${deb_file}"' | tar -xOf - ./postinst > /work/postinst
    sed -i "s/^POSTMAN_DOWNLOAD_SHA256=.*/POSTMAN_DOWNLOAD_SHA256=\x27$(printf "0%.0s" {1..64})\x27/" /work/postinst
    cat > /work/bin/curl <<"EOF"
#!/usr/bin/env bash
printf invalid > "${!#}"
EOF
    chmod 0755 /work/bin/curl /work/postinst

    if PATH=/work/bin:$PATH bash /work/postinst; then
        echo "postinstall unexpectedly accepted an invalid archive" >&2
        exit 1
    fi

    test -f /opt/Postman/marker
    test ! -d /opt/.postman-install.failed
'
