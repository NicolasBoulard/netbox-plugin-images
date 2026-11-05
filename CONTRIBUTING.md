# Contributing

Thanks for helping. Most contributions are a new plugin; the steps are below.

## Add a plugin

1. Check the plugin qualifies:
   - it is published on PyPI as a **pure-Python wheel** (`py3-none-any`): image volumes are
     mounted `noexec`, so compiled extensions cannot load;
   - it and every dependency it adds use an **OSI-approved license** that ships its text in the
     wheel (see `allowed` in `policy/plugin.rego`);
   - it supports a current NetBox release.
2. Create `plugins/<pypi-name>/plugin.toml`, copying `plugins/netbox-plugin-dns/plugin.toml`:
   - `name`, `version`: the PyPI distribution and the exact version, on two consecutive lines in
     that order: that is how Renovate finds the version;
   - `module`: what goes in NetBox's `PLUGINS`;
   - `homepage`: the plugin's project page, an `https://` URL;
   - `dependencies`: the names of the runtime dependencies NetBox does **not** already ship, without
     versions: each comes in its latest version on the day the plugin was released. Never list a
     NetBox dependency: it would shadow NetBox's own copy;
   - `netbox`: the NetBox image tag to build and test against (`vX.Y.Z`), whose minor matches the
     plugin's support: the build picks the packages with that image's own Python;
   - `[licenses]`: the SPDX identifier of every package, after reading its license file. Leave it
     empty at first: the check lists each missing package with the license its metadata declares,
     when it declares an SPDX one. Free text such as `Apache 2.0` shows as `<SPDX>`: the license
     file decides.
3. Run it locally. You need make, bash, git, jq, [yq](https://github.com/mikefarah/yq) (mikefarah's,
   v4) and Docker with Buildx. The build exports an SBOM, which needs Docker Desktop, the containerd
   image store or a `docker-container` Buildx builder.

   ```sh
   make lint
   make test PLUGIN=<pypi-name>
   ```

   `make test` builds the image content, checks wheels and licenses, then boots NetBox with the
   plugin and checks it loads and migrates. NetBox listens on port 8080: set `NETBOX_PORT` if it is
   taken.
4. Open a pull request. Once merged, the release workflow publishes the image and Renovate keeps it
   up to date.

## How releases work

Nothing is released by hand. On every push to `main`, `scripts/plugin.sh plan` lists the plugin
versions that have no release yet; each gets a tag `<plugin>/<version>`, an image tagged
`<version>`, an attestation and a GitHub release. Dependencies follow the plugin: their versions are
the latest on PyPI when that plugin version was released, so Renovate only tracks the plugin and a
version always builds the same packages.

A version is released once and never rebuilt. Any other change, to `dependencies`, `[licenses]` or
the root `Dockerfile`, ships with the plugin's next version.

## Conventions

- Commits follow [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): description`.
- Keep comments short and about *why*.
- `make lint` runs CI's lint job with the same pinned tools, in Docker: the policy's format
  (`scripts/plugin.sh conftest fmt policy` fixes it), shellcheck, actionlint and editorconfig.
- `make unit` runs the license policy's tests (`policy/plugin_test.rego`, with Conftest).
- `.github/actions/plugin` builds, checks and tests one plugin; CI and the release workflow both
  run it, so a release goes through the checks its pull request passed.
- The site is Markdown in `docs/` ([VitePress](https://vitepress.dev)): `make docs` serves it
  locally and needs Node, in the version of `.node-version`.
  The catalog reads each `plugin.toml` and the release tags at build time (`docs/catalog.data.ts`).

## Maintainer setup

One-time settings on GitHub, after the first push:

1. **Settings → Pages**: source *GitHub Actions*.
2. Install the [Renovate GitHub App](https://github.com/apps/renovate) on the repository.
3. **Settings → General**: enable *Allow auto-merge*.
4. **Settings → Rules**: protect `main`, require pull requests and the `ci-ok` status check.
5. **Settings → Code security**: enable *Private vulnerability reporting*, where `SECURITY.md` and
   the issue forms send reports.
6. **Issues → Labels**: create `plugin-request`, which the plugin request form applies (`bug`
   exists by default).
7. After the first release, check each package under **Packages** is *public* and linked to this
   repository.
