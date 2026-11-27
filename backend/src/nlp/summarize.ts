/**
 * "Catch up": an extractive summary of a group conversation (API.md 63).
 *
 * TextRank (Mihalcea & Tarau, 2004): sentences are nodes, TF-IDF cosine
 * similarity is the edge weight, and PageRank finds the sentences the rest
 * of the conversation keeps coming back to. The summary quotes those
 * sentences in the order they were said; it never names who said them, so
 * it cannot reveal an anonymous sender.
 */
import { classify, INTERESTS } from './topics';
import { cosine, idfOf, tfidf } from './rank';
import { stem, tokenize } from './text';

export interface SummaryMessage {
  text: string;
  at: Date;
}

export interface ConversationSummary {
  message_count: number;
  highlights: string[];
  open_questions: string[];
  key_topics: string[];
  themes: { id: string; label: string; icon: string }[];
}

interface Sentence {
  text: string;
  order: number;
  words: string[];
  terms: string[];
}

const MAX_SENTENCE = 220;

/** Splits a message into sentences; very short ones carry no content. */
export function sentencesOf(text: string): string[] {
  return text
    .replace(/\s+/g, ' ')
    .split(/(?<=[.!?])\s+(?=[A-Z0-9"'(])|\n+/)
    .map((s) => s.trim())
    .filter((s) => tokenize(s).length >= 3);
}

function pageRank(weights: number[][], damping = 0.85, iterations = 40): number[] {
  const n = weights.length;
  const outSum = weights.map((row) => row.reduce((a, b) => a + b, 0));
  let score = new Array<number>(n).fill(1 / n);
  for (let it = 0; it < iterations; it++) {
    const next = new Array<number>(n).fill((1 - damping) / n);
    for (let j = 0; j < n; j++) {
      if (outSum[j] === 0) {
        // A sentence like no other spreads its weight evenly.
        for (let i = 0; i < n; i++) next[i] += (damping * score[j]) / n;
        continue;
      }
      for (let i = 0; i < n; i++) {
        if (weights[j][i] > 0) next[i] += (damping * score[j] * weights[j][i]) / outSum[j];
      }
    }
    score = next;
  }
  return score;
}

function clip(s: string): string {
  return s.length > MAX_SENTENCE ? `${s.slice(0, MAX_SENTENCE - 3).trimEnd()}...` : s;
}

export function summarize(messages: SummaryMessage[], opts: { highlights?: number } = {}): ConversationSummary {
  const maxHighlights = opts.highlights ?? 3;
  const ordered = [...messages].sort((a, b) => a.at.getTime() - b.at.getTime());
  const sentences: Sentence[] = [];
  for (const m of ordered) {
    for (const text of sentencesOf(m.text)) {
      const words = tokenize(text);
      sentences.push({ text, order: sentences.length, words, terms: words.map(stem) });
    }
  }
  const empty: ConversationSummary = {
    message_count: messages.length,
    highlights: [],
    open_questions: [],
    key_topics: [],
    themes: [],
  };
  if (sentences.length === 0) return empty;

  const idf = idfOf(sentences.map((s) => s.terms));
  const vecs = sentences.map((s) => tfidf(s.terms, idf));
  const n = sentences.length;
  const weights = vecs.map((a, i) => vecs.map((b, j) => (i === j ? 0 : cosine(a, b))));
  const score = pageRank(weights);

  // Highest-ranked sentences, skipping near-repeats, shown in the order said.
  const byScore = sentences.map((_, i) => i).sort((a, b) => score[b] - score[a] || a - b);
  const picked: number[] = [];
  for (const i of byScore) {
    if (picked.length >= maxHighlights) break;
    if (sentences[i].text.endsWith('?')) continue;
    if (picked.some((p) => weights[p][i] > 0.6)) continue;
    picked.push(i);
  }
  // A conversation of nothing but questions still gets highlights.
  if (picked.length === 0) picked.push(...byScore.slice(0, Math.min(maxHighlights, n)));
  picked.sort((a, b) => a - b);

  const questions = byScore.filter((i) => sentences[i].text.endsWith('?') && !picked.includes(i)).slice(0, 2);

  // Key topics: stems with the most TF-IDF weight, shown as their most
  // common spelling (the shorter one on a tie: "review", not "reviews").
  const weight = new Map<string, number>();
  const spelling = new Map<string, Map<string, number>>();
  sentences.forEach((s, i) => {
    for (const [t, w] of vecs[i]) weight.set(t, (weight.get(t) ?? 0) + w * (1 + score[i] * n));
    s.words.forEach((word, k) => {
      const forms = spelling.get(s.terms[k]) ?? new Map<string, number>();
      forms.set(word, (forms.get(word) ?? 0) + 1);
      spelling.set(s.terms[k], forms);
    });
  });
  const keyTopics = [...weight.entries()]
    .filter(([t]) => t.length >= 3 && !/^\d+$/.test(t) && (spelling.get(t) ? [...spelling.get(t)!.values()].reduce((a, b) => a + b, 0) : 0) >= 2)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([t]) => [...spelling.get(t)!.entries()].sort((a, b) => b[1] - a[1] || a[0].length - b[0].length)[0][0]);

  const themes = classify(null, ordered.map((m) => m.text).join('\n'))
    .filter((t) => t.score >= 0.25)
    .slice(0, 2)
    .map((t) => INTERESTS.find((i) => i.id === t.id)!)
    .filter(Boolean)
    .map(({ id, label, icon }) => ({ id, label, icon }));

  return {
    message_count: messages.length,
    highlights: picked.map((i) => clip(sentences[i].text)),
    open_questions: questions.sort((a, b) => a - b).map((i) => clip(sentences[i].text)),
    key_topics: keyTopics,
    themes,
  };
}
