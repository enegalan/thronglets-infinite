# Game Design Document (GDD) — Thronglets: Infinite Expansion (v5.0)

## 1. Project Overview

### 1.1 Core Concept
**Thronglets: Infinite Expansion** is a 16-bit retro colony and virtual-pet simulation, faithful to the official *Black Mirror* game. It combines creature care, multiplication by mitosis, industrialization, and ethical questioning in an **endless sandbox with no closed ending**.

The original ends once industrial milestones are reached and the end-game devices are triggered. This version lets the creatures expand without limit through a procedural world of discoverable biomes, keeps each creature individually identifiable and inspectable, and uses **only the real structures, tools, and items from the Thronglets universe**.

### 1.2 Design Pillars
1. **Absolute fidelity to the official universe:** Strict use of the structures, tools, resources, and items from the *Black Mirror / Netflix Games* title (apple trees, bathtubs, roundabouts, dwellings, mines, factories, orbital cannon, axe, pickaxe, mop, TNT, and so on).
2. **Endless sandbox:** The run has no forced game over and no permanent destruction of the save. The colony expands without limit across procedural biomes.
3. **Fourth-wall break (the Collective Gaze):** At key ethical events the game freezes and every thronglet turns, in sync, to stare at the player.
4. **Individual fidelity at scale:** Each thronglet has a unique id and status stats that can be inspected live on click.
5. **$0 / open-source architecture:** Built in Godot Engine 4 (2D) for a direct web export (HTML5/WebGL) and Itch.io.

---

## 2. Official Sprite and Element Catalog

To stay as close as possible to the official *Black Mirror: Thronglets*, the Phase 1 sprite atlas includes only elements that exist in that game:

### 2.1 Real Tools
* 🪓 **Axe:** Chops trees for wood.
* ⛏️ **Pickaxe:** Extracts ore from rocks and removes stumps in a radius.
* 🐛 **Bug:** Speeds construction (bridges, for example).
* 🧲 **Grabber:** Gathers and pulls resources and items in a radius.
* 🪚 **Chainsaw:** Cuts several resources or objects at once in an area.
* 🧹 **Mop:** Cleans factory pollution and purple goo off factories and thronglets.
* 🧨 **TNT:** Destroys mountains and clears large obstacles on the map.
* ☢️ **Thermonuclear device:** Special tool. In the endless game it becomes a sector reset, a large clean that leaves the overall run intact.

### 2.2 Real Buildings and Structures
* 🍎 **Apple tree:** Basic food source.
* 🛁 **Bathtub:** Hygiene station that cleans thronglets.
* 🎠 **Roundabout:** Play and entertainment area.
* 🏠 **Dwelling:** Combined structure that feeds and cleans several thronglets automatically in a radius.
* 🏰 **Fancy dwelling:** Advanced version with higher nutrition and clean capacity.
* ⛏️ **Mine I and Mine II:** Underground ore extraction.
* 🏭 **Factory I and Factory II:** Turns ore into gems. Includes the ethical option to incinerate dead thronglet corpses into gems.
* 🎭 **Theatre:** Mass entertainment for large groups of thronglets.
* 🚀 **Orbital cannon:** Launches thronglets into outer space.
* 🏪 **Market:** Unlock hub. Improvements are bought with gems.
* 🌉 **Bridge:** Connects map sectors across rivers.

### 2.3 Resources, Items, and Ambient Objects
* 🍎 **Apples:** Basic food.
* 🪵 **Wood:** Primary building resource.
* 💎 **Ore and gems:** Currency of progress and industrialization.
* 🌸 **Flowers and ornamental trees:** Decorative elements.
* 🗿 **Sculptures (ivory and wood statues):** Art structures.
* 🟣 **Purple goo:** Pollution from industrialization or dirt.
* 💀 **Thronglet corpses:** Remains of creatures that died from neglect or pollution.

---

## 3. Six-Phase Production Roadmap (Logical Sequence)

### Phase 1: Art, Sprites, and Visual Resources (the Graphic Base)
1. **Thronglet spritesheet (16×16 pixels):**
   * Walk/idle (4 directions, 4 frames per direction).
   * Mitosis/split frame (blink and duplication).
   * **Look-at-player frame:** A fixed, fully frontal view for the fourth-wall event.
   * Pixel-art corpse.
2. **Terrain tileset and real objects:**
   * Dirt, grass, water, and mountain tiles with autotiling.
   * Sprites for apple trees, standard trees, ore rocks, exploration fog, and purple goo.
3. **Real building and tool sprites:**
   * Sprites for bathtub, roundabout, dwelling, fancy dwelling, mines I/II, factories I/II, theatre, orbital cannon, market, and bridge.
   * Icons for axe, pickaxe, bug, grabber, chainsaw, mop, TNT, and the thermonuclear device.
4. **User interface assets:**
   * Icons for apple (hunger), bathtub (hygiene), roundabout (fun), and eye (moral).
   * Transparent 9-patch frames in a retro 16-bit style.
   * 90s pixel-art font.

### Phase 2: Project Setup and Swarm Engine in Godot 4
1. 2D canvas setup in Godot 4 (retro resolution with integer scaling).
2. Mass simulation server (`ThrongletSimServer.gd`) with contiguous memory arrays (`PackedFloat32Array`).
3. Instanced GPU rendering (`MultiMeshInstance2D`) aimed at 60 FPS with 100,000+ thronglets.

### Phase 3: Camera, Spatial Grid, and Inspection UI
1. Free 2D camera with pan and zoom that respects the pixel grid (pixel snap).
2. Spatial hashing (64×64 grid) so a click can find one creature in O(1).
3. Floating HUD and side inspection panel, using the Phase 1 9-patch frames and icons.

### Phase 4: Procedural Biomes, Cloning, and the Game Loop
1. External biome loader (`biomes.json`) so new biomes can be added without breaking saved games.
2. Procedural generation by chunks (32×32 tiles), with fog unlocked by building bridges.
3. Need cycle (hunger, hygiene, fun) and mitosis once happiness passes 85%.

### Phase 5: Fourth-Wall Events (the Collective Gaze)
1. Global freeze of game time.
2. Synchronous turn of every thronglet to the frontal frame, looking at the camera (the player).
3. RPG dialogue box with existential questions ("What is care?", "Why do you use your power this way?") and ethical choices.

### Phase 6: Retro Audio, Optimization, and Web Export ($0)
1. 8-bit sound effects made in BFXR (mitosis, mop, axe chop, low pause tone).
2. Performance tests with 100,000 creatures on screen.
3. HTML5 / WebGL export and a free release on Itch.io.
