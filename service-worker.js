// service-worker.js
// Offline cache for Boxing Timer PWA

const CACHE_VERSION = 'v7'; // bump when you ship updates
const CACHE_NAME = `boxing-timer-${CACHE_VERSION}`;

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

// Install: warm the cache + take control ASAP
self.addEventListener('install', (event) => {
  self.skipWaiting(); // <-- auto-activate new SW
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      try {
        await cache.addAll(ASSETS);
      } catch (err) {
        // Cache as much as possible if some requests fail (e.g., CDN hiccups)
        await Promise.allSettled(
          ASSETS.map(async (url) => {
            try {
              const resp = await fetch(url, { cache: 'no-cache' });
              if (resp && (resp.ok || resp.type === 'opaque')) {
                await cache.put(url, resp.clone());
              }
            } catch (_) {}
          })
        );
      }
    })
  );
});

// Activate: clean old caches + claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)));
    await self.clients.claim(); // <-- correct spelling, inside the waitUntil
  })());
});

// Optional: allow pages to request skipWaiting() explicitly
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

// Fetch: network-first for HTML, cache-first for everything else
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const isHTML =
    req.headers.get('accept')?.includes('text/html') ||
    url.pathname.endsWith('/') ||
    url.pathname.endsWith('.html');

  if (isHTML) {
    event.respondWith((async () => {
      try {
        const net = await fetch(req, { cache: 'no-cache' });
        const cache = await caches.open(CACHE_NAME);
        cache.put(req, net.clone()).catch(() => {});
        return net;
      } catch {
        return (await caches.match(req)) || (await caches.match('./index.html'));
      }
    })());
  } else {
    event.respondWith((async () => {
      const cached = await caches.match(req, { ignoreSearch: false });
      if (cached) return cached;
      try {
        const net = await fetch(req);
        if (net && net.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(req, net.clone()).catch(() => {});
        }
        return net;
      } catch {
        return caches.match('./index.html');
      }
    })());
  }
});
