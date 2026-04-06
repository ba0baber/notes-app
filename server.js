const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const webpush = require('web-push');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');

const vapidKeys = {
  publicKey: 'BGtkjigg0I3WzDHDEjjiUzLr1HWVxSoAffXWo-Q-Pm2jf2Z51ffOc1Gv_Fpld7FGZEeMHbWh9HXbTZy0vf5LzeM',
  privateKey: 'i_rrMNuIzm973LaybTW243Xc3oihrO6CBBEKyROg7Vw'
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
    console.log('newTask получен:', task);
    console.log('Подписок на push:', subscriptions.length);
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
  console.log('Новая подписка сохранена');
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