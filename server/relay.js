import { WebSocketServer } from 'ws';
import crypto from 'node:crypto';

const PORT = Number(process.env.PORT || 8080);
const clients = new Map();
const pendingPairs = new Map();

const wss = new WebSocketServer({ host: '127.0.0.1', port: PORT });
console.log(`TalMessenger relay listening on ws://127.0.0.1:${PORT}`);

function send(ws, msg) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

wss.on('connection', (ws) => {
  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }
    switch (msg.type) {
      case 'register': {
        const id = crypto.randomUUID();
        ws._id = id;
        ws._name = String(msg.name || 'Anonyme').slice(0, 40);
        ws._pub = String(msg.publicKey || '');
        clients.set(id, ws);
        send(ws, { type: 'registered', id });
        break;
      }
      case 'pair_request': {
        const code = String(msg.code || '').toUpperCase();
        if (code.length !== 6) return;
        pendingPairs.set(code, ws);
        send(ws, { type: 'pairing_code', code });
        setTimeout(() => pendingPairs.delete(code), 5 * 60 * 1000);
        break;
      }
      case 'pair_answer': {
        const code = String(msg.code || '').toUpperCase();
        const requester = pendingPairs.get(code);
        if (!requester || requester.readyState !== requester.OPEN) {
          send(ws, { type: 'pair_error', reason: 'Code invalide ou expiré' });
          return;
        }
        pendingPairs.delete(code);
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
        const target = clients.get(String(msg.to));
        if (!target) return;
        send(target, {
          type: 'cipher',
          from: ws._id,
          messageId: msg.messageId,
          payload: msg.payload,
        });
        break;
      }
      case 'read': {
        const target = clients.get(String(msg.to));
        if (!target) return;
        send(target, {
          type: 'read',
          from: ws._id,
          messageId: msg.messageId,
        });
        break;
      }
    }
  });
  ws.on('close', () => {
    if (ws._id) clients.delete(ws._id);
  });
});
