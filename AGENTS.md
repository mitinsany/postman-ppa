# AGENTS.md

## Purpose

This repository hosts an unofficial APT repository for Postman packages, built and published via `reprepro`.

Main flows:
- track Postman desktop releases from the official release notes JSON;
- rebuild small `.deb` wrappers with `fpm`;
- publish metadata and package indexes under `deb/` and `db/`.

## Project Map

- `scripts/update-packages.sh`: main automation entrypoint; fetches latest Postman version, updates templates, builds `.deb` packages, and includes them into the repo.
- `scripts/build-single-deb.sh`: builds one Debian package from one architecture template folder.
- `packages/latest/postman/<arch>/`: package templates for `amd64` and `arm64`.
- `conf/`: `reprepro` configuration.
- `deb/`: published APT repository contents.
- `db/`: `reprepro` database files.
- `changelogs/`: published changelog files used by APT/Mint changelog fetch.
- `scripts/docker/`: helper scripts to prepare CI/runtime dependencies and import signing key.
- `scripts/update-release-changelogs.sh`: injects `Changelogs` into `Release` and resigns metadata.
- `scripts/validate-release-integrity.sh`: validates release metadata/changelog integrity before commit.
- `.github/workflows/build.yml`: scheduled/manual CI update and auto-commit pipeline.

## Working Rules For Agents

1. Keep changes minimal and task-focused.
2. Never manually edit generated repository indexes in `deb/dists/**` or `db/**` unless the task explicitly requires low-level recovery.
3. Prefer modifying source-of-truth files: `packages/**`, `conf/**`, and `scripts/**`.
4. Preserve the package layout under `/opt/Postman`, matching the local Postman install shape.
5. Do not remove or rotate signing configuration unless explicitly requested.
6. If task touches library/framework usage, use MCP `context7` for documentation lookup when needed.
7. Local package build/update workflow should run inside Docker container built from repository-root `Dockerfile`.

## Standard Local Workflow

```bash
docker build -f Dockerfile -t postman-ppa-builder .
docker run --rm -it -v "$PWD:/app" postman-ppa-builder bash -lc "./scripts/update-packages.sh"
```

## Validation Checklist Before Commit

- Scripts pass shell syntax checks:
  - `bash -n scripts/*.sh scripts/docker/*.sh`
- Desktop files validate:
  - `desktop-file-validate packages/latest/postman/*/root/usr/share/applications/postman.desktop`
- If versions changed:
  - matching `preinstall` download URLs are updated;
  - changelog file exists at `changelogs/main/p/postman/postman_<version>`;
  - package files for `amd64` and `arm64` exist in `deb/pool/main/p/postman/`;
  - repo metadata files under `deb/dists/latest/` changed consistently.

