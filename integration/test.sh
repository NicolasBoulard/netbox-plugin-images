#!/usr/bin/env bash
# Boots NetBox with a plugin's image content and checks NetBox loaded it.
# Usage: integration/test.sh <plugin> <content-dir>
set -euo pipefail

plugin=$1
content=$(cd "$2" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
field() { "$here/../scripts/plugin.sh" info "$plugin" "$1"; }

export NETBOX_IMAGE PLUGIN_MODULE PLUGIN_CONTENT=$content NETBOX_PORT=${NETBOX_PORT:-8080}
NETBOX_IMAGE=$(field netbox_image)
PLUGIN_MODULE=$(field module)
version=$(field version)
compose=(docker compose -f "$here/compose.yaml")

cleanup() {
  [ "${failed:-1}" = 0 ] || "${compose[@]}" logs netbox | tail -n 100
  "${compose[@]}" down --volumes --remove-orphans >/dev/null 2>&1
}
trap cleanup EXIT

echo "Starting $NETBOX_IMAGE with $PLUGIN_MODULE"
"${compose[@]}" up --detach --wait --wait-timeout 1000

manage() { "${compose[@]}" exec -T netbox /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py "$@"; }

# The running NetBox loaded the plugin, at the expected version (last line: the image prints config banners).
loaded=$(manage shell --no-startup --no-imports --interface python \
  -c "from django.apps import apps; print(apps.get_app_config('${PLUGIN_MODULE##*.}').version)" | tail -n 1)
if [ "$loaded" != "$version" ]; then
  echo "expected $PLUGIN_MODULE $version, NetBox loaded: $loaded" >&2
  exit 1
fi
manage check

# Every plugin migration ran.
if manage showmigrations "${PLUGIN_MODULE##*.}" | grep -F '[ ]'; then
  echo "unapplied migrations" >&2
  exit 1
fi
failed=0
echo "OK: $PLUGIN_MODULE $version loads in NetBox"
