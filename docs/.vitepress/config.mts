import { defineConfig } from 'vitepress'

const repo = 'https://github.com/NicolasBoulard/netbox-plugin-images'

export default defineConfig({
  title: 'NetBox Plugin Images',
  description: 'NetBox plugins as OCI images, mounted into the official NetBox image with Kubernetes image volumes.',
  // Served from https://nicolasboulard.github.io/netbox-plugin-images/
  base: '/netbox-plugin-images/',
  cleanUrls: true,
  lastUpdated: true,
  head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/netbox-plugin-images/favicon.svg' }]],
  themeConfig: {
    logo: '/favicon.svg',
    nav: [
      { text: 'Guide', link: '/usage' },
      { text: 'Catalog', link: '/catalog' },
    ],
    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'How it works', link: '/how-it-works' },
          { text: 'Usage', link: '/usage' },
          { text: 'Tags and versions', link: '/versions' },
        ],
      },
      { text: 'Catalog', link: '/catalog' },
    ],
    socialLinks: [{ icon: 'github', link: repo }],
    search: { provider: 'local' },
    editLink: { pattern: `${repo}/edit/main/docs/:path` },
    footer: {
      message: 'Repository code under Apache-2.0; each plugin keeps its own license. '
        + 'NetBox is a trademark of NetBox Labs, Inc.; this project is not affiliated with NetBox Labs or the plugins\' authors.',
    },
  },
})
