import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";

const TRAFFIC = ["#ff5f57", "#febc2e", "#28c840"];

// Dark macOS window chrome. entrance3d slides it up with a perspective tilt
// (rotateX settling from 20deg with a slight rotateY oscillation).
export const MacWindow: React.FC<{
  title?: string;
  width?: number | string;
  height?: number | string;
  entrance3d?: boolean;
  entranceDelay?: number;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}> = ({ title, width, height, entrance3d = false, entranceDelay = 0, style, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  let transform = "none";
  let opacity = 1;
  if (entrance3d) {
    const t = spring({ frame: frame - entranceDelay, fps, config: { damping: 200 }, durationInFrames: 35 });
    const y = interpolate(t, [0, 1], [420, 0]);
    const rx = interpolate(t, [0, 1], [22, 0]);
    const ry = Math.sin((frame - entranceDelay) / 9) * 2.2 * (1 - t);
    transform = `perspective(1200px) translateY(${y}px) rotateX(${rx}deg) rotateY(${ry}deg)`;
    opacity = interpolate(t, [0, 0.35], [0, 1], { extrapolateRight: "clamp" });
  }

  return (
    <div
      style={{
        width,
        height,
        background: theme.panel,
        border: `1px solid ${theme.panelBorder}`,
        borderRadius: 14,
        boxShadow: "0 30px 80px rgba(0,0,0,0.55)",
        overflow: "hidden",
        transform,
        opacity,
        display: "flex",
        flexDirection: "column",
        ...style,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "12px 16px",
          borderBottom: `1px solid ${theme.panelBorder}`,
          flexShrink: 0,
        }}
      >
        {TRAFFIC.map((c) => (
          <div key={c} style={{ width: 12, height: 12, borderRadius: 6, background: c }} />
        ))}
        {title ? (
          <div
            style={{
              flex: 1,
              textAlign: "center",
              marginRight: 60,
              color: theme.faint,
              fontFamily: theme.fontUI,
              fontSize: 13,
            }}
          >
            {title}
          </div>
        ) : null}
      </div>
      <div style={{ flex: 1, minHeight: 0 }}>{children}</div>
    </div>
  );
};
