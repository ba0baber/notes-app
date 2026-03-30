const CACHE_NAME = 'notes-cache-v5';
const DYNAMIC_CACHE_NAME = 'dynamic-content-v1';

const ASSETS = [
  './',
  './index.html',
  './style.css',
  './app.js',
  './manifest.json',
  './icons/favicon.ico',
  './icons/favicon-16x16.png',
  './icons/favicon-32x32.png',
  './icons/apple-touch-icon.png',
  './icons/android-chrome-512x512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(key => key !== CACHE_NAME && key !== DYNAMIC_CACHE_NAME)
          .map(key => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  if (url.origin !== location.origin) return;

  if (url.pathname.startsWith('/content/')) {
    event.respondWith(
      fetch(event.request)
        .then(networkRes => {
          const resClone = networkRes.clone();
          caches.open(DYNAMIC_CACHE_NAME).then(cache => {
            cache.put(event.request, resClone);
          });
          return networkRes;
        })
        .catch(() => {
          return caches.match(event.request)
            .then(cached => cached || caches.match('./content/home.html'));
        })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});