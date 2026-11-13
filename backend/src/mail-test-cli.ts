/**
 * npm run mail:test -- you@example.com
 *
 * Sends one test email through the configured MAIL_TRANSPORT, so SMTP
 * settings (for example a Gmail app password) can be checked without
 * going through the password-reset flow. Prints only success or the error
 * type, never credentials.
 */
import { loadConfig } from './config';
import { createMailer } from './mailer';

async function main(): Promise<number> {
  const to = (process.argv[2] ?? '').trim();
  if (!to.includes('@')) {
    console.error('usage: npm run mail:test -- you@example.com');
    return 2;
  }
  const appConfig = loadConfig();
  const mailer = createMailer(appConfig);
  if (!mailer) {
    console.error('MAIL_TRANSPORT is disabled; set it to smtp in backend/.env first.');
    return 2;
  }
  try {
    await mailer.send({
      to,
      subject: 'Talk It Out test email',
      text: 'Email delivery works. Password-reset codes will arrive like this.',
    });
  } catch (err) {
    const e = err as { code?: string; responseCode?: number; name?: string };
    console.error(
      `send failed: ${e.code ?? e.name ?? 'error'}${e.responseCode ? ` (${e.responseCode})` : ''}`,
    );
    if (e.code === 'EAUTH') {
      console.error('Check SMTP_USER and SMTP_PASS (Gmail needs an app password, not your normal password).');
    }
    return 1;
  }
  console.log(`sent via ${appConfig.mailTransport} from ${appConfig.mailFrom}`);
  return 0;
}

main().then((code) => process.exit(code));
