class_name Catalog

const TILE := 16
## Tiles along one edge of a terrain chunk buffer in the world grid.
const CHUNK := 32
## World units per spatial hash bucket for neighbor queries.
const HASH_CELL := 64.0
## Bucket count for the spatial hash backing thronglet proximity lists.
const HASH_SIZE := 4096
## Upper bound on simultaneous thronglet agents in the structure-of-arrays.
const MAX_SLOTS := 120000
## Presentation: above this many on-screen thronglets, switch to cheap crowd LOD
## (still draws every thronglet in the viewport — no density hiding).
const DRAW_THRONG_DETAIL := 420
## Seconds before a thronglet re-evaluates speech-bubble desire icons.
const BARK_COOL := 1.6
## How long a thronglet keeps walking toward a remembered seek target.
const SEEK_HOLD := 0.55
## Walkable land tiles needed before another thronglet can split.
const SPACE_PER_THRONG := 14
## Soft local pile limit: mitosis waits if this many already sit nearby.
const LOCAL_CROWD_R := 56.0
## Neighbor thronglet count inside LOCAL_CROWD_R that blocks mitosis.
const LOCAL_CROWD_N := 12
## World-space radius for "near a building" (music spot, ore seek, probes).
const NEAR_BUILDING := 180.0
## Wellness threshold treated as comfortably satisfied for routine AI.
const NEED_OK := 85.0
## Fed meter below which hunger seeking and apple runs dominate behavior.
const NEED_HUNGRY := 75.0
## Need level that triggers active seeking toward relief buildings or items.
const NEED_SEEK := 40.0
## Amusement meter threshold for boredom and play-seeking decisions.
const NEED_FUN := 82.0
## Seconds of sustained wellness before a thronglet may attempt mitosis.
const MITOSIS_WAIT := 60.0
## Delay after felling before a tree stump may regrow into a full tree.
const TREE_REGROW := 90.0
## Delay after clearing a stump before a new tree may sprout on the cell.
const TREE_REPLANT := 60.0
## Canopy sockets in world space that only shift iso X (±10 / 0), plus screen lift into the leaves.
const APPLE_SPOTS := [Vector2(-5.0, 5.0), Vector2(5.0, -5.0), Vector2(0.0, 0.0)]
## Screen Y lift per canopy socket so fruit reads inside the leaves.
const APPLE_LIFTS := [32.0, 30.0, 40.0]
## Seconds for a ripe apple to detach and fall from the tree canopy.
const APPLE_FALL_T := 1.7
## Minimum ground scatter distance when a fallen apple lands.
const APPLE_LAND_MIN := 10.0
## Maximum ground scatter distance when a fallen apple lands.
const APPLE_LAND_MAX := 24.0
## Seat in the tub, world offset from the snap cell.
const TUB_SEAT_OFF := Vector2(8.0, 12.0)
## Ride seat from the snap cell. Mid sits on the painted hub (tune: 14,14).
## Radius keeps feet on the wedges; larger values spill onto the grass.
const ROUND_RIDE_OFF := Vector2(12.0, 12.0)
## Seat ring radius keeping carousel feet on the painted wedges.
const ROUND_RIDE_RADIUS := 4.0
## Number of simultaneous riders the roundabout building supports.
const ROUND_RIDE_SLOTS := 4
## Carousel angular speed scaling how fast the ride sprite spins.
const ROUND_SPIN_RATE := 2.8
## Draw scale for the bathtub building prop in world presentation.
const TUB_SPRITE_SCALE := 0.35
## Draw scale for the tiovivo carousel prop.
const ROUND_SPRITE_SCALE := 0.45
## Draw scale for decorative flower feature props.
const FLOWER_SPRITE_SCALE := 0.5
## Draw scale for standard ore node features.
const NODE_SPRITE_SCALE := 0.7
## Draw scale for oversized super-node features.
const SUPER_SPRITE_SCALE := 0.6
## Draw scale for loose ore item pickups.
const ORE_SPRITE_SCALE := 0.4
## Draw scale for the tutorial egg world prop.
const EGG_SPRITE_SCALE := 0.4
## Draw scale for plain surface rocks without ore.
const ROCK_SPRITE_SCALE := 0.25
## Draw scale for ore-bearing surface rocks.
const ROCK_ORE_SPRITE_SCALE := 0.4
## Draw scale for mega, super, and ultra ore clusters.
const ORE_CLUSTER_SPRITE_SCALE := 0.4
## Draw scale for ball items kicked for amusement.
const BALL_SPRITE_SCALE := 0.25
## Draw scale for log and plank wood haulables.
const WOOD_SPRITE_SCALE := 0.5
## Draw scale for bone loot left after defleshing.
const BONE_SPRITE_SCALE := 0.25
## Draw scale for explosive TNT charges on the ground.
const TNT_SPRITE_SCALE := 0.25
## Draw scale for the rare curer landmark feature.
const CURER_SPRITE_SCALE := 0.3
## Draw scale for positive cosmetic world decorations.
const COSMETIC_SPRITE_SCALE := 0.6
## Draw scale for negative cosmetic clutter props.
const COSMETIC_BAD_SPRITE_SCALE := 0.7
## Draw scale for dropped apple food pickups.
const APPLE_SPRITE_SCALE := 0.15
## Draw scale for sponge items when carried or dropped.
const SPONGE_SPRITE_SCALE := 0.25
## Vertical lift applied while a thronglet soaks in the tub.
const TUB_SOAK_LIFT := 4.0
## Extra lift during the tub entry splash animation.
const TUB_ENTER_LIFT := 11.0
## Normalized seconds to fully charge a hold-to-use player tool.
const TOOL_CHARGE := 0.55
## World radius of the chainsaw clear-cut area while charged.
const SAW_RADIUS := 40.0
## World radius of the pickaxe smash affecting rocks and stumps.
const PICK_RADIUS := 42.0
## World radius for hammer strikes on ore and structures.
const HAMMER_ORE_RADIUS := 48.0
## World radius scooped when the grabber tool gathers ground loot.
const GRAB_RADIUS := 48.0
## World radius cleaned by the mop on goo and dirty thronglets.
const MOP_RADIUS := 48.0
## World radius reached by a sponge scrub pass.
const SPONGE_RADIUS := 30.0
## World radius for the swarm tool deflesh burst.
const SWARM_RADIUS := 36.0
## Debug tint drawn for valid tool hover reach while aiming.
const TOOL_REACH_COLOR := Color(0.28, 0.92, 0.32, 0.95)
## Debug tint drawn for tool charge fill during hold actions.
const TOOL_CHARGE_COLOR := Color(1.0, 1.0, 1.0, 0.95)

## Terrain tile id for default walkable grass.
const TILE_GRASS := 0
## Terrain tile id for worn or bare dirt ground.
const TILE_DIRT := 1
## Terrain tile id for blocked water cells.
const TILE_WATER := 2
## Terrain tile id for impassable mountain rock.
const TILE_MOUNTAIN := 3
## Terrain tile id for blast or collapse rubble.
const TILE_RUBBLE := 4
## Terrain tile id for pollution goo that needs cleaning.
const TILE_GOO := 5
## Terrain tile id for unrevealed fog-of-war cells.
const TILE_FOG := 8
## Sentinel tile id for out-of-map void padding.
const TILE_VOID := 255
## Terrain tile id for special blooming grass variants.
const TILE_BLOOM := 9
## Number of defined terrain tile ids in this catalog.
const TILE_COUNT := 10

## Thronglet life-state id for active living agents.
const ST_LIVING := 0
## Thronglet life-state id for corpses awaiting cleanup.
const ST_DEAD := 1
## Thronglet slot state id for unused agent rows.
const ST_VACANT := 2

## Carry-kind id when a thronglet hauls nothing.
const CARRY_NONE := 0
## Carry-kind id while hauling a wood log.
const CARRY_WOOD := 1
## Carry-kind id while hauling a bone.
const CARRY_BONE := 2
## Carry-kind id while hauling ore nuggets.
const CARRY_ORE := 3

## World feature kind id for harvestable trees.
const FEAT_TREE := 1
## World feature kind id for tree stumps after chopping.
const FEAT_STUMP := 2
## World feature kind id for surface boulders.
const FEAT_ROCK := 3
## World feature kind id for standard underground ore nodes.
const FEAT_NODE := 4
## World feature kind id for rare oversized resource nodes.
const FEAT_SUPER := 5
## World feature kind id for ambient flower decorations.
const FEAT_FLOWER := 6
## World feature kind id for story monolith landmarks.
const FEAT_MONOLITH := 7
## World feature kind id for oversized blocking boulders.
const FEAT_BIGROCK := 8
## World feature kind id for positive cosmetic props.
const FEAT_COSMETIC := 9
## World feature kind id for negative visual clutter props.
const FEAT_COSMETIC_BAD := 10
## World feature kind id for mega ore clusters.
const FEAT_ORE_MEGA := 11
## World feature kind id for super ore clusters.
const FEAT_ORE_SUPER := 12
## World feature kind id for ultra ore clusters.
const FEAT_ORE_ULTRA := 13
## World feature kind id for burning hazard props.
const FEAT_FIRE := 14
## World feature kind id for totem landmarks.
const FEAT_TOTEM := 15
## World feature kind id for the curer healing shrine.
const FEAT_CURER := 16
## World feature kind id for monolith-tier mutant stumps.
const FEAT_MSTUMP := 18
## World feature kind id for monolith-tier mutant nodes.
const FEAT_MNODE := 19
## World feature kind id for glitch-story corrupted trees.
const FEAT_GLITCH_TREE := 20
## World feature kind id for glitch-story corrupted houses.
const FEAT_GLITCH_HOUSE := 21
## World feature kind id for the anomaly spectacle prop.
const FEAT_ANOMALY := 22
## World feature kind id for endgame epilogue scenery.
const FEAT_EPILOGUE := 23
## World feature kind id for scripted mountain landmarks.
const FEAT_MOUNTAIN := 24

## Loose item kind id for edible apples on the ground.
const ITEM_APPLE := 1
## Loose item kind id for kickable amusement balls.
const ITEM_BALL := 2
## Loose item kind id for haulable wood logs.
const ITEM_WOOD := 3
## Loose item kind id for bone remains.
const ITEM_BONE := 4
## Loose item kind id for mineable ore nuggets.
const ITEM_ORE := 5
## Loose item kind id for placed explosive charges.
const ITEM_TNT := 6
## Loose item kind id for the tutorial egg prop.
const ITEM_EGG := 7

## Building kind id for the apple tree food source.
const BLD_APPLE := 1
## Building kind id for the cleanliness bathtub.
const BLD_TUB := 2
## Building kind id for the tiovivo carousel ride.
const BLD_ROUND := 3
## Building kind id for standard housing dwellings.
const BLD_DWELL := 4
## Building kind id for luxury deluxe dwellings.
const BLD_FANCY := 5
## Building kind id for the tier-one ore mine.
const BLD_MINE := 6
## Building kind id for the upgraded tier-two mine.
const BLD_MINE2 := 7
## Building kind id for the tier-one smelting factory.
const BLD_FACTORY := 8
## Building kind id for the tier-two gem factory.
const BLD_FACTORY2 := 9
## Building kind id for the amusement theatre.
const BLD_THEATRE := 10
## Building kind id for the gem shop market stall.
const BLD_MARKET := 12
## Building kind id for placeable flower beds.
const BLD_FLOWER := 13
## Building kind id for stone sculpture placements.
const BLD_STATUE := 14
## Building kind id for carved wood statue placements.
const BLD_WOOD := 16

## Player tool id for the passive observation / gaze mode.
const TOOL_EYE := 0
## Player tool id for dropping apples to feed thronglets.
const TOOL_APPLE := 1
## Player tool id for spawning amusement balls.
const TOOL_BALL := 2
## Player tool id for scrubbing dirty thronglets.
const TOOL_SPONGE := 3
## Player tool id for charging tree chops.
const TOOL_AXE := 4
## Player tool id for breaking stumps, rocks, and structures.
const TOOL_HAMMER := 5
## Player tool id for defleshing a single thronglet.
const TOOL_BUG := 6
## Player tool id for area pickaxe smashes on stone.
const TOOL_PICK := 7
## Player tool id for chainsaw area tree clearing.
const TOOL_SAW := 8
## Player tool id for scooping and relocating ground loot.
const TOOL_GRAB := 9
## Player tool id for cleaning goo tiles and thronglets.
const TOOL_MOP := 10
## Player tool id for radius deflesh swarm bursts.
const TOOL_SWARM := 11
## Player tool id for placing remote-detonated charges.
const TOOL_TNT := 12
## Player tool id for the thermal sector cleanse.
const TOOL_NUKE := 13

## Thronglet animation frame id for idle staring poses.
const FRAME_STARE := 20
## Thronglet animation frame id for corpse piles.
const FRAME_CORPSE := 21
## Thronglet animation frame id for illness visuals.
const FRAME_SICK := 22
## Thronglet animation frame id for eating apple bites.
const FRAME_EAT := 23

## Atlas is 32 columns by 2 rows. Keep indices aligned with tools/make_art.py.
## 16px atlas index for the apple tool, dropped food pickups, and hunger bark glyphs.
const ICON_APPLE := 0
## 16px atlas index for the ball tool and kickable amusement items.
const ICON_BALL := 1
## 16px atlas index for living trees on the minimap and placement hints.
const ICON_TREE := 2
## 16px atlas index for tree stumps and chop targets.
const ICON_STUMP := 3
## 16px atlas index for plain surface boulders.
const ICON_ROCK := 4
## 16px atlas index for ore-bearing surface rocks.
const ICON_ORE_ROCK := 5
## 16px atlas index for standard underground ore nodes.
const ICON_NODE := 6
## 16px atlas index for rare super resource nodes.
const ICON_SUPER := 7
## 16px atlas index for haulable wood logs.
const ICON_WOOD := 8
## 16px atlas index for bone loot and deflesh results.
const ICON_BONE := 9
## 16px atlas index for loose ore nuggets and mine output.
const ICON_ORE := 10
## 16px atlas index for the apple tree building in build mode.
const ICON_APPLE_TREE := 11
## 16px atlas index for the bathtub building and soak barks.
const ICON_TUB := 12
## 16px atlas index for the tiovivo carousel building.
const ICON_ROUND := 13
## 16px atlas index for standard dwelling placements.
const ICON_DWELL := 14
## 16px atlas index for luxury dwelling placements.
const ICON_FANCY := 15
## 16px atlas index for the tier-one mine structure.
const ICON_MINE := 16
## 16px atlas index for the upgraded tier-two mine.
const ICON_MINE2 := 17
## 16px atlas index for the tier-one smelting factory.
const ICON_FACTORY := 18
## 16px atlas index for the tier-two gem factory.
const ICON_FACTORY2 := 19
## 16px atlas index for the amusement theatre building.
const ICON_THEATRE := 20
## 16px atlas index for the gem shop market stall.
const ICON_MARKET := 22
## 16px atlas index for decorative flower placements.
const ICON_FLOWER := 23
## 16px atlas index for stone sculpture placements.
const ICON_STATUE := 24
## 16px atlas index for story monolith landmarks.
const ICON_MONOLITH := 25
## 16px atlas index for TNT charges and the explosives tool.
const ICON_TNT := 26
## 16px atlas index for pollution goo tiles and warnings.
const ICON_GOO := 27
## TODO: Update following icons positions in the atlas
## 16px atlas index for the tree-chopping axe tool.
const ICON_AXE := 29
## 16px atlas index for the structure-breaking hammer tool.
const ICON_HAMMER := 30
## 16px atlas index for the sponge wash tool and scrub barks.
const ICON_SPONGE := 31
## 16px atlas index for the pickaxe mining tool.
const ICON_PICK := 32
## 16px atlas index for the deflesh bug tool.
const ICON_BUG := 33
## 16px atlas index for the grabber relocation tool.
const ICON_GRAB := 34
## 16px atlas index for the chainsaw clear-cut tool.
const ICON_SAW := 35
## 16px atlas index for the mop goo-cleaning tool.
const ICON_MOP := 36
## 16px atlas index for the swarm radius deflesh tool.
const ICON_SWARM := 37
## 16px atlas index for the thermal sector cleanse tool.
const ICON_NUKE := 38
## 16px atlas index for gem currency and market purchases.
const ICON_GEM := 39
## 16px atlas index for the tutorial egg prop.
const ICON_EGG := 40
## 16px atlas index for chop impact effect badges.
const ICON_FX_CHOP := 41
## 16px atlas index for hammer strike effect badges.
const ICON_FX_HAMMER := 42
## 16px atlas index for mining spark effect badges.
const ICON_FX_SPARK := 43
## 16px atlas index for explosion effect badges.
const ICON_FX_BOOM := 44
## 16px atlas index for violent death effect badges.
const ICON_FX_BLOOD := 46
## 16px atlas index for oversized blocking boulders.
const ICON_BIGROCK := 47
## 16px atlas index for positive cosmetic clutter.
const ICON_COSMETIC := 48
## 16px atlas index for negative cosmetic clutter.
const ICON_COSMETIC_BAD := 49
## 16px atlas index for mega ore cluster features.
const ICON_ORE_MEGA := 50
## 16px atlas index for super ore cluster features.
const ICON_ORE_SUPER := 51
## 16px atlas index for ultra ore cluster features.
const ICON_ORE_ULTRA := 52
## 16px atlas index for carved wood statue placements.
const ICON_WOOD_STATUE := 53
## 16px atlas index for fire hazards and burn barks.
const ICON_FIRE := 54
## 16px atlas index for totem landmark features.
const ICON_TOTEM := 55
## 16px atlas index for the curer healing shrine.
const ICON_CURER := 56
## 16px atlas index for jack-of-all-trades debug or event markers.
const ICON_JACK := 57
## 16px atlas index for the superbug swarm upgrade.
const ICON_SUPERBUG := 58
## 16px atlas index for theatre upgrade or alternate art.
const ICON_THEATRE2 := 59
## 16px atlas index for the act-three gaping maw spectacle.
const ICON_MAW := 60
## 16px atlas index for monolith-tier mutant stumps.
const ICON_MSTUMP := 61
## 16px atlas index for monolith-tier mutant ore nodes.
const ICON_MNODE := 62

## Column count of the 16px Sprites-Icons toolbar atlas.
const ATLAS_COLUMNS := 32

## Speech-bubble thought glyphs from text_sprites_new.png (Unity rects, Godot Y).
## ICON_MOP / ICON_EGG have no match in that atlas; presentation falls back to world_marks atlas_icon.
const BARK_ICON_RECT := {
	ICON_APPLE: Rect2(3, 1, 26, 31),
	ICON_SPONGE: Rect2(0, 64, 32, 32),
	ICON_BALL: Rect2(2, 100, 26, 26),
	ICON_TUB: Rect2(0, 192, 28, 30),
	ICON_ROCK: Rect2(0, 416, 32, 32),
	ICON_FIRE: Rect2(0, 544, 32, 32),
	ICON_ROUND: Rect2(0, 608, 32, 32),
	ICON_ORE: Rect2(113, 673, 31, 29),
	ICON_FLOWER: Rect2(196, 673, 28, 32),
}

## Resource path to the bark icon texture atlas.
const BARK_ICON_ATLAS := "res://resources/ui/text_sprites_new.png"

## HQ toolbar glyphs sliced from Sprites-Icons. Missing keys fall back to the 16px atlas.
const MENU_ICON := {
	ICON_APPLE: "res://resources/ui/icons/apple.png",
	ICON_BALL: "res://resources/ui/icons/ball.png",
	ICON_AXE: "res://resources/ui/icons/axe.png",
	ICON_HAMMER: "res://resources/ui/icons/hammer.png",
	ICON_SPONGE: "res://resources/ui/icons/sponge.png",
	ICON_PICK: "res://resources/ui/icons/pick.png",
	ICON_BUG: "res://resources/ui/icons/bug.png",
	ICON_SAW: "res://resources/ui/icons/saw.png",
	ICON_GRAB: "res://resources/ui/icons/grab.png",
	ICON_MOP: "res://resources/ui/icons/mop.png",
	ICON_SWARM: "res://resources/ui/icons/swarm.png",
	ICON_NUKE: "res://resources/ui/icons/nuke.png",
	ICON_APPLE_TREE: "res://resources/ui/icons/apple_tree.png",
	ICON_TUB: "res://resources/ui/icons/tub.png",
	ICON_ROUND: "res://resources/ui/icons/round.png",
	ICON_DWELL: "res://resources/ui/icons/dwell.png",
	ICON_FANCY: "res://resources/ui/icons/fancy.png",
	ICON_MINE: "res://resources/ui/icons/mine.png",
	ICON_MINE2: "res://resources/ui/icons/mine2.png",
	ICON_FACTORY: "res://resources/ui/icons/factory.png",
	ICON_FACTORY2: "res://resources/ui/icons/factory2.png",
	ICON_THEATRE: "res://resources/ui/icons/theatre.png",
	ICON_MARKET: "res://resources/ui/icons/market.png",
	ICON_FLOWER: "res://resources/ui/icons/flower.png",
	ICON_STATUE: "res://resources/ui/icons/statue.png",
	ICON_WOOD_STATUE: "res://resources/ui/icons/wood_statue.png",
	ICON_FIRE: "res://resources/ui/icons/fire.png",
}

## Resolves a catalog icon index to an optional HQ PNG toolbar path.
static func menu_icon_path(icon: int) -> String:
	return str(MENU_ICON.get(icon, ""))

## Cosmetic body tint palette colors for thronglet variants.
const TINTS := [
	Color(1.0, 0.86, 0.28),
	Color(0.98, 0.78, 0.2),
	Color(1.0, 0.92, 0.45),
	Color(0.72, 0.88, 0.38),
	Color(0.55, 0.74, 0.95),
	Color(0.95, 0.7, 0.32),
	Color(0.72, 0.42, 0.92),
	Color(0.42, 0.48, 0.58),
]

## Tint index assigned when a thronglet adapts to the environment.
const TINT_ADAPT := 6
## Tint index used for numb or shocked emotional states.
const TINT_NUMB := 7

## Unlock keys that open a collective gaze talk instead of a toast.
const UNLOCK_TALK := {
	"axe": "unlock_axe",
	"hammer": "unlock_hammer",
	"bathtub": "unlock_bathtub",
	"apple_tree": "unlock_apple_tree",
	"roundabout": "unlock_roundabout",
	"market": "unlock_market",
	"pickaxe": "unlock_pickaxe",
	"mine": "unlock_mine",
	"dwelling": "unlock_dwelling",
	"factory": "unlock_factory",
	"chainsaw": "unlock_chainsaw",
	"theatre": "unlock_theatre",
	"factory2": "unlock_factory2",
	"mine2": "unlock_mine2",
	"fancy": "unlock_fancy",
	"bug": "unlock_bug",
	"grabber": "unlock_grabber",
	"mop": "unlock_mop",
	"tnt": "unlock_tnt",
	"nuke": "unlock_nuke",
	"swarm": "unlock_swarm",
}

## Toolbar metadata rows mapping tool ids to labels, icons, and hints.
const TOOL_INFO := [
	{"tool": TOOL_EYE, "label": "", "icon": -1, "hint": ""},
	{"tool": TOOL_APPLE, "unlock": "apple", "label": "MANZANA", "icon": ICON_APPLE, "hint": "SUELTA UNA MANZANA. SE LA COMEN Y DESAPARECE."},
	{"tool": TOOL_BALL, "unlock": "ball", "label": "BALON", "icon": ICON_BALL, "hint": "EL BALON ENTRETIENE A POCOS A LA VEZ."},
	{"tool": TOOL_SPONGE, "unlock": "sponge", "label": "ESPONJA", "icon": ICON_SPONGE, "hint": "FROTA PARA LAVAR A VARIOS A LA VEZ. PARA AL 100%."},
	{"tool": TOOL_AXE, "unlock": "axe", "label": "HACHA", "icon": ICON_AXE, "hint": "MANTEN SOBRE UN ARBOL. CARGA Y TALA. MATA MULTIS CERCA."},
	{"tool": TOOL_HAMMER, "unlock": "hammer", "label": "MARTILLO", "icon": ICON_HAMMER, "hint": "MANTEN SOBRE TOCON, ROCA O ESTRUCTURA. CARGA Y PICA."},
	{"tool": TOOL_BUG, "unlock": "bug", "label": "BICHO", "icon": ICON_BUG, "hint": "DESUELLA A UNO, VIVO O MUERTO, Y DEJA HUESO."},
	{"tool": TOOL_PICK, "unlock": "pickaxe", "label": "PICO", "icon": ICON_PICK, "hint": "MANTEN: CARGA Y ROMPE ROCAS Y TOCONES DEL ÁREA. NO MATA MULTIS."},
	{"tool": TOOL_SAW, "unlock": "chainsaw", "label": "MOTOSIERRA", "icon": ICON_SAW, "hint": "MANTEN: VE EL ÁREA, CARGA Y TALA TODO. MATA MULTIS."},
	{"tool": TOOL_GRAB, "unlock": "grabber", "label": "MANO", "icon": ICON_GRAB, "hint": "MANTEN: CARGA, JUNTA LO DEL SUELO Y MUEVELO. AL SOLTAR SE ESPARCE."},
	{"tool": TOOL_MOP, "unlock": "mop", "label": "FREGONA", "icon": ICON_MOP, "hint": "LIMPIA SUELO MORADO Y THRONGLETS EN UN RADIO."},
	{"tool": TOOL_SWARM, "unlock": "swarm", "label": "ENJAMBRE", "icon": ICON_SWARM, "hint": "DESUELLA EN UN RADIO."},
	{"tool": TOOL_TNT, "unlock": "tnt", "label": "TNT", "icon": ICON_TNT, "hint": "COLOCA UNA CARGA. PULSALA PARA VOLAR ESCOMBROS."},
	{"tool": TOOL_NUKE, "unlock": "nuke", "label": "TERMAL", "icon": ICON_NUKE, "hint": "LIMPIA EL SECTOR. LA PARTIDA SIGUE."},
]

## Placement metadata for buildings: unlock key, wood cost, label, and icon.
const BUILD_INFO := {
	BLD_APPLE: {"unlock": "apple_tree", "wood": 0, "label": "MANZANO", "icon": ICON_APPLE_TREE},
	BLD_TUB: {"unlock": "bathtub", "wood": 0, "label": "BANERA", "icon": ICON_TUB},
	BLD_ROUND: {"unlock": "roundabout", "wood": 0, "label": "TIOVIVO", "icon": ICON_ROUND},
	BLD_DWELL: {"unlock": "dwelling", "wood": 0, "label": "VIVIENDA", "icon": ICON_DWELL},
	BLD_FANCY: {"unlock": "fancy", "wood": 3, "label": "VIVIENDA DE LUJO", "icon": ICON_FANCY},
	BLD_MINE: {"unlock": "mine", "wood": 0, "label": "MINA", "icon": ICON_MINE},
	BLD_MINE2: {"unlock": "mine2", "wood": 3, "label": "MINA II", "icon": ICON_MINE2},
	BLD_FACTORY: {"unlock": "factory", "wood": 0, "label": "FABRICA", "icon": ICON_FACTORY},
	BLD_FACTORY2: {"unlock": "factory2", "wood": 4, "label": "FABRICA II", "icon": ICON_FACTORY2},
	BLD_THEATRE: {"unlock": "theatre", "wood": 0, "label": "TEATRO", "icon": ICON_THEATRE},
	BLD_MARKET: {"unlock": "market", "wood": 0, "label": "MERCADO", "icon": ICON_MARKET},
	BLD_FLOWER: {"unlock": "flower", "wood": 0, "label": "FLOR", "icon": ICON_FLOWER},
	BLD_STATUE: {"unlock": "sculpture", "wood": 0, "label": "ESCULTURA", "icon": ICON_STATUE},
	BLD_WOOD: {"unlock": "sculpture", "wood": 0, "label": "TALLA", "icon": ICON_WOOD_STATUE},
}

## Tiles the sprite stands on. Measured against the thronglet (18px) and the rock
## (13px): one tile is the 32px diamond. The sprite is drawn at the pad center.
static func footprint_for_building(kind: int) -> Vector2i:
	match kind:
		BLD_TUB:
			return Vector2i(1, 2)
		BLD_MINE:
			return Vector2i(6, 5)
		BLD_MINE2:
			return Vector2i(5, 6)
		BLD_FACTORY, BLD_FACTORY2:
			return Vector2i(4, 4)
		BLD_THEATRE:
			return Vector2i(4, 6)
		BLD_MARKET:
			return Vector2i(5, 4)
		BLD_ROUND:
			return Vector2i(2, 2)
		BLD_DWELL, BLD_FANCY:
			return Vector2i(3, 3)
		_:
			return Vector2i(1, 1)

## World ellipse axes for thronglet approach / enter. Centered on the footprint mid.
static func building_reach(kind: int) -> Vector2:
	match kind:
		BLD_APPLE:
			return Vector2(10.0, 10.0)
	var size := footprint_for_building(kind)
	var pad := 10.0
	match kind:
		BLD_ROUND:
			pad = 8.0
		BLD_THEATRE:
			pad = 14.0
		BLD_MINE, BLD_MINE2:
			pad = 12.0
		BLD_TUB, BLD_FLOWER, BLD_STATUE, BLD_WOOD:
			pad = 10.0
		_:
			pad = 10.0
	return Vector2(
		float(size.x) * float(TILE) * 0.5 + pad,
		float(size.y) * float(TILE) * 0.5 + pad
	)

## Iso tile footprint size for large world feature props.
static func footprint_for_feature(kind: int) -> Vector2i:
	match kind:
		FEAT_NODE, FEAT_MNODE:
			return Vector2i(4, 4)
		FEAT_SUPER:
			return Vector2i(4, 4)
		FEAT_GLITCH_HOUSE:
			return Vector2i(3, 3)
		_:
			return Vector2i(1, 1)


## Presentation scale multiplier for building sprites.
static func building_sprite_scale(kind: int) -> float:
	match kind:
		BLD_TUB:
			return TUB_SPRITE_SCALE
		BLD_ROUND:
			return ROUND_SPRITE_SCALE
		BLD_FLOWER:
			return FLOWER_SPRITE_SCALE
		BLD_STATUE, BLD_WOOD:
			return 1.03
		_:
			return 1.0


## Presentation scale multiplier for feature props with ore variants.
static func feature_sprite_scale(kind: int, ore: int = 0) -> float:
	match kind:
		FEAT_NODE, FEAT_MNODE:
			return NODE_SPRITE_SCALE
		FEAT_SUPER:
			return SUPER_SPRITE_SCALE
		FEAT_FLOWER:
			return FLOWER_SPRITE_SCALE
		FEAT_ROCK:
			return ROCK_ORE_SPRITE_SCALE if ore == 1 else ROCK_SPRITE_SCALE
		FEAT_ORE_MEGA, FEAT_ORE_SUPER, FEAT_ORE_ULTRA:
			return ORE_CLUSTER_SPRITE_SCALE
		FEAT_CURER:
			return CURER_SPRITE_SCALE
		FEAT_COSMETIC:
			return COSMETIC_SPRITE_SCALE
		FEAT_COSMETIC_BAD:
			return COSMETIC_BAD_SPRITE_SCALE
		_:
			return 1.0


## Presentation scale multiplier for loose ground items.
static func item_sprite_scale(kind: int) -> float:
	match kind:
		ITEM_ORE:
			return ORE_SPRITE_SCALE
		ITEM_EGG:
			return EGG_SPRITE_SCALE
		ITEM_BALL:
			return BALL_SPRITE_SCALE
		ITEM_WOOD:
			return WOOD_SPRITE_SCALE
		ITEM_BONE:
			return BONE_SPRITE_SCALE
		ITEM_TNT:
			return TNT_SPRITE_SCALE
		ITEM_APPLE:
			return APPLE_SPRITE_SCALE
		_:
			return 1.0


## World sprite nudge applied when drawing idle buildings.
static func building_draw_off(kind: int) -> Vector2:
	match kind:
		BLD_TUB:
			return Vector2(1.0, 2.0)
		BLD_ROUND, BLD_FLOWER:
			return Vector2(4.0, 4.0)
		BLD_FACTORY, BLD_FACTORY2:
			return Vector2(-14.0, -14.0)
		BLD_THEATRE:
			return Vector2(-12.0, -12.0)
		BLD_MARKET:
			return Vector2(-12.0, -12.0)
		_:
			return Vector2.ZERO


## Extra world offset for occupied/active/goo building sprites.
static func active_building_draw_off(kind: int) -> Vector2:
	match kind:
		BLD_THEATRE:
			return Vector2(0.5, -0.5)
		BLD_FACTORY, BLD_FACTORY2:
			return Vector2(-14.0, -14.0)
		_:
			return Vector2.ZERO


## Whether a building kind shows an occupied/active visual state.
static func building_has_active(kind: int) -> bool:
	return (
		kind == BLD_DWELL or kind == BLD_FANCY or kind == BLD_THEATRE
		or kind == BLD_MINE or kind == BLD_MINE2
		or kind == BLD_FACTORY or kind == BLD_FACTORY2
	)


## Whether a building kind can accumulate pollution goo overlays.
static func building_has_goo(kind: int) -> bool:
	return (
		kind == BLD_DWELL or kind == BLD_FANCY or kind == BLD_THEATRE
		or kind == BLD_MINE or kind == BLD_MINE2
		or kind == BLD_FACTORY or kind == BLD_FACTORY2
	)


## World sprite nudge for features including ore and glitch variants.
static func feature_draw_off(kind: int, ore: int = 0) -> Vector2:
	match kind:
		FEAT_STUMP, FEAT_MSTUMP:
			return Vector2(-4.0, -4.0)
		FEAT_ROCK:
			return Vector2(1.0, 1.0) if ore == 1 else Vector2(2.0, 2.0)
		FEAT_MONOLITH:
			return Vector2(4.0, 4.0)
		FEAT_COSMETIC:
			return Vector2(1.0, -1.0)
		FEAT_COSMETIC_BAD:
			return Vector2(-2.0, 0.0)
		FEAT_GLITCH_TREE:
			match ore:
				0:
					return Vector2(4.0, 4.0)
				1:
					return Vector2(6.0, 4.0)
				2:
					return Vector2(7.0, 7.0)
				3:
					return Vector2(3.0, 3.0)
				4:
					return Vector2(3.0, 5.0)
				_:
					return Vector2.ZERO
		FEAT_GLITCH_HOUSE:
			return Vector2(22.0, 25.0)
		_:
			return Vector2.ZERO


## World sprite nudge for loose items such as apples and TNT.
static func item_draw_off(kind: int) -> Vector2:
	match kind:
		ITEM_APPLE:
			return Vector2(1.0, 1.0)
		ITEM_BONE:
			return Vector2(1.0, 1.0)
		ITEM_TNT:
			return Vector2(2.0, 2.0)
		_:
			return Vector2.ZERO

## World offset from the snap cell to the center of the pad. 1x1 stays put.
static func footprint_center(size: Vector2i) -> Vector2:
	var ox0 := -((size.x - 1) >> 1)
	var oy0 := -((size.y - 1) >> 1)
	var cx := float(ox0) + float(size.x - 1) * 0.5
	var cy := float(oy0) + float(size.y - 1) * 0.5
	return Vector2(cx, cy) * float(TILE)

## List of tile offsets occupied by a rectangular footprint.
static func footprint_offsets(size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var ox0 := -((size.x - 1) >> 1)
	var oy0 := -((size.y - 1) >> 1)
	for oy in size.y:
		for ox in size.x:
			out.append(Vector2i(ox0 + ox, oy0 + oy))
	return out

## Converts an iso cell coordinate to world-space center.
static func cell_world(cell: Vector2i) -> Vector2:
	var half := float(TILE) * 0.5
	return Vector2(float(cell.x) * float(TILE) + half, float(cell.y) * float(TILE) + half)

## Gem shop price table for catalog unlock purchases.
const MARKET := {
	"pickaxe": {"cost": 15, "label": "PICO"},
	"mine": {"cost": 50, "label": "MINA"},
	"dwelling": {"cost": 200, "label": "VIVIENDA"},
	"factory": {"cost": 200, "label": "FABRICA"},
	"chainsaw": {"cost": 400, "label": "MOTOSIERRA"},
	"theatre": {"cost": 1000, "label": "TEATRO"},
	"factory2": {"cost": 5000, "label": "FABRICA II"},
	"mine2": {"cost": 120000, "label": "MINA II"},
	"fancy": {"cost": 200000, "label": "VIVIENDA DE LUJO"},
}

## Talk events point at DialogueBook trees. allow gates confirm actions by final choice index.
const GAZE := {
	"first_born": {"kind": "reflect", "tree": "CH01_S03_010HELLO", "allow": [0, 1, 2]},
	"unlock_axe": {"kind": "reflect", "tree": "", "allow": [0, 1, 2]},
	"unlock_hammer": {"kind": "reflect", "tree": "CH02_SEE_101BREAK", "allow": [0, 1, 2]},
	"ambient": {"kind": "reflect", "tree": "CH01.RECAP", "allow": [0, 1, 2]},
	"unlock_bathtub": {"kind": "reflect", "tree": "CH02_SEE_117ENCOURA", "allow": [0, 1, 2]},
	"unlock_apple_tree": {"kind": "reflect", "tree": "CH02_SEE_201TREES", "allow": [0, 1, 2]},
	"unlock_roundabout": {"kind": "reflect", "tree": "CH02_SEE_104RNDABT", "allow": [0, 1, 2]},
	"unlock_market": {"kind": "reflect", "tree": "CH02_SEE_103MARKET", "allow": [0, 1, 2]},
	"unlock_pickaxe": {"kind": "reflect", "tree": "CH02_SEE_105PICKAXE", "allow": [0, 1, 2]},
	"unlock_mine": {"kind": "reflect", "tree": "CH02_FTUE_ABOUTMINES", "allow": [0, 1, 2]},
	"unlock_dwelling": {"kind": "reflect", "tree": "CH02_SEE_102DWELL", "allow": [0, 1, 2]},
	"unlock_factory": {"kind": "reflect", "tree": "CH02_SEE_107FACTORY", "allow": [0, 1, 2]},
	"unlock_chainsaw": {"kind": "reflect", "tree": "CH02_SEE_109CHAINSA", "allow": [0, 1, 2]},
	"unlock_theatre": {"kind": "reflect", "tree": "CH02_SEE_112THEATRE", "allow": [0, 1, 2]},
	"unlock_factory2": {"kind": "reflect", "tree": "CH02_SEE_108FACTORY", "allow": [0, 1, 2]},
	"unlock_mine2": {"kind": "reflect", "tree": "CH02_SEE_120MINE2", "allow": [0, 1, 2]},
	"unlock_fancy": {"kind": "reflect", "tree": "CH02_SEE_102DWELL", "allow": [0, 1, 2]},
	"unlock_bug": {"kind": "reflect", "tree": "CH02_FIRSTBUGUS", "allow": [0, 1, 2]},
	"unlock_grabber": {"kind": "reflect", "tree": "CH02_SEE_119GRAB", "allow": [0, 1, 2]},
	"unlock_mop": {"kind": "reflect", "tree": "CH02_SEE_116MOP", "allow": [0, 1, 2]},
	"unlock_tnt": {"kind": "reflect", "tree": "CH02_S04_010TNT", "allow": [0, 1, 2]},
	"unlock_nuke": {"kind": "reflect", "tree": "CH02_ITEM_NUKEUNLOCK", "allow": [0, 1, 2]},
	"unlock_swarm": {"kind": "reflect", "tree": "CH02_SEE_600BONES", "allow": [0, 1, 2]},
	"neglect": {"kind": "reflect", "tree": "CH02_SEE_700DEATH", "allow": [0, 1, 2]},
	"tool": {"kind": "reflect", "tree": "CH01_S07_030CARELES", "allow": [0, 1, 2]},
	"bug": {"kind": "confirm", "tree": "confirm_bug", "allow": [0, 1]},
	"bones": {"kind": "reflect", "tree": "CH01_S07_010BONES", "allow": [0, 1, 2]},
	"goo": {"kind": "reflect", "tree": "CH02_SEE_115POLLUTE", "allow": [0, 1, 2]},
	"burn": {"kind": "confirm", "tree": "confirm_burn", "allow": [0, 1]},
	"nuke": {"kind": "confirm", "tree": "confirm_nuke", "allow": [0, 1]},
	"learn_self": {"kind": "reflect", "tree": "CH02_S03_010INT1", "allow": [0, 1, 2]},
	"what_is_care": {"kind": "reflect", "tree": "CH01_S06_WHATISLOVE", "allow": [0, 1, 2]},
	"work_life": {"kind": "reflect", "tree": "CH02_SEE_300WORKLIF", "allow": [0, 1, 2]},
	"monolith_appear": {"kind": "reflect", "tree": "", "allow": [0]},
	"act3_maw": {"kind": "reflect", "tree": "ACT3_S020_GAPINGMAW", "allow": [0, 1, 2]},
}

## Maps a world feature kind (and ore tier) to a toolbar atlas icon.
static func icon_for_feature(kind: int, ore: int) -> int:
	if kind == FEAT_TREE:
		return ICON_TREE
	if kind == FEAT_STUMP:
		return ICON_STUMP
	if kind == FEAT_ROCK:
		return ICON_ORE_ROCK if ore > 0 else ICON_ROCK
	if kind == FEAT_NODE:
		return ICON_NODE
	if kind == FEAT_SUPER:
		return ICON_SUPER
	if kind == FEAT_FLOWER:
		return ICON_FLOWER
	if kind == FEAT_MONOLITH:
		return ICON_MONOLITH
	if kind == FEAT_BIGROCK:
		return ICON_BIGROCK
	if kind == FEAT_COSMETIC:
		return ICON_COSMETIC
	if kind == FEAT_COSMETIC_BAD:
		return ICON_COSMETIC_BAD
	if kind == FEAT_ORE_MEGA:
		return ICON_ORE_MEGA
	if kind == FEAT_ORE_SUPER:
		return ICON_ORE_SUPER
	if kind == FEAT_ORE_ULTRA:
		return ICON_ORE_ULTRA
	if kind == FEAT_FIRE:
		return ICON_FIRE
	if kind == FEAT_TOTEM:
		return ICON_TOTEM
	if kind == FEAT_CURER:
		return ICON_CURER
	if kind == FEAT_MSTUMP:
		return ICON_MSTUMP
	if kind == FEAT_MNODE:
		return ICON_MNODE
	return ICON_ROCK

## Maps a loose item kind to its HUD and world icon index.
static func icon_for_item(kind: int) -> int:
	if kind == ITEM_APPLE:
		return ICON_APPLE
	if kind == ITEM_BALL:
		return ICON_BALL
	if kind == ITEM_WOOD:
		return ICON_WOOD
	if kind == ITEM_BONE:
		return ICON_BONE
	if kind == ITEM_ORE:
		return ICON_ORE
	if kind == ITEM_TNT:
		return ICON_TNT
	if kind == ITEM_EGG:
		return ICON_EGG
	return ICON_APPLE

## Maps a building kind to its placement and UI icon index.
static func icon_for_building(kind: int) -> int:
	if BUILD_INFO.has(kind):
		return int(BUILD_INFO[kind].icon)
	return ICON_MARKET

## Returns whether a feature kind blocks walking on its cells.
static func feature_blocks(kind: int) -> bool:
	return kind == FEAT_TREE or kind == FEAT_ROCK or kind == FEAT_BIGROCK or kind == FEAT_NODE or kind == FEAT_SUPER or kind == FEAT_MNODE or kind == FEAT_COSMETIC or kind == FEAT_COSMETIC_BAD or kind == FEAT_ORE_MEGA or kind == FEAT_ORE_SUPER or kind == FEAT_ORE_ULTRA or kind == FEAT_MONOLITH or kind == FEAT_TOTEM

## Returns whether a placed building occupies blocking footprint cells.
static func building_blocks(kind: int) -> bool:
	# Mine footprints are walkable ground pads; they still occupy cells for placement.
	return kind == BLD_TUB or kind == BLD_APPLE or kind == BLD_ROUND or kind == BLD_DWELL or kind == BLD_FANCY or kind == BLD_FACTORY or kind == BLD_FACTORY2 or kind == BLD_THEATRE or kind == BLD_MARKET or kind == BLD_FLOWER or kind == BLD_STATUE or kind == BLD_WOOD

## Returns whether a terrain tile id is impassable for pathing.
static func tile_blocks(tile: int) -> bool:
	return tile == TILE_WATER or tile == TILE_MOUNTAIN or tile == TILE_RUBBLE or tile == TILE_FOG or tile == TILE_VOID

## Snaps world X/Y to the center of the nearest iso tile.
static func snap_world(x: float, y: float) -> Vector2:
	var size := float(TILE)
	var half := size * 0.5
	return Vector2(floor(x / size) * size + half, floor(y / size) * size + half)

## Vector2 wrapper around snap_world for cursor placement.
static func snap_vec(pos: Vector2) -> Vector2:
	return snap_world(pos.x, pos.y)

## Whether an item kind uses grid snapping instead of free cursor drop.
static func item_snaps_grid(kind: int) -> bool:
	# Care drops (apple/ball/egg) keep free cursor coords like the ball.
	return kind != ITEM_BALL and kind != ITEM_EGG and kind != ITEM_APPLE
