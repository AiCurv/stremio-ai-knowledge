# Stremio AI Knowledge Base

> AI Agent Knowledge Base for Stremio Addon Development

A comprehensive, machine-readable knowledge base that enables AI agents (and humans) to build production-ready Stremio addons quickly and correctly.

## What Is This?

This repository contains everything needed to build a Stremio addon from scratch:

- **Templates** — Complete, copy-paste-ready code for every component
- **Error Database** — Known errors with proven fixes, so you don't repeat mistakes
- **Site Patterns** — Documented site structures for quick scraping
- **Stream Fix Discovery** — How User-Agent redirects enable native MP4 playback in Stremio
- **Workflow Guide** — Step-by-step process for building any addon
- **AI Prompt** — Ready-made prompt template for AI agent interactions

## Quick Start

### For AI Agents

1. Read `agent-index.json` for the quick-reference overview
2. Use the prompt template in `AI_AGENT_PROMPT.md` to start building
3. Follow `AGENT_GUIDE.md` for the step-by-step workflow

### For Humans

1. Read this README for the big picture
2. Follow `AGENT_GUIDE.md` as a tutorial
3. Use `KNOWLEDGE_BASE.md` as a reference for templates
4. Check `ERRORS_DB.md` when you hit problems
5. Check `SITE_PATTERNS.md` for site-specific patterns

## Repository Structure

```
stremio-ai-knowledge/
├── agent-index.json      # Machine-readable quick reference (JSON)
├── KNOWLEDGE_BASE.md     # Complete templates and patterns
├── ERRORS_DB.md          # Error database with proven fixes
├── SITE_PATTERNS.md      # Documented site structures
├── AGENT_GUIDE.md        # Step-by-step workflow guide
├── AI_AGENT_PROMPT.md    # Prompt template for AI agents
├── README.md             # This file
└── update.sh             # Auto-update script
```

## File Descriptions

### `agent-index.json`

Machine-readable quick reference containing:
- Critical version requirements (Node.js, SDK, dependencies)
- Stremio protocol routes
- Content type definitions (channel, movie, series, tv)
- Video source type reference (MP4, M3U8, torrent)
- App limitations and workarounds

**Use this when:** You need a quick lookup for API formats, version numbers, or stream object structures.

### `KNOWLEDGE_BASE.md`

Complete, production-ready templates for:
- `manifest.json` format with all fields explained
- `addon.js` using `stremio-addon-sdk` with catalog, meta, and stream handlers
- `api/index.js` Vercel serverless entry point with CORS
- `vercel.json` with rewrites and function configuration
- `package.json` with correct dependency versions
- Handler patterns: Catalog (searchable + browse), Meta (channel + movie), Stream (MP4/M3U8)
- **Stream Fix (v2.0.0):** How User-Agent redirects enable native MP4 playback

**Use this when:** You're building an addon and need a template to start from.

### `ERRORS_DB.md`

Living database of errors encountered during addon development:
- KVS video page 404 without slug → use embed URL
- Vercel serverless timeout → cache and optimize
- KVS slug requirement → use embed URLs or store full URLs
- **KVS /get_stream/ User-Agent redirect** → use direct `stream.url`, NEVER `externalUrl`

**Use this when:** You encounter an error and want to check if it's a known issue.

### `SITE_PATTERNS.md`

Documented site structures and scraping patterns:
- URL patterns for models, videos, search, categories
- Video source extraction methods with code samples
- Platform-specific gotchas and token handling
- Platform detection guide
- **ThePornBang:** User-Agent redirect gateway for direct MP4 playback

**Use this when:** You're building an addon for a site that's already documented, or need to identify a new site's platform.

### `AGENT_GUIDE.md`

7-step workflow for building Stremio addons:
1. Check for Cloudflare
2. Identify site platform
3. Map site structure
4. Find video source extraction method
5. Build addon using templates
6. Deploy to Vercel
7. Update knowledge base

**Use this when:** You're starting a new addon from scratch and need a systematic approach.

### `AI_AGENT_PROMPT.md`

Universal prompt template for AI agents:
- Fill-in-the-blank format for any site
- Example filled-in prompts for w1mp.com and thepornbang.com
- Prompt engineering tips for best results

**Use this when:** You want to ask an AI agent to build an addon for you.

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Runtime | Node.js | >=16 |
| Addon SDK | stremio-addon-sdk | ^1.6.10 |
| HTML Parser | cheerio | ^1.0.0 |
| HTTP Client | node-fetch | ^2.7.0 |
| Hosting | Vercel | Serverless Functions |
| Protocol | Stremio Addon Protocol | v3 |

## Stremio Addon Protocol Overview

Stremio addons implement a simple HTTP-based protocol with four core endpoints:

| Endpoint | Purpose | Returns |
|----------|---------|---------|
| `/manifest.json` | Addon identity and capabilities | Manifest object |
| `/catalog/{type}/{id}.json` | List of content items | `{ metas: [...] }` |
| `/meta/{type}/{id}.json` | Detailed info about one item | `{ meta: {...} }` |
| `/stream/{type}/{id}.json` | Playable video URLs | `{ streams: [...] }` |

### Content Types

- **channel** — Multi-video containers (models, collections, performers). Meta handler returns a `videos` array.
- **movie** — Single standalone video. One meta entry maps to one stream.
- **series** — Episodic content with seasons and episodes.
- **tv** — Live TV channels.

### Video Source Types

- **MP4** — Direct video URL. Return as `stream.url` with `notWebReady: false`.
- **M3U8** — HLS playlist URL. Return as `stream.url` with `notWebReady: true`.
- **torrent** — BitTorrent info hash. Return as `stream.infoHash` with optional `sources` array.

> ⚠️ **NEVER use `externalUrl` for video streams.** It opens a browser/webview which users hate. Always extract the direct video URL (MP4 or M3U8). If a URL triggers a download in your browser, test it with Stremio's User-Agent — it may redirect to a CDN for native playback. See the Stream Fix section in `KNOWLEDGE_BASE.md`.
>
> The ONLY acceptable use of `externalUrl` is for **cross-navigation within Stremio** using `stremio:///detail/` deep links.

## Key Limitations

1. **Library is manual** — Users must click "Add to Library". Addons cannot add items programmatically.
2. **Search is string-only** — Plain text matching, no filters or faceted search.
3. **Caching is app-side** — Stremio controls cache TTL. Addons cannot set cache headers directly.
4. **Vercel Hobby timeout** — 10-second limit on serverless functions. Keep handlers fast.

## Contributing

1. Add new site patterns to `SITE_PATTERNS.md`
2. Add new errors to `ERRORS_DB.md`
3. Update templates in `KNOWLEDGE_BASE.md` if you find better patterns
4. Update `agent-index.json` version and date
5. Run `./update.sh` to timestamp the changes
6. Commit and push

## License

MIT

---

*Built by [AiCurv](https://github.com/AiCurv) — Last updated: 2026-06-07*
