import React from "react";
import { AbsoluteFill, Series, interpolate, useCurrentFrame } from "remotion";
import { TypeCard } from "./components/TypeCard";
import { Backdrop, GithubMark, SoundBed, TerminalStage } from "./Shared";
import { theme } from "./theme";

const Note: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [75, 92], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        bottom: 122,
        transform: "translateX(-50%)",
        border: `1px solid ${theme.panelBorder}`,
        borderRadius: 12,
        background: "rgba(10,10,10,0.92)",
        color: theme.dim,
        fontFamily: theme.fontUI,
        fontSize: 19,
        padding: "13px 20px",
        opacity,
      }}
    >
      {children}
    </div>
  );
};

const LoginScene: React.FC = () => (
  <AbsoluteFill>
    <TerminalStage
      title="login — opm"
      fontSize={27}
      chapter={3}
      seed={43}
      lines={[{ cmd: "opm login work" }, { pause: 35 }]}
    />
    <Note>Runs the official Codex login. OPM never touches your tokens.</Note>
  </AbsoluteFill>
);

const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  const items = [
    "Explicit profiles",
    "Read-only quota status",
    "Native macOS app",
    "Finder launchers",
  ];
  return (
    <AbsoluteFill
      style={{
        background: theme.bg,
        color: theme.text,
        alignItems: "center",
        justifyContent: "center",
        fontFamily: theme.fontUI,
        textAlign: "center",
      }}
    >
      <Backdrop seed={71} />
      <div
        style={{
          position: "relative",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
        }}
      >
        <GithubMark size={84} />
        <div
          style={{
            fontSize: 48,
            fontWeight: 650,
            letterSpacing: -1.8,
            marginTop: 20,
          }}
        >
          Open Profile Manager
        </div>
        <div
          style={{
            display: "flex",
            gap: 24,
            color: theme.dim,
            fontSize: 20,
            marginTop: 22,
          }}
        >
          {items.map((item, index) => (
            <React.Fragment key={item}>
              {index ? <span style={{ color: theme.faint }}>·</span> : null}
              <span
                style={{
                  opacity: interpolate(
                    frame,
                    [index * 12, index * 12 + 10],
                    [0, 1],
                    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
                  ),
                }}
              >
                {item}
              </span>
            </React.Fragment>
          ))}
        </div>
        <div
          style={{
            marginTop: 34,
            border: `1px solid ${theme.panelBorder}`,
            borderRadius: 12,
            padding: "14px 22px",
            color: theme.text,
            fontFamily: theme.fontMono,
            fontSize: 19,
          }}
        >
          github.com/mneves75/open-profile-manager
        </div>
        <div
          style={{
            color: theme.faint,
            fontFamily: theme.fontMono,
            fontSize: 17,
            marginTop: 22,
          }}
        >
          MIT · macOS 15+
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const Tutorial: React.FC = () => (
  <AbsoluteFill style={{ background: theme.bg }}>
    <SoundBed />
    <Series>
      <Series.Sequence durationInFrames={150}>
        <TypeCard
          lines={["Open Profile Manager", "An 85-second tutorial."]}
          fontSize={70}
          kicker="opm"
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={134}>
        <TypeCard lines={["Install.", "Build from source."]} fontSize={68} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={210}>
        <TerminalStage
          title="install — zsh"
          fontSize={25}
          chapter={1}
          seed={31}
          lines={[
            {
              cmd: "git clone https://github.com/mneves75/open-profile-manager.git",
              cpf: 2,
            },
            { out: "Cloning into 'open-profile-manager'…", dim: true },
            { cmd: "cd open-profile-manager", cpf: 2 },
            { cmd: "Scripts/install-local.sh", cpf: 2 },
            { out: "Installed CLI: ~/.local/bin/opm" },
            { out: "Installed app: ~/Applications/Open Profile Manager.app" },
            { cmd: "opm version", cpf: 2 },
            { out: "0.1.1" },
          ]}
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={143}>
        <TypeCard
          lines={["Add profiles.", "Keep state separate."]}
          fontSize={68}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={240}>
        <TerminalStage
          title="profiles — opm"
          fontSize={24}
          chapter={2}
          seed={37}
          lines={[
            {
              cmd: 'opm profile add work --name "Work" --home ~/.codex-work',
              cpf: 2,
            },
            { out: "Added work (Work)." },
            {
              cmd: 'opm profile add research --name "Research" --home ~/.codex-research',
              cpf: 2,
            },
            { out: "Added research (Research)." },
            {
              cmd: 'opm profile add client-acme --name "Client — ACME" --home ~/.codex-acme',
              cpf: 3,
            },
            { out: "Added client-acme (Client — ACME)." },
            { cmd: "opm profile list", cpf: 2 },
            { out: "work          Work            /Users/demo/.codex-work" },
            {
              out: "research      Research        /Users/demo/.codex-research",
            },
            { out: "client-acme   Client — ACME   /Users/demo/.codex-acme" },
          ]}
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={137}>
        <TypeCard lines={["Log in.", "Official Codex flow."]} fontSize={68} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={180}>
        <LoginScene />
      </Series.Sequence>

      <Series.Sequence durationInFrames={145}>
        <TypeCard
          lines={["Check quota.", "Status, never rotation."]}
          fontSize={68}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={210}>
        <TerminalStage
          title="status — opm"
          fontSize={25}
          chapter={4}
          seed={47}
          lines={[
            { cmd: "opm status --all", cpf: 2 },
            { out: "work: available (chatgpt)" },
            { out: "  Primary window used: 12%", bar: 12 },
            { out: "research: available (chatgpt)" },
            { out: "  Primary window used: 64%", bar: 64 },
            { out: "client-acme: available (chatgpt)" },
            { out: "  Primary window used: 3%", bar: 3 },
          ]}
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={146}>
        <TypeCard
          lines={["Pick a profile.", "Launch it explicitly."]}
          fontSize={68}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={270}>
        <TerminalStage
          title="launch — opm"
          fontSize={25}
          chapter={5}
          seed={53}
          lines={[
            { cmd: "opm run work", cpf: 2 },
            { pause: 25 },
            { out: "codex ›", dim: true },
            { pause: 30 },
            { out: "— Codex session ended · new shell —", dim: true },
            { cmd: "opm app launch research", cpf: 2 },
            { pause: 25 },
            { cmd: "opm launcher install work", cpf: 2 },
            {
              out: "Installed /Users/demo/Applications/Open Profile Manager - work.app.",
            },
          ]}
          caption="CLI, official app, or a Finder launcher — you choose."
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={150}>
        <TypeCard
          lines={["Run the health check.", "Know what is ready."]}
          fontSize={68}
        />
      </Series.Sequence>
      <Series.Sequence durationInFrames={225}>
        <TerminalStage
          title="doctor — opm"
          fontSize={24}
          chapter={6}
          seed={61}
          lines={[
            { cmd: "opm doctor", cpf: 2 },
            {
              out: "[pass] Profile registry: Registry is readable with owner-only permissions.",
            },
            { out: "[pass] Codex CLI: Found codex at /usr/local/bin/codex." },
            {
              out: "[pass] Official macOS app: Found /Applications/Codex.app.",
            },
            { out: "[pass] CODEX_HOME (work): Directory is private." },
            { out: "[pass] GUI data directory (work): Directory is private." },
          ]}
        />
      </Series.Sequence>

      <Series.Sequence durationInFrames={210}>
        <EndCard />
      </Series.Sequence>
    </Series>
  </AbsoluteFill>
);
