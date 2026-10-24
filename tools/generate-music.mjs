/**
 * Roadster Flight — four original scene loops, authored specifically for this game.
 * Rebuild: node tools/generate-music.mjs
 * No samples, downloaded recordings, third-party packages, or copyrighted melodies.
 * 32 kHz stereo PCM16. Note tails and delay taps wrap around the musical loop.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = resolve(ROOT, 'assets/music');
const SAMPLE_RATE = 32000;
const TAU = Math.PI * 2;
const clamp = (n, low, high) => Math.max(low, Math.min(high, n));
const smooth = (n) => { const x = clamp(n, 0, 1); return x * x * (3 - 2 * x); };
const hz = (midi) => 440 * 2 ** ((midi - 69) / 12);
const db = (linear) => 20 * Math.log10(Math.max(1e-12, linear));

function random(seed) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13; state ^= state >>> 17; state ^= state << 5;
    return (state >>> 0) / 4294967296;
  };
}

class Song {
  constructor(id, title, bpm, bars, seed, description) {
    this.id = id; this.title = title; this.bpm = bpm; this.bars = bars;
    this.description = description;
    this.beat = 60 / bpm;
    this.frames = Math.round(bars * 4 * this.beat * SAMPLE_RATE);
    this.seconds = this.frames / SAMPLE_RATE;
    this.left = new Float64Array(this.frames);
    this.right = new Float64Array(this.frames);
    this.rng = random(seed);
    this.eventCount = 0;
  }

  mix(atBeat, seconds, gain, pan, synth) {
    const count = Math.ceil(seconds * SAMPLE_RATE);
    const start = Math.round(atBeat * this.beat * SAMPLE_RATE);
    const p = clamp(pan, -1, 1);
    const leftGain = gain * Math.sqrt((1 - p) / 2);
    const rightGain = gain * Math.sqrt((1 + p) / 2);
    this.eventCount += 1;
    for (let n = 0; n < count; n += 1) {
      const frame = ((start + n) % this.frames + this.frames) % this.frames;
      const sample = synth(n / SAMPLE_RATE, seconds, n);
      this.left[frame] += sample * leftGain;
      this.right[frame] += sample * rightGain;
    }
  }

  note(kind, midi, atBeat, beats, gain, pan = 0, shade = 0) {
    const f = hz(midi);
    const seconds = beats * this.beat;
    const phase = this.rng() * TAU;
    this.mix(atBeat, seconds, gain, pan, (t, duration) => {
      const end = smooth((duration - t) / Math.min(0.14, duration * 0.22));
      const x = TAU * f * t;
      if (kind === 'pad') {
        // Soft harmonic bed; sub-cent beating creates width without harsh saw teeth.
        const attack = smooth(t / Math.min(0.6, duration * 0.22));
        const release = smooth((duration - t) / Math.min(0.8, duration * 0.36));
        const drift = 0.08 * Math.sin(TAU * 0.19 * t + phase);
        const a = Math.sin(x + drift);
        const b = Math.sin(x * 1.0017 + phase) * 0.28;
        const c = Math.sin(x * 2 + phase * 0.4) * (shade ? 0.07 : 0.13);
        return (a + b + c) * attack * release * 0.72;
      }
      if (kind === 'bass') {
        const attack = smooth(t / 0.012);
        return (Math.sin(x) * 0.86 + Math.sin(x * 2) * 0.12 + Math.sin(x * 3) * 0.045)
          * attack * end * (0.62 + 0.38 * Math.exp(-t * 8));
      }
      if (kind === 'pluck') {
        const attack = smooth(t / 0.006);
        const decay = Math.exp(-t / (shade ? 0.36 : 0.24));
        return (Math.sin(x) + 0.27 * Math.sin(x * 2.001) * Math.exp(-t * 5)
          + 0.12 * Math.sin(x * 3) * Math.exp(-t * 9)) * attack * end * decay;
      }
      if (kind === 'bell') {
        const attack = smooth(t / 0.009);
        return (Math.sin(x) * Math.exp(-t * 2.1) + Math.sin(x * 2.002) * 0.28 * Math.exp(-t * 4.5)
          + Math.sin(x * 3.01) * 0.06 * Math.exp(-t * 7)) * attack * end;
      }
      if (kind === 'lead') {
        const attack = smooth(t / 0.025);
        const vibrato = Math.sin(TAU * 4.4 * t) * 0.4 * smooth(t / 0.2);
        return (Math.sin(x + vibrato) * 0.81 + Math.sin(x * 2) * 0.13
          + Math.sin(x * 3) * 0.04) * attack * end * (0.8 + 0.2 * Math.exp(-t * 4));
      }
      throw new Error(`Unknown instrument ${kind}`);
    });
  }

  drum(kind, atBeat, gain, pan = 0) {
    const lengths = { kick: 0.42, snare: 0.25, hat: 0.095, shaker: 0.085, hand: 0.3, pulse: 0.65 };
    let noiseLow = 0;
    let noiseAir = 0;
    let phase = 0;
    this.mix(atBeat, lengths[kind], gain, pan, (t, duration) => {
      const noise = this.rng() * 2 - 1;
      noiseLow += 0.25 * (noise - noiseLow);
      noiseAir += 0.67 * (noise - noiseAir);
      const clickSafe = smooth(t / 0.0025) * smooth((duration - t) / 0.02);
      if (kind === 'kick' || kind === 'pulse') {
        const soft = kind === 'pulse';
        phase += TAU * ((soft ? 45 : 48) + (soft ? 25 : 92) * Math.exp(-t * 24)) / SAMPLE_RATE;
        return (Math.sin(phase) * Math.exp(-t * (soft ? 7 : 11))
          + noiseLow * (soft ? 0.015 : 0.06) * Math.exp(-t * 60)) * clickSafe;
      }
      if (kind === 'snare') {
        return (noiseLow * 1.6 * Math.exp(-t * 20) + Math.sin(TAU * 185 * t) * 0.28 * Math.exp(-t * 28)
          + Math.sin(TAU * 326 * t) * 0.12 * Math.exp(-t * 35)) * clickSafe;
      }
      if (kind === 'hand') {
        phase += TAU * (112 + 78 * Math.exp(-t * 22)) / SAMPLE_RATE;
        return (Math.sin(phase) * Math.exp(-t * 15) + noiseLow * 0.19 * Math.exp(-t * 38)) * clickSafe;
      }
      const brightNoise = noiseAir - noiseLow;
      return brightNoise * Math.exp(-t * (kind === 'hat' ? 48 : 65)) * clickSafe;
    });
  }

  finish(delayBeats, wet, cutoff) {
    // Circular feed-forward echoes retain reverberant tails at the loop boundary.
    const dryL = this.left.slice();
    const dryR = this.right.slice();
    const delays = [delayBeats, delayBeats * 2, delayBeats * 3, delayBeats * 4];
    for (let tap = 0; tap < delays.length; tap += 1) {
      const offset = Math.round(delays[tap] * this.beat * SAMPLE_RATE);
      const gain = wet * 0.47 ** tap;
      for (let i = 0; i < this.frames; i += 1) {
        const source = ((i - offset) % this.frames + this.frames) % this.frames;
        this.left[i] += (tap % 2 === 0 ? dryR[source] : dryL[source]) * gain;
        this.right[i] += (tap % 2 === 0 ? dryL[source] : dryR[source]) * gain;
      }
    }

    // Two settling passes give a periodic low-pass state rather than a start-up transient.
    const alpha = 1 - Math.exp(-TAU * cutoff / SAMPLE_RATE);
    for (const channel of [this.left, this.right]) {
      let filtered = 0;
      for (let pass = 0; pass < 2; pass += 1) {
        for (let i = 0; i < channel.length; i += 1) {
          filtered += alpha * (channel[i] - filtered);
          if (pass === 1) channel[i] = filtered;
        }
      }
      let sum = 0;
      for (const value of channel) sum += value;
      const mean = sum / channel.length;
      for (let i = 0; i < channel.length; i += 1) channel[i] = Math.tanh((channel[i] - mean) * 1.12);
    }
    let rawPeak = 0;
    for (let i = 0; i < this.frames; i += 1) rawPeak = Math.max(rawPeak, Math.abs(this.left[i]), Math.abs(this.right[i]));
    const gain = 0.8 / rawPeak;
    const data = Buffer.alloc(this.frames * 4);
    let peak = 0; let squares = 0; let dc = 0; let cross = 0; let energyL = 0; let energyR = 0;
    let maxStep = 0; let stepSquares = 0;
    const first = [0, 0]; const last = [0, 0]; const prev = [0, 0];
    for (let i = 0; i < this.frames; i += 1) {
      const pair = [this.left[i] * gain, this.right[i] * gain];
      for (let c = 0; c < 2; c += 1) {
        const pcm = Math.round(clamp(pair[c], -0.85, 0.85) * 32767);
        data.writeInt16LE(pcm, i * 4 + c * 2);
        const value = pcm / 32768;
        peak = Math.max(peak, Math.abs(value)); squares += value * value; dc += value;
        if (i === 0) first[c] = value;
        else { const step = value - prev[c]; maxStep = Math.max(maxStep, Math.abs(step)); stepSquares += step * step; }
        prev[c] = value; last[c] = value;
      }
      cross += pair[0] * pair[1]; energyL += pair[0] ** 2; energyR += pair[1] ** 2;
    }
    const header = Buffer.alloc(44);
    header.write('RIFF', 0); header.writeUInt32LE(36 + data.length, 4); header.write('WAVEfmt ', 8);
    header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
    header.writeUInt32LE(SAMPLE_RATE, 24); header.writeUInt32LE(SAMPLE_RATE * 4, 28);
    header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34); header.write('data', 36); header.writeUInt32LE(data.length, 40);
    writeFileSync(resolve(OUT, `${this.id}.wav`), Buffer.concat([header, data]));
    const rms = Math.sqrt(squares / (this.frames * 2));
    const boundaryJump = Math.max(...first.map((v, c) => Math.abs(v - last[c])));
    const report = {
      id: this.id, title: this.title, description: this.description,
      file: `assets/music/${this.id}.wav`, bytes: header.length + data.length,
      sampleRate: SAMPLE_RATE, channels: 2, bits: 16, bpm: this.bpm, bars: this.bars,
      frames: this.frames, durationSeconds: +this.seconds.toFixed(6),
      peak: +peak.toFixed(6), peakDbfs: +db(peak).toFixed(3),
      rms: +rms.toFixed(6), rmsDbfs: +db(rms).toFixed(3), dcOffset: +(dc / (this.frames * 2)).toFixed(8),
      stereoCorrelation: +(cross / Math.sqrt(energyL * energyR)).toFixed(5),
      loopBoundaryJump: +boundaryJump.toFixed(7), largestInternalSampleStep: +maxStep.toFixed(7),
      rmsInternalSampleStep: +Math.sqrt(stepSquares / ((this.frames - 1) * 2)).toFixed(7),
      synthesizedEvents: this.eventCount,
    };
    if (peak > 0.85 || !Number.isFinite(rms) || rms < 0.03 || boundaryJump > 0.06) {
      throw new Error(`${this.id}: audio quality guard failed: ${JSON.stringify(report)}`);
    }
    return report;
  }
}

function city() {
  const song = new Song('city', 'Midnight Ion Drive', 128, 16, 0x42696f6e,
    'Neon synthwave: warm minor-ninth pads, syncopated analog bass, electronic kick/snare, arpeggio and an original two-phrase lead.');
  const chords = [[52, 59, 62, 66], [48, 55, 59, 62], [55, 59, 62, 69], [50, 57, 60, 66]];
  const roots = [40, 36, 43, 38];
  const melodyA = [[0, 76, .65], [1, 79, .65], [2, 78, 1.25], [3.5, 74, .4]];
  const melodyB = [[.5, 74, .65], [1.5, 71, .65], [2.5, 74, 1.1]];
  for (let bar = 0; bar < song.bars; bar += 1) {
    const chord = chords[bar % 4]; const beat = bar * 4;
    chord.forEach((note, i) => song.note('pad', note, beat, 5, .075, (i - 1.5) * .4));
    for (const step of [0, .75, 1.5, 2, 2.75, 3.5]) song.note('bass', roots[bar % 4], beat + step, .44, .23);
    for (let n = 0; n < 8; n += 1) {
      song.note('pluck', chord[[0, 2, 1, 3, 2, 1, 3, 2][n]] + 12, beat + n * .5, .72,
        n % 2 ? .052 : .075, n % 2 ? .48 : -.48);
      song.drum('hat', beat + n * .5 + .02, n % 2 ? .13 : .085, n % 2 ? .3 : -.3);
    }
    for (const step of [0, 2, ...(bar % 4 === 3 ? [3.5] : [])]) song.drum('kick', beat + step, .43);
    song.drum('snare', beat + 1, .25, -.07); song.drum('snare', beat + 3, .25, .07);
    if (bar >= 4 && bar < 12) {
      const phrase = bar % 2 === 0 ? melodyA : melodyB;
      const transpose = [0, -4, 3, -2][bar % 4];
      phrase.forEach(([offset, note, length]) => song.note('lead', note + transpose, beat + offset, length, .095, .08));
    }
    if (bar === 15) for (const step of [3.25, 3.75]) song.drum('snare', beat + step, .10, step === 3.25 ? -.35 : .35);
  }
  return song.finish(.75, .12, 5700);
}

function desert() {
  const song = new Song('desert', 'Amber Dune Horizon', 104, 12, 0x43617261,
    'Warm desert electronica: plucked strings, hand percussion, wide suspended chords and a sparse modal melody.');
  const chords = [[50, 57, 60, 64], [48, 55, 62, 64], [46, 53, 57, 60], [48, 55, 58, 62]];
  const roots = [38, 36, 34, 36];
  const phrase = [[0, 74, .8], [1.5, 77, .65], [2.5, 76, .7], [3.5, 72, .8]];
  for (let bar = 0; bar < song.bars; bar += 1) {
    const beat = bar * 4; const chord = chords[bar % 4];
    chord.forEach((note, i) => song.note('pad', note, beat, 5.2, .078, (i - 1.5) * .5, 1));
    [0, 1.5, 2.75].forEach(step => song.note('bass', roots[bar % 4], beat + step, .82, .20));
    for (let n = 0; n < 8; n += 1) {
      const note = chord[[0, 2, 3, 1, 2, 0, 3, 2][n]] + 12;
      song.note('pluck', note, beat + n * .5, 1.1, n % 3 === 0 ? .12 : .078, n % 2 ? .55 : -.55, 1);
      song.drum('shaker', beat + n * .5 + .03, n % 2 ? .10 : .065, n % 2 ? .7 : -.7);
    }
    song.drum('kick', beat, .25);
    for (const [step, gain, pan] of [[1, .21, -.28], [2.5, .15, .3], [3, .22, .1], [3.75, .11, -.3]]) {
      song.drum('hand', beat + step, gain, pan);
    }
    if (bar % 4 === 1 || bar % 4 === 2) phrase.forEach(([offset, note, length]) =>
      song.note('pluck', note + (bar % 4 === 2 ? -2 : 0), beat + offset, length + .6, .12, .13, 1));
    if (bar % 4 === 3) song.note('bell', 69, beat + 2.5, 2.5, .055, -.45);
  }
  return song.finish(.75, .18, 4800);
}

function sky() {
  const song = new Song('sky', 'Cloudline Daybreak', 112, 12, 0x436c6f75,
    'Bright airborne ambience: major-seventh pads, glockenspiel-like bells, light syncopated pulse and floating arpeggios.');
  const chords = [[53, 60, 64, 69], [48, 55, 59, 64], [50, 57, 60, 65], [55, 62, 65, 69]];
  const roots = [41, 36, 38, 43];
  const melody = [[0, 81, .9], [1.5, 79, .8], [2.5, 76, 1.2]];
  for (let bar = 0; bar < song.bars; bar += 1) {
    const beat = bar * 4; const chord = chords[bar % 4];
    chord.forEach((note, i) => song.note('pad', note + (i === 3 ? 12 : 0), beat, 5.3, .07, (i - 1.5) * .49));
    [0, 2.5].forEach(step => song.note('bass', roots[bar % 4], beat + step, 1.1, .19));
    song.drum('pulse', beat, .25); song.drum('pulse', beat + 2, .20);
    song.drum('shaker', beat + 1, .10, -.5); song.drum('shaker', beat + 3, .10, .5);
    for (let n = 0; n < 8; n += 1) {
      song.note('bell', chord[[0, 1, 2, 3, 2, 1, 3, 1][n]] + 12, beat + n * .5,
        1.7, n % 2 ? .040 : .065, Math.sin(n * 1.7) * .68);
      if (n % 2) song.drum('hat', beat + n * .5, .06, -.25);
    }
    if (bar % 4 < 2) melody.forEach(([offset, note, length]) =>
      song.note('bell', note + (bar % 4 === 1 ? -2 : 0), beat + offset, length + .8, .09, .17));
    if (bar % 4 === 3) song.note('lead', 74, beat + 1, 2.6, .055, -.15);
  }
  return song.finish(.75, .23, 5000);
}

function underwater() {
  const song = new Song('underwater', 'Below the Blue', 72, 8, 0x53656173,
    'Slow deep-water ambience: dark suspended pads, soft water-drop bells, low pulses and spacious stereo echoes.');
  const chords = [[45, 52, 59, 60], [41, 48, 55, 57], [48, 55, 62, 64], [43, 50, 57, 59]];
  const roots = [33, 29, 36, 31];
  for (let bar = 0; bar < song.bars; bar += 1) {
    const beat = bar * 4; const chord = chords[bar % 4];
    chord.forEach((note, i) => song.note('pad', note, beat, 5.8, .095, (i - 1.5) * .52, 1));
    song.note('bass', roots[bar % 4], beat, 3.8, .18);
    song.drum('pulse', beat, .22); song.drum('pulse', beat + 2.5, .13);
    for (const [step, index, up, pan] of [[.75, 2, 12, -.65], [1.5, 3, 12, .35], [3.25, 1, 24, .6]]) {
      song.note('bell', chord[index] + up, beat + step, 2.2, .10, pan);
    }
    if (bar % 2 === 1) {
      song.note('pluck', chord[2] + 12, beat + 2, 2.4, .06, -.25, 1);
      song.drum('shaker', beat + 3.5, .055, .5);
    }
  }
  return song.finish(.75, .30, 3100);
}

mkdirSync(OUT, { recursive: true });
const tracks = [city(), desert(), sky(), underwater()];
const totalBytes = tracks.reduce((sum, track) => sum + track.bytes, 0);
if (totalBytes > 25 * 1024 * 1024) throw new Error('Music exceeds the 25 MiB resource budget.');
const report = {
  generator: 'tools/generate-music.mjs', deterministic: true,
  authorship: 'Original in-project composition and procedural PCM synthesis. No external music or samples.',
  audioVerification: 'Numeric PCM checks only; no claim of human listening approval.',
  loopMethod: 'Whole musical bars with circular note tails, circular delay taps, and periodic low-pass filter state.',
  totalBytes, tracks,
};
writeFileSync(resolve(OUT, 'music-report.json'), `${JSON.stringify(report, null, 2)}\n`);
console.table(tracks.map(({ id, durationSeconds, bytes, peak, rmsDbfs, loopBoundaryJump, synthesizedEvents }) =>
  ({ id, seconds: durationSeconds, MiB: +(bytes / 1048576).toFixed(2), peak, rmsDbfs, loopBoundaryJump, events: synthesizedEvents })));
console.log(`Original soundtrack: ${(totalBytes / 1048576).toFixed(2)} MiB. Reproducible report: assets/music/music-report.json`);
