/**
 * Generate `src/Generated__Data.res` — the two facts the page needs at build
 * time: the version of rescript-signals it documents, and the recent releases.
 *
 * Releases come from the GitHub Releases API, which is the curated, per-package
 * source: semantic-release publishes one release per package, so filtering to
 * `rescript-signals-v*` gives exactly this package's notes. Deriving them from
 * the repository's own commits instead gets this wrong — the commits between
 * two core tags also contain the React adapter's work, which would then be
 * reported as changes to the core package.
 *
 * Fetching happens at build time rather than in the browser, so the changelog
 * ends up in the prerendered HTML: indexable, instant, and unable to fail in
 * front of a reader. (The previous site fetched at runtime, pointed at a path
 * that does not exist, and rendered GitHub's "404: Not Found" body as if it
 * were the changelog.) Publishing a release redeploys the site — see the
 * `release` trigger in .github/workflows/docs.yml.
 *
 * With no network the script falls back to the CHANGELOG.md inside the
 * installed package and says so loudly. That file is missing several releases,
 * so the fallback is a degraded mode, not an equal alternative. If neither
 * source works the script exits non-zero rather than emitting an empty
 * changelog.
 *
 * Usage: node scripts/gen-data.mjs
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const siteRoot = path.join(__dirname, '..')
const pkgDir = path.join(siteRoot, 'node_modules', 'rescript-signals')
const outFile = path.join(siteRoot, 'src', 'Generated__Data.res')

const OWNER = 'brnrdog'
const REPO_NAME = 'rescript-signals'
const REPO = `https://github.com/${OWNER}/${REPO_NAME}`
const API = `https://api.github.com/repos/${OWNER}/${REPO_NAME}/releases?per_page=30`

/**
 * Releases for this package. `rescript-signals-v*` is the tag scheme since the
 * monorepo split and `v*` the one before it; `rescript-signals-react-v*` is the
 * adapter and matches neither.
 */
const TAG_PREFIX = 'rescript-signals-v'
const LEGACY_TAG = /^v(\d+\.\d+\.\d+.*)$/

const versionOfTag = (tag) => {
  if (tag.startsWith(TAG_PREFIX)) return tag.slice(TAG_PREFIX.length)
  const legacy = tag.match(LEGACY_TAG)
  return legacy ? legacy[1] : null
}

const MAX_RELEASES = 5
const TIMEOUT_MS = 10000

/** Change types a changelog reader cares about. Everything else is bookkeeping. */
const NOTABLE = new Set(['feat', 'fix', 'perf', 'breaking'])

/** semantic-release's section headings, which carry the type for their bullets. */
const HEADING_KINDS = {
  features: 'feat',
  'bug fixes': 'fix',
  'performance improvements': 'perf',
  reverts: 'fix',
  'breaking changes': 'breaking',
}

/* ---------------------------------------------------------------- version */

function readVersion() {
  const pkgPath = path.join(pkgDir, 'package.json')
  if (!fs.existsSync(pkgPath)) {
    fail(`rescript-signals is not installed (${pkgPath} not found). Run npm install first.`)
  }
  return JSON.parse(fs.readFileSync(pkgPath, 'utf8')).version
}

/* --------------------------------------------------------- github releases */

async function releasesFromGitHub() {
  const base = { Accept: 'application/vnd.github+json' }
  // Actions provides a token; it lifts the rate limit from 60/hr to 1000/hr.
  // Releases are public, so a rejected token is not fatal — a stale one in the
  // developer's environment should not be able to break the build.
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN
  const attempts = token
    ? [{ ...base, Authorization: `Bearer ${token}` }, base]
    : [base]

  let payload
  let lastReason = ''

  for (const [index, headers] of attempts.entries()) {
    try {
      const response = await fetch(API, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) })
      if (response.ok) {
        payload = await response.json()
        break
      }
      lastReason = `GitHub API responded ${response.status}`
      if (index === 0 && attempts.length > 1 && (response.status === 401 || response.status === 403)) {
        console.warn('gen-data: the token in this environment was rejected, retrying anonymously.')
        continue
      }
      return { releases: [], reason: lastReason }
    } catch (err) {
      lastReason = `GitHub API unreachable: ${err.message}`
    }
  }

  if (!payload) return { releases: [], reason: lastReason || 'GitHub API unreachable' }

  if (!Array.isArray(payload)) {
    return { releases: [], reason: 'GitHub API returned an unexpected shape' }
  }

  const seen = new Set()
  const releases = payload
    .filter((r) => !r.draft && typeof r.tag_name === 'string' && versionOfTag(r.tag_name))
    .sort((a, b) => (a.published_at < b.published_at ? 1 : -1))
    .filter((r) => {
      // A version released under both tag schemes would otherwise appear twice.
      const version = versionOfTag(r.tag_name)
      if (seen.has(version)) return false
      seen.add(version)
      return true
    })
    .slice(0, MAX_RELEASES)
    .map((r) => ({
      version: versionOfTag(r.tag_name),
      date: (r.published_at || '').slice(0, 10),
      url: r.html_url || `${REPO}/releases/tag/${r.tag_name}`,
      ...parseReleaseNotes(r.body || ''),
    }))

  if (releases.length === 0) return { releases: [], reason: 'no matching releases published' }
  return { releases, reason: null }
}

/* -------------------------------------------------------------- changelog */

/**
 * Degraded fallback, for builds with no network. Handles the heading shapes
 * present in that file:
 *   ## 2.1.0 (2026-04-07)
 *   ## <small>1.3.4 (2026-03-29)</small>
 *   ## [rescript-signals-v3.1.2](…compare…) (2026-08-10)
 * and skips the stray `# Changelog` header sitting partway down, since newer
 * entries are prepended above the original file header.
 */
function releasesFromChangelog() {
  const file = path.join(pkgDir, 'CHANGELOG.md')
  if (!fs.existsSync(file)) return { releases: [], reason: `${file} not found` }

  const lines = fs.readFileSync(file, 'utf8').split('\n')
  const headings = []

  lines.forEach((line, index) => {
    if (!line.startsWith('## ')) return
    const text = line.slice(3).replace(/<\/?small>/g, '').trim()
    const linked = text.match(/^\[[^\]]*?v?(\d+\.\d+\.\d+[^\]]*)\]\([^)]*\)\s*\(([\d-]+)\)/)
    const plain = text.match(/^v?(\d+\.\d+\.\d+\S*)\s*\(([\d-]+)\)/)
    const match = linked || plain
    if (match) headings.push({ version: match[1], date: match[2], index })
  })

  if (headings.length === 0) return { releases: [], reason: `no releases parsed from ${file}` }

  const seen = new Set()
  const releases = []

  for (let i = 0; i < headings.length && releases.length < MAX_RELEASES; i++) {
    const { version, date, index } = headings[i]
    if (seen.has(version)) continue
    seen.add(version)

    // Newer entries are prepended above the file's own `# Changelog` header, so
    // a section can run into it. Stop there — the boilerplate paragraph that
    // follows it belongs to the file, not to this release.
    let body = lines.slice(index + 1, end)
    const fileHeader = body.findIndex((line) => /^#\s/.test(line))
    if (fileHeader !== -1) body = body.slice(0, fileHeader)
    const section = body.join('\n')

    releases.push({
      version,
      date,
      url: `${REPO}/releases/tag/${TAG_PREFIX}${version}`,
      ...parseReleaseNotes(section),
    })
  }

  return { releases, reason: null }
}

/* ---------------------------------------------------------------- parsing */

function splitConventional(subject) {
  const match = subject.match(/^(\w+)(?:\([^)]*\))?(!)?:\s*(.+)$/)
  if (!match) return { kind: '', title: stripMarkdown(subject), breaking: false }
  return { kind: match[1].toLowerCase(), title: stripMarkdown(match[3]), breaking: match[2] === '!' }
}

/**
 * Release notes → { breaking, changes, notes }.
 *
 * Both sources are the same markdown, so one parser serves both. Bullets become
 * the change list; loose prose and fenced code become the notes underneath.
 * Older entries prefix each bullet with its type ("fix: …"); newer ones drop the
 * prefix and group bullets under a "### Bug Fixes" heading, so the heading has
 * to supply the type.
 */
function parseReleaseNotes(markdown) {
  const lines = markdown.split('\n')
  const changes = []
  const noteLines = []
  let heading = ''
  let breaking = false

  for (const raw of lines) {
    const line = raw.replace(/\r$/, '')

    // The version header the notes open with is already shown as the heading.
    if (/^##\s/.test(line)) {
      const text = line.replace(/^#+\s*/, '').toLowerCase()
      if (/breaking/.test(text)) {
        breaking = true
        heading = 'breaking'
      } else {
        heading = ''
      }
      continue
    }

    const sub = line.match(/^###\s+(.*)$/)
    if (sub) {
      const text = sub[1].replace(/[^\w\s]/g, '').trim().toLowerCase()
      heading = HEADING_KINDS[text] || ''
      if (heading === 'breaking') breaking = true
      continue
    }

    const bullet = line.match(/^\s*[*-]\s+(.*)$/)
    if (bullet) {
      const text = stripMarkdown(bullet[1])
      if (!text) continue
      const parsed = splitConventional(text)
      const kind = parsed.kind || heading
      const isBreaking = parsed.breaking || heading === 'breaking'
      if (isBreaking) breaking = true
      changes.push({
        kind: kind === 'breaking' || (isBreaking && !NOTABLE.has(kind)) ? 'breaking' : kind,
        summary: parsed.title,
        breaking: isBreaking,
      })
      continue
    }

    noteLines.push(line)
  }

  return {
    breaking,
    changes: changes.filter((c) => c.kind && NOTABLE.has(c.kind) && c.summary),
    notes: parseBlocks(noteLines),
  }
}

/**
 * Prose lines → blocks. Paragraphs have their soft line wrapping joined back
 * up, and fenced code is kept verbatim.
 */
function parseBlocks(lines) {
  const blocks = []
  let paragraph = []

  const flush = () => {
    if (paragraph.length > 0) blocks.push({ tag: 'Paragraph', text: paragraph.join(' ') })
    paragraph = []
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    if (line.trimStart().startsWith('```')) {
      flush()
      const code = []
      i++
      while (i < lines.length && !lines[i].trimStart().startsWith('```')) code.push(lines[i++])
      const text = code.join('\n').trim()
      if (text) blocks.push({ tag: 'Code', text })
      continue
    }

    if (line.trim() === '') {
      flush()
      continue
    }

    paragraph.push(stripMarkdown(line.trim()))
  }

  flush()
  return blocks.filter((b) => (b.text || '').trim() !== '')
}

/**
 * Release notes are read as plain text, never as markup — the page renders them
 * as text nodes, so anything left here would show up literally. Links are
 * reduced to their label, and the commit-hash and "closes #n" trails that
 * semantic-release appends are dropped as noise.
 */
function stripMarkdown(text) {
  return text
    .replace(/,?\s*closes\s+(\[[^\]]*\]\([^)]*\)\s*)+$/i, '')
    .replace(/\s*\(\[[0-9a-f]{6,}\]\([^)]*\)\)\s*$/i, '')
    .replace(/\s*\(#\d+\)\s*$/, '')
    .replace(/^#{1,6}\s+/, '')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/\*\*([^*]*)\*\*/g, '$1')
    .replace(/\s+/g, ' ')
    .trim()
}

/* ----------------------------------------------------------- emit ReScript */

/**
 * ReScript string literal. Escapes the syntax characters and everything outside
 * printable ASCII, so the generated file is pure ASCII regardless of what a
 * release note contains.
 */
function res(value) {
  let out = '"'
  for (const char of String(value)) {
    const code = char.codePointAt(0)
    if (char === '\\') out += '\\\\'
    else if (char === '"') out += '\\"'
    else if (char === '\n') out += '\\n'
    else if (char === '\t') out += '\\t'
    else if (char === '\r') continue
    else if (code >= 0x20 && code <= 0x7e) out += char
    else out += `\\u{${code.toString(16)}}`
  }
  return out + '"'
}

function resBlock(block) {
  return block.tag === 'Code' ? `Code(${res(block.text)})` : `Paragraph(${res(block.text)})`
}

function resChange(change) {
  return `{kind: ${res(change.kind)}, summary: ${res(change.summary)}, breaking: ${
    change.breaking ? 'true' : 'false'
  }}`
}

function resRelease(release) {
  const changes = release.changes.map((c) => `      ${resChange(c)},`).join('\n')
  const notes = release.notes.map((n) => `      ${resBlock(n)},`).join('\n')
  return [
    '  {',
    `    version: ${res(release.version)},`,
    `    date: ${res(release.date)},`,
    `    url: ${res(release.url)},`,
    `    breaking: ${release.breaking ? 'true' : 'false'},`,
    release.changes.length > 0 ? `    changes: [\n${changes}\n    ],` : '    changes: [],',
    release.notes.length > 0 ? `    notes: [\n${notes}\n    ],` : '    notes: [],',
    '  },',
  ].join('\n')
}

function emit(version, releases, source) {
  return `// Generated by scripts/gen-data.mjs — do not edit.
// Source: ${source}

type block =
  | Paragraph(string)
  | Code(string)

type change = {
  kind: string,
  summary: string,
  breaking: bool,
}

type release = {
  version: string,
  date: string,
  url: string,
  breaking: bool,
  changes: array<change>,
  notes: array<block>,
}

let version = ${res(version)}

let repositoryUrl = ${res(REPO)}

let releases: array<release> = [
${releases.map(resRelease).join('\n')}
]
`
}

function fail(message) {
  console.error(`gen-data: ${message}`)
  process.exit(1)
}

/* ------------------------------------------------------------------- main */

const version = readVersion()

let source = 'GitHub Releases'
let { releases, reason } = await releasesFromGitHub()

if (releases.length === 0) {
  console.warn(`gen-data: falling back to the packaged CHANGELOG.md — ${reason}.`)
  console.warn('gen-data: that file is missing releases, so the changelog will be incomplete.')
  source = 'packaged CHANGELOG.md (degraded, some releases missing)'
  const fallback = releasesFromChangelog()
  releases = fallback.releases
  if (releases.length === 0) fail(`no releases from GitHub or CHANGELOG.md (${fallback.reason})`)
}

fs.writeFileSync(outFile, emit(version, releases, source))
console.log(
  `gen-data: v${version}, ${releases.length} releases from ${source} → ${path.relative(
    siteRoot,
    outFile,
  )}`,
)
