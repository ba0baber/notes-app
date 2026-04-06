const CACHE_NAME = 'notes-cache-v8';
const DYNAMIC_CACHE_NAME = 'dynamic-content-v3';

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

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) { return cache.addAll(ASSETS); })
      .then(function() { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(
        keys.filter(function(key) {
          return key !== CACHE_NAME && key !== DYNAMIC_CACHE_NAME;
        }).map(function(key) { return caches.delete(key); })
      );
    }).then(function() { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function(event) {
  const url = new URL(event.request.url);

  if (url.origin !== location.origin) return;
  if (url.pathname.startsWith('/socket.io/')) return;
  if (url.pathname.startsWith('/subscribe')) return;
  if (url.pathname.startsWith('/unsubscribe')) return;
  if (url.pathname.startsWith('/snooze')) return;

  if (url.pathname.startsWith('/content/')) {
    event.respondWith(
      fetch(event.request)
        .then(function(networkRes) {
          const resClone = networkRes.clone();
          caches.open(DYNAMIC_CACHE_NAME).then(function(cache) {
            cache.put(event.request, resClone);
          });
          return networkRes;
        })
        .catch(function() {
          return caches.match(event.request)
            .then(function(cached) {
              return cached || caches.match('./content/home.html');
            });
        })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then(function(response) { return response || fetch(event.request); })
  );
});

self.addEventListener('push', function(event) {
  var data = { title: 'Новое уведомление', body: '', reminderId: null };
  if (event.data) {
    data = event.data.json();
  }

  const options = {
    body: data.body,
    icon: './icons/android-chrome-512x512.png',
    badge: './icons/favicon-32x32.png',
    data: { reminderId: data.reminderId }
  };

  if (data.reminderId) {
    options.actions = [
      { action: 'snooze', title: 'Отложить на 5 минут' }
    ];
  }

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

self.addEventListener('notificationclick', function(event) {
  const notification = event.notification;
  const action = event.action;

  if (action === 'snooze') {
    const reminderId = notification.data.reminderId;
    event.waitUntil(
      fetch('http://localhost:3000/snooze?reminderId=' + reminderId, { method: 'POST' })
        .then(function() {
          console.log('Напоминание отложено');
          notification.close();
        })
        .catch(function(err) {
          console.error('Snooze failed:', err);
          notification.close();
        })
    );
  } else {
    notification.close();
    event.waitUntil(
      clients.openWindow('http://localhost:3000')
    );
  }
});