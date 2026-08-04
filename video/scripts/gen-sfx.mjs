import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RATE = 44100;
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "public", "sfx");
mkdirSync(OUT, { recursive: true });

const random = (() => {
  let seed = 0x4f504d;
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let value = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    value = value + Math.imul(value ^ (value >>> 7), 61 | value) ^ value;
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
})();

const noise = () => random() * 2 - 1;

const wav = (samples) => {
  const dataSize = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataSize);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write("WAVEfmt ", 8);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(RATE, 24);
  buffer.writeUInt32LE(RATE * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(dataSize, 40);
  samples.forEach((sample, index) => buffer.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + index * 2));
  return buffer;
};

const synth = (seconds, sample) => {
  const length = Math.round(seconds * RATE);
  return Array.from({ length }, (_, index) => sample(index / RATE, index / length));
};

const sounds = {
  "key.wav": synth(0.03, (time, progress) => {
    const envelope = Math.exp(-progress * 15);
    return (noise() * 0.42 + Math.sin(2 * Math.PI * 1800 * time) * 0.08) * envelope;
  }),
  "click.wav": synth(0.12, (time, progress) => {
    const fundamental = Math.sin(2 * Math.PI * (105 - 38 * progress) * time);
    const body = Math.sin(2 * Math.PI * (58 - 12 * progress) * time);
    const transient = noise() * Math.exp(-progress * 45);
    const envelope = Math.min(1, progress * 35) * Math.exp(-progress * 7.2);
    return (fundamental * 0.48 + body * 0.30 + transient * 0.12) * envelope;
  }),
  "whoosh.wav": synth(0.35, (time, progress) => {
    const sweep = Math.sin(2 * Math.PI * (260 + 1100 * progress) * time) * 0.1;
    const envelope = Math.sin(Math.PI * progress) ** 1.5;
    return (noise() * 0.32 + sweep) * envelope;
  }),
  "roomtone.wav": synth(10, (_time, progress) => {
    const edgeFade = Math.min(1, progress * 200, (1 - progress) * 200);
    return noise() * 0.006 * edgeFade;
  }),
};

for (const [name, samples] of Object.entries(sounds)) {
  writeFileSync(join(OUT, name), wav(samples));
  console.log(`wrote ${name} (${(samples.length / RATE).toFixed(2)}s)`);
}
