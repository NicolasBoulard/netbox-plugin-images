---
editLink: false
lastUpdated: false
---

<script setup>
import { data as plugins } from './catalog.data'
</script>

# Catalog

The latest release of each plugin. Its release notes list the packages, licenses and digest.

<table>
  <thead>
    <tr><th>Plugin</th><th>Module</th><th>NetBox</th><th>Licenses</th><th>Latest image</th></tr>
  </thead>
  <tbody>
    <tr v-for="p in plugins" :key="p.plugin">
      <td><a :href="p.homepage">{{ p.name }}</a></td>
      <td><code>{{ p.module }}</code></td>
      <td>{{ p.netbox }}</td>
      <td><code>{{ p.licenses }}</code></td>
      <td v-if="p.image"><code>{{ p.image }}</code> (<a :href="p.notes">notes</a>)</td>
      <td v-else>not released yet</td>
    </tr>
  </tbody>
</table>

Missing a plugin? [Request it](https://github.com/NicolasBoulard/netbox-plugin-images/issues/new?template=plugin-request.yml) or
[add it yourself](https://github.com/NicolasBoulard/netbox-plugin-images/blob/main/CONTRIBUTING.md): one small TOML file.
