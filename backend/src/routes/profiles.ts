import { Request, Router } from 'express';
import multer from 'multer';
import { Pool, PoolClient } from 'pg';
import { z } from 'zod';
import { ApiError, conflict, notFound, parseWith } from '../errors';
import { RequireAuth } from '../middleware/auth';
import { withTransaction } from '../db';

/**
 * Public profiles, work experience, education, and profile images.
 *
 * Not used by the Flutter app yet (its profile screen is local-only); this
 * is the backend side of HANDOFF.md features 13 and 14, in this API's
 * snake_case conventions. Profiles carry no group, message, or anonymity
 * data. Email is only returned when you view your own profile.
 */

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const MAX_SKILLS = 50;
const MAX_ENTRIES = 50;

/** Rewrite tones a contributor can pick (migration 013). */
export const REWRITE_TONES = ['professional', 'direct', 'socratic', 'empathetic'] as const;

const text = (max: number) => z.string().trim().max(max, `Must be at most ${max} characters.`);

const profileUpdateSchema = z
  .object({
    name: z.string().trim().min(1, 'Enter your name.').max(200, 'Name is too long.'),
    headline: text(200),
    bio: text(2000),
    location: text(200),
    website: text(300),
    github_handle: text(100),
    twitter_handle: text(100),
    linkedin_url: text(300),
    rewrite_tone: z.enum(REWRITE_TONES, { error: () => 'Choose one of the listed tones.' }),
    skills: z
      .array(z.string().trim().min(1, 'Skills cannot be empty.').max(50, 'Skill is too long.'))
      .max(MAX_SKILLS, `At most ${MAX_SKILLS} skills.`),
  })
  .partial()
  .strict();

const isoDate = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Use a YYYY-MM-DD date.')
  .refine((value) => !Number.isNaN(Date.parse(`${value}T00:00:00Z`)), 'Use a real date.');

const experienceSchema = z
  .object({
    title: z.string().trim().min(1, 'Enter a title.').max(200),
    company: z.string().trim().min(1, 'Enter a company.').max(200),
    location: text(200).default(''),
    start_date: isoDate,
    end_date: isoDate.nullable().default(null),
    is_current: z.boolean().default(false),
    description: text(2000).default(''),
  })
  .strict()
  .refine((e) => !(e.is_current && e.end_date !== null), {
    message: 'A current role has no end date.',
    path: ['end_date'],
  })
  .refine((e) => e.end_date === null || e.end_date >= e.start_date, {
    message: 'End date must be on or after the start date.',
    path: ['end_date'],
  });

const year = z.number().int().min(1900).max(2200);

const educationSchema = z
  .object({
    school: z.string().trim().min(1, 'Enter a school.').max(200),
    degree: text(200).default(''),
    field_of_study: text(200).default(''),
    start_year: year.nullable().default(null),
    end_year: year.nullable().default(null),
  })
  .strict()
  .refine(
    (e) => e.start_year === null || e.end_year === null || e.end_year >= e.start_year,
    { message: 'End year must be on or after the start year.', path: ['end_year'] },
  );

/** Base URL prefix ('' or '/api/v1') this router was reached through. */
function apiPrefix(req: Request): string {
  return req.baseUrl.replace(/\/users$/, '');
}

function mediaUrl(req: Request, mediaId: string | null): string | null {
  if (!mediaId) return null;
  return `${req.protocol}://${req.get('host')}${apiPrefix(req)}/media/${mediaId}`;
}

interface ExperienceRow {
  id: string;
  title: string;
  company: string;
  location: string;
  start_date: string;
  end_date: string | null;
  is_current: boolean;
  description: string;
}

function experienceJson(row: ExperienceRow) {
  return {
    id: row.id,
    title: row.title,
    company: row.company,
    location: row.location,
    start_date: row.start_date,
    end_date: row.end_date,
    is_current: row.is_current,
    description: row.description,
  };
}

interface EducationRow {
  id: string;
  school: string;
  degree: string;
  field_of_study: string;
  start_year: number | null;
  end_year: number | null;
}

function educationJson(row: EducationRow) {
  return {
    id: row.id,
    school: row.school,
    degree: row.degree,
    field_of_study: row.field_of_study,
    start_year: row.start_year,
    end_year: row.end_year,
  };
}

// Dates are returned as text: a pg `date` parsed into a JS Date lands on
// local midnight and can shift a day when serialized in another timezone.
const EXPERIENCE_COLUMNS =
  'id, title, company, location, start_date::text AS start_date, ' +
  'end_date::text AS end_date, is_current, description';
const EDUCATION_COLUMNS = 'id, school, degree, field_of_study, start_year, end_year';

async function ensureProfileRow(client: Pool | PoolClient, userId: string): Promise<void> {
  await client.query(
    'INSERT INTO user_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
    [userId],
  );
}

async function loadProfile(pool: Pool, req: Request, userId: string, includeEmail: boolean) {
  const { rows } = await pool.query(
    `SELECT u.id, u.name, u.username, u.email,
            p.headline, p.bio, p.location, p.website, p.github_handle,
            p.twitter_handle, p.linkedin_url, p.skills,
            p.avatar_media_id, p.cover_media_id, p.rewrite_tone
     FROM users u
     LEFT JOIN user_profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId],
  );
  const row = rows[0];
  if (!row) throw notFound('We could not find that profile.');
  const [experiences, educations] = await Promise.all([
    pool.query(
      `SELECT ${EXPERIENCE_COLUMNS} FROM user_experiences WHERE user_id = $1
       ORDER BY is_current DESC, start_date DESC, created_at DESC`,
      [userId],
    ),
    pool.query(
      `SELECT ${EDUCATION_COLUMNS} FROM user_educations WHERE user_id = $1
       ORDER BY start_year DESC NULLS LAST, created_at DESC`,
      [userId],
    ),
  ]);
  return {
    user: {
      id: row.id,
      name: row.name,
      username: row.username,
      // Private settings only on your own profile.
      ...(includeEmail
        ? { email: row.email, rewrite_tone: row.rewrite_tone ?? 'professional' }
        : {}),
      headline: row.headline ?? '',
      bio: row.bio ?? '',
      location: row.location ?? '',
      website: row.website ?? '',
      github_handle: row.github_handle ?? '',
      twitter_handle: row.twitter_handle ?? '',
      linkedin_url: row.linkedin_url ?? '',
      skills: (row.skills as string[] | null) ?? [],
      avatar_url: mediaUrl(req, row.avatar_media_id),
      cover_url: mediaUrl(req, row.cover_media_id),
    },
    experiences: experiences.rows.map(experienceJson),
    educations: educations.rows.map(educationJson),
  };
}

function requireEntryId(value: string, what: string): string {
  if (!UUID_RE.test(value)) throw notFound(`We could not find that ${what}.`);
  return value;
}

/** Detects the image type from its first bytes; never trusts the header. */
export function sniffImageType(bytes: Buffer): 'image/png' | 'image/jpeg' | 'image/webp' | null {
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('latin1') === 'RIFF' &&
    bytes.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_IMAGE_BYTES, files: 1, fields: 0 },
});

/** Runs multer and maps its errors onto this API's error envelope. */
function readSingleFile(req: Request, res: import('express').Response): Promise<Express.Multer.File> {
  return new Promise((resolve, reject) => {
    upload.single('file')(req, res, (err: unknown) => {
      if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
          reject(new ApiError(413, 'file_too_large', 'Images must be 2 MB or smaller.'));
          return;
        }
        reject(new ApiError(422, 'validation', 'Upload one image in the "file" field.'));
        return;
      }
      if (err) {
        reject(new ApiError(422, 'validation', 'Upload one image in the "file" field.'));
        return;
      }
      if (!req.file) {
        reject(new ApiError(422, 'validation', 'Upload one image in the "file" field.'));
        return;
      }
      resolve(req.file);
    });
  });
}

export function createProfilesRouter(pool: Pool, requireAuth: RequireAuth): Router {
  const router = Router();
  router.use(requireAuth);

  router.get('/:userId/profile', async (req, res) => {
    const raw = req.params.userId;
    const userId = raw === 'me' ? req.user!.id : requireEntryId(raw, 'profile');
    res.json(await loadProfile(pool, req, userId, userId === req.user!.id));
  });

  router.put('/me/profile', async (req, res) => {
    const body = parseWith(profileUpdateSchema, req.body);
    const userId = req.user!.id;
    await withTransaction(pool, async (client) => {
      if (body.name !== undefined) {
        await client.query('UPDATE users SET name = $1 WHERE id = $2', [body.name, userId]);
      }
      await ensureProfileRow(client, userId);
      const columns = [
        'headline',
        'bio',
        'location',
        'website',
        'github_handle',
        'twitter_handle',
        'linkedin_url',
        'rewrite_tone',
      ] as const;
      const sets: string[] = [];
      const values: unknown[] = [];
      for (const column of columns) {
        if (body[column] !== undefined) {
          values.push(body[column]);
          sets.push(`${column} = $${values.length}`);
        }
      }
      if (body.skills !== undefined) {
        // Case-insensitive de-duplication, first spelling wins.
        const seen = new Set<string>();
        const skills = body.skills.filter((skill) => {
          const key = skill.toLowerCase();
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
        values.push(skills);
        sets.push(`skills = $${values.length}`);
      }
      if (sets.length > 0) {
        values.push(userId);
        await client.query(
          `UPDATE user_profiles SET ${sets.join(', ')}, updated_at = now()
           WHERE user_id = $${values.length}`,
          values,
        );
      }
    });
    res.json(await loadProfile(pool, req, userId, true));
  });

  // --- Experience ---------------------------------------------------------

  router.post('/me/experiences', async (req, res) => {
    const body = parseWith(experienceSchema, req.body);
    const userId = req.user!.id;
    const { rows: count } = await pool.query(
      'SELECT count(*)::int AS n FROM user_experiences WHERE user_id = $1',
      [userId],
    );
    if (count[0].n >= MAX_ENTRIES) {
      throw conflict('too_many_entries', `You can add at most ${MAX_ENTRIES} roles.`);
    }
    const { rows } = await pool.query(
      `INSERT INTO user_experiences
         (user_id, title, company, location, start_date, end_date, is_current, description)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING ${EXPERIENCE_COLUMNS}`,
      [
        userId,
        body.title,
        body.company,
        body.location,
        body.start_date,
        body.end_date,
        body.is_current,
        body.description,
      ],
    );
    res.status(201).json(experienceJson(rows[0]));
  });

  router.put('/me/experiences/:entryId', async (req, res) => {
    const entryId = requireEntryId(req.params.entryId, 'role');
    const body = parseWith(experienceSchema, req.body);
    const { rows } = await pool.query(
      `UPDATE user_experiences
       SET title = $3, company = $4, location = $5, start_date = $6,
           end_date = $7, is_current = $8, description = $9
       WHERE id = $1 AND user_id = $2
       RETURNING ${EXPERIENCE_COLUMNS}`,
      [
        entryId,
        req.user!.id,
        body.title,
        body.company,
        body.location,
        body.start_date,
        body.end_date,
        body.is_current,
        body.description,
      ],
    );
    if (!rows[0]) throw notFound('We could not find that role.');
    res.json(experienceJson(rows[0]));
  });

  router.delete('/me/experiences/:entryId', async (req, res) => {
    const entryId = requireEntryId(req.params.entryId, 'role');
    const { rowCount } = await pool.query(
      'DELETE FROM user_experiences WHERE id = $1 AND user_id = $2',
      [entryId, req.user!.id],
    );
    if (rowCount === 0) throw notFound('We could not find that role.');
    res.status(204).end();
  });

  // --- Education ----------------------------------------------------------

  router.post('/me/educations', async (req, res) => {
    const body = parseWith(educationSchema, req.body);
    const userId = req.user!.id;
    const { rows: count } = await pool.query(
      'SELECT count(*)::int AS n FROM user_educations WHERE user_id = $1',
      [userId],
    );
    if (count[0].n >= MAX_ENTRIES) {
      throw conflict('too_many_entries', `You can add at most ${MAX_ENTRIES} schools.`);
    }
    const { rows } = await pool.query(
      `INSERT INTO user_educations
         (user_id, school, degree, field_of_study, start_year, end_year)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${EDUCATION_COLUMNS}`,
      [userId, body.school, body.degree, body.field_of_study, body.start_year, body.end_year],
    );
    res.status(201).json(educationJson(rows[0]));
  });

  router.put('/me/educations/:entryId', async (req, res) => {
    const entryId = requireEntryId(req.params.entryId, 'school');
    const body = parseWith(educationSchema, req.body);
    const { rows } = await pool.query(
      `UPDATE user_educations
       SET school = $3, degree = $4, field_of_study = $5, start_year = $6, end_year = $7
       WHERE id = $1 AND user_id = $2
       RETURNING ${EDUCATION_COLUMNS}`,
      [
        entryId,
        req.user!.id,
        body.school,
        body.degree,
        body.field_of_study,
        body.start_year,
        body.end_year,
      ],
    );
    if (!rows[0]) throw notFound('We could not find that school.');
    res.json(educationJson(rows[0]));
  });

  router.delete('/me/educations/:entryId', async (req, res) => {
    const entryId = requireEntryId(req.params.entryId, 'school');
    const { rowCount } = await pool.query(
      'DELETE FROM user_educations WHERE id = $1 AND user_id = $2',
      [entryId, req.user!.id],
    );
    if (rowCount === 0) throw notFound('We could not find that school.');
    res.status(204).end();
  });

  // --- Images -------------------------------------------------------------

  for (const kind of ['avatar', 'cover'] as const) {
    router.post(`/me/${kind}`, async (req, res) => {
      const file = await readSingleFile(req, res);
      const contentType = sniffImageType(file.buffer);
      if (!contentType) {
        throw new ApiError(415, 'unsupported_media_type', 'Upload a PNG, JPEG, or WebP image.');
      }
      const userId = req.user!.id;
      const column = kind === 'avatar' ? 'avatar_media_id' : 'cover_media_id';
      const mediaId = await withTransaction(pool, async (client) => {
        const { rows } = await client.query(
          `INSERT INTO media (owner_id, kind, content_type, bytes, byte_size)
           VALUES ($1, $2, $3, $4, $5) RETURNING id`,
          [userId, kind, contentType, file.buffer, file.buffer.length],
        );
        const id = rows[0].id as string;
        await ensureProfileRow(client, userId);
        await client.query(
          `UPDATE user_profiles SET ${column} = $1, updated_at = now() WHERE user_id = $2`,
          [id, userId],
        );
        // Keep only the latest image of this kind.
        await client.query(
          'DELETE FROM media WHERE owner_id = $1 AND kind = $2 AND id <> $3',
          [userId, kind, id],
        );
        return id;
      });
      res.status(201).json({ url: mediaUrl(req, mediaId) });
    });

    router.delete(`/me/${kind}`, async (req, res) => {
      const userId = req.user!.id;
      const column = kind === 'avatar' ? 'avatar_media_id' : 'cover_media_id';
      await withTransaction(pool, async (client) => {
        await client.query(
          `UPDATE user_profiles SET ${column} = NULL, updated_at = now() WHERE user_id = $1`,
          [userId],
        );
        await client.query('DELETE FROM media WHERE owner_id = $1 AND kind = $2', [
          userId,
          kind,
        ]);
      });
      res.status(204).end();
    });
  }

  return router;
}

/**
 * Serves uploaded profile images. Public by design (profile images are
 * public and must work in an <img> tag without an auth header); ids are
 * random UUIDs. Bytes are only ever served with their sniffed type.
 */
export function createMediaRouter(pool: Pool): Router {
  const router = Router();
  router.get('/:mediaId', async (req, res) => {
    const mediaId = req.params.mediaId;
    if (!UUID_RE.test(mediaId)) throw notFound();
    const { rows } = await pool.query(
      'SELECT content_type, bytes FROM media WHERE id = $1',
      [mediaId],
    );
    if (!rows[0]) throw notFound();
    res.set({
      'Content-Type': rows[0].content_type,
      'Cache-Control': 'public, max-age=86400, immutable',
      // Allow the Flutter web app on another origin to display it.
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'Content-Disposition': 'inline',
    });
    res.send(rows[0].bytes);
  });
  return router;
}
