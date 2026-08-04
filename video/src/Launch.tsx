import React from "react";
import { AbsoluteFill, Series, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { AppMock } from "./components/AppMock";
import { MacWindow } from "./components/MacWindow";
import { Sfx } from "./components/Sfx";
import { Backdrop, Caption, GithubMark, SoundBed, SpringTitle, TerminalStage } from "./Shared";
import { SFX, theme, VOLUME } from "./theme";

const SCENES = [120, 120, 180, 165, 120, 150, 120, 165] as const;

const PainScene: React.FC = () => {
  const frame = useCurrentFrame();
  const line1 = "Two Codex accounts.";
  const line2 = "One ~/.codex. Chaos.";
  const first = line1.slice(0, Math.max(0, Math.min(line1.length, frame)));
  const secondStart = line1.length + 8;
  const second = line2.slice(0, Math.max(0, Math.min(line2.length, frame - secondStart)));
  const flash = frame % 20 < 12 ? 1 : 0.35;
  return <AbsoluteFill style={{ background: theme.bg, color: theme.text, fontFamily: theme.fontUI }}>
    <Backdrop seed={4} />
    <div style={{ position: "absolute", top: 58, left: 70, fontSize: 43, fontWeight: 650, letterSpacing: -1.4 }}>
      <div>{first}</div>
      <div style={{ color: theme.dim, marginTop: 5 }}>{second}</div>
    </div>
    <MacWindow title="work — zsh" width={570} height={265} entrance3d style={{ position: "absolute", left: 70, top: 265, transform: "rotate(-3deg)" }}>
      <MiniTerminal flash={flash} label="work" />
    </MacWindow>
    <MacWindow title="research — zsh" width={570} height={265} entrance3d entranceDelay={9} style={{ position: "absolute", right: 65, top: 340, transform: "rotate(3deg)" }}>
      <MiniTerminal flash={flash} label="research" />
    </MacWindow>
  </AbsoluteFill>;
};

const MiniTerminal: React.FC<{ flash: number; label: string }> = ({ flash, label }) => (
  <div style={{ padding: 24, color: theme.text, fontFamily: theme.fontMono, fontSize: 17, lineHeight: 1.65 }}>
    <div><span style={{ color: theme.dim }}>❯ </span>CODEX_HOME=~/.codex codex</div>
    <div style={{ color: theme.faint }}>profile: {label}</div>
    <div style={{ opacity: flash, marginTop: 10 }}>Primary window used: 97%</div>
  </div>
);

const AppScene: React.FC = () => (
  <AbsoluteFill style={{ background: theme.bg }}>
    <Backdrop seed={17} quiet />
    <div style={{ position: "absolute", inset: "55px 70px 92px" }}>
      <MacWindow title="Open Profile Manager" width="100%" height="100%" entrance3d><AppMock /></MacWindow>
    </div>
    <Caption>Also a native macOS app. English &amp; Português.</Caption>
  </AbsoluteFill>
);

const TrustScene: React.FC = () => {
  const frame = useCurrentFrame();
  const lines = ["Local-first", "Notarized", "No telemetry", "Open source (MIT)"];
  return <AbsoluteFill style={{
    background: theme.bg, color: theme.text, alignItems: "center", justifyContent: "center", fontFamily: theme.fontUI,
  }}>
    <Backdrop seed={23} />
    <div style={{ display: "flex", alignItems: "center", gap: 22, fontSize: 31, fontWeight: 550 }}>
      {lines.map((line, index) => {
        const reveal = interpolate(frame, [index * 13, index * 13 + 12], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
        return <React.Fragment key={line}>
          {index ? <span style={{ color: theme.faint, opacity: reveal }}>·</span> : null}
          <span style={{ opacity: reveal, transform: `translateY(${(1 - reveal) * 10}px)` }}>{line}</span>
        </React.Fragment>;
      })}
    </div>
  </AbsoluteFill>;
};

const CtaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const reveal = spring({ frame, fps, config: { damping: 120 }, durationInFrames: 42 });
  const pulse = 1 + Math.sin(frame / 12) * 0.018;
  return <AbsoluteFill style={{
    background: theme.bg, color: theme.text, alignItems: "center", justifyContent: "center",
    fontFamily: theme.fontUI, textAlign: "center",
  }}>
    <Backdrop seed={29} />
    <div style={{ position: "relative", opacity: reveal, transform: `scale(${reveal * pulse})` }}>
      <div style={{ transform: `rotate(${interpolate(reveal, [0, 1], [-180, 0])}deg)`, display: "inline-flex" }}><GithubMark size={112} /></div>
      <div style={{ fontSize: 43, fontWeight: 650, letterSpacing: -1.5, marginTop: 22 }}>Star it on GitHub</div>
      <div style={{
        marginTop: 24, border: `1px solid ${theme.panelBorder}`, borderRadius: 12, padding: "14px 22px",
        color: theme.dim, background: "rgba(255,255,255,0.035)", fontFamily: theme.fontMono, fontSize: 18,
      }}>github.com/mneves75/open-profile-manager</div>
    </div>
  </AbsoluteFill>;
};

const TransitionSounds: React.FC = () => {
  const starts = SCENES.slice(0, -1).map((_, index) => SCENES.slice(0, index + 1).reduce((sum, duration) => sum + duration, 0));
  return <>{starts.map((at) => <React.Fragment key={at}>
    <Sfx src={SFX.whoosh} at={at} volume={VOLUME.whoosh} durationInFrames={16} />
    <Sfx src={SFX.click} at={at + 3} volume={VOLUME.click} durationInFrames={8} />
  </React.Fragment>)}</>;
};

export const Launch: React.FC = () => (
  <AbsoluteFill style={{ background: theme.bg }}>
    <SoundBed />
    <TransitionSounds />
    <Series>
      <Series.Sequence durationInFrames={SCENES[0]}><PainScene /></Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[1]}><SpringTitle title="Open Profile Manager" subtitle="Every Codex account. Cleanly separated." kicker="Introducing" /></Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[2]}>
        <TerminalStage title="profiles — opm" fontSize={18} seed={7} lines={[
          { cmd: 'opm profile add work --name "Work" --home ~/.codex-work' },
          { out: "Added work (Work)." },
          { cmd: 'opm profile add research --name "Research" --home ~/.codex-research', cpf: 2 },
          { out: "Added research (Research)." },
          { cmd: 'opm profile add client-acme --name "Client — ACME" --home ~/.codex-acme', cpf: 3 },
          { out: "Added client-acme (Client — ACME)." },
        ]} caption="Named profiles. Separate local state. Explicit selection." />
      </Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[3]}>
        <TerminalStage title="status — opm" fontSize={19} seed={9} lines={[
          { cmd: "opm status --all" },
          { out: "work: available (chatgpt)" },
          { out: "  Primary window used: 12%", bar: 12 },
          { out: "research: available (chatgpt)" },
          { out: "  Primary window used: 64%", bar: 64 },
          { out: "client-acme: available (chatgpt)" },
          { out: "  Primary window used: 3%", bar: 3 },
        ]} caption="Quota is status information only. You stay in control." />
      </Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[4]}>
        <TerminalStage title="work — codex" fontSize={21} seed={13} lines={[
          { cmd: "opm run work" }, { pause: 12 }, { out: "codex ›", dim: true },
        ]} caption="The real Codex process. Your terminal, untouched." />
      </Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[5]}><AppScene /></Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[6]}><TrustScene /></Series.Sequence>
      <Series.Sequence durationInFrames={SCENES[7]}><CtaScene /></Series.Sequence>
    </Series>
  </AbsoluteFill>
);
