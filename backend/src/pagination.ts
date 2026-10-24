import { Request } from 'express';
import { badRequest } from './errors';

export const DEFAULT_LIMIT = 50;
export const MAX_LIMIT = 100;

export interface PageCursor {
  /** Sort-column value (ISO timestamp) of the last item on the previous page. */
  t: string;
  /** Tiebreaker id of the last item on the previous page. */
  i: string;
}

export interface ListQuery {
  limit: number;
  cursor: PageCursor | null;
}

export function encodeCursor(cursor: PageCursor): string {
  return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
}

export function decodeCursor(raw: string): PageCursor {
  try {
    const parsed = JSON.parse(
      Buffer.from(raw, 'base64url').toString('utf8'),
    ) as unknown;
    if (
      parsed &&
      typeof parsed === 'object' &&
      typeof (parsed as PageCursor).t === 'string' &&
      typeof (parsed as PageCursor).i === 'string'
    ) {
      return parsed as PageCursor;
    }
  } catch {
    // Fall through to the shared error below.
  }
  throw badRequest('invalid_cursor', 'That page link is no longer valid.');
}

export function parseListQuery(req: Request): ListQuery {
  let limit = DEFAULT_LIMIT;
  const rawLimit = req.query.limit;
  if (rawLimit !== undefined) {
    if (typeof rawLimit !== 'string') {
      throw badRequest('bad_request', 'Invalid limit.');
    }
    const parsed = Number.parseInt(rawLimit, 10);
    if (Number.isNaN(parsed) || parsed < 1) {
      throw badRequest('bad_request', 'Invalid limit.');
    }
    limit = Math.min(parsed, MAX_LIMIT);
  }

  let cursor: PageCursor | null = null;
  const rawCursor = req.query.cursor;
  if (typeof rawCursor === 'string' && rawCursor.length > 0) {
    cursor = decodeCursor(rawCursor);
  }

  return { limit, cursor };
}

/**
 * Builds {items, next_cursor} from a keyset-paginated query that fetched
 * limit + 1 rows. Rows are raw database rows; mapTo turns them into the
 * response shape and pickCursor reads the sort key off the last returned row.
 */
export function buildPage<Row, Item>(
  rows: Row[],
  limit: number,
  pickCursor: (row: Row) => PageCursor,
  mapTo: (row: Row) => Item,
): { items: Item[]; next_cursor: string | null } {
  const hasMore = rows.length > limit;
  const pageRows = hasMore ? rows.slice(0, limit) : rows;
  return {
    items: pageRows.map(mapTo),
    next_cursor:
      hasMore && pageRows.length > 0
        ? encodeCursor(pickCursor(pageRows[pageRows.length - 1]))
        : null,
  };
}

