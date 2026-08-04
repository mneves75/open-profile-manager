import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";

const PROFILES = [
  { id: "work", name: "Work", home: "~/.codex-work", used: 12 },
  { id: "research", name: "Research", home: "~/.codex-research", used: 64 },
  { id: "client-acme", name: "Client — ACME", home: "~/.codex-acme", used: 3 },
];

const Reveal: React.FC<{ delay: number; children: React.ReactNode }> = ({ delay, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames: 25 });
  return (
    <div style={{ opacity: t, transform: `translateY(${interpolate(t, [0, 1], [14, 0])}px)` }}>
      {children}
    </div>
  );
};

// Faithful grayscale mock of the real GUI: NavigationSplitView with a profile
// sidebar and a detail pane (ContentView.swift / ProfileDetailView.swift).
export const AppMock: React.FC = () => {
  const selected = PROFILES[0];
  return (
    <div style={{ display: "flex", height: "100%", fontFamily: theme.fontUI }}>
      <div
        style={{
          width: 230,
          borderRight: `1px solid ${theme.panelBorder}`,
          padding: "14px 10px",
          display: "flex",
          flexDirection: "column",
          gap: 4,
          flexShrink: 0,
        }}
      >
        <Reveal delay={0}>
          <div style={{ color: theme.faint, fontSize: 12, padding: "0 10px 8px", letterSpacing: 1 }}>
            PROFILES
          </div>
        </Reveal>
        {PROFILES.map((p, i) => (
          <Reveal key={p.id} delay={6 + i * 6}>
            <div
              style={{
                padding: "9px 10px",
                borderRadius: 8,
                background: p.id === selected.id ? "rgba(255,255,255,0.12)" : "transparent",
                color: theme.text,
                fontSize: 16,
              }}
            >
              {p.name}
              <div style={{ color: theme.faint, fontSize: 12, fontFamily: theme.fontMono }}>
                {p.id}
              </div>
            </div>
          </Reveal>
        ))}
        <div style={{ flex: 1 }} />
        <Reveal delay={30}>
          <div style={{ display: "flex", gap: 8, padding: "0 6px" }}>
            {["＋ Add Profile", "⟳ Refresh"].map((label) => (
              <div
                key={label}
                style={{
                  border: `1px solid ${theme.panelBorder}`,
                  borderRadius: 7,
                  padding: "5px 10px",
                  color: theme.dim,
                  fontSize: 12,
                }}
              >
                {label}
              </div>
            ))}
          </div>
        </Reveal>
      </div>

      <div style={{ flex: 1, padding: "26px 30px" }}>
        <Reveal delay={14}>
          <div style={{ color: theme.text, fontSize: 30, fontWeight: 600 }}>{selected.name}</div>
        </Reveal>
        <Reveal delay={20}>
          <div style={{ color: theme.faint, fontSize: 14, marginTop: 6, fontFamily: theme.fontMono }}>
            CODEX_HOME&nbsp;&nbsp;{selected.home}
          </div>
        </Reveal>
        <Reveal delay={26}>
          <div
            style={{
              marginTop: 24,
              border: `1px solid ${theme.panelBorder}`,
              borderRadius: 10,
              padding: "16px 18px",
              display: "flex",
              flexDirection: "column",
              gap: 12,
            }}
          >
            <Row label="Status" value="available (chatgpt)" />
            <Row label="Primary window" value={`${selected.used}% used`} bar={selected.used} />
            <Row label="Secondary window" value="5% used" bar={5} />
          </div>
        </Reveal>
        <Reveal delay={34}>
          <div style={{ display: "flex", gap: 10, marginTop: 22 }}>
            {["Launch CLI", "Launch App", "Install Launcher"].map((label, i) => (
              <div
                key={label}
                style={{
                  borderRadius: 8,
                  padding: "8px 16px",
                  fontSize: 14,
                  background: i === 0 ? theme.text : "transparent",
                  color: i === 0 ? theme.bg : theme.dim,
                  border: i === 0 ? "none" : `1px solid ${theme.panelBorder}`,
                  fontWeight: 500,
                }}
              >
                {label}
              </div>
            ))}
          </div>
        </Reveal>
      </div>
    </div>
  );
};

const Row: React.FC<{ label: string; value: string; bar?: number }> = ({ label, value, bar }) => {
  const frame = useCurrentFrame();
  const w = bar === undefined ? 0 : interpolate(frame, [30, 55], [0, bar], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div style={{ display: "flex", alignItems: "center", fontSize: 15 }}>
      <div style={{ width: 170, color: theme.faint }}>{label}</div>
      <div style={{ color: theme.text }}>{value}</div>
      {bar !== undefined ? (
        <div
          style={{
            marginLeft: "auto",
            width: 200,
            height: 8,
            borderRadius: 4,
            background: "rgba(255,255,255,0.10)",
            overflow: "hidden",
          }}
        >
          <div style={{ width: `${w}%`, height: "100%", background: theme.text, opacity: 0.85 }} />
        </div>
      ) : null}
    </div>
  );
};
