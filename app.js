const contentDiv = document.getElementById('app-content');
const homeBtn = document.getElementById('home-btn');
const aboutBtn = document.getElementById('about-btn');

const socket = io('http://localhost:3000');

const VAPID_PUBLIC_KEY = 'BGtkjigg0I3WzDHDEjjiUzLr1HWVxSoAffXWo-Q-Pm2jf2Z51ffOc1Gv_Fpld7FGZEeMHbWh9HXbTZy0vf5LzeM';

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
    const existing = await registration.pushManager.getSubscription();
    if (existing) {
      await fetch('http://localhost:3000/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(existing)
      });
      return;
    }
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
    const response = await fetch('content/' + page + '.html');
    const html = await response.text();
    contentDiv.innerHTML = html;
    if (page === 'home') {
      initNotes();
    }
  } catch (err) {
    contentDiv.innerHTML = '<p style="text-align:center;">Ошибка загрузки страницы</p>';
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

  if (!form || !input || !list) {
    console.error('initNotes: элементы не найдены');
    return;
  }

  console.log('initNotes OK');

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
      li.innerHTML =
        '<span class="note-dot"></span>' +
        '<span class="note-text">' + escapeHtml(text) + '</span>' +
        '<button class="delete-btn" data-index="' + index + '" title="Удалить">🗑️</button>';
      list.appendChild(li);
    });
  }

  function addNote(text) {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    notes.push({ id: Date.now(), text: text });
    localStorage.setItem('notes', JSON.stringify(notes));
    loadNotes();
    console.log('emit newTask:', text);
    socket.emit('newTask', { text: text, timestamp: Date.now() });
  }

  function deleteNote(index) {
    const notes = JSON.parse(localStorage.getItem('notes') || '[]');
    notes.splice(index, 1);
    localStorage.setItem('notes', JSON.stringify(notes));
    loadNotes();
  }

  form.addEventListener('submit', function(e) {
    e.preventDefault();
    const text = input.value.trim();
    if (text) {
      addNote(text);
      input.value = '';
      input.focus();
    }
  });

  list.addEventListener('click', function(e) {
    const btn = e.target.closest('.delete-btn');
    if (btn) {
      deleteNote(Number(btn.dataset.index));
    }
  });

  loadNotes();
}

socket.on('connect', function() {
  console.log('Socket connected:', socket.id);
});

socket.on('taskAdded', function(task) {
  console.log('taskAdded received:', task);
  const toast = document.createElement('div');
  toast.className = 'ws-toast';
  toast.textContent = '✨ Новая заметка: ' + task.text;
  document.body.appendChild(toast);
  setTimeout(function() { toast.classList.add('show'); }, 10);
  setTimeout(function() {
    toast.classList.remove('show');
    setTimeout(function() { toast.remove(); }, 300);
  }, 3000);
});

if ('serviceWorker' in navigator) {
  window.addEventListener('load', async function() {
    try {
      const reg = await navigator.serviceWorker.register('sw.js');
      console.log('SW registered:', reg.scope);

      const enableBtn = document.getElementById('enable-push');
      const disableBtn = document.getElementById('disable-push');

      const subscription = await reg.pushManager.getSubscription();
      if (subscription) {
        await fetch('http://localhost:3000/subscribe', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(subscription)
        });
        enableBtn.style.display = 'none';
        disableBtn.style.display = 'inline-block';
      }

      enableBtn.addEventListener('click', async function() {
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

      disableBtn.addEventListener('click', async function() {
        await unsubscribeFromPush();
        disableBtn.style.display = 'none';
        enableBtn.style.display = 'inline-block';
      });

    } catch (err) {
      console.error('SW registration failed:', err);
    }
  });
}
