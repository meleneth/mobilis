import { readdirSync, readFileSync, existsSync } from 'node:fs'
import { join, resolve, relative } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const output = join(root, 'docs/.vitepress/dist')
const site = 'https://meleneth.github.io/mobilis/'
const base = new URL(site).pathname
const errors = []
let checked = 0

function htmlFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const path = join(directory, entry.name)
    return entry.isDirectory() ? htmlFiles(path) : entry.name.endsWith('.html') ? [path] : []
  })
}

if (!existsSync(output)) throw new Error('Build the docs before checking links.')

const pages = new Map(htmlFiles(output).map(path => [path, readFileSync(path, 'utf8')]))

function check(href, source, sourceUrl) {
  const url = new URL(href.replaceAll('&amp;', '&'), sourceUrl)
  if (url.origin !== new URL(site).origin) return
  checked++
  const fail = reason => errors.push(`${source}: ${href} (${reason})`)
  if (!url.pathname.startsWith(base)) return fail('outside the site base path')
  let path = decodeURIComponent(url.pathname.slice(base.length))
  if (!path || path.endsWith('/')) path += 'index.html'
  let target = resolve(output, path)
  if (!existsSync(target) && !path.endsWith('.html')) {
    if (existsSync(`${target}.html`)) {
      // GitHub Pages redirects extensionless routes to their .html page.
      target += '.html'
    } else if (existsSync(join(target, 'index.html'))) {
      target = join(target, 'index.html')
    }
  }
  if (!existsSync(target)) return fail('missing target')
  if (url.hash && pages.has(target)) {
    const fragment = decodeURIComponent(url.hash.slice(1))
    const ids = [...pages.get(target).matchAll(/\bid="([^"]+)"/g)].map(match => match[1])
    if (!ids.includes(fragment)) fail(`missing fragment ${fragment}`)
  }
}

for (const [path, html] of pages) {
  const source = relative(output, path)
  const url = new URL(source, site)
  for (const match of html.matchAll(/\bhref="([^"]+)"/g)) check(match[1], source, url)
}

const readme = readFileSync(join(root, 'README.md'), 'utf8')
for (const match of readme.matchAll(/\]\((https:\/\/meleneth\.github\.io\/[^)]+)\)/g)) {
  check(match[1], 'README.md', site)
}

if (errors.length) {
  console.error(errors.join('\n'))
  process.exitCode = 1
} else {
  console.log(`Checked ${checked} local links across ${pages.size} HTML pages and README.md.`)
}
