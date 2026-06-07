# Agent Guide: Building Stremio Addons

A step-by-step workflow for AI agents (and humans) to build Stremio addons from scratch. Follow these steps in order.

---

## Overview

Building a Stremio addon is a systematic process:

1. **Analyze** the target site
2. **Map** its structure
3. **Extract** video sources
4. **Build** the addon
5. **Deploy** to Vercel
6. **Document** findings

---

## ⚠️ MANDATORY COMPLIANCE CHECKLIST — READ BEFORE BUILDING

Before you write ANY code for a Stremio addon, you MUST read and agree to follow these rules. If you skip any of these, your addon will be BROKEN or INCOMPLETE. These are NOT suggestions — they are REQUIREMENTS.

### Pre-Build Requirements

- [ ] **Read KNOWLEDGE_BASE.md Sections 10, 11, and 12** before writing any handler code
- [ ] **Understand the difference between `meta.links` and `stream.externalUrl`** — they serve DIFFERENT purposes and appear in DIFFERENT parts of Stremio's UI
- [ ] **Identify all navigable entities** on the target site (stars, models, channels, tags, categories, dates) — each one MUST be a `channel` type with its own ID prefix

### Build Requirements

- [ ] **Use `channel` + `movie` types** — NEVER use custom types like "curvcorn" (breaks library + cross-navigation)
- [ ] **Add `externalUrl` navigation streams** in the stream handler for EVERY navigable entity (stars, channels, tags) — this is NOT optional, it's the #1 feature users want
- [ ] **Add `meta.links`** in the meta handler for cross-navigation on the detail page
- [ ] **Scope DOM selectors** to the video's own metadata section only — NEVER use broad selectors like `$("a")` or `$("a[href*='/models/']")` on video pages (picks up related/suggested content)
- [ ] **Limit navigation streams** to 10 tags max, 10 stars max, 5 channels max — prevents clutter from related section pollution
- [ ] **Test the stream endpoint** — verify `/stream/movie/video_{id}.json` returns BOTH playable streams AND navigation streams

### Post-Build Verification

- [ ] **`/manifest.json`** returns valid manifest with `channel` + `movie` types
- [ ] **`/catalog/channel/{id}.json`** returns channel metas (stars, channels, tags)
- [ ] **`/meta/channel/star_{id}.json`** returns a `videos` array (not empty)
- [ ] **`/meta/movie/video_{id}.json`** returns video meta with `links` array
- [ ] **`/stream/movie/video_{id}.json`** returns playable streams AND navigation `externalUrl` streams
- [ ] **Navigation streams use `stremio:///detail/channel/` deep links** — NOT `stremio:///detail/movie/`
- [ ] **Clicking a navigation stream opens a channel page** with a video list

### ❌ COMMON MISTAKE: Only implementing meta.links

**This is the #1 mistake AI agents make.** They add `links` to the meta handler but forget to add `externalUrl` streams. The result: users can see links on the detail page but NOT in the streams list, which is where they spend 95% of their time.

```
WRONG: Only meta.links → users can't navigate from streams list
RIGHT: BOTH meta.links AND stream.externalUrl → users can navigate from everywhere
```

If you only implement one, implement the STREAM NAVIGATION. It's 10x more useful than meta links.

---

## Step 1: Check Target Site for Cloudflare

**Why:** Cloudflare-protected sites will block your HTTP requests. You need to know this before investing time in scraping.

### How to Check

```bash
# Check response headers for Cloudflare indicators
curl -sI https://target-site.com | head -20

# Look for these headers:
#   server: cloudflare
#   cf-ray: ...
#   cf-cache-status: ...
```

### Decision Matrix

| Cloudflare Status | Action |
|-------------------|--------|
| **No Cloudflare** | Proceed to Step 2. Direct HTTP requests will work. |
| **Cloudflare (JS Challenge only)** | Try with proper headers. May work from server-side. If blocked, consider using a headless browser or different approach. |
| **Cloudflare (Under Attack Mode)** | Cannot scrape directly. Look for API endpoints, RSS feeds, or alternative data sources. May not be feasible. |

### Headers That Help Bypass Mild Protection

```javascript
const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
};
```

---

## Step 2: Identify Site Platform

**Why:** Platform determines URL patterns, extraction methods, and common pitfalls.

### Detection Checklist

1. **Check `<meta name="generator">`** tag in the HTML source
2. **Check URL patterns** — compare against known patterns in SITE_PATTERNS.md
3. **Check JavaScript globals** — KVS sites have `kt_player`, WordPress has `wp`
4. **Check asset paths** — `wp-content` indicates WordPress, KVS has specific paths
5. **Check the page source** for platform signatures

### Common Platforms

| Platform | Key Indicators | Difficulty |
|----------|---------------|------------|
| **KVS** (Kernel Video Sharing) | `/video/{id}/{slug}/`, `/embed/{id}/`, `kt_player` | Medium — slug requirement, but embed URLs work |
| **WordPress** | `wp-content`, `wp-json`, `<meta name="generator" content="WordPress">` | Easy — usually clean HTML, often has REST API |
| **Custom** | None of the above | Varies — need manual analysis |
| **AVS** (Adult Video Script) | `/video/{slug}/`, specific JS patterns | Medium — similar to KVS but different structure |

---

## Step 3: Map Site Structure

**Why:** You need to know what pages exist and how they're organized before you can scrape them.

### What to Map

#### 3a. Content Organization

- [ ] **Models/Channels:** URL pattern for listing and individual pages
- [ ] **Categories:** URL pattern for category browsing
- [ ] **Videos:** URL pattern for video pages and embed pages
- [ ] **Search:** URL pattern and query parameter format
- [ ] **Pagination:** How are pages numbered? (page parameter, skip offset, etc.)

#### 3b. Page Structure (for each page type)

- [ ] **Listing pages:** What HTML elements contain the items? (class names, structure)
- [ ] **Detail pages:** Where is the title, description, poster, video player?
- [ ] **Embed pages:** Where is the `<video>` tag? What attributes contain the URL?

#### 3c. Mapping Template

Fill this out for each new site:

```markdown
## Site: [domain]
- **Platform:** [KVS / WordPress / Custom]
- **Cloudflare:** [Yes / No]

### URL Map
- Models list: [URL pattern]
- Model detail: [URL pattern]
- Video page: [URL pattern]
- Embed page: [URL pattern]
- Search: [URL pattern]
- Categories: [URL pattern]

### HTML Selectors
- Model name: [selector]
- Model poster: [selector]
- Video title: [selector]
- Video poster/thumbnail: [selector]
- Video source: [selector]

### Pagination
- Method: [page number / offset / infinite scroll]
- URL format: [pattern]
- Items per page: [number]
```

---

## Step 4: Find Video Source Extraction Method

**Why:** This is the core of your addon. You need to reliably extract playable video URLs.

### Extraction Methods (in order of preference)

#### Method 1: Direct MP4 from Embed Page (Best)

```javascript
const html = await fetchPage(`https://site.com/embed/${videoId}/`);
const $ = cheerio.load(html);

const videoUrl = $('video source').attr('src');
```

**Pros:** Simple, reliable, direct URL.
**Cons:** Not all sites have embed pages.

#### Method 2: JavaScript Variable Extraction (flashvars)

```javascript
const html = await fetchPage(pageUrl);
const $ = cheerio.load(html);

const scripts = $('script').text();
const match = scripts.match(/video_url\s*[:=]\s*["']([^"']+)["']/);
const videoUrl = match ? match[1] : null;
```

**Pros:** Works when video URL is in JS, not in HTML. Common in KVS platforms.
**Cons:** Pattern varies between sites; may need regex tuning.

#### Method 3: User-Agent Redirect Discovery (KVS get_stream)

Some KVS sites use `/get_stream/` URLs that behave differently based on User-Agent:
- **Browser UA** → returns 200 HTML (player page)
- **Non-browser UA** (Stremio's player) → returns 302 redirect to CDN

```javascript
// Extract get_stream URLs from flashvars
const match = scripts.match(/video_url\s*[:=]\s*["']([^"']+)["']/);
if (match) {
    streams.push({
        url: match[1],  // Return as direct stream.url
        title: '1080p FHD',
    });
}
// Stremio's player uses a non-browser UA → server returns 302 → CDN → native playback!
```

**Pros:** Native playback in Stremio, no browser/webview needed.
**Cons:** Requires testing User-Agent behavior to confirm the redirect.

**How to test:**
```bash
# Browser UA → 200 HTML
curl -sI -H "User-Agent: Mozilla/5.0" "https://target.com/get_stream/123-480.mp4?md5=..."
# Stremio UA → 302 redirect
curl -sI -H "User-Agent: Stremio" "https://target.com/get_stream/123-480.mp4?md5=..."
```

#### Method 4: M3U8 from Player Config

```javascript
const match = scripts.match(/hls["']?\s*[:=]\s*["']([^']+\.m3u8[^"']*)["']/);
const m3u8Url = match ? match[1] : null;
```

**Pros:** HLS streams are often higher quality with adaptive bitrate.
**Cons:** Requires `notWebReady: true` in Stremio stream object.

#### Method 5: API Endpoint Discovery

```javascript
const apiUrl = `https://site.com/api/video/${videoId}`;
const response = await fetch(apiUrl);
const data = await response.json();
const videoUrl = data.video_url || data.files?.hls || data.files?.mp4;
```

**Pros:** Clean data, no HTML parsing needed.
**Cons:** Undocumented APIs may change or require authentication.

### ⚠️ NEVER Use `externalUrl` for Video Streams

**`externalUrl` opens a browser/webview — users HATE this.** Before giving up on extracting a direct URL:
1. Test the URL with different User-Agents (Method 3 above)
2. Check if the URL triggers a redirect when accessed with a non-browser UA
3. Look for flashvars or JavaScript variables containing stream URLs
4. The ONLY acceptable use of `externalUrl` is for **cross-navigation within Stremio** using `stremio:///` deep links

### Extraction Decision Tree

```
Start → Is there an embed page?
  ├─ Yes → Can you extract MP4/M3U8 from it?
  │   ├─ Yes → Use Method 1 or 4
  │   └─ No → Is there a JS variable with the URL?
  │       ├─ Yes → Use Method 2
  │       └─ No → Check User-Agent redirect behavior (Method 3)
  └─ No → Check the video page itself
      ├─ JS variable with URL? → Use Method 2
      ├─ get_stream URL? → Test with non-browser UA (Method 3)
      ├─ API endpoint? → Use Method 5
      └─ None of the above → Site may not be feasible
```

---

## Step 5: Build Addon Using Templates

**Why:** Use proven templates from KNOWLEDGE_BASE.md to avoid common mistakes.

### Build Checklist

1. [ ] Copy `addon.js` template from KNOWLEDGE_BASE.md
2. [ ] Update `SITE_BASE` and `ADDON_ID` constants
3. [ ] Update `manifest` with correct catalogs and content types
4. [ ] Implement `parseSearchResults()`, `parseModelList()`, `parseVideoList()`
5. [ ] Implement meta handlers (channel with videos array, movie)
6. [ ] Implement stream handler using the extraction method from Step 4
7. [ ] Test locally with `node addon.js`
8. [ ] Create `api/index.js` from template
9. [ ] Create `vercel.json` from template
10. [ ] Create `package.json` from template
11. [ ] Run `npm install` to verify dependencies

### Local Testing

```bash
# Install dependencies
npm install

# Run addon locally (starts HTTP server)
node addon.js

# Test endpoints
curl http://localhost:7000/manifest.json
curl http://localhost:7000/catalog/channel/models.json
curl "http://localhost:7000/catalog/channel/models.json?search=test"
curl http://localhost:7000/meta/channel/myaddon_slug.json
curl http://localhost:7000/stream/channel/myaddon_videoid.json
```

---

## Step 6: Deploy to Vercel

**Why:** Vercel provides free hosting with HTTPS, which is required for Stremio addon URLs.

### Deployment Steps

```bash
# Install Vercel CLI (if not already installed)
npm install -g vercel

# Login to Vercel
vercel login

# Deploy from the project root
cd /path/to/your/addon
vercel --prod

# Your addon URL will be something like:
# https://my-stremio-addon.vercel.app
```

### Post-Deployment Verification

1. [ ] Visit `https://your-addon.vercel.app/manifest.json` — should return valid JSON
2. [ ] Visit `https://your-addon.vercel.app/catalog/channel/models.json` — should return metas
3. [ ] Add the addon URL to Stremio: `https://your-addon.vercel.app/manifest.json`
4. [ ] Browse the catalog in Stremio
5. [ ] Play a video to verify stream extraction works

### Vercel Configuration Tips

- **Hobby plan:** 10-second function timeout, 100GB bandwidth/month
- **Pro plan:** 60-second function timeout, 1TB bandwidth/month
- **Set region** in `vercel.json` for lower latency: `"regions": ["iad1"]`
- **Use environment variables** for secrets: `vercel env add`

---

## Step 7: Update Knowledge Base with New Findings

**Why:** Every new site teaches us something. Document it to make the next addon faster.

### What to Update

1. **SITE_PATTERNS.md** — Add the new site's structure and extraction method
2. **ERRORS_DB.md** — Add any new errors you encountered
3. **KNOWLEDGE_BASE.md** — Update templates if you found a new pattern
4. **agent-index.json** — Update errors_quick and any new version requirements
5. **update.sh** — Run the auto-update script to timestamp the changes

### Update Checklist

```markdown
- [ ] Site pattern documented in SITE_PATTERNS.md
- [ ] New errors added to ERRORS_DB.md
- [ ] Templates updated in KNOWLEDGE_BASE.md if needed
- [ ] agent-index.json updated if needed
- [ ] Changes committed and pushed to GitHub
```

---

## Quick Reference: Common Patterns

### KVS Platform Sites

```
1. Check Cloudflare → usually no
2. Map: /models/{slug}/, /video/{id}/{slug}/, /embed/{id}/, /search/?q=
3. Extract: embed page → <video><source> → MP4 URL
   OR: flashvars → get_stream URLs → test with non-browser UA → direct stream.url
4. Build: channel type for models, movie type for standalone videos
5. Gotcha: video page needs slug, use embed instead
6. Gotcha: get_stream URLs may work via User-Agent redirect even if they trigger downloads in browser
```

### WordPress Sites

```
1. Check Cloudflare → varies
2. Map: look for /category/, /tag/, search, /page/2/
3. Extract: check for REST API at /wp-json/ first, then HTML scraping
4. Build: depends on content structure
5. Gotcha: some themes use JavaScript rendering, may need headless browser
```

### Cloudflare-Protected Sites

```
1. Detection: check response headers
2. Options:
   a. Try with full browser headers (may work for JS challenge only)
   b. Look for API endpoints that bypass CF
   c. Use RSS feeds if available
   d. Consider if the site is feasible at all
3. If blocked: document it and move to the next site
```

---

*Last updated: 2026-06-07*
