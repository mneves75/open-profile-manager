import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { SFX, theme, VOLUME, mulberry32 } from "../theme";
import { Sfx } from "./Sfx";

export type TermLine =
  | { cmd: string; cpf?: number } // typed at cpf chars/frame (default 1, per the Cursor reference)
  | { out: string; dim?: boolean; bar?: number } // output line; bar renders an animated quota bar
  | { pause: number };

const POST_CMD = 8; // beat after a command finishes typing
const OUT_STEP = 5; // frames between output lines appearing

type Slot = { start: number; typeFrames: number };

const schedule = (lines: TermLine[]): { slots: Slot[]; total: number } => {
  const slots: Slot[] = [];
  let at = 0;
  for (const line of lines) {
    if ("cmd" in line) {
      const typeFrames = Math.ceil(line.cmd.length / (line.cpf ?? 1));
      slots.push({ start: at, typeFrames });
      at += typeFrames + POST_CMD;
    } else if ("out" in line) {
      slots.push({ start: at, typeFrames: 0 });
      at += OUT_STEP;
    } else {
      slots.push({ start: at, typeFrames: 0 });
      at += line.pause;
    }
  }
  return { slots, total: at };
};

export const terminalDuration = (lines: TermLine[], tail = 25): number =>
  schedule(lines).total + tail;

const Bar: React.FC<{ pct: number; sinceFrames: number }> = ({ pct, sinceFrames }) => {
  const w = interpolate(sinceFrames, [0, 15], [0, pct], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <span
      style={{
        display: "inline-block",
        width: 220,
        height: 9,
        marginLeft: 18,
        borderRadius: 5,
        background: "rgba(255,255,255,0.10)",
        verticalAlign: "middle",
        overflow: "hidden",
      }}
    >
      <span
        style={{
          display: "block",
          width: `${w}%`,
          height: "100%",
          borderRadius: 5,
          background: theme.text,
          opacity: 0.85,
        }}
      />
    </span>
  );
};

export const Terminal: React.FC<{
  lines: TermLine[];
  fontSize?: number;
  seed?: number;
  muted?: boolean;
}> = ({ lines, fontSize = 22, seed = 7, muted = false }) => {
  const frame = useCurrentFrame();
  const { slots } = schedule(lines);
  const rand = mulberry32(seed);

  // Keystroke sounds: one every 2 chars of every typed command, pitch jittered.
  const keys: { at: number; rate: number }[] = [];
  lines.forEach((line, i) => {
    if ("cmd" in line) {
      const cpf = line.cpf ?? 1;
      for (let c = 0; c < line.cmd.length; c += 2) {
        keys.push({ at: slots[i].start + Math.floor(c / cpf), rate: 0.9 + rand() * 0.25 });
      }
    } else if ("out" in line) {
      keys.push({ at: slots[i].start, rate: 0.7 });
    }
  });

  // Last line that has started is the "active" one (owns the cursor).
  let active = -1;
  slots.forEach((s, i) => {
    if (s.start <= frame) active = i;
  });

  const cursorVisible = (i: number): boolean => {
    if (i !== active) return false;
    const s = slots[i];
    const typing = frame < s.start + s.typeFrames;
    return typing || frame % 30 < 18;
  };

  return (
    <div
      style={{
        fontFamily: theme.fontMono,
        fontSize,
        lineHeight: 1.65,
        color: theme.text,
        padding: "20px 28px",
        whiteSpace: "pre-wrap",
      }}
    >
      {lines.map((line, i) => {
        const s = slots[i];
        if (s.start > frame) return null;
        if ("pause" in line) return null;
        const cursor = cursorVisible(i) ? (
          <span style={{ background: theme.text, color: theme.bg }}>&nbsp;</span>
        ) : null;
        if ("cmd" in line) {
          const cpf = line.cpf ?? 1;
          const chars = Math.min(line.cmd.length, Math.floor((frame - s.start + 1) * cpf));
          return (
            <div key={i}>
              <span style={{ color: theme.dim }}>❯ </span>
              {line.cmd.slice(0, chars)}
              {cursor}
            </div>
          );
        }
        return (
          <div key={i} style={{ color: line.dim ? theme.dim : theme.text }}>
            {line.out}
            {line.bar !== undefined ? <Bar pct={line.bar} sinceFrames={frame - s.start} /> : null}
          </div>
        );
      })}
      {muted
        ? null
        : keys.map((k, i) => (
            <Sfx key={i} src={SFX.key} at={k.at} volume={VOLUME.key} playbackRate={k.rate} />
          ))}
    </div>
  );
};
