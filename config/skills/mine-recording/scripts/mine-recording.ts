#!/usr/bin/env bun
/**
 * mine-recording — turn a screenshare recording into a timecoded set of distinct
 * UI frames + a transcript, so a walkthrough video can be mined into an actionable spec.
 */

import { existsSync } from "node:fs";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";
import { spawn, spawnSync } from "node:child_process";

const OUT_ROOT = ".local/recordings";
const WHISPER_CPP_MODELS = join(homedir(), "whisper-models");

type Probe = {
  duration: number;
  width: number;
  height: number;
  fps: number;
  hasAudio: boolean;
};

function log(msg: string) {
  console.log(`[mine-recording] ${msg}`);
}

function die(msg: string): never {
  console.error(`[mine-recording] ERROR: ${msg}`);
  process.exit(1);
}

function hms(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  return [Math.floor(s / 3600), Math.floor((s % 3600) / 60), s % 60]
    .map((n) => String(n).padStart(2, "0"))
    .join(":");
}

function runCmd(cmd: string, args: string[]): Promise<string> {
  return new Promise((res, rej) => {
    const proc = spawn(cmd, args, { shell: true, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    proc.stdout?.on("data", (d) => (stdout += d.toString()));
    proc.stderr?.on("data", (d) => (stderr += d.toString()));
    proc.on("close", (code) => {
      if (code === 0) res(stdout);
      else rej(new Error(`Command '${cmd} ${args.join(" ")}' failed (${code}): ${stderr}`));
    });
    proc.on("error", (err) => rej(err));
  });
}

async function probeVideo(video: string): Promise<Probe> {
  if (!existsSync(video)) die(`Video file not found: ${video}`);
  try {
    const raw = await runCmd("ffprobe", [
      "-v", "error",
      "-show_entries", "format=duration",
      "-show_entries", "stream=codec_type,width,height,r_frame_rate",
      "-of", "json",
      `"${video}"`
    ]);
    const json = JSON.parse(raw);
    const v = json.streams?.find((s: any) => s.codec_type === "video");
    if (!v) die("No video stream found in the file.");
    const [num, den] = String(v.r_frame_rate ?? "24/1").split("/").map(Number);
    return {
      duration: Number(json.format?.duration ?? 0),
      width: v.width,
      height: v.height,
      fps: den ? num / den : num,
      hasAudio: Boolean(json.streams?.some((s: any) => s.codec_type === "audio")),
    };
  } catch (e: any) {
    die(`ffprobe failed. Make sure ffmpeg/ffprobe is installed and added to PATH.\n${e.message}`);
  }
}

async function runDir(run: string): Promise<string> {
  const dir = resolve(OUT_ROOT, run);
  await mkdir(dir, { recursive: true });
  return dir;
}

/** probe — duration/geometry + sample stills for choosing crop */
async function cmdProbe(video: string, run: string, samples: number = 6) {
  const p = await probeVideo(video);
  const dir = join(await runDir(run), "probe");
  await mkdir(dir, { recursive: true });

  log(`Video: ${basename(video)}`);
  log(`  Duration: ${hms(p.duration)} | Resolution: ${p.width}x${p.height} | FPS: ${p.fps.toFixed(2)} | Audio: ${p.hasAudio}`);

  const written: string[] = [];
  for (let i = 1; i <= samples; i++) {
    const at = (p.duration * i) / (samples + 1);
    const out = join(dir, `probe_${String(Math.round(at)).padStart(5, "0")}s.jpg`);
    await runCmd("ffmpeg", [
      "-v", "error",
      "-ss", String(at),
      "-i", `"${video}"`,
      "-frames:v", "1",
      "-q:v", "3",
      `"${out}"`,
      "-y"
    ]);
    written.push(out);
  }
  log(`Wrote ${written.length} sample stills to: ${dir}`);
  for (const w of written) console.log(`  - ${w}`);
  log(`Inspect these stills, determine screenshare crop (W:H:X:Y), then run:`);
  log(`  bun scripts/mine-recording.ts frames "${video}" --run ${run} --crop W:H:X:Y [--threshold 0.02]`);
}

/** still — extract a single frame at an exact timestamp */
async function cmdStill(video: string, run: string, at: number, crop?: string) {
  const dir = join(await runDir(run), "stills");
  await mkdir(dir, { recursive: true });
  const out = join(dir, `t${String(Math.round(at)).padStart(5, "0")}.jpg`);
  const vfArgs = crop ? ["-vf", `crop=${crop}`] : [];
  await runCmd("ffmpeg", [
    "-v", "error",
    "-ss", String(at),
    "-i", `"${video}"`,
    ...vfArgs,
    "-frames:v", "1",
    "-q:v", "2",
    `"${out}"`,
    "-y"
  ]);
  log(`Saved frame at ${hms(at)} -> ${out}`);
}

/** frames — extract distinct scene frames with crop and threshold */
async function cmdFrames(
  video: string,
  run: string,
  crop?: string,
  threshold: number = 0.02,
  from?: number,
  to?: number
) {
  const dir = join(await runDir(run), "frames");
  await mkdir(dir, { recursive: true });

  log(`Extracting distinct UI frames (threshold=${threshold}, crop=${crop ?? "none"})...`);

  const vfFilters: string[] = [];
  if (crop) vfFilters.push(`crop=${crop}`);
  vfFilters.push(`select='gt(scene,${threshold})'`);

  const fromArgs = from !== undefined ? ["-ss", String(from)] : [];
  const toArgs = to !== undefined ? ["-to", String(to)] : [];

  const outPattern = join(dir, "frame_%04d.jpg");
  await runCmd("ffmpeg", [
    "-v", "error",
    ...fromArgs,
    "-i", `"${video}"`,
    ...toArgs,
    "-vf", `"${vfFilters.join(",")}"`,
    "-vsync", "vfr",
    "-q:v", "2",
    `"${outPattern}"`,
    "-y"
  ]);

  const files = (await readdir(dir)).filter((f) => f.endsWith(".jpg"));
  log(`Extracted ${files.length} UI frames into ${dir}`);
}

/** transcript — run local whisper */
async function cmdTranscript(video: string, run: string, model: string = "base.en") {
  const dir = join(await runDir(run), "transcript");
  await mkdir(dir, { recursive: true });

  const wavOut = join(dir, "audio.wav");
  log(`Extracting 16kHz mono audio for Whisper...`);
  await runCmd("ffmpeg", [
    "-v", "error",
    "-i", `"${video}"`,
    "-vn",
    "-ar", "16000",
    "-ac", "1",
    "-c:a", "pcm_s16le",
    `"${wavOut}"`,
    "-y"
  ]);

  const srtOut = join(dir, "transcript.srt");
  log(`Transcribing with Whisper (model: ${model})...`);

  // Try whisper-cli / whisper.cpp or python whisper
  let transcribed = false;
  try {
    const modelPath = join(WHISPER_CPP_MODELS, `ggml-${model}.bin`);
    if (existsSync(modelPath)) {
      await runCmd("whisper-cli", [
        "-m", `"${modelPath}"`,
        "-f", `"${wavOut}"`,
        "-osrt",
        "-of", `"${join(dir, "transcript")}"`
      ]);
      transcribed = true;
    }
  } catch {}

  if (!transcribed) {
    try {
      await runCmd("whisper", [
        `"${wavOut}"`,
        "--model", model,
        "--output_format", "all",
        "--output_dir", `"${dir}"`
      ]);
      transcribed = true;
    } catch (e: any) {
      log(`Note: Whisper CLI not found or failed. You can provide transcript manually under ${dir}`);
    }
  }

  if (transcribed) {
    log(`Transcript saved in ${dir}`);
  }
}

/** index — join frames + transcript into a master Markdown scaffold */
async function cmdIndex(run: string) {
  const base = await runDir(run);
  const framesDir = join(base, "frames");
  const transcriptDir = join(base, "transcript");

  const frames = existsSync(framesDir) ? (await readdir(framesDir)).filter((f) => f.endsWith(".jpg")).sort() : [];
  
  let transcriptText = "";
  const srtPath = join(transcriptDir, "transcript.srt");
  const txtPath = join(transcriptDir, "audio.txt");
  if (existsSync(srtPath)) {
    transcriptText = await readFile(srtPath, "utf-8");
  } else if (existsSync(txtPath)) {
    transcriptText = await readFile(txtPath, "utf-8");
  }

  const scaffold = [
    `# Walkthrough Findings & Index: ${run}`,
    ``,
    `## Summary Matrix`,
    `| Timecode | Frame | Screen / Step | Observed (Screen) | Stated (Audio) | Layer | Status |`,
    `|---|---|---|---|---|---|---|`,
  ];

  for (const f of frames) {
    scaffold.push(`| --:-- | [${f}](frames/${f}) | [Step Name] | [Fields / UI State] | [Spoken rules / traps] | \`[shared]\` | [ ] Pending |`);
  }

  scaffold.push(``);
  scaffold.push(`## Transcript Excerpt`);
  scaffold.push(`\`\`\`text`);
  scaffold.push(transcriptText.slice(0, 3000) || "(No transcript found - transcribe video first)");
  scaffold.push(`\`\`\``);

  const indexPath = join(base, "index.md");
  await writeFile(indexPath, scaffold.join("\n"), "utf-8");
  log(`Created findings index scaffold at: ${indexPath}`);
}

// CLI Arg Dispatcher
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  function getFlag(flag: string): string | undefined {
    const idx = args.indexOf(flag);
    return idx !== -1 && idx + 1 < args.length ? args[idx + 1] : undefined;
  }

  const run = getFlag("--run") || `run-${Date.now()}`;
  const video = args[1] && !args[1].startsWith("--") ? args[1] : undefined;

  switch (command) {
    case "probe": {
      if (!video) die("Usage: mine-recording.ts probe <video_path> --run <run_id>");
      const samples = Number(getFlag("--samples") ?? 6);
      await cmdProbe(video, run, samples);
      break;
    }
    case "frames": {
      if (!video) die("Usage: mine-recording.ts frames <video_path> --run <run_id> [--crop W:H:X:Y] [--threshold 0.02]");
      const crop = getFlag("--crop");
      const threshold = Number(getFlag("--threshold") ?? 0.02);
      const from = getFlag("--from") ? Number(getFlag("--from")) : undefined;
      const to = getFlag("--to") ? Number(getFlag("--to")) : undefined;
      await cmdFrames(video, run, crop, threshold, from, to);
      break;
    }
    case "still": {
      if (!video) die("Usage: mine-recording.ts still <video_path> --run <run_id> --at <seconds> [--crop W:H:X:Y]");
      const at = Number(getFlag("--at") ?? 0);
      const crop = getFlag("--crop");
      await cmdStill(video, run, at, crop);
      break;
    }
    case "transcript": {
      if (!video) die("Usage: mine-recording.ts transcript <video_path> --run <run_id> [--model base.en]");
      const model = getFlag("--model") ?? "base.en";
      await cmdTranscript(video, run, model);
      break;
    }
    case "index": {
      await cmdIndex(run);
      break;
    }
    default: {
      console.log(`
mine-recording CLI — Extract structured UI workflows from video walkthroughs.

Usage:
  bun scripts/mine-recording.ts <command> [args...]

Commands:
  probe <video> --run <id> [--samples 6]       Extract sample stills to determine crop
  frames <video> --run <id> [--crop W:H:X:Y]  Extract distinct UI transition frames
  still <video> --run <id> --at <sec>         Extract a single frame at exact seconds
  transcript <video> --run <id> [--model base.en] Transcribe audio locally with Whisper
  index --run <id>                             Join frames and transcript into index.md
      `);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
