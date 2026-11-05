#!/usr/bin/env bash
# Plugin tooling for CI, releases and local runs. Each plugin is one plugins/<plugin>/plugin.toml;
# the Dockerfile at the root builds them all.
#
#   scripts/plugin.sh info <plugin> [field]   JSON description of a plugin, or one field as text
#   scripts/plugin.sh changed [base-ref]      JSON matrix of the plugins a change touches (all without a usable ref)
#   scripts/plugin.sh plan                    JSON matrix of the plugin versions not released yet
#   scripts/plugin.sh check <plugin> <sbom>   policy/plugin.rego on plugin.toml and the image's SBOM
#   scripts/plugin.sh summary <plugin> <content>   the plugin's own one-line summary, from its wheel
#   scripts/plugin.sh notes <plugin> <tag> <image> <digest> <content> <repo>   release notes in Markdown
#                                             (<content>: the image content; its SBOM is <content>.spdx.json)
#   scripts/plugin.sh conftest <args>...      conftest itself, e.g. `conftest verify` for the policy tests
#
# Needs bash, git, jq, yq (mikefarah, v4) and Docker (for conftest).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# renovate: datasource=docker depName=openpolicyagent/conftest
conftest_version=v0.71.1@sha256:0e77cdf7c1fcde035f3c579e4aaa6664ee2a8be5777eaa9af9f520cdd02280c0
conftest_image=openpolicyagent/conftest:$conftest_version
# A change to any of these can alter every image: CI rebuilds and tests them all.
shared_inputs='^(Dockerfile$|scripts/plugin\.sh$|policy/|integration/|\.github/actions/|\.github/workflows/ci\.yml$)'
# PEP 503 names.
jq_lib='def normalize: ascii_downcase | gsub("[-_.]+"; "-");'

die() { echo "$*" >&2; exit 1; }

plugin_toml() {
  # Names and pins end up in tags, image names and shell commands: keep them inert.
  [[ $1 =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "$1: plugin directories are lowercase letters, digits and dashes"
  [ -f "$root/plugins/$1/plugin.toml" ] || die "unknown plugin: $1"
  echo "$root/plugins/$1/plugin.toml"
}

plugins() {
  for f in "$root"/plugins/*/plugin.toml; do basename "$(dirname "$f")"; done
}

info() {
  yq -p toml -o json "$(plugin_toml "$1")" | jq --arg plugin "$1" '
    def require(f; pattern; what):
      if all(f; type == "string" and test(pattern)) then . else error("\($plugin): \(what)") end;
    require(.name, (.dependencies // [])[]; "^[A-Za-z0-9][A-Za-z0-9._-]*$"; "name and dependencies are PyPI names only")
    | require(.version; "^[A-Za-z0-9][A-Za-z0-9.+!_-]*$"; "version is an exact version")
    | require(.module; "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$"; "module is a Python module path")
    | require(.netbox; "^v[0-9]+\\.[0-9]+\\.[0-9]+$"; "netbox is a NetBox image tag, vX.Y.Z")
    | require(.homepage; "^https://[A-Za-z0-9._~:/?#@!&+,;=%-]+$"; "homepage is an https URL")
    | {
        plugin: $plugin, name, version, module, homepage,
        dependencies: (.dependencies // [] | join(" ")),
        netbox_image: "ghcr.io/netbox-community/netbox:\(.netbox)",
        netbox_minor: (.netbox | ltrimstr("v") | split(".")[:2] | join(".")),
        license: ([.licenses // {} | .[] | if test(" OR ") then "(\(.))" else . end] | unique | join(" AND "))
      }'
}

matrix() { while read -r p; do info "$p"; done | jq -cs .; }

changed() {
  # No base, or one this clone lacks (manual run, force push, new branch): every plugin.
  if [ -z "${1:-}" ] || ! git -C "$root" rev-parse -q --verify "$1^{commit}" >/dev/null; then
    plugins | matrix
    return
  fi
  local paths
  paths=$(git -C "$root" diff --name-only "$1...HEAD")
  if grep -qE "$shared_inputs" <<<"$paths"; then plugins | matrix; return; fi
  sed -n 's|^plugins/\([^/]*\)/.*|\1|p' <<<"$paths" | sort -u |
    while read -r p; do if [ -f "$root/plugins/$p/plugin.toml" ]; then echo "$p"; fi; done | matrix
}

# Releases: tag <plugin>/<version>, image tag <version>, one per plugin version and never rebuilt:
# its dependencies resolve to their versions on the plugin's release day, so the version says it all.
plan() {
  local p version
  for p in $(plugins); do
    version=$(info "$p" | jq -r .version)
    git -C "$root" rev-parse -q --verify "refs/tags/$p/$version" >/dev/null && continue
    info "$p" | jq -c '. + {tag: "\(.plugin)/\(.version)"}'
  done | jq -cs .
}

conftest() {
  docker run --rm -v "$root:/project:ro" -w /project "$@"
}

check() {
  local file sbom
  file=$(plugin_toml "$1")
  sbom=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
  conftest -v "$sbom:/sbom/$1.spdx.json:ro" "$conftest_image" \
    test --no-color --combine "${file#"$root"/}" "/sbom/$1.spdx.json"
}

# The Summary of the plugin's own wheel, in the image content.
summary() {
  local name meta
  name=$(info "$1" | jq -r "$jq_lib"'.name | normalize')
  for meta in "${2%/}"/*.dist-info/METADATA; do
    if [ "$(sed -n 's/^Name: //p' "$meta" | head -n 1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[-_.]+/-/g')" = "$name" ]; then
      sed -n 's/^Summary: //p' "$meta" | head -n 1
      return
    fi
  done
  die "$2: no wheel of $name"
}

notes() {
  local plugin=$1 tag=$2 image=$3 digest=$4 content=${5%/} repo=$6 sbom previous changes licenses
  sbom=$content.spdx.json
  previous=$(git -C "$root" tag --list "$plugin/*" --sort=-creatordate | grep -vxF "$tag" | head -n 1 || true)
  changes=$(git -C "$root" log --format='- %s (%h)' "${previous:+$previous..}HEAD" -- "plugins/$plugin")
  licenses=$(yq -p toml -o json "$(plugin_toml "$plugin")" | jq "$jq_lib"'.licenses // {} | with_entries(.key |= normalize)')
  info "$plugin" | jq -r \
    --arg tag "$tag" --arg image "$image" --arg digest "$digest" --arg repo "$repo" \
    --arg changes "${changes:-- Initial release}" --argjson licenses "$licenses" \
    --arg summary "$(summary "$plugin" "$content")" \
    --slurpfile sbom "$sbom" "$jq_lib"'
    ([($sbom[0].predicate // $sbom[0]).packages[]
        | select(any(.externalRefs[]?; .referenceType == "purl" and (.referenceLocator | startswith("pkg:pypi/"))))
        | "| [\(.name)](https://pypi.org/project/\(.name | normalize)/\(.versionInfo)/) | \(.versionInfo) | `\($licenses[.name | normalize])` |"]
      | sort | join("\n")) as $rows
    | "**\($summary)**

| | |
|---|---|
| Image | `\($image):\(.version)` |
| Digest | `\($digest)` |
| NetBox module | `\(.module)` |
| Tested with | NetBox \(.netbox_image | sub(".*:"; "")) |
| License | `\(.license)` |

### Contents

| Package | Version | License |
|---|---|---|
\($rows)

Each package keeps its own license text in its `*.dist-info` directory inside the image.

### Usage

```yaml
volumes:
  - name: \(.plugin)
    image:
      reference: \($image):\(.version)@\($digest)
```

Mount it at `/opt/netbox/plugins/\(.plugin)`, add that path to `PYTHONPATH` and `\(.module)` to `PLUGINS`.

### Verify

```sh
gh attestation verify oci://\($image)@\($digest) --repo \($repo)
```

### Changes

\($changes)"'
}

command=${1:-}
shift || true
case $command in
  info) if [ -n "${2:-}" ]; then info "$1" | jq -r --arg f "$2" '.[$f]'; else info "$1"; fi ;;
  changed) changed "${1:-}" ;;
  plan) plan ;;
  check) [ $# -eq 2 ] || die "usage: $0 check <plugin> <sbom>"; check "$@" ;;
  summary) [ $# -eq 2 ] || die "usage: $0 summary <plugin> <content>"; summary "$@" ;;
  notes) [ $# -eq 6 ] || die "usage: $0 notes <plugin> <tag> <image> <digest> <content> <repo>"; notes "$@" ;;
  conftest) conftest "$conftest_image" "$@" ;;
  *) sed -n '2,15s/^# \{0,1\}//p' "$0" >&2; exit 2 ;;
esac
