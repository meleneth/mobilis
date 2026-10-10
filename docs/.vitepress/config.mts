import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Mobilis',
  description: 'Scaffold multi-service projects with Ruby, Docker Compose, and Kubernetes.',
  base: '/mobilis/',
  lastUpdated: true,
  themeConfig: {
    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Examples', link: '/guide/examples' },
      { text: 'Contributing', link: '/contributing' }
    ],
    sidebar: [
      { text: 'Guide', items: [
        { text: 'Getting started', link: '/guide/getting-started' },
        { text: 'Writing a system', link: '/guide/dsl' },
        { text: 'Connection affordances', link: '/guide/connections' },
        { text: 'OpenTelemetry and observability', link: '/guide/observability' },
        { text: 'Shared local gems', link: '/guide/local-gems' },
        { text: 'Generated projects', link: '/guide/generated-projects' },
        { text: 'Example scripts', link: '/guide/examples' },
        { text: 'Kubernetes and Istio', link: '/guide/kubernetes' },
        { text: 'Storage and ownership', link: '/guide/storage' }
      ] },
      { text: 'Development', items: [
        { text: 'Architecture', link: '/architecture' },
        { text: 'Contributing and documentation', link: '/contributing' }
      ] }
    ],
    search: { provider: 'local' },
    socialLinks: [{ icon: 'github', link: 'https://github.com/meleneth/mobilis' }],
    editLink: {
      pattern: 'https://github.com/meleneth/mobilis/edit/core/docs/:path',
      text: 'Edit this page on GitHub'
    }
  }
})
