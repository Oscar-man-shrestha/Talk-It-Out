import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import supertest from 'supertest';
import { stripImageMetadata } from '../src/imageStrip';
import { runStubWorkerOnce } from '../src/worker/stubWorker';
import {
  api,
  closePool,
  ensureSchema,
  registerUser,
  resetDb,
  seedGroup,
  testApp,
  testPool,
} from './helpers';

beforeAll(ensureSchema);
beforeEach(resetDb);
afterAll(closePool);

const seg = (marker: number, payload: Buffer) => {
  const head = Buffer.from([0xff, marker, 0, 0]);
  head.writeUInt16BE(payload.length + 2, 2);
  return Buffer.concat([head, payload]);
};

/** An EXIF block with Orientation=6 and a fake GPS / camera string. */
function exifApp1(): Buffer {
  const tiff = Buffer.alloc(26);
  tiff.write('II', 0, 'latin1');
  tiff.writeUInt16LE(42, 2);
  tiff.writeUInt32LE(8, 4);
  tiff.writeUInt16LE(1, 8);
  tiff.writeUInt16LE(0x0112, 10);
  tiff.writeUInt16LE(3, 12);
  tiff.writeUInt32LE(1, 14);
  tiff.writeUInt16LE(6, 18);
  tiff.writeUInt32LE(0, 22);
  return seg(
    0xe1,
    Buffer.concat([
      Buffer.from('Exif\0\0', 'latin1'),
      tiff,
      Buffer.from('GPSLatitude 27.7172 Canon EOS SerialNumber 0042', 'latin1'),
    ]),
  );
}

/** A structurally valid JPEG carrying EXIF, XMP-ish APP1 and a comment. */
function jpegWithMetadata(): Buffer {
  return Buffer.concat([
    Buffer.from([0xff, 0xd8]),
    seg(0xe0, Buffer.from('JFIF\0\x01\x01\0\0\x01\0\x01\0\0', 'latin1')),
    exifApp1(),
    seg(0xfe, Buffer.from('Author: Priya Shah', 'latin1')),
    seg(0xdb, Buffer.alloc(65, 1)),
    seg(0xda, Buffer.from([1, 1, 0, 0, 0x3f, 0])),
    Buffer.from([0x12, 0x34, 0x56, 0xff, 0xd9]),
  ]);
}

function pngWithText(): Buffer {
  const chunk = (type: string, data: Buffer) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    return Buffer.concat([len, Buffer.from(type, 'latin1'), data, Buffer.alloc(4)]);
  };
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', Buffer.alloc(13)),
    chunk('tEXt', Buffer.from('Author\0Priya Shah', 'latin1')),
    chunk('IDAT', Buffer.alloc(10, 7)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const uploadTo = (app: ReturnType<typeof testApp>, groupId: string, token: string, bytes: Buffer, name = 'photo.jpg') =>
  supertest(app)
    .post(`/groups/${groupId}/attachments`)
    .set({ Authorization: `Bearer ${token}` })
    .attach('file', bytes, name);

const fetchImage = (app: ReturnType<typeof testApp>, groupId: string, id: string, token: string) =>
  supertest(app)
    .get(`/groups/${groupId}/attachments/${id}`)
    .set({ Authorization: `Bearer ${token}` })
    .buffer(true)
    .parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    });

describe('image metadata stripping', () => {
  it('removes GPS, camera and author details from a JPEG but keeps orientation', () => {
    const out = stripImageMetadata(jpegWithMetadata(), 'image/jpeg');
    const text = out.toString('latin1');
    expect(text).not.toContain('GPSLatitude');
    expect(text).not.toContain('Canon');
    expect(text).not.toContain('Priya');
    expect(text).toContain('JFIF');
    expect(text).toContain('Exif'); // orientation-only block
    expect(out.subarray(-2)).toEqual(Buffer.from([0xff, 0xd9]));
    // Orientation 6 survives.
    const idx = out.indexOf(Buffer.from('MM', 'latin1'), out.indexOf('Exif'));
    expect(out.readUInt16BE(idx + 18)).toBe(6);
  });

  it('removes text chunks from a PNG', () => {
    const out = stripImageMetadata(pngWithText(), 'image/png');
    expect(out.toString('latin1')).not.toContain('Priya');
    expect(out.toString('latin1')).toContain('IDAT');
  });

  it('refuses a broken file', () => {
    expect(() => stripImageMetadata(Buffer.from([0xff, 0xd8, 0xff, 0x00]), 'image/jpeg')).toThrow();
  });
});

describe('chat images', () => {
  it('anonymous image: hidden in review from the group, published with the rewrite, no identity', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const other = await registerUser(app, 'Other', 'other-att@example.com');
    await api.post(app, `/groups/${groupId}/members`, controller.token, { username: 'other-att' });

    const up = await uploadTo(app, groupId, contributor.token, jpegWithMetadata());
    expect(up.status).toBe(201);
    expect(Object.keys(up.body).sort()).toEqual(['byte_size', 'content_type', 'id']);
    const attachmentId = up.body.id as string;

    // Stored without the hidden details.
    const { rows } = await testPool().query('SELECT bytes FROM message_attachments WHERE id = $1', [
      attachmentId,
    ]);
    expect((rows[0].bytes as Buffer).toString('latin1')).not.toContain('GPSLatitude');

    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'this screen is broken again',
      is_anonymous: true,
      attachment_id: attachmentId,
    });
    expect(sent.status).toBe(201);

    // In review: the controller can see it, other members cannot.
    expect((await fetchImage(app, groupId, attachmentId, controller.token)).status).toBe(200);
    expect((await fetchImage(app, groupId, attachmentId, other.token)).status).toBe(404);
    const queue = await api.get(app, `/groups/${groupId}/review-queue`, controller.token);
    expect(queue.body.items[0].attachment_id).toBe(attachmentId);

    // The same image cannot go on a second message.
    const again = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'again',
      attachment_id: attachmentId,
    });
    expect(again.status).toBe(400);
    expect(again.body.error.code).toBe('invalid_attachment');

    await runStubWorkerOnce(testPool());
    const acc = await api.post(app, `/messages/${sent.body.id}/accept`, controller.token);
    expect(acc.status).toBe(200);

    const chat = await api.get(app, `/groups/${groupId}/messages`, other.token);
    const item = chat.body.items[0];
    expect(item.display_sender).toBeNull();
    expect(item.attachment_id).toBe(attachmentId);
    const img = await fetchImage(app, groupId, attachmentId, other.token);
    expect(img.status).toBe(200);
    expect(img.headers['content-type']).toBe('image/jpeg');
    expect(img.headers['cache-control']).toContain('private');
    expect((img.body as Buffer).toString('latin1')).not.toContain('Priya');
    expect(JSON.stringify(img.headers)).not.toContain(contributor.id);

    // Deleting the published message deletes the image.
    const pub = chat.body.items[0].id as string;
    expect((await api.del(app, `/groups/${groupId}/messages/${pub}`, controller.token)).status).toBe(204);
    expect((await fetchImage(app, groupId, attachmentId, other.token)).status).toBe(404);
  });

  it('rejecting a message deletes its image', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const up = await uploadTo(app, groupId, contributor.token, pngWithText(), 'a.png');
    const sent = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'see the attached chart',
      attachment_id: up.body.id,
    });
    await api.post(app, `/messages/${sent.body.id}/reject`, controller.token);
    const { rows } = await testPool().query('SELECT count(*)::int AS n FROM message_attachments');
    expect(rows[0].n).toBe(0);
  });

  it('only members upload; only real images; someone else\'s upload cannot be used', async () => {
    const app = testApp();
    const { controller, contributor, groupId } = await seedGroup(app);
    const outsider = await registerUser(app, 'Out', 'out-att@example.com');
    expect((await uploadTo(app, groupId, outsider.token, jpegWithMetadata())).status).toBe(403);
    const fake = await uploadTo(app, groupId, contributor.token, Buffer.from('not an image'), 'x.jpg');
    expect(fake.status).toBe(415);

    const mine = await uploadTo(app, groupId, controller.token, pngWithText(), 'c.png');
    const steal = await api.post(app, `/groups/${groupId}/messages`, contributor.token, {
      text: 'using your image',
      attachment_id: mine.body.id,
    });
    expect(steal.status).toBe(400);

    // Controller announcements can carry an image too.
    const ann = await api.post(app, `/groups/${groupId}/messages/controller`, controller.token, {
      text: 'New layout attached',
      attachment_id: mine.body.id,
    });
    expect(ann.status).toBe(201);
    expect(ann.body.attachment_id).toBe(mine.body.id);
  });
});
