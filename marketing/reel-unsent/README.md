# Talk It Out — "Unsent" (Instagram Reel)

28 seconds · 1080×1920 · 30 fps · original soundtrack (synthesized, no licensing needed) · loudness −14 LUFS.

| File | What it is |
|---|---|
| `talk-it-out-unsent.mp4` | The reel, ready to upload |
| `talk-it-out-unsent-no-audio.mp4` | The same video without sound, if you want to add a trending track in Instagram |
| `make_reel.py` | Renders the reel and its soundtrack (`python3 make_reel.py --silent`; `--stills` for review frames) |
| `fonts/` | Inter (SIL Open Font License, see `OFL-LICENSE.txt`) |

The AI rewrite shown in the reel is real output from the project's model (Qwen2.5-3B through the pipeline).

## Feature tour from real screenshots (English, 88 s)

| File | What it is |
|---|---|
| `talk-it-out-feature-tour-real.mp4` | 11 feature chapters, every phone screen a real capture of the app |
| `make_real_tour.py` | Builds it from `showcase/shots/` (`--stills 20 40` for review frames) |
| `showcase/seed.py` | Seeds the showcase story into a **local** backend through the API (test accounts `@example.test`) |
| `showcase/cap.py` | Drives the live web build with Playwright and saves 3× screenshots |
| `showcase/shots/` | The 32 real screenshots (1170×2445), usable on their own for the App Store, Play Store or posts |

To recapture: run the backend (`:3000`), the worker and the live web build (`:52001`), then `python3 showcase/seed.py part1`, `cap.py priya_compose` (with `SEND=1`), `rahul_review` (with `PUBLISH=1`), `priya_after`, `python3 showcase/seed.py part2`, then the remaining `cap.py` steps. The invite link in `07_qr.png` is a local address; the film blurs it.

`make_tour.py` is the earlier, illustrated version of the tour.

## Story

1. **Dark, 0–7 s.** Someone types *"This plan makes no sense and nobody listens to us."*, hovers over Send, and deletes it. *Kyunki sach bolna risky lagta hai.*
2. **Light, 7–22 s.** *Ab ek aur raasta hai.* The same message goes through Talk It Out as an anonymous message. The AI rewrites the tone and keeps the meaning, the lead publishes it, and the group responds well.
3. **Payoff, 22–28 s.** *Sach bhi bola. Rishte bhi bache.* End card: *Talk It Out — Sach bolo. Shaanti se.* — with the honest note that anonymous messages are visible to the group's controller.

## Caption

> Kuch baatein zaroori hoti hain, par kehna mushkil.
> Talk It Out pe likho. AI tone sambhalta hai, lead review karta hai, aur group tak sirf point pahunchta hai.
> Us dost ko tag karo jo meetings mein chup reh jaata hai.

`#TalkItOut #WorkplaceCulture #CorporateIndia #OfficeLife #TeamCommunication #PsychologicalSafety #FutureOfWork #ReelsIndia`

## Posting

- Cover frame: the "Kyunki sach bolna risky lagta hai." card (around 6 s).
- Post Tuesday to Thursday, 7–9 pm IST.
- Pin a comment: *"Aapne last unsent message kisko likha tha? 👀"*
- Try the reel as a Trial Reel first and compare 3-second hold rate.
