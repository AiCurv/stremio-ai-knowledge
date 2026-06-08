# Stremio Addon Knowledge Base

Complete templates and patterns for building Stremio addons. Every code block is production-ready and can be used directly.

---

## Table of Contents

1. [manifest.json Format](#1-manifestjson-format)
2. [addon.js Template](#2-addonjs-template-using-stremio-addon-sdk)
3. [api/index.js Vercel Serverless Entry](#3-apiindexjs-vercel-serverless-entry)
4. [vercel.json Rewrites](#4verceljson-rewrites)
5. [package.json Dependencies](#5packagejson-dependencies)
6. [Catalog Handler Pattern](#6-catalog-handler-pattern)
7. [Meta Handler Pattern](#7-meta-handler-pattern)
8. [Stream Handler Pattern](#8-stream-handler-pattern)
9. [Stream Fix: Direct MP4 Playback via User-Agent Redirect (v2.0.0)](#9-stream-fix-direct-mp4-playback-via-user-agent-redirect-v200)
10. [Meta `links` Field — Clickable Cross-Navigation](#10-meta-links-field--clickable-cross-navigation)
11. [Multi-Prefix ID Strategy for Channel Types](#11-multi-prefix-id-strategy-for-channel-types)
12. [Clickable Navigation Streams — Tags & Models as Clickable Channel Links (v3.0.0)](#12-clickable-navigation-streams--tags--models-as-clickable-channel-links-v300)
13. [CRITICAL: DOM Scraping Pitfall — Related Section Pollution (v3.1.0)](#13-critical-dom-scraping-pitfall--related-section-pollution-v310)

---

## 1. manifest.json Format

The manifest declares your addon's identity, supported content types, catalogs, and resources.

```json
{
  "id": "community.my-addon",
  "version": "1.0.0",
  "name": "My Stremio Addon",
  "description": "Description of what this addon provides",
  "logo": "https://example.com/logo.png",
  "background": "https://example.com/background.png",
  "resources": ["catalog", "meta", "stream"],
  "types": ["channel", "movie"],
  "idPrefixes": ["myaddon_"],
  "catalogs": [
    {
      "type": "channel",
      "id": "models",
      "name": "Models",
      "extra": [
        {
          "name": "search",
          "isRequired": false
        },
        {
          "name": "genre",
          "isRequired": false,
          "options": ["Category A", "Category B", "Category C"]
        },
        {
          "name": "skip",
          "isRequired": false
        }
      ]
    },
    {
      "type": "movie",
      "id": "videos",
      "name": "Videos",
      "extra": [
        {
          "name": "search",
          "isRequired": false
        },
        {
          "name": "skip",
          "isRequired": false
        }
      ]
    }
  ],
  "behaviorHints": {
    "configurable": false,
    "configurationRequired": false
  }
}
```

### Key Fields Explained

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique addon identifier. Must start with `community.` for public addons. |
| `version` | Yes | Semantic version (semver). |
| `name` | Yes | Human-readable addon name shown in Stremio. |
| `resources` | Yes | Which handlers your addon implements: `catalog`, `meta`, `stream`. |
| `types` | Yes | Content types supported: `movie`, `series`, `channel`, `tv`. |
| `idPrefixes` | Recommended | Prefix for your meta IDs. Prevents collisions with other addons. |
| `catalogs` | Yes (if catalog resource) | Array of catalog definitions with extra parameters. |
| `behaviorHints` | No | Controls addon behavior in the app. |

---

## 2. addon.js Template Using stremio-addon-sdk

```javascript
const { addonBuilder } = require('stremio-addon-sdk');
const cheerio = require('cheerio');
const fetch = require('node-fetch');

// ─── Configuration ───────────────────────────────────────────────────
const SITE_BASE = 'https://example.com';
const ADDON_ID = 'community.my-addon';
const ID_PREFIX = 'myaddon_';

// ─── Helper Functions ────────────────────────────────────────────────

/**
 * Fetch a page with proper headers and error handling
 */
async function fetchPage(url) {
    const response = await fetch(url, {
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
        },
        timeout: 10000,
    });
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} for ${url}`);
    }
    return await response.text();
}

/**
 * Parse HTML with cheerio
 */
function parseHTML(html) {
    return cheerio.load(html);
}

/**
 * Build a meta ID from a slug or identifier
 */
function buildId(slug) {
    return `${ID_PREFIX}${slug}`;
}

/**
 * Extract slug from a meta ID
 */
function extractSlug(id) {
    return id.replace(ID_PREFIX, '');
}

// ─── Manifest ────────────────────────────────────────────────────────

const manifest = {
    id: ADDON_ID,
    version: '1.0.0',
    name: 'My Stremio Addon',
    description: 'Description of what this addon provides',
    logo: `${SITE_BASE}/favicon.ico`,
    resources: ['catalog', 'meta', 'stream'],
    types: ['channel', 'movie'],
    idPrefixes: [ID_PREFIX],
    catalogs: [
        {
            type: 'channel',
            id: 'models',
            name: 'Models',
            extra: [
                { name: 'search', isRequired: false },
                { name: 'skip', isRequired: false },
            ],
        },
        {
            type: 'movie',
            id: 'videos',
            name: 'Videos',
            extra: [
                { name: 'search', isRequired: false },
                { name: 'skip', isRequired: false },
            ],
        },
    ],
    behaviorHints: {
        configurable: false,
        configurationRequired: false,
    },
};

const builder = new addonBuilder(manifest);

// ─── Catalog Handler ─────────────────────────────────────────────────

builder.defineCatalogHandler(async ({ type, id, extra }) => {
    const search = extra.search || '';
    const skip = parseInt(extra.skip || '0', 10);
    const page = Math.floor(skip / 20) + 1;

    let results = [];

    try {
        if (search) {
            // Search mode
            const url = `${SITE_BASE}/search/?q=${encodeURIComponent(search)}`;
            const html = await fetchPage(url);
            const $ = parseHTML(html);
            results = parseSearchResults($, type);
        } else {
            // Browse mode
            if (type === 'channel' && id === 'models') {
                const url = `${SITE_BASE}/models/${page > 1 ? page + '/' : ''}`;
                const html = await fetchPage(url);
                const $ = parseHTML(html);
                results = parseModelList($);
            } else if (type === 'movie' && id === 'videos') {
                const url = `${SITE_BASE}/videos/${page > 1 ? page + '/' : ''}`;
                const html = await fetchPage(url);
                const $ = parseHTML(html);
                results = parseVideoList($);
            }
        }
    } catch (err) {
        console.error('Catalog handler error:', err.message);
    }

    return { metas: results };
});

/**
 * Parse search results into meta objects
 */
function parseSearchResults($, type) {
    const metas = [];
    $('.search-result-item').each((i, el) => {
        const elem = $(el);
        const slug = elem.find('a').attr('href')?.split('/').filter(Boolean).pop() || '';
        const name = elem.find('.title').text().trim();
        const poster = elem.find('img').attr('src') || '';
        if (slug && name) {
            metas.push({
                id: buildId(slug),
                type: type,
                name: name,
                poster: poster.startsWith('http') ? poster : `${SITE_BASE}${poster}`,
            });
        }
    });
    return metas;
}

/**
 * Parse model list page into channel meta objects
 */
function parseModelList($) {
    const metas = [];
    $('.model-item').each((i, el) => {
        const elem = $(el);
        const slug = elem.find('a').attr('href')?.match(/\/models\/([^/]+)/)?.[1] || '';
        const name = elem.find('.model-name').text().trim();
        const poster = elem.find('img').attr('src') || '';
        if (slug && name) {
            metas.push({
                id: buildId(slug),
                type: 'channel',
                name: name,
                poster: poster.startsWith('http') ? poster : `${SITE_BASE}${poster}`,
            });
        }
    });
    return metas;
}

/**
 * Parse video list page into movie meta objects
 */
function parseVideoList($) {
    const metas = [];
    $('.video-item').each((i, el) => {
        const elem = $(el);
        const slug = elem.find('a').attr('href')?.match(/\/video\/(\d+)/)?.[1] || '';
        const name = elem.find('.video-title').text().trim();
        const poster = elem.find('img').attr('src') || '';
        if (slug && name) {
            metas.push({
                id: buildId(slug),
                type: 'movie',
                name: name,
                poster: poster.startsWith('http') ? poster : `${SITE_BASE}${poster}`,
            });
        }
    });
    return metas;
}

// ─── Meta Handler ────────────────────────────────────────────────────

builder.defineMetaHandler(async ({ type, id }) => {
    const slug = extractSlug(id);

    try {
        if (type === 'channel') {
            return await handleChannelMeta(slug);
        } else if (type === 'movie') {
            return await handleMovieMeta(slug);
        }
    } catch (err) {
        console.error('Meta handler error:', err.message);
    }

    return { meta: null };
});

/**
 * Handle channel (model) meta with videos array
 */
async function handleChannelMeta(slug) {
    const url = `${SITE_BASE}/models/${slug}/`;
    const html = await fetchPage(url);
    const $ = parseHTML(html);

    const name = $('.model-name').text().trim();
    const poster = $('.model-poster img').attr('src') || '';
    const background = $('.model-background').attr('src') || poster;
    const description = $('.model-bio').text().trim();

    // Build videos array (episodes under the channel)
    const videos = [];
    $('.video-item').each((i, el) => {
        const elem = $(el);
        const videoId = elem.find('a').attr('href')?.match(/\/video\/(\d+)/)?.[1] || '';
        const videoTitle = elem.find('.video-title').text().trim();
        const videoThumb = elem.find('img').attr('src') || '';
        if (videoId && videoTitle) {
            videos.push({
                id: buildId(videoId),
                title: videoTitle,
                thumbnail: videoThumb.startsWith('http') ? videoThumb : `${SITE_BASE}${videoThumb}`,
                released: new Date().toISOString(),
                overview: '',
            });
        }
    });

    return {
        meta: {
            id: buildId(slug),
            type: 'channel',
            name: name || slug,
            poster: poster.startsWith('http') ? poster : `${SITE_BASE}${poster}`,
            background: background.startsWith('http') ? background : `${SITE_BASE}${background}`,
            description: description,
            videos: videos,
        },
    };
}

/**
 * Handle movie (single video) meta
 */
async function handleMovieMeta(slug) {
    const url = `${SITE_BASE}/video/${slug}/some-slug/`;
    const html = await fetchPage(url);
    const $ = parseHTML(html);

    const name = $('.video-title').text().trim();
    const poster = $('meta[property="og:image"]').attr('content') || '';
    const background = poster;
    const description = $('.video-description').text().trim();

    return {
        meta: {
            id: buildId(slug),
            type: 'movie',
            name: name || slug,
            poster: poster,
            background: background,
            description: description,
            releaseInfo: new Date().getFullYear().toString(),
        },
    };
}

// ─── Stream Handler ──────────────────────────────────────────────────

builder.defineStreamHandler(async ({ type, id }) => {
    const slug = extractSlug(id);

    try {
        // For channels, streams are requested per video
        if (type === 'channel') {
            return await handleVideoStream(slug);
        } else if (type === 'movie') {
            return await handleVideoStream(slug);
        }
    } catch (err) {
        console.error('Stream handler error:', err.message);
    }

    return { streams: [] };
});

/**
 * Extract video stream from embed page
 */
async function handleVideoStream(videoId) {
    const embedUrl = `${SITE_BASE}/embed/${videoId}/`;
    const html = await fetchPage(embedUrl);
    const $ = parseHTML(html);

    const streams = [];

    // Method 1: Direct MP4 from <video><source> tag
    const mp4Url = $('video source').attr('src');
    if (mp4Url) {
        streams.push({
            url: mp4Url.startsWith('http') ? mp4Url : `${SITE_BASE}${mp4Url}`,
            title: 'Direct MP4',
            behaviorHints: {
                notWebReady: false,
            },
        });
    }

    // Method 2: M3U8 from HLS source
    const m3u8Url = $('video source[type="application/x-mpegURL"]').attr('src');
    if (m3u8Url) {
        streams.push({
            url: m3u8Url.startsWith('http') ? m3u8Url : `${SITE_BASE}${m3u8Url}`,
            title: 'HLS Stream',
            behaviorHints: {
                notWebReady: true,
            },
        });
    }

    // Method 3: JavaScript variable extraction (common in KVS)
    if (streams.length === 0) {
        const scriptContent = $('script').text();
        const videoUrlMatch = scriptContent.match(/(?:video_url|video_alt_url[0-9]?)\s*[:=]\s*["']([^"']+)["']/);
        if (videoUrlMatch) {
            streams.push({
                url: videoUrlMatch[1],
                title: 'Extracted MP4',
                behaviorHints: { notWebReady: false },
            });
        }
    }

    // ⚠️ NEVER use externalUrl for video streams — it opens a TV browser/webview
    // If no direct URL can be extracted, return empty streams and log the error

    if (streams.length === 0) {
        console.error(`No direct stream found for ${videoId}`);
    }

    return { streams };
}

// ─── Export ──────────────────────────────────────────────────────────

module.exports = builder.getInterface();
```

---

## 3. api/index.js Vercel Serverless Entry

```javascript
const addon = require('../addon');

module.exports = async (req, res) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
        res.setHeader('Access-Control-Max-Age', '86400');
        res.status(204).end();
        return;
    }

    // Set CORS headers for all responses
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    // Route the request to the addon SDK router
    const url = new URL(req.url, `https://${req.headers.host || 'localhost'}`);
    const path = url.pathname;

    try {
        const { headers, body, statusCode } = await addon.router({
            path: path,
            query: Object.fromEntries(url.searchParams),
            method: req.method,
        });

        if (headers) {
            Object.entries(headers).forEach(([key, value]) => {
                res.setHeader(key, value);
            });
        }

        res.status(statusCode || 200).send(body);
    } catch (err) {
        console.error('Serverless handler error:', err);
        res.status(500).json({ error: 'Internal server error' });
    }
};
```

---

## 4. vercel.json Rewrites

```json
{
  "version": 2,
  "rewrites": [
    { "source": "/manifest.json", "destination": "/api/index" },
    { "source": "/catalog/(.*)", "destination": "/api/index" },
    { "source": "/meta/(.*)", "destination": "/api/index" },
    { "source": "/stream/(.*)", "destination": "/api/index" }
  ],
  "functions": {
    "api/index.js": {
      "memory": 1024,
      "maxDuration": 10
    }
  }
}
```

### Important Notes

- All Stremio protocol routes are rewritten to the single serverless function.
- `maxDuration: 10` is the maximum for Vercel Hobby plan. Upgrade to Pro for 60s.
- `memory: 1024` gives the function more headroom for parsing HTML.

---

## 5. package.json Dependencies

```json
{
  "name": "my-stremio-addon",
  "version": "1.0.0",
  "description": "Stremio addon",
  "main": "addon.js",
  "scripts": {
    "start": "node addon.js",
    "dev": "node addon.js --local",
    "vercel-dev": "vercel dev"
  },
  "dependencies": {
    "stremio-addon-sdk": "^1.6.10",
    "cheerio": "^1.0.0",
    "node-fetch": "^2.7.0"
  },
  "engines": {
    "node": ">=16"
  }
}
```

### Dependency Notes

| Package | Version | Purpose |
|---------|---------|---------|
| `stremio-addon-sdk` | ^1.6.10 | Core SDK for building addons with `addonBuilder`, routing, and serving. |
| `cheerio` | ^1.0.0 | Fast, lean HTML parser. jQuery-like API for scraping. v1.0 is a major rewrite — do NOT use ^0.x. |
| `node-fetch` | ^2.7.0 | HTTP client. **Must use v2.x** (CommonJS). v3.x is ESM-only and will break `require()`. |

---

## 6. Catalog Handler Pattern

The catalog handler returns lists of meta objects. It supports both **browsing** and **searching**.

### Searchable + Browse Pattern

```javascript
builder.defineCatalogHandler(async ({ type, id, extra }) => {
    const search = extra.search || '';
    const skip = parseInt(extra.skip || '0', 10);
    const PAGE_SIZE = 20;
    const page = Math.floor(skip / PAGE_SIZE) + 1;

    let results = [];

    try {
        if (search) {
            // ─── Search Mode ──────────────────────────────────
            const searchUrl = `${SITE_BASE}/search/?q=${encodeURIComponent(search)}`;
            const html = await fetchPage(searchUrl);
            const $ = parseHTML(html);
            results = parseSearchResults($, type);
        } else {
            // ─── Browse Mode ──────────────────────────────────
            let browseUrl;
            if (type === 'channel' && id === 'models') {
                browseUrl = page > 1
                    ? `${SITE_BASE}/models/${page}/`
                    : `${SITE_BASE}/models/`;
            } else if (type === 'movie' && id === 'videos') {
                browseUrl = page > 1
                    ? `${SITE_BASE}/videos/${page}/`
                    : `${SITE_BASE}/videos/`;
            }

            if (browseUrl) {
                const html = await fetchPage(browseUrl);
                const $ = parseHTML(html);
                results = parseResults($, type, id);
            }
        }
    } catch (err) {
        console.error(`Catalog error [type=${type}, id=${id}]:`, err.message);
    }

    return { metas: results };
});
```

### Meta Object Format for Catalogs

```javascript
// Minimal catalog meta (what you MUST return)
{
    id: 'myaddon_model-slug',    // Unique ID with prefix
    type: 'channel',              // Must match catalog type
    name: 'Model Name',           // Display name
}

// Recommended catalog meta (better UX)
{
    id: 'myaddon_model-slug',
    type: 'channel',
    name: 'Model Name',
    poster: 'https://example.com/poster.jpg',   // Thumbnail image
    description: 'Short description',
}
```

### Pagination Behavior

- Stremio automatically requests more pages by increasing `skip` by 20.
- Your handler must return fewer than 20 results to signal the end of the list.
- Do NOT return empty results for page 1 — the catalog will appear empty.

---

## 7. Meta Handler Pattern

The meta handler returns detailed information about a single item.

### Channel Type with Videos Array

For models/collections that contain multiple videos, use the `channel` type with a `videos` array.

```javascript
builder.defineMetaHandler(async ({ type, id }) => {
    const slug = extractSlug(id);

    if (type === 'channel') {
        const url = `${SITE_BASE}/models/${slug}/`;
        const html = await fetchPage(url);
        const $ = parseHTML(html);

        const name = $('.model-name').text().trim();
        const poster = $('.model-avatar img').attr('src') || '';
        const background = $('.model-cover').attr('src') || poster;
        const description = $('.model-bio').text().trim();

        const videos = [];
        $('.video-item').each((i, el) => {
            const elem = $(el);
            const videoId = elem.find('a').attr('href')?.match(/\/video\/(\d+)/)?.[1];
            const videoTitle = elem.find('.title').text().trim();
            const videoThumb = elem.find('img').attr('src') || '';
            const duration = elem.find('.duration').text().trim();

            if (videoId && videoTitle) {
                videos.push({
                    id: buildId(videoId),
                    title: videoTitle,
                    thumbnail: videoThumb.startsWith('http') ? videoThumb : `${SITE_BASE}${videoThumb}`,
                    released: new Date().toISOString(),
                    duration: duration,
                    overview: '',
                });
            }
        });

        return {
            meta: {
                id: buildId(slug),
                type: 'channel',
                name: name || slug,
                poster: poster.startsWith('http') ? poster : `${SITE_BASE}${poster}`,
                background: background.startsWith('http') ? background : `${SITE_BASE}${background}`,
                description: description,
                videos: videos,
            },
        };
    }

    return { meta: null };
});
```

### Movie Type (Single Video)

```javascript
if (type === 'movie') {
    const url = `${SITE_BASE}/video/${slug}/some-slug/`;
    const html = await fetchPage(url);
    const $ = parseHTML(html);

    const name = $('meta[property="og:title"]').attr('content') || '';
    const poster = $('meta[property="og:image"]').attr('content') || '';
    const description = $('meta[property="og:description"]').attr('content') || '';
    const releaseInfo = $('.upload-date').text().trim();

    return {
        meta: {
            id: buildId(slug),
            type: 'movie',
            name: name || slug,
            poster: poster,
            background: poster,
            description: description,
            releaseInfo: releaseInfo,
        },
    };
}
```

### Critical Meta Handler Rules

1. **The `id` in the returned meta MUST match the `id` that was requested.** If they don't match, Stremio will show nothing.
2. **For channels, the `videos` array is required.** Each video's `id` will later be passed to the stream handler.
3. **Always return an object with a `meta` property**, not the meta object directly: `return { meta: {...} }`.
4. **Poster/background URLs must be absolute.** Relative URLs will not load in Stremio.

---

## 8. Stream Handler Pattern

The stream handler returns playable video URLs for a given meta ID.

### MP4 Direct Stream

```javascript
builder.defineStreamHandler(async ({ type, id }) => {
    const slug = extractSlug(id);
    const streams = [];

    const embedUrl = `${SITE_BASE}/embed/${slug}/`;
    const html = await fetchPage(embedUrl);
    const $ = parseHTML(html);

    const videoSrc = $('video source').attr('src')
        || $('video').attr('src');

    if (videoSrc) {
        const mp4Url = videoSrc.startsWith('http')
            ? videoSrc
            : `${SITE_BASE}${videoSrc}`;

        streams.push({
            url: mp4Url,
            title: 'Direct MP4',
            behaviorHints: {
                notWebReady: false,
            },
        });
    }

    return { streams };
});
```

### M3U8 HLS Stream

```javascript
// M3U8 streams MUST set notWebReady: true
streams.push({
    url: 'https://example.com/stream.m3u8',
    title: 'HLS Stream',
    behaviorHints: {
        notWebReady: true,  // Required for HLS
    },
});
```

### ⚠️ NEVER Use `externalUrl` for Video Streams

**`externalUrl` opens a TV browser/webview — users HATE this experience.** Always extract the direct video URL (MP4 or M3U8) and return it as `stream.url`. If you cannot extract a direct URL, investigate the User-Agent redirect behavior (see Section 9 below) before giving up.

The ONLY acceptable use of `externalUrl` is for **cross-navigation within Stremio** using `stremio:///` deep links (e.g., navigating from a video to a model page). This is done via `stream.externalUrl` with `stremio:///detail/...` URLs, which open within Stremio itself — NOT a browser.

### Complete Stream Handler with All Methods

```javascript
builder.defineStreamHandler(async ({ type, id }) => {
    const slug = extractSlug(id);
    const streams = [];

    try {
        const embedUrl = `${SITE_BASE}/embed/${slug}/`;
        const html = await fetchPage(embedUrl);
        const $ = parseHTML(html);

        // Method 1: Direct MP4
        const mp4Src = $('video source[type="video/mp4"]').attr('src')
            || $('video source').attr('src')
            || $('video').attr('src');

        if (mp4Src) {
            streams.push({
                url: mp4Src.startsWith('http') ? mp4Src : `${SITE_BASE}${mp4Src}`,
                title: 'Direct MP4',
                behaviorHints: { notWebReady: false },
            });
        }

        // Method 2: M3U8 HLS
        const m3u8Src = $('video source[type="application/x-mpegURL"]').attr('src')
            || $("video source[src$='.m3u8']").attr('src');

        if (m3u8Src) {
            streams.push({
                url: m3u8Src.startsWith('http') ? m3u8Src : `${SITE_BASE}${m3u8Src}`,
                title: 'HLS Stream',
                behaviorHints: { notWebReady: true },
            });
        }

        // Method 3: JavaScript variable extraction (common in KVS)
        if (streams.length === 0) {
            const scriptContent = $('script').text();
            const videoUrlMatch = scriptContent.match(/(?:video_url|video_alt_url[0-9]?)\s*[:=]\s*["']([^"']+)["']/);
            if (videoUrlMatch) {
                streams.push({
                    url: videoUrlMatch[1],
                    title: 'Extracted MP4',
                    behaviorHints: { notWebReady: false },
                });
            }
        }

        // If no direct stream found, log the error
        // NEVER fall back to externalUrl for video — it opens a browser/webview
        if (streams.length === 0) {
            console.error(`No direct stream URL found for ${id}`);
        }
    } catch (err) {
        console.error(`Stream error for ${id}:`, err.message);
    }

    return { streams };
});
```

### Stream Object Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | string | Yes* | Direct video URL (MP4, M3U8). Mutually exclusive with `externalUrl` and `infoHash`. |
| `externalUrl` | string | Yes* | ⚠️ **For cross-navigation ONLY** (`stremio:///` deep links). NEVER use for video playback — opens browser/webview. |
| `infoHash` | string | Yes* | BitTorrent info hash (40 hex chars). For torrent streams. |
| `sources` | string[] | No | Tracker announce URLs. Only for torrent streams. |
| `title` | string | No | Display label shown to user (e.g., "1080p MP4"). |
| `behaviorHints.notWebReady` | boolean | No | Set `true` for HLS streams. |

*Exactly one of `url`, `externalUrl`, or `infoHash` must be provided per stream.

---

## 9. Stream Fix: Direct MP4 Playback via User-Agent Redirect (v2.0.0)

### The Problem

KVS platform sites like ThePornBang use `/get_stream/` URLs that appear to be direct MP4 links but actually serve as redirect gateways. When tested in a browser, these URLs trigger file downloads instead of streaming. This led to the false conclusion that they couldn't be used as native Stremio streams, and the old v1.x implementation incorrectly used `externalUrl` (opening a browser/webview — which users hated).

### Root Cause Analysis

ThePornBang's `/get_stream/` endpoint is a **redirect gateway**, not a direct media server:

1. When a **browser User-Agent** requests the URL → server returns **200 HTML** (a player page)
2. When a **non-browser/media-player User-Agent** requests the URL → server returns **302 redirect** → CDN (vkuser.net)

The CDN (vkuser.net) serves proper MP4 files with:
- `Content-Type: video/mp4`
- `Accept-Ranges: bytes`
- `206 Partial Content` support
- `Content-Length` headers
- `Content-Disposition: attachment` (for full requests) / `inline` (for range requests)

### Key Discovery: User-Agent Based Redirect Behavior

| User-Agent | Response |
|---|---|
| Browser (Chrome, Firefox, etc.) | 200 HTML (player page) |
| "Stremio" UA | 302 → CDN redirect ✓ |
| Android stagefright UA | 302 → CDN redirect ✓ |
| VLC UA | 200 HTML |
| ffmpeg UA | 200 HTML |
| curl default UA | 200 HTML |
| No UA / empty UA | 200 or 302 (inconsistent) |

**The critical insight:** Stremio's internal player uses its own User-Agent (not a browser UA) when requesting stream URLs. This means the `/get_stream/` URL automatically returns a 302 redirect to the CDN when Stremio requests it — **no browser, no webview needed!**

### The Fix

Instead of using `externalUrl` (which opens a browser/webview), extract the `get_stream` URLs from the page's `flashvars` JavaScript and return them as direct `url` streams:

```javascript
// flashvars format on the page:
// video_url: 'https://www.thepornbang.com/get_stream/{id}-480.mp4?md5=...&timestamp=...'
// video_alt_url: '...720p...'
// video_alt_url2: '...1080p...'  
// video_alt_url3: '...2160p...'

streams.push({
    name: 'Curvcorn',
    title: '1080p FHD',
    url: streamUrl,  // Direct get_stream URL with auth params
});
```

When Stremio's player requests this URL:
1. Stremio sends the request with its own User-Agent (not a browser UA)
2. ThePornBang returns 302 → CDN redirect
3. CDN serves the MP4 with proper streaming headers
4. Video plays natively in Stremio — **NO browser, NO webview!**

### Stream URL Format

```
https://www.thepornbang.com/get_stream/{videoId}-{quality}.mp4?md5={hash}&timestamp={ts}_{nonce}
```

- Quality options: 480, 720, 1080, 2160
- `md5` and `timestamp` are time-limited auth parameters
- URL expires after some time (user must re-request streams)

### CDN Redirect Chain

```
Stremio Player → get_stream URL (thepornbang.com)
                → 302 Redirect to vkuser.net CDN
                → CDN serves MP4 (200/206 with range support)
```

### Fallback: Proxy Endpoint

If direct URLs don't work for some reason, there's a `/stream-proxy/` endpoint:
- URL: `https://curvcorn-thepornbang.vercel.app/stream-proxy/{segment}/{quality}`
- Our server fetches the video page, extracts stream URLs, and resolves the redirect
- Returns 302 redirect to CDN URL or get_stream URL as fallback
- Uses "Stremio" UA to reliably get 302 redirects from thepornbang.com

### Cross-Navigation Streams

Models and Tags are included as `externalUrl` streams with `stremio:///detail/curvcorn/{id}` URLs:
- These navigate **WITHIN Stremio** (not a browser/webview)
- Clicking a model stream card → opens that model's page in Stremio
- Clicking a tag stream card → opens that tag's page in Stremio
- This is the ONLY acceptable use of `externalUrl` — for in-app navigation, NOT video playback

### What NOT To Do (Lessons Learned)

1. **NEVER use `externalUrl` for video streams** — it opens a browser/webview, users hate it
2. **NEVER assume MP4 URLs that trigger downloads are unplayable** — check the User-Agent behavior first
3. **NEVER strip auth parameters from get_stream URLs** — they're required for the redirect
4. **The `Content-Disposition: attachment` header on the CDN does NOT prevent Stremio from playing the stream** — Stremio's player handles this correctly

### Files Changed

- `addon.js`: Complete rewrite of `getVideoStreams()` — extracts URLs from flashvars, returns direct streams
- `api/index.js`: Added `/stream-proxy/` and `/debug-streams/` endpoints

---

## 10. Meta `links` Field — Clickable Cross-Navigation

The `links` array in a meta response creates clickable navigation links on Stremio's detail page. This is the key mechanism for enabling users to navigate between related content (e.g., from a video to a model page, or from a video to a tag page).

### Link Object Format

```javascript
{
    name: "Display Name",     // REQUIRED - text shown to user
    category: "Group Name",   // REQUIRED - links are grouped by category in UI
    url: "stremio:///..."     // REQUIRED - deep link URL
}
```

### Stremio Deep Link URL Formats

| Deep Link | Purpose | Example |
|-----------|---------|---------|
| `stremio:///detail/{type}/{id}` | Navigate to another item's detail page | `stremio:///detail/channel/model_kwini-kim` |
| `stremio:///detail/{type}/{id}/{videoId}` | Open a specific video in a series/channel | `stremio:///detail/series/tt0108778/tt0108778:1:1` |
| `stremio:///search?search={query}` | Open the search page with a query | `stremio:///search?search=Kwini%20Kim` |
| `stremio:///discover/{encodedManifestUrl}/{type}/{catalogId}?{extra}` | Open a specific catalog with filters | `stremio:///discover/https%3A%2F%2Fv3-cinemeta.strem.io%2Fmanifest.json/movie/top?genre=Drama` |

### Complete Example: Video Meta with Models, Categories, and Tags

```javascript
const links = [];

for (const model of pageData.models) {
    links.push({
        name: model.name,
        category: "Models",
        url: `stremio:///detail/channel/model_${model.slug}`,
    });
}

for (const cat of pageData.categories) {
    links.push({
        name: cat.name,
        category: "Categories",
        url: `stremio:///detail/channel/cat_${cat.slug}`,
    });
}

for (const tag of pageData.tags.slice(0, 5)) {
    links.push({
        name: tag.name,
        category: "Tags",
        url: `stremio:///detail/channel/tag_${tag.slug}`,
    });
}

const meta = {
    id: "video_12345",
    type: "movie",
    name: "Video Title",
    links: links,
};
```

### Important Notes

1. **Stremio routes deep links based on `idPrefixes`.** When a user clicks `stremio:///detail/channel/model_kwini-kim`, Stremio looks for addons that handle `channel` type with an idPrefix matching `model_`. Make sure your manifest declares all prefixes you use in links.
2. **Categories group links visually.** Links with the same `category` are displayed together under that heading.
3. **Reserved categories:** Do NOT use `imdb` or `share` as categories — these are reserved by Stremio.
4. **Platform support varies.** Meta links may not work identically on all platforms (Android, Desktop, Web). Test on your target platform.
5. **Users can add linked items to their library.** When a user navigates to a channel page via a deep link, they can add it to their Stremio library for easy access.

---

## 11. Multi-Prefix ID Strategy for Channel Types

When building an addon with multiple navigable entities (models, tags, categories), use a separate ID prefix for each entity type. This allows Stremio to route requests correctly.

### Manifest Configuration

```javascript
const manifest = {
    id: "community.my-addon",
    resources: [
        "catalog",
        { name: "meta", types: ["channel", "movie"], idPrefixes: ["model_", "video_", "tag_", "cat_"] },
        { name: "stream", types: ["movie"], idPrefixes: ["video_"] },
    ],
    types: ["channel", "movie"],
    catalogs: [
        { type: "channel", id: "models", name: "Models", extra: [...] },
        { type: "channel", id: "tags", name: "Tags", extra: [...] },
        { type: "movie", id: "video_search", name: "Video Search", extra: [...] },
    ],
    idPrefixes: ["model_", "video_", "tag_", "cat_"],
};
```

### Entity Type Mapping

| Entity | Type | Prefix | ID Format | Description |
|--------|------|--------|-----------|-------------|
| Model | channel | `model_` | `model_kwini-kim` | Model page with all their videos |
| Video | movie | `video_` | `video_416282` | Single video with stream |
| Tag | channel | `tag_` | `tag_british` | Tag page with all tagged videos |
| Category | channel | `cat_` | `cat_asian` | Category page with all category videos |

### Meta Handler Routing

```javascript
builder.defineMetaHandler(async ({ id, type }) => {
    if (type === "channel" && id.startsWith("model_")) {
        // Handle model page
    }
    if (type === "channel" && id.startsWith("tag_")) {
        // Handle tag page
    }
    if (type === "channel" && id.startsWith("cat_")) {
        // Handle category page
    }
    if (type === "movie" && id.startsWith("video_")) {
        // Handle video
    }
    return { meta: {} };
});
```

### Key Design Decisions

1. **Tags and categories as `channel` type** allows users to add them to their Stremio library, just like models.
2. **Each entity type has its own prefix** prevents ID collisions and allows clean routing.
3. **Streams only for `video_` prefix** — channel-type items don't have streams; users click individual videos from the video list.
4. **Sort model pages by date** using `?sort_by=post_date` so newest videos appear first.

---

## 12. Clickable Navigation Streams — Tags & Models as Clickable Channel Links (v3.0.0)

### The Feature

When a user opens a video in Stremio, they see a list of "streams" — typically just the video playback options. But you can add **non-playable navigation streams** that, when clicked, navigate the user to another page within Stremio (like a model's channel page or a tag's channel page). This is done using `stream.externalUrl` with Stremio deep links.

This is the EXACT same pattern used by the **TMDB Collections addon** — when you open a movie that's part of a collection, you see a stream entry that says "Click to view collection" and clicking it navigates to the collection page.

### Why This Is Revolutionary

Without navigation streams, users have to:
1. Remember a model's name
2. Go back to the addon's catalog
3. Search for the model
4. Find them in the results
5. Open their page

WITH navigation streams, users can:
1. Open a video
2. See "👤 Kwini Kim" in the streams list
3. Click it → instantly on Kwini Kim's channel page
4. Click "Add to Library" → done!

This makes your addon feel like a premium streaming app with connected content, not just a list of isolated videos.

### How It Works — The `externalUrl` Deep Link Pattern

```javascript
// In your stream handler, after adding the playable MP4 stream:
streams.push({
    name: "MySite",
    title: "▶ Direct MP4",
    url: mp4Url,
    behaviorHints: { notWebReady: false },
});

// Then add navigation streams for models:
for (const model of videoModels) {
    streams.push({
        name: "👤 Model",
        title: `${model.name}\nClick to view model page`,
        externalUrl: `stremio:///detail/channel/model_${model.slug}`,
    });
}

// Then add navigation streams for tags:
for (const tag of videoTags.slice(0, 5)) {
    streams.push({
        name: "🏷️ Tag",
        title: `${tag.name}\nClick to browse tag`,
        externalUrl: `stremio:///detail/channel/tag_${tag.slug}`,
    });
}
```

### Deep Link URL Reference

| Deep Link Format | What It Does | Example |
|---|---|---|
| `stremio:///detail/{type}/{id}` | Opens a meta item's detail page | `stremio:///detail/channel/model_kwini-kim` |
| `stremio:///detail/{type}/{id}/{videoId}` | Opens with a specific video selected | `stremio:///detail/channel/model_kwini-kim/video_492438` |
| `stremio:///search?search={query}` | Opens Stremio search with a query | `stremio:///search?search=British` |

For **web.stremio.com**, use `https://web.stremio.com/#/detail/{type}/{id}` instead. Detect the platform by checking if the request came from `web.stremio.com` in the origin header.

### Stream Order Best Practice

Put the playable stream FIRST, then models, then tags. Users expect the first option to be the video itself:

```
[0] ▶ Direct MP4          (playable - stream.url)
[1] 👤 Model - Kwini Kim  (navigation - stream.externalUrl)
[2] 👤 Model - Martin Spell (navigation - stream.externalUrl)
[3] 🏷️ Tag - British     (navigation - stream.externalUrl)
[4] 🏷️ Tag - Amateur     (navigation - stream.externalUrl)
[5] 🏷️ Tag - Blowjob     (navigation - stream.externalUrl)
```

### Manifest Configuration Required

Your stream resource MUST include all prefixes that might appear in stream IDs. If you only put `["video_"]` in the stream idPrefixes, Stremio might not route stream requests for videos accessed from channel pages correctly:

```javascript
const manifest = {
    resources: [
        "catalog",
        { name: "meta", types: ["channel", "movie"], idPrefixes: ["model_", "tag_", "video_"] },
        { name: "stream", types: ["channel", "movie"], idPrefixes: ["video_", "model_", "tag_"] },
    ],
    // ...
};
```

### The "No Streams Found" Bug — Compound IDs from Channel Pages

When a user clicks a video from a model's channel page, Stremio may send the stream request with a compound ID like `model_kwini-kim:video_492438`. If your stream handler only checks `id.startsWith("video_")`, it won't match and returns empty streams → "No Streams found".

**Fix:** Extract the video ID from compound formats:

```javascript
function extractVideoId(id) {
    // Direct format: video_12345
    if (id.startsWith("video_")) return id.replace("video_", "");
    // Compound format: model_slug:video_12345 or tag_slug:video_12345
    const parts = id.split(":");
    for (const part of parts) {
        if (part.startsWith("video_")) return part.replace("video_", "");
    }
    return null;
}

builder.defineStreamHandler(async ({ id, type }) => {
    const videoId = extractVideoId(id);
    if (videoId) {
        // Fetch the embed page and extract MP4 stream
        const embedUrl = `${SITE_BASE}/embed/${videoId}/`;
        // ... rest of stream extraction
    }
    // Channel items (models, tags) don't need streams
    if (id.startsWith("model_") || id.startsWith("tag_")) {
        return { streams: [] };
    }
    return { streams: [] };
});
```

---

## 13. CRITICAL: DOM Scraping Pitfall — Related Section Pollution (v3.1.0)

### The Problem

When scraping video pages to extract models and tags for navigation streams, the page often contains a "Related Videos" or "Recommended Videos" section at the bottom. This section contains video cards from OTHER videos, each with their own model links and tags. If you use a broad selector like `$("a[href*='/models/']")` or `$("a[href*='/tags/']")`, you will pick up ALL models from ALL related videos — potentially 20-50+ models that have NOTHING to do with the video the user is watching.

### Real-World Example (w1mp.com / KVS Platform)

A video page on w1mp.com contains:
- **2 actual models** (in `.js-models-list` div, part of the video player section)
- **22+ related video models** (in `.section-row.related .card` divs, from the "Related Videos" section)

Using `$("a[href*='/models/']")` returns ALL 24+ models, making the streams list unusable — the user has to scroll past 20+ random models to find the tags.

### The Fix — Use Specific Parent Container Selectors

Instead of selecting ALL links on the page, scope your selectors to the video's own info section:

```javascript
// ❌ WRONG — picks up models from Related Videos section
$("a[href*='/models/']").each((_, el) => { ... });

// ✅ CORRECT — only picks up the video's own models
$(".js-models-list a").each((_, el) => { ... });

// ❌ WRONG — picks up tags from Related Videos section  
$("a[href*='/tags/']").each((_, el) => { ... });

// ✅ CORRECT — only picks up the video's own tags
$(".top-player-items-wrap a[href*='/tags/']").each((_, el) => { ... });
```

### How to Find the Right Selectors

1. **Fetch the page HTML** and load it with cheerio
2. **Find all links** of the type you want (models, tags, categories)
3. **Build the parent chain** for each link (walk up 4-6 levels of parents, recording tag + class)
4. **Identify the container** that holds ONLY the video's own data (usually near the video player)
5. **Identify the container** for related/recommended content (usually has class like `.related`, `.recommended`, `.similar`)
6. **Scope your selector** to the video info container only

Here's a diagnostic script you can run:

```javascript
// Diagnostic: Find all model links and their parent containers
$("a").each((i, el) => {
    const href = $(el).attr("href") || "";
    if (href.includes("/models/") && !href.endsWith("/models/")) {
        const text = $(el).text().trim();
        if (text && text.length < 50 && !text.includes("See all")) {
            // Build parent chain
            const parents = [];
            let parent = $(el).parent();
            for (let d = 0; d < 6 && parent.length; d++) {
                const cls = parent.attr("class") || "";
                const tag = parent.get(0)?.tagName || "";
                parents.push(`${tag}.${cls.split(" ").join(".")}`);
                parent = parent.parent();
            }
            console.log(`"${text}" → parents: ${parents.join(" > ")}`);
        }
    }
});
```

### KVS Platform DOM Structure (w1mp.com, and similar sites)

| Element | Correct Selector | What It Contains |
|---|---|---|
| Video's own models | `.js-models-list a` | Only models credited in THIS video (2-3 typically) |
| Video's own tags | `.top-player-items-wrap a[href*="/tags/"]` | Only tags for THIS video |
| Video's own categories | `.top-player-items-wrap a[href*="/categories/"]` | Only categories for THIS video |
| Related video models | `.section-row.related .card a[href*="/models/"]` | Models from OTHER videos — DO NOT USE |
| Related video models | `.item-tool.model a` | Models from video cards in related section — DO NOT USE |
| Model poster image | `img.image` (src contains `/contents/models/`) | Full-size model photo |
| Model poster fallback | `data-model-id` attribute → construct CDN URL | When no `img.image` exists |
| Model icon | `img[src*="_ico.jpg"]` | Small thumbnail (not ideal for poster) |

### Model Poster Extraction Strategy

Not all models have poster images. Use a fallback chain:

```javascript
let modelPoster = "";

// 1. Full-size poster image (class="image")
$("img.image").each((_, el) => {
    const src = $(el).attr("src") || "";
    if (src.includes("/contents/models/")) {
        modelPoster = fixUrl(src);
    }
});

// 2. Fallback: Use data-model-id to construct CDN URL
if (!modelPoster) {
    const modelIdMatch = html.match(/data-model-id="(\d+)"/);
    if (modelIdMatch) {
        modelPoster = `${CDN_STATIC}/contents/models/${modelIdMatch[1]}/${slug}.jpg`;
    }
}

// Some models don't have photos at all — modelPoster will be ""
// This is fine, Stremio handles missing posters gracefully
```

### What NOT To Do

1. **NEVER use `$("a[href*='/models/']")` on a video page** — it picks up 20+ models from related videos
2. **NEVER use `$("a[href*='/tags/']")` on a video page** without scoping to the video info section
3. **NEVER assume all links on a page belong to the current video** — video pages have related sections, comments, sidebar content
4. **NEVER skip the parent chain analysis** — always inspect the DOM structure before writing selectors
5. **NEVER use models from `.card` elements inside `.related` sections** — these are from other videos
