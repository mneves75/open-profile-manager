import { loadFont as loadInter } from "@remotion/google-fonts/Inter";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";

const inter = loadInter("normal", {
  weights: ["400", "500", "600", "700"],
  subsets: ["latin", "latin-ext"],
});
const mono = loadMono("normal", {
  weights: ["400"],
  subsets: ["latin", "latin-ext"],
});

// Monochrome Apple-style system.
export const theme = {
  bg: "#0a0a0a",
  panel: "#131315",
  panelBorder: "rgba(255, 255, 255, 0.12)",
  text: "#f5f5f7",
  dim: "#a1a1aa",
  faint: "#6b7280",
  fontUI: inter.fontFamily,
  fontMono: mono.fontFamily,
} as const;

export const SFX = {
  key: "sfx/key.wav",
  click: "sfx/click.wav",
  whoosh: "sfx/whoosh.wav",
  roomtone: "sfx/roomtone.wav",
} as const;

export const VOLUME = {
  key: 0.35,
  click: 0.4,
  whoosh: 0.3,
  roomtone: 0.04,
} as const;

// Deterministic PRNG — renders must be reproducible, no Math.random.
export const mulberry32 = (seed: number): (() => number) => {
  let a = seed | 0;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};
