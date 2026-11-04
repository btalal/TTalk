import crypto from 'node:crypto';

const x25519Prefix = Buffer.from('302a300506032b656e032100', 'hex');
export const protocolVersion = 2;
export function decodePublicKey(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9+/]{43}=$/.test(value)) throw new Error('Invalid public key');
  const raw = Buffer.from(value, 'base64');
  if (raw.length !== 32 || raw.toString('base64') !== value) throw new Error('Invalid public key');
  return raw;
}
export function stableId(raw) { return crypto.createHash('sha256').update(raw).digest('hex'); }
export function importPublicKey(raw) {
  return crypto.createPublicKey({ key: Buffer.concat([x25519Prefix, raw]), format: 'der', type: 'spki' });
}
export function authenticationKey(privateKey, rawPublicKey) {
  const shared = crypto.diffieHellman({ privateKey, publicKey: importPublicKey(rawPublicKey) });
  return Buffer.from(crypto.hkdfSync('sha256', shared, Buffer.from('ttalk-auth-v2'), Buffer.alloc(0), 32));
}
export function proof(key, nonce, publicKey) {
  return crypto.createHmac('sha256', key).update(`ttalk-register-v2\n${nonce}\n${publicKey}`).digest('base64');
}
export function createChallenge() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('x25519');
  return { privateKey, publicKey: publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64'),
    nonce: crypto.randomBytes(32).toString('base64') };
}
