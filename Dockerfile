# check=skip=InvalidDefaultArgInFrom
# One plugin per image: its Python packages at the root of an empty image, meant to be mounted
# as a Kubernetes image volume, never run. The build args come from plugins/<plugin>/plugin.toml.

# NETBOX_IMAGE, required (hence no default): the NetBox image the plugin is tested against.
# Packages are picked by its own Python and uv (it ships no pip), so they match the interpreter
# that imports them.
ARG NETBOX_IMAGE
# Pure-Python wheels only, so the build platform's Python serves every target platform.
FROM --platform=$BUILDPLATFORM ${NETBOX_IMAGE} AS build
# PLUGIN and VERSION: the PyPI distribution and its exact version. DEPENDENCIES: names only.
ARG PLUGIN VERSION DEPENDENCIES
ENV UV_PYTHON=/opt/netbox/venv/bin/python UV_PYTHON_DOWNLOADS=never UV_NO_CACHE=1
# Wheels only: no sdist build code runs here. Dependencies come in their latest version when the
# plugin was released, so a plugin version always builds the same packages.
RUN test -n "$PLUGIN" && test -n "$VERSION" \
 && released=$("$UV_PYTHON" -c 'import json, sys, urllib.request; \
      files = json.load(urllib.request.urlopen(f"https://pypi.org/pypi/{sys.argv[1]}/{sys.argv[2]}/json"))["urls"]; \
      print(min(f["upload_time_iso_8601"] for f in files))' "$PLUGIN" "$VERSION") \
 && echo "$PLUGIN $VERSION released $released, for $("$UV_PYTHON" -V)" \
 && install() { uv pip install --target /plugin --no-deps --only-binary :all: "$@"; } \
 && install "$PLUGIN==$VERSION" \
 && if [ -n "$DEPENDENCIES" ]; then install --exclude-newer "$released" $DEPENDENCIES; fi

FROM scratch
COPY --from=build /plugin /
