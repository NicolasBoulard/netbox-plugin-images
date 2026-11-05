# Checks a plugin image before it is tested or published. Two inputs, read together:
#   conftest test --combine plugins/<plugin>/plugin.toml build/<plugin>.spdx.json
# - plugin.toml: the license reviewed for each package, in [licenses];
# - the SPDX SBOM BuildKit generated for the image content (docker buildx build --sbom=true).
package main

import rego.v1

# OSI-approved licenses whose text ships inside each wheel: redistributing them in an image is allowed.
allowed := {
	"0BSD", "AGPL-3.0-only", "AGPL-3.0-or-later", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause",
	"CC0-1.0", "GPL-2.0-only", "GPL-2.0-or-later", "GPL-3.0-only", "GPL-3.0-or-later", "HPND", "ISC",
	"LGPL-2.1-only", "LGPL-2.1-or-later", "LGPL-3.0-only", "LGPL-3.0-or-later", "MIT", "MIT-0",
	"MPL-2.0", "PSF-2.0", "Python-2.0", "Unlicense", "Zlib",
}

plugin := [f.contents | some f in input; endswith(f.path, "plugin.toml")][0]

# BuildKit wraps the SPDX document in an in-toto statement; a bare SPDX document works too.
sbom := [object.get(f.contents, "predicate", f.contents) | some f in input; endswith(f.path, ".spdx.json")][0]

normalize(name) := lower(regex.replace(name, `[-_.]+`, "-"))

# PEP 503 name -> SPDX expression reviewed for it.
declared[normalize(name)] := license if some name, license in object.get(plugin, "licenses", {})

packages contains pkg if {
	some pkg in sbom.packages
	some ref in pkg.externalRefs
	ref.referenceType == "purl"
	startswith(ref.referenceLocator, "pkg:pypi/")
}

file_names := {f.SPDXID: f.fileName | some f in sbom.files}

files(pkg) := {file_names[rel.relatedSpdxElement] |
	some rel in sbom.relationships
	rel.spdxElementId == pkg.SPDXID
	rel.relationshipType == "CONTAINS"
}

# What the package's own metadata says, when it says it in SPDX. Free text such as "Apache 2.0"
# reaches the SBOM as LicenseRef-*, which only the human review can map, as when metadata is silent.
detected(pkg) := pkg.licenseDeclared if {
	not pkg.licenseDeclared in {"", "NOASSERTION", "NONE"}
	not contains(pkg.licenseDeclared, "LicenseRef-")
}

# The license to suggest for a package nobody reviewed yet.
suggestion(pkg) := detected(pkg) if {
	detected(pkg)
} else := "<SPDX>"

spdx_ids(expression) := {id | some id in regex.find_n(`[A-Za-z0-9.+-]+`, expression, -1)} - {"AND", "OR", "WITH"}

deny contains "SBOM: no Python package, nothing was installed" if count(packages) == 0

deny contains msg if {
	some pkg in packages
	not declared[normalize(pkg.name)]
	msg := sprintf(
		`%s: add %s = "%s" to [licenses] after reading its license file`,
		[pkg.name, normalize(pkg.name), suggestion(pkg)],
	)
}

deny contains msg if {
	some pkg in packages
	license := declared[normalize(pkg.name)]
	detected(pkg) != license
	msg := sprintf(
		"%s: declared %s but the package now says %s: review the change",
		[pkg.name, license, detected(pkg)],
	)
}

deny contains msg if {
	some name, license in declared
	unknown := spdx_ids(license) - allowed
	count(unknown) > 0
	msg := sprintf("%s: %s is not in the allowed license list", [name, concat(", ", sort(unknown))])
}

deny contains msg if {
	some name, _ in declared
	not name in {normalize(pkg.name) | some pkg in packages}
	msg := sprintf("[licenses] lists %s, which is not installed", [name])
}

deny contains msg if {
	some pkg in packages
	not any_match(`(?i)\.dist-info/(.+/)?(LICEN[CS]E|COPYING|NOTICE)[^/]*$`, files(pkg))
	msg := sprintf("%s: the wheel ships no license file, so the image could not carry its notice", [pkg.name])
}

deny contains msg if {
	some pkg in packages
	some name in files(pkg)
	regex.match(`\.(so|pyd|dylib)$`, name)
	msg := sprintf(
		"%s: %s is compiled code; only pure-Python wheels work (image volumes are mounted noexec)",
		[pkg.name, name],
	)
}

any_match(pattern, names) if {
	some name in names
	regex.match(pattern, name)
}
