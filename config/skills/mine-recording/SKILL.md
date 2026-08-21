---
name: mine-recording
description: Mine a screenshare recording (a customer walkthrough, Loom, or Meet/Zoom capture) for workflow steps, screen names, field labels, traps, and the business logic someone says out loud — the input to a new carrier/system skill when nobody can drive the live app for you. Use when handed an .mp4/.mov of someone demoing a workflow, or asked to "extract the flow from this recording", "watch this walkthrough", "get the steps out of this video". Sibling of `rpa-capture`, which mines a live browser for selectors.
---

# mine-recording — turn a walkthrough video into a buildable spec

We get sent recordings: a customer expert screenshares their real workflow for an hour and narrates it. That video is the only ground truth for a system we may not be able to drive ourselves yet. This skill mines it.

Driver: `scripts/mine-recording.ts`. Output lands under **`.local/recordings/<run>/`** (gitignored).

**Frames are the payload; the transcript is the index into them.** Neither alone is enough — the screen shows labels and option spellings but never *why*; the audio carries the judgment ("we always pick this", "that one's a trap") but never a field name. You need both, joined on timestamp.

---

## Hard limit — read this before promising anything

**A video gives labels and flow. It never gives selectors.** No DOM, no ids, no option values. Everything here feeds *what to build*; the hooks to build it with still require a live capture (`rpa-capture`) or direct app access.

The two compose in this order:
1. Mine the video first so you know the flow, branch points, and vocabulary.
2. Capture live (via `rpa-capture`) to get exact stable selectors.

---

## Prerequisites (100% Local & Open-Source)

- **`ffmpeg` & `ffprobe`**: in system PATH (Windows: `winget install Gyan.FFmpeg` or Chocolatey `choco install ffmpeg`).
- **`whisper-cli`** (`whisper.cpp`) with models under `~/whisper-models/` or Python `whisper` / `faster-whisper`.
- **Runtime**: `bun` or `npx tsx`.

---

## The Loop

```bash
V="path/to/Recording.mp4"

# 1. Probe — geometry, duration, and evenly spaced stills to pick the crop from.
bun scripts/mine-recording.ts probe "$V" --run <id> [--samples 6]

# 2. Inspect the stills. Find the screenshare rectangle. Then extract distinct frames.
bun scripts/mine-recording.ts frames "$V" --run <id> \
    --crop W:H:X:Y [--threshold 0.02] [--from S] [--to S]

# 3. Transcribe locally. Fast model over the whole video first.
bun scripts/mine-recording.ts transcript "$V" --run <id> --model base.en

# 4. Join frames + transcript into one master index to write findings against.
bun scripts/mine-recording.ts index --run <id>
```

Then `view_file` the frames the index points at. 
Use `still "$V" --run <id> --at <seconds>` to grab an exact moment the transcript flagged if no scene cut caught it.

---

## Crop Before Detecting

A call recording has the speaker's webcam pinned in a corner, and **a talking head moves far more than a form does** — detect scenes on the full frame and you get thousands of cuts of someone nodding, missing the page transitions entirely.

`probe` exists to let you inspect the layout and crop the webcam, participant strip, and browser chrome out:
- Standard 1080p recording (1920x1080, camera pinned right): `1440:1040:0:20` is a good starting point.

---

## Threshold: Start at 0.02, not ffmpeg's default 0.3

Scene score is a whole-frame difference, and a portal form barely moves it — a new wizard page can score lower than a jump cut in a movie:

| `--threshold` | frames / 180s | verdict |
|---|---|---|
| 0.08 | 1 | useless — missed an entire wizard page |
| 0.04 | 6 | thin |
| **0.02** | **9** | **good default (~300 frames for a 1.5h call)** |
| 0.005 | 19 | for a dense stretch you're studying closely |

### Bursts are scrolling — do not dedupe them
On form-heavy pages, a burst of frames is almost always the expert *scrolling*. Every frame in it carries fields the next one has already scrolled past. The burst is the field inventory. The gaps are dwell.

---

## Two-Tier Local Transcription

1. **Tier 1 (Whole Recording):** Run `base.en` (fast, takes ~1-2 min for 1h audio).
2. **Tier 2 (Targeted Moments):** Once the index shows which minutes contain domain terminology, re-run just those segments with a larger model (`medium.en` / `large-v3-turbo`) to verify terms and avoid phonetic transcription errors (e.g. `Indio` vs `NDO`).

---

## Cloud-Assisted Analysis (Optional Tier 3)

When the local pipeline has produced frames + transcript but deeper semantic understanding is needed (complex domain terminology, code on screen, architectural diagrams):

1. **Key frames → agent vision:** Feed extracted PNGs via `view_file` for OCR/code extraction.
2. **Short clips (< 10 min):** Pass the video file directly to the agent's multimodal capabilities for temporal grounding and audio-visual correlation.
3. **Targeted segments:** Use local Tier 1 index to identify minutes of interest, then re-analyze those segments with multimodal for precise extraction.

| Scenario | Path |
|---|---|
| Long recordings (30+ min), privacy-sensitive | Local pipeline (Tier 1-2) |
| Short bug demo, architecture walkthrough | Direct multimodal |
| Dense domain terms needing verification | Local Tier 1 → Cloud Tier 3 for segments |

**Hard constraint:** Never upload client-sensitive recordings without explicit user authorization.

---

## Tagging Discipline: Layer & Provenance

When creating the findings document, tag every finding:

- **Layer:**
  - `[shared]` **system mechanics:** Screens, wizard tabs, field labels, option spellings, error triggers.
  - `[org]` **business judgment:** Defaults assumed, when to refer vs push through, client-tier rules.
- **Provenance:**
  - `(observed)`: visible on screen (factual).
  - `(stated)`: said aloud by one person in the call (habit or policy — confirm before automating).

---

## Deliverables from a Mined Recording

1. **Findings Document** (`.local/plans/<ticket>-<system>-walkthrough.md`): Navigation path, field inventory per screen, branch points, and blocking conditions.
2. **Vocabulary File** (`references/vocab/<system>.md`): Option lists and **TRAPS** (fields that mean something other than their label, subtle invalid values).
3. **Question List**: Gaps, skipped branches, or scrolled-past screens for the follow-up live session.
