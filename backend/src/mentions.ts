/**
 * @mentions in group messages (API.md 68). Only the published text (what
 * the group sees) is searched, and the notification never names the
 * sender, so a mention cannot reveal who wrote an anonymous message.
 */
import { PoolClient } from 'pg';
import { fold } from './nlp/text';

export interface MentionMember {
  id: string;
  name: string;
  handle: string | null;
}

/**
 * Member ids mentioned in a text as @Full Name, @handle, or @FirstName when
 * no other member shares that first name. Case and accents are ignored.
 */
export function findMentions(text: string, members: MentionMember[]): string[] {
  if (!text.includes('@')) return [];
  const folded = fold(text);
  const firstCounts = new Map<string, number>();
  for (const m of members) {
    const first = fold(m.name).split(/\s+/)[0];
    if (first) firstCounts.set(first, (firstCounts.get(first) ?? 0) + 1);
  }
  const boundary = (s: string, at: number) => at >= s.length || !/[a-z0-9_.]/.test(s[at]);
  const has = (needle: string) => {
    if (!needle) return false;
    let from = 0;
    for (;;) {
      const i = folded.indexOf(`@${needle}`, from);
      if (i < 0) return false;
      if (boundary(folded, i + needle.length + 1)) return true;
      from = i + 1;
    }
  };
  const found: string[] = [];
  for (const m of members) {
    const full = fold(m.name).replace(/\s+/g, ' ').trim();
    const first = full.split(' ')[0];
    if (
      has(full) ||
      (m.handle && has(fold(m.handle))) ||
      (first && firstCounts.get(first) === 1 && has(first))
    ) {
      found.push(m.id);
    }
  }
  return found;
}

/** Notifies mentioned members of a just-published message. */
export async function notifyMentions(
  client: PoolClient,
  groupId: string,
  messageId: string,
  text: string,
  authorId: string | null,
): Promise<void> {
  if (!text.includes('@')) return;
  const { rows } = await client.query<MentionMember>(
    `SELECT u.id, u.name, CASE WHEN u.username_chosen THEN u.username END AS handle
     FROM group_members m JOIN users u ON u.id = m.user_id
     WHERE m.group_id = $1`,
    [groupId],
  );
  const ids = findMentions(text, rows).filter((id) => id !== authorId);
  if (ids.length === 0) return;
  await client.query(
    `INSERT INTO notifications (recipient_id, type, ref_id, group_id)
     SELECT unnest($1::uuid[]), 'mentioned', $2, $3`,
    [ids, messageId, groupId],
  );
}
