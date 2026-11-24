# Changelog

## [Unreleased](https://github.com/enegalan/thronglets-infinite/compare/v2.7.5...HEAD)

### 2026-11-25

- Eat body clip no longer sticks after the apple claim is lost: `ACT_EAT` is sticky only in bite range, the full AI path continues/clears chew via `_continue_eat`, and expired non-sticky acts clear even when `act_t` is already 0.
- Sponge scrub reads `stroke_min` / `stroke_cap` / `gain` / `radius` from `EffectTune` (defaults match the live gentle scrub).
- Building goo pollution is cached on the building and invalidated when goo tiles change, so draw/HUD no longer rescan footprints every frame.

### 2026-11-24

- Goo on a building footprint shuts houses, fancy houses, theatres, mines, and factories until it is mopped; those buildings also switch to active and goo sprite variants.
- Capacity marks now show occupancy for houses, fancy houses, and theatres plus mine stock, while factories keep their progress wedges. Full visit buildings read `LLENO`.
- World art is split into per-tile sprites and separate structure frames; the art tools and runtime drawing were updated to match, including the roundabout and flower strips. Prop draws can tint instances through the thronglet shader.
- Bath-exit sparkles now draw at 0.28 scale with a (9, 9) offset; wash sparkles use the same offset and sponge suds draw at 0.45 scale with a (7, 7) offset.
- Violent deaths (saw, TNT, nuke, axe splash) leave a blood pool under the corpse; neglect deaths do not. The bloody state is saved and restored.
- Flower buildings use updated art and animation offsets, can be placed from the sandbox terrain props, and factory pollution goo now spills on 25% of completed cycles instead of every cycle.
- Thronglets inside visit buildings do not show thought bubbles while hidden indoors.
- Kit building placement previews use the same loose Sprite2D frames as placed buildings, so flower and roundabout ghosts match what lands on the island.
- Factories now use a 4x4 footprint; statues and wood sculptures draw at 1.03 scale. The axe hint notes it can kill nearby multis.
- Added bench probes and shot modes for building goo, visit capacity, flower placement, no indoor barks, and corpse blood; video-gap notes record the verified building UI.

### 2026-11-23

- Dirty thronglets stay dirty while walking at default zoom: far-view LOD no longer zeroes the dirt factor (held already kept it). Missing dirt masks filled via `python3 tools/fill_throng_dirt.py`; check with `--shot-dirt`.
- Grabbing a thronglet no longer draws a giant walk sprite on top: FX (hand, bubbles, fire, …) were restored after the throng extras that had overwritten those atlas cells.
- Thronglet body clips share one foot baseline in the atlas (no more floating FreakOut / clipped walks); hop clips keep their air. Re-home with `python3 tools/home_throng_atlas.py`.
- Thronglet animations follow situation pools (idle / mood / peer talk-sing / console stare / possessed / celebrate / panic) with a tiered `_frame` selector; Unity panic, carry, mood-walk, puppy, and awe sheets are packed into the atlas and wired.
- Post-feed `Rotund` and eat→`Celebrate` cheer removed: playthrough frames show Happy stand after a bite ([68:03](references/video-frames/t068-03.jpg)), not a fat walk or cheer hop. `Celebrate` stays on unlock (`celebrate_t`). Dense eat/wash frames added under `references/video-frames/`.
- `ACT_WASH` is no longer sticky after scrub ends (was looping `Happy` forever).
- Full situation wiring audit vs playthrough: `_begin_gaze` no longer forces `glitch_t` (POSSESSED was firing on every talk; inject frames stay Default). Dead `cheer_t` body path removed; Celebrate/Panic pools trimmed to live clips.
- Ball play no longer pops a giant thronglet: pack-extra clips (`Happy_Walk`, `FreakOut`, carry, …) were missing from `ThrongTune.SCALE` and drew at 1.0 instead of 0.4. Check with `--shot-ball` → `shots/ball_kick_scale.png`.
- Sponge wash: one bubble atlas cell (no stacked sheets); suds only on the thronglet under the sponge; prior targets clear when the sponge moves on; sparkles on release. Shot: `wash_scrub_vs_sparkle.png`.
- Thought-bubble barks pick a random `SingB`/`SingC`/`SingD`/`SingE` while free; the thronglet stands still for one full clip (bark life = frames/8fps).

### 2026-11-22

- Zooming out keeps performance steadier: distant thronglets and static props use lighter rendering paths, simulation ticks batch living agents and throttle compaction, and idle ground items skip unnecessary physics checks.
- Added performance bench and repro scripts for zoom-out, save, and pick/zoom scenarios.

### 2026-11-20

- Tapping a thronglet opens a HUD needs card instead of three bars over its head.

### 2026-11-19

- New eating system for apples: Thronglets can now bite into apples up to 3 times.
- The hand tool shows a single sprite in the kit and plays the pickup strip while dragging over something it can collect; idle drags stay on the first frame.
- Runtime animations follow their `AnimTune` entries: per-clip fps, frame scale, offset, and rotation now drive the hand, egg, bubbles and foam, splash and clean pops, fire, fumes, anomaly rays, biome features, and the roundabout instead of hardcoded timings.
- The progression milestone that required 100 gems now requires 20 gems.
- Island expansions are larger: early land-tier growth is doubled and later tiers expand to the chunk edge.
- Kit tab icons have been updated.
- Kit buildings now show their price with the correspondent icon.
- Removed remaining bridge remnants: bridge dialogues/trees and related lines, bridge audio and art/sprite assets, and leftover bridge code, probes, spec text, catalog/gaze references, and reference assets.

### 2026-11-18

- Dropped and thrown items now use a physics system: they arc, bounce, collide with obstacles and each other, can be thrown from the hand, and react to terrain edges and water instead of stopping instantly.
- Tool use shows an area-of-effect preview with dashed reach, target outlines, and clearer feedback for affected items, features, buildings, and thronglets.
- Mine footprints act as walkable ground pads, and item/thronglet drop handling is safer around blocked tiles, water, fog, and void edges.
- The axe tutorial unlock is gated on reaching a peak colony of six thronglets, and the hammer unlocks from cutting trees; sponge, mop, and swarm use consistent tuned interaction radii.
- Splash effects use tuned frame scales for the new item/water interactions.
- Thronglets leaving the bathtub sparkle on exit, monoliths rise vertically with an appearance cinematic, and occupied theatre, dwelling, and fancy-house windows switch to their active sprites.
- Bridge construction and bridge-driven island progression were removed. The starting island now grows into a larger single landmass over time, with progression, saves, and world logic updated for the bridge-free flow.

### 2026-11-17

- Thronglet pathing avoids getting stuck on building corners and blocked goals: they peel sideways around convex obstacles, stop camping at occupied tubs or full buildings, and resume seeking elsewhere until a spot is free.
- Thought bubbles no longer suggest a tub or roundabout while a thronglet is already using one, and ambient barks appear less often.
- Trees, rocks, and other placed features snap to the tile grid on spawn, load, and reindex to stay aligned with terrain.
- Save data remains compatible with the new pathing state.
- Water tiles animate by cycling frames over game time, and several visual timers (eggs, bubbles, plates, gaze glyphs) now follow paused game time instead of the real clock.
- Thronglet draw sorting uses their ground position so large animations such as mitosis no longer sort too far forward.
- Thronglets stay still while the mitosis animation plays (including the charge-up), so they no longer walk through the split.
- The development bench releases lab drags correctly on mouse release, and the FPS overlay applies when entering play or the bench.

### 2026-11-16

- Thronglets in the mitosis animation can no longer be interacted with: autonomous actions remain paused during `mito_t`, scrubbing and mopping skip them, and grabbing them is blocked until the animation ends (their thought bubble also closes when picked up).
- Dragged thronglets released on water or on blocked/construction tiles are displaced to a nearby safe spot instead of dying; releasing them outside the island (`TILE_VOID`/`TILE_FOG`) still kills them.
- Infinite progression is now driven by a decoupled catalog and manager: tool/building unlocks evaluate live metrics (population, total gems earned, pollution, deaths, trees cut) with systemic conditions instead of one-off narrative triggers.
- Improved tools replace their base versions in the HUD and active selection (hammer→pickaxe, axe→chainsaw, sponge→mop, bug→swarm), and repeatable buildings use exponentially scaled placement costs.
- Simulation telemetry tracks cumulative gems earned, deaths, and pollution state for progression; catalog-driven unlocks and progression hooks (narrative/world side effects) are centralized in the progression manager.
- The development bench includes a tiovivo lab for trying carousel layouts and ride timing. Its saved tuning is shared with the game so ride spacing, spin, and fun rates stay in step.
- Mines act as walkable pads. When a factory exists, miners take ore into their hands for delivery instead of dropping it on the ground, and mines no longer block movement.
- Clicking a thronglet selects it and keeps the camera following until you click elsewhere. Sponge scrubbing responds to movement over dirty thronglets, and expired ground items and some chop feedback no longer spawn extra poofs.
- Dropped thronglets avoid unsafe tiles (water, fog, void, or blocked land) by falling back to a nearby safe spot when possible.
- Presentation code was split into dedicated camera, UI, and media helpers; save and shot-capture scripts moved under core/dev, and monolith props moved into the props folder.
- Progression, tuning, and probe scripts were adjusted to match the reorganized systems.
- Animation and effect tuning values were adjusted, including mitosis and clean/suds frames, feature footprints, and effect preview options.
- Added a VS Code launch configuration for running the main Godot scene.

### 2026-11-15

- Needs drain faster, while baths clean more slowly and rides take longer to satisfy. A thronglet keeps bathing or riding until the stay is done and the need is topped up.
- Hauling and mine work can continue while basic needs are steady, so unfinished loads and ore runs are less likely to stall. Mitosis also respects a colony space cap.
- Islands start and refill with more trees and ore, and biome scatter yields more resources.
- Carried goods use item-sized sprites, roundabout riders sit and orbit on the ride, and ore deliveries no longer pop an extra marker at the factory.
- The development bench, effects, tuning values, and shot probes gained more options for checking carry and ride behaviour.

### 2026-11-13

- The bars open the original Tuckersoft settings: black panel, logo, close chip, and four tabs for mail, cog, sound, and edit. Captions, CRT, language, volumes, support, credits, and reset live there; development and quit stay on the cog tab. Blue buttons use the blue rim and white inner frame; the close chip is the original `cancel` asset; the version line follows the project tag.
- One run only: it autosaves, `Comenzar` resumes that save, and game over can restore the latest autosave history. Pause no longer offers save or load slots.
- The title opens ready to play: a wooden `Comenzar` plate resumes the last save when there is one, otherwise starts a run. The bars open settings, and the video plate opens the OldOS shell `C:\BIN\.SHELL\` with eight MOV slots (unlocked thumbs after watching) and EXIT.
- The task banner uses the original goal plate: a white frame, a cyan inner ring, and a drop shadow, sitting beside the population badge.

### 2026-11-12

- The task banner uses the OldOS goal frame: a cyan tag and a stretchable body. Letters use the Aline font, with the DOS face as a fallback. The wood panel is filled solid.
- Thronglets draw smaller, and so do the tub, roundabout, egg, rocks, ore, and carried goods. Each kind has its own scale.
- Talk follows trees drafted from the Spanish book. The console uses the original panel and border. Choices walk the tree, and ambient lines can open when nothing else is waiting.
- On the development bench, you can pick several props at once and nudge them together.
- Grass stays grass. A path sprite is laid on top where they have walked.
- The kit is the original wood tray. Each group has its own icon, and the selected group uses the same slot as the items. The hammer fills the round button.
- The counter, the need gauges, and the pollution marks use the original art. A market shows the new-item sign when something there can be bought.
- The console sits across the bottom, over the wood frame. The log and each choice have their own glyphs and swirls, and the border is a solid line. Opening a talk glitches the screen.
- Speech uses the original animated bubble, with the tail aimed at the thronglet.
- A factory fills one wedge per ore, up to eight, and then it takes no more. Ore stacks beside it in the order it arrived, and the factory spends the oldest first.
- The development bench lists every strip on the sprite sheet. The egg and the roundabout stay off that list, because the sheet does not own them.
- The population badge is the native counter cell. The ring and the face use the soft filter, so the cream ring stays whole.
- After the Tuckersoft logo, a green DOS session types itself out: `TS-DOZ`, `TUCK96.IMG`, `HIMEM`, and the `.COM` directory. A click skips it.
- The title has settings: video captions, a CRT overlay, and the language row with the original icons. Captions and the overlay are remembered.
- The first minutes stay inside the wood frame. A plank sign steps through the opening lines before the tray and the counter appear. The counter reads `?` until that stretch ends. The first talk waits. A hatch pops a spark.
- After that talk, the game asks what the thronglets should call you, asks you to confirm, and refuses an empty, unknown, or banned name.
- The title is a painted scene: sky, sun flare, drifting clouds, grass, thronglets, an egg, and the logo. The menu sits on the grass.
- The pause button uses the original bars icon. When a save lands, a disk flashes beside it.
- The CRT filter starts on, covers the whole screen including menus, and the scanlines read harder.

### 2026-11-11

- Buildings claim a footprint: the tub takes two tiles, homes and mines take a square, the theatre takes a wider pad. Ghost and place marks follow that shape.
- A thronglet can sit in the bathtub and soak. The roundabout is a real ride. Apple trees grow fruit in the canopy and drop it nearby.
- Trees grow back more slowly after you cut them.
- Hold the hand tool on a thronglet to pick it up. A short click still opens its status.
- Speech uses the old bubble shape and colors. Dirty thronglets show dirt on their fur.
- Bridge tiles match the grass diamonds, with plank seams on the wood span.
- Thronglets path with more curiosity, keep clearer thoughts over their heads, and the talk and tool copy is tighter Spanish.
- Debug shots land under `shots/` and stay out of git.
- Pads were measured again. The factory is a short pad, mines and the theatre take a square, the market is wider, and homes take a larger square. Sprites sit on the middle of that pad. Several thronglets can ride the roundabout at once.
- Grass wears down to a path, then to dirt, where they walk. Rivers and the wasteland use their own ground tiles.
- Later, the world opens a mountain, a glitch land, an anomaly, and an epilogue. Each has its own props, music, and a short film the first time the camera arrives. A click skips a film. The Tuckersoft logo plays before the title.
- The monolith is the original model. Anomaly and epilogue land show a plate over the chunk.
- Talk quotes a line from the Spanish book, then the choice. The interface uses the DOS font, the wood frame, and the epilogue faces.
- Mines and the market have their own ambience. Singing, splashes, and the rest of the original effects are in the bank. Thronglets also play the extra original clips, including the bored kick.
- The anomaly is a pile with a ray above it, instead of one picture swapping for the other.
- Thronglets use their original sprites and stand on their feet. Kicking a rock, the fire, and the hand no longer include a piece of another sprite.
- The art the game builds from is stored with the game. The reference dump is only there to copy from, and can go when the game is finished.
- The title opens a development bench for placing props and nudging each animation. Scale, position, and rotation can apply to the frame you see, or to every frame. Those notes stay out of the repository.
- Title menu letters stay dark on the wood.

### 2026-11-10

- Thronglets act out what they are doing: walk, eat, bathe, play, work, talk, or stand still. A sad one looks sad. A happy one looks happy. Going west turns them to face west.
- The circle above their head is gone. Click one to see food, play, and clean.
- When the last thronglet dies, the run ends. You can start over, or load the last save of that game.
- The game saves itself every minute.
- A falling egg stays in front of the trees.
- The island is bigger, with a coast, a lake, forests, and rocks, and enough wood and ore to get started. The egg lands in an open clearing.
- Flowers are something you build.
- Rocks, ore, and decorations no longer pile on top of each other. Trees can stand close together.
- A mine sits in open grass, with nothing grown against it.
- Big rocks and ore rocks are smaller.
- Mitosis waits about a minute once they are well fed, entertained, and clean, then takes a short while to finish. They get hungry more slowly.
- Tools show up as you follow the tasks. The orbital cannon is gone. The second monolith cleans a whole area and the game keeps going.
- They visit homes, baths, the roundabout, and the theatre. Apple trees drop fruit. They talk.
- Title screen, save slots, drag to build, and the original music and sounds.
- The window can grow to fill the monitor. You see more of the island, and the pixels stay sharp.
- Hold a tool and it charges before it acts. You can zoom in and out further.
- The game starts with one egg. Tap it four times. Only the first hatch brings a thronglet.
- They go after apples and balls, trees grow back, and they get out of corners.
- One conversation at a time. The colony turns to look at you, and you choose.
- A bridge of wood and bone leads to another island. The rest of the world stays hidden until a path opens.
- Mines, and some ore ready from the start.

### 2026-11-09

- Eating has its own little animation.
- Land outside the home island stays hidden until the world opens.
- First playable version: care for the thronglets, use tools and buildings, and grow the island.

## [v2.7.5](https://github.com/enegalan/thronglets-infinite/compare/v2.7.0...v2.7.5) - 2026-11-23

### What's Changed

* Update CHANGELOG for v2.7.0 by [@github-actions](https://github.com/github-actions)[bot] in https://github.com/enegalan/thronglets-infinite/pull/35
* fix: performance drops when zooming out by [@enegalan](https://github.com/enegalan) in https://github.com/enegalan/thronglets-infinite/pull/38
* chore: set application version to 2.7.5 by [@github-actions](https://github.com/github-actions)[bot] in https://github.com/enegalan/thronglets-infinite/pull/39

**Full Changelog**: https://github.com/enegalan/thronglets-infinite/compare/v2.7.0...v2.7.5

## [v2.7.0](https://github.com/enegalan/thronglets-infinite/compare/v2.6.5...v2.7.0) - 2026-11-20

### What's Changed

* Update CHANGELOG for v2.6.5 by [@github-actions](https://github.com/github-actions)[bot] in https://github.com/enegalan/thronglets-infinite/pull/33
* chore: set application version to 2.7.0 by [@github-actions](https://github.com/github-actions)[bot] in https://github.com/enegalan/thronglets-infinite/pull/34

**Full Changelog**: https://github.com/enegalan/thronglets-infinite/compare/v2.6.5...v2.7.0

## [v2.6.5](https://github.com/enegalan/thronglets-infinite/compare/7851ab6...v2.6.5) - 2026-11-20

### What's Changed

* feat(ui): implement new HUD needs card for thronglets, replacing needbars with a card by [@enegalan](https://github.com/enegalan) in https://github.com/enegalan/thronglets-infinite/pull/29
* fix(ci): sync app version via pull request by [@enegalan](https://github.com/enegalan) in https://github.com/enegalan/thronglets-infinite/pull/31
* chore: set application version to 2.6.5 by [@github-actions](https://github.com/github-actions)[bot] in https://github.com/enegalan/thronglets-infinite/pull/32

### New Contributors

* [@github-actions](https://github.com/github-actions)[bot] made their first contribution in https://github.com/enegalan/thronglets-infinite/pull/32

**Full Changelog**: https://github.com/enegalan/thronglets-infinite/compare/v2.6.0...v2.6.5
