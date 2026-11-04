import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import WebSocket from 'ws';
import { authenticationKey, proof, stableId } from '../protocol.js';
import { Mailbox } from '../store.js';

function identity() {
  const keys = crypto.generateKeyPairSync('x25519');
  keys.raw = keys.publicKey.export({ type: 'spki', format: 'der' }).subarray(-32);
  keys.encoded = keys.raw.toString('base64'); keys.id = stableId(keys.raw);
  return keys;
}
async function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'ttalk-relay-'));
  let child, port; const sockets = [];
  async function stop() {
    for (const ws of sockets) ws.terminate();
    if (child && child.exitCode === null) { const done = once(child, 'exit'); child.kill(); await done; }
    child = null;
  }
  async function start() {
    child = spawn(process.execPath, ['relay.js'], { cwd: new URL('../', import.meta.url), env: { ...process.env, PORT: '0', HOST: '127.0.0.1', DATA_DIR: directory } });
    let logs = ''; child.stderr.on('data', raw => { logs += raw.toString(); });
    port = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Startup timeout: ${logs}`)), 5000);
      child.stdout.on('data', raw => { const m = raw.toString().match(/127\.0\.0\.1:(\d+)/); if (m) { clearTimeout(timer); resolve(+m[1]); } });
      child.once('error', reject);
    });
  }
  async function socket() {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws`), messages = [], waiting = [];
    sockets.push(ws);
    ws.on('message', raw => {
      const msg = JSON.parse(raw.toString());
      const i = waiting.findIndex(w => w.type === msg.type);
      if (i >= 0) waiting.splice(i, 1)[0].resolve(msg); else messages.push(msg);
    });
    ws.next = (type, timeout = 3000) => {
      const index = messages.findIndex(m => m.type === type);
      if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
      return new Promise((resolve, reject) => {
        const entry = { type, resolve: message => { clearTimeout(timer); resolve(message); } };
        const timer = setTimeout(() => { waiting.splice(waiting.indexOf(entry), 1); reject(new Error(`No ${type} message`)); }, timeout);
        waiting.push(entry);
      });
    };
    ws.sendJson = msg => ws.send(JSON.stringify(msg));
    await once(ws, 'open');
    return ws;
  }
  async function connect(name, keys = identity()) {
    const ws = await socket(), challenge = await ws.next('auth_challenge');
    assert.equal(challenge.protocol, 2);
    ws.registration = { type: 'register', name, publicKey: keys.encoded,
      proof: proof(authenticationKey(keys.privateKey, Buffer.from(challenge.publicKey, 'base64')), challenge.nonce, keys.encoded) };
    ws.sendJson(ws.registration);
    const registration = await ws.next('registered');
    assert.equal(registration.id, keys.id); ws.id = registration.id; ws.keys = keys;
    return ws;
  }
  t.after(async () => { await stop(); fs.rmSync(directory, { recursive: true, force: true }); });
  await start(); return { start, stop, connect, socket, directory };
}

test('identity survives reconnect; copied proofs cannot authenticate another connection', async t => {
  const f = await fixture(t), alice = await f.connect('Alice');
  const keys = alice.keys, id = alice.id;
  const attacker = await f.socket(); await attacker.next('auth_challenge');
  attacker.sendJson(alice.registration);
  assert.equal((await attacker.next('relay_error')).code, 'authentication_failed');
  alice.close(); await once(alice, 'close');
  const restored = await f.connect('Alice', keys); assert.equal(restored.id, id);
  restored.sendJson({ ...restored.registration, name: 'Alice modifiée' });
  assert.equal((await restored.next('registered')).id, id);
});

test('ciphertext survives recipient and server restarts, retries until ACK, then deduplicates', async t => {
  const f = await fixture(t), alice = await f.connect('Alice'), bob = await f.connect('Bob');
  const aliceKeys = alice.keys, bobKeys = bob.keys;
  bob.close(); await once(bob, 'close');
  const message = { type: 'cipher', to: bob.id, messageId: 'offline-1', payload: Buffer.from('encrypted-opaque-bytes').toString('base64') };
  alice.sendJson(message); assert.equal((await alice.next('accepted')).recipientId, bob.id);
  await f.stop(); await f.start();
  const resumed = await f.connect('Bob', bobKeys), delivery = await resumed.next('cipher');
  assert.equal(delivery.from, aliceKeys.id); assert.equal(delivery.payload, message.payload);
  resumed.close(); await once(resumed, 'close');
  const retry = await f.connect('Bob', bobKeys), repeated = await retry.next('cipher');
  assert.equal(repeated.relayId, delivery.relayId);
  retry.sendJson({ type: 'delivery_ack', relayId: repeated.relayId });
  const sender = await f.connect('Alice', aliceKeys); sender.sendJson(message); await sender.next('accepted');
  await assert.rejects(retry.next('cipher', 150), /No cipher/);
});

test('pairing rejects collisions and self-pairing, and contact exchange is durable', async t => {
  const f = await fixture(t), alice = await f.connect('Alice'), bob = await f.connect('Bob');
  alice.sendJson({ type: 'pair_request', code: 'ABC123' }); await alice.next('pairing_code');
  bob.sendJson({ type: 'pair_request', code: 'ABC123' }); assert.equal((await bob.next('pair_error')).type, 'pair_error');
  alice.sendJson({ type: 'pair_answer', code: 'ABC123' }); await alice.next('pair_error');
  bob.sendJson({ type: 'pair_answer', code: 'ABC123' });
  assert.equal((await alice.next('peer_matched')).peerId, bob.id);
  assert.equal((await bob.next('peer_matched')).peerId, alice.id);
});

test('mailbox bounds storage, rejects conflicting IDs, ACK ownership, and prunes expired data', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ttalk-mailbox-'));
  const store = new Mailbox(dir, { maxBytes: 500, perRecipientBytes: 300 });
  try {
    const envelope = { type: 'cipher', messageId: 'm', payload: 'opaque' };
    const id = store.enqueue('bob', 'alice', envelope);
    assert.equal(store.enqueue('bob', 'alice', envelope), id);
    assert.throws(() => store.enqueue('bob', 'alice', { ...envelope, payload: 'different' }), /conflict/);
    store.acknowledge(id, 'attacker'); assert.equal(store.pending('bob').length, 1);
    store.acknowledge(id, 'bob'); assert.equal(store.pending('bob').length, 0);
    assert.throws(() => store.enqueue('bob', 'alice', { ...envelope, messageId: 'large', payload: 'x'.repeat(400) }), /full/);
    store.db.prepare('UPDATE messages SET expires = 0').run(); store.prune();
    assert.equal(store.db.prepare('SELECT count(*) n FROM messages').get().n, 0);
  } finally { store.close(); fs.rmSync(dir, { recursive: true, force: true }); }
});
