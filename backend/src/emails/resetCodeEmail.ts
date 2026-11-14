/**
 * The password-reset email: a plain-text part and an HTML part in the
 * app's monochrome style. Table layout with inline styles, because email
 * clients ignore <style> blocks and modern CSS.
 */

export interface ResetEmail {
  subject: string;
  text: string;
  html: string;
}

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

export function resetCodeEmail(opts: {
  name: string;
  code: string;
  minutes: number;
  contact: string;
}): ResetEmail {
  const first = opts.name.trim().split(/\s+/)[0] || 'there';
  const name = escapeHtml(first);
  const contact = escapeHtml(opts.contact);
  const digits = opts.code
    .split('')
    .map(
      (d) =>
        `<td style="width:44px;height:56px;border:1px solid #111111;border-radius:10px;` +
        `background:#ffffff;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:28px;` +
        `font-weight:700;color:#111111;text-align:center;vertical-align:middle;">${d}</td>` +
        `<td style="width:8px;"></td>`,
    )
    .join('');

  const subject = `${opts.code} is your Talk It Out reset code`;

  const text = [
    `Hi ${first},`,
    '',
    'Use this code to reset your Talk It Out password:',
    '',
    `    ${opts.code}`,
    '',
    `It expires in ${opts.minutes} minutes and works once.`,
    '',
    "If you didn't ask to reset your password, ignore this email. Your",
    'password stays the same and nobody can change it without this code.',
    '',
    'Never share this code. Talk It Out will never ask you for it.',
    '',
    '— Talk It Out',
    opts.contact,
  ].join('\n');

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Your code expires in ${opts.minutes} minutes.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f4f5;">
<tr><td align="center" style="padding:32px 16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid #e4e4e7;border-radius:16px;">
    <tr><td style="padding:28px 32px 0 32px;">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr>
        <td style="width:36px;height:36px;background:#111111;border-radius:10px;text-align:center;vertical-align:middle;font-family:Helvetica,Arial,sans-serif;font-size:15px;font-weight:800;color:#ffffff;">T</td>
        <td style="padding-left:10px;font-family:Helvetica,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:1.4px;color:#52525b;">TALK IT OUT</td>
      </tr></table>
    </td></tr>
    <tr><td style="padding:24px 32px 0 32px;font-family:Helvetica,Arial,sans-serif;">
      <h1 style="margin:0;font-size:22px;line-height:28px;font-weight:800;letter-spacing:-0.3px;color:#111111;">Reset your password</h1>
      <p style="margin:12px 0 0 0;font-size:15px;line-height:22px;color:#3f3f46;">Hi ${name}, use this code to reset your Talk It Out password.</p>
    </td></tr>
    <tr><td align="center" style="padding:24px 32px 8px 32px;">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr>${digits}</tr></table>
    </td></tr>
    <tr><td align="center" style="padding:8px 32px 0 32px;font-family:Helvetica,Arial,sans-serif;font-size:13px;line-height:20px;color:#71717a;">
      Expires in <strong style="color:#111111;">${opts.minutes} minutes</strong> &middot; works once
    </td></tr>
    <tr><td style="padding:24px 32px 0 32px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#fafafa;border:1px solid #e4e4e7;border-radius:10px;">
        <tr><td style="padding:14px 16px;font-family:Helvetica,Arial,sans-serif;font-size:13px;line-height:20px;color:#3f3f46;">
          <strong style="color:#111111;">Didn't ask for this?</strong> Ignore this email. Your password stays the same, and nobody can change it without this code.
        </td></tr>
      </table>
    </td></tr>
    <tr><td style="padding:16px 32px 28px 32px;font-family:Helvetica,Arial,sans-serif;font-size:12px;line-height:18px;color:#71717a;">
      Never share this code. Talk It Out will never ask you for it.
    </td></tr>
  </table>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;">
    <tr><td align="center" style="padding:16px 32px 0 32px;font-family:Helvetica,Arial,sans-serif;font-size:11px;line-height:17px;color:#a1a1aa;">
      Talk It Out &middot; candid feedback without fear<br>${contact}
    </td></tr>
  </table>
</td></tr>
</table>
</body>
</html>`;

  return { subject, text, html };
}
