# Tags and versions

Each image is tagged with the plugin's own version, such as `1.7.3`, and the tag never moves: a
plugin version is built once. Its dependencies come in their latest version on the day that plugin
version was released. Pin the tag in deployments, ideally with its digest.

## Keep deployments up to date with Renovate

Renovate does not read `image.reference` on its own. Add this to your `renovate.json`:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/\\.ya?ml$/"],
      "matchStrings": [
        "reference: (?<depName>ghcr\\.io/nicolasboulard/netbox-plugin-images/[^:\\s]+):(?<currentValue>[^@\\s]+)(@(?<currentDigest>sha256:[a-f0-9]+))?"
      ],
      "datasourceTemplate": "docker",
      "versioningTemplate": "pep440"
    }
  ]
}
```
