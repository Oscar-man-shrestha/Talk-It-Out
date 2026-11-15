import { describe, expect, it } from 'vitest';
import { editDistance, jaroWinkler, matchPerson, phoneticKey } from '../src/nlp/fuzzy';
import { fold, nameKey, stem, terms } from '../src/nlp/text';
import { classify, INTERESTS } from '../src/nlp/topics';
import { rankForYou, RankPost, searchPosts, similarPosts, ViewerProfile } from '../src/nlp/rank';

describe('text', () => {
  it('folds accents and case, and keys names', () => {
    expect(fold('José ÑÚÑEZ')).toBe('jose nunez');
    expect(nameKey('Arhaat_99')).toBe('arhat');
    expect(nameKey('oscar.man')).toBe('oscarman');
  });

  it('stems word families to one form', () => {
    expect(new Set(['promoted', 'promotion', 'promoting'].map(stem)).size).toBe(1);
    expect(new Set(['manager', 'managing', 'manage'].map(stem)).size).toBe(1);
    expect(new Set(['policy', 'policies'].map(stem)).size).toBe(1);
    expect(new Set(['meeting', 'meetings'].map(stem)).size).toBe(1);
    expect(terms('The and of')).toEqual([]);
  });
});

describe('fuzzy matching', () => {
  it('counts typos, including swapped letters', () => {
    expect(editDistance('rohan', 'rohan')).toBe(0);
    expect(editDistance('rhoan', 'rohan')).toBe(1);
    expect(editDistance('rohn', 'rohan')).toBe(1);
    expect(jaroWinkler('martha', 'marhta')).toBeGreaterThan(0.95);
  });

  it('gives sound-alike names the same key', () => {
    expect(phoneticKey('Katherine')).toBe(phoneticKey('Catherine'));
    expect(phoneticKey('Shrestha')).toBe(phoneticKey('Shresta'));
    expect(phoneticKey('Vikram')).toBe(phoneticKey('Wikram'));
    expect(phoneticKey('Rohan')).not.toBe(phoneticKey('Ronak'));
  });

  const rohan = { name: 'Rohan Shrestha', username: 'rohan.s', usernameChosen: true };
  const hidden = { name: 'Priya Rao', username: 'priya.rao.work', usernameChosen: false };

  it('ranks exact > prefix > typo > sound-alike', () => {
    expect(matchPerson('rohan.s', rohan)).toEqual({ score: 1, kind: 'exact' });
    expect(matchPerson('@roh', rohan)?.kind).toBe('prefix');
    expect(matchPerson('shre', rohan)?.kind).toBe('prefix');
    const typo = matchPerson('rhoan', rohan)!;
    expect(typo.kind).toBe('similar');
    const sound = matchPerson('shresta', rohan)!;
    expect(sound).not.toBeNull();
    expect(matchPerson('rohan', rohan)!.score).toBeGreaterThan(typo.score);
    expect(matchPerson('zzzz', rohan)).toBeNull();
  });

  it('matches an unchosen username only exactly', () => {
    expect(matchPerson('priya.rao.work', hidden)?.kind).toBe('exact');
    expect(matchPerson('priya.rao.w', hidden)?.kind).not.toBe('prefix');
    // The name still matches as usual.
    expect(matchPerson('pri', hidden)?.kind).toBe('prefix');
  });
});

describe('topics', () => {
  it('has 30 interests with unique ids', () => {
    expect(INTERESTS).toHaveLength(30);
    expect(new Set(INTERESTS.map((i) => i.id)).size).toBe(30);
  });

  it('tags posts with ranked topics', () => {
    const t = classify('How do I ask for a promotion?', 'My manager keeps delaying my performance review and the raise.');
    const ids = t.map((x) => x.id);
    expect(ids[0]).toBe('career_growth');
    expect(ids).toContain('compensation');
    expect(classify(null, 'I am so burned out, working every weekend')[0].id).toBe('wellbeing');
    expect(classify(null, 'qwerty zxcv')).toEqual([]);
  });

  it('trusts the author-chosen topic', () => {
    expect(classify(null, 'salary raise bonus', 'safety')[0].id).toBe('safety');
  });
});

describe('For You ranking', () => {
  const now = new Date('2026-11-14T12:00:00Z');
  const hoursAgo = (h: number) => new Date(now.getTime() - h * 3600000);
  const post = (id: string, content: string, extra: Partial<RankPost> = {}): RankPost => ({
    id,
    title: null,
    content,
    topic: null,
    authorId: `author-${id}`,
    createdAt: hoursAgo(10),
    likes: 0,
    comments: 0,
    inMyGroups: false,
    engagedByMe: false,
    ...extra,
  });
  const viewer = (extra: Partial<ViewerProfile> = {}): ViewerProfile => ({
    userId: 'me',
    picked: [],
    engaged: [],
    hidden: new Set(),
    disliked: new Map(),
    now,
    ...extra,
  });

  const posts = [
    post('pay', 'How should I negotiate my salary and bonus?'),
    post('burn', 'Burnout from late night on call shifts every weekend'),
    post('code', 'Our code review and tech debt keeps growing'),
  ];

  it('puts picked interests first and explains why', () => {
    const ranked = rankForYou(posts, viewer({ picked: ['compensation'] }));
    expect(ranked[0].id).toBe('pay');
    expect(ranked[0].reason.kind).toBe('interest');
    expect(ranked[0].reason.text).toBe('Because you follow Pay & equity');
  });

  it('learns from engagement', () => {
    const ranked = rankForYou(posts, viewer({
      engaged: [{ title: null, content: 'tech debt in our code base', topic: null, weight: 1, at: hoursAgo(1) }],
    }));
    expect(ranked[0].id).toBe('code');
  });

  it('hides posts and pushes down disliked topics', () => {
    const ranked = rankForYou(posts, viewer({
      picked: ['compensation'],
      hidden: new Set(['burn']),
      disliked: new Map([['compensation', 3]]),
    }));
    expect(ranked.map((r) => r.id)).not.toContain('burn');
    expect(ranked[0].id).not.toBe('pay');
  });

  it('shows your own new question first, then not', () => {
    const fresh = rankForYou([
      ...posts,
      post('mine', 'my new question', { authorId: 'me', createdAt: hoursAgo(0.2) }),
    ], viewer({ picked: ['compensation'] }));
    expect(fresh[0]).toMatchObject({ id: 'mine', reason: { kind: 'yours', text: 'Your new question' } });
    const old = rankForYou([
      ...posts,
      post('mine', 'my old question', { authorId: 'me', createdAt: hoursAgo(5) }),
    ], viewer({ picked: ['compensation'] }));
    expect(old[old.length - 1].id).toBe('mine');
  });

    it('cold start: engagement and freshness lead', () => {
    const ranked = rankForYou([
      post('old', 'something', { createdAt: hoursAgo(24 * 20) }),
      post('hot', 'something else', { likes: 9, comments: 4, createdAt: hoursAgo(5) }),
    ], viewer());
    expect(ranked[0].id).toBe('hot');
  });

  it('does not show one topic three times in a row when others exist', () => {
    const many = [
      ...[1, 2, 3, 4].map((i) => post(`pay${i}`, `salary bonus raise negotiation ${i}`)),
      post('well', 'burnout stress weekend'),
    ];
    const ranked = rankForYou(many, viewer({ picked: ['compensation'] }));
    const firstFour = ranked.slice(0, 4).map((r) => r.id);
    expect(firstFour).toContain('well');
  });
});

describe('feed search', () => {
  const docs = [
    { id: 'a', title: 'Promotion advice', content: 'How do I get promoted to senior engineer?' },
    { id: 'b', title: 'Remote work', content: 'Working from home with a team in another time zone' },
    { id: 'c', title: null, content: 'Burnout and stress at the end of the quarter' },
  ];

  it('matches word families', () => {
    expect(searchPosts(docs, 'promoting').ids[0]).toBe('a');
  });

  it('survives typos and suggests a correction', () => {
    const r = searchPosts(docs, 'burnuot');
    expect(r.ids[0]).toBe('c');
    expect(r.didYouMean).toBe('burnout');
  });

  it('matches the last word as a prefix while typing', () => {
    expect(searchPosts(docs, 'remo').ids[0]).toBe('b');
  });

  it('returns nothing for nonsense', () => {
    expect(searchPosts(docs, 'xyzzy').ids).toEqual([]);
  });
});

describe('similar questions', () => {
  const docs = [
    { id: 'promo', title: 'How do I ask my manager for a promotion?', content: 'I have been a senior engineer for two years.' },
    { id: 'remote', title: 'Remote work across time zones', content: 'Meetings at midnight are hard.' },
    { id: 'pay', title: 'Is my salary fair?', content: 'No raise this year.' },
  ];

  it('finds a question asked in other words', () => {
    const hits = similarPosts(docs, 'Asking my manager about getting promoted', 'Senior engineer, two years, no promotion yet');
    expect(hits[0].id).toBe('promo');
    expect(hits.map((h) => h.id)).not.toContain('remote');
  });

  it('stays quiet for unrelated or tiny drafts', () => {
    expect(similarPosts(docs, 'Lunch', 'Where to eat near the office?')).toEqual([]);
    expect(similarPosts(docs, null, 'hi')).toEqual([]);
  });
});

