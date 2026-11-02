import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export class Mailbox {
  constructor(directory, { retentionMs = 7 * 86400000, maxBytes = 256 * 1024 * 1024, perRecipientBytes = 32 * 1024 * 1024 } = {}) {
    fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    this.db = new DatabaseSync(path.join(directory, 'mailbox.sqlite'));
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY, dedup TEXT NOT NULL UNIQUE, recipient TEXT NOT NULL,
        sender TEXT NOT NULL, body TEXT, bytes INTEGER NOT NULL, expires INTEGER NOT NULL
      );
      CREATE INDEX IF NOT EXISTS message_expiry ON messages(expires);
      CREATE INDEX IF NOT EXISTS recipient_pending ON messages(recipient, expires);
`);
    this.retentionMs = retentionMs; this.maxBytes = maxBytes; this.perRecipientBytes = perRecipientBytes;
    this.prune();
  }
  prune() { this.db.prepare('DELETE FROM messages WHERE expires <= ?').run(Date.now()); }
  enqueue(recipient, sender, envelope) {
    this.prune();
    const body = JSON.stringify(envelope), bytes = Buffer.byteLength(body);
    const dedup = crypto.createHash('sha256').update(JSON.stringify([sender, recipient, envelope.type, envelope.messageId])).digest('hex');
    const previous = this.db.prepare('SELECT id, body FROM messages WHERE dedup = ?').get(dedup);
    if (previous) {
      if (previous.body !== null && previous.body !== body) throw new Error('Message identifier conflict');
      return previous.id;
    }
    const total = this.db.prepare('SELECT coalesce(sum(bytes),0) AS n FROM messages').get().n;
    const user = this.db.prepare('SELECT coalesce(sum(bytes),0) AS n FROM messages WHERE recipient = ?').get(recipient).n;
    if (total + bytes > this.maxBytes || user + bytes > this.perRecipientBytes) throw new Error('Mailbox full');
    // Bound metadata too, including deduplication tombstones.
    if (this.db.prepare('SELECT count(*) AS n FROM messages').get().n >= 100000) throw new Error('Mailbox full');
    const id = crypto.randomUUID();
    this.db.prepare('INSERT INTO messages VALUES (?,?,?,?,?,?,?)').run(id, dedup, recipient, sender, body, bytes, Date.now() + this.retentionMs);
    return id;
  }
  pending(recipient, limit = 32) {
    this.prune();
    return this.db.prepare('SELECT id, body FROM messages WHERE recipient = ? AND body IS NOT NULL ORDER BY rowid LIMIT ?').all(recipient, limit);
  }
  acknowledge(id, recipient) {
    // Keep only the deduplication marker until expiry; ciphertext is removed.
    this.db.prepare('UPDATE messages SET body = NULL, bytes = 0 WHERE id = ? AND recipient = ?').run(id, recipient);
  }
  close() { this.db.close(); }
}
