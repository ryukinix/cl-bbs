const CACHE_NAME = 'cl-bbs-v1';
const ASSETS = [
  '/',
  '/static/styles/themes/default.css',
  '/static/styles/themes/dark.css',
  '/static/styles/themes/no.css',
  '/static/styles/themes/colored.css',
  '/static/styles/themes/matrix.css',
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
