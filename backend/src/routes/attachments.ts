import { Request, Response, Router } from 'express';
import multer from 'multer';
import { Pool } from 'pg';
import { ApiError, forbidden, notFound } from '../errors';
import { ImageStripError, stripImageMetadata } from '../imageStrip';
import { RequireAuth } from '../middleware/auth';
import { sniffImageType } from './profiles';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_ATTACHMENT_BYTES, files: 1, fields: 0 },
});

function readFile(req: Request, res: Response): Promise<Express.Multer.File> {
  return new Promise((resolve, reject) => {
    upload.single('file')(req, res, (err: unknown) => {
      if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
        reject(new ApiError(413, 'file_too_large', 'Images must be 5 MB or smaller.'));
        return;
      }
      if (err || !req.file) {
        reject(new ApiError(422, 'validation', 'Upload one image in the "file" field.'));
        return;
      }
      resolve(req.file);
    });
  });
}

const role = async (pool: Pool, groupId: string, userId: string) => {
  const { rows } = await pool.query(
    'SELECT role FROM group_members WHERE group_id = $1 AND user_id = $2',
    [groupId, userId],
  );
  return (rows[0]?.role as string | undefined) ?? null;
};

/**
 * Chat images (API.md 49). Upload returns an id to send with a message;
 * the image is served only to people allowed to see that message.
 */
export function createAttachmentsRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();

  router.post('/:groupId/attachments', requireAuth, async (req, res) => {
    const groupId = String(req.params.groupId);
    if (!UUID_RE.test(groupId)) throw notFound();
    const myRole = await role(pool, groupId, req.user!.id);
    if (myRole === null) throw forbidden();
    const file = await readFile(req, res);
    const type = sniffImageType(file.buffer);
    if (!type) {
      throw new ApiError(415, 'unsupported_media_type', 'Send a PNG, JPEG, or WebP image.');
    }
    let clean: Buffer;
    try {
      clean = stripImageMetadata(file.buffer, type);
    } catch (err) {
      if (err instanceof ImageStripError) {
        throw new ApiError(415, 'unreadable_image', 'That image could not be read. Try another.');
      }
      throw err;
    }
    // Tidy up this person's uploads that were never sent.
    await pool.query(
      `DELETE FROM message_attachments a
       WHERE a.uploader_id = $1 AND a.created_at < now() - interval '1 day'
         AND NOT EXISTS (SELECT 1 FROM raw_messages r WHERE r.attachment_id = a.id)
         AND NOT EXISTS (SELECT 1 FROM published_messages p WHERE p.attachment_id = a.id)`,
      [req.user!.id],
    );
    const { rows } = await pool.query(
      `INSERT INTO message_attachments (group_id, uploader_id, content_type, bytes, byte_size)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [groupId, req.user!.id, type, clean, clean.length],
    );
    res.status(201).json({ id: rows[0].id, content_type: type, byte_size: clean.length });
  });

  router.get('/:groupId/attachments/:attachmentId', requireAuth, async (req, res) => {
    const groupId = String(req.params.groupId);
    const attachmentId = String(req.params.attachmentId);
    if (!UUID_RE.test(groupId) || !UUID_RE.test(attachmentId)) throw notFound();
    const myRole = await role(pool, groupId, req.user!.id);
    if (myRole === null) throw notFound();
    // Who may see it: anyone in the group once it is published; the
    // controller while its message is in review; the uploader always.
    const { rows } = await pool.query(
      `SELECT a.content_type, a.bytes
       FROM message_attachments a
       WHERE a.id = $1 AND a.group_id = $2
         AND (
           a.uploader_id = $3
           OR EXISTS (SELECT 1 FROM published_messages p WHERE p.attachment_id = a.id)
           OR ($4 AND EXISTS (SELECT 1 FROM raw_messages r WHERE r.attachment_id = a.id))
         )`,
      [attachmentId, groupId, req.user!.id, myRole === 'controller'],
    );
    if (!rows[0]) throw notFound();
    res.set({
      'Content-Type': rows[0].content_type,
      'Cache-Control': 'private, max-age=3600',
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'Content-Disposition': 'inline',
      'X-Content-Type-Options': 'nosniff',
    });
    res.send(rows[0].bytes);
  });

  return router;
}
