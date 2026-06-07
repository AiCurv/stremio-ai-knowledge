# Errors Database

A living database of errors encountered during Stremio addon development. Each entry documents the error, its root cause, and the proven fix.

---

## How to Use This Database

1. **Before building a new addon**, scan this database for known issues with the target platform.
2. **When you hit an error**, check here first before debugging.
3. **When you find a new error**, add it here following the format below.

### Entry Format

```
### ERROR #N: [Short Title]
- **Context:** Where/when this error occurs
- **Symptom:** What you see (error message, behavior)
- **Root Cause:** Why it happens
- **Fix:** Proven solution
- **Prevention:** How to avoid it in the future
```

---

### ERROR #1: /video/{id}/ without slug returns 404

- **Context:** KVS (Kernel Video Sharing) platform sites. Attempting to fetch video pages using only the numeric ID.
- **Symptom:** HTTP 404 Not Found when requesting `https://example.com/video/12345/`. The page simply does not exist at this URL.
- **Root Cause:** KVS requires the URL slug after the ID. The full URL format is `/video/{id}/{slug}/`. Without the slug, the server returns 404. This is a server-side routing requirement, not a bug.
- **Fix:** Use `/embed/{id}/` instead. The embed URL works with just the numeric ID and does not require the slug. Example: `https://example.com/embed/12345/` returns the video player page successfully.
- **Prevention:** Always use embed URLs for stream extraction on KVS sites. If you need the video page metadata (title, description, poster), store the full URL (including slug) in your catalog/meta data, or fetch it from the model/channel page where full URLs are available.

---

### ERROR #2: Vercel serverless function timeout (10s default on hobby)

- **Context:** Vercel Hobby (free) plan deployments. Addons making multiple HTTP requests or scraping complex pages.
- **Symptom:** The addon works locally but returns 504 Gateway Timeout on Vercel after ~10 seconds. Some catalog pages load, others time out. Stream extraction may fail for slow sites.
- **Root Cause:** Vercel Hobby plan enforces a 10-second execution limit on serverless functions. If your handler takes longer than 10 seconds (including all HTTP requests, HTML parsing, etc.), Vercel terminates the function.
- **Fix:**
  1. Keep handlers fast — minimize the number of HTTP requests per handler call.
  2. Cache responses where possible using a simple in-memory cache or Vercel KV.
  3. Set `maxDuration: 10` in `vercel.json` (already the max for Hobby).
  4. Consider upgrading to Vercel Pro for 60-second timeout.
  5. For catalog handlers, return results immediately even if some items are incomplete — Stremio will request more.
- **Prevention:** Test with Vercel's timeout in mind from the start. Use `vercel dev` locally to simulate serverless conditions. Time your handlers and optimize the slow ones before deploying.

---

### ERROR #3: KVS sites need slug in video URLs

- **Context:** Any KVS (Kernel Video Sharing) platform site. Storing or constructing video URLs for meta/stream handlers.
- **Symptom:** 404 errors when trying to access video pages. The video exists on the site but your addon cannot reach it because the URL is incomplete.
- **Root Cause:** KVS video page URLs follow the pattern `/video/{id}/{slug}/`. The slug is derived from the video title and is required by the server's URL routing. You cannot skip it. However, the embed URL `/embed/{id}/` does NOT require the slug.
- **Fix:**
  1. **Best approach:** Use embed URLs (`/embed/{id}/`) for stream extraction. They work with just the numeric ID.
  2. **Alternative:** Store the full video URL (including slug) in the catalog/meta data. When scraping model pages, extract the complete `href` from video links and save it.
  3. **If you must construct the URL:** You can try to derive the slug from the video title by converting it to a URL-safe string (lowercase, spaces to hyphens, remove special characters), but this is fragile and may break if the site changes slug generation.
- **Prevention:** When scraping model/channel pages, always extract and store the full video URL. Do not try to reconstruct it later. The embed URL is the safest fallback.

---

### ERROR #4: defaultVideoId causes infinite back-loop in Stremio

- **Context:** Stremio addon using `channel` type for model/creator pages. Setting `behaviorHints.defaultVideoId` in the meta response.
- **Symptom:** When user clicks on a channel detail page, Stremio auto-navigates to play one video. Pressing Back returns to the channel page, which immediately auto-navigates again. User is stuck in an infinite loop and cannot browse the video list.
- **Root Cause:** `behaviorHints.defaultVideoId` tells Stremio to auto-open a specific video's streams when the detail page loads. Combined with Stremio's `guessStream: true` flag in `useMetaDetails`, this creates: detail page → auto-play video → press back → detail page reloads → auto-play video → infinite loop.
- **Fix:** DO NOT set `defaultVideoId` in channel meta responses. Remove it entirely:
  ```javascript
  // WRONG — causes infinite back loop:
  const meta = {
      id: "model_kwini-kim",
      type: "channel",
      videos: [...],
      behaviorHints: { defaultVideoId: "video_12345" }  // REMOVE THIS
  };

  // CORRECT — no defaultVideoId, user clicks videos manually:
  const meta = {
      id: "model_kwini-kim",
      type: "channel",
      videos: [...],
      // NO behaviorHints.defaultVideoId
  };
  ```
- **Prevention:** Never use `defaultVideoId` for channel type content. It was designed for movie type (where there's one implicit video) but causes navigation loops in channel type. Let users click videos from the list manually.

---

### ERROR #5: Meta `links` field enables clickable cross-navigation in Stremio

- **Context:** Stremio video detail pages. User wants to click on model/tag links to navigate to their dedicated pages.
- **Symptom:** Video detail pages show no clickable links for models or tags. User cannot navigate to model pages or tag pages from a video they're watching.
- **Root Cause:** The `links` field in the meta response was not being populated. Stremio's `links` array is the official way to add clickable navigation links on detail pages.
- **Fix:** Add the `links` array to your movie-type meta response with `stremio:///detail/` deep link URLs:
  ```javascript
  const meta = {
      id: "video_12345",
      type: "movie",
      name: "Video Title",
      links: [
          { name: "Kwini Kim", category: "Models", url: "stremio:///detail/channel/model_kwini-kim" },
          { name: "Asian", category: "Categories", url: "stremio:///detail/channel/cat_asian" },
          { name: "petite", category: "Tags", url: "stremio:///detail/channel/tag_petite" },
      ]
  };
  ```
  Stremio deep link URL formats:
  - `stremio:///detail/{type}/{id}` — Navigate to another meta item's detail page
  - `stremio:///detail/{type}/{id}/{videoId}` — Navigate to a specific video within a series/channel
  - `stremio:///search?search={query}` — Open the search page with a query
  - `stremio:///discover/{encodedManifestUrl}/{type}/{catalogId}?{extra}` — Open a specific catalog filtered
  Links are grouped visually by `category` in Stremio's UI.
- **Prevention:** Always populate the `links` field for movie-type meta. Stremio routes `stremio:///detail/` deep links to the appropriate addon based on `idPrefixes` in the manifest.

---

### ERROR #6: Model page videos not sorted by date (random order)

- **Context:** KVS model pages. When user opens a model's channel page in Stremio, videos appear in random order instead of newest first.
- **Symptom:** User has to scroll through many old videos to find the newest content.
- **Root Cause:** KVS model pages default to a non-chronological sort.
- **Fix:** Append `?sort_by=post_date` to the model page URL:
  ```javascript
  const modelUrl = `${BASE_URL}/models/${slug}/?sort_by=post_date`;
  const pUrl = `${BASE_URL}/models/${slug}/${page}/?sort_by=post_date`;
  ```
  Available KVS sort options: `post_date`, `video_viewed`, `rating`, `duration`, `most_commented`, `most_favourited`, `video_viewed_today`
- **Prevention:** Always use explicit sort parameters when scraping model/channel pages.

---

### ERROR #7: Video dates all show the same (today's date)

- **Context:** Stremio channel video list. The `released` field.
- **Symptom:** All videos show the same date, making it impossible to tell which is newer.
- **Root Cause:** KVS sites don't expose publication dates on video cards. Using `new Date().toISOString()` gives all videos the same date.
- **Fix:** Use video IDs as date proxy. KVS uses auto-incrementing IDs, so higher = newer:
  ```javascript
  function videoIdToDate(videoId) {
      const id = parseInt(videoId);
      const baseDate = new Date("2020-01-01").getTime();
      const msPerId = (6.4 * 365.25 * 24 * 60 * 60 * 1000) / 500000;
      return new Date(baseDate + id * msPerId).toISOString();
  }
  ```
  Adjust calibration constants based on your target site's ID range.
- **Prevention:** Never use `new Date().toISOString()` for all videos.

---

### ERROR #8: Embed page canonical URL gives full video page for tag extraction

- **Context:** KVS sites. Need tags/models/categories from a video page but only have the embed URL.
- **Symptom:** Video meta handler can only get basic info from embed page. No model/tag links.
- **Root Cause:** Embed page is minimal - no tag/category links. Full video page needs slug which we don't have.
- **Fix:** The embed page contains `<link rel="canonical">` pointing to the full video page:
  ```javascript
  const embedHtml = await fetchPage(`${BASE_URL}/embed/${videoId}/`);
  const e$ = cheerio.load(embedHtml);
  const canonicalUrl = e$('link[rel="canonical"]').attr('href');
  if (canonicalUrl) {
      const fullHtml = await fetchPage(canonicalUrl);
      // Extract models, categories, tags from full page
  }
  ```
- **Prevention:** Always check for canonical URLs when scraping embed pages.

---

### ERROR #9: KVS /get_stream/ URLs — User-Agent redirect discovery enables native MP4 playback (v2.0.0 Fix)

- **Context:** KVS (Kernel Video Sharing) sites like thepornbang.com. The `/get_stream/{videoId}-{quality}.mp4?md5=...&timestamp=...` URLs.
- **Symptom (v1.x):** Stremio showed "none of the available extractors" error. The `/get_stream/` URLs triggered file downloads in browsers instead of streaming. The old v1.x implementation used `externalUrl` (proxy player page), which opened a browser/webview — users HATED this experience.
- **Root Cause — The Misunderstanding:** We initially assumed `/get_stream/` was an encrypted anti-leeching system because:
  1. Browsers received `200 HTML` (a player page) instead of video
  2. `curl` with default UA received `200 HTML`
  3. The URLs triggered file downloads in browsers
  
  **The real behavior** is that `/get_stream/` is a **User-Agent-based redirect gateway**:
  - **Browser UA** → server returns `200 HTML` (player page)
  - **Non-browser/media-player UA** → server returns `302 redirect` → CDN (vkuser.net)
  
  The CDN serves proper MP4 files with `Content-Type: video/mp4`, `Accept-Ranges: bytes`, `206 Partial Content` support, and `Content-Length` headers.

- **Key Discovery — Stremio's Player UA:** Stremio's internal media player uses its own User-Agent (not a browser UA) when requesting stream URLs. This means:
  1. Addon returns `stream.url` with the `/get_stream/` URL (with auth params)
  2. Stremio's player requests the URL with its non-browser UA
  3. ThePornBang returns `302 → CDN redirect`
  4. CDN serves the MP4 with proper streaming headers
  5. **Video plays natively in Stremio — NO browser, NO webview!**

- **User-Agent Redirect Behavior Table:**

  | User-Agent | Response |
  |---|---|
  | Browser (Chrome, Firefox, etc.) | 200 HTML (player page) |
  | "Stremio" UA | 302 → CDN redirect ✓ |
  | Android stagefright UA | 302 → CDN redirect ✓ |
  | VLC UA | 200 HTML |
  | ffmpeg UA | 200 HTML |
  | curl default UA | 200 HTML |
  | No UA / empty UA | 200 or 302 (inconsistent) |

- **Fix (v2.0.0):** Extract `get_stream` URLs from the page's `flashvars` JavaScript and return them as direct `url` streams:
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
  
  **Fallback:** If direct URLs don't work, use the `/stream-proxy/` endpoint which uses a "Stremio" UA to resolve the redirect server-side and returns a 302 to the CDN URL.

- **What NOT To Do:**
  1. ❌ NEVER use `externalUrl` for video streams — it opens a browser/webview
  2. ❌ NEVER assume MP4 URLs that trigger downloads in browsers are unplayable — check User-Agent behavior
  3. ❌ NEVER strip auth parameters (md5, timestamp) from `/get_stream/` URLs — they're required
  4. ❌ The `Content-Disposition: attachment` header on the CDN does NOT prevent Stremio from playing the stream

- **Detection test:**
  ```bash
  # Test with different User-Agents:
  # Browser UA → 200 HTML
  curl -sI -H "User-Agent: Mozilla/5.0" "https://target.com/get_stream/123-480.mp4?md5=...&timestamp=..."
  # Stremio UA → 302 redirect
  curl -sI -H "User-Agent: Stremio" "https://target.com/get_stream/123-480.mp4?md5=...&timestamp=..."
  ```
- **Prevention:** Always test stream URLs with Stremio's actual User-Agent, not just browser or curl. The server may behave differently based on UA. Never assume a URL is unplayable just because it triggers a download in a browser.

---

### ERROR #10: Cloudflare-protected target sites block server-side scraping

- **Context:** Sites like hdthot.com that are behind Cloudflare's JavaScript challenge.
- **Symptom:** Server-side fetch (node-fetch, curl without proper headers) returns HTTP 403 with Cloudflare challenge page. The addon works in browser but fails on Vercel.
- **Root Cause:** Cloudflare requires JavaScript execution to solve a challenge before serving content. Server-side Node.js fetch cannot execute JavaScript.
- **Fix:** Avoid Cloudflare-protected sites entirely. If you must use one:
  1. Try using proper browser-like headers (User-Agent, Accept-Encoding: identity, Connection: keep-alive)
  2. Use a CORS proxy as fallback (api.allorigins.win)
  3. As last resort, use FlareSolverr or similar Cloudflare-solving proxy
  For our case, switching from hdthot.com (Cloudflare) to thepornbang.com (accessible) was the correct solution.
- **Prevention:** Always test target site accessibility before building an addon:
  ```bash
  curl -sI -H "Accept-Encoding: identity" -H "User-Agent: Mozilla/5.0" "https://target.com/"
  # If you see "server: cloudflare" + 403 → site is Cloudflare-protected
  # If you see 200 + proper HTML → site is accessible
  ```

---

## Quick Reference: Error → Fix Lookup

| # | Error | Quick Fix |
|---|-------|-----------|
| 1 | /video/{id}/ 404 | Use /embed/{id}/ |
| 2 | Vercel timeout | Cache, optimize, minimize HTTP requests |
| 3 | KVS slug required | Use embed URLs or store full URLs |
| 4 | defaultVideoId back loop | Remove defaultVideoId from channel meta |
| 5 | No clickable model/tag links | Add `links` array with stremio:///detail/ deep links |
| 6 | Videos not sorted by date | Add ?sort_by=post_date to model page URLs |
| 7 | All video dates same | Use videoId as date proxy with calibration |
| 8 | Can't get tags from embed | Use canonical link from embed page |
| 9 | KVS /get_stream/ "error 1" or "none of the available extractors" | Use direct `url` streams with get_stream URLs — Stremio's UA triggers 302 CDN redirect. NEVER use externalUrl. |
| 10 | Cloudflare blocks scraping | Switch target or use Cloudflare-solving proxy |

---

## Platform-Specific Error Rates

| Platform | Known Errors | Risk Level |
|----------|-------------|------------|
| KVS | 6 (Errors #1, #3, #6, #7, #8, #9) | Medium — embed URLs + direct streams + sort params solve most issues |
| Vercel Hobby | 1 (Error #2) | High — 10s timeout is a real constraint |
| WordPress | 0 | Low — standard HTML, easy to scrape |
| Cloudflare-protected | 1 (Error #10) | High — may block requests entirely |

---

*Last updated: 2026-06-07*
