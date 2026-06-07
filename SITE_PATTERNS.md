# Site Patterns Database

Documented site structure and scraping patterns for building Stremio addons. Each entry provides a complete map of a site's structure, extraction methods, and gotchas.

---

## How to Use This Database

1. **Before building an addon for a new site**, check if the site (or a similar platform) is already documented here.
2. **When you discover a new site pattern**, add it here following the format below.
3. **When a site changes its structure**, update the existing entry with the new information.

### Entry Format

```
## Site: [domain]
- **Platform:** [KVS / WordPress / Custom / Unknown]
- **Cloudflare:** [Yes / No]
- **Last Verified:** [Date]
- [URL patterns, extraction methods, gotchas]
```

---

## Site: w1mp.com

- **Platform:** KVS (Kernel Video Sharing)
- **Cloudflare:** No
- **Last Verified:** 2026-05-22

### URL Patterns

#### Models (Channels)

| Pattern | URL | Notes |
|---------|-----|-------|
| Model page | `/models/{slug}/` | All videos by this model. Use as channel meta. |
| Model page (paginated) | `/models/{slug}/{page}/` | Page 1 is `/models/{slug}/`, page 2+ adds page number. |

#### Videos

| Pattern | URL | Notes |
|---------|-----|-------|
| Video page (full) | `/video/{id}/{slug}/` | **Slug is REQUIRED.** Without slug → 404. |
| Embed page | `/embed/{id}/` | **Works without slug.** Use this for stream extraction. |

#### Search

| Pattern | URL | Notes |
|---------|-----|-------|
| Search | `/search/?q={query}` | Standard query parameter. |

#### Categories

| Pattern | URL | Notes |
|---------|-----|-------|
| Category page | `/categories/{slug}/` | Browse videos by category. |
| Category page (paginated) | `/categories/{slug}/{page}/` | Same pagination as models. |

### Video Source Extraction

**Method: Direct MP4 from embed page**

1. Fetch `/embed/{id}/`
2. Parse HTML with cheerio
3. Find `<video>` → `<source>` tag
4. Extract `src` attribute — this is the direct MP4 URL

```javascript
async function extractStream(videoId) {
    const embedUrl = `https://w1mp.com/embed/${videoId}/`;
    const html = await fetchPage(embedUrl);
    const $ = cheerio.load(html);

    // Primary: <video><source> tag
    let videoUrl = $('video source').attr('src');

    // Fallback: <video> src attribute
    if (!videoUrl) {
        videoUrl = $('video').attr('src');
    }

    // Fallback: JavaScript variable in page scripts
    if (!videoUrl) {
        const scripts = $('script').text();
        const match = scripts.match(/video_url\s*[:=]\s*["']([^"']+)["']/);
        if (match) {
            videoUrl = match[1];
        }
    }

    if (videoUrl) {
        if (!videoUrl.startsWith('http')) {
            videoUrl = `https://w1mp.com${videoUrl}`;
        }
        return {
            url: videoUrl,
            title: 'Direct MP4',
            behaviorHints: { notWebReady: false },
        };
    }

    // No stream found — NEVER use externalUrl (opens browser/webview)
    console.error(`No direct stream found for ${videoId}`);
    return null;
}
```

### Video Tokens

- **v-acctoken**: This token appears in video page requests. It is **base64-encoded** and **time-limited**.
- The token is typically embedded in the page's JavaScript and is used to authorize the video stream URL.
- For direct MP4 extraction from the embed page, the token is usually already included in the extracted URL.
- If the token has expired, the MP4 URL will return 403 Forbidden. Re-fetching the embed page generates a new token.

### Scraping Notes

1. **No Cloudflare** — direct HTTP requests work without browser emulation.
2. **Embed URLs are the key** — always use `/embed/{id}/` instead of `/video/{id}/{slug}/`.
3. **Rate limiting** — the site may rate-limit aggressive requests. Add a small delay between requests if scraping multiple pages.
4. **Pagination** — model pages are paginated. Page 1 has no page number in the URL. Subsequent pages use `/{page}/`.
5. **Model slug** — the model slug is used in the URL and is typically a lowercase, hyphenated version of the model's name.

### Recommended Addon Architecture for w1mp.com

```
Content Type: channel (for models)
              movie (for individual videos if needed)

Catalog:
  - type: channel, id: "models"
    - Browse: /models/ (paginated)
    - Search: /search/?q=...

Meta:
  - channel: /models/{slug}/ → videos array
  - movie: /embed/{id}/ → metadata from embed page

Stream:
  - /embed/{id}/ → <video><source> → MP4 URL (stream.url)
  - NEVER use externalUrl for video streams
```

---

## Quick Reference: Platform Detection

When approaching a new site, use these signals to identify the platform:

| Signal | KVS | WordPress | Custom |
|--------|-----|-----------|--------|
| URL pattern `/video/{id}/{slug}/` | ✅ | ❌ | ❌ |
| URL pattern `/embed/{id}/` | ✅ | ❌ | Sometimes |
| `<meta name="generator" content="Kernel Video Sharing">` | ✅ | ❌ | ❌ |
| `<meta name="generator" content="WordPress">` | ❌ | ✅ | ❌ |
| `/wp-json/` API endpoint | ❌ | ✅ | ❌ |
| `wp-content` in asset URLs | ❌ | ✅ | ❌ |
| KVS-specific JavaScript (kt_player, kvs) | ✅ | ❌ | ❌ |
| Model pages with `/models/{slug}/` | ✅ | ❌ | Sometimes |

---

## Site: thepornbang.com

- **Platform:** KVS (Kernel Video Sharing) — User-Agent-based redirect gateway
- **Cloudflare:** Behind Cloudflare CDN (but accessible with proper headers)
- **Last Verified:** 2026-06-07

### URL Patterns

#### Home & Browsing

| Pattern | URL | Notes |
|---------|-----|-------|
| Homepage | `/home35/` | Multiple sections: Premium 4K, Latest, Trending, Popular, Channels, Pornstars |
| All Videos | `/videos_27/{page}/` | Paginated |
| Most Viewed | `/most-viewed_17/{page}/` | Paginated |
| Top Rated | `/top-rated_15/{page}/` | Paginated |
| Search | `/search/{query}/{page}/` | Search results, paginated |

#### Categories

| Pattern | URL | Notes |
|---------|-----|-------|
| Categories List | `/categories_16/` | All categories with thumbnails |
| Category Detail | `/category/{slug}_c{id}/{page}/` | Videos in category. Slug+ID suffix format. |

#### Models (Pornstars)

| Pattern | URL | Notes |
|---------|-----|-------|
| Pornstars List | `/pornstars_19/{page}/` | Also `/pornstars_19/name/` for alphabetical |
| Pornstar Detail | `/pornstar/{slug}_p{id}/{page}/` | Videos by pornstar |

#### Tags

| Pattern | URL | Notes |
|---------|-----|-------|
| Tags List | `/tags_34/` | All tags with video counts |
| Tag Detail | `/tag/{slug}_t{id}/{page}/` | Videos with tag |

#### Studios (Channels)

| Pattern | URL | Notes |
|---------|-----|-------|
| Studios List | `/studios_32/` | All studios/channels |
| Studio Detail | `/studio/{slug}_s{id}/{page}/` | Videos by studio |

#### Videos

| Pattern | URL | Notes |
|---------|-----|-------|
| Video page | `/video/{slug}_v{id}/` | Full page with player, metadata, related videos |
| Stream URL | `/get_stream/{contentId}-{quality}.mp4?md5=...&timestamp=...` | **Direct MP4 via User-Agent redirect — see below** |

### URL Convention

All entity URLs use the format: `/{entity_type}/{slug}_{typeChar}{id}/`
- Type chars: `c`=category, `p`=pornstar, `s`=studio, `t`=tag, `v`=video
- Example: `/category/big-tits_c18/` → slug="big-tits", type=c, id=18

### Video Source Extraction — Direct MP4 via User-Agent Redirect (v2.0.0)

**✅ ThePornBang's `/get_stream/` URLs work as direct `stream.url` streams in Stremio!**

The `/get_stream/` endpoint is a **User-Agent-based redirect gateway**:

| User-Agent | Response |
|---|---|
| Browser (Chrome, Firefox, etc.) | 200 HTML (player page) — triggers download in browser |
| "Stremio" UA | **302 → CDN redirect ✓** |
| Android stagefright UA | **302 → CDN redirect ✓** |
| VLC UA | 200 HTML |
| ffmpeg UA | 200 HTML |
| curl default UA | 200 HTML |

**The CDN (vkuser.net) serves proper MP4 files** with:
- `Content-Type: video/mp4`
- `Accept-Ranges: bytes`
- `206 Partial Content` support
- `Content-Length` headers
- `Content-Disposition: attachment` (full requests) / `inline` (range requests)

**How it works in Stremio:**
1. Addon extracts `get_stream` URLs from the page's `flashvars` JavaScript
2. Returns them as direct `url` streams (NOT `externalUrl`!)
3. Stremio's player requests the URL with its own non-browser User-Agent
4. ThePornBang returns `302 → CDN redirect`
5. CDN serves the MP4 with proper streaming headers
6. **Video plays natively in Stremio — NO browser, NO webview!**

**Extraction code:**

```javascript
// flashvars format on the page:
// video_url: 'https://www.thepornbang.com/get_stream/{id}-480.mp4?md5=...&timestamp=...'
// video_alt_url: '...720p...'
// video_alt_url2: '...1080p...'  
// video_alt_url3: '...2160p...'

const qualityMap = {
    'video_alt_url3': { quality: '2160p UHD', suffix: '2160' },
    'video_alt_url2': { quality: '1080p FHD', suffix: '1080' },
    'video_alt_url':  { quality: '720p HD', suffix: '720' },
    'video_url':      { quality: '480p SD', suffix: '480' },
};

for (const [varName, config] of Object.entries(qualityMap)) {
    const match = flashvars.match(new RegExp(varName + "\\s*[:=]\\s*['\"]([^'\"]+)['\"]"));
    if (match && match[1]) {
        streams.push({
            name: 'Curvcorn',
            title: config.quality,
            url: match[1],  // Direct get_stream URL with auth params
        });
    }
}
```

**Stream URL format:**
```
https://www.thepornbang.com/get_stream/{videoId}-{quality}.mp4?md5={hash}&timestamp={ts}_{nonce}
```
- Quality options: 480, 720, 1080, 2160
- `md5` and `timestamp` are time-limited auth parameters — DO NOT strip them
- URL expires after some time (user must re-request streams)

**CDN redirect chain:**
```
Stremio Player → get_stream URL (thepornbang.com)
                → 302 Redirect to vkuser.net CDN
                → CDN serves MP4 (200/206 with range support)
```

**Fallback: Proxy endpoint** (if direct URLs don't work for some reason):
- URL: `https://curvcorn-thepornbang.vercel.app/stream-proxy/{segment}/{quality}`
- Our server fetches the video page, extracts stream URLs, resolves the redirect
- Returns 302 redirect to CDN URL or get_stream URL as fallback
- Uses "Stremio" UA to reliably get 302 redirects from thepornbang.com

### ⚠️ Critical: What NOT To Do

1. ❌ **NEVER use `externalUrl` for video streams** — it opens a browser/webview, users HATE it
2. ❌ **NEVER assume `/get_stream/` URLs are unplayable because they trigger downloads in browsers** — the server behavior depends on User-Agent
3. ❌ **NEVER strip auth parameters** (md5, timestamp) from get_stream URLs — they're required for the redirect
4. ❌ **The `Content-Disposition: attachment` header does NOT prevent Stremio from playing the stream** — Stremio's player handles this correctly
5. ❌ **NEVER use a proxy player page approach** — the direct `stream.url` approach is simpler, faster, and gives native playback

### Scraping Notes

1. **Must use `Accept-Encoding: identity`** — without this, requests timeout or return empty
2. **Keep-alive agent recommended** — reusing connections significantly improves speed
3. **Retry logic needed** — site can be flaky, 2-3 retries with 1.5s delay recommended
4. **Lazy-loaded images** — thumbnails use `data-original` attribute, not `src`
5. **31 categories, 45+ models, 22+ channels, 527+ tags** — all accessible
6. **Search works** — `/search/{query}/1/` returns video cards

### Video Card DOM Selectors

```css
div.row.item a.thumb         → Video card link
a.thumb[title]               → Video title
a.thumb[href]                → Video URL (contains /video/{slug}_v{id}/)
img.thumb-img[data-original]  → Thumbnail (lazy-loaded)
span.duration span.value      → Duration (e.g. "33:49")
span.views span.value         → Views (e.g. "49.76K")
div.rating                    → Rating percentage
span.qhd                      → 4K quality badge
```

### Recommended Addon Architecture

```
Content Type: curvcorn (custom type, appears as separate section in Discover)

Catalogs:
  - Home: /home35/
  - Popular: /most-viewed_17/{page}/
  - Top Rated: /top-rated_15/{page}/
  - Categories: /categories_16/
  - Models: /pornstars_19/{page}/
  - Channels: /studios_32/
  - Tags: /tags_34/
  - Search: /search/{query}/{page}/

Meta:
  - Video (v_ prefix): /video/{segment}/ → title, description, poster, cast, genre, links
  - Model (m_ prefix): /pornstar/{segment}/ → name, poster, videos array
  - Category (c_ prefix): /category/{segment}/ → name, poster, videos array
  - Studio (s_ prefix): /studio/{segment}/ → name, poster, videos array
  - Tag (t_ prefix): /tag/{segment}/ → name, videos array

Stream:
  - Direct MP4 via get_stream URLs (stream.url) — Stremio's UA triggers 302 CDN redirect
  - Fallback: /stream-proxy/ endpoint with "Stremio" UA
  - Cross-navigation: externalUrl with stremio:///detail/curvcorn/{id} for models/tags (in-app navigation only)
  - ❌ NEVER use externalUrl for video playback
```

---

*Last updated: 2026-06-07*
