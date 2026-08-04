import React from "react";
import {
  AbsoluteFill,
  Audio,
  Easing,
  interpolate,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { theme } from "./theme";

const profiles = [
  { id: "work", name: "Work", home: "~/.codex-work", used: 12 },
  { id: "research", name: "Research", home: "~/.codex-research", used: 64 },
  { id: "client-acme", name: "Client — ACME", home: "~/.codex-acme", used: 3 },
] as const;

const clicks = [420, 650, 750, 810, 1015, 1275, 1540];

const chapters = [
  {
    from: 0,
    to: 150,
    kicker: "GUI TUTORIAL",
    title: "Open Profile Manager",
    body: "Manage every Codex profile from one native macOS app.",
  },
  {
    from: 150,
    to: 390,
    kicker: "01 · ORIENTATION",
    title: "Everything in one place",
    body: "Profiles on the left. Status and explicit launch actions on the right.",
  },
  {
    from: 390,
    to: 720,
    kicker: "02 · ADD A PROFILE",
    title: "Create an isolated home",
    body: "Name the profile and choose its own CODEX_HOME. Tokens stay with the official Codex login.",
  },
  {
    from: 720,
    to: 990,
    kicker: "03 · CHECK STATUS",
    title: "See quota at a glance",
    body: "Select a profile, then refresh. Quota is information only — switching is always your choice.",
  },
  {
    from: 990,
    to: 1260,
    kicker: "04 · COPY CLI COMMAND",
    title: "Continue in your terminal",
    body: "Copy the profile command, then paste it into Terminal to launch the real codex process.",
  },
  {
    from: 1260,
    to: 1530,
    kicker: "05 · LAUNCH APP",
    title: "Open the official macOS app",
    body: "The independently installed app opens with the selected profile. OPM never bundles OpenAI software.",
  },
  {
    from: 1530,
    to: 1800,
    kicker: "06 · INSTALL LAUNCHER",
    title: "One-click access",
    body: "Install a profile launcher in ~/Applications for fast, explicit switching.",
  },
  {
    from: 1800,
    to: 2160,
    kicker: "READY",
    title: "Three profiles. Cleanly separated.",
    body: "Local-first · Notarized · No telemetry · Open source (MIT)",
  },
] as const;

const fade = (frame: number, start: number, end: number) =>
  interpolate(frame, [start, start + 18, end - 18, end], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

export const GuiTutorial: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const chapter =
    chapters.find(({ from, to }) => frame >= from && frame < to) ??
    chapters[chapters.length - 1];
  const titleOnly = frame < 150 || frame >= 1800;
  const windowIn = spring({
    frame: frame - 145,
    fps,
    config: { damping: 18, stiffness: 115 },
    durationInFrames: 42,
  });
  const chapterOpacity = fade(frame, chapter.from, chapter.to);

  return (
    <AbsoluteFill
      style={{
        background: theme.bg,
        color: theme.text,
        fontFamily: theme.fontUI,
        overflow: "hidden",
      }}
    >
      <Grid />
      <Audio src={staticFile("sfx/roomtone.wav")} loop volume={0.028} />
      {clicks.map((at) => (
        <Sequence key={at} from={at} durationInFrames={12}>
          <Audio src={staticFile("sfx/click.wav")} volume={0.72} />
        </Sequence>
      ))}

      {titleOnly ? (
        <Hero chapter={chapter} opacity={chapterOpacity} frame={frame} />
      ) : (
        <>
          <div
            style={{
              position: "absolute",
              left: 150,
              top: 70,
              opacity: chapterOpacity,
              transform: `translateY(${interpolate(chapterOpacity, [0, 1], [12, 0])}px)`,
            }}
          >
            <div
              style={{
                color: theme.faint,
                fontSize: 18,
                letterSpacing: 3,
                fontWeight: 650,
              }}
            >
              {chapter.kicker}
            </div>
            <div
              style={{
                fontSize: 44,
                letterSpacing: -1.5,
                fontWeight: 650,
                marginTop: 10,
              }}
            >
              {chapter.title}
            </div>
          </div>
          <div
            style={{
              position: "absolute",
              left: 150,
              right: 150,
              top: 182,
              height: 730,
              opacity: windowIn,
              transform: `perspective(1800px) translateY(${interpolate(windowIn, [0, 1], [90, 0])}px) rotateX(${interpolate(windowIn, [0, 1], [8, 0])}deg)`,
              transformOrigin: "50% 100%",
            }}
          >
            <AppWindow frame={frame} />
          </div>
          <div
            style={{
              position: "absolute",
              left: 150,
              right: 150,
              bottom: 56,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              opacity: chapterOpacity,
            }}
          >
            <div style={{ color: theme.dim, fontSize: 21 }}>{chapter.body}</div>
            <Progress frame={frame} />
          </div>
        </>
      )}
    </AbsoluteFill>
  );
};

const Hero: React.FC<{
  chapter: (typeof chapters)[number];
  opacity: number;
  frame: number;
}> = ({ chapter, opacity, frame }) => {
  const reveal = spring({
    frame: frame < 150 ? frame - 16 : frame - 1815,
    fps: 30,
    config: { damping: 18 },
    durationInFrames: 34,
  });
  return (
    <AbsoluteFill
      style={{
        alignItems: "center",
        justifyContent: "center",
        textAlign: "center",
        opacity,
      }}
    >
      <div
        style={{
          color: theme.faint,
          fontSize: 19,
          letterSpacing: 4,
          fontWeight: 650,
        }}
      >
        {chapter.kicker}
      </div>
      <div
        style={{
          marginTop: 24,
          maxWidth: 1400,
          fontSize: frame < 150 ? 82 : 74,
          lineHeight: 1.04,
          letterSpacing: -3.5,
          fontWeight: 680,
          transform: `translateY(${interpolate(reveal, [0, 1], [24, 0])}px) scale(${interpolate(reveal, [0, 1], [0.97, 1])})`,
        }}
      >
        {chapter.title}
      </div>
      <div style={{ marginTop: 30, color: theme.dim, fontSize: 26 }}>
        {chapter.body}
      </div>
      {frame >= 1800 ? (
        <div
          style={{
            marginTop: 58,
            padding: "16px 24px",
            border: `1px solid ${theme.panelBorder}`,
            borderRadius: 14,
            color: theme.text,
            fontFamily: theme.fontMono,
            fontSize: 22,
          }}
        >
          github.com/mneves75/open-profile-manager
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

const AppWindow: React.FC<{ frame: number }> = ({ frame }) => {
  const selected = frame >= 750 && frame < 990 ? profiles[1] : profiles[0];
  const showModal = frame >= 420 && frame < 670;
  const showTerminal = frame >= 1015 && frame < 1240;
  const showAppLaunch = frame >= 1275 && frame < 1510;
  const toast =
    frame >= 650 && frame < 715
      ? "Profile saved"
      : frame >= 850 && frame < 940
        ? "Status refreshed"
        : frame >= 1540 && frame < 1710
          ? "Launcher installed in ~/Applications"
          : null;

  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        background: "#101012",
        border: `1px solid ${theme.panelBorder}`,
        borderRadius: 20,
        boxShadow: "0 36px 100px rgba(0,0,0,.55)",
        overflow: "hidden",
      }}
    >
      <Chrome />
      <div style={{ display: "flex", height: "calc(100% - 54px)" }}>
        <Sidebar selected={selected.id} frame={frame} />
        <Detail profile={selected} frame={frame} />
      </div>
      {showModal ? <AddProfileModal frame={frame} /> : null}
      {showTerminal ? <TerminalPop frame={frame} /> : null}
      {showAppLaunch ? <AppLaunchPop frame={frame} /> : null}
      {toast ? <Toast text={toast} frame={frame} /> : null}
      <Cursor frame={frame} />
    </div>
  );
};

const Chrome = () => (
  <div
    style={{
      height: 53,
      borderBottom: `1px solid ${theme.panelBorder}`,
      display: "flex",
      alignItems: "center",
      padding: "0 20px",
      position: "relative",
    }}
  >
    <div style={{ display: "flex", gap: 9 }}>
      {["#ff5f57", "#febc2e", "#28c840"].map((color) => (
        <div
          key={color}
          style={{ width: 13, height: 13, borderRadius: 99, background: color }}
        />
      ))}
    </div>
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        color: theme.faint,
        fontSize: 14,
      }}
    >
      Open Profile Manager
    </div>
  </div>
);

const Sidebar: React.FC<{ selected: string; frame: number }> = ({
  selected,
  frame,
}) => (
  <div
    style={{
      width: 320,
      borderRight: `1px solid ${theme.panelBorder}`,
      padding: "24px 18px 18px",
      display: "flex",
      flexDirection: "column",
      gap: 8,
    }}
  >
    <div
      style={{
        color: theme.faint,
        fontSize: 13,
        letterSpacing: 1.6,
        padding: "0 12px 8px",
      }}
    >
      PROFILES
    </div>
    {profiles.slice(0, frame < 650 ? 2 : 3).map((profile) => (
      <div
        key={profile.id}
        style={{
          padding: "13px 14px",
          borderRadius: 10,
          background:
            selected === profile.id ? "rgba(255,255,255,.12)" : "transparent",
          color: theme.text,
          fontSize: 19,
        }}
      >
        {profile.name}
        <div
          style={{
            color: theme.faint,
            fontFamily: theme.fontMono,
            fontSize: 13,
            marginTop: 3,
          }}
        >
          {profile.id}
        </div>
      </div>
    ))}
    <div style={{ flex: 1 }} />
    <div style={{ display: "flex", gap: 10 }}>
      <Button label="＋ Add Profile" active={frame >= 390 && frame < 720} />
      <Button label="⟳ Refresh" active={frame >= 720 && frame < 990} />
    </div>
  </div>
);

const Detail: React.FC<{
  profile: (typeof profiles)[number];
  frame: number;
}> = ({ profile, frame }) => {
  const refreshing = frame >= 810 && frame < 850;
  return (
    <div style={{ flex: 1, padding: "40px 46px" }}>
      <div style={{ fontSize: 38, fontWeight: 650 }}>{profile.name}</div>
      <div
        style={{
          color: theme.faint,
          fontFamily: theme.fontMono,
          fontSize: 16,
          marginTop: 8,
        }}
      >
        CODEX_HOME&nbsp;&nbsp;{profile.home}
      </div>
      <div
        style={{
          marginTop: 34,
          border: `1px solid ${theme.panelBorder}`,
          borderRadius: 14,
          padding: "24px 26px",
          display: "flex",
          flexDirection: "column",
          gap: 22,
        }}
      >
        <StatusRow
          label="Status"
          value={refreshing ? "refreshing…" : "available (chatgpt)"}
        />
        <StatusRow
          label="Primary window"
          value={`${profile.used}% used`}
          bar={profile.used}
          frame={frame}
        />
        <StatusRow
          label="Secondary window"
          value="5% used"
          bar={5}
          frame={frame}
        />
      </div>
      <div style={{ display: "flex", gap: 14, marginTop: 28 }}>
        <Button
          label="Copy CLI Command"
          active={frame >= 990 && frame < 1260}
          large
        />
        <Button
          label="Launch App"
          active={frame >= 1260 && frame < 1530}
          large
        />
        <Button
          label="Install Launcher"
          active={frame >= 1530 && frame < 1800}
          large
        />
      </div>
      <div style={{ color: theme.faint, fontSize: 15, marginTop: 28 }}>
        Profile switching is always explicit. OPM never reads or stores
        authentication tokens.
      </div>
    </div>
  );
};

const Button: React.FC<{
  label: string;
  active?: boolean;
  large?: boolean;
}> = ({ label, active, large }) => (
  <div
    style={{
      border: `1px solid ${active ? "rgba(255,255,255,.7)" : theme.panelBorder}`,
      background: active ? theme.text : "rgba(255,255,255,.025)",
      color: active ? theme.bg : theme.dim,
      borderRadius: 9,
      padding: large ? "11px 20px" : "8px 12px",
      fontSize: large ? 17 : 14,
      fontWeight: 560,
      whiteSpace: "nowrap",
    }}
  >
    {label}
  </div>
);

const StatusRow: React.FC<{
  label: string;
  value: string;
  bar?: number;
  frame?: number;
}> = ({ label, value, bar, frame = 0 }) => {
  const animationStart =
    frame < 720 ? 150 : frame < 810 ? 720 : frame < 990 ? 810 : 990;
  const width =
    bar === undefined
      ? 0
      : interpolate(frame - animationStart, [0, 34], [0, bar], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
  return (
    <div style={{ display: "flex", alignItems: "center", fontSize: 18 }}>
      <div style={{ width: 210, color: theme.faint }}>{label}</div>
      <div>{value}</div>
      {bar !== undefined ? (
        <div
          style={{
            marginLeft: "auto",
            width: 300,
            height: 9,
            borderRadius: 99,
            background: "rgba(255,255,255,.1)",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              width: `${width}%`,
              height: "100%",
              background: theme.text,
            }}
          />
        </div>
      ) : null}
    </div>
  );
};

const AddProfileModal: React.FC<{ frame: number }> = ({ frame }) => {
  const enter = spring({
    frame: frame - 420,
    fps: 30,
    config: { damping: 18 },
    durationInFrames: 26,
  });
  const typed = (value: string, start: number) =>
    value.slice(0, Math.max(0, Math.floor((frame - start) / 2)));
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: "rgba(0,0,0,.55)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          width: 650,
          borderRadius: 18,
          border: `1px solid ${theme.panelBorder}`,
          background: "#18181b",
          padding: 30,
          boxShadow: "0 30px 90px rgba(0,0,0,.7)",
          opacity: enter,
          transform: `scale(${interpolate(enter, [0, 1], [0.94, 1])})`,
        }}
      >
        <div style={{ fontSize: 28, fontWeight: 650 }}>Add Profile</div>
        <Field label="Profile ID" value={typed("client-acme", 450)} />
        <Field label="Display Name" value={typed("Client — ACME", 500)} />
        <Field label="CODEX_HOME" value={typed("~/.codex-acme", 555)} mono />
        <div
          style={{
            display: "flex",
            justifyContent: "flex-end",
            gap: 12,
            marginTop: 26,
          }}
        >
          <Button label="Cancel" />
          <Button label="Save Profile" active={frame >= 630} />
        </div>
      </div>
    </div>
  );
};

const Field: React.FC<{ label: string; value: string; mono?: boolean }> = ({
  label,
  value,
  mono,
}) => (
  <div style={{ marginTop: 22 }}>
    <div style={{ color: theme.faint, fontSize: 14, marginBottom: 8 }}>
      {label}
    </div>
    <div
      style={{
        height: 48,
        borderRadius: 9,
        border: `1px solid ${theme.panelBorder}`,
        background: "#111113",
        padding: "12px 14px",
        fontSize: 18,
        fontFamily: mono ? theme.fontMono : theme.fontUI,
      }}
    >
      {value}
      <span style={{ opacity: 0.65 }}>▌</span>
    </div>
  </div>
);

const TerminalPop: React.FC<{ frame: number }> = ({ frame }) => {
  const enter = spring({
    frame: frame - 1015,
    fps: 30,
    config: { damping: 16 },
    durationInFrames: 28,
  });
  return (
    <div
      style={{
        position: "absolute",
        right: 34,
        bottom: 32,
        width: 760,
        height: 330,
        borderRadius: 15,
        border: `1px solid ${theme.panelBorder}`,
        background: "#09090a",
        boxShadow: "0 30px 80px rgba(0,0,0,.7)",
        opacity: enter,
        transform: `translateY(${interpolate(enter, [0, 1], [55, 0])}px)`,
        overflow: "hidden",
      }}
    >
      <div
        style={{
          height: 40,
          borderBottom: `1px solid ${theme.panelBorder}`,
          display: "flex",
          alignItems: "center",
          padding: "0 15px",
          color: theme.faint,
          fontSize: 13,
        }}
      >
        Terminal — paste copied command
      </div>
      <div
        style={{
          padding: 24,
          fontFamily: theme.fontMono,
          fontSize: 18,
          lineHeight: 1.7,
        }}
      >
        <div>
          <span style={{ color: theme.faint }}>❯</span> opm run work
        </div>
        <div style={{ marginTop: 20, color: theme.dim }}>
          Launching codex with CODEX_HOME=~/.codex-work
        </div>
        <div style={{ marginTop: 12 }}>
          codex › <span style={{ opacity: 0.7 }}>▌</span>
        </div>
      </div>
    </div>
  );
};

const AppLaunchPop: React.FC<{ frame: number }> = ({ frame }) => {
  const enter = spring({
    frame: frame - 1275,
    fps: 30,
    config: { damping: 16 },
    durationInFrames: 30,
  });
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: "rgba(0,0,0,.55)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <div
        style={{
          width: 620,
          textAlign: "center",
          borderRadius: 18,
          border: `1px solid ${theme.panelBorder}`,
          background: "#18181b",
          padding: "52px 46px",
          opacity: enter,
          transform: `scale(${interpolate(enter, [0, 1], [0.92, 1])})`,
        }}
      >
        <div
          style={{
            width: 76,
            height: 76,
            margin: "0 auto",
            borderRadius: 18,
            background: "linear-gradient(145deg,#fafafa,#888)",
            color: "#111",
            display: "grid",
            placeItems: "center",
            fontWeight: 750,
            fontSize: 29,
          }}
        >
          A
        </div>
        <div style={{ fontSize: 28, fontWeight: 650, marginTop: 24 }}>
          Opening the official app
        </div>
        <div
          style={{
            color: theme.dim,
            fontSize: 18,
            lineHeight: 1.5,
            marginTop: 12,
          }}
        >
          Profile: Work
          <br />
          <span style={{ fontFamily: theme.fontMono }}>
            CODEX_HOME=~/.codex-work
          </span>
        </div>
        <div style={{ color: theme.faint, fontSize: 14, marginTop: 24 }}>
          OPM is unofficial and not affiliated with OpenAI.
        </div>
      </div>
    </div>
  );
};

const Toast: React.FC<{ text: string; frame: number }> = ({ text, frame }) => {
  const start = text.startsWith("Profile")
    ? 650
    : text.startsWith("Status")
      ? 850
      : 1540;
  const duration = text.startsWith("Profile")
    ? 65
    : text.startsWith("Status")
      ? 90
      : 170;
  const local = frame - start;
  const opacity = interpolate(
    local,
    [0, 12, duration - 25, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        bottom: 26,
        transform: `translateX(-50%) translateY(${interpolate(opacity, [0, 1], [12, 0])}px)`,
        border: `1px solid ${theme.panelBorder}`,
        borderRadius: 99,
        background: "rgba(20,20,22,.96)",
        padding: "11px 20px",
        fontSize: 15,
        opacity,
      }}
    >
      {text}
    </div>
  );
};

const Cursor: React.FC<{ frame: number }> = ({ frame }) => {
  const points = [
    { at: 150, x: 780, y: 360 },
    { at: 390, x: 80, y: 690 },
    { at: 420, x: 80, y: 690 },
    { at: 630, x: 1080, y: 535 },
    { at: 650, x: 1080, y: 535 },
    { at: 720, x: 110, y: 210 },
    { at: 750, x: 110, y: 210 },
    { at: 790, x: 190, y: 690 },
    { at: 810, x: 190, y: 690 },
    { at: 990, x: 435, y: 410 },
    { at: 1015, x: 435, y: 410 },
    { at: 1260, x: 585, y: 410 },
    { at: 1275, x: 585, y: 410 },
    { at: 1530, x: 775, y: 410 },
    { at: 1540, x: 775, y: 410 },
    { at: 1770, x: 775, y: 410 },
  ];
  const nextIndex = points.findIndex((point) => frame < point.at);
  const index =
    nextIndex === -1 ? points.length - 1 : Math.max(0, nextIndex - 1);
  const a = points[index];
  const b = points[Math.min(index + 1, points.length - 1)];
  const t =
    a === b
      ? 0
      : interpolate(frame, [a.at, b.at], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.inOut(Easing.cubic),
        });
  const x = interpolate(t, [0, 1], [a.x, b.x]);
  const y = interpolate(t, [0, 1], [a.y, b.y]);
  const activeClick = clicks.find((at) => frame >= at && frame < at + 10);
  const pulse =
    activeClick === undefined
      ? 1
      : interpolate(frame - activeClick, [0, 9], [1, 1.8]);
  return (
    <div
      style={{
        position: "absolute",
        left: x,
        top: y,
        width: 24,
        height: 31,
        filter: "drop-shadow(0 2px 3px rgba(0,0,0,.65))",
        transform: `scale(${pulse})`,
        transformOrigin: "2px 2px",
      }}
    >
      <svg width="24" height="31" viewBox="0 0 24 31">
        <path
          d="M2 2L2 25L8.3 19L13.2 29L17 27L12.2 17H21L2 2Z"
          fill="white"
          stroke="#111"
          strokeWidth="1.5"
        />
      </svg>
    </div>
  );
};

const Progress: React.FC<{ frame: number }> = ({ frame }) => {
  const active = Math.max(
    0,
    chapters
      .slice(1, -1)
      .findIndex(({ from, to }) => frame >= from && frame < to),
  );
  return (
    <div style={{ display: "flex", gap: 9 }}>
      {Array.from({ length: 6 }, (_, index) => (
        <div
          key={index}
          style={{
            width: index === active ? 28 : 8,
            height: 8,
            borderRadius: 99,
            background: index === active ? theme.text : "rgba(255,255,255,.2)",
          }}
        />
      ))}
    </div>
  );
};

const Grid = () => (
  <AbsoluteFill
    style={{
      opacity: 0.09,
      backgroundImage:
        "linear-gradient(rgba(255,255,255,.12) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.12) 1px, transparent 1px)",
      backgroundSize: "72px 72px",
      maskImage: "radial-gradient(circle at center, black 0%, transparent 76%)",
    }}
  />
);
