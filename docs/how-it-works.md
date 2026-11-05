# How it works

Each image is `FROM scratch`: it holds one plugin's Python packages, plus the dependencies NetBox
does not ship, and nothing else. It is never run.

Kubernetes pulls it like any image and mounts its files, read-only, into the NetBox pod. Adding
the mount path to `PYTHONPATH` lets NetBox import the plugin; listing it in `PLUGINS` enables it.

```
ghcr.io/nicolasboulard/netbox-plugin-images/netbox-plugin-dns:1.7.3
        │  image volume (read-only)
        ▼
NetBox pod ─ ghcr.io/netbox-community/netbox (official, unchanged)
             /opt/netbox/plugins/netbox-plugin-dns   ◄── PYTHONPATH
```

## What a release goes through

1. The plugin is installed from PyPI, with each dependency in its latest version on the day that
   plugin version was released, **wheels only**: no source distribution is built, so no
   third-party build code runs.
2. Every package must be a pure-Python wheel (image volumes are mounted `noexec`) and match the
   license reviewed for it.
3. NetBox boots with the plugin mounted read-only, next to PostgreSQL and Valkey. The plugin must
   load at the expected version, pass `manage.py check` and apply all its migrations.
4. The image is pushed for `linux/amd64` and `linux/arm64`, with an SBOM and a signed build
   provenance attestation, and a GitHub release lists its contents.

Nobody runs these steps by hand: Renovate proposes the updates, CI tests them, and the release
workflow publishes whatever has changed.
