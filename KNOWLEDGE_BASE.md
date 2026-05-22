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
    // Try embed page first (more reliable for KVS sites)
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

    // Method 3: Fallback to embed/externalUrl
    if (streams.length === 0) {
        streams.push({
            externalUrl: embedUrl,
            title: 'Embed Player',
            behaviorHints: {
                notWebReady: true,
            },
        });
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
        // The addon SDK getInterface() returns an object with a router
        // that can handle incoming HTTP requests
        const { headers, body, statusCode } = await addon.router({
            path: path,
            query: Object.fromEntries(url.searchParams),
            method: req.method,
        });

        // Apply response headers
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
            // Stremio passes the search string in extra.search
            // Use the site's search endpoint
            const searchUrl = `${SITE_BASE}/search/?q=${encodeURIComponent(search)}`;
            const html = await fetchPage(searchUrl);
            const $ = parseHTML(html);
            results = parseSearchResults($, type);
        } else {
            // ─── Browse Mode ──────────────────────────────────
            // Stremio uses skip for pagination (skip=0, skip=20, skip=40...)
            // Convert to site's page number
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

        // ─── Build videos array ────────────────────────────────
        // Each video becomes an "episode" under this channel
        const videos = [];
        $('.video-item').each((i, el) => {
            const elem = $(el);
            const videoId = elem.find('a').attr('href')?.match(/\/video\/(\d+)/)?.[1];
            const videoTitle = elem.find('.title').text().trim();
            const videoThumb = elem.find('img').attr('src') || '';
            const duration = elem.find('.duration').text().trim();

            if (videoId && videoTitle) {
                videos.push({
                    id: buildId(videoId),   // This ID will be used in stream handler
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

    // Fetch the embed page
    const embedUrl = `${SITE_BASE}/embed/${slug}/`;
    const html = await fetchPage(embedUrl);
    const $ = parseHTML(html);

    // Extract MP4 URL from <video><source> tag
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

### Embed / iframe Stream (External URL)

When you cannot extract a direct video URL, fall back to opening the embed page:

```javascript
// Use externalUrl to open the embed page in Stremio's web view
streams.push({
    externalUrl: 'https://example.com/embed/12345/',
    title: 'Embed Player',
    behaviorHints: {
        notWebReady: true,  // Required for external URLs
    },
});
```

### Complete Stream Handler with All Methods

```javascript
builder.defineStreamHandler(async ({ type, id }) => {
    const slug = extractSlug(id);
    const streams = [];

    try {
        // Strategy: Try embed page first (most reliable for KVS sites)
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

        // Method 4: Fallback to embed page as externalUrl
        if (streams.length === 0) {
            streams.push({
                externalUrl: embedUrl,
                title: 'Embed Player',
                behaviorHints: { notWebReady: true },
            });
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
| `externalUrl` | string | Yes* | URL to open in web view. For iframe/embed pages. |
| `infoHash` | string | Yes* | BitTorrent info hash (40 hex chars). For torrent streams. |
| `sources` | string[] | No | Tracker announce URLs. Only for torrent streams. |
| `title` | string | No | Display label shown to user (e.g., "1080p MP4"). |
| `behaviorHints.notWebReady` | boolean | No | Set `true` for HLS and external URLs. |

*Exactly one of `url`, `externalUrl`, or `infoHash` must be provided per stream.
