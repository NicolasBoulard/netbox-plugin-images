# Unit tests for plugin.rego: conftest verify
package main

import rego.v1

package_doc(id, name, license) := {
	"SPDXID": id,
	"name": name,
	"licenseDeclared": license,
	"externalRefs": [{"referenceType": "purl", "referenceLocator": sprintf("pkg:pypi/%s@1.0.0", [name])}],
}

sbom_with(packages, files) := {"predicate": {
	"packages": [package_doc(p.id, p.name, p.license) | some p in packages],
	"files": [{"SPDXID": sprintf("f-%s", [f]), "fileName": f} | some _, f in files],
	"relationships": [{"spdxElementId": id, "relationshipType": "CONTAINS", "relatedSpdxElement": sprintf("f-%s", [f])} |
		some id, f in files
	],
}}

example := {"id": "p1", "name": "netbox_example", "license": "MIT"}

example_files := {"p1": "netbox_example-1.0.0.dist-info/licenses/LICENSE"}

check(licenses, packages, files) := result if {
	result := deny with input as [
		{"path": "plugins/netbox-example/plugin.toml", "contents": {"name": "netbox-example", "licenses": licenses}},
		{"path": "build/netbox-example.spdx.json", "contents": sbom_with(packages, files)},
	]
}

test_valid if {
	count(check({"netbox-example": "MIT"}, [example], example_files)) == 0
}

test_names_are_normalized if {
	count(check({"Netbox_Example": "MIT"}, [example], example_files)) == 0
}

test_reviewed_license_when_metadata_says_nothing if {
	count(check({"netbox-example": "MIT"}, [object.union(example, {"license": "NOASSERTION"})], example_files)) == 0
}

test_reviewed_license_when_metadata_is_free_text if {
	count(check({"netbox-example": "Apache-2.0"}, [object.union(example, {"license": "LicenseRef-Apache-2.0"})], example_files)) == 0
}

test_free_text_license_is_not_suggested if {
	"netbox_example: add netbox-example = \"<SPDX>\" to [licenses] after reading its license file" in check({}, [object.union(example, {"license": "LicenseRef-BSD"})], example_files)
}

test_unreviewed_package if {
	"netbox_example: add netbox-example = \"MIT\" to [licenses] after reading its license file" in check({}, [example], example_files)
}

test_license_changed_upstream if {
	"netbox_example: declared MIT but the package now says BUSL-1.1: review the change" in check({"netbox-example": "MIT"}, [object.union(example, {"license": "BUSL-1.1"})], example_files)
}

test_license_not_allowed if {
	"netbox-example: BUSL-1.1 is not in the allowed license list" in check({"netbox-example": "BUSL-1.1"}, [object.union(example, {"license": "BUSL-1.1"})], example_files)
}

test_declared_but_not_installed if {
	"[licenses] lists gone, which is not installed" in check({"netbox-example": "MIT", "gone": "MIT"}, [example], example_files)
}

test_no_license_file if {
	"netbox_example: the wheel ships no license file, so the image could not carry its notice" in check({"netbox-example": "MIT"}, [example], {"p1": "netbox_example/__init__.py"})
}

test_compiled_code if {
	some msg in check({"netbox-example": "MIT"}, [example], object.union(example_files, {"p1": "netbox_example/_speedups.so"}))
	contains(msg, "only pure-Python wheels work")
}

test_nothing_installed if {
	"SBOM: no Python package, nothing was installed" in check({}, [], {})
}
