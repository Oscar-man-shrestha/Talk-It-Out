import { z, ZodError } from 'zod';

// Friendly defaults for zod 4's generic messages. Messages written on a
// schema (for example 'Enter your name.') still take precedence.
z.config({
  customError: (issue) => {
    if (issue.code === 'invalid_type') {
      return issue.input === undefined ? 'This field is required.' : `Expected ${issue.expected}.`;
    }
    if (issue.code === 'unrecognized_keys') {
      return `Unexpected field: ${issue.keys.join(', ')}.`;
    }
    return undefined;
  },
});

/**
 * Every non-2xx response uses the envelope {"error":{"code","message"}} —
 * the Flutter client relies on that shape.
 */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

export const unauthorized = (message = 'Please log in again.') =>
  new ApiError(401, 'unauthorized', message);
export const forbidden = (message = 'You are not allowed to do that.') =>
  new ApiError(403, 'forbidden', message);
export const notFound = (message = 'We could not find that.') =>
  new ApiError(404, 'not_found', message);
export const conflict = (code: string, message: string) =>
  new ApiError(409, code, message);
export const badRequest = (code: string, message: string) =>
  new ApiError(400, code, message);

/** Parses a request body with a zod schema; throws a 422 ApiError on failure. */
export function parseWith<T>(schema: { parse: (data: unknown) => T }, body: unknown): T {
  try {
    return schema.parse(body);
  } catch (err) {
    if (err instanceof ZodError) {
      const issue = err.issues[0];
      const where = issue?.path?.length ? ` (${issue.path.join('.')})` : '';
      throw new ApiError(
        422,
        'validation',
        `${issue?.message ?? 'Invalid input.'}${where}`,
      );
    }
    throw err;
  }
}
