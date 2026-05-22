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
  6. For stream handlers, use the embed URL directly (externalUrl) instead of scraping if extraction is too slow.
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

## Quick Reference: Error → Fix Lookup

| # | Error | Quick Fix |
|---|-------|-----------|
| 1 | /video/{id}/ 404 | Use /embed/{id}/ |
| 2 | Vercel timeout | Cache, optimize, or use externalUrl |
| 3 | KVS slug required | Use embed URLs or store full URLs |

---

## Platform-Specific Error Rates

| Platform | Known Errors | Risk Level |
|----------|-------------|------------|
| KVS | 2 (Errors #1, #3) | Medium — embed URLs solve most issues |
| Vercel Hobby | 1 (Error #2) | High — 10s timeout is a real constraint |
| WordPress | 0 | Low — standard HTML, easy to scrape |
| Cloudflare-protected | 0 (documented in AGENT_GUIDE) | High — may block requests entirely |

---

*Last updated: 2026-05-22*
