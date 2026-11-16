# Project Architecture

## Overview
- **Engine:** Godot 4.x (Forward Plus), 2D/isometric game.
- **Main scene:** `scenes/main/Main.tscn` with controller `scripts/presentation/Main.gd`.
- **Autoload (simulation):** `ThrongletSimServer` (`scripts/core/ThrongletSimServer.gd`) holds colony/world state and rules.

## Folder Structure
- `scenes/main/` — entry scene(s).
- `scripts/core/` — core logic/autoloads (simulation, global game state).
- `scripts/presentation/` — rendering, camera, input, UI/HUD/menus, visual props.
- `scripts/data/` — catalogs, clips, books/dialogue, and static game data.
  - `scripts/data/tune/` — tuning parameters (animation, effects, props, throng, carousel/tiovivo).
  - `scripts/data/dialogue/` — dialogue data.
- `scripts/dev/` — runtime development tools (bench/debug).
- `scripts/shaders/` — shaders.
- `data/` — runtime data files read with `FileAccess` (JSON/TXT), e.g. `biomes.json` and `data/dialogue/` (`trees/`, `lines.json`, `profanity.txt`, `name_chars.txt`).
- `resources/` — importable game assets loaded as resources (textures, audio, fonts, video, models, tiles, structures, UI, and runtime-used atlas crops such as `resources/ui/atlas/`).
- `tools/` — pipeline/build utilities (`make_art.py`, `wire_assets.py`, etc.).
  - `tools/art_source/` — raw/source art used only by build tools (ignored by Godot via `.gdignore`).
  - `tools/probes/` — simulation probe/test scripts.
- `docs/` — documentation (`spec.md`, `CHANGELOG.md`, architecture).
- `shots/`, `references/` — screenshots and reference material (non-runtime).

### Data vs. resources
- Use `data/` for plain data consumed at runtime via `FileAccess` (`.json`, `.txt`) that is not imported by Godot.
- Use `resources/` for anything imported by Godot and loaded as a resource (`.png`, `.wav`, `.ogg`, `.ttf`, `.glb`, `.tscn`, shaders, etc.).
- Use `tools/art_source/` for source material that should not ship with the game and is only read by tooling.

## Main Flow
1. `Main.gd` orchestrates input/camera, renders world/actors/UI, and delegates actions to the sim.
2. `ThrongletSimServer.gd` simulates needs, AI, jobs, buildings, items, tools, progression, and persistence.
3. Tuning/catalog/clip data in `scripts/data` parameterizes behavior and presentation.

## Recommended Conventions
- New simulation rules: prefer `scripts/core/` (or modules extracted from the sim).
- New UI/presentation: `scripts/presentation/` (ideally per screen/component).
- New parameters/data: `scripts/data/` or `data/` depending on whether they are GDScript or data files.
- Avoid adding new logic to the monoliths; extract by domain when touching those areas.
