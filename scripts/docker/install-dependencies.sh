#!/usr/bin/env bash

set -euxo pipefail

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -qq install --yes --no-install-recommends \
  ca-certificates \
  binutils \
  curl \
  desktop-file-utils \
  git \
  gnupg2 \
  jq \
  openssl \
  reprepro \
  ripgrep \
  ruby \
  sed

gem install fpm
