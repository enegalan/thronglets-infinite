extends Node2D

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const DevBench := preload("res://scripts/dev/dev_bench.gd")
const ProgressionManager := preload("res://scripts/core/progression_manager.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const UIAssets := preload("res://scripts/presentation/ui/ui_assets.gd")
const ShotCaptureScript := preload("res://scripts/dev/shot_capture.gd")
const PerfBenchScript := preload("res://scripts/dev/perf_bench.gd")
const SavePerfScript := preload("res://scripts/dev/save_perf.gd")
const PickZoomReproScript := preload("res://scripts/dev/pick_zoom_repro.gd")
const PathOverlay := preload("res://scripts/presentation/world/path_overlay.gd")
const StructureTextures := preload("res://scripts/presentation/structures/structure_textures.gd")
const ThrongAnimFrames := preload("res://scripts/presentation/anim/throng_anim_frames.gd")
const WorldBootstrap := preload("res://scripts/presentation/world/world_bootstrap.gd")
const PlacementOverlay := preload("res://scripts/presentation/overlays/placement_overlay.gd")
const WorldMarks := preload("res://scripts/presentation/hud/world_marks.gd")
const ConsoleUI := preload("res://scripts/presentation/hud/console_ui.gd")
const FocusViewport := preload("res://scripts/presentation/hud/focus_viewport.gd")
const KitToolbar := preload("res://scripts/presentation/kit/kit_toolbar.gd")
const ToolController := preload("res://scripts/presentation/tools/tool_controller.gd")
const IsoDraw := preload("res://scripts/presentation/world/iso_draw.gd")
const WorldDrawer := preload("res://scripts/presentation/world/world_drawer.gd")
const WorldActorSync := preload("res://scripts/presentation/world/world_actor_sync.gd")
const PrefsController := preload("res://scripts/presentation/prefs/prefs_controller.gd")
const BootSequence := preload("res://scripts/presentation/boot/boot_sequence.gd")
const TitleScreen := preload("res://scripts/presentation/title/title_screen.gd")
const SettingsMenu := preload("res://scripts/presentation/settings/settings_menu.gd")
const VideoLibrary := preload("res://scripts/presentation/settings/video_library.gd")
const GameFlowUI := preload("res://scripts/presentation/flow/game_flow_ui.gd")

## Active Camera2D the rig positions for the main world view.
var camera: Camera2D
## Live camera rig instance wired to tilemap, viewport, and pointer callbacks.
var cam_rig: CameraRig
## Path overlay module owning main and focus path tile layers.
var path_overlay: PathOverlay
## Structure texture cache used when drawing buildings and placement ghosts.
var structure_tex: StructureTextures
## Animation frame resolver shared by sync, focus view, and iso draw.
var anim_frames: ThrongAnimFrames
## World bootstrap module that owns chunk paint and tilemap lifecycle.
var world_boot: WorldBootstrap
## Placement overlay module for structures, charges, and debug draws.
var placement_overlay: PlacementOverlay
## World marks module for need UI, task banner hooks, and floating markers.
var world_marks_ui: WorldMarks
## Console UI module driving gaze dialogue and console input.
var console_ui: ConsoleUI
## Focus viewport module for dimmer, subviewport, and talk framing.
var focus_viewport: FocusViewport
## Kit toolbar module for tray state, rebuild, and drag helpers.
var kit_toolbar: KitToolbar
## Tool controller module bound to camera and placement callbacks.
var tool_controller: ToolController
## Iso draw module that turns sim poses into multimesh instance payloads.
var iso_draw: IsoDraw
## World drawer module that owns prop, feature, void, and crowd bands.
var world_drawer: WorldDrawer
## Actor sync module that refreshes throng, feature, and building draws.
var world_actor_sync: WorldActorSync
## Prefs controller applying CRT shader, FPS label, and audio on load.
var prefs: PrefsController
## Boot sequence instance coordinating logo, DOS, and title handoff.
var boot_seq: BootSequence
## Title screen instance hosting backdrop, HUD, and flow callbacks.
var title: TitleScreen
## Settings menu instance embedded in the title root.
var settings_menu: SettingsMenu
## Video library instance for browsing unlocked cutscenes.
var video_lib: VideoLibrary
## Game flow UI instance for pause, slots, and return-to-title.
var game_flow: GameFlowUI

## UI assets singleton used while building HUD and world chrome.
var ui_assets: UIAssets
## Screenshot harness child (only active in shot test mode).
var shot_capture: ShotCapture
## Perf bench child node (only active in perf test mode).
var perf_bench = null
## Save perf child node (only active in save-perf test mode).
var save_perf = null
## Pick/zoom repro child node (only active with CLI repro flag).
var pick_zoom_repro = null
## Media controller child handling SFX, music, birds, and fullscreen video.
var media: Node
## Primary terrain TileMapLayer painted by world bootstrap chunks.
var tilemap: TileMapLayer
## Main-world path TileMapLayer updated by the path overlay.
var pathmap: TileMapLayer
## Node2D parent for non-tilemap path decorations on the main map.
var path_root: Node2D
## Path decoration root inside the focus subviewport.
var focus_path_root: Node2D
## Focus subviewport path TileMapLayer mirroring main connectivity.
var focus_pathmap: TileMapLayer
## Legacy primary world MultiMeshInstance2D for batched iso instances.
var world: MultiMeshInstance2D
## Root Node2D stacking sky, tilemaps, multimesh bands, and sprites.
var world_layer: Node2D
## Far-view crowd MultiMeshInstance2D for distant throng LOD.
var throng_crowd: MultiMeshInstance2D
## Shared MultiMesh buffer reused by the far crowd instance.
var throng_crowd_mesh: MultiMesh
## Static feature presentation root for one-shot multimesh feature meshes.
var feat_static: Node2D
## Void backfill root hiding empty chunks behind playable land.
var void_back: Node2D
## World presentation root inside the focus subviewport.
var focus_root: Node2D
## Multimesh band pool allocated by focus viewport close-up draws.
var _focus_bands: Array = []
## Next free index when handing out focus viewport multimesh bands.
var _focus_band_cursor := 0
## Cached atlas frame index for idle far-crowd throngs.
var _crowd_default_frame := -1
## Cached atlas frame index for walking far-crowd throngs.
var _crowd_walk_frame := -1
## Cached atlas frame index for sad far-crowd throngs.
var _crowd_sad_frame := -1
## Chunk epoch when static feature multimesh was last rebuilt.
var _feat_static_epoch := -1
## Whether a static feature multimesh is currently displayed.
var _feat_static_active := false
## Previous pointer world position while the hand tool is active.
var hand_last_world := Vector2.ZERO
## Exponential moving average of hand-tool drag velocity in world space.
var hand_vel := Vector2.ZERO
## Whether hand velocity smoothing has a prior sample this grab.
var hand_vel_init := false
## Multimesh band pool for ground props in the world drawer.
var _prop_bands: Array = []
## Live monolith Sprite2D or Node2D instances keyed by feature id.
var _monoliths := {}
## Busy-state building Sprite2D overlays keyed by building id.
var _building_active_sprites := {}
## Semi-transparent Sprite2D preview while placing a structure.
var _place_ghost_sprite: Sprite2D = null
## Per-cell terrain texture cache to avoid repeat tile lookups.
var _cell_tex_cache := {}
## Per-cell dirt tint factors synced with throng cleanliness visuals.
var _cell_dirt_cache := {}
## Next free index when allocating prop multimesh bands.
var _band_cursor := 0
## Multimesh band pool for void/backfill draws behind the land mask.
var _void_bands: Array = []
## Next free index when allocating void multimesh bands.
var _void_band_cursor := 0
## Multimesh band pool for animated world features.
var _feat_bands: Array = []
## Feature ids currently receiving selection outline emphasis.
var outlined_feat_ids := {}
## Ground item ids currently receiving selection outline emphasis.
var outlined_item_ids := {}
## Throng slot ids currently receiving selection outline emphasis.
var outlined_throng_ids := {}
## Building ids currently receiving selection outline emphasis.
var outlined_bld_ids := {}

## Currently selected Catalog tool id (eye, hand, sponge, etc.).
var tool := Catalog.TOOL_EYE
## Structure kind id actively being placed, or -1 when not building.
var placing := -1
## In-progress kit tray drag payload (type, id, origin cell).
var kit_drag := {}
## Selected throng sim slot index, or -1 when nothing is picked.
var selected := -1
## Selected building id for focus or build tools, or -1.
var selected_bld := -1
## Hold-to-charge progress for grab and place tools, 0..1.
var tool_charge := 0.0
## Input action name currently driving tool charge decay.
var tool_charge_key := ""
## Stack count shown while a charge tool is building power.
var tool_charge_n := 0

## Chunk keys already painted so bootstrap skips redundant tile work.
var painted := {}
## Last world chunk epoch Main applied during incremental paint.
var seen_epoch := -1
## Hash of kit cost signature; triggers toolbar rebuild when it changes.
var bar_serial := -1
## Whether the gem market panel is expanded over gameplay.
var market_open := false
## Cache key of gems and unlock serial; skips market list rebuild.
var market_sig := ""
## Last narrative event id shown in console or focus dialogue.
var shown_event := ""
## Pending HUD toast messages drained one at a time.
var toast_queue: Array = []
## Text of the toast currently on screen.
var toast_msg := ""
## Seconds remaining before the active toast hides.
var toast_t := 0.0
## Seconds remaining for the save-disk icon pulse after autosave.
var save_flash_t := 0.0
## Last sim save_pulse value consumed for the save icon flash.
var save_pulse_seen := 0
## Global presentation time for water, mood faces, and sprite clips.
var anim_time := 0.0
## Animated water tile cells keyed for bootstrap water sync.
var water_cells: Dictionary = {}

## Root CanvasLayer holding HUD, kit, console, and modal overlays.
var ui: CanvasLayer
## Living-count label centered in the thronglet counter badge.
var pop_label: Label
## Mood face TextureRect inside the population counter ring.
var pop_face: TextureRect
## POP_FACES atlas key last applied to the population face.
var pop_face_key := ""
## Part-two gem count plaque beside the population badge.
var gem_panel: Control
## Numeric gem total label inside the gem plaque.
var gem_label: Label
## Gem icon TextureRect on the left of the gem plaque.
var gem_icon_rect: TextureRect
## Current objective text in the cyan task banner body.
var goal_label: Label
## Bottom context hint describing the active tool or drag operation.
var hint: Label
## Center-top transient message label for sim notes and events.
var toast: Label
## Whether the selected throng need card should stay visible.
var need_show := false
## Floating need summary card built by world marks.
var need_card: Control
## Progress bar controls inside the need card.
var need_fills: Array = []
## Need type icon TextureRect on the need card.
var need_icon: TextureRect
## Full-screen ColorRect for narrative glitch effects.
var glitch_overlay: ColorRect
## ShaderMaterial driving glitch overlay distortion.
var glitch_mat: ShaderMaterial
## Shared Theme applied to HUD root controls and buttons.
var ui_theme: Theme
## Bottom-right tray PanelContainer holding kit item icons.
var kit_panel: PanelContainer
## Tab row PanelContainer above the kit tray.
var kit_tab_row: PanelContainer
## HBoxContainer of kit category tab buttons.
var kit_tabs: HBoxContainer
## HBoxContainer of draggable kit tool and structure icons.
var kit_icons: HBoxContainer
## Wood, bone, and ore totals label (hidden unless dev or tutorial needs it).
var res_label: Label
## Whether the kit tray is expanded from the toolbar button.
var kit_open := false
## Active kit category tab index in the tray.
var kit_tab := 0
## True while title screen is up and sim presentation is idle.
var in_title := true
## Top HUD cluster containing counter, gems, and task banner.
var hud_top: Control
## Floppy disk TextureRect pulsing after autosave near the menu button.
var save_icon: TextureRect
## Bottom-left frames-per-second label toggled via prefs.
var fps_label: Label
## Whether DevBench mode has taken over input and hidden play HUD.
var dev_on := false
## Live DevBench child while developer overlay is open.
var dev_bench = null
## Snapshot of root UI child visibility before dev bench blanks the HUD.
var dev_hud_vis := {}
## World point where the current hand grab started.
var hand_from := Vector2.ZERO
## Whether a hand release is waiting to commit pickup or drop.
var hand_pending := false
## Sim slot or entity id targeted by a pending hand release.
var hand_pending_id := -1
## Seconds the hand tool has been held on the current target.
var hand_hold_t := 0.0
## Last world point sampled while scrubbing with the sponge tool.
var sponge_last := Vector2.ZERO
## Whether sponge stroke distance should contribute scrub sim calls.
var sponge_tracking := false
## Centered modal PanelContainer listing gem unlock purchases.
var market_panel: PanelContainer
## VBoxContainer of dynamic market offer rows inside the market panel.
var market_list: VBoxContainer
## Root control stacking the green dialogue console and side chrome.
var gaze_panel: Control
## Console frame control receiving gaze clicks and glyph borders.
var gaze_log: Control
## Typewriter RichTextLabel inside the green dialogue console.
var gaze_text: RichTextLabel
## Hidden LineEdit for naming throngs during console prompts.
var name_edit: LineEdit
## Side VBox beside the console for face and reaction widgets.
var gaze_box: VBoxContainer
## Speaker face TextureRect beside gaze dialogue lines.
var gaze_face: TextureRect
## Atlas textures for animated console frame glyph strips.
var console_glyphs: Array[Texture2D] = []
## TextureRect corners animated around the console frame.
var console_corner_glyphs: Array[TextureRect] = []
## Full dialogue line text while the typewriter is revealing.
var console_line := ""
## Character index up to which the console typewriter has shown.
var console_reveal := 0
## Dialogue substring already committed to the gaze log.
var console_shown := ""
## Monotonic dialogue sequence id to ignore stale console callbacks.
var shown_seq := 0
## Full-screen dimmer ColorRect with shader punch-out around focus box.
var focus_dim: ColorRect
## Decorative dialogue frame Panel bordering the focus subviewport.
var focus_frame: Panel
## ShaderMaterial carving the transparent hole in the focus dimmer.
var focus_shade: ShaderMaterial
## SubViewportContainer displaying the magnified talk viewport.
var focus_box: SubViewportContainer
## SubViewport rendering the isolated chunk during focus dialogue.
var focus_port: SubViewport
## Terrain TileMapLayer inside the focus subviewport.
var focus_tilemap: TileMapLayer
## Camera2D inside the focus subviewport framing the speaker.
var focus_cam_node: Camera2D
## Goal banner anchor control slotted beside the population badge.
var task_panel: Control
## Whether focus dialogue mode has raised the subviewport overlay.
var focus_on := false
## Seconds focus overlay has been held open for framing ease-in.
var focus_hold := 0.0
## Catalog tool TextureButtons keyed by tool id for quick binding.
var tool_buttons := {}
## Structure placement TextureButtons keyed by build kind id.
var build_buttons := {}

## Wire placement overlay and world marks under the scene world root.
func _attach_world_overlay_nodes() -> void:
	placement_overlay.attach_world_nodes(self)
	world_marks_ui.attach_world_nodes(self, ui_assets)

## Share world-marks agent task panel refs with the placement overlay.
func _link_agent_task_panel() -> void:
	placement_overlay.agent_task_panel = world_marks_ui.agent_task_panel
	placement_overlay.agent_task_title = world_marks_ui.agent_task_title
	placement_overlay.agent_task_rows = world_marks_ui.agent_task_rows

## Instantiate presentation modules, build world and HUD, then start boot or test harness.
func _ready() -> void:
	placement_overlay = PlacementOverlay.new()
	world_marks_ui = WorldMarks.new()
	console_ui = ConsoleUI.new()
	focus_viewport = FocusViewport.new()
	kit_toolbar = KitToolbar.new()
	tool_controller = ToolController.new()
	EffectTune.load_saved()
	ui_assets = UIAssets.new()
	structure_tex = StructureTextures.new()
	anim_frames = ThrongAnimFrames.new()
	world_boot = WorldBootstrap.new()
	world_boot.setup(ui_assets, null)
	world_boot.build_sky(self)
	world_boot.build_world(self)
	var MediaControllerScript := preload("res://scripts/presentation/media/media_controller.gd")
	media = MediaControllerScript.new()
	add_child(media)
	media.host = self
	media.build_audio()
	media.build_video()
	shot_capture = ShotCaptureScript.new()
	shot_capture.setup(self)
	cam_rig = CameraRig.new()
	cam_rig.setup(
		camera,
		tilemap,
		func(): return get_viewport_rect(),
		func(): return get_viewport().get_mouse_position(),
		func(): return get_global_mouse_position(),
	)
	path_overlay = PathOverlay.new()
	path_overlay.setup(pathmap, path_root, focus_pathmap, focus_path_root, ui_assets, cam_rig)
	world_boot.setup(ui_assets, path_overlay)
	iso_draw = IsoDraw.new()
	iso_draw.setup(self, cam_rig, anim_frames)
	world_drawer = WorldDrawer.new()
	world_drawer.setup(self, iso_draw, world_boot)
	world_actor_sync = WorldActorSync.new()
	world_actor_sync.setup(self, cam_rig, iso_draw, world_drawer, anim_frames, structure_tex)
	tool_controller.setup(self, cam_rig)
	kit_toolbar.setup(self, cam_rig)
	kit_toolbar.on_is_charge_tool = tool_controller.is_charge_tool
	kit_toolbar.on_clear_tool_charge = tool_controller.clear_tool_charge
	kit_toolbar.on_drop_on_island = tool_controller.drop_on_island
	placement_overlay.setup(self, cam_rig)
	placement_overlay.on_feature_draw_at = iso_draw.feature_draw_at
	placement_overlay.on_charge_tool_id = tool_controller.charge_tool_id
	placement_overlay.on_want_place_grid = tool_controller.want_place_grid
	placement_overlay.on_drop_on_island = tool_controller.drop_on_island
	world_marks_ui.setup(self, cam_rig)
	world_marks_ui.on_building_draw_at = iso_draw.building_draw_at
	world_marks_ui.on_building_active_draw_at = iso_draw.building_active_draw_at
	world_marks_ui.on_iso_ellipse_points = placement_overlay.iso_ellipse_points
	world_marks_ui.on_throng_hidden_indoors = world_actor_sync.throng_hidden_indoors
	console_ui.setup(self, cam_rig)
	focus_viewport.setup(self, cam_rig)
	focus_viewport.on_paint_chunk = func(ck: String, fog: bool, into = null) -> void:
		world_boot.paint_chunk(self, ck, fog, into)
	focus_viewport.on_write_focus_draws = world_drawer.write_focus_draws
	focus_viewport.on_feature_draw_at = iso_draw.feature_draw_at
	focus_viewport.on_feature_anim = anim_frames.feature_anim
	focus_viewport.on_prop_frame = anim_frames.prop_frame
	focus_viewport.on_push_iso = iso_draw.push_iso
	focus_viewport.on_push_glitch_fumes = iso_draw.push_glitch_fumes
	focus_viewport.on_push_anomaly_ray = iso_draw.push_anomaly_ray
	focus_viewport.on_item_draw_at = iso_draw.item_draw_at
	focus_viewport.on_egg_anim = anim_frames.egg_anim
	focus_viewport.on_apple_frame = anim_frames.apple_frame
	focus_viewport.on_building_draw_at = iso_draw.building_draw_at
	focus_viewport.on_throng_frame = anim_frames.frame
	focus_viewport.on_throng_sprite_look = anim_frames.throng_sprite_look
	focus_viewport.on_push_corpse_blood = world_actor_sync.push_corpse_blood
	focus_viewport.on_throng_flip = anim_frames.throng_flip
	focus_viewport.on_throng_dirty = anim_frames.throng_dirty
	focus_viewport.on_layout_console = console_ui.layout_console
	focus_viewport.on_set_box = kit_toolbar.set_box
	kit_toolbar.on_atlas_icon = world_marks_ui.atlas_icon
	_build_ui()
	path_overlay.setup(pathmap, path_root, focus_pathmap, focus_path_root, ui_assets, cam_rig)
	_link_agent_task_panel()
	if media != null:
		media.on_begin_dos = boot_seq.begin_dos
		media.on_show_title = title.show_title
		media.on_open_video_library = video_lib.open
		if cam_rig != null:
			media.on_near_spot = cam_rig.near_spot
		media.get_boot = func(): return boot_seq.boot
		media.get_logo_started = func(): return boot_seq.logo_started
	cam_rig.focus_world(Vector2(256, 256))
	if ThrongletSimServer.testing:
		in_title = false
		if ThrongletSimServer.shot_mode:
			cam_rig.set_zoom(3.0)
			cam_rig.focus_world(Vector2(256, 256))
			if ui != null:
				ui.visible = false
		elif ThrongletSimServer.save_perf_mode:
			save_perf = SavePerfScript.new()
			add_child(save_perf)
			save_perf.setup(self)
		elif ThrongletSimServer.perf_mode:
			perf_bench = PerfBenchScript.new()
			add_child(perf_bench)
			perf_bench.setup(self)
		elif OS.get_cmdline_user_args().has("--pick-zoom-repro"):
			pick_zoom_repro = PickZoomReproScript.new()
			add_child(pick_zoom_repro)
			pick_zoom_repro.setup(self)
	else:
		if PropTune.consume_boot():
			_enter_dev()
		else:
			boot_seq.begin_logo()

## Handle boot skips, video stop, and zoom before controls consume events.
func _input(event: InputEvent) -> void:
	if boot_seq.dos_root != null and boot_seq.dos_root.visible and event is InputEventMouseButton and event.pressed:
		boot_seq.finish_dos()
		get_viewport().set_input_as_handled()
		return
	if boot_seq.boot == "logo" and event is InputEventMouseButton and event.pressed:
		boot_seq.begin_dos()
		get_viewport().set_input_as_handled()
		return
	if media != null and media.video_player != null and media.video_player.visible and event is InputEventMouseButton and event.pressed:
		media.video_player.stop()
		media._on_video_finished()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dev_on:
		if dev_bench != null:
			dev_bench.release_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not kit_drag.is_empty():
			kit_toolbar.end_kit_drag()
		elif ThrongletSimServer.has_scoop():
			kit_toolbar.drop_scoop()
		elif ThrongletSimServer.is_holding():
			tool_controller.hand_release()
		elif tool_controller.is_charge_tool(tool):
			tool_controller.clear_tool_charge()
			tool = Catalog.TOOL_EYE
		elif tool == Catalog.TOOL_SPONGE:
			tool = Catalog.TOOL_EYE
	if in_title or not ThrongletSimServer.modal.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_rig.zoom_by(1.0, not ThrongletSimServer.modal.is_empty())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_rig.zoom_by(-1.0, not ThrongletSimServer.modal.is_empty())
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		cam_rig.zoom_factor(float(event.factor), not ThrongletSimServer.modal.is_empty())
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			cam_rig.zoom_by(1.0, not ThrongletSimServer.modal.is_empty())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			cam_rig.zoom_by(-1.0, not ThrongletSimServer.modal.is_empty())
			get_viewport().set_input_as_handled()

## Handle pan, save keys, pause, kit hotkeys, and tool clicks after UI.
func _unhandled_input(event: InputEvent) -> void:
	if dev_on:
		if dev_bench != null:
			dev_bench.input(event)
		return
	if in_title or ThrongletSimServer.game_over:
		return
	var sim: ThrongletSim = ThrongletSimServer
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			cam_rig.begin_drag(event.position)
			kit_toolbar.cancel_kit_drag()
		else:
			cam_rig.end_drag()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			ThrongletSimServer.save_system.save_progress()
		elif event.keycode == KEY_F9:
			game_flow.toggle_slots()
		elif event.keycode == KEY_F8:
			sim.debug_spawn(10000, cam_rig.from_iso(camera.position))
		elif event.keycode == KEY_ESCAPE:
			if game_flow.slots_panel.visible:
				media.play("ui")
				game_flow.close_slots()
			elif not sim.frozen:
				media.play("ui")
				game_flow.open_menu()
		else:
			kit_toolbar.hotkey(event.keycode)
		return
	if sim.frozen or sim.paused or in_title:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not kit_drag.is_empty():
			return
		if tool == Catalog.TOOL_EYE:
			tool_controller.hand_press()
		else:
			tool_controller.world_click()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tool_controller.hand_release()

## Drive boot, media, camera, sync, overlays, HUD, console, and focus each frame.
func _process(delta: float) -> void:
	boot_seq.tick_logo(delta)
	boot_seq.tick_dos(delta)
	media.tick_captions()
	_sync_tutorial()
	kit_toolbar.sync_active_tool()
	if ThrongletSimServer.perf_mode and perf_bench != null and not perf_bench.done:
		_process_perf(delta)
		perf_bench.tick(delta)
		return
	if ThrongletSimServer.save_perf_mode and save_perf != null and not save_perf.done:
		_process_save_perf(delta)
		save_perf.tick(delta)
		return
	if pick_zoom_repro != null and str(pick_zoom_repro.phase) != "quit":
		pick_zoom_repro.tick(delta)
	if dev_on:
		var _focus := get_viewport().gui_get_focus_owner()
		var _typing := _focus is LineEdit or _focus is TextEdit
		cam_rig.move(delta, _typing, dev_on)
		if dev_bench != null:
			dev_bench.tick()
		if ThrongletSimServer.shot_mode and not shot_capture.done:
			shot_capture.tick_shot()
		return
	media.sync_music(in_title, cam_rig.camera_biome(is_inside_tree()))
	media.tick_birds(delta)
	if in_title:
		title.tick(delta)
		placement_overlay.sync_place_mark()
		placement_overlay.hide_hitboxes()
		placement_overlay.hide_agent_debug()
		if placement_overlay.charge_ring != null:
			placement_overlay.charge_ring.visible = false
		if placement_overlay.charge_area != null:
			placement_overlay.charge_area.visible = false
		if need_show:
			selected = -1
			world_marks_ui.sync_need_bars()
		world_marks_ui.hide_marks()
		if ThrongletSimServer.shot_mode and not shot_capture.done:
			shot_capture.tick_shot()
		return
	var sim: ThrongletSim = ThrongletSimServer
	game_flow.sync_game_over()
	if sim.game_over:
		return
	if not sim.paused:
		anim_time += delta
		world_boot.sync_water_animation(self, anim_time)
	var _focus := get_viewport().gui_get_focus_owner()
	var _typing := _focus is LineEdit or _focus is TextEdit
	cam_rig.move(delta, _typing, dev_on)
	# TODO: Condition looks hacky: str(sim.modal.get("event", "")) == "monolith_appear"
	# Cinematic focus (e.g. monolith appearance)
	if not sim.modal.is_empty() and str(sim.modal.get("event", "")) == "monolith_appear" and sim.modal.has("focus_x"):
		var focus_at := cam_rig.to_iso(Vector2(float(sim.modal.get("focus_x", 256.0)), float(sim.modal.get("focus_y", 256.0))))
		camera.position = camera.position.lerp(focus_at, 0.15)
	# Follow selected thronglet continuously until clicked elsewhere
	elif selected >= 0:
		if selected < sim.slot_count and sim.state[selected] != Catalog.ST_VACANT:
			if sim.held_kind != "thronglet" and not hand_pending:
				camera.position = camera.position.lerp(cam_rig.to_iso(Vector2(sim.pos_x[selected], sim.pos_y[selected])), 0.12)
		else:
			selected = -1
	var view := cam_rig.world_view()
	sim.view_rect = view
	sim.explore_rect(view.grow(8.0))
	# Kit-drag sponge still scrubs over the world even if a Control was under the press.
	var sponge_held := tool == Catalog.TOOL_SPONGE and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not sim.frozen
	var sponge_over_ui := get_viewport().gui_get_hovered_control() != null and kit_drag.is_empty()
	if sponge_held and not sponge_over_ui:
		var at := cam_rig.pointer_world()
		var stroke := 0.0
		if sponge_tracking:
			stroke = at.distance_to(sponge_last)
		else:
			sponge_tracking = true
		sponge_last = at
		# Bubbles + clean gain when agitating; hold still keeps Happy + suds if already washing.
		var stroke_min := float(EffectTune.get_tune("act:sponge").get("stroke_min", ThrongletSimServer.SCRUB_STROKE_MIN))
		sim.scrub(at.x, at.y, stroke, stroke >= stroke_min)
	else:
		if sponge_tracking and not sim.shot_mode:
			sim.sponge_release()
		if not sim.shot_mode:
			sponge_tracking = false
	if sim.hand_id != -1:
		var cur_w := cam_rig.pointer_world()
		if hand_vel_init:
			var inst_v := (cur_w - hand_last_world) / maxf(delta, 0.001)
			hand_vel = hand_vel.lerp(inst_v, 0.45)
		else:
			hand_vel = Vector2.ZERO
			hand_vel_init = true
		hand_last_world = cur_w
	else:
		hand_vel = Vector2.ZERO
		hand_vel_init = false
	tool_controller.tick_tool_charge(delta)
	tool_controller.tick_hand_hold(delta)
	# Shot harness mutates pose/FX before the draw sync.
	if sim.shot_mode and not shot_capture.done:
		shot_capture.tick_shot()
	world_boot.sync_world(self, cam_rig)
	placement_overlay.sync_charge_mark(delta)
	world_actor_sync.sync()
	placement_overlay.sync_place_mark()
	placement_overlay.sync_hitboxes()
	placement_overlay.sync_agent_debug()
	if not sim.shot_mode:
		_sync_hud(delta)
	world_marks_ui.sync_need_bars()
	world_marks_ui.sync_marks()
	world_marks_ui.sync_glitch(delta)
	_sync_market()
	console_ui.sync_gaze()
	focus_viewport.sync_focus(delta)
	for name in sim.take_sfx():
		media.play(str(name))

## Run a trimmed play tick while perf bench records sync and HUD timings.
func _process_perf(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.paused:
		anim_time += delta
		world_boot.sync_water_animation(self, anim_time)
	var view := cam_rig.world_view()
	sim.view_rect = view
	sim.explore_rect(view.grow(8.0))
	world_boot.sync_world(self, cam_rig)
	var t0 := Time.get_ticks_usec()
	world_actor_sync.sync()
	set_meta("perf_sync_ms", float(Time.get_ticks_usec() - t0) * 0.001)
	placement_overlay.sync_place_mark()
	_sync_hud(delta)
	world_marks_ui.sync_need_bars()
	world_marks_ui.sync_marks()

## Run play systems with meta timers while save-perf bench measures cost.
func _process_save_perf(delta: float) -> void:
	# Same systems as normal play, with timers so we can see where the save burns time.
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.paused:
		anim_time += delta
		world_boot.sync_water_animation(self, anim_time)
	cam_rig.move(delta, true, false)
	var view := cam_rig.world_view()
	sim.view_rect = view
	sim.explore_rect(view.grow(8.0))
	var tw := Time.get_ticks_usec()
	world_boot.sync_world(self, cam_rig)
	set_meta("save_perf_world_ms", float(Time.get_ticks_usec() - tw) * 0.001)
	placement_overlay.sync_charge_mark(delta)
	var ts := Time.get_ticks_usec()
	world_actor_sync.sync()
	set_meta("save_perf_sync_ms", float(Time.get_ticks_usec() - ts) * 0.001)
	placement_overlay.sync_place_mark()
	_sync_hud(delta)
	world_marks_ui.sync_need_bars()
	world_marks_ui.sync_marks()
	world_marks_ui.sync_glitch(delta)
	_sync_market()
	console_ui.sync_gaze()
	focus_viewport.sync_focus(delta)
	# Sim _process already ran; expose its last step cost if present.
	set_meta("save_perf_step_ms", float(sim.get_meta("save_perf_step_ms", 0.0)))


## Free monolith nodes and active building sprites tracked on Main.
func _clear_world_sprite_registry() -> void:
	for id in _monoliths.keys():
		var node: Node2D = _monoliths[id]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_monoliths.clear()
	for id in _building_active_sprites.keys():
		var node: Sprite2D = _building_active_sprites[id]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_building_active_sprites.clear()

## Resize gem plaque width from label minimum size for part-two HUD.
func _fit_gem_plaque() -> void:
	if gem_panel == null or gem_label == null:
		return
	const PLAQUE_H := 36
	var text_w := gem_label.get_minimum_size().x
	var width := int(ceil(10.0 + 17.0 + 10.0 + text_w + 14.0))
	width = maxi(width, 96)
	gem_panel.custom_minimum_size = Vector2(width, PLAQUE_H)
	gem_panel.size = Vector2(width, PLAQUE_H)

## Refresh population, gems, goals, hints, toasts, kit bars, and save flash.
func _sync_hud(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if fps_label != null:
		fps_label.text = "%d FPS" % int(round(Engine.get_frames_per_second()))
	pop_label.text = "?" if sim.count_unknown else str(sim.living)
	var face_key := "base"
	if sim.living <= 0:
		face_key = "cry" if sim.peak > 0 else "base"
	elif sim.frozen:
		face_key = "trance"
	elif cam_rig.camera_biome(is_inside_tree()) == "epilogue":
		var faces := ["epilogue_caretaker", "epilogue_bewildered", "epilogue_angry", "epilogue_birthday", "epilogue_capitalist"]
		face_key = faces[int(anim_time * 1000.0 / 2400.0) % faces.size()]
	elif ui_assets.POP_FACES.has(sim.mood_face):
		face_key = sim.mood_face
	if face_key != pop_face_key:
		pop_face_key = face_key
		pop_face.texture = ui_assets.tex(ui_assets.POP_FACES[face_key])
	gem_panel.visible = sim.part_two
	gem_label.text = str(sim.gems)
	_fit_gem_plaque()
	# Task banner sits beside the badge at x=72; shift right when the gem slot appears.
	var task_x := 72.0
	if gem_panel.visible:
		task_x = 72.0 + gem_panel.get_combined_minimum_size().x + 6.0
	task_panel.position.x = task_x
	# count_item is generation-cached; one ensure covers wood/bone/ore for this HUD pass.
	goal_label.text = sim.goal_line()
	res_label.text = "MADERA %d   HUESO %d   MINERAL %d" % [
		sim.count_item(Catalog.ITEM_WOOD),
		sim.count_item(Catalog.ITEM_BONE),
		sim.count_item(Catalog.ITEM_ORE),
	]
	var info := ""
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == tool:
			info = str(entry.hint)
			break
	if sim.has_scoop():
		info = "MANO  SUELTA PARA ESPARCIR  x%d" % (sim.scoop_item_ids.size() + sim.scoop_dead_ids.size())
	elif not kit_drag.is_empty():
		var drag_id := int(kit_drag.get("id", -1))
		var drag_is_tool := str(kit_drag.get("type", "")) == "tool"
		if drag_is_tool and tool_controller.is_charge_tool(drag_id):
			if drag_id == Catalog.TOOL_GRAB:
				info = "MANO  MANTEN SOBRE OBJETOS DEL SUELO"
				if tool_charge > 0.0:
					info = "MANO  %.0f%%  x%d" % [tool_charge * 100.0, maxi(tool_charge_n, 1)]
			elif tool_charge > 0.0:
				info = "%s  %.0f%%" % [kit_toolbar.kit_drag_label(), tool_charge * 100.0]
				if tool_charge_n > 1:
					info += "  x%d" % tool_charge_n
			else:
				info = "MANTEN SOBRE EL OBJETIVO  " + kit_toolbar.kit_drag_label()
		else:
			info = "SUELTA EN LA REJILLA  " + kit_toolbar.kit_drag_label()
	elif tool_controller.is_charge_tool(tool) and tool_charge > 0.0:
		info = "CARGANDO  %.0f%%" % (tool_charge * 100.0)
		if tool_charge_n > 1:
			info += "  x%d" % tool_charge_n
	elif tool_controller.want_place_grid():
		info = "REJILLA ACTIVA  SUELTA EN UNA CELDA"
	hint.text = info
	if sim.save_pulse != save_pulse_seen:
		save_pulse_seen = sim.save_pulse
		save_flash_t = 1.6
	if save_flash_t > 0.0:
		save_flash_t -= delta
	if save_icon != null:
		save_icon.visible = save_flash_t > 0.0 and game_flow.menu_button != null and game_flow.menu_button.visible
	for note in sim.take_notes():
		toast_queue.append(str(note))
		media.play("console")
	if toast_t <= 0.0 and not toast_queue.is_empty():
		toast_msg = str(toast_queue.pop_front())
		toast_t = 2.8
	if toast_t > 0.0:
		toast_t -= delta
	toast.visible = toast_t > 0.0
	toast.text = toast_msg
	var kit_sig := hash(ProgressionManager.kit_cost_signature(sim))
	if bar_serial != kit_sig:
		bar_serial = kit_sig
		kit_toolbar.rebuild_bars()
	world_marks_ui.sync_market_sign(sim)
	kit_toolbar.mark_selected()

## Rebuild gem market offer list when panel is open and sim economy changed.
func _sync_market() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	market_panel.visible = market_open and sim.has_building_kind(Catalog.BLD_MARKET)
	if not market_panel.visible:
		return
	var sig := "%d:%d" % [sim.gems, sim.unlock_serial]
	if sig == market_sig:
		return
	market_sig = sig
	for child in market_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "MERCADO  %d GEMAS" % sim.gems
	market_list.add_child(title)
	for key in Catalog.MARKET.keys():
		var row: Dictionary = Catalog.MARKET[key]
		var button := Button.new()
		var owned := bool(sim.unlocks.get(key, false))
		button.text = "%s  %d" % [str(row.label), int(row.cost)]
		button.disabled = owned or sim.gems < int(row.cost)
		if owned:
			button.text += "  LISTO"
		var buy_key := str(key)
		button.pressed.connect(func():
			ThrongletSimServer.buy(buy_key)
			market_sig = ""
		)
		market_list.add_child(button)
	var close := Button.new()
	close.text = "CERRAR"
	close.pressed.connect(func(): market_open = false)
	market_list.add_child(close)

## Construct CanvasLayer HUD, focus stack, console, title roots, and wire modules.
func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var theme := Theme.new()
	var font := ui_assets.ui_font()
	if font != null:
		theme.default_font = font
		theme.default_font_size = 16
	var panel := ui_assets.panel_style()
	var slot := ui_assets.slot_style()
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("normal", "Button", slot)
	theme.set_stylebox("hover", "Button", slot)
	theme.set_stylebox("pressed", "Button", slot)
	theme.set_stylebox("disabled", "Button", slot)
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.45, 0.35))
	root.theme = theme
	ui_theme = theme

	hud_top = Control.new()
	hud_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_row := HBoxContainer.new()
	top_row.position = Vector2(6, 6)
	top_row.add_theme_constant_override("separation", 6)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_top.add_child(top_row)
	var badge := Control.new()
	# Native ThrongletCounter cell is 60x60; keep 1:1 so the cream ring is not cropped.
	badge.custom_minimum_size = Vector2(60, 60)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := TextureRect.new()
	ring.texture = ui_assets.tex("res://resources/ui/thronglet_counter.png")
	# Atlas Sprites-ThrongletCounter ships FilterMode bilinear; nearest makes the
	# cream ring look thin and the face eyes read as white plates.
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ring.custom_minimum_size = Vector2(60, 60)
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP
	ring.size = Vector2(60, 60)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(ring)
	pop_face = TextureRect.new()
	pop_face.texture = ui_assets.tex(ui_assets.POP_FACES["base"])
	pop_face_key = "base"
	pop_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pop_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pop_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Face + count sit as one tight cluster in the dark well.
	pop_face.position = Vector2(22, 17)
	pop_face.size = Vector2(16, 13)
	pop_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(pop_face)
	pop_label = Label.new()
	pop_label.position = Vector2(0, 29)
	pop_label.size = Vector2(60, 16)
	pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pop_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	pop_label.add_theme_font_size_override("font_size", 14)
	pop_label.add_theme_color_override("font_color", Color.WHITE)
	pop_label.add_theme_color_override("font_outline_color", Color.BLACK)
	pop_label.add_theme_constant_override("outline_size", 2)
	pop_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	pop_label.add_theme_constant_override("shadow_offset_x", 1)
	pop_label.add_theme_constant_override("shadow_offset_y", 1)
	pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(pop_label)
	top_row.add_child(badge)
	# Plaque scales above the native 28px cell; badge is 60px so keep SHRINK_CENTER.
	gem_panel = Control.new()
	gem_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem_panel.custom_minimum_size = Vector2(96, 36)
	gem_panel.size = Vector2(96, 36)
	gem_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_panel.visible = false
	var gem_bg := NinePatchRect.new()
	gem_bg.texture = ui_assets.tex("res://resources/ui/gem_frame.png")
	gem_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem_bg.patch_margin_left = 17
	gem_bg.patch_margin_right = 19
	gem_bg.patch_margin_top = 5
	gem_bg.patch_margin_bottom = 5
	gem_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_panel.add_child(gem_bg)
	var gem_row := HBoxContainer.new()
	gem_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem_row.offset_left = 10
	gem_row.offset_top = 0
	gem_row.offset_right = -14
	gem_row.offset_bottom = 0
	gem_row.add_theme_constant_override("separation", 10)
	gem_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gem_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem_icon_slot := CenterContainer.new()
	gem_icon_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gem_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_icon_rect = TextureRect.new()
	gem_icon_rect.texture = ui_assets.tex("res://resources/ui/gem_icon.png")
	gem_icon_rect.custom_minimum_size = Vector2(17, 18)
	gem_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gem_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_icon_slot.add_child(gem_icon_rect)
	gem_row.add_child(gem_icon_slot)
	var gem_label_slot := CenterContainer.new()
	gem_label_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gem_label_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_label = Label.new()
	gem_label.text = "0"
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gem_label.add_theme_font_size_override("font_size", 18)
	gem_label.add_theme_constant_override("line_spacing", -2)
	gem_label.add_theme_color_override("font_color", Color.WHITE)
	gem_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gem_label.add_theme_constant_override("outline_size", 2)
	gem_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	gem_label.add_theme_constant_override("shadow_offset_x", 1)
	gem_label.add_theme_constant_override("shadow_offset_y", 1)
	gem_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem_label_slot.add_child(gem_label)
	gem_row.add_child(gem_label_slot)
	gem_panel.add_child(gem_row)
	top_row.add_child(gem_panel)
	# Banner is positioned beside the badge (not inside the HBox) so it keeps original height.
	var goal_wrap := Control.new()
	goal_wrap.position = Vector2(72, 18)
	goal_wrap.size = Vector2(380, 34)
	goal_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal_panel := PanelContainer.new()
	task_panel = goal_wrap
	goal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	goal_panel.add_theme_stylebox_override("panel", ui_assets.goal_outer_style())
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cyan_panel := PanelContainer.new()
	cyan_panel.add_theme_stylebox_override("panel", ui_assets.goal_cyan_style())
	cyan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", 0)
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_panel := PanelContainer.new()
	tag_panel.custom_minimum_size = Vector2(56, 0)
	tag_panel.add_theme_stylebox_override("panel", ui_assets.goal_tag_style())
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_label := Label.new()
	tag_label.text = "TAREA"
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 13)
	tag_label.add_theme_color_override("font_color", ui_assets.goal_ink())
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_child(tag_label)
	goal_row.add_child(tag_panel)
	var body_panel := PanelContainer.new()
	body_panel.custom_minimum_size = Vector2(280, 0)
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", ui_assets.goal_body_style())
	body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_label = Label.new()
	goal_label.text = ""
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	goal_label.add_theme_font_size_override("font_size", 13)
	goal_label.add_theme_color_override("font_color", ui_assets.goal_ink())
	goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_panel.add_child(goal_label)
	goal_row.add_child(body_panel)
	cyan_panel.add_child(goal_row)
	goal_panel.add_child(cyan_panel)
	goal_wrap.add_child(goal_panel)
	hud_top.add_child(goal_wrap)
	root.add_child(hud_top)

	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fps_label.offset_left = 6
	fps_label.offset_top = -28
	fps_label.offset_right = 84
	fps_label.offset_bottom = -6
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = false
	fps_label.z_index = 5
	root.add_child(fps_label)

	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 44
	toast.offset_left = -160
	toast.offset_right = 160
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.visible = false
	root.add_child(toast)

	kit_tab_row = PanelContainer.new()
	kit_tab_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_tab_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kit_tab_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_tab_row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	kit_tab_row.visible = false
	kit_tabs = HBoxContainer.new()
	kit_tabs.add_theme_constant_override("separation", -kit_toolbar.TRAY_FRAME)
	kit_tab_row.add_child(kit_tabs)
	root.add_child(kit_tab_row)
	kit_panel = PanelContainer.new()
	kit_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_panel.offset_left = -180
	kit_panel.offset_top = -56
	kit_panel.offset_right = -68
	kit_panel.offset_bottom = -8
	kit_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	kit_panel.visible = false
	kit_icons = HBoxContainer.new()
	kit_icons.add_theme_constant_override("separation", -kit_toolbar.TRAY_FRAME)
	kit_panel.add_child(kit_icons)
	root.add_child(kit_panel)
	hint = Label.new()
	hint.visible = false
	root.add_child(hint)
	res_label = Label.new()
	res_label.visible = false
	root.add_child(res_label)
	var kit_button := TextureButton.new()
	kit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kit_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_button.offset_left = -76
	kit_button.offset_top = -62
	kit_button.offset_right = -4
	kit_button.offset_bottom = 0
	kit_button.ignore_texture_size = true
	kit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	kit_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	kit_button.texture_normal = ui_assets.tex("res://resources/ui/toolbar_button.png")
	kit_button.pressed.connect(kit_toolbar.toggle_kit)
	root.add_child(kit_button)

	market_panel = PanelContainer.new()
	market_panel.set_anchors_preset(Control.PRESET_CENTER)
	market_panel.offset_left = -90
	market_panel.offset_top = -80
	market_panel.offset_right = 90
	market_panel.offset_bottom = 80
	market_panel.visible = false
	market_list = VBoxContainer.new()
	market_panel.add_child(market_list)
	root.add_child(market_panel)
	world_marks_ui.build_need_card(root)
	world_marks_ui.build_task_panel(root)

	focus_dim = ColorRect.new()
	focus_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	focus_dim.color = Color.WHITE
	focus_dim.visible = false
	focus_dim.z_index = 30
	var shade := Shader.new()
	shade.code = "shader_type canvas_item;\nuniform vec4 hole = vec4(0.2, 0.2, 0.8, 0.8);\nvoid fragment() {\n\tfloat inside = step(hole.x, UV.x) * step(UV.x, hole.z) * step(hole.y, UV.y) * step(UV.y, hole.w);\n\tCOLOR = vec4(0.0, 0.0, 0.0, 0.72 * (1.0 - inside));\n}\n"
	focus_shade = ShaderMaterial.new()
	focus_shade.shader = shade
	focus_dim.material = focus_shade
	root.add_child(focus_dim)
	focus_box = SubViewportContainer.new()
	focus_box.stretch = true
	focus_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_box.visible = false
	focus_box.z_index = 31
	focus_port = SubViewport.new()
	focus_port.disable_3d = true
	focus_port.transparent_bg = false
	focus_port.gui_disable_input = true
	focus_port.handle_input_locally = false
	focus_port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	focus_port.size = Vector2i(320, 180)
	focus_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	focus_box.add_child(focus_port)
	var focus_sky := CanvasLayer.new()
	focus_sky.layer = -1
	focus_port.add_child(focus_sky)
	var focus_stars := TextureRect.new()
	focus_stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_stars.texture = ui_assets.tex("res://resources/tiles/space.png")
	focus_stars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	focus_stars.stretch_mode = TextureRect.STRETCH_SCALE
	focus_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_sky.add_child(focus_stars)
	focus_tilemap = TileMapLayer.new()
	focus_tilemap.tile_set = tilemap.tile_set
	focus_port.add_child(focus_tilemap)
	focus_pathmap = TileMapLayer.new()
	focus_pathmap.tile_set = pathmap.tile_set
	focus_pathmap.z_index = 1
	focus_port.add_child(focus_pathmap)
	focus_path_root = Node2D.new()
	focus_path_root.z_index = 1
	focus_port.add_child(focus_path_root)
	focus_root = Node2D.new()
	focus_root.z_index = 2
	focus_port.add_child(focus_root)
	_focus_bands = []
	focus_cam_node = Camera2D.new()
	focus_port.add_child(focus_cam_node)
	root.add_child(focus_box)
	focus_cam_node.make_current()
	focus_frame = Panel.new()
	focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_frame.visible = false
	focus_frame.z_index = 32
	var border := ui_assets.box_style("res://resources/ui/dialogue_frame.png", 22, 0)
	border.draw_center = false
	focus_frame.add_theme_stylebox_override("panel", border)
	root.add_child(focus_frame)

	var glyph_atlas := "res://resources/ui/atlas/Sprites-ConsoleUI/"
	var glyph_sheets := [
		"UI_ConsoleUI_FrameGlyph_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph1_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph2_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph3_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph4_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph5_Animation_SpriteSheet_0.png",
		"UI_ConsoleUI_FrameGlyph6_Animation_SpriteSheet_0.png",
	]
	for sheet in glyph_sheets:
		var glyph_tex := ui_assets.tex(glyph_atlas + sheet)
		if glyph_tex != null:
			console_glyphs.append(glyph_tex)
	gaze_panel = Control.new()
	gaze_panel.visible = false
	gaze_panel.z_index = 33
	gaze_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_log = Control.new()
	gaze_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	gaze_log.mouse_filter = Control.MOUSE_FILTER_STOP
	gaze_log.gui_input.connect(console_ui.on_console_input)
	console_ui.build_console_frame(gaze_log, 2.0, 0)
	var gaze_margin := MarginContainer.new()
	gaze_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	gaze_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_margin.add_theme_constant_override("margin_left", 40)
	gaze_margin.add_theme_constant_override("margin_right", 40)
	gaze_margin.add_theme_constant_override("margin_top", 18)
	gaze_margin.add_theme_constant_override("margin_bottom", 16)
	gaze_text = RichTextLabel.new()
	gaze_text.bbcode_enabled = true
	gaze_text.fit_content = false
	gaze_text.scroll_active = true
	gaze_text.scroll_following = true
	gaze_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gaze_text.add_theme_font_size_override("normal_font_size", 16)
	gaze_text.add_theme_color_override("default_color", Color(0.22, 0.86, 0.28))
	var gaze_col := VBoxContainer.new()
	gaze_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gaze_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gaze_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_col.add_theme_constant_override("separation", 4)
	gaze_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gaze_col.add_child(gaze_text)
	var gaze_scroll := gaze_text.get_v_scroll_bar()
	gaze_scroll.modulate.a = 0.0
	gaze_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_edit = LineEdit.new()
	name_edit.visible = false
	name_edit.max_length = 24
	name_edit.placeholder_text = ">>"
	name_edit.caret_blink = true
	name_edit.custom_minimum_size = Vector2(0, 22)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_override("font", ui_assets.ui_font())
	name_edit.add_theme_font_size_override("font_size", 16)
	name_edit.add_theme_color_override("font_color", Color(0.22, 0.86, 0.28))
	name_edit.add_theme_color_override("font_placeholder_color", Color(0.22, 0.86, 0.28, 0.45))
	name_edit.add_theme_color_override("caret_color", Color(0.22, 0.86, 0.28))
	var field := StyleBoxEmpty.new()
	name_edit.add_theme_stylebox_override("normal", field)
	name_edit.add_theme_stylebox_override("focus", field)
	name_edit.add_theme_stylebox_override("read_only", field)
	gaze_col.add_child(name_edit)
	gaze_margin.add_child(gaze_col)
	gaze_log.add_child(gaze_margin)
	gaze_box = VBoxContainer.new()
	gaze_box.anchor_left = 1.0
	gaze_box.anchor_right = 1.0
	gaze_box.anchor_bottom = 1.0
	gaze_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_box.add_theme_constant_override("separation", 4)
	gaze_panel.add_child(gaze_log)
	gaze_panel.add_child(gaze_box)
	root.add_child(gaze_panel)
	world_marks_ui.build_marks()
	world_marks_ui.build_glitch(root)

	boot_seq = BootSequence.new()
	boot_seq.setup(self, media, ui_assets)
	prefs = PrefsController.new()
	video_lib = VideoLibrary.new()
	title = TitleScreen.new()
	settings_menu = SettingsMenu.new()
	prefs.setup(
		media,
		func(): return boot_seq.crt_overlay,
		func(): return fps_label,
		func(): return in_title,
		placement_overlay.hide_hitboxes,
		func(): settings_menu.fill(),
	)
	boot_seq.on_advance_sign = _advance_sign
	boot_seq.on_show_title = title.show_title
	title.setup(
		self,
		media,
		ui_assets,
		func(): settings_menu.fill(),
		_start_sandbox_game,
		video_lib.open,
		_continue_game,
		_start_new_game,
		kit_toolbar.cancel_kit_drag,
		kit_toolbar.set_kit_shown,
	)
	settings_menu.setup(
		self,
		media,
		ui_assets,
		prefs,
		title,
		func(): title.fill_title(),
		title.show_title,
		_enter_dev,
		_quit_game,
		prefs.save_prefs,
		prefs.set_sfx_vol,
		prefs.set_music_vol,
		prefs.toggle_captions,
		prefs.toggle_crt,
		prefs.toggle_show_fps,
		prefs.toggle_show_hitboxes,
	)
	video_lib.setup(
		self,
		media,
		ui_assets,
		func(): return title.title_root,
		func(): return settings_menu.title_menu,
	)
	game_flow = GameFlowUI.new()
	game_flow.setup(
		self,
		media,
		ui_assets,
		_sandbox_resize,
		_enter_game,
		_start_new_game,
		title.show_title,
		_quit_game,
		kit_toolbar.cancel_kit_drag,
		kit_toolbar.set_kit_shown,
		tool_controller.clear_tool_charge,
		func(): return tool,
		func(v: int): tool = v,
	)
	game_flow.build_pause(root)
	save_icon = TextureRect.new()
	save_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	save_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_icon.offset_left = -54
	save_icon.offset_top = 4
	save_icon.offset_right = -32
	save_icon.offset_bottom = 28
	save_icon.z_index = 42
	save_icon.texture = ui_assets.tex("res://resources/ui/save_disk.png")
	save_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	save_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	save_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_icon.visible = false
	root.add_child(save_icon)

	title.title_root = Control.new()
	title.title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.title_root.mouse_filter = Control.MOUSE_FILTER_STOP
	title.title_root.visible = false
	title.title_root.z_index = 70
	title.build_backdrop(title.title_root)
	title.build_hud(title.title_root)
	settings_menu.build(title.title_root)
	video_lib.build(title.title_root)
	root.add_child(title.title_root)
	boot_seq.build_opening(root)
	if not ThrongletSimServer.testing:
		prefs.load_prefs()
		prefs.apply_all()

	kit_toolbar.rebuild_bars()

## Hide play HUD while an active tutorial step is driving the player.
func _sync_tutorial() -> void:
	if in_title or ThrongletSimServer.testing:
		return
	if ThrongletSimServer.tutorial_i >= 0:
		_set_hud_shown(false)

## Toggle top HUD, menu button, FPS, kit tray, and save icon visibility.
func _set_hud_shown(shown: bool) -> void:
	if hud_top != null:
		hud_top.visible = shown
	if game_flow.menu_button != null:
		game_flow.menu_button.visible = shown
	if save_icon != null and not shown:
		save_icon.visible = false
	if fps_label != null:
		fps_label.visible = prefs.show_fps and not in_title
	if not shown:
		kit_toolbar.set_kit_shown(false)

## Advance sim tutorial sign and restore HUD when the chain completes.
func _advance_sign() -> void:
	ThrongletSimServer.advance_tutorial()
	if ThrongletSimServer.tutorial_i < 0:
		_set_hud_shown(true)
		if boot_seq.sign_button != null:
			boot_seq.sign_button.visible = false

## Leave title mode, show world UI, and unpause simulation.
func _enter_game() -> void:
	in_title = false
	title.title_root.visible = false
	ThrongletSimServer.paused = false
	prefs.apply_show_fps()

## Snap camera rig to default zoom and world center after new game.
func _reset_camera() -> void:
	if camera == null or cam_rig == null:
		return
	cam_rig.end_drag()
	cam_rig.set_zoom(2.0)
	cam_rig.focus_world(Vector2(256, 256))

## Start a fresh sim session, reset camera, and enter gameplay.
func _start_new_game() -> void:
	ThrongletSimServer.new_game()
	_reset_camera()
	_enter_game()

## Load or create sandbox save, reset paint, camera, and enter gameplay.
func _start_sandbox_game() -> void:
	if not ThrongletSimServer.save_system.load_sandbox():
		ThrongletSimServer.new_sandbox_game()
	_reset_world_paint()
	_reset_camera()
	_enter_game()

## Drop chunk caches and clear tilemaps so bootstrap repaints land.
func _reset_world_paint() -> void:
	painted.clear()
	seen_epoch = -1
	_feat_static_epoch = -1
	world_drawer.clear_feat_static()
	if tilemap != null:
		tilemap.clear()
		water_cells.clear()
	world_drawer.paint_props([])

## Grow or shrink sandbox land tier and repaint when tier actually changes.
func _sandbox_resize(delta: int) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.sandbox_mode:
		return
	var before := sim.land_tier
	if delta > 0:
		sim.sandbox_grow()
	elif delta < 0:
		sim.sandbox_shrink()
	if sim.land_tier == before:
		return
	_reset_world_paint()
	game_flow.close_slots()

## Open DevBench, pause sim, blank HUD, and hide play overlays.
func _enter_dev() -> void:
	if dev_on and dev_bench != null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	sim.cancel_hold()
	sim.paused = true
	dev_on = true
	in_title = false
	prefs.crt_on = false
	prefs.apply_crt()
	prefs.apply_show_fps()
	if ui != null:
		ui.visible = true
	if title.title_root:
		title.title_root.visible = false
	market_open = false
	kit_toolbar.cancel_kit_drag()
	kit_open = false
	_blank_play_ui()
	if placement_overlay.charge_ring:
		placement_overlay.charge_ring.visible = false
	if placement_overlay.charge_area:
		placement_overlay.charge_area.visible = false
	if need_card != null:
		need_card.visible = false
	placement_overlay.hide_agent_debug()
	world_marks_ui.hide_marks()
	for id in _monoliths.keys():
		var node: Node2D = _monoliths[id]
		node.visible = false
	dev_bench = DevBench.new()
	dev_bench.setup(self)
	add_child(dev_bench)
	dev_bench.open()

## Tear down DevBench, clear dev paint state, restore HUD, return to title.
func _leave_dev() -> void:
	if not dev_on:
		return
	dev_on = false
	if dev_bench != null:
		dev_bench.close()
		dev_bench.queue_free()
		dev_bench = null
	world_drawer.paint_props([])
	painted.clear()
	seen_epoch = -1
	_feat_static_epoch = -1
	world_drawer.clear_feat_static()
	if tilemap:
		tilemap.clear()
		water_cells.clear()
	_restore_play_ui()
	title.show_title()

## Record and hide root HUD children while dev bench owns the screen.
func _blank_play_ui() -> void:
	dev_hud_vis.clear()
	if ui == null or ui.get_child_count() == 0:
		return
	var root := ui.get_child(0)
	for child in root.get_children():
		dev_hud_vis[child.get_instance_id()] = child.visible
		child.visible = false

## Restore HUD child visibility saved when entering dev bench.
func _restore_play_ui() -> void:
	if ui == null or ui.get_child_count() == 0:
		return
	var root := ui.get_child(0)
	for child in root.get_children():
		var id := child.get_instance_id()
		if dev_hud_vis.has(id):
			child.visible = bool(dev_hud_vis[id])
	dev_hud_vis.clear()

## Resume last save or checkpoint and enter gameplay if data exists.
func _continue_game() -> bool:
	if not title.has_continue():
		return false
	if ThrongletSimServer.save_system.resume_last():
		_enter_game()
		return true
	if ThrongletSimServer.save_system.load_checkpoint():
		_enter_game()
		return true
	return false

## Autosave live session if needed and request application exit.
func _quit_game() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		sim.save_system.save_progress()
	get_tree().quit()
