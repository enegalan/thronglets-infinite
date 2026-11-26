extends Node

# Colony simulation.

const DialogueBook := preload("res://scripts/data/dialogue/dialogue_book.gd")
const ProgressionManager := preload("res://scripts/core/sim/progression_manager.gd")
const ProgressionCatalog := preload("res://scripts/data/progression_catalog.gd")
const TiovivoLabTune := preload("res://scripts/data/tune/tiovivo_lab_tune.gd")
const SaveSystemScript := preload("res://scripts/core/sim/save_system.gd")
const IslandGenScript := preload("res://scripts/core/sim/island_gen.gd")
const SimHarnessScript := preload("res://scripts/core/sim/harness.gd")
const SimPlayerToolsScript := preload("res://scripts/core/sim/player_tools.gd")
const SimDialogueScript := preload("res://scripts/core/sim/dialogue.gd")
const SimBuildingSimScript := preload("res://scripts/core/sim/building_sim.gd")
const SimWorldTickScript := preload("res://scripts/core/sim/world_tick.gd")
const SimWorldEntitiesScript := preload("res://scripts/core/sim/world_entities.gd")
const SimCollisionScript := preload("res://scripts/core/sim/collision.gd")
const SimSpatialScript := preload("res://scripts/core/sim/spatial.gd")
const SimPathsScript := preload("res://scripts/core/sim/paths.gd")
const SimAgentMoveScript := preload("res://scripts/core/sim/agent_move.gd")
const SimAgentTickScript := preload("res://scripts/core/sim/agent_tick.gd")

## Per-second drain on the fed need while a thronglet is alive.
const DECAY_FED := 0.24
## Per-second drain on the amusement need.
const DECAY_FUN := 0.14
## Per-second drain on the cleanliness need.
const DECAY_CLEAN := 0.16
## Default walking speed in world units per second.
const MOVE_SPEED := 26.0
## Maximum cells expanded in one pathfinding query.
const PATH_BFS_MAX := 256
## Wellness time required before mitosis can begin.
const MITOSIS_CHARGE := 6.0
## Length of the mitosis split presentation.
const MITOSIS_ANIM := 0.45
## Normalized split timeline when the child agent is spawned.
const MITOSIS_SPLIT_ALONG := 0.72
## Spawn separation between parent and child during mitosis.
const MITOSIS_OFFSET := 12.0
## Delay after hunger reaches zero before starvation death.
const STARVE_GRACE := 30.0
## Population milestone before the opening egg may hatch.
const EGG_NEED := 4
## Drop height for the tutorial egg prop.
const EGG_FALL := 140.0
## Lifetime of an unattended ball item before despawn.
const BALL_LIFE := 60.0
## Lifetime of a corpse pile before cleanup.
const CORPSE_LIFE := 60.0
## The ring art is eight wedges: a time meter for one ore→energy cycle, not stock.
const FACTORY_WEDGES := 8
## Duration of one Mk I factory smelt cycle.
const FACTORY_PROCESS_TIME := 8.0
## Duration of one Mk II factory smelt cycle.
const FACTORY_PROCESS_TIME2 := 4.0
## Per ore unit spent. Early original cycles paid ~+10; Mk II pays more.
const FACTORY_GEM_PAY := 10
## Gems paid per ore when a Mk II factory completes.
const FACTORY_GEM_PAY2 := 25
## Chance that a finished factory cycle spills goo (was always on; too aggressive).
const FACTORY_GOO_CHANCE := 0.25
## Mine ore stock (blue bar). Fills on a timer; diggers enter and leave with a load.
const MINE_STOCK_CAP := 5
## Maximum ore units stored in a Mk II mine.
const MINE_STOCK_CAP2 := 8
## Seconds to add one ore unit to mine stock.
const MINE_FILL_TIME := 8.0
## In-mine work time per ore haul.
const MINE_DIG_TIME := 2.5
## Grace before a queued modal talk may take focus.
const TALK_OPEN_DELAY := 1.0
## Cleanliness recovered per second in a tub.
const BATH_CLEAN_RATE := 3.0
## Clean level required before a bather may leave.
const BATH_DONE := 95.0
## Minimum soak duration before bathtub exit is allowed.
const BATH_MIN_STAY := 8.0
## Approach time before tub soaking begins.
const BATH_ENTER_T := 1.2
## Fallback fun-per-second on the carousel if lab tune is missing.
const RIDE_FUN_RATE := 2.5
## Fun threshold that ends a carousel visit.
const RIDE_DONE := 95.0
## Minimum carousel ride before exit is allowed.
const RIDE_MIN_STAY := 8.0

## Carousel lab tuning (seat count, rates) cached via TiovivoLabTune for roundabout fun.
func _ride_cfg() -> Dictionary:
	# TiovivoLabTune caches by file mtime, so this stays cheap.
	return TiovivoLabTune.carousel()

## Per-second amusement gain while a thronglet rides the carousel, from lab tune.
func _ride_fun_rate() -> float:
	return float(_ride_cfg().get("ride_fun_rate", RIDE_FUN_RATE))

## Amusement level that marks the fun need satisfied so riders may exit the roundabout.
func _ride_done_need() -> float:
	return float(_ride_cfg().get("ride_done", RIDE_DONE))

## Minimum dwell time on the carousel before fun counts as fulfilled and exit is allowed.
func _ride_min_stay_need() -> float:
	return float(_ride_cfg().get("min_stay", RIDE_MIN_STAY))
## Amusement passed to neighbors during play animations.
const PLAY_AURA_FUN := 6.0
## Amusement added when a thronglet strikes a ball.
const BALL_KICK_FUN := 8.0
## Open grass around the egg so the opening shot stays clear of trees.
const SPAWN_CLEAR := 110.0

## Automated harness is running instead of a normal player session.
var testing := false
## Pauses advancement after bootstrap for deterministic smoke captures.
var smoke_hold := false
## Samples frame cost without pacing gameplay for benchmarks.
var perf_mode := false
## Measures save/load only, without smoke-world hold.
var save_perf_mode := false
## user:// path used for the next write or read of colony state.
var save_path := ""
## Drives island shape, prop scatter, and seeded random rolls.
var world_seed := 1
## Loaded biome palette rows for special regions.
var biomes: Array = []
## Fast lookup from biome id string to biome record.
var biome_by_id := {}

## Set of progression catalog ids the player has earned.
var unlocks := {}
## Monotonic counter bumped on every grant for UI cache busting.
var unlock_serial := 0
## Recorded answers to branching ethics prompts.
var ethics: Array = []
## Helper that owns slots, autosave, and sandbox files.
var save_system: SaveSystem
## Transient Spanish toast strings shown in the HUD.
var notes: Array = []
## Sound ids to play on the next audio pump.
var sfx_queue: Array = []
## Remaining cooldown before another voice line may start.
var voice_wait := 0.0
## Active blocking UI state (talk, gaze, game over) if non-empty.
var modal := {}
## Talk ids waiting for a free moment to open.
var talk_pending := {}
## Monolith or spectacle ids lined up for forced camera beats.
var gaze_queue: Array = []
## Simulation time is halted for gaze, modal, or endgame.
var frozen := false
## Aggregate ethics score influencing rare outcomes.
var moral := 0
## Per-agent cosmetic mutation flags keyed by slot.
var mutations := {}
## Tree features already used for learn-to-talk milestones.
var talked_trees := {}
## Colony has completed the teaching-tree introduction.
var learn_talked := false

## Super-island expansion chapter is active.
var part_two := false
## Player has been shown the mountain landmark beat.
var mountain_seen := false
## Biome ids already spawned on this save.
var special_biomes := {}
## Lifetime trees felled; gates axe and pollution talks.
var trees_chopped := 0
## Stumps removed after chopping.
var stumps_cleared := 0
## Times the debug bug tool was fired.
var bug_uses := 0
## Times explosives cleared terrain or props.
var tnt_used := 0
## Live pollution piles; feeds pollution-percent unlocks.
var goo_count := 0
## Spendable gem currency in the colony wallet.
var gems := 0
## High-water gem balance for achievements and saves.
var gems_peak := 0
## Lifetime gems collected across the campaign.
var total_gems_earned := 0
## Cumulative colony deaths tracked for progression.
var deaths_total := 0
## Highest population ever reached on this save.
var peak := 0
## Home island growth stage controlling radius and scatter.
var land_tier := 0
## Unlimited cheats and tier sliders without slot progression.
var sandbox_mode := false
## Lowest land tier allowed in sandbox sliders.
const SANDBOX_TIER_MIN := 0
## Highest land tier allowed in sandbox sliders.
const SANDBOX_TIER_MAX := 16
## Default land tier when opening a fresh sandbox.
const SANDBOX_START_TIER := 2
## Gem balance granted in sandbox for free building.
const SANDBOX_GEMS := 99999
## Re-entrancy guard while island geometry is being rebuilt.
var _shaping_island := false
## Story glitch spectacle has already triggered once.
var glitch_seen := false
## Countdown or hold timer during the glitch presentation.
var glitch_t := 0.0
## Saved camera framing to restore after a gaze sequence.
var gaze_home := {}
## Short ambient bark events awaiting playback.
var barks: Array = []
## Ground wear intensity sampled per world cell.
var wear := {}
## Maps worn cells back to the agent or tool that caused them.
var wear_from := {}
## CLI flag to render marketing stills instead of playing.
var shot_mode := false
## Capture pass includes particle and pop effects.
var shot_fx := false
## Capture pass stages thronglets carrying haulables.
var shot_carry := false
## Capture pass stages the carousel scene.
var shot_round := false
## Capture pass stages apple-tree food loop.
var shot_apple := false
## Capture pass exaggerates need meters for readability.
var shot_needs := false
## Capture pass cycles showcase animation states.
var shot_anims := false
## Capture pass highlights dirt and cleaning.
var shot_dirt := false
## Capture pass highlights ball play.
var shot_ball := false
## Capture pass highlights sponge scrubbing.
var shot_wash := false
## Capture pass highlights goo on buildings.
var shot_bld_goo := false
## Capture pass highlights violent death residue.
var shot_blood := false
## World point the marketing camera orbits.
var shot_focus := Vector2(256, 256)
## Radius around the focus point included in still framing.
var shot_span := 210.0
## Agent slot staged as hero for stills, or -1 for auto.
var shot_throng := -1
## Building id staged for factory stills, or -1.
var shot_factory := -1
## Waypoint used to pose walkers in still shots.
var shot_path := Vector2(256, 256)
## Counter driving low-rate ambient sound variety.
var ambient_n := 0
## Clean level below which ground wear decals accumulate.
const WEAR_NEED := 120
## Discrete wear intensity levels painted on tiles.
const WEAR_STEPS := 4
## Current count of non-dead thronglet agents.
var living := 0
## Flags which monolith tiers already exist in the world.
var monolith_tier_spawned := {}

## Chunk keys the player has uncovered on the map.
var revealed := {}
## Terrain tile buffers keyed by chunk coordinate string.
var chunks := {}
## Chunk keys needing a client mesh or texture refresh.
var dirty_chunks: Array = []
## Version stamp bumped when terrain painting changes globally.
var paint_epoch := 0
## Bumped when features are added/removed so presentation can rebuild static prop meshes.
var feat_mesh_epoch := 0
## Partitioned seek lists need rebuilding after entity churn.
var lists_dirty := false

## Live world props (trees, rocks, nodes, monoliths).
var features: Array = []
## Feature records indexed by stable id.
var feature_by_id := {}
## Grid cell to feature id for O(1) spatial queries.
var feature_cell := {}
## Allocator for new feature entity ids.
var next_feature_id := 1
## Deferred tree sprouts waiting for valid ground.
var tree_seeds: Array = []

## Loose world items (food, ore, balls, corpses).
var items: Array = []
## Item records indexed by stable id.
var item_by_id := {}
## Allocator for new item entity ids.
var next_item_id := 1
## Agent slot currently controlled by direct player pick.
var hand_id := -1
## Catalog kind string for the object in the cursor hand.
var held_kind := ""
## Entity id attached to the hand, or -1 when empty.
var held_ref := -1
## Hand anchor X in world space.
var held_x := 0.0
## Hand anchor Y in world space.
var held_y := 0.0
## Batch harvest of item ids collected by one scoop tool action.
var scoop_item_ids: Array = []
## Corpses queued for removal by the same scoop pass.
var scoop_dead_ids: Array = []
## True after a successful load or new game has begun.
var session_live := false
## Display name entered for the colony founder.
var player_name := ""
## Index into the guided tutorial step sequence, or -1 when done.
var tutorial_i := -1
## Population readout is hidden until the naming beat completes.
var count_unknown := false
## Custom alphabet rules loaded for thronglet naming.
var _name_rules := false
## Allowed characters string for generated names.
var _name_chars := ""
## Forbidden substrings rejected during name entry.
var _name_bans: PackedStringArray = PackedStringArray()
## Item id of the sponge currently in the cleaning hand.
var sponge_id := -1
## Seconds the sponge has been held continuously while scrubbing.
var sponge_hold := 0.0
## Thronglets cleaned while scrubbing; sparkle+Happy fire on mouse/kit release.
var wash_fx_pending: Array = []

## Placed structures with sim state (homes, mines, baths, etc.).
var buildings: Array = []
## Building records indexed by stable id.
var building_by_id := {}
## Grid cell to building id for footprint queries.
var building_cell := {}
## Allocator for new building entity ids.
var next_building_id := 1

## Allocated thronglet slots in the structure-of-arrays.
var slot_count := 0
## Selected tool or kit id in the player UI.
var cursor := 0
## Aggregate colony mood label driving HUD face art.
var mood_face := "base"
## Smoothed baseline mood sample for HUD blending.
var _mood_base := 0
## Smoothed happy-mood contribution.
var _mood_happy := 0
## Smoothed distressed-mood contribution.
var _mood_cry := 0
## Smoothed suspicious-mood contribution.
var _mood_sus := 0
## Smoothed frantic-mood contribution.
var _mood_freak := 0
## Simulation frame counter for staggered cheap checks.
var frame_i := 0
## World rectangle currently visible to the client camera.
var view_rect := Rect2()
## Population cap warning has already been shown to the player.
var cap_told := false

## World X coordinates per thronglet slot.
var pos_x := PackedFloat32Array()
## World Y coordinates per thronglet slot.
var pos_y := PackedFloat32Array()
## Facing X per thronglet slot.
var dir_x := PackedFloat32Array()
## Facing Y per thronglet slot.
var dir_y := PackedFloat32Array()
## Hunger need level per slot.
var fed := PackedFloat32Array()
## Fun need level per slot.
var amused := PackedFloat32Array()
## Cleanliness need level per slot.
var clean := PackedFloat32Array()
## Heat comfort need level per slot.
var cool := PackedFloat32Array()
## Seconds at zero hunger before death per slot.
var starve := PackedFloat32Array()
## Timer gating eating retries per slot.
var hungry_t := PackedFloat32Array()
## Idle wander phase timer per slot.
var wander_t := PackedFloat32Array()
## Repulsion timer after bumping hazards per slot.
var avoid_t := PackedFloat32Array()
## Mitosis animation timer per slot.
var mito_t := PackedFloat32Array()
## Wellness buildup toward mitosis per slot.
var mito_charge := PackedFloat32Array()
## Hit-react wobble timer per slot.
var shake_t := PackedFloat32Array()
## Temporary boost timer per slot.
var buff_t := PackedFloat32Array()
## Shock reaction after witnessing death per slot.
var react_t := PackedFloat32Array()
## Celebration loop timer per slot.
var cheer_t := PackedFloat32Array()
## Nap animation timer per slot.
var sleep_t := PackedFloat32Array()
## Peer social beat: stand, face partner, talk or sing body clips.
var peer_t := PackedFloat32Array()
## Partner slot id during social peer beats, or -1.
var peer_of := PackedInt32Array()
## Whether the peer beat uses sing vs talk body clips per slot.
var peer_sing := PackedByteArray()
## One-shot DropProp after putting down a haul.
var drop_t := PackedFloat32Array()
## 1 = violent corpse (saw / tnt / nuke); draw Throng_Prop_Blood_A under it.
var bloody := PackedByteArray()
## High-level life state enum per slot (living, dead, etc.).
var state := PackedInt32Array()
## Carried item kind id per slot, or none.
var carry := PackedInt32Array()
## Ore units or stack count for the carried haul per slot.
var carry_value := PackedInt32Array()
## Cosmetic palette index per slot.
var tint := PackedInt32Array()
## World item id reserved for this agent's current job.
var claim := PackedInt32Array()
## Mine building id assigned to this digger, or -1.
var mine_job := PackedInt32Array()
## Active behavior act id (eat, wash, work) per slot.
var act := PackedInt32Array()
## Elapsed time within the current act per slot.
var act_t := PackedFloat32Array()
## Last simulation frame that updated AI for this slot.
var tick_stamp := PackedInt32Array()
## Floating UI feedback sprites awaiting draw.
var pops: Array = []
## Campaign save slot index, or -1 for sandbox/ephemeral.
var current_slot := -1
## Player has paused simulation time.
var paused := false
## Colony wipe state blocking normal play.
var game_over := false
## Swarm celebration window after unlock / milestone (seconds).
var celebrate_t := 0.0
## Radius to pair thronglets for talk or sing peer beats.
const PEER_R := 40.0
## Radius within which agents react to a violent death.
const REACT_KILL_R := 72.0
## Length of the death-shock reaction animation.
const REACT_DUR := 0.85
## Length of the cheer loop after local good news.
const CHEER_DUR := 0.9
## Swarm celebration window after unlocks or milestones.
const CELEBRATE_DUR := 1.4
## One ThrongA_Happy loop @ 6fps (5 frames) — matches CLEAN sparkle life.
const WASH_FX_LIFE := 5.0 / 6.0
## World units of sponge motion per frame to count as scrub (clean gain + start wash).
## Kept low: at zoom 2 a gentle rub is often < 1.0 world/frame; 2.0 never lit suds in play.
const SCRUB_STROKE_MIN := 0.35
## Length of a voluntary nap animation.
const SLEEP_DUR := 3.2
## Length of a paired social interaction.
const PEER_DUR := 2.4
## One-shot timer after placing a carried haul.
const DROP_DUR := 0.5
## Mine dig body: pickaxe swing then Twiddle wait (seconds each).
const MINE_SWING_T := 0.7
## Idle twiddle time between pickaxe swings in a mine.
const MINE_WAIT_T := 0.55
## Seconds between autosaves. A later settings screen can change this. Zero turns it off.
var autosave_interval := 60.0
## Elapsed seconds since the last autosave attempt.
var autosave_t := 0.0
## Incremented on each successful write for UI acknowledgment.
var save_pulse := 0
## Spatial hash bucket heads for thronglet slot indices.
var hash_head := PackedInt32Array()
## Spatial hash singly-linked next slot per thronglet.
var hash_next := PackedInt32Array()
## Spatial hash bucket count / cell list heads.
var hash_cell := PackedInt32Array()
## O(1) reverse links: thronglet slot -> entity id (-1 = none).
var link_tub := PackedInt32Array()
## Roundabout building id bound to each rider slot.
var link_ride := PackedInt32Array()
## Guest seat building link per slot for theatres or rides.
var link_guest := PackedInt32Array()
## Reserved claim target mirrored for fast invalidation.
var link_claim := PackedInt32Array()
## Ball item id a thronglet is dribbling, per slot.
var link_ball := PackedInt32Array()
## Compact list of slot indices that are currently alive.
var living_ids := PackedInt32Array()
## Inverse map from slot index to position in living_ids.
var living_at := PackedInt32Array()
## Per-slot cooldown before another ambient bark may fire.
var bark_cool := PackedFloat32Array()
## Cached penned flag (expensive probe); refreshed on the same cadence as rock bark.
var penned_flag := PackedByteArray()
## Active ground fire patches with spread state.
var fires: Array = []
## Features keyed by chunk ("cx,cy") so draw/sync only walks visible chunks.
var features_by_chunk := {}
## Cached colony walkable-cell count; invalidated when terrain/props change.
var _walk_cells_cache := -1
## Memoized answer to whether any factory exists.
var _has_factory_cache := false
## Whether the factory-exists memo is valid.
var _has_factory_known := false
## Per-cell inland (cliff) cache: depends only on tiles, not props.
var inland_cache := {}
## bid -> assigned mine workers (avoids O(living) scans in agent_tick._seek_mine).
var mine_job_n := {}
## Full AI while the colony fits — LOD budgets only above this (50k–120k scale).
const AGENT_FULL_CAP := 220
## Agents allowed to keep chasing their current goal each frame once population exceeds full AI.
const AGENT_STICKY_BUDGET := 160
## Fresh seek-job assignments permitted per frame under population LOD.
const AGENT_SEEK_BUDGET := 48
## Agents that may run the lightweight think pass per frame when the colony is huge.
const AGENT_CHEAP_BUDGET := 256
## Agents near the camera that still get full interaction and collision work per frame.
const AGENT_NEAR_BUDGET := 420
## World padding added around the view rect when classifying near-camera agents.
const AGENT_NEAR_PAD := 160.0
## Cap on neighbor slots examined while sticking to an existing target under LOD.
const AGENT_STICKY_SCAN_CAP := 4000
## Frame index when need-decay LOD scale was last computed.
var _decay_scale_frame := -1
## Population-based multiplier slowing need decay at scale.
var _decay_scale_cached := 1.0
## Last frame each slot finished a full AI tick under LOD budgets.
var _agent_done_frame := PackedInt32Array()
## Kind-partitioned live lists so seeks skip full items/buildings scans.
var items_apple: Array = []
## Live ball items for sports seek jobs.
var items_ball: Array = []
## Loose wood piles on the ground.
var items_wood: Array = []
## Bone pickups from corpses or crafting.
var items_bone: Array = []
## Ore piles dropped by miners or explosions.
var items_ore: Array = []
## Bathtub buildings eligible for wash seeks.
var blds_tub: Array = []
## Carousel buildings eligible for fun seeks.
var blds_round: Array = []
## Dwellings counted for housing and ethics hooks.
var blds_home: Array = []
## Mines accepting digger assignments.
var blds_mine: Array = []
## Theatres or show buildings for guest routing.
var blds_show: Array = []
## Generation cache for ground piles; carried resources stay O(1) via carry_*_n.
var _item_count_gen := 0
## Cached total ground items when built count is trusted.
var _item_count_built := -1
## Cached loose wood count for milestone checks.
var _item_count_wood := 0
## Cached loose bone count.
var _item_count_bone := 0
## Cached loose ore count.
var _item_count_ore := 0
## Cached counts for minor item kinds keyed by kind id.
var _item_count_other := {}
## Wood units currently held in inventory by all living agents.
var carry_wood_n := 0
## Bone units carried collectively.
var carry_bone_n := 0
## Ore units carried collectively.
var carry_ore_n := 0
## Throttle timer between duplicate milestone announcements.
var _milestone_cool := 0.0
## Number of corpse agents tracked without a full slot scan.
var dead_n := 0
## Slot indices currently in the dead state list.
var dead_ids := PackedInt32Array()
## Transient AI seek target X per slot.
var seek_x := PackedFloat32Array()
## Transient AI seek target Y per slot.
var seek_y := PackedFloat32Array()
## Time remaining on the current seek goal per slot.
var seek_t := PackedFloat32Array()

## Dedicated RNG instance for gameplay rolls.
var _rng := RandomNumberGenerator.new()
## Delegated integrator for airborne and bouncing items.
var item_physics: ItemPhysics
## Delegated helper for island growth and prop scatter.
var island_gen: IslandGen
## Delegated smoke shots and automated assertion suite.
var harness: SimHarness
## Delegated player tool actions.
var player_tools: SimPlayerTools
## Delegated talks, gaze, ethics, and milestones.
var dialogue: SimDialogue
## Delegated building visitors, mines, and factories.
var building_sim: SimBuildingSim
## Delegated per-frame world systems.
var world_tick: SimWorldTick
## Delegated entity add/remove and session bootstrap.
var world_entities: SimWorldEntities
## Delegated collision and tile helpers.
var collision: SimCollision
## Delegated spatial hash and client queries.
var spatial: SimSpatial
## Delegated ground wear and path sampling.
var paths: SimPaths
## Delegated agent locomotion.
var agent_move: SimAgentMove
## Delegated agent AI ticks.
var agent_tick: SimAgentTick


## Initializes physics, island gen, save slot, CLI modes, and bootstrap or smoke harness worlds.
func _ready() -> void:
	item_physics = ItemPhysics.new(self)
	island_gen = IslandGenScript.new(self)
	save_system = SaveSystemScript.new(self)
	harness = SimHarnessScript.new(self)
	player_tools = SimPlayerToolsScript.new(self)
	dialogue = SimDialogueScript.new(self)
	building_sim = SimBuildingSimScript.new(self)
	world_tick = SimWorldTickScript.new(self)
	world_entities = SimWorldEntitiesScript.new(self)
	collision = SimCollisionScript.new(self)
	spatial = SimSpatialScript.new(self)
	paths = SimPathsScript.new(self)
	agent_move = SimAgentMoveScript.new(self)
	agent_tick = SimAgentTickScript.new(self)
	save_path = save_system.slot_path(SaveSystem.LIVE_SLOT)
	var args := OS.get_cmdline_user_args()
	perf_mode = args.has("--perf")
	save_perf_mode = args.has("--save-perf")
	shot_mode = args.has("--shot") or args.has("--shot-fx") or args.has("--shot-carry") or args.has("--shot-round") or args.has("--shot-apple") or args.has("--shot-needs") or args.has("--shot-anims") or args.has("--shot-dirt") or args.has("--shot-ball") or args.has("--shot-wash") or args.has("--shot-bld-goo") or args.has("--shot-blood")
	var pick_zoom_repro := args.has("--pick-zoom-repro")
	testing = args.has("--smoke") or shot_mode or perf_mode or pick_zoom_repro or save_perf_mode
	if args.has("--shot-fx"):
		shot_fx = true
	if args.has("--shot-carry"):
		shot_carry = true
	if args.has("--shot-round"):
		shot_round = true
	if args.has("--shot-apple"):
		shot_apple = true
	if args.has("--shot-needs"):
		shot_needs = true
	if args.has("--shot-anims"):
		shot_anims = true
	if args.has("--shot-dirt"):
		shot_dirt = true
	if args.has("--shot-ball"):
		shot_ball = true
	if args.has("--shot-wash"):
		shot_wash = true
	if args.has("--shot-bld-goo"):
		shot_bld_goo = true
	if args.has("--shot-blood"):
		shot_blood = true
	if testing and not save_perf_mode:
		# Keep smoke/shot/perf saves inside the project so headless CI sandboxes can write.
		save_path = ProjectSettings.globalize_path("res://shots/thronglets_smoke.save")
		world_seed = 12345
		seed(world_seed)
		# Perf / pick-zoom repro must keep the sim stepping; smoke/shot freeze until harness moves.
		smoke_hold = not perf_mode and not pick_zoom_repro
	elif save_perf_mode:
		# Keep the real user:// slot path; harness loads the player's save.
		smoke_hold = false
		world_seed = 12345
		seed(world_seed)
	else:
		world_seed = randi()
	hash_head.resize(Catalog.HASH_SIZE)
	hash_head.fill(-1)
	world_entities._load_biomes()
	dialogue._init_unlocks()
	if testing and not save_perf_mode:
		world_entities._bootstrap_new()
	if testing and not perf_mode and not pick_zoom_repro and not save_perf_mode:
		_begin_smoke()


## Godot frame driver: runs one simulation step unless paused or held for smoke captures.
func _process(delta: float) -> void:
	if smoke_hold or paused:
		return
	if save_perf_mode:
		var t0 := Time.get_ticks_usec()
		_step(delta)
		set_meta("save_perf_step_ms", float(Time.get_ticks_usec() - t0) * 0.001)
		if (frame_i % 30) == 0:
			print("SAVE PERF step_parts %s" % str(get_meta("save_perf_parts", {})))
	else:
		_step(delta)


## Persists the live colony when the player closes the game outside test harnesses.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not testing and session_live and not game_over:
		save_system.save_progress()


## After one frame, runs screenshot prep scenes or the automated smoke assertion suite.
func _begin_smoke() -> void:
	await get_tree().process_frame
	if shot_mode:
		if shot_carry:
			harness._prep_shot_carry()
		elif shot_round:
			harness._prep_shot_round()
		elif shot_apple:
			harness._prep_shot_apple()
		elif shot_needs:
			harness._prep_shot_needs()
		elif shot_dirt:
			harness._prep_shot_dirt()
		elif shot_ball:
			harness._prep_shot_ball()
		elif shot_wash:
			harness._prep_shot_wash()
		elif shot_bld_goo:
			harness._prep_shot_bld_goo()
		elif shot_blood:
			harness._prep_shot_blood()
		else:
			harness._prep_shot_world()
		return
	harness._run_checks()


## Central per-frame simulation pass: world systems, agents, barks, milestones, voice, and autosave.
func _step(delta: float) -> void:
	frame_i += 1
	if frame_i > 1000000:
		frame_i = 1
	if celebrate_t > 0.0:
		celebrate_t = maxf(0.0, celebrate_t - delta)
	if sponge_hold > 0.0:
		sponge_hold = maxf(0.0, sponge_hold - delta)
		if sponge_hold <= 0.0:
			sponge_id = -1
	dialogue._tick_talk_wait(delta)
	if save_perf_mode:
		var parts := {}
		var mark := Time.get_ticks_usec()
		if not frozen:
			item_physics.tick_items(delta)
			parts["items"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			world_tick._tick_trees(delta)
			parts["trees"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			world_tick._tick_props(delta)
			parts["props"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			world_tick._tick_monoliths(delta)
			parts["mono"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			building_sim._tick_buildings(delta)
			parts["bld"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			building_sim._tick_auras(delta)
			parts["aura"] = float(Time.get_ticks_usec() - mark) * 0.001
			mark = Time.get_ticks_usec()
			agent_tick._tick_agents(delta)
			world_tick._tick_corpses(delta)
			parts["agents"] = float(Time.get_ticks_usec() - mark) * 0.001
			parts["agent_walk_ms"] = float(get_meta("_ap_walk_us", 0)) * 0.001
			parts["move_blocked_n"] = int(get_meta("_ap_move_n", 0))
			parts["walk_cells_n"] = int(get_meta("_ap_walk_cells_n", 0))
			set_meta("_ap_walk_us", 0)
			set_meta("_ap_move_n", 0)
			set_meta("_ap_walk_cells_n", 0)
			mark = Time.get_ticks_usec()
			if lists_dirty or (frame_i & 7) == 0:
				var item_n := items.size()
				var bld_n := buildings.size()
				var feat_n := features.size()
				world_entities._compact(items)
				world_entities._compact(features)
				world_entities._compact(buildings)
				lists_dirty = false
				if items.size() != item_n or buildings.size() != bld_n or features.size() != feat_n:
					world_entities._rebuild_kind_indexes()
			parts["compact"] = float(Time.get_ticks_usec() - mark) * 0.001
		elif str(modal.get("event", "")) == "monolith_appear":
			world_tick._tick_monoliths(delta, false)
		mark = Time.get_ticks_usec()
		dialogue._tick_barks(delta, not frozen)
		dialogue._tick_pops(delta, not frozen)
		_milestone_cool = maxf(0.0, _milestone_cool - delta)
		if _milestone_cool <= 0.0:
			_milestone_cool = 0.35
			dialogue._check_milestones()
		dialogue._tick_voice(delta)
		save_system.tick_autosave(delta)
		parts["tail"] = float(Time.get_ticks_usec() - mark) * 0.001
		set_meta("save_perf_parts", parts)
		return
	if not frozen:
		item_physics.tick_items(delta)
		world_tick._tick_trees(delta)
		world_tick._tick_props(delta)
		world_tick._tick_monoliths(delta)
		building_sim._tick_buildings(delta)
		building_sim._tick_auras(delta)
		agent_tick._tick_agents(delta)
		world_tick._tick_corpses(delta)
		# Compacting 3k+ feature dicts every frame was a large sync tax; only when dirty or periodically.
		if lists_dirty or (frame_i & 7) == 0:
			var item_n := items.size()
			var bld_n := buildings.size()
			var feat_n := features.size()
			world_entities._compact(items)
			world_entities._compact(features)
			world_entities._compact(buildings)
			lists_dirty = false
			if items.size() != item_n or buildings.size() != bld_n or features.size() != feat_n:
				world_entities._rebuild_kind_indexes()
	elif str(modal.get("event", "")) == "monolith_appear":
		world_tick._tick_monoliths(delta, false)
	# Keep bark and anchored pop positions on live thronglets even during gaze teleport.
	dialogue._tick_barks(delta, not frozen)
	dialogue._tick_pops(delta, not frozen)
	_milestone_cool = maxf(0.0, _milestone_cool - delta)
	if _milestone_cool <= 0.0:
		_milestone_cool = 0.35
		dialogue._check_milestones()
	dialogue._tick_voice(delta)
	save_system.tick_autosave(delta)


## Behavior act id while chewing food.
const ACT_EAT := 1
## Behavior act id while playing with props or peers.
const ACT_PLAY := 2
## Behavior act id while scrubbing with a sponge.
const ACT_WASH := 3
## Behavior act id while soaking in a tub.
const ACT_BATH := 4
## Behavior act id while working a building job.
const ACT_WORK := 5
