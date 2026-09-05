import React from "react";
import { useCurrentFrame } from "remotion";
import { SFX, theme, VOLUME, mulberry32 } from "../theme";
import { Sfx } from "./Sfx";

const GAP = 10; // beat between line 1 finishing and line 2 starting

// Cursor-announcement-style title card: line 1 types at 1 char/frame, then
// line 2, then holds.

export const TypeCard: React.FC<{
  lines: string[];
  fontSize?: number;
  kicker?: string;
  seed?: number;
}> = ({ lines, fontSize = 54, kicker, seed = 11 }) => {
  const frame = useCurrentFrame();
  const rand = mulberry32(seed);

  const starts: number[] = [];
  let at = 0;
  for (const line of lines) {
    starts.push(at);
    at += line.length + GAP;
  }
  const typingDone = at - GAP;

  const keys: { at: number; rate: number }[] = [];
  lines.forEach((line, i) => {
    for (let c = 0; c < line.length; c += 2) {
      keys.push({ at: starts[i] + c, rate: 0.9 + rand() * 0.25 });
    }
  });

  let active = 0;
  starts.forEach((s, i) => {
    if (s <= frame) active = i;
  });

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: theme.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 18,
        fontFamily: theme.fontUI,
        textAlign: "center",
        padding: "0 80px",
      }}
    >
      {kicker ? (
        <div
          style={{
            color: theme.faint,
            fontSize: fontSize * 0.35,
            letterSpacing: 6,
            textTransform: "uppercase",
            fontFamily: theme.fontMono,
          }}
        >
          {kicker}
        </div>
      ) : null}
      {lines.map((line, i) => {
        const chars = Math.max(0, Math.min(line.length, frame - starts[i] + 1));
        if (chars === 0 && i > 0 && frame < starts[i]) {
          return <div key={i} style={{ height: fontSize * 1.3 }} />;
        }
        const showCursor =
          i === active && (frame < typingDone || frame % 30 < 18);
        return (
          <div
            key={i}
            style={{
              color: theme.text,
              fontSize,
              fontWeight: 600,
              letterSpacing: -1,
              minHeight: fontSize * 1.3,
            }}
          >
            {line.slice(0, chars)}
            {showCursor ? (
              <span
                style={{ borderLeft: `4px solid ${theme.text}`, marginLeft: 6 }}
              >
                &nbsp;
              </span>
            ) : null}
          </div>
        );
      })}
      {keys.map((k, i) => (
        <Sfx
          key={i}
          src={SFX.key}
          at={k.at}
          volume={VOLUME.key}
          playbackRate={k.rate}
        />
      ))}
    </div>
  );
};
