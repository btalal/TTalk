import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import WebSocket from 'ws';

async function setup(t) {
  const child = spawn(process.execPath, ['relay.js'], { cwd: new URL('../', import.meta.url), env: { ...process.env, PORT: '0' } });
  const sockets = [];
  t.after(async () => {
    sockets.forEach(ws => ws.terminate());
    const exited = once(child, 'exit'); child.kill(); await exited;
  });
  const port = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Relay startup timeout')), 5000);
    child.stdout.on('data', bytes => {
      const match = bytes.toString().match(/127\.0\.0\.1:(\d+)/);
      if (match) { clearTimeout(timer); resolve(Number(match[1])); }
    });
    child.once('error', reject);
  });
  async function connect(name) {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    const queue = [], waiters = [];
    ws.on('message', raw => {
      const message = JSON.parse(raw.toString());
      if (waiters.length) waiters.shift()(message); else queue.push(message);
    });
    ws.next = () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Message timeout')), 3000);
      waiters.push(message => { clearTimeout(timer); resolve(message); });
    });
    ws.sendJson = message => ws.send(JSON.stringify(message));
    sockets.push(ws);
    await once(ws, 'open');
    ws.sendJson({ type: 'register', name, publicKey: Buffer.alloc(32, name.charCodeAt(0)).toString('base64') });
    const registration = await ws.next();
    ws.id = registration.id;
    assert.equal(registration.type, 'registered');
    return ws;
  }
  return { connect, port };
}

test('registration survives malformed frames and repeated profile updates retain the session ID', async t => {
  const { connect } = await setup(t);
  const alice = await connect('Alice');
  for (const raw of ['null', '[]', '{invalid']) alice.send(raw);
  alice.sendJson({ type: 'register', name: 'Alice modifiée', publicKey: Buffer.alloc(32, 65).toString('base64') });
  assert.equal((await alice.next()).id, alice.id);
});

test('pairing rejects collisions and self-pairing; closed sessions invalidate codes', async t => {
  const { connect } = await setup(t);
  const alice = await connect('Alice'), bob = await connect('Bob');
  alice.sendJson({ type: 'pair_request', code: 'ABC123' });
  assert.equal((await alice.next()).type, 'pairing_code');
  bob.sendJson({ type: 'pair_request', code: 'ABC123' });
  assert.equal((await bob.next()).type, 'pair_error');
  alice.sendJson({ type: 'pair_answer', code: 'ABC123' });
  assert.equal((await alice.next()).type, 'pair_error');
  alice.close(); await once(alice, 'close');
  bob.sendJson({ type: 'pair_answer', code: 'ABC123' });
  assert.equal((await bob.next()).type, 'pair_error');
});

test('ciphertext, group delivery and group read receipts preserve sender and group IDs', async t => {
  const { connect } = await setup(t);
  const alice = await connect('Alice'), bob = await connect('Bob');
  alice.sendJson({ type: 'pair_request', code: 'ABC123' }); await alice.next();
  bob.sendJson({ type: 'pair_answer', code: 'ABC123' });
  assert.equal((await alice.next()).peerId, bob.id);
  assert.equal((await bob.next()).peerId, alice.id);
  alice.sendJson({ type: 'cipher', to: [bob.id], messageId: 'm', groupId: 'g', payload: 'opaque' });
  assert.deepEqual(await bob.next(), { type: 'cipher', from: alice.id, messageId: 'm', groupId: 'g', payload: 'opaque' });
  for (const type of ['delivered', 'read']) {
    bob.sendJson({ type, to: alice.id, messageId: 'm', groupId: 'g' });
    assert.deepEqual(await alice.next(), { type, from: bob.id, groupId: 'g', messageId: 'm' });
  }
});
