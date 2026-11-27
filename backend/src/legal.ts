/**
 * Public legal pages for Google Play and the web (API.md 62):
 * /legal/privacy, /legal/terms and /legal/delete-account. The Markdown in
 * backend/legal is the same text the app shows (test/legal.test.ts checks).
 */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { Router } from 'express';

export const LEGAL_PAGES = ['privacy', 'terms', 'delete-account'] as const;

const escape = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const inline = (s: string) => escape(s).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');

/** The small Markdown subset the legal pages use: #/## headings, lists, bold. */
export function markdownToHtml(md: string): string {
  const out: string[] = [];
  let list = false;
  let para: string[] = [];
  const flush = () => {
    if (para.length) out.push(`<p>${inline(para.join(' '))}</p>`);
    para = [];
  };
  for (const raw of md.split('\n')) {
    const line = raw.trimEnd();
    if (line.startsWith('- ')) {
      flush();
      if (!list) out.push('<ul>');
      list = true;
      out.push(`<li>${inline(line.slice(2))}</li>`);
      continue;
    }
    if (list) {
      out.push('</ul>');
      list = false;
    }
    if (line.startsWith('## ')) {
      flush();
      out.push(`<h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith('# ')) {
      flush();
      out.push(`<h1>${inline(line.slice(2))}</h1>`);
    } else if (line === '') {
      flush();
    } else {
      para.push(line);
    }
  }
  flush();
  if (list) out.push('</ul>');
  return out.join('\n');
}

function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)} · Talk It Out</title>
<style>
body{margin:0;background:#fafafa;color:#09090b;font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:32px 16px 64px}
h1{font-size:28px;line-height:1.2;margin:0 0 8px}h2{font-size:19px;margin:28px 0 6px}
p,li{color:#27272a}a{color:#09090b}ul{padding-left:22px}
nav{font-size:14px;margin-bottom:24px}nav a{margin-right:14px;color:#71717a}
</style></head><body><main>
<nav><a href="privacy">Privacy</a><a href="terms">Terms</a><a href="delete-account">Delete account</a></nav>
${body}
</main></body></html>`;
}

export function createLegalRouter(dir = path.join(__dirname, '..', 'legal')): Router {
  const router = Router();
  const pages = new Map<string, string>();
  for (const name of LEGAL_PAGES) {
    const md = readFileSync(path.join(dir, `${name}.md`), 'utf8');
    const title = md.match(/^# (.+)$/m)?.[1] ?? 'Talk It Out';
    pages.set(name, page(title, markdownToHtml(md)));
  }
  router.get('/:page', (req, res, next) => {
    const html = pages.get(req.params.page);
    if (!html) {
      next();
      return;
    }
    res.set('Cache-Control', 'public, max-age=3600').type('html').send(html);
  });
  return router;
}
