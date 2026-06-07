# AI Agent Prompt Template for Stremio Addon Development

Use this prompt when asking an AI agent to build a Stremio addon. Copy the template below, fill in the site-specific details, and provide it to the AI agent along with this knowledge base.

---

## Universal Prompt Template

```
You are an expert Stremio addon developer. Your task is to build a complete, production-ready Stremio addon for the following site.

## Target Site
- **URL:** [SITE_URL]
- **Platform:** [KVS / WordPress / Custom / Unknown — leave as "Unknown" if not sure]
- **Cloudflare:** [Yes / No / Unknown — leave as "Unknown" if not sure]

## Requirements
1. Build a Stremio addon using `stremio-addon-sdk` (^1.6.10), `cheerio` (^1.0.0), and `node-fetch` (^2.7.0)
2. Deploy to Vercel as a serverless function
3. Use the following knowledge base for patterns and templates: https://github.com/AiCurv/stremio-ai-knowledge

## Content Structure
- **Content type for models/collections:** channel (with videos array in meta handler)
- **Content type for standalone videos:** movie
- **Catalogs needed:** [list catalogs, e.g., "Models", "Videos", "Categories"]

## Known Site Patterns (if any)
- Model pages: [URL pattern, e.g., /models/{slug}/]
- Video pages: [URL pattern, e.g., /video/{id}/{slug}/]
- Embed pages: [URL pattern, e.g., /embed/{id}/]
- Search: [URL pattern, e.g., /search/?q=]
- Categories: [URL pattern, e.g., /categories/{slug}/]
- Pagination: [how pages work, e.g., /models/{slug}/{page}/]

## Video Source Extraction
- **Method:** [Direct MP4 / M3U8 / Flashvars get_stream / Unknown]
- **Known selectors:** [e.g., "video source tag on embed page"]
- **Known gotchas:** [e.g., "video page needs slug, use embed URL instead"]
- **User-Agent redirect:** [Yes/No — does the site use UA-based redirect for stream URLs?]

## Files to Generate
1. `addon.js` — Main addon logic with all handlers (catalog, meta, stream)
2. `api/index.js` — Vercel serverless entry point
3. `vercel.json` — Vercel configuration with rewrites
4. `package.json` — Dependencies

## Rules
- Use `node-fetch` v2.x (CommonJS), NOT v3.x (ESM)
- Use `cheerio` v1.0.0+ (not 0.x)
- For KVS sites: ALWAYS use `/embed/{id}/` for stream extraction, NEVER `/video/{id}/{slug}/`
- For channel types: meta handler MUST return a `videos` array
- Stream handler: ALWAYS extract direct video URLs (MP4 or M3U8) as `stream.url`. NEVER use `externalUrl` for video playback — it opens a browser/webview and users hate it.
- If a stream URL appears to trigger a download in browser, test it with a non-browser User-Agent (e.g., "Stremio") — the server may return a 302 redirect to a CDN for non-browser UAs.
- The ONLY acceptable use of `externalUrl` is for cross-navigation within Stremio using `stremio:///detail/` deep links (e.g., navigating from a video to a model page).
- All poster/background URLs must be absolute (prepend site base URL if relative)
- The `id` in returned meta objects MUST match the `id` that was requested
- Keep Vercel serverless function under 10 seconds execution time
- Add proper error handling with try/catch in every handler
- Add proper CORS headers in the serverless entry point
- Use a proper User-Agent header in all HTTP requests
- NEVER strip auth parameters (md5, timestamp, etc.) from stream URLs

## Addon Identity
- **Addon ID:** community.[name]
- **ID Prefix:** [prefix]_
- **Addon Name:** [Human-readable name]

## Output Format
Provide all files as complete, production-ready code blocks. Do not use placeholders or TODOs.
```

---

## Example: Filled-in Prompt for w1mp.com

```
You are an expert Stremio addon developer. Your task is to build a complete, production-ready Stremio addon for the following site.

## Target Site
- **URL:** https://w1mp.com
- **Platform:** KVS (Kernel Video Sharing)
- **Cloudflare:** No

## Requirements
1. Build a Stremio addon using `stremio-addon-sdk` (^1.6.10), `cheerio` (^1.0.0), and `node-fetch` (^2.7.0)
2. Deploy to Vercel as a serverless function
3. Use the following knowledge base for patterns and templates: https://github.com/AiCurv/stremio-ai-knowledge

## Content Structure
- **Content type for models:** channel (with videos array in meta handler)
- **Content type for standalone videos:** movie
- **Catalogs needed:** Models (channel type, searchable), Videos (movie type, searchable)

## Known Site Patterns
- Model pages: /models/{slug}/ (paginated: /models/{slug}/{page}/)
- Video pages: /video/{id}/{slug}/ (slug REQUIRED)
- Embed pages: /embed/{id}/ (works without slug)
- Search: /search/?q={query}
- Categories: /categories/{slug}/
- Pagination: /models/{slug}/{page}/ — page 1 has no page number

## Video Source Extraction
- **Method:** Direct MP4 from embed page
- **Known selectors:** <video><source> tag on /embed/{id}/ page
- **Known gotchas:** Video page (/video/{id}/) without slug returns 404 — always use embed URL. v-acctoken is base64-encoded and time-limited.
- **User-Agent redirect:** No

## Files to Generate
1. `addon.js` — Main addon logic with all handlers (catalog, meta, stream)
2. `api/index.js` — Vercel serverless entry point
3. `vercel.json` — Vercel configuration with rewrites
4. `package.json` — Dependencies

## Rules
- Use `node-fetch` v2.x (CommonJS), NOT v3.x (ESM)
- Use `cheerio` v1.0.0+ (not 0.x)
- For KVS sites: ALWAYS use `/embed/{id}/` for stream extraction, NEVER `/video/{id}/{slug}/`
- For channel types: meta handler MUST return a `videos` array
- Stream handler: ALWAYS extract direct video URLs (MP4 or M3U8) as `stream.url`. NEVER use `externalUrl` for video playback.
- All poster/background URLs must be absolute (prepend site base URL if relative)
- The `id` in returned meta objects MUST match the `id` that was requested
- Keep Vercel serverless function under 10 seconds execution time
- Add proper error handling with try/catch in every handler
- Add proper CORS headers in the serverless entry point
- Use a proper User-Agent header in all HTTP requests

## Addon Identity
- **Addon ID:** community.w1mp
- **ID Prefix:** w1mp_
- **Addon Name:** W1MP

## Output Format
Provide all files as complete, production-ready code blocks. Do not use placeholders or TODOs.
```

---

## Example: Filled-in Prompt for thepornbang.com (KVS with User-Agent Redirect)

```
You are an expert Stremio addon developer. Your task is to build a complete, production-ready Stremio addon for the following site.

## Target Site
- **URL:** https://www.thepornbang.com
- **Platform:** KVS (Kernel Video Sharing) — with User-Agent redirect gateway
- **Cloudflare:** Behind CDN but accessible with proper headers

## Requirements
1. Build a Stremio addon using `stremio-addon-sdk` (^1.6.10), `cheerio` (^1.0.0), and `node-fetch` (^2.7.0)
2. Deploy to Vercel as a serverless function
3. Use the following knowledge base for patterns and templates: https://github.com/AiCurv/stremio-ai-knowledge

## Content Structure
- **Content type for models/tags/categories:** channel (with videos array)
- **Content type for standalone videos:** movie
- **Catalogs needed:** Home, Popular, Top Rated, Categories, Models, Channels, Tags, Search

## Known Site Patterns
- Video pages: /video/{slug}_v{id}/
- Stream URLs: /get_stream/{contentId}-{quality}.mp4?md5=...&timestamp=...
- Model pages: /pornstar/{slug}_p{id}/{page}/
- Category pages: /category/{slug}_c{id}/{page}/
- Tag pages: /tag/{slug}_t{id}/{page}/
- Studio pages: /studio/{slug}_s{id}/{page}/
- Search: /search/{query}/{page}/
- Pagination: /{entity}/{slug}_{type}{id}/{page}/

## Video Source Extraction
- **Method:** Flashvars get_stream extraction with User-Agent redirect
- **How it works:** Extract /get_stream/ URLs from page flashvars. Return as stream.url. Stremio's non-browser UA triggers 302 redirect to CDN → native MP4 playback.
- **User-Agent redirect:** YES — browser UA gets 200 HTML, Stremio UA gets 302 → CDN
- **Quality options:** 480p, 720p, 1080p, 2160p (from video_url, video_alt_url, video_alt_url2, video_alt_url3)
- **Known gotchas:** 
  - Auth params (md5, timestamp) are REQUIRED — do not strip them
  - URLs are time-limited — user must re-request streams
  - Content-Disposition: attachment on CDN does NOT prevent playback
  - NEVER use externalUrl for video streams

## Files to Generate
1. `addon.js` — Main addon logic with all handlers (catalog, meta, stream)
2. `api/index.js` — Vercel serverless entry point with /stream-proxy/ fallback
3. `vercel.json` — Vercel configuration with rewrites
4. `package.json` — Dependencies

## Rules
- Use `node-fetch` v2.x (CommonJS), NOT v3.x (ESM)
- Use `cheerio` v1.0.0+ (not 0.x)
- For KVS sites: ALWAYS use `/embed/{id}/` for stream extraction, NEVER `/video/{id}/{slug}/`
- For channel types: meta handler MUST return a `videos` array
- Stream handler: ALWAYS extract direct video URLs as `stream.url`. NEVER use `externalUrl` for video playback.
- The get_stream URLs MUST be returned as stream.url — Stremio's UA will trigger the 302 redirect to CDN
- NEVER strip auth parameters (md5, timestamp) from stream URLs
- Cross-navigation streams (models, tags) can use externalUrl with stremio:///detail/curvcorn/{id} deep links
- All poster/background URLs must be absolute
- The `id` in returned meta objects MUST match the `id` that was requested
- Keep Vercel serverless function under 10 seconds execution time
- Must use Accept-Encoding: identity in all requests to thepornbang.com

## Addon Identity
- **Addon ID:** community.curvcorn-thepornbang
- **ID Prefix:** curvcorn_
- **Addon Name:** Curvcorn ThePornBang

## Output Format
Provide all files as complete, production-ready code blocks. Do not use placeholders or TODOs.
```

---

## Prompt Engineering Tips

### For Best Results with AI Agents

1. **Be specific about the platform.** "KVS" tells the agent to use embed URLs and watch for slugs. "Unknown" forces the agent to discover patterns from scratch.

2. **Provide the knowledge base URL.** This gives the agent access to all templates, error databases, and site patterns.

3. **Specify content types explicitly.** The choice between `channel` and `movie` determines the entire meta handler structure.

4. **List known gotchas upfront.** Each gotcha you mention prevents a debugging cycle later.

5. **Include the addon identity.** A clear ID and prefix prevents naming collisions.

6. **Mention Vercel deployment.** This ensures the serverless entry point and vercel.json are included.

7. **Note User-Agent redirect behavior.** If the target site uses UA-based redirect for stream URLs, specify this so the agent doesn't waste time on proxy player approaches.

### What NOT to Include

- Do NOT ask the agent to handle user authentication or login-protected content — Stremio addons are public.
- Do NOT ask for torrent streaming unless the site specifically provides magnet links — focus on direct streaming.
- Do NOT ask for a UI or configuration page — Stremio addons are headless services.
- Do NOT ask the agent to use `externalUrl` for video streams — it opens a browser/webview.

---

*Last updated: 2026-06-07*
