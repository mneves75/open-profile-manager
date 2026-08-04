import React from "react";
import { Audio, Sequence, staticFile } from "remotion";

// One-shot sound at a frame. Sequence keeps the Audio mounted only while it plays.
export const Sfx: React.FC<{
  src: string;
  at: number;
  volume: number;
  durationInFrames?: number;
  playbackRate?: number;
}> = ({ src, at, volume, durationInFrames = 15, playbackRate = 1 }) => (
  <Sequence from={at} durationInFrames={durationInFrames}>
    <Audio src={staticFile(src)} volume={volume} playbackRate={playbackRate} />
  </Sequence>
);
