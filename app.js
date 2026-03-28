const form = document.getElementById('note-form');
const input = document.getElementById('note-input');
const list = document.getElementById('notes-list');

function loadNotes() {
  const notes = JSON.parse(localStorage.getItem('notes') || '[]');
  list.innerHTML = '';
  notes.forEach((note, index) => {
    const li = document.createElement('li');
    li.innerHTML = `
      <span class="note-dot"></span>
      <span class="note-text">${escapeHtml(note)}</span>
      <button class="delete-btn" data-index="${index}" title="Удалить">🗑️</button>
    `;
    list.appendChild(li);
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.appendChild(document.createTextNode(text));
  return div.innerHTML;
}

function addNote(text) {
  const notes = JSON.parse(localStorage.getItem('notes') || '[]');
  notes.push(text);
  localStorage.setItem('notes', JSON.stringify(notes));
  loadNotes();
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

if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('/sw.js');
      console.log('ServiceWorker зарегистрирован:', registration.scope);
    } catch (err) {
      console.error('Ошибка регистрации ServiceWorker:', err);
    }
  });
}
