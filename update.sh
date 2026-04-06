#!/bin/bash

echo "🌸 Обновляем проект..."

# Создаём папку content если нет
mkdir -p content

# =====================
# server.js
# =====================
cat > server.js << 'SERVEREOF'
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const webpush = require('web-push');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');

const vapidKeys = {
  publicKey: 'BD0fWaIkakUxFHoEmdcK2C--tGTh1sXGNUR34oLOxoJDbcz50Lz68wd8fBxqX5UhhadLTdR4CjyQWH1i3Oa7ZY0',
  privateKey: 'bcz50Lz68wd8fBxqX5UhhadLTdR4CjyQWH1i3Oa7ZY0'
};

webpush.setVapidDetails(
  'mailto:example@example.com',
  vapidKeys.publicKey,
  vapidKeys.privateKey
);

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, './')));

let subscriptions = [];

const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

io.on('connection', (socket) => {
  console.log('Клиент подключён:', socket.id);

  socket.on('newTask', (task) => {
    io.emit('taskAdded', task);

    const payload = JSON.stringify({
      title: 'Новая задача ✨',
      body: task.text
    });

    subscriptions.forEach(sub => {
      webpush.sendNotification(sub, payload).catch(err =>
        console.error('Push error:', err)
      );
    });
  });

  socket.on('disconnect', () => {
    console.log('Клиент отключён:', socket.id);
  });
});

app.post('/subscribe', (req, res) => {
  const sub = req.body;
  const exists = subscriptions.find(s => s.endpoint === sub.endpoint);
  if (!exists) subscriptions.push(sub);
  res.status(201).json({ message: 'Подписка сохранена' });
});

app.post('/unsubscribe', (req, res) => {
  const { endpoint } = req.body;
  subscriptions = subscriptions.filter(s => s.endpoint !== endpoint);
  res.status(200).json({ message: 'Подписка удалена' });
});

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`Сервер запущен на http://localhost:${PORT}`);
});
SERVEREOF

# =====================
# index.html
# =====================
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="manifest" href="manifest.json">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#f78fb3">
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <title>Заметки ✨</title>
  <link rel="icon" href="icons/favicon.ico" type="image/x-icon">
  <link rel="icon" type="image/png" sizes="16x16" href="icons/favicon-16x16.png">
  <link rel="icon" type="image/png" sizes="32x32" href="icons/favicon-32x32.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Pacifico&family=Nunito:wght@400;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="bg-blobs">
    <div class="blob blob1"></div>
    <div class="blob blob2"></div>
    <div class="blob blob3"></div>
  </div>

  <div class="container">
    <header>
      <div class="title-wrap">
        <span class="crown">👑</span>
        <h1>мои заметки</h1>
      </div>
      <p class="subtitle">всё важное в одном месте 🌸</p>
      <nav class="nav-tabs">
        <button id="home-btn" class="tab-btn active">🏠 главная</button>
        <button id="about-btn" class="tab-btn">💜 о приложении</button>
      </nav>
    </header>

    <main id="app-content"></main>

    <footer class="push-footer">
      <button id="enable-push" class="push-btn enable">🔔 включить уведомления</button>
      <button id="disable-push" class="push-btn disable" style="display:none;">🔕 отключить уведомления</button>
    </footer>
  </div>

  <script src="https://cdn.socket.io/4.5.4/socket.io.min.js"></script>
  <script src="app.js"></script>
</body>
</html>
HTMLEOF

# =====================
# app.js
# =====================
cat > app.js << 'APPEOF'
const contentDiv = document.getElementById('app-content');
const homeBtn = document.getElementById('home-btn');
const aboutBtn = document.getElementById('about-btn');

const socket = io('http://localhost:3000');

const VAPID_PUBLIC_KEY = 'BD0fWaIkakUxFHoEmdcK2C--tGTh1sXGNUR34oLOxoJDbcz50Lz68wd8fBxqX5UhhadLTdR4CjyQWH1i3Oa7ZY0';

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

async function subscribeToPush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY)
    });
    await fetch('http://localhost:3000/subscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(subscription)
    });
    console.log('Подписка на push отправлена');
  } catch (err) {
    console.error('Ошибка подписки на push:', err);
  }
}

async function unsubscribeFromPush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();
  if (subscription) {
    await fetch('http://localhost:3000/unsubscribe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ endpoint: subscription.endpoint })
    });
    await subscription.unsubscribe();
    console.log('Отписка выполнена');
  }
}

function setActiveButton(activeId) {
  [homeBtn, aboutBtn].forEach(btn => btn.classList.remove('active'));
  document.getElementById(activeId).classList.add('active');
}

async function loadContent(page) {
  try {
    const response = await fetch(`content/${page}.html`);
    const html = await response.text();
    contentDiv.innerHTML = html;
    if (page === 'home') {
      initNotes();
    }
  } catch (err) {
    contentDiv.innerHTML = `<p style="text-align:center; color: var(--pink-dark);">Ошибка загрузки страницы 😢</p>`;
    console.error(err);
  }
}

homeBtn.addEventListener('click', () => {
  setActiveButton('home-btn');
  loadContent('home');
});

aboutBtn.addEventListener('click', () => {
  setActiveButton('about-btn');
  loadContent('about');
});

loadContent('home');

function initNotes() {
  const form = document.getElementById('note-form');
  const input = document.getElementById('note-input');
  const list = document.getElementById('notes-list');

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
  }

  function loadNotes() {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    list.innerHTML = '';
    notes.forEach((note, index) => {
      const text = typeof note === 'object' ? note.text : note;
      const li = document.createElement('li');
      li.innerHTML = `
        <span class="note-dot"></span>
        <span class="note-text">${escapeHtml(text)}</span>
        <button class="delete-btn" data-index="${index}" title="Удалить">🗑️</button>
      `;
      list.appendChild(li);
    });
  }

  function addNote(text) {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    const newNote = { id: Date.now(), text };
    notes.push(newNote);
    localStorage.setItem('notes', JSON.stringify(notes));
    loadNotes();
    socket.emit('newTask', { text, timestamp: Date.now() });
  }

  function deleteNote(index) {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    notes.splice(index, 1);
    localStorage.setItem('notes', JSON.stringify(notes));
    loadNotes();
  }

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const text = input.value.trim();
    if (text) {
      addNote(text);
      input.value = '';
      input.focus();
    }
  });

  list.addEventListener('click', (e) => {
    const btn = e.target.closest('.delete-btn');
    if (btn) {
      deleteNote(Number(btn.dataset.index));
    }
  });

  loadNotes();
}

socket.on('taskAdded', (task) => {
  const toast = document.createElement('div');
  toast.className = 'ws-toast';
  toast.textContent = `✨ Новая заметка: ${task.text}`;
  document.body.appendChild(toast);
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      const reg = await navigator.serviceWorker.register('sw.js');
      console.log('SW registered:', reg.scope);

      const enableBtn = document.getElementById('enable-push');
      const disableBtn = document.getElementById('disable-push');

      if (enableBtn && disableBtn) {
        const subscription = await reg.pushManager.getSubscription();
        if (subscription) {
          enableBtn.style.display = 'none';
          disableBtn.style.display = 'inline-block';
        }

        enableBtn.addEventListener('click', async () => {
          if (Notification.permission === 'denied') {
            alert('Уведомления запрещены. Разрешите их в настройках браузера.');
            return;
          }
          if (Notification.permission === 'default') {
            const permission = await Notification.requestPermission();
            if (permission !== 'granted') {
              alert('Необходимо разрешить уведомления.');
              return;
            }
          }
          await subscribeToPush();
          enableBtn.style.display = 'none';
          disableBtn.style.display = 'inline-block';
        });

        disableBtn.addEventListener('click', async () => {
          await unsubscribeFromPush();
          disableBtn.style.display = 'none';
          enableBtn.style.display = 'inline-block';
        });
      }
    } catch (err) {
      console.error('SW registration failed:', err);
    }
  });
}
APPEOF

# =====================
# sw.js
# =====================
cat > sw.js << 'SWEOF'
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

self.addEventListener('push', (event) => {
  let data = { title: 'Новое уведомление', body: '' };
  if (event.data) {
    data = event.data.json();
  }
  const options = {
    body: data.body,
    icon: './icons/android-chrome-512x512.png',
    badge: './icons/favicon-32x32.png'
  };
  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});
SWEOF

# =====================
# content/home.html
# =====================
cat > content/home.html << 'HOMEEOF'
<div class="card form-card">
  <form id="note-form">
    <input
      type="text"
      id="note-input"
      placeholder="новая заметочка... ✍️"
      autocomplete="off"
      required
    >
    <button type="submit">добавить 💖</button>
  </form>
</div>

<div id="notes-container">
  <ul id="notes-list"></ul>
  <p id="empty-msg">пока тут пусто... добавь первую заметку! 🌷</p>
</div>
HOMEEOF

# =====================
# content/about.html
# =====================
cat > content/about.html << 'ABOUTEOF'
<div class="card about-card">
  <h2>о приложении 💜</h2>
  <p>Версия 1.3.0</p>
  <ul class="about-list">
    <li>📝 Сохраняет заметки в localStorage</li>
    <li>📡 Работает офлайн благодаря Service Worker</li>
    <li>⚡ Обновляется в реальном времени через WebSocket</li>
    <li>🔔 Отправляет push-уведомления о новых задачах</li>
    <li>📱 Устанавливается как приложение (PWA)</li>
  </ul>
</div>
ABOUTEOF

# =====================
# Добавляем новые стили в style.css
# =====================
cat >> style.css << 'CSSEOF'

.push-footer {
  display: flex;
  justify-content: center;
  margin-top: 32px;
  gap: 12px;
  flex-wrap: wrap;
}

.push-btn {
  border: none;
  border-radius: 16px;
  padding: 12px 22px;
  font-size: 0.9rem;
  font-family: 'Nunito', sans-serif;
  font-weight: 700;
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s;
}

.push-btn.enable {
  background: linear-gradient(135deg, var(--lavender), var(--pink));
  color: white;
  box-shadow: 0 4px 16px var(--shadow);
}

.push-btn.disable {
  background: rgba(255,255,255,0.8);
  color: var(--text-light);
  border: 2px solid rgba(247, 143, 179, 0.3);
}

.push-btn:hover {
  transform: translateY(-2px);
}

.ws-toast {
  position: fixed;
  top: 20px;
  right: 20px;
  background: linear-gradient(135deg, var(--pink), var(--lavender));
  color: white;
  padding: 14px 20px;
  border-radius: 18px;
  font-family: 'Nunito', sans-serif;
  font-weight: 700;
  font-size: 0.95rem;
  box-shadow: 0 8px 24px var(--shadow);
  z-index: 1000;
  opacity: 0;
  transform: translateY(-10px);
  transition: opacity 0.3s, transform 0.3s;
  max-width: 300px;
}

.ws-toast.show {
  opacity: 1;
  transform: translateY(0);
}

.about-card h2 {
  font-family: 'Pacifico', cursive;
  color: var(--pink-dark);
  margin-bottom: 12px;
  font-size: 1.6rem;
}

.about-card p {
  color: var(--text-light);
  font-weight: 600;
  margin-bottom: 16px;
}

.about-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.about-list li {
  font-size: 0.95rem;
  color: var(--text);
  font-weight: 600;
  padding: 10px 14px;
  background: var(--pink-light);
  border-radius: 12px;
}

#empty-msg {
  text-align: center;
  color: var(--text-light);
  font-size: 1rem;
  padding: 32px 0;
}
CSSEOF

# =====================
# Устанавливаем зависимости
# =====================
echo "📦 Устанавливаем зависимости..."
npm install express socket.io web-push body-parser cors

echo ""
echo "✅ Готово! Запускай сервер:"
echo "   node server.js"
echo ""
echo "🌸 Открывай http://localhost:3000"
