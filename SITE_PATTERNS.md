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
// Extraction code for w1mp.com
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
        // Ensure absolute URL
        if (!videoUrl.startsWith('http')) {
            videoUrl = `https://w1mp.com${videoUrl}`;
        }
        return {
            url: videoUrl,
            title: 'Direct MP4',
            behaviorHints: { notWebReady: false },
        };
    }

    // Last resort: return embed as externalUrl
    return {
        externalUrl: embedUrl,
        title: 'Embed Player',
        behaviorHints: { notWebReady: true },
    };
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
  - /embed/{id}/ → <video><source> → MP4 URL
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

- **Platform:** KVS (Kernel Video Sharing) — Enhanced with encrypted anti-leeching
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
| Stream token | `/get_stream/{contentId}-{quality}.mp4?md5=...&timestamp=...` | **ENCRYPTED — see below** |

### URL Convention

All entity URLs use the format: `/{entity_type}/{slug}_{typeChar}{id}/`
- Type chars: `c`=category, `p`=pornstar, `s`=studio, `t`=tag, `v`=video
- Example: `/category/big-tits_c18/` → slug="big-tits", type=c, id=18

### Video Source Extraction — CRITICAL

**⚠️ ThePornBang uses KVS encrypted anti-leeching (generate_mp4). Direct MP4 URLs DO NOT work.**

The `/get_stream/` URLs return `"error 1"` when fetched programmatically because KVS requires a 2-step CryptoJS decryption process via `generate_mp4()`:

1. Video page contains: `generate_mp4(encryptedData, key, commaIds, videoId)`
2. The function decrypts `encryptedData` using AES-256-CBC with PBKDF2-SHA512
3. Makes XHR GET to decrypted URL
4. Decrypts response
5. Makes XHR POST to `/get_video/` with re-encrypted data
6. Only then are the `/get_stream/` URLs unlocked

**The kt_player.js is heavily obfuscated** — string array rotation, hex encoding, variable name mangling. Replicating in Node.js is impractical.

**✅ Proven Fix: Proxy Player Page**

Create a serverless function that:
1. Fetches the video page HTML
2. Extracts `kt_player.js` script + `generate_mp4()` call + `flashvars` object
3. Serves a minimal HTML page with the player
4. The site's own JS handles decryption and playback
5. Stremio opens this via `externalUrl` in its built-in web view

```javascript
// Stream handler
streams.push({
    name: 'Curvcorn',
    title: 'Play (Proxy Player)',
    externalUrl: `${ADDON_BASE}/play/${videoSegment}`,
    notWebReady: true,
});
```

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
  - Proxy player page (/play/{segment}) with externalUrl
  - Fallback: direct link to video page on ThePornBang
```

---

*Last updated: 2026-06-07*
