import { readFileSync } from 'node:fs';
import path from 'node:path';
import supertest from 'supertest';
import { describe, expect, it } from 'vitest';
import { LEGAL_PAGES, markdownToHtml } from '../src/legal';
import { testApp } from './helpers';

describe('legal pages (API 62)', () => {
  it('serves each page without sign-in', async () => {
    const app = testApp();
    for (const name of LEGAL_PAGES) {
      const res = await supertest(app).get(`/legal/${name}`);
      expect(res.status, name).toBe(200);
      expect(res.type).toBe('text/html');
      expect(res.text).toContain('talkitoutapp.mail@gmail.com');
    }
    expect((await supertest(app).get('/legal/nope')).status).toBe(404);
  });

  it('matches the text the app shows', () => {
    for (const name of LEGAL_PAGES) {
      const server = readFileSync(path.join(__dirname, '..', 'legal', `${name}.md`), 'utf8');
      const app = readFileSync(path.join(__dirname, '..', '..', 'assets', 'legal', `${name}.md`), 'utf8');
      expect(server, `${name}.md differs between backend/legal and assets/legal`).toBe(app);
    }
  });

  it('escapes HTML and renders lists and bold', () => {
    expect(markdownToHtml('# A <b>\n\n- **x** y\n- z\n\npara')).toBe(
      '<h1>A &lt;b&gt;</h1>\n<ul>\n<li><strong>x</strong> y</li>\n<li>z</li>\n</ul>\n<p>para</p>',
    );
  });
});
