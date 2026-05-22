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

*Last updated: 2026-05-22*
