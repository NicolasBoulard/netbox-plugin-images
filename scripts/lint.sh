#!/usr/bin/env bash
# The lint checks CI runs, with the same pinned tools, in Docker: make lint.
# Runs every check and fails if any failed. Needs bash and Docker.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
# renovate: datasource=docker depName=koalaman/shellcheck
shellcheck_version=v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
# renovate: datasource=docker depName=rhysd/actionlint
actionlint_version=1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667
# renovate: datasource=docker depName=mstruebing/editorconfig-checker
editorconfig_checker_version=4.0.2@sha256:2ba6232bfa0058f72f5f7d7816711590aa764afab1542af30b3ecb4553587918

docker=(docker run --rm -v "$root:/project:ro" -w /project)

status=0
step() {
  echo "--- $1"
  shift
  "$@" || status=1
}

step "policy format (fix with: scripts/plugin.sh conftest fmt policy)" scripts/plugin.sh conftest fmt --check policy
step shellcheck "${docker[@]}" "koalaman/shellcheck:$shellcheck_version" integration/*.sh scripts/*.sh
# actionlint also runs shellcheck on every run: block.
step actionlint "${docker[@]}" "rhysd/actionlint:$actionlint_version" .github/workflows/*.yml
step editorconfig "${docker[@]}" "mstruebing/editorconfig-checker:$editorconfig_checker_version" editorconfig-checker
exit "$status"
