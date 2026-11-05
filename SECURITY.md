# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub security advisories](https://github.com/NicolasBoulard/netbox-plugin-images/security/advisories/new),
not in a public issue.

- **A flaw in this repository** (build, workflows, published images): it is handled here.
- **A flaw in a packaged plugin or dependency**: report it to its upstream project. Once fixed
  upstream, Renovate picks up the new version and a new image is released automatically.

## What the images guarantee

- Each image holds only the wheels listed in its release notes, downloaded from PyPI: the pinned
  plugin and its dependencies as they were on the day it was released. No sdist is built, so no
  third-party build code runs.
- Every image has a signed build provenance attestation and an SBOM:

  ```sh
  gh attestation verify oci://ghcr.io/nicolasboulard/netbox-plugin-images/<plugin>@<digest> \
    --repo NicolasBoulard/netbox-plugin-images
  ```

- New upstream versions wait three days before Renovate proposes them, to give time for a
  compromised release to be pulled.
