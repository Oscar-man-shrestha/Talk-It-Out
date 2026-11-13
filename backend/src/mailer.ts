import nodemailer from 'nodemailer';
import { Config } from './config';

export interface Mail {
  to: string;
  subject: string;
  text: string;
}

export interface Mailer {
  send(mail: Mail): Promise<void>;
}

/** Mails sent with MAIL_TRANSPORT=memory (tests only). */
export const memoryOutbox: Mail[] = [];

function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  return `${local.slice(0, 1)}***@${domain ?? ''}`;
}

/**
 * Builds the configured mailer, or null when email is disabled. Mail
 * bodies are never logged except by the explicit dev-only 'log' transport.
 */
export function createMailer(appConfig: Config): Mailer | null {
  switch (appConfig.mailTransport) {
    case 'disabled':
      return null;
    case 'memory':
      return {
        async send(mail) {
          memoryOutbox.push(mail);
        },
      };
    case 'log':
      return {
        async send(mail) {
          // Development only (refused when NODE_ENV=production).
          console.log(`[dev-mail] to ${maskEmail(mail.to)}: ${mail.subject}\n${mail.text}`);
        },
      };
    case 'smtp': {
      const transport = nodemailer.createTransport(appConfig.smtpUrl);
      return {
        async send(mail) {
          await transport.sendMail({ from: appConfig.mailFrom, ...mail });
        },
      };
    }
  }
}
