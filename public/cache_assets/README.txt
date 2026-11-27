LIVE ROBLOX IMAGE COLLECTION — UNCONFIRMED ATTRIBUTION

Open the main macro's Image Review window. Start Collection resumes this session;
Stop Collection stops the background watcher/exporter. Closing the window leaves
collection running. No model calls or account login are used.

New/changed cache image entries are exported by rbxcache v1.2.0. KTX2 textures are
converted to PNG. SHA-256 names deduplicate content. SQLite persists source stamps,
content hashes, review states and progress. Old collection decisions are archived
separately and do not suppress this session's downloads.

Skip removes an image from this session's pending queue, including after restart.
Double-click toggles fit/zoom; wheel zooms at the cursor; left-drag pans while
zoomed. Panning/zoom are clamped and reset on the next image.

manifest.json is a batched checkpoint. ReviewStore.read_manifest() overlays the
durable SQLite changes immediately. Source cache-entry metadata is retained.
Images downloaded during Pixel Empire play are not automatically attributed to it.
