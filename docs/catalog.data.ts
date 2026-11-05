// Catalog rows, read at build time from plugins/*/plugin.toml and the release tags.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { basename, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'smol-toml'
import { defineLoader } from 'vitepress'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// Set by GitHub Actions; the default serves local runs and forks keep working.
const repository = process.env.GITHUB_REPOSITORY ?? 'NicolasBoulard/netbox-plugin-images'

export interface Plugin {
  plugin: string
  name: string
  homepage: string
  module: string
  netbox: string
  licenses: string
  image?: string
  notes?: string
}

declare const data: Plugin[]
export { data }

interface PluginToml {
  name: string
  module: string
  homepage: string
  netbox: string
  licenses?: Record<string, string>
}

// The image's SPDX expression: every reviewed license, as scripts/plugin.sh computes it.
function licenseExpression(licenses: Record<string, string> = {}): string {
  const parts = new Set(Object.values(licenses).map((l) => (l.includes(' OR ') ? `(${l})` : l)))
  return [...parts].sort().join(' AND ')
}

// Newest release tag <plugin>/<version>, or none outside a git checkout or before the first release.
function latestTag(plugin: string): string | undefined {
  try {
    const options = { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] } as const
    return execFileSync('git', ['tag', '--list', `${plugin}/*`, '--sort=-v:refname'], options)
      .split('\n')[0] || undefined
  } catch {
    return undefined
  }
}

export default defineLoader({
  watch: ['../plugins/*/plugin.toml'],
  load(files: string[]): Plugin[] {
    return files.sort().map((file) => {
      const toml = parse(readFileSync(file, 'utf8')) as unknown as PluginToml
      const plugin = basename(dirname(file))
      const tag = latestTag(plugin)
      return {
        plugin,
        name: toml.name,
        homepage: toml.homepage,
        module: toml.module,
        netbox: toml.netbox.replace(/^v/, '').split('.').slice(0, 2).join('.'),
        licenses: licenseExpression(toml.licenses),
        image: tag && `ghcr.io/${repository.toLowerCase()}/${plugin}:${tag.slice(plugin.length + 1)}`,
        notes: tag && `https://github.com/${repository}/releases/tag/${tag}`,
      }
    })
  },
})
