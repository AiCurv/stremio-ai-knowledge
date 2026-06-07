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

## Site: xxdbx.com

- **Platform:** Custom (plain HTML + jQuery + FluidPlayer)
- **Cloudflare:** No
- **Last Verified:** 2026-06-07
- **Status:** ✅ WORKS PERFECTLY — Direct MP4 streams, no anti-leeching, no encryption

### URL Patterns

#### Home & Browsing

| Pattern | URL | Notes |
|---------|-----|-------|
| Homepage (newest) | `/` or `/?page=N` | 30 videos per page |
| Most Popular | `/most-popular` or `/most-popular?page=N` | Paginated |
| Search/Tag | `/search/{query}` or `/search/{query}?page=N` | Same format for tags and search |
| Star/Pornstar | `/stars/{name}` | URL-encoded name, e.g. `/stars/Bad%20Bella` |
| Channel | `/channels/{name}` | e.g. `/channels/LegalPorno.com` |
| Date | `/dates/{date}` | e.g. `/dates/2026` or `/dates/2026-03-09` |

#### Videos

| Pattern | URL | Notes |
|---------|-----|-------|
| Video detail | `/view/{id}` | e.g. `/view/22325971680` |
| Stream CDN | `//d.v1d30.com/{TOKEN}/{VIDEO_ID}{QUALITY_CODE}/{QUALITY}.mp4` | Direct MP4, time-limited token |

### Video Card DOM Selectors

```css
div.v                              → Video card container
a[href^='/view/']                  → Video link (href contains /view/{id})
.v_title                           → Video title
.v_pic                             → Thumbnail img (use data-src for lazy, src for immediate)
.v_dur                             → Duration (e.g. "34:34", "1:22:41")
.v_preview[data-preview]           → Preview clip URL (//prev.xxdbx.com/{ID}3230.mp4)
.v_tags a[href^='/stars/']         → Star/pornstar link
.v_tags a[href^='/channels/']      → Channel/studio link
.v_tags a[href^='/dates/']         → Date link
.pagina a                          → Pagination links
```

### Video Detail Page Selectors

```css
article h1                         → Video title
video#p                            → Video player element
video#p[poster]                    → Poster image URL
video#p source[src]                → Stream URL (direct MP4!)
video#p source[title]              → Quality label ("360p", "720p", "1080p")
.tags a[href^='/search/']          → Genre/category tags (Anal, Hardcore, Gonzo, etc.)
.tags a[href^='/stars/']           → Star/pornstar links
.tags a[href^='/channels/']        → Channel/studio links
#desc                              → Description (optional, may be absent)
```

### Video Source Extraction

**Method: Direct MP4 from `<source>` tags — SIMPLEST POSSIBLE**

1. Fetch `/view/{id}` (the video detail page)
2. Parse HTML with cheerio
3. Find `video#p source` elements
4. Extract `src` (stream URL) and `title` (quality label)
5. Return as direct `url` streams — Stremio plays them natively!

```javascript
// Extraction code for xxdbx.com
async function extractStreams(videoId) {
    const detailUrl = `https://xxdbx.com/view/${videoId}`;
    const html = await fetchPage(detailUrl);
    const $ = cheerio.load(html);
    const streams = [];

    $("video#p source").each((_, el) => {
        const src = $(el).attr("src");
        const quality = $(el).attr("title"); // "360p", "720p", "1080p"
        if (src) {
            streams.push({
                name: "XXDBX",
                title: quality,
                url: src.startsWith("//") ? "https:" + src : src,
                behaviorHints: { notWebReady: false },
            });
        }
    });

    return streams;
}
```

### Stream URL Format

```
https://d.v1d30.com/{TOKEN}/{VIDEO_ID}{QUALITY_CODE}/{QUALITY}.mp4
```

| Part | Example | Description |
|------|---------|-------------|
| CDN host | `d.v1d30.com` | Stream CDN |
| TOKEN | `wp5z_h0Ie5ZX1F89k8Gkc45PQ` | Time-limited, unique per video+quality |
| VIDEO_ID | `22325971` | Base video identifier |
| QUALITY_CODE | `103`, `258`, `786` | Varies per quality (not a simple formula) |
| QUALITY | `360`, `720`, `1080` | Resolution in pixels |

**Always 3 qualities available: 360p, 720p, 1080p**

### Stream Token Behavior

- Tokens are **time-limited** (expire within minutes)
- Each quality gets a **different token**
- Tokens are generated **fresh on each page load**
- The addon must **fetch the video detail page fresh** on each stream request
- Cache the HTML for 5 minutes max — but be aware tokens may expire sooner
- When a token expires, re-fetching the page generates new tokens

### Key Advantages Over Other Sites

1. **No anti-leeching encryption** — unlike KVS sites (thepornbang.com), no generate_mp4() decryption needed
2. **No Cloudflare** — direct HTTP requests work perfectly
3. **Simple HTML** — no SPA, no JavaScript rendering needed
4. **Direct MP4** — streams play natively in Stremio's built-in player
5. **No webview/externalUrl needed** — NO TV BROWSER!
6. **3 quality levels** — 360p, 720p, 1080p always available
7. **No embed page needed** — the main `/view/{id}` page has everything

### Scraping Notes

1. **No Cloudflare** — direct HTTP requests work without browser emulation
2. **Lazy-loaded images** — thumbnails use `data-src` for lazy, `src` for first few images
3. **30 videos per page** — consistent across all listing types
4. **No master category/tag list page** — categories and tags are discovered from video cards
5. **Search doubles as tag browser** — `/search/Anal` shows all "Anal" tagged videos
6. **Stars can have multiple names** — e.g., "Bad Bella" and "Bad Bella XO" are separate star pages
7. **Preview clips are publicly accessible** — `//prev.xxdbx.com/{ID}3230.mp4` returns 200 OK with `video/mp4`

### Thumbnail URL Pattern

| Type | Pattern | Example |
|------|---------|---------|
| Listing thumb | `/{VIDEO_ID}64{SUFFIX}.jpg` | `/2232597164360.jpg` |
| Detail poster | `/{VIDEO_ID}96{SUFFIX}.jpg` | `/2232597196360.jpg` |

The `64` and `96` likely indicate dimensions (640px, 960px width). SUFFIX varies per video.

### Recommended Addon Architecture for xxdbx.com

```
Content Type: curvcorn (custom type, appears as separate section in Discover)

Catalogs:
  - type: curvcorn, id: "xxdbx_home"
    - Browse: / (paginated with ?page=N)
    - Search: /search/{query}
  - type: curvcorn, id: "xxdbx_popular"
    - Browse: /most-popular (paginated)
  - type: curvcorn, id: "xxdbx_stars"
    - Search: extracts unique stars from search results
  - type: curvcorn, id: "xxdbx_channels"
    - Search: extracts unique channels from search results
  - type: curvcorn, id: "xxdbx_tags"
    - Search: fetches video detail to extract search/genre tags

Meta:
  - Video (xxdbx: prefix): /view/{id} → title, poster, genres, cast, links
  - Star (xxdbx_star: prefix): /stars/{name} → name, videos array
  - Channel (xxdbx_channel: prefix): /channels/{name} → name, videos array
  - Tag (xxdbx_tag: prefix): /search/{tag} → name, videos array

Stream:
  - /view/{id} → <video#p><source> → Direct MP4 URLs (3 qualities)
  - Star cross-nav streams: stremio:///detail/curvcorn/xxdbx_star:{slug}
  - Tag cross-nav streams: stremio:///detail/curvcorn/xxdbx_tag:{slug}
```

### Deployment

- **Vercel URL:** https://xxdbx-addon.vercel.app
- **Manifest URL:** https://xxdbx-addon.vercel.app/manifest.json
- **GitHub Repo:** AiCurv/curvcorn-stremio (xxdbx-addon subfolder)
- **Version:** 1.0.0

---

*Last updated: 2026-06-07*
