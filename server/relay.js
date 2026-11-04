import { WebSocketServer } from 'ws';
import crypto from 'node:crypto';

const PORT = Number(process.env.PORT || 8080);
const clients = new Map();
const pendingPairs = new Map();

const wss = new WebSocketServer({ host: '127.0.0.1', port: PORT, maxPayload: 16 * 1024 * 1024 });
wss.on('listening', () => console.log(`TTalk relay listening on ws://127.0.0.1:${wss.address().port}`));

function clearPair(ws) {
  if (!ws._pairCode) return;
  const entry = pendingPairs.get(ws._pairCode);
  if (entry?.ws === ws) {
    clearTimeout(entry.timer);
    pendingPairs.delete(ws._pairCode);
  }
  ws._pairCode = null;
}

const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (ws._alive === false) { ws.terminate(); continue; }
    ws._alive = false;
    ws.ping();
  }
}, 30000);
heartbeat.unref();
wss.on('close', () => clearInterval(heartbeat));

function send(ws, msg) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

wss.on('connection', (ws) => {
  ws._alive = true;
  ws.on('pong', () => { ws._alive = true; });
  ws.on('error', () => ws.terminate());
  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (!msg || typeof msg !== 'object' || Array.isArray(msg)) return;
    if (msg.type !== 'register' && !ws._id) return;
    switch (msg.type) {
      case 'register': {
        const publicKey = String(msg.publicKey || '');
        if (!/^[A-Za-z0-9+/]{43}=$/.test(publicKey) || Buffer.from(publicKey, 'base64').length !== 32) return;
        const id = ws._id || crypto.randomUUID();
        ws._id = id;
        ws._name = String(msg.name || 'Anonyme').slice(0, 40);
        ws._pub = publicKey;
        clients.set(id, ws);
        send(ws, { type: 'registered', id });
        break;
      }
      case 'pair_request': {
        const code = String(msg.code || '').toUpperCase();
        if (!/^[A-Z0-9]{6}$/.test(code)) return;
        if (pendingPairs.has(code) && pendingPairs.get(code).ws !== ws) {
          send(ws, { type: 'pair_error', reason: 'Code déjà utilisé, génère un nouveau code' });
          return;
        }
        clearPair(ws);
        const timer = setTimeout(() => clearPair(ws), 5 * 60 * 1000);
        timer.unref();
        ws._pairCode = code;
        pendingPairs.set(code, { ws, timer });
        send(ws, { type: 'pairing_code', code });
        break;
      }
      case 'pair_answer': {
        const code = String(msg.code || '').toUpperCase();
        const requester = pendingPairs.get(code)?.ws;
        if (!requester || requester === ws || requester.readyState !== requester.OPEN) {
          send(ws, { type: 'pair_error', reason: 'Code invalide ou expiré' });
          return;
        }
        clearPair(requester);
        const a = requester;
        const b = ws;
        send(a, {
          type: 'peer_matched',
          peerId: b._id,
          peerName: b._name,
          peerPublicKey: b._pub,
        });
        send(b, {
          type: 'peer_matched',
          peerId: a._id,
          peerName: a._name,
          peerPublicKey: a._pub,
        });
        break;
      }
      case 'cipher': {
        const targets = Array.isArray(msg.to) ? msg.to : [msg.to];
        for (const t of targets) {
          const target = clients.get(String(t));
          if (!target) continue;
          send(target, {
            type: 'cipher',
            from: ws._id,
            messageId: msg.messageId,
            groupId: msg.groupId || null,
            payload: msg.payload,
          });
        }
        break;
      }
      case 'delivered':
      case 'read': {
        const targets = Array.isArray(msg.to) ? msg.to : [msg.to];
        for (const t of targets) {
          const target = clients.get(String(t));
          if (!target) continue;
          send(target, {
            type: msg.type,
            groupId: msg.groupId || null,
            from: ws._id,
            messageId: msg.messageId,
          });
        }
        break;
      }
      case 'group_invite': {
        const target = clients.get(String(msg.to));
        if (!target) return;
        send(target, {
          type: 'group_invite',
          from: ws._id,
          fromName: ws._name,
          payload: msg.payload,
        });
        break;
      }
    }
  });
  ws.on('close', () => {
    clearPair(ws);
    if (ws._id) clients.delete(ws._id);
  });
});
