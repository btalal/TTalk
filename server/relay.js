import { WebSocketServer, WebSocket } from 'ws';
import http from 'node:http';
import crypto from 'node:crypto';
import path from 'node:path';
import { Mailbox } from './store.js';
import { protocolVersion, createChallenge, decodePublicKey, authenticationKey, proof, stableId } from './protocol.js';

const PORT = Number(process.env.PORT || 8080), HOST = process.env.HOST || '127.0.0.1';
const mailbox = new Mailbox(process.env.DATA_DIR || path.resolve('data'));
const clients = new Map(), pendingPairs = new Map(), ipConnections = new Map();
const server = http.createServer((req, res) => {
  const ok = req.url === '/healthz' || req.url === '/';
  res.writeHead(ok ? 200 : 404, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(ok ? { status: 'ok', protocol: protocolVersion } : { error: 'not_found' }));
});
const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 16 * 1024 * 1024 });
server.listen(PORT, HOST, () => console.log(`TTalk relay listening on ws://${HOST}:${server.address().port}/ws`));

function send(ws, message) { if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(message)); }
function error(ws, code, reason, messageId) { send(ws, { type: 'relay_error', code, reason, messageId }); }
function clearPair(ws) {
  const entry = pendingPairs.get(ws._pairCode);
  if (entry?.ws === ws) { clearTimeout(entry.timer); pendingPairs.delete(ws._pairCode); }
  ws._pairCode = null;
}
function deliver(ws) {
  if (!ws._id || ws.readyState !== WebSocket.OPEN) return;
  for (const row of mailbox.pending(ws._id)) {
    if (ws._inflight.has(row.id)) continue;
    if (ws._inflight.size >= 16 || ws.bufferedAmount > 16 * 1024 * 1024) break;
    ws._inflight.add(row.id);
    send(ws, { ...JSON.parse(row.body), relayId: row.id });
  }
}
const heartbeat = setInterval(() => {
  mailbox.prune();
  for (const ws of wss.clients) {
    if (ws.readyState !== WebSocket.OPEN) continue;
    if (ws._alive === false) { ws.terminate(); continue; }
    ws._alive = false; ws.ping();
    deliver(ws);
  }
}, 30000);
heartbeat.unref();

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress || 'unknown';
  // Use the socket address, never an untrusted forwarded-IP header.
  const count = ipConnections.get(ip) || 0;
  if (count >= 20) { ws.close(1013, 'Connection limit'); return; }
  ipConnections.set(ip, count + 1);
  ws._alive = true; ws._inflight = new Set(); ws._challenge = createChallenge();
  ws._window = Date.now(); ws._requests = 0;
  const deadline = setTimeout(() => { if (!ws._id) ws.close(1008, 'Authentication timeout'); }, 30000);
  deadline.unref();
  send(ws, { type: 'auth_challenge', protocol: protocolVersion, nonce: ws._challenge.nonce, publicKey: ws._challenge.publicKey });
  ws.on('pong', () => { ws._alive = true; });
  ws.on('error', () => ws.terminate());
  ws.on('message', raw => {
    try {
      if (Date.now() - ws._window >= 60000) { ws._window = Date.now(); ws._requests = 0; }
      if (++ws._requests > 600) { ws.close(1008, 'Rate limit'); return; }
      const msg = JSON.parse(raw.toString());
      if (!msg || typeof msg !== 'object' || Array.isArray(msg)) return;
      if (msg.type === 'register') {
        const rawKey = decodePublicKey(msg.publicKey);
        if (ws._id && ws._pub !== msg.publicKey) throw new Error('Identity change requires reconnect');
        const expected = Buffer.from(proof(authenticationKey(ws._challenge.privateKey, rawKey), ws._challenge.nonce, msg.publicKey), 'base64');
        const provided = Buffer.from(String(msg.proof || ''), 'base64');
        if (provided.length !== expected.length || !crypto.timingSafeEqual(expected, provided)) {
          error(ws, 'authentication_failed', 'Identity proof rejected'); ws.close(1008, 'Authentication failed'); return;
        }
        const id = stableId(rawKey), previous = clients.get(id);
        if (previous && previous !== ws) previous.close(4001, 'Identity connected elsewhere');
        ws._id = id; ws._pub = msg.publicKey; ws._name = String(msg.name || 'Utilisateur').slice(0, 40);
        clients.set(id, ws); clearTimeout(deadline);
        send(ws, { type: 'registered', id, protocol: protocolVersion }); deliver(ws); return;
      }
      if (!ws._id) { error(ws, 'authentication_required', 'Register first'); return; }
      if (msg.type === 'delivery_ack') {
        if (typeof msg.relayId !== 'string') return;
        mailbox.acknowledge(msg.relayId, ws._id); ws._inflight.delete(msg.relayId); deliver(ws); return;
      }
      if (msg.type === 'pair_request') {
        const code = String(msg.code || '').toUpperCase();
        if (!/^[A-Z0-9]{6}$/.test(code)) return;
        if (pendingPairs.has(code) && pendingPairs.get(code).ws !== ws) { send(ws, { type: 'pair_error', reason: 'Code déjà utilisé' }); return; }
        clearPair(ws);
        const timer = setTimeout(() => clearPair(ws), 300000); timer.unref();
        ws._pairCode = code; pendingPairs.set(code, { ws, timer }); send(ws, { type: 'pairing_code', code }); return;
      }
      if (msg.type === 'pair_answer') {
        const requester = pendingPairs.get(String(msg.code || '').toUpperCase())?.ws;
        if (!requester || requester === ws || requester.readyState !== WebSocket.OPEN) { send(ws, { type: 'pair_error', reason: 'Code invalide ou expiré' }); return; }
        clearPair(requester);
        mailbox.enqueue(requester._id, ws._id, { type: 'peer_matched', messageId: crypto.randomUUID(), peerId: ws._id, peerName: ws._name, peerPublicKey: ws._pub });
        mailbox.enqueue(ws._id, requester._id, { type: 'peer_matched', messageId: crypto.randomUUID(), peerId: requester._id, peerName: requester._name, peerPublicKey: requester._pub });
        deliver(requester); deliver(ws); return;
      }
      if (msg.type !== 'cipher' && msg.type !== 'group_invite') return;
      if (typeof msg.messageId !== 'string' || !/^[A-Za-z0-9_-]{1,80}$/.test(msg.messageId) ||
          typeof msg.payload !== 'string' || msg.payload.length > 15 * 1024 * 1024 ||
          !/^[A-Za-z0-9+/]*={0,2}$/.test(msg.payload)) { error(ws, 'invalid_packet', 'Invalid encrypted packet', msg.messageId); return; }
      const targets = [...new Set(Array.isArray(msg.to) ? msg.to : [msg.to])];
      if (targets.length < 1 || targets.length > 100 || targets.some(id => typeof id !== 'string' || !/^[a-f0-9]{64}$/.test(id))) { error(ws, 'invalid_recipient', 'Invalid recipient', msg.messageId); return; }
      for (const target of targets) {
        const envelope = { type: msg.type, from: ws._id, messageId: msg.messageId, groupId: msg.groupId || null, payload: msg.payload };
        if (msg.type === 'group_invite') envelope.fromName = ws._name;
        try {
          mailbox.enqueue(target, ws._id, envelope);
          send(ws, { type: 'accepted', messageId: msg.messageId, recipientId: target });
          const recipient = clients.get(target); if (recipient) deliver(recipient);
        } catch (e) { error(ws, 'queue_rejected', e.message, msg.messageId); }
      }
    } catch { error(ws, 'invalid_request', 'Invalid request'); }
  });
  ws.on('close', () => {
    clearTimeout(deadline); clearPair(ws);
    if (clients.get(ws._id) === ws) clients.delete(ws._id);
    const remaining = (ipConnections.get(ip) || 1) - 1;
    if (remaining) ipConnections.set(ip, remaining); else ipConnections.delete(ip);
  });
});
function stop() {
  clearInterval(heartbeat);
  for (const ws of wss.clients) ws.terminate();
  wss.close(() => server.close(() => { mailbox.close(); process.exit(0); }));
}
process.on('SIGTERM', stop); process.on('SIGINT', stop);
