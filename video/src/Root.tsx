import { Composition } from "remotion";
import { Launch } from "./Launch";
import { Tutorial } from "./Tutorial";
import { GuiTutorial } from "./GuiTutorial";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="Launch" component={Launch} durationInFrames={1140} fps={30} width={1080} height={700} />
      <Composition id="Tutorial" component={Tutorial} durationInFrames={2550} fps={30} width={1920} height={1080} />
      <Composition id="GuiTutorial" component={GuiTutorial} durationInFrames={2160} fps={30} width={1920} height={1080} />
    </>
  );
};
