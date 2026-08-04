import React from "react";
import { AbsoluteFill, Audio, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { MacWindow } from "./components/MacWindow";
import { Terminal, type TermLine } from "./components/Terminal";
import { BGM_SRC, SFX, theme, VOLUME, mulberry32 } from "./theme";

export const SoundBed: React.FC = () => (
  <>
    <Audio src={staticFile(SFX.roomtone)} volume={() => VOLUME.roomtone} loop />
    {BGM_SRC ? <Audio src={staticFile(BGM_SRC)} volume={() => 0.2} loop /> : null}
  </>
);

export const Backdrop: React.FC<{ seed?: number; quiet?: boolean }> = ({ seed = 1, quiet = false }) => {
  const frame = useCurrentFrame();
  const random = mulberry32(seed);
  const particles = Array.from({ length: quiet ? 10 : 22 }, () => ({
    x: random() * 100,
    y: random() * 100,
    r: 1 + random() * 2,
    phase: random() * Math.PI * 2,
  }));
  return (
    <AbsoluteFill style={{
      background: [
        "radial-gradient(circle at 50% 14%, rgba(255,255,255,0.065), transparent 38%)",
        "linear-gradient(rgba(255,255,255,0.025) 1px, transparent 1px)",
        "linear-gradient(90deg, rgba(255,255,255,0.025) 1px, transparent 1px)",
        theme.bg,
      ].join(","),
      backgroundSize: "auto, 48px 48px, 48px 48px, auto",
    }}>
      {particles.map((particle, index) => {
        const drift = Math.sin(frame / 38 + particle.phase) * 7;
        return <div key={index} style={{
          position: "absolute", left: `${particle.x}%`, top: `${particle.y}%`,
          width: particle.r, height: particle.r, borderRadius: "50%",
          background: theme.text, opacity: quiet ? 0.08 : 0.14,
          transform: `translateY(${drift}px)`,
        }} />;
      })}
    </AbsoluteFill>
  );
};

export const TerminalStage: React.FC<{
  title: string; lines: TermLine[]; fontSize?: number; caption?: string; chapter?: number; seed?: number;
}> = ({ title, lines, fontSize = 23, caption, chapter, seed = 7 }) => (
  <AbsoluteFill style={{ background: theme.bg, color: theme.text }}>
    <Backdrop seed={seed} quiet />
    <div style={{ position: "absolute", inset: chapter ? "92px 112px 118px" : "62px 58px 88px", display: "flex" }}>
      <MacWindow title={title} width="100%" height="100%" entrance3d>
        <Terminal lines={lines} fontSize={fontSize} seed={seed} />
      </MacWindow>
    </div>
    {caption ? <Caption>{caption}</Caption> : null}
    {chapter ? <ChapterMark current={chapter} total={6} /> : null}
  </AbsoluteFill>
);

export const Caption: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [18, 32], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return <div style={{
    position: "absolute", left: 0, right: 0, bottom: 28, color: theme.dim,
    fontFamily: theme.fontUI, fontSize: 18, textAlign: "center", letterSpacing: -0.2, opacity,
  }}>{children}</div>;
};

export const ChapterMark: React.FC<{ current: number; total: number }> = ({ current, total }) => (
  <div style={{
    position: "absolute", right: 60, bottom: 48, display: "flex", alignItems: "center", gap: 10,
    color: theme.faint, fontFamily: theme.fontMono, fontSize: 16,
  }}>
    {Array.from({ length: total }, (_, index) => <span key={index} style={{
      width: index + 1 === current ? 22 : 6, height: 6, borderRadius: 3,
      background: index + 1 <= current ? theme.text : theme.faint,
      opacity: index + 1 === current ? 1 : 0.45,
    }} />)}
    <span style={{ marginLeft: 6 }}>{String(current).padStart(2, "0")} / {String(total).padStart(2, "0")}</span>
  </div>
);

export const SpringTitle: React.FC<{ title: string; subtitle: string; kicker?: string }> = ({ title, subtitle, kicker }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const reveal = spring({ frame, fps, config: { damping: 160 }, durationInFrames: 38 });
  return <AbsoluteFill style={{
    background: theme.bg, color: theme.text, alignItems: "center", justifyContent: "center",
    fontFamily: theme.fontUI, textAlign: "center",
  }}>
    <Backdrop seed={31} />
    <div style={{
      position: "relative", opacity: reveal,
      transform: `translateY(${interpolate(reveal, [0, 1], [26, 0])}px) scale(${interpolate(reveal, [0, 1], [0.96, 1])})`,
    }}>
      {kicker ? <div style={{
        color: theme.faint, fontFamily: theme.fontMono, fontSize: 14, letterSpacing: 5,
        marginBottom: 24, textTransform: "uppercase",
      }}>{kicker}</div> : null}
      <div style={{ fontSize: 62, fontWeight: 650, letterSpacing: -2.6 }}>{title}</div>
      <div style={{ color: theme.dim, fontSize: 25, marginTop: 18 }}>{subtitle}</div>
    </div>
  </AbsoluteFill>;
};

export const GithubMark: React.FC<{ size?: number }> = ({ size = 120 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-label="GitHub">
    <path fill={theme.text} fillRule="evenodd" clipRule="evenodd" d="M12 2C6.477 2 2 6.59 2 12.253c0 4.53 2.865 8.373 6.839 9.73.5.095.682-.222.682-.493 0-.244-.009-.889-.014-1.744-2.782.619-3.369-1.375-3.369-1.375-.455-1.185-1.11-1.5-1.11-1.5-.908-.636.069-.623.069-.623 1.003.073 1.531 1.057 1.531 1.057.892 1.566 2.341 1.114 2.91.852.091-.663.349-1.114.635-1.37-2.221-.26-4.555-1.14-4.555-5.069 0-1.12.39-2.034 1.03-2.752-.103-.26-.446-1.304.098-2.716 0 0 .84-.276 2.75 1.051A9.36 9.36 0 0112 6.976a9.36 9.36 0 012.504.345c1.909-1.327 2.748-1.05 2.748-1.05.545 1.411.202 2.455.1 2.715.64.718 1.028 1.632 1.028 2.752 0 3.939-2.338 4.806-4.566 5.061.359.317.679.944.679 1.903 0 1.373-.013 2.481-.013 2.818 0 .274.18.593.688.492C19.138 20.626 22 16.784 22 12.253 22 6.59 17.523 2 12 2z" />
  </svg>
);
