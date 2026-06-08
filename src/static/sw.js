const CACHE_NAME = 'cl-bbs-v1';
const ASSETS = [
  '/',
  '/static/styles/default.css',
  '/static/styles/dark.css',
  '/static/styles/no.css',
  '/static/favicon.ico',
  '/static/schemebbs.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS);
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        return cachedResponse;
      }
      return fetch(event.request).catch(() => {
        // Fallback or offline page
      });
    })
  );
});
