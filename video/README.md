# OPM product videos

Three deterministic Remotion compositions live here:

- `Launch`: 1080×700, 30 fps, 38 seconds.
- `Tutorial`: 1920×1080, 30 fps, 85 seconds.
- `GuiTutorial`: 1920×1080, 30 fps, 72 seconds.

All visible profiles, paths, and quota values are synthetic. Audio is generated locally from `scripts/gen-sfx.mjs`; there is no downloaded music or recorded screen content.

Authoring requires Node 24 and npm 11, matching the repository `.nvmrc` and this directory's `package.json`. Use the committed lockfile for reproducible installs.

```bash
npm ci
npm run dev
npm run render:launch
npm run render:tutorial
npm run render:gui
```

Rendered files are written to `out/` and are intentionally ignored by Git.
