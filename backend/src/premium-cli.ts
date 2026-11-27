/**
 * npm run premium -- grant <email> [days]   (no days: no end date)
 * npm run premium -- revoke <email>
 * npm run premium -- status <email>
 *
 * Manual Premium for testing and pilot users (provider 'manual'). Store
 * purchases arrive through the RevenueCat webhook instead (API.md 71).
 */
import { config } from './config';
import { createPool } from './db';
import { entitlementsFor, upsertSubscription } from './premium';

async function main(): Promise<number> {
  const [command, email, daysArg] = process.argv.slice(2);
  if (!['grant', 'revoke', 'status'].includes(command ?? '') || !email) {
    console.error('Usage: npm run premium -- grant|revoke|status <email> [days]');
    return 2;
  }
  const pool = createPool(config.databaseUrl);
  try {
    const { rows } = await pool.query<{ id: string }>('SELECT id FROM users WHERE email = $1', [email]);
    const user = rows[0];
    if (!user) {
      console.error('No account uses that email.');
      return 1;
    }
    if (command === 'grant') {
      const days = daysArg ? Number(daysArg) : null;
      if (days !== null && (!Number.isFinite(days) || days <= 0)) {
        console.error('Days must be a positive number.');
        return 2;
      }
      await upsertSubscription(pool, {
        userId: user.id,
        provider: 'manual',
        status: 'active',
        expiresAt: days === null ? null : new Date(Date.now() + days * 86_400_000),
      });
    } else if (command === 'revoke') {
      await upsertSubscription(pool, {
        userId: user.id,
        provider: 'manual',
        status: 'expired',
        expiresAt: new Date(),
      });
    }
    console.log(JSON.stringify(await entitlementsFor(pool, user.id)));
    return 0;
  } finally {
    await pool.end();
  }
}

main().then(
  (code) => process.exit(code),
  (error: unknown) => {
    console.error(error instanceof Error ? error.message : 'Premium command failed.');
    process.exit(1);
  },
);
