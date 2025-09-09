// service-worker.js
// Offline cache for Boxing Timer PWA

// Bump this when you change index.html/manifest or want to force an update
const CACHE_VERSION = 'v5';
const CACHE_NAME = `boxing-timer-${CACHE_VERSION}`;

// NOTE: If you host at https://<user>.github.io/Timer/
// keep these paths relative as below.
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',

  // CDN assets (cached after first load for offline use)
  'https://cdn.tailwindcss.com',
  'https://unpkg.com/react@18/umd/react.development.js',
  'https://unpkg.com/react-dom@18/umd/react-dom.development.js',
  'https://unpkg.com/@babel/standalone/babel.min.js'
];

// Install: warm the cache
self.addEventListener('install', (event) => {
  // Activate this SW immediately
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      // Use addAll; if any single fetch fails it throws.
      // If you often change CDN versions, you can wrap individually.
      try {
        await cache.addAll(ASSETS);
      } catch (err) {
        // Fallback: try to cache what we can, don’t fail install completely
        await Promise.allSettled(
          ASSETS.map(async (url) => {
            try {
              const resp = await fetch(url, { cache: 'no-cache' });
              if (resp && (resp.ok || resp.type === 'opaque')) {
                await cache.put(url, resp.clone());
              }
            } catch (_) { /* ignore */ }
          })
        );
      }
    })
  );
});

// Activate: cleanup old versions
self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

// Fetch: network-first for HTML, cache-first for everything else
self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Only handle GET
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const isHTML =
    req.headers.get('accept')?.includes('text/html') ||
    url.pathname.endsWith('/') ||
    url.pathname.endsWith('.html');

  if (isHTML) {
    // Network-first for pages (so updates appear when online)
    event.respondWith(
      (async () => {
        try {
          const net = await fetch(req, { cache: 'no-cache' });
          // Update cache in the background
          const cache = await caches.open(CACHE_NAME);
          cache.put(req, net.clone()).catch(() => {});
          return net;
        } catch {
          // Offline fallback
          const cacheMatch =
            (await caches.match(req)) || (await caches.match('./index.html'));
          return cacheMatch;
        }
      })()
    );
  } else {
    // Cache-first for static assets (icons, JS, CSS, CDN libs)
    event.respondWith(
      (async () => {
        const cached = await caches.match(req, { ignoreSearch: false });
        if (cached) return cached;
        try {
          const net = await fetch(req);
          // Cache successful GET responses
          if (net && net.ok) {
            const cache = await caches.open(CACHE_NAME);
            cache.put(req, net.clone()).catch(() => {});
          }
          return net;
        } catch {
          // Last-resort fallback to root if it helps
          return caches.match('./index.html');
        }
      })()
    );
  }
});
