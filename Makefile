# Local equivalents of the CI steps: make test PLUGIN=netbox-plugin-dns
PLUGIN ?= netbox-plugin-dns

.PHONY: build check test lint unit docs clean

# The image content in build/<plugin>, its SBOM next to it.
build:
	rm -rf build/$(PLUGIN) build/$(PLUGIN).spdx.json
	docker buildx build --sbom=true \
		--build-arg PLUGIN="$$(scripts/plugin.sh info $(PLUGIN) name)" \
		--build-arg VERSION="$$(scripts/plugin.sh info $(PLUGIN) version)" \
		--build-arg DEPENDENCIES="$$(scripts/plugin.sh info $(PLUGIN) dependencies)" \
		--build-arg NETBOX_IMAGE="$$(scripts/plugin.sh info $(PLUGIN) netbox_image)" \
		--output type=local,dest=build/$(PLUGIN) .
	mv build/$(PLUGIN)/sbom.spdx.json build/$(PLUGIN).spdx.json

check: build
	scripts/plugin.sh check $(PLUGIN) build/$(PLUGIN).spdx.json

test: check
	integration/test.sh $(PLUGIN) build/$(PLUGIN)

# Policy format, shellcheck, actionlint and editorconfig, with CI's pinned tools.
lint:
	scripts/lint.sh

unit:
	scripts/plugin.sh conftest verify

docs:
	npm ci
	npm run docs:dev

clean:
	rm -rf build node_modules docs/.vitepress/dist docs/.vitepress/cache
