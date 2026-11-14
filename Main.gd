extends Node2D

const ThrongletSim := preload("res://ThrongletSimServer.gd")
const DevBench := preload("res://dev_bench.gd")
const DialogueBook := preload("res://dialogue_book.gd")

var camera: Camera2D
var tilemap: TileMapLayer
var pathmap: TileMapLayer
var path_root: Node2D
var path_nodes := {}
var focus_path_root: Node2D
var focus_path_nodes := {}
var path_sheet: Image
var path_iso := {}
var focus_pathmap: TileMapLayer
var world: MultiMeshInstance2D
var world_mesh: MultiMesh
var world_layer: Node2D
var _prop_bands: Array = []
var _monoliths := {}
var place_marks: Node2D
var place_fills: Array[Polygon2D] = []
var place_edges: Array[Line2D] = []
var charge_ring: Line2D
var charge_area: Line2D

var tool := Catalog.TOOL_EYE
var placing := -1
var kit_drag := {}
var selected := -1
var selected_bld := -1
var tool_charge := 0.0
var tool_charge_key := ""
var tool_charge_n := 0
const ZOOM_MIN := 0.55
const ZOOM_MAX := 4.5
const ZOOM_STEP := 1.12
const EGG_ANIM := 87
const ROUND_ANIM := 132
const THRONG_SPRITE_SCALE := 0.4
const FIRE_ANIM := 140
const RIVER_ATLAS := 12
const WASTE_ATLAS := 48
const WASTE_VARIANTS := 6
# Neighbor mask: N=1, E=2, S=4, W=8. Each piece is a TEMP_Path index plus
# flips: h, v, and r (90 degrees counter-clockwise). The draw maps sprite east
# onto the east neighbor, so the bar sits inside the grass diamond.
const PATH_PIECE := [
	"0h", "6rv", "6h", "5h", "6r", "4rv", "5hv", "2rrr",
	"6", "5", "4", "2", "5r", "2rv", "2rrh", "1",
]
const CALM: Array[String] = [
	"ThrongA_Default", "ThrongA_Default Blink", "ThrongA_Happy", "ThrongA_EarWiggleLow",
	"ThrongA_Celebrate_Spritesheet", "ThrongA_Shrug", "Throng_Think_Spritesheet",
	"ThrongA_Jump", "ThrongA_Bored_KickRock", "ThrongA_Default_Ghost",
]
const SING: Array[String] = [
	"Throng_Sing_Spritesheet", "Throng_SingB_Spritesheet", "Throng_SingC_Spritesheet",
	"ThrongA_SingToThronglet_Spritesheet2",
]
# Matches tools/make_art.py CELL. The quad is the whole cell; sprites sit on its bottom edge.
const WORLD_CELL := 128.0
var zoom_level := 2.0
var dragging := false
var drag_from := Vector2.ZERO
var cam_from := Vector2.ZERO

var painted := {}
var seen_epoch := -1
var bar_serial := -1
var market_open := false
var market_sig := ""
var shown_event := ""
var toast_queue: Array = []
var toast_msg := ""
var toast_t := 0.0
var save_flash_t := 0.0
var save_pulse_seen := 0

var ui: CanvasLayer
var pop_label: Label
var pop_face: TextureRect
var pop_face_key := ""
const POP_FACES := {
	"base": "res://resources/ui/face_base.png",
	"happy": "res://resources/ui/face_happy.png",
	"cry": "res://resources/ui/face_cry.png",
	"suspicious": "res://resources/ui/face_suspicious.png",
	"freak": "res://resources/ui/face_freak.png",
	"trance": "res://resources/ui/face_trance.png",
	"epilogue_angry": "res://resources/ui/face_Epilogue_Angry.png",
	"epilogue_bewildered": "res://resources/ui/face_Epilogue_Bewildered.png",
	"epilogue_caretaker": "res://resources/ui/face_Epilogue_Caretaker.png",
	"epilogue_birthday": "res://resources/ui/face_Epilogue_Birthday.png",
	"epilogue_capitalist": "res://resources/ui/face_Epilogue_Capitalist.png",
}
var gem_panel: PanelContainer
var gem_label: Label
var goal_label: Label
var hint: Label
var toast: Label
var need_show := false
var need_backs: Array = []
var need_fills: Array = []
var bubble_panels: Array = []
var bubble_tails: Array = []
var bubble_icons: Array = []
var bubble_labels: Array = []
var full_labels: Array = []
var ring_lines: Array = []
var shot_frames := 0
var shot_done := false
var shot_hud_saved := false
var shot_egg_done := false
var shot_console_saved := false
var shot_name_saved := false
var shot_dos_saved := false
var shot_settings_saved := false
var shot_sign_saved := false
var shot_path_saved := false
var shot_board: SubViewport
var glitch_bars: Array = []
var glitch_label: Label
var ui_theme: Theme
var kit_panel: PanelContainer
var kit_tab_row: PanelContainer
var kit_tabs: HBoxContainer
var kit_icons: HBoxContainer
var res_label: Label
var kit_open := false
var kit_tab := 0
var in_title := true
var hud_top: Control
var menu_button: Button
var save_icon: TextureRect
var dos_root: Control
var dos_label: Label
var dos_full := ""
var dos_shown := 0
var dos_hold := 0.0
var crt_overlay: ColorRect
var captions_label: Label
var captions_layer: CanvasLayer
var captions_on := true
var crt_on := true
var captions_lines: Array = []
var captions_ends: Array = []
var captions_index := -1
var sfx_vol := 1.0
var music_vol := 1.0
var settings_lang := "Español"
const SETTINGS_LANGS := ["Español"]
var sign_button: Button
var dev_on := false
var dev_bench = null
var dev_hud_vis := {}
var title_root: Control
var title_menu: Control
var title_hud: Control
var title_bars: Button
var title_start: Button
var title_video: Button
var settings_tab := 3
var settings_shell: Control
var settings_body: VBoxContainer
var settings_tabs: Array = []
const SETTINGS_BLUE := Color(0.0, 0.0, 170.0 / 255.0)
var video_library: Control
var video_library_shell: Control
var video_library_grid: GridContainer
var video_from_library := false
var shot_video_saved := false
const VIDEO_SHELL_INK := Color(29.0 / 255.0, 22.0 / 255.0, 73.0 / 255.0)
const VIDEO_SHELL_CYAN := Color(88.0 / 255.0, 200.0 / 255.0, 218.0 / 255.0)
const VIDEO_LIBRARY := [
	{"id": "SEQ_1.5", "label": "MOV_01_AB4F12.MOV", "thumb": "1.5"},
	{"id": "SEQ_2.1", "label": "MOV_02_208FA3.MOV", "thumb": "2.1"},
	{"id": "SEQ_3.4", "label": "MOV_03_09FF90.MOV", "thumb": "3.4"},
	{"id": "SEQ_4.2", "label": "MOV_04_0024AB.MOV", "thumb": "4.2"},
	{"id": "SEQ_5.3", "label": "MOV_05_AB4F12.MOV", "thumb": "5.3"},
	{"id": "SEQ_6.2", "label": "MOV_06_FFFDA7.MOV", "thumb": "6.2"},
	{"id": "SEQ_7.3", "label": "MOV_07_73757A.MOV", "thumb": "7.3"},
	{"id": "SEQ_8.3", "label": "MOV_08_12412B.MOV", "thumb": "8.3"},
]
var title_clouds: Array = []
var title_time := 0.0
var title_flare: TextureRect
var title_grass: TextureRect
var title_logo: TextureRect
var title_front: TextureRect
var title_side: TextureRect
var title_egg: TextureRect
var title_layout_size := Vector2.ZERO
var shot_title_saved := false
var hand_from := Vector2.ZERO
const HAND_HOLD := 0.22
var hand_pending := false
var hand_pending_id := -1
var hand_hold_t := 0.0
var sponge_last := Vector2.ZERO
var sponge_dir := Vector2.ZERO
var sponge_tracking := false
var market_panel: PanelContainer
var market_list: VBoxContainer
var gaze_panel: Control
var gaze_log: Control
var gaze_text: RichTextLabel
var name_edit: LineEdit
var gaze_box: VBoxContainer
var gaze_face: TextureRect
var console_glyph: TextureRect
var console_glyphs: Array[Texture2D] = []
var console_corner_glyphs: Array[TextureRect] = []
var glitch_overlay: ColorRect
var glitch_mat: ShaderMaterial
var console_line := ""
var console_reveal := 0
var factory_frame: Sprite2D
var factory_slices: Array[Sprite2D] = []
var pollution_mark: Sprite2D
var pollution_bld: Sprite2D
var market_signs: Node2D
var shown_seq := 0
var focus_dim: ColorRect
var focus_frame: Panel
var focus_shade: ShaderMaterial
var focus_box: SubViewportContainer
var focus_port: SubViewport
var focus_tilemap: TileMapLayer
var focus_mesh: MultiMesh
var focus_cam_node: Camera2D
var task_panel: Control
var focus_on := false
var focus_hold := 0.0
var slots_panel: PanelContainer
var over_panel: PanelContainer
var over_list: VBoxContainer
var slots_list: VBoxContainer
var menu_dim: ColorRect
var tool_buttons := {}
var build_buttons := {}
var sfx_bank := {}
var sfx_pool: Array = []
var music: AudioStreamPlayer
var amb: AudioStreamPlayer
var sting: AudioStreamPlayer
var music_mode := ""
var spot_mode := ""
var video_played := {}
var video_player: VideoStreamPlayer
var video_from_title := false
var boot := ""
var logo_started := false
var logo_wait := 0.0
var logo_video_playing := false
var bird_wait := 8.0
var textures := {}
var biome_plates: Array[Sprite2D] = []


func _ready() -> void:
	_build_sky()
	_build_world()
	_build_audio()
	_build_ui()
	camera.position = _to_iso(Vector2(256, 256))
	camera.zoom = Vector2(zoom_level, zoom_level)
	if ThrongletSimServer.testing:
		in_title = false
		if ThrongletSimServer.shot_mode:
			zoom_level = 3.0
			camera.zoom = Vector2(zoom_level, zoom_level)
			if ui != null:
				ui.visible = false
	else:
		if PropTune.consume_boot():
			_enter_dev()
		else:
			_begin_logo()


func _input(event: InputEvent) -> void:
	if dos_root != null and dos_root.visible and event is InputEventMouseButton and event.pressed:
		_finish_dos()
		get_viewport().set_input_as_handled()
		return
	if boot == "logo" and event is InputEventMouseButton and event.pressed:
		_begin_dos()
		get_viewport().set_input_as_handled()
		return
	if video_player != null and video_player.visible and event is InputEventMouseButton and event.pressed:
		video_player.stop()
		_on_video_finished()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dev_on:
		if dev_bench != null:
			dev_bench.release_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not kit_drag.is_empty():
			_end_kit_drag()
		elif ThrongletSimServer.has_scoop():
			_drop_scoop()
		elif ThrongletSimServer.is_holding():
			_hand_release()
		elif _is_charge_tool(tool):
			_clear_tool_charge()
			tool = Catalog.TOOL_EYE
		elif tool == Catalog.TOOL_SPONGE:
			tool = Catalog.TOOL_EYE
	if in_title or not ThrongletSimServer.modal.is_empty():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(-1.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_zoom_factor(float(event.factor))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_zoom_by(1.0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom_by(-1.0)
			get_viewport().set_input_as_handled()


func _zoom_by(direction: float) -> void:
	if direction > 0.0:
		_zoom_factor(ZOOM_STEP)
	elif direction < 0.0:
		_zoom_factor(1.0 / ZOOM_STEP)


func _zoom_factor(factor: float) -> void:
	if factor <= 0.0 or not ThrongletSimServer.modal.is_empty():
		return
	zoom_level = clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if dev_on:
		if dev_bench != null:
			dev_bench.input(event)
		return
	if in_title or ThrongletSimServer.game_over:
		return
	var sim: ThrongletSim = ThrongletSimServer
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		dragging = event.pressed
		drag_from = event.position
		cam_from = camera.position
		if event.pressed:
			_cancel_kit_drag()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_save_current()
		elif event.keycode == KEY_F9:
			_toggle_slots()
		elif event.keycode == KEY_F8:
			sim.debug_spawn(10000, _from_iso(camera.position))
		elif event.keycode == KEY_ESCAPE:
			if slots_panel.visible:
				_play("ui")
				_close_slots()
			elif not sim.frozen:
				_play("ui")
				_open_menu()
		else:
			_hotkey(event.keycode)
		return
	if sim.frozen or sim.paused or in_title:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not kit_drag.is_empty():
			return
		if tool == Catalog.TOOL_EYE:
			_hand_press()
		else:
			_world_click()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_hand_release()


func _process(delta: float) -> void:
	_tick_logo(delta)
	_tick_dos(delta)
	_tick_captions()
	_sync_tutorial()
	if dev_on:
		_move_camera(delta)
		if dev_bench != null:
			dev_bench.tick()
		return
	_sync_music()
	_tick_birds(delta)
	if in_title:
		_tick_title(delta)
		_sync_place_mark()
		if charge_ring != null:
			charge_ring.visible = false
		if charge_area != null:
			charge_area.visible = false
		if need_show:
			selected = -1
			_sync_need_bars()
		_hide_marks()
		if ThrongletSimServer.shot_mode and not shot_done:
			_tick_shot()
		return
	var sim: ThrongletSim = ThrongletSimServer
	_sync_game_over()
	if sim.game_over:
		return
	_move_camera(delta)
	var view := _world_view()
	sim.view_rect = view
	sim.explore_rect(view.grow(8.0))
	if tool == Catalog.TOOL_SPONGE and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not sim.frozen and get_viewport().gui_get_hovered_control() == null:
		var at := _pointer()
		var stroke := 0.0
		if sponge_tracking:
			var move := at - sponge_last
			if move.length() >= 4.0:
				var dir := move.normalized()
				if sponge_dir != Vector2.ZERO and dir.dot(sponge_dir) < 0.0:
					stroke = move.length()
				sponge_dir = dir
		else:
			sponge_tracking = true
			sponge_dir = Vector2.ZERO
		sponge_last = at
		sim.scrub(at.x, at.y, stroke)
	else:
		sponge_tracking = false
	_tick_tool_charge(delta)
	_tick_hand_hold(delta)
	_sync_world()
	_sync_actors()
	_sync_biome_plates()
	_sync_place_mark()
	_sync_charge_mark()
	if not sim.shot_mode:
		_sync_hud(delta)
	_sync_need_bars()
	_sync_marks()
	_sync_glitch(delta)
	_sync_market()
	_sync_gaze()
	_sync_focus(delta)
	for name in sim.take_sfx():
		_play(str(name))
	if sim.shot_mode and not shot_done:
		_tick_shot()


func _world_click() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var at := _aim_thronglet(false)
	selected = sim.find_thronglet(at.x, at.y, 14.0, false)
	selected_bld = -1
	var used := tool
	if used == Catalog.TOOL_SPONGE:
		return
	if _is_charge_tool(used):
		return
	if used == Catalog.TOOL_TNT:
		at = _grid_pointer()
	sim.use_tool(used, at.x, at.y)
	if used != Catalog.TOOL_EYE:
		tool = Catalog.TOOL_EYE


func _is_charge_tool(tool_id: int) -> bool:
	return tool_id == Catalog.TOOL_AXE or tool_id == Catalog.TOOL_HAMMER or tool_id == Catalog.TOOL_PICK or tool_id == Catalog.TOOL_SAW or tool_id == Catalog.TOOL_GRAB


func _charge_tool_id() -> int:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.has_scoop():
		return -1
	if not kit_drag.is_empty() and str(kit_drag.get("type", "")) == "tool":
		var drag_id := int(kit_drag.get("id", -1))
		if _is_charge_tool(drag_id):
			return drag_id
	if _is_charge_tool(tool) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return tool
	return -1


func _clear_tool_charge() -> void:
	tool_charge = 0.0
	tool_charge_key = ""
	tool_charge_n = 0


func _tick_tool_charge(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var at := _pointer()
	if sim.has_scoop():
		_clear_tool_charge()
		if (not kit_drag.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and _drop_on_island():
			sim.scoop_follow(at.x, at.y)
		return
	var used := _charge_tool_id()
	if used < 0 or sim.frozen or sim.paused or not _drop_on_island():
		_clear_tool_charge()
		return
	var target: Dictionary = sim.charge_tool_target(used, at.x, at.y)
	if target.is_empty():
		_clear_tool_charge()
		return
	var key := str(target.get("key", ""))
	var n := int(target.get("n", 0))
	if used == Catalog.TOOL_GRAB and n <= 0:
		tool_charge_key = key
		tool_charge = 0.0
		tool_charge_n = 0
		return
	if key != tool_charge_key:
		tool_charge_key = key
		tool_charge = 0.0
		tool_charge_n = maxi(1, n)
	else:
		tool_charge_n = maxi(1, n)
	tool_charge = minf(1.0, tool_charge + delta / Catalog.TOOL_CHARGE)
	if tool_charge < 1.0:
		return
	if used == Catalog.TOOL_GRAB:
		sim.scoop_gather(float(target.x), float(target.y))
		_clear_tool_charge()
		return
	sim.use_tool(used, float(target.x), float(target.y))
	_clear_tool_charge()


func _clear_hand_pending() -> void:
	hand_pending = false
	hand_pending_id = -1
	hand_hold_t = 0.0


func _tick_hand_hold(delta: float) -> void:
	if not hand_pending:
		return
	var sim: ThrongletSim = ThrongletSimServer
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or sim.frozen or sim.paused:
		_clear_hand_pending()
		return
	hand_hold_t += delta
	if hand_hold_t < HAND_HOLD:
		return
	var id := hand_pending_id
	_clear_hand_pending()
	if sim.grab_thronglet(id):
		selected = id
		selected_bld = -1


func _hand_press() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	_clear_hand_pending()
	var at := _aim_thronglet(true)
	if _throng_under_cursor(true) < 0:
		var egg := _egg_under_cursor()
		if not egg.is_empty():
			at = Vector2(float(egg.x), float(egg.y))
	hand_from = get_viewport().get_mouse_position()
	var throng := _throng_under_cursor(true)
	if throng >= 0:
		selected = throng
		selected_bld = -1
		hand_pending = true
		hand_pending_id = throng
		hand_hold_t = 0.0
		return
	if sim.grab_at(at.x, at.y):
		selected_bld = -1
		selected = -1
		return
	var hit: Dictionary = sim.eye_use(at.x, at.y)
	var kind := str(hit.get("type", ""))
	if kind == "thronglet":
		selected = int(hit.id)
		selected_bld = -1
	elif kind == "market":
		market_open = true
		selected = -1
		selected_bld = int(hit.get("id", -1))
	elif kind == "building" or kind == "factory":
		selected = -1
		selected_bld = int(hit.id)
	else:
		selected = -1
		selected_bld = -1


func _hand_release() -> void:
	_clear_hand_pending()
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.is_holding():
		return
	var short_click := get_viewport().get_mouse_position().distance_to(hand_from) < 12.0
	if not _drop_on_island():
		sim.cancel_hold()
		return
	var at := _pointer()
	if sim.held_kind == "building" or sim.held_kind == "rock":
		at = _grid_pointer()
	elif sim.hand_id != -1:
		var held: Dictionary = sim.hand_item()
		if not held.is_empty() and Catalog.item_snaps_grid(int(held.kind)):
			at = _grid_pointer()
	var held_thronglet: bool = sim.held_kind == "thronglet"
	var held_id: int = sim.held_ref
	var hit: Dictionary = sim.release_at(at.x, at.y, short_click)
	var kind := str(hit.get("type", ""))
	if kind == "thronglet":
		selected = int(hit.id)
		selected_bld = -1
	elif kind == "market":
		market_open = true
		selected = -1
		selected_bld = -1
	elif held_thronglet:
		selected = held_id
		selected_bld = -1
	else:
		selected = -1
		selected_bld = -1


func _move_camera(delta: float) -> void:
	var keys := Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	if not typing:
		if Input.is_key_pressed(KEY_A) or (not dev_on and Input.is_key_pressed(KEY_LEFT)):
			keys.x -= 1.0
		if Input.is_key_pressed(KEY_D) or (not dev_on and Input.is_key_pressed(KEY_RIGHT)):
			keys.x += 1.0
		if Input.is_key_pressed(KEY_W) or (not dev_on and Input.is_key_pressed(KEY_UP)):
			keys.y -= 1.0
		if Input.is_key_pressed(KEY_S) or (not dev_on and Input.is_key_pressed(KEY_DOWN)):
			keys.y += 1.0
	camera.position += keys * 220.0 * delta / zoom_level
	if dragging:
		var drag := get_viewport().get_mouse_position() - drag_from
		camera.position = cam_from - drag / zoom_level
	camera.zoom = Vector2(zoom_level, zoom_level)
	var step := 1.0 / zoom_level
	camera.position = camera.position.snapped(Vector2(step, step))


func _iso_view() -> Rect2:
	var size := get_viewport_rect().size / zoom_level
	return Rect2(camera.position - size * 0.5, size)


func _world_view() -> Rect2:
	var view := _iso_view()
	var corners: Array[Vector2] = [
		_from_iso(view.position),
		_from_iso(view.position + Vector2(view.size.x, 0)),
		_from_iso(view.position + Vector2(0, view.size.y)),
		_from_iso(view.end),
	]
	var lo := corners[0]
	var hi := corners[0]
	for corner in corners:
		lo = lo.min(corner)
		hi = hi.max(corner)
	return Rect2(lo, hi - lo)


func _to_iso(world_pos: Vector2) -> Vector2:
	var tile := Vector2(tilemap.tile_set.tile_size)
	var cell := world_pos / float(Catalog.TILE) - Vector2(0.5, 0.5)
	return Vector2(tile.x * 0.5 * (cell.x - cell.y), tile.y * 0.5 * (cell.x + cell.y))


func _from_iso(iso: Vector2) -> Vector2:
	var tile := Vector2(tilemap.tile_set.tile_size)
	var a := iso.x / (tile.x * 0.5)
	var b := iso.y / (tile.y * 0.5)
	var cell := Vector2((a + b) * 0.5, (b - a) * 0.5)
	return (cell + Vector2(0.5, 0.5)) * float(Catalog.TILE)


func _pointer() -> Vector2:
	return _from_iso(get_global_mouse_position())


func _aim_thronglet(living_only: bool) -> Vector2:
	var id := _throng_under_cursor(living_only)
	if id < 0:
		return _pointer()
	var sim: ThrongletSim = ThrongletSimServer
	return Vector2(sim.pos_x[id], sim.pos_y[id])


func _throng_under_cursor(living_only: bool) -> int:
	var sim: ThrongletSim = ThrongletSimServer
	var mouse := get_global_mouse_position()
	var probe := _from_iso(mouse + Vector2(0.0, 10.0))
	var best := -1
	var best_feet := -1.0e9
	var best_live := false
	for raw in sim.query_radius(probe.x, probe.y, 40.0):
		var i := int(raw)
		var st := int(sim.state[i])
		if st != Catalog.ST_LIVING and st != Catalog.ST_DEAD:
			continue
		var live := st == Catalog.ST_LIVING
		if living_only and not live:
			continue
		var feet := _to_iso(Vector2(sim.pos_x[i], sim.pos_y[i]))
		var delta := mouse - feet
		if absf(delta.x) > 12.0 or delta.y > 4.0 or delta.y < -24.0:
			continue
		if best >= 0 and live == best_live and feet.y < best_feet:
			continue
		if best >= 0 and not live and best_live:
			continue
		best = i
		best_feet = feet.y
		best_live = live
	return best


func _egg_under_cursor() -> Dictionary:
	var mouse := get_global_mouse_position()
	var best := {}
	var best_feet := -1.0e9
	for it in ThrongletSimServer.items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_EGG:
			continue
		var feet := _to_iso(Vector2(float(it.x), float(it.y)))
		feet.y -= float(it.get("air", 0.0))
		var delta := mouse - feet
		if absf(delta.x) > 8.0 or delta.y > 3.0 or delta.y < -18.0:
			continue
		if feet.y < best_feet:
			continue
		best = it
		best_feet = feet.y
	return best


func _grid_pointer() -> Vector2:
	return Catalog.snap_vec(_pointer())


func _is_care_tool(tool_id: int) -> bool:
	return tool_id == Catalog.TOOL_APPLE or tool_id == Catalog.TOOL_BALL or tool_id == Catalog.TOOL_SPONGE


func _want_place_grid() -> bool:
	if in_title or not _drop_on_island():
		return false
	var sim: ThrongletSim = ThrongletSimServer
	if not kit_drag.is_empty():
		if str(kit_drag.get("type", "")) == "build":
			return true
		return not _is_care_tool(int(kit_drag.get("id", -1))) and int(kit_drag.get("id", -1)) == Catalog.TOOL_TNT
	if sim.hand_id != -1:
		var hand: Dictionary = sim.hand_item()
		return not hand.is_empty() and Catalog.item_snaps_grid(int(hand.kind))
	if sim.held_kind == "building" or sim.held_kind == "rock":
		return true
	return tool == Catalog.TOOL_TNT


func _sync_world() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.paint_epoch != seen_epoch:
		seen_epoch = sim.paint_epoch
		painted.clear()
		tilemap.clear()
		if pathmap != null:
			pathmap.clear()
			for cell in path_nodes.keys():
				_drop_path_at(cell, true)
	for ck in sim.take_dirty():
		_paint_chunk(str(ck), not sim.chunk_shown(str(ck)))
	var rect := _world_view().grow(128.0)
	var size := float(Catalog.TILE * Catalog.CHUNK)
	var x0 := int(floor(rect.position.x / size))
	var y0 := int(floor(rect.position.y / size))
	var x1 := int(floor(rect.end.x / size))
	var y1 := int(floor(rect.end.y / size))
	for cy in range(y0 - 1, y1 + 2):
		for cx in range(x0 - 1, x1 + 2):
			var ck := "%d,%d" % [cx, cy]
			if sim.chunk_shown(ck):
				if str(painted.get(ck, "")) != "real":
					_paint_chunk(ck, false)
			elif str(painted.get(ck, "")) != "fog":
				_paint_chunk(ck, true)


func _paint_chunk(ck: String, fog: bool, into = null) -> void:
	var map: TileMapLayer = tilemap if into == null else into
	var paths: TileMapLayer = pathmap if into == null else focus_pathmap
	var sim: ThrongletSim = ThrongletSimServer
	var origin: Vector2i = sim.chunk_origin(ck)
	if fog:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var cell := origin + Vector2i(lx, ly)
				map.erase_cell(cell)
				_drop_path_at(cell, into == null)
		if into == null:
			painted[ck] = "fog"
		return
	var tiles: PackedByteArray = sim.chunk_tiles(ck)
	if tiles.is_empty():
		return
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(tiles[ly * Catalog.CHUNK + lx])
			var cell: Vector2i = origin + Vector2i(lx, ly)
			if tile == Catalog.TILE_VOID:
				map.erase_cell(cell)
				_drop_path_at(cell, into == null)
			else:
				var atlas_x := tile
				if tile == Catalog.TILE_GRASS:
					var pick := absi((lx * 13 + ly * 7) % 3)
					if pick == 1:
						atlas_x = 10
					elif pick == 2:
						atlas_x = 11
				elif tile == Catalog.TILE_WATER:
					atlas_x = _river_atlas(cell)
				elif tile == Catalog.TILE_GOO:
					atlas_x = WASTE_ATLAS + absi((cell.x * 3 + cell.y * 5) % WASTE_VARIANTS)
				map.set_cell(cell, 0, Vector2i(atlas_x, 0))
				_paint_path_cell(paths, cell, tile)
	if into == null:
		painted[ck] = "real"


func _paint_path_cell(paths: TileMapLayer, cell: Vector2i, tile: int) -> void:
	var main := paths == pathmap
	var show := tile == Catalog.TILE_GRASS and ThrongletSimServer.path_at(cell.x, cell.y)
	if not show:
		_drop_path_at(cell, main)
		return
	var sprite := _path_sprite_at(cell, main)
	sprite.texture = _path_iso_tex(PATH_PIECE[_path_mask(cell)])
	sprite.position = _to_iso(Catalog.cell_world(cell))
	sprite.scale = Vector2.ONE


func _path_mask(cell: Vector2i) -> int:
	var mask := 0
	if ThrongletSimServer.path_at(cell.x, cell.y - 1):
		mask |= 1
	if ThrongletSimServer.path_at(cell.x + 1, cell.y):
		mask |= 2
	if ThrongletSimServer.path_at(cell.x, cell.y + 1):
		mask |= 4
	if ThrongletSimServer.path_at(cell.x - 1, cell.y):
		mask |= 8
	return mask


func _path_iso_tex(piece: String) -> Texture2D:
	if path_iso.has(piece):
		return path_iso[piece]
	var tile := _path_raw(piece.to_int())
	var ops := piece
	while not ops.is_empty() and ops.substr(0, 1).is_valid_int():
		ops = ops.substr(1)
	for i in ops.length():
		tile = _path_turn(tile, ops.substr(i, 1))
	var baked := Image.create(36, 20, false, Image.FORMAT_RGBA8)
	baked.fill(Color(0, 0, 0, 0))
	for py in 20:
		for px in 36:
			var dx := px - 18
			var dy := py - 10
			var lx := dx * 0.5 + float(dy)
			var ly := float(dy) - dx * 0.5
			var sx := int(round(lx + 7.5))
			var sy := int(round(ly + 7.5))
			if sx < 0 or sy < 0 or sx > 15 or sy > 15:
				continue
			var color := tile.get_pixel(sx, sy)
			if color.a <= 40.0 / 255.0:
				continue
			baked.set_pixel(px, py, color)
	var tex := ImageTexture.create_from_image(baked)
	path_iso[piece] = tex
	return tex


func _path_raw(index: int) -> Image:
	if path_sheet == null:
		var tex := _tex("res://resources/tiles/path_overlay.png")
		path_sheet = tex.get_image()
	var raw := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ox := index * 32
	for y in 16:
		for x in 16:
			raw.set_pixel(x, y, path_sheet.get_pixel(ox + x * 2, y * 2))
	return raw


func _path_turn(src: Image, op: String) -> Image:
	var out := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var sx := x
			var sy := y
			if op == "h":
				sx = 15 - x
			elif op == "v":
				sy = 15 - y
			else:
				sx = 15 - y
				sy = x
			out.set_pixel(x, y, src.get_pixel(sx, sy))
	return out


func _path_sprite_at(cell: Vector2i, main: bool) -> Sprite2D:
	var nodes: Dictionary = path_nodes if main else focus_path_nodes
	if nodes.has(cell):
		return nodes[cell]
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var root := path_root if main else focus_path_root
	root.add_child(sprite)
	nodes[cell] = sprite
	return sprite


func _drop_path_at(cell: Vector2i, main: bool) -> void:
	var nodes: Dictionary = path_nodes if main else focus_path_nodes
	if not nodes.has(cell):
		return
	var sprite: Sprite2D = nodes[cell]
	sprite.queue_free()
	nodes.erase(cell)


func _biome_plate_paths(biome: String) -> PackedStringArray:
	if biome == "epilogue":
		return PackedStringArray([
			"res://resources/sprites/plates/T_Epilogue_Tree1.png",
			"res://resources/sprites/plates/T_Epilogue_Tree2.png",
			"res://resources/sprites/plates/T_Epilogue_Tree3_Neurons.png",
		])
	if biome == "anomaly":
		return PackedStringArray([
			"res://resources/sprites/plates/Anomaly_Base_Shape.png",
			"res://resources/sprites/plates/Anomaly_Blue_Outline.png",
			"res://resources/sprites/plates/Anomaly_Pink_Outline.png",
		])
	return PackedStringArray()


func _sync_biome_plates() -> void:
	if biome_plates.is_empty():
		for biome in ["epilogue", "anomaly"]:
			var paths := _biome_plate_paths(biome)
			for i in paths.size():
				var sprite := Sprite2D.new()
				sprite.texture = _tex(paths[i])
				sprite.centered = true
				sprite.z_index = 1
				sprite.visible = false
				sprite.set_meta("biome", biome)
				sprite.set_meta("plate", i)
				add_child(sprite)
				biome_plates.append(sprite)
	var shown := {}
	for key in ThrongletSimServer.special_biomes:
		var biome := str(ThrongletSimServer.special_biomes[key])
		if _biome_plate_paths(biome).is_empty() or shown.has(biome):
			continue
		shown[biome] = str(key)
	var pick := int(Time.get_ticks_msec() / 1400.0)
	for sprite in biome_plates:
		var biome := str(sprite.get_meta("biome"))
		var paths := _biome_plate_paths(biome)
		var on := shown.has(biome) and sprite.texture != null and int(sprite.get_meta("plate")) == posmod(pick, paths.size())
		sprite.visible = on
		if not on:
			continue
		var parts := str(shown[biome]).split(",")
		var cx := int(parts[0])
		var cy := int(parts[1])
		var center := Vector2(float(cx * Catalog.CHUNK + Catalog.CHUNK / 2) * Catalog.TILE, float(cy * Catalog.CHUNK + Catalog.CHUNK / 2) * Catalog.TILE)
		sprite.position = _to_iso(center)
		sprite.scale = Vector2.ONE * (280.0 / maxf(float(sprite.texture.get_width()), 1.0))
		sprite.modulate = Color(1, 1, 1, 0.72 if biome == "anomaly" else 0.42)


func _sync_actors() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var view := _world_view().grow(64.0)
	var draws: Array = []
	var egg_front: Array = []
	var time_pre := Time.get_ticks_msec() / 1000.0
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		if not sim.chunk_shown("%d,%d" % [int(feat.cx), int(feat.cy)]):
			continue
		var p := Vector2(float(feat.x), float(feat.y))
		if int(feat.kind) == Catalog.FEAT_MONOLITH:
			_sync_monolith(int(feat.id), p + Catalog.feature_draw_off(Catalog.FEAT_MONOLITH))
			continue
		var feat_at := _feature_draw_at(int(feat.kind), p, int(feat.ore))
		if view.has_point(p) or view.has_point(feat_at):
			var feat_frame := _feature_frame(int(feat.kind), time_pre, int(feat.ore))
			if feat_frame < 0:
				feat_frame = _prop_frame(Catalog.icon_for_feature(int(feat.kind), int(feat.ore)))
			if int(feat.kind) == Catalog.FEAT_FIRE and feat_frame < 0:
				feat_frame = FIRE_ANIM + int(time_pre * 8.0) % 4
			_push_iso(draws, feat_at, feat_frame, Color.WHITE, 0.0, Catalog.feature_sprite_scale(int(feat.kind), int(feat.ore)))
			_push_glitch_fumes(draws, int(feat.kind), feat_at, time_pre)
			_push_anomaly_ray(draws, int(feat.kind), feat_at)
	for it in sim.items:
		if it.dead or it.held:
			continue
		if not sim.chunk_shown(sim.chunk_key_at(float(it.x), float(it.y))):
			continue
		var p2 := _item_draw_at(int(it.kind), Vector2(float(it.x), float(it.y)))
		if view.has_point(p2):
			var egg_lift := float(it.get("air", 0.0))
			var item_frame := _prop_frame(Catalog.icon_for_item(int(it.kind)))
			if int(it.kind) == Catalog.ITEM_EGG:
				item_frame = _egg_frame(it)
				if float(it.get("shake", 0.0)) > 0.0:
					p2 += Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
				if egg_lift > 0.0:
					_push_iso(egg_front, p2, item_frame, Color.WHITE, egg_lift, Catalog.item_sprite_scale(int(it.kind)))
					continue
			elif int(it.kind) == Catalog.ITEM_APPLE and egg_lift > 0.0:
				_push_iso(egg_front, p2, item_frame, Color.WHITE, egg_lift, Catalog.item_sprite_scale(int(it.kind)))
				continue
			elif int(it.kind) == Catalog.ITEM_BALL:
				var spd := absf(float(it.get("vx", 0.0))) + absf(float(it.get("vy", 0.0)))
				if spd > 2.0:
					egg_lift = absf(sin(time_pre * 14.0 + float(it.id))) * (3.0 if spd > 8.0 else 1.2)
					if spd > 8.0:
						p2 += Vector2(sin(time_pre * 20.0) * 1.0, cos(time_pre * 18.0) * 0.6)
			_push_iso(draws, p2, item_frame, Color.WHITE, egg_lift, Catalog.item_sprite_scale(int(it.kind)))
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if not sim.chunk_shown(sim.chunk_key_at(float(b.x), float(b.y))):
			continue
		var p3 := Vector2(float(b.x), float(b.y))
		var b_kind := int(b.kind)
		var draw_at := _building_draw_at(b_kind, p3)
		if view.has_point(p3) or view.has_point(draw_at):
			var b_lift := 0.0
			var b_tint := Color.WHITE
			var b_frame := _prop_frame(Catalog.icon_for_building(b_kind))
			if b_kind == Catalog.BLD_ROUND and bool(b.get("active", false)):
				b_frame = ROUND_ANIM + int(time_pre * 8.0) % 8
			if bool(b.get("active", false)) and b_kind != Catalog.BLD_APPLE:
				if b_kind == Catalog.BLD_TUB:
					b_tint = Color(0.85, 0.95, 1.0)
				elif b_kind != Catalog.BLD_ROUND:
					b_lift = absf(sin(time_pre * 8.0 + float(b.id))) * 2.2
					if b_kind == Catalog.BLD_FACTORY or b_kind == Catalog.BLD_FACTORY2:
						b_tint = Color(1.0, 0.9, 0.82)
					elif b_kind == Catalog.BLD_MINE or b_kind == Catalog.BLD_MINE2:
						b_tint = Color(1.0, 0.95, 0.75)
			var b_scale := Catalog.building_sprite_scale(b_kind)
			_push_iso(draws, draw_at, b_frame, b_tint, b_lift, b_scale)
			if b_kind == Catalog.BLD_FACTORY or b_kind == Catalog.BLD_FACTORY2:
				_push_factory_pile(draws, b, draw_at)
			if b_kind == Catalog.BLD_APPLE:
				var fruit_sort := _prop_front_sort_y(p3)
				for fruit in b.get("fruits", []):
					var slot := clampi(int(fruit.slot), 0, 2)
					var grown := clampf(float(fruit.s), 0.15, 1.0)
					_push_iso(
						draws,
						Vector2(float(b.x), float(b.y)) + Catalog.APPLE_SPOTS[slot],
						_prop_frame(Catalog.ICON_APPLE),
						Color.WHITE,
						Catalog.APPLE_LIFTS[slot],
						0.55 + 0.45 * grown,
						fruit_sort
					)
			if bool(b.get("active", false)) and b_kind == Catalog.BLD_TUB:
				var seat := p3 + Catalog.TUB_SEAT_OFF
				var spark := Vector2(cos(time_pre * 10.0 + float(b.id)) * 6.0, sin(time_pre * 10.0) * 4.0)
				_push_iso(draws, seat + spark, _prop_frame(Catalog.ICON_SPONGE), Color(1, 1, 1, 0.7), 8.0)
	var bridge: Dictionary = sim.bridge_marker()
	if not sim.shot_mode and not bridge.is_empty() and sim.chunk_shown(str(bridge.ck)):
		var site := Vector2(float(bridge.x), float(bridge.y))
		var drop := Vector2(float(bridge.drop_x), float(bridge.drop_y))
		var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 280.0))
		var mark := Color(1.0, 0.85, 0.2, pulse)
		var site_draw := _bridge_view_point(site, view)
		var drop_draw := _bridge_view_point(drop, view)
		var on_site := view.has_point(site)
		_push_iso(draws, site_draw, _prop_frame(Catalog.ICON_MONOLITH), mark, 28.0 if on_site else 22.0)
		_push_iso(draws, drop_draw, _prop_frame(Catalog.ICON_WOOD), Color(1.0, 1.0, 1.0, pulse), 16.0)
		if on_site or view.has_point(drop):
			var filled := mini(int(bridge.progress), int(bridge.need))
			for n in filled:
				var ox := float((n % 3) - 1) * 10.0
				var oy := float(n / 3) * -8.0
				_push_iso(draws, drop + Vector2(ox, oy), _prop_frame(Catalog.ICON_WOOD), Color(0.95, 0.82, 0.4, 0.9), 14.0)
			for n in range(filled, int(bridge.need)):
				var gx := float((n % 3) - 1) * 10.0
				var gy := float(n / 3) * -8.0
				_push_iso(draws, drop + Vector2(gx, gy), _prop_frame(Catalog.ICON_WOOD), Color(1.0, 1.0, 1.0, 0.22 * pulse), 10.0)
	var grid_at := _grid_pointer()
	var free_at := _pointer()
	var hand: Dictionary = sim.hand_item()
	if not hand.is_empty():
		if _drop_on_island():
			var hand_at := grid_at if Catalog.item_snaps_grid(int(hand.kind)) else free_at
			_push_iso(draws, _item_draw_at(int(hand.kind), hand_at), _prop_frame(Catalog.icon_for_item(int(hand.kind))), Color(1, 1, 1, 0.9), 10.0, Catalog.item_sprite_scale(int(hand.kind)))
		else:
			draws.append({
				"p": get_global_mouse_position(),
				"icon": _prop_frame(Catalog.icon_for_item(int(hand.kind))),
				"tint": Color.WHITE,
			})
	if sim.has_scoop():
		for raw in sim.scoop_item_ids:
			var scooped = sim.item_by_id.get(int(raw), {})
			if scooped.is_empty() or scooped.dead:
				continue
			_push_iso(draws, _item_draw_at(int(scooped.kind), Vector2(float(scooped.x), float(scooped.y))), _prop_frame(Catalog.icon_for_item(int(scooped.kind))), Color(1, 1, 1, 0.92), 12.0, Catalog.item_sprite_scale(int(scooped.kind)))
	if sim.held_kind == "rock":
		var rock = sim.feature_by_id.get(sim.held_ref, {})
		if not rock.is_empty():
			if _drop_on_island():
				_push_iso(draws, _feature_draw_at(int(rock.kind), grid_at, int(rock.ore)), _prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))), Color(1, 1, 1, 0.9), 10.0, Catalog.feature_sprite_scale(int(rock.kind), int(rock.ore)))
			else:
				draws.append({
					"p": get_global_mouse_position(),
					"icon": _prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))),
					"tint": Color.WHITE,
				})
	elif sim.held_kind == "building":
		var carried = sim.building_by_id.get(sim.held_ref, {})
		if not carried.is_empty():
			var carried_kind := int(carried.kind)
			if _drop_on_island():
				var carried_scale := Catalog.building_sprite_scale(carried_kind)
				_push_iso(draws, _building_draw_at(carried_kind, grid_at), _prop_frame(Catalog.icon_for_building(carried_kind)), Color(1, 1, 1, 0.9), 10.0, carried_scale)
			else:
				draws.append({
					"p": get_global_mouse_position(),
					"icon": _prop_frame(Catalog.icon_for_building(carried_kind)),
					"tint": Color.WHITE,
				})
	var drag_front: Array = []
	if not kit_drag.is_empty():
		var ghost := Color(1, 1, 1, 0.85)
		var drag_icon := _kit_drag_icon()
		if drag_icon >= 0:
			if _want_place_grid() and _drop_on_island():
				var ghost_kind := placing if str(kit_drag.get("type", "")) == "build" else -1
				var ghost_scale := Catalog.building_sprite_scale(ghost_kind)
				_push_iso(drag_front, _building_draw_at(ghost_kind, grid_at), _prop_frame(drag_icon), ghost, 10.0, ghost_scale)
			else:
				drag_front.append({
					"p": get_global_mouse_position(),
					"icon": _prop_frame(drag_icon),
					"tint": ghost,
				})
	var time := Time.get_ticks_msec() / 1000.0
	for id in sim.query_rect(view):
		var i := int(id)
		if sim.held_kind == "thronglet" and i == sim.held_ref:
			continue
		var pos := Vector2(sim.pos_x[i], sim.pos_y[i])
		var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
		if sim.state[i] == Catalog.ST_DEAD:
			tint = Color.WHITE
		var lift := 0.0
		var doing := int(sim.act[i])
		var seated := false
		var riding := false
		var prop_anchor := Vector2.INF
		var ball_play: bool = doing == ThrongletSim.ACT_PLAY and not sim.ball_of(i).is_empty()
		if not sim.frozen:
			if sim.shake_t[i] > 0.0:
				pos += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
			if doing == ThrongletSim.ACT_EAT:
				lift = sin(time * 10.0 + float(i)) * 1.0
			elif doing == ThrongletSim.ACT_PLAY and not ball_play:
				var ride: Dictionary = sim.ride_of(i)
				if ride.is_empty():
					lift = absf(sin(time * 14.0 + float(i))) * 5.5
					pos += Vector2(sin(time * 18.0 + float(i)) * 1.4, cos(time * 16.0 + float(i)) * 0.8)
				else:
					riding = true
					lift = absf(sin(time * 10.0 + float(i))) * 1.5
					prop_anchor = Vector2(float(ride.x), float(ride.y))
			elif doing == ThrongletSimServer.ACT_BATH:
				var tub: Dictionary = sim.seat_of(i)
				if tub.is_empty():
					lift = absf(sin(time * 9.0 + float(i))) * 2.2
				else:
					seated = true
					var tub_origin := Vector2(float(tub.x), float(tub.y))
					pos = tub_origin + Catalog.TUB_SEAT_OFF
					var age := float(tub.get("bath_t", 0.0))
					# Sink with the FallInBath enter frames, then hold still in the water.
					if age < 0.0:
						lift = Catalog.TUB_ENTER_LIFT
					elif age < ThrongletSimServer.BATH_ENTER_T:
						lift = lerpf(Catalog.TUB_ENTER_LIFT, Catalog.TUB_SOAK_LIFT, age / ThrongletSimServer.BATH_ENTER_T)
					else:
						lift = Catalog.TUB_SOAK_LIFT
					prop_anchor = _building_draw_at(Catalog.BLD_TUB, tub_origin)
			elif doing == ThrongletSimServer.ACT_WORK:
				lift = absf(sin(time * 12.0 + float(i))) * 3.0
			elif sim.act_t[i] > 0.0:
				lift = sin(time * 16.0 + float(i)) * 3.5
		if prop_anchor.x == INF:
			prop_anchor = _use_prop_anchor(pos)
		var sort_y := NAN if prop_anchor.x == INF else _prop_front_sort_y(prop_anchor)
		var throng_frame := _frame(i, time)
		var throng_scale := _throng_sprite_scale(throng_frame)
		_push_iso(draws, pos + _throng_sprite_off(throng_frame), throng_frame, tint, lift, throng_scale, sort_y)
		draws[draws.size() - 1]["flip"] = _throng_flip(i)
		draws[draws.size() - 1]["dirty"] = _throng_dirty(sim.clean[i])
		if sim.carry[i] != Catalog.CARRY_NONE:
			_push_iso(draws, pos, _carry_icon(int(sim.carry[i])), Color.WHITE, 12.0, 1.0, sort_y)
		if not sim.frozen and doing == ThrongletSimServer.ACT_WASH:
			var bub := Vector2(cos(time * 14.0) * 7.0, sin(time * 14.0) * 4.0)
			var bubble := AssetFrames.frame(AssetFrames.SUDS, AssetFrames.SUDS_N, 0)
			if bubble < 0:
				bubble = _prop_frame(Catalog.ICON_SPONGE)
			_push_iso(draws, pos + bub, bubble, Color(1, 1, 1, 0.85), 8.0, 1.0, sort_y)
			var spark := AssetFrames.frame(AssetFrames.CLEAN, AssetFrames.CLEAN_N, int(time * 10.0))
			if spark >= 0:
				_push_iso(draws, pos + bub * 0.4, spark, Color(1, 1, 1, 0.7), 10.0, 1.0, sort_y)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_BATH and not seated:
			var suds := Vector2(cos(time * 11.0 + float(i)) * 6.0, sin(time * 11.0) * 3.5)
			var foam := AssetFrames.frame(AssetFrames.SUDS, AssetFrames.SUDS_N, 0)
			if foam < 0:
				foam = AssetFrames.frame(AssetFrames.SPLASH, AssetFrames.SPLASH_N, int(time * 8.0))
			if foam < 0:
				foam = _prop_frame(Catalog.ICON_SPONGE)
			_push_iso(draws, pos + suds, foam, Color(0.85, 0.95, 1.0, 0.8), 7.0, 1.0, sort_y)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_PLAY and not riding and not ball_play:
			var toy := Vector2(cos(time * 12.0 + float(i)) * 8.0, sin(time * 12.0) * 4.0)
			_push_iso(draws, pos + toy, _prop_frame(Catalog.ICON_BALL), Color(1, 1, 1, 0.9), 9.0 + lift, 1.0, sort_y)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_WORK:
			var chip := Vector2(sin(time * 15.0 + float(i)) * 6.0, -4.0)
			_push_iso(draws, pos + chip, _prop_frame(Catalog.ICON_ORE), Color(1, 1, 1, 0.75), 8.0, 1.0, sort_y)
	if sim.held_kind == "thronglet" and sim.held_ref >= 0 and sim.held_ref < sim.slot_count:
		var hi: int = sim.held_ref
		var htint: Color = Catalog.TINTS[int(sim.tint[hi]) % Catalog.TINTS.size()]
		draws.append({
			"p": get_global_mouse_position(),
			"icon": _frame(hi, time),
			"tint": htint,
			"flip": _throng_flip(hi),
			"dirty": _throng_dirty(sim.clean[hi]),
			"scale": THRONG_SPRITE_SCALE,
		})
		var hand_frame := AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, int(time * 8.0))
		if hand_frame >= 0:
			draws.append({
				"p": get_global_mouse_position() + Vector2(10, 6),
				"icon": hand_frame,
				"tint": Color.WHITE,
				"flip": 1.0,
				"dirty": 0.0,
			})
	for pop in sim.pops:
		var fade := clampf(float(pop.t) / 0.55, 0.0, 1.0)
		_push_iso(draws, Vector2(float(pop.x), float(pop.y)), _pop_frame(int(pop.icon)), Color(1, 1, 1, fade), float(pop.lift))
	draws.sort_custom(func(a, b): return float(a.get("sy", a.p.y)) < float(b.get("sy", b.p.y)))
	draws.append_array(egg_front)
	draws.append_array(drag_front)
	_paint_props(draws)


func _frame(i: int, time: float) -> int:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.state[i] == Catalog.ST_DEAD:
		var clip := "ThrongA_Dead_001" if int(time * 2.0) % 2 == 0 else "ThrongA_Dead_002"
		return ThrongClips.frame_at(clip, 0)
	if sim.frozen:
		return _clip_pool(ThrongClips.TALK, i, time, 2.4, "ThrongA_Talk")
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		var along := 0.0
		if sim.mito_t[i] > 0.0:
			var split_t := 1.0 - clampf(sim.mito_t[i] / ThrongletSimServer.MITOSIS_ANIM, 0.0, 1.0)
			along = lerpf(ThrongletSimServer.MITOSIS_SPLIT_ALONG, 0.999, split_t)
		else:
			along = clampf(sim.mito_charge[i] / ThrongletSimServer.MITOSIS_CHARGE, 0.0, 1.0) * ThrongletSimServer.MITOSIS_SPLIT_ALONG
		return ThrongClips.frame_along("ThrongA_Mitosis_Spritesheet", along)
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if doing == ThrongletSimServer.ACT_EAT:
		return ThrongClips.frame_at("ThrongA_Eat", int(time * 6.0))
	if doing == ThrongletSimServer.ACT_BATH:
		var tub: Dictionary = sim.seat_of(i)
		if tub.is_empty():
			return ThrongClips.frame_at("ThrongA_Happy", int(time * 6.0))
		var age := float(tub.get("bath_t", 0.0))
		var enter_t := ThrongletSimServer.BATH_ENTER_T
		if age < 0.0:
			return ThrongClips.frame_at("Throng_FallInBath_Spritesheet", 0)
		if age < enter_t:
			# Frames 0-4: climb / fall into the water.
			return ThrongClips.frame_along("Throng_FallInBath_Spritesheet", (age / enter_t) * (5.0 / 8.0))
		# Frames 5-7: soak loop (head above water, eyes closed).
		return ThrongClips.frame_at("Throng_FallInBath_Spritesheet", 5 + int((age - enter_t) * 2.5) % 3)
	if doing == ThrongletSimServer.ACT_WASH:
		return ThrongClips.frame_at("ThrongA_Happy", int(time * 6.0))
	if doing == ThrongletSimServer.ACT_PLAY:
		if not sim.ball_of(i).is_empty():
			if moving:
				if absf(sim.dir_y[i]) > absf(sim.dir_x[i]) and sim.dir_y[i] < 0.0:
					return ThrongClips.frame_at("Throng_WalkBack_Anim_Spritesheet", int(time * 8.0 + float(i)))
				return ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", int(time * 8.0 + float(i)))
			return ThrongClips.frame_at("ThrongA_Happy", int(time * 6.0))
		var play := "ThrongA_Jump_VariantA_Spritesheet"
		if not sim.ride_of(i).is_empty():
			play = "ThrongA_Roundabout_SpriteSheet"
		return ThrongClips.frame_at(play, int(time * 8.0))
	if doing == ThrongletSimServer.ACT_WORK and not moving:
		return ThrongClips.frame_at("ThrongA_Pickaxe_Spritesheet", int(time * 8.0))
	if moving:
		if absf(sim.dir_y[i]) > absf(sim.dir_x[i]) and sim.dir_y[i] < 0.0:
			return ThrongClips.frame_at("Throng_WalkBack_Anim_Spritesheet", int(time * 8.0 + float(i)))
		return ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", int(time * 8.0 + float(i)))
	if sim.clean[i] < 12.0 or sim.fed[i] < 25.0:
		return ThrongClips.frame_at("ThrongA_Sad", int(time * 6.0))
	if sim.amused[i] < 25.0:
		return ThrongClips.frame_at("ThrongA_Grumpy", 0)
	if sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK:
		if posmod(i + int(time), 9) < 3:
			return _clip_pool(SING, i, time, 1.6, "ThrongA_Happy")
		return _clip_pool(CALM, i, time, 2.2, "ThrongA_Happy")
	return _clip_pool(CALM, i, time, 2.8, "ThrongA_Default")


func _throng_flip(i: int) -> float:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.state[i] != Catalog.ST_LIVING or sim.frozen:
		return 1.0
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return 1.0
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if doing == ThrongletSimServer.ACT_EAT or doing == ThrongletSimServer.ACT_BATH or doing == ThrongletSimServer.ACT_WASH:
		return 1.0
	if doing == ThrongletSimServer.ACT_PLAY and sim.ball_of(i).is_empty():
		return 1.0
	if doing == ThrongletSimServer.ACT_WORK and not moving:
		return 1.0
	if not moving:
		return 1.0
	if absf(sim.dir_x[i]) > absf(sim.dir_y[i]) and sim.dir_x[i] < 0.0:
		return -1.0
	return 1.0


func _clip_pool(pool: Array, index: int, time: float, hold: float, fallback: String) -> int:
	var usable: Array[String] = []
	for raw in pool:
		var clip := str(raw)
		if ThrongClips.has_clip(clip):
			usable.append(clip)
	if usable.is_empty():
		return ThrongClips.frame_at(fallback, int(time * 6.0))
	return ThrongClips.pick(usable, index, time, hold)


func _camera_biome() -> String:
	if camera == null:
		return ""
	var world_pos := _from_iso(camera.position) if is_inside_tree() else camera.position
	return ThrongletSimServer.biome_at(world_pos.x, world_pos.y)


func _feature_frame(kind: int, time: float, ore: int = 0) -> int:
	var tick := int(time * 8.0)
	if kind == Catalog.FEAT_GLITCH_TREE:
		return _listed_frame(ore, [
			[AssetFrames.GLITCH_TREE, AssetFrames.GLITCH_TREE_N],
			[AssetFrames.WASTE_TREE, AssetFrames.WASTE_TREE_N],
			[AssetFrames.GLITCH_TREE_C, AssetFrames.GLITCH_TREE_C_N],
			[AssetFrames.GLITCH_TREE_D, AssetFrames.GLITCH_TREE_D_N],
			[AssetFrames.WASTE_TREE_B, AssetFrames.WASTE_TREE_B_N],
		], tick)
	if kind == Catalog.FEAT_GLITCH_HOUSE:
		return AssetFrames.frame(AssetFrames.GLITCH_HOUSE, AssetFrames.GLITCH_HOUSE_N, tick)
	if kind == Catalog.FEAT_ANOMALY:
		return AssetFrames.ANOMALY
	if kind == Catalog.FEAT_FIRE:
		if int(time) % 2 == 1:
			var blob := AssetFrames.frame(AssetFrames.FIRE_BLOB, AssetFrames.FIRE_BLOB_N, tick)
			if blob >= 0:
				return blob
		var flame := AssetFrames.frame(AssetFrames.FIRE, AssetFrames.FIRE_N, tick)
		return flame if flame >= 0 else FIRE_ANIM + tick % 4
	if kind == Catalog.FEAT_EPILOGUE:
		return _listed_frame(ore, [
			[AssetFrames.EPILOGUE, AssetFrames.EPILOGUE_N],
			[AssetFrames.ROTTEN_APPLE, AssetFrames.ROTTEN_APPLE_N],
		], tick)
	if kind == Catalog.FEAT_MOUNTAIN:
		return _listed_frame(ore, [
			[AssetFrames.MOUNT_BIG, AssetFrames.MOUNT_BIG_N],
			[AssetFrames.MOUNT_SMALL, AssetFrames.MOUNT_SMALL_N],
			[AssetFrames.MOUNT_GLITCH, AssetFrames.MOUNT_GLITCH_N],
			[AssetFrames.GRASS_PATCH, AssetFrames.GRASS_PATCH_N],
		], tick)
	return -1


func _listed_frame(pick: int, rows: Array, tick: int) -> int:
	if rows.is_empty():
		return -1
	var row: Array = rows[posmod(pick, rows.size())]
	return AssetFrames.frame(int(row[0]), int(row[1]), tick)


func _push_anomaly_ray(draws: Array, kind: int, at: Vector2) -> void:
	if kind != Catalog.FEAT_ANOMALY:
		return
	_push_iso(draws, at, AssetFrames.ANOMALY_RAY, Color.WHITE)
	draws[draws.size() - 1]["sy"] = float(draws[draws.size() - 1].get("sy", 0.0)) + 0.5


func _push_glitch_fumes(draws: Array, kind: int, at: Vector2, time: float) -> void:
	if kind != Catalog.FEAT_GLITCH_HOUSE and kind != Catalog.FEAT_GLITCH_TREE:
		return
	var frame := AssetFrames.frame(AssetFrames.FUMES, AssetFrames.FUMES_N, int(time * 8.0))
	if frame >= 0:
		_push_iso(draws, at + Vector2(0, -18), frame, Color.WHITE)


func _prop_frame(icon: int) -> int:
	if _BIG.has(icon):
		return 96 + int(_BIG[icon])
	return 24 + icon


func _pop_frame(icon: int) -> int:
	if icon >= ThrongClips.BASE:
		return icon
	return _prop_frame(icon)


func _egg_frame(it: Dictionary) -> int:
	var stage := int(it.get("hatch", 0))
	if float(it.get("shake", 0.0)) > 0.0:
		return EGG_ANIM + 1 + int(Time.get_ticks_msec() / 90) % 2
	if stage >= 3:
		return EGG_ANIM + 4
	if stage >= 1:
		return EGG_ANIM + 3
	return EGG_ANIM


func _carry_icon(kind: int) -> int:
	if kind == Catalog.CARRY_BONE:
		return Catalog.ICON_BONE
	if kind == Catalog.CARRY_ORE:
		return Catalog.ICON_ORE
	return Catalog.ICON_WOOD


func _place_cell_poly() -> PackedVector2Array:
	var tile := Vector2(tilemap.tile_set.tile_size)
	return PackedVector2Array([
		Vector2(0.0, -tile.y * 0.5),
		Vector2(tile.x * 0.5, 0.0),
		Vector2(0.0, tile.y * 0.5),
		Vector2(-tile.x * 0.5, 0.0),
	])


func _place_footprint_kind() -> Dictionary:
	var sim: ThrongletSim = ThrongletSimServer
	if placing >= 0:
		return {"building": true, "kind": placing}
	if sim.held_kind == "building":
		var b = sim.building_by_id.get(sim.held_ref, {})
		if not b.is_empty():
			return {"building": true, "kind": int(b.kind)}
	if sim.held_kind == "rock":
		var feat = sim.feature_by_id.get(sim.held_ref, {})
		if not feat.is_empty():
			return {"building": false, "kind": int(feat.kind)}
	return {"building": true, "kind": -1}


func _ensure_place_marks(n: int) -> void:
	while place_fills.size() < n:
		var fill := Polygon2D.new()
		fill.z_index = 1
		place_marks.add_child(fill)
		place_fills.append(fill)
		var edge := Line2D.new()
		edge.z_index = 1
		edge.width = 2.0
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		place_marks.add_child(edge)
		place_edges.append(edge)


func _hide_place_marks() -> void:
	for fill in place_fills:
		fill.visible = false
	for edge in place_edges:
		edge.visible = false


func _sync_place_mark() -> void:
	if place_marks == null:
		return
	if not _want_place_grid():
		_hide_place_marks()
		return
	var sim: ThrongletSim = ThrongletSimServer
	var at := _grid_pointer()
	var building_id: int = sim.held_ref if sim.held_kind == "building" else -1
	var ignore_item: int = sim.hand_id
	var info := _place_footprint_kind()
	var kind: int = int(info.kind)
	var ok := false
	if placing >= 0:
		ok = sim.can_place_building(placing, at.x, at.y)
	elif kind >= 0 and bool(info.building):
		ok = sim.spot_ok(at.x, at.y, building_id, ignore_item, kind)
	elif kind >= 0 and not bool(info.building):
		ok = sim.can_drop_feature(sim.held_ref, at.x, at.y)
	else:
		ok = sim.spot_ok(at.x, at.y, building_id, ignore_item)
	var spots: Array = [at]
	if kind >= 0:
		spots = sim.footprint_world(kind, at.x, at.y, bool(info.building))
	_ensure_place_marks(spots.size())
	var poly := _place_cell_poly()
	var fill_c := Color(0.3, 1.0, 0.5, 0.55) if ok else Color(1.0, 0.25, 0.22, 0.55)
	var edge_c := Color(0.75, 1.0, 0.85, 1.0) if ok else Color(1.0, 0.55, 0.5, 1.0)
	for i in place_fills.size():
		if i >= spots.size():
			place_fills[i].visible = false
			place_edges[i].visible = false
			continue
		var pos := _to_iso(spots[i])
		place_fills[i].polygon = poly
		place_fills[i].color = fill_c
		place_fills[i].position = pos
		place_fills[i].visible = true
		place_edges[i].points = poly + PackedVector2Array([poly[0]])
		place_edges[i].default_color = edge_c
		place_edges[i].position = pos
		place_edges[i].visible = true


func _sync_charge_mark() -> void:
	if charge_ring == null or charge_area == null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	var at := _pointer()
	if sim.has_scoop():
		charge_area.points = _iso_circle_points(at, Catalog.GRAB_RADIUS * 0.35, 20)
		charge_area.default_color = Color(0.95, 0.9, 0.45, 0.7)
		charge_area.visible = true
		charge_ring.visible = false
		return
	var used := _charge_tool_id()
	if used < 0:
		charge_ring.visible = false
		charge_area.visible = false
		return
	var target: Dictionary = sim.charge_tool_target(used, at.x, at.y)
	if target.is_empty() and used != Catalog.TOOL_GRAB:
		charge_ring.visible = false
		charge_area.visible = false
		return
	var tx := float(target.get("x", at.x)) if not target.is_empty() else at.x
	var ty := float(target.get("y", at.y)) if not target.is_empty() else at.y
	var area_r := float(target.get("radius", 0.0)) if not target.is_empty() else 0.0
	if used == Catalog.TOOL_GRAB:
		area_r = Catalog.GRAB_RADIUS
		tx = at.x
		ty = at.y
	var center := _to_iso(Vector2(tx, ty))
	if area_r > 0.0:
		charge_area.points = _iso_circle_points(Vector2(tx, ty), area_r, 28)
		if used == Catalog.TOOL_SAW:
			charge_area.default_color = Color(1.0, 0.55, 0.2, 0.85)
		elif used == Catalog.TOOL_GRAB:
			charge_area.default_color = Color(0.95, 0.9, 0.45, 0.8)
		else:
			charge_area.default_color = Color(0.55, 0.85, 1.0, 0.8)
		charge_area.visible = true
	else:
		charge_area.visible = false
	if tool_charge > 0.02 and (used != Catalog.TOOL_GRAB or int(target.get("n", 0)) > 0):
		charge_ring.points = _charge_arc_points(center, 18.0, tool_charge)
		charge_ring.default_color = Color(1.0, 0.92, 0.35, 0.95)
		charge_ring.visible = true
	else:
		charge_ring.visible = false


func _iso_circle_points(world_center: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		var world := world_center + Vector2(cos(ang), sin(ang)) * radius
		pts.append(_to_iso(world))
	return pts


func _charge_arc_points(center_iso: Vector2, radius: float, progress: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var filled := clampf(progress, 0.0, 1.0)
	var steps := maxi(2, int(ceil(28.0 * filled)))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := -PI * 0.5 + TAU * filled * t
		pts.append(center_iso + Vector2(cos(ang), sin(ang)) * radius)
	return pts


func _bridge_view_point(world_pos: Vector2, view: Rect2) -> Vector2:
	if view.has_point(world_pos):
		return world_pos
	var center := view.get_center()
	var delta := world_pos - center
	var half := view.size * 0.38
	var scale_x := absf(delta.x) / maxf(half.x, 1.0)
	var scale_y := absf(delta.y) / maxf(half.y, 1.0)
	var scale := maxf(scale_x, scale_y)
	if scale <= 1.0:
		return world_pos
	return center + delta / scale


func _push_factory_pile(draws: Array, b: Dictionary, at: Vector2) -> void:
	var stacked := int(b.get("buffer", 0))
	if b.has("pile") and b.get("pile") is Array:
		stacked = (b.get("pile") as Array).size()
	if stacked <= 0:
		return
	# Right of the factory wall. Layer 0 is the first deposit and stays on the ground.
	var ore_at := at + Vector2(24.0, -10.0)
	var ore_sy := _to_iso(ore_at).y
	var frame := _prop_frame(Catalog.ICON_ORE_ULTRA)
	# 120 layers at 6px clear the view at the widest zoom. The rest stay in the pile.
	var drawn := mini(stacked, 120)
	for layer in drawn:
		_push_iso(draws, ore_at, frame, Color.WHITE, float(layer) * 6.0, Catalog.ORE_CLUSTER_SPRITE_SCALE, ore_sy + float(drawn - layer) * 0.05)


func _push_iso(draws: Array, world_pos: Vector2, frame: int, tint: Color, lift: float = 0.0, sprite_scale: float = 1.0, sort_y: float = NAN) -> void:
	var at := _to_iso(world_pos)
	var draw_p := Vector2(at.x, at.y - lift)
	var sy := at.y if is_nan(sort_y) else sort_y
	draws.append({"p": draw_p, "sy": sy, "icon": frame, "tint": tint, "scale": sprite_scale})


# World offset that puts the opaque middle of a frame on the anchor.
# Tall sprites are clamped to the pad so the base stays inside its cells.
const _CENTER := {
	24: Vector2(6.7, 6.7),
	25: Vector2(22.5, 22.5),
	26: Vector2(26.0, 26.0),
	27: Vector2(6.7, 6.7),
	28: Vector2(30.8, 30.8),
	29: Vector2(20.5, 20.5),
	30: Vector2(29.7, 29.7),
	31: Vector2(47.4, 47.4),
	32: Vector2(11.1, 11.1),
	33: Vector2(28.3, 28.3),
	34: Vector2(16.6, 16.6),
	35: Vector2(26.0, 26.0),
	36: Vector2(38.1, 38.1),
	37: Vector2(24.5, 24.5),
	38: Vector2(43.3, 43.3),
	39: Vector2(45.4, 45.4),
	40: Vector2(37.6, 37.6),
	41: Vector2(36.2, 36.2),
	42: Vector2(45.6, 45.6),
	43: Vector2(53.8, 53.8),
	44: Vector2(50.8, 50.8),
	45: Vector2(36.2, 36.2),
	46: Vector2(40.0, 40.0),
	47: Vector2(26.1, 26.1),
	48: Vector2(16.5, 16.5),
	49: Vector2(30.0, 30.0),
	50: Vector2(40.8, 40.8),
	51: Vector2(16.5, 16.5),
	52: Vector2(12.5, 12.5),
	53: Vector2(30.4, 30.4),
	54: Vector2(30.9, 30.9),
	55: Vector2(29.6, 29.6),
	56: Vector2(36.8, 36.8),
	57: Vector2(25.6, 25.6),
	58: Vector2(15.8, 15.8),
	59: Vector2(27.1, 27.1),
	60: Vector2(23.1, 23.1),
	61: Vector2(29.7, 29.7),
	62: Vector2(44.6, 44.6),
	63: Vector2(28.9, 28.9),
	64: Vector2(21.5, 21.5),
	65: Vector2(5.6, 5.6),
	66: Vector2(3.6, 3.6),
	67: Vector2(14.5, 14.5),
	68: Vector2(44.6, 44.6),
	69: Vector2(29.8, 29.8),
	70: Vector2(7.4, 7.4),
	71: Vector2(11.4, 11.4),
	72: Vector2(35.9, 35.9),
	73: Vector2(30.2, 30.2),
	74: Vector2(16.3, 16.3),
	75: Vector2(16.1, 16.1),
	76: Vector2(24.4, 24.4),
	77: Vector2(16.5, 16.5),
	78: Vector2(21.5, 21.5),
	79: Vector2(21.7, 21.7),
	80: Vector2(29.6, 29.6),
	81: Vector2(21.9, 21.9),
	82: Vector2(29.7, 29.7),
	83: Vector2(15.6, 15.6),
	84: Vector2(15.0, 15.0),
	85: Vector2(6.7, 6.7),
	86: Vector2(29.7, 29.7),
	87: Vector2(21.5, 21.5),
	88: Vector2(21.7, 21.7),
	89: Vector2(21.7, 21.7),
	90: Vector2(21.5, 21.5),
	91: Vector2(21.3, 21.3),
	96: Vector2(26.0, 26.0),
	97: Vector2(30.8, 30.8),
	98: Vector2(20.5, 20.5),
	99: Vector2(29.7, 29.7),
	100: Vector2(47.4, 47.4),
	101: Vector2(26.0, 26.0),
	102: Vector2(38.1, 38.1),
	103: Vector2(24.5, 24.5),
	104: Vector2(43.3, 43.3),
	105: Vector2(45.4, 45.4),
	106: Vector2(37.6, 37.6),
	107: Vector2(36.2, 36.2),
	108: Vector2(45.6, 45.6),
	109: Vector2(53.8, 53.8),
	110: Vector2(50.8, 50.8),
	111: Vector2(36.2, 36.2),
	112: Vector2(40.0, 40.0),
	113: Vector2(30.0, 30.0),
	114: Vector2(16.5, 16.5),
	115: Vector2(16.5, 16.5),
	116: Vector2(11.4, 11.4),
	117: Vector2(35.9, 35.9),
	118: Vector2(30.2, 30.2),
	119: Vector2(16.3, 16.3),
	120: Vector2(16.1, 16.1),
	121: Vector2(24.4, 24.4),
	122: Vector2(16.5, 16.5),
	123: Vector2(21.5, 21.5),
	124: Vector2(21.7, 21.7),
	125: Vector2(29.6, 29.6),
	126: Vector2(21.9, 21.9),
	127: Vector2(29.7, 29.7),
	128: Vector2(15.6, 15.6),
	129: Vector2(15.0, 15.0),
	130: Vector2(6.7, 6.7),
	131: Vector2(29.7, 29.7),
	132: Vector2(24.5, 24.5),
	133: Vector2(24.5, 24.5),
	134: Vector2(24.5, 24.5),
	135: Vector2(24.5, 24.5),
	136: Vector2(24.5, 24.5),
	137: Vector2(24.5, 24.5),
	138: Vector2(24.5, 24.5),
	139: Vector2(24.5, 24.5),
	140: Vector2(13.4, 13.4),
	141: Vector2(13.0, 13.0),
	142: Vector2(13.2, 13.2),
	143: Vector2(12.2, 12.2),
}


func _pad_nudge(frame: int, scale: float, size: Vector2i) -> Vector2:
	var raw: Vector2 = _CENTER.get(frame, Vector2.ZERO)
	var dsy := (raw.x + raw.y) * 0.5
	var half_h := 4.0 * float(size.x + size.y)
	if dsy > half_h and dsy > 0.0:
		raw *= half_h / dsy
	return raw * scale


func _building_draw_at(kind: int, origin: Vector2) -> Vector2:
	var size := Catalog.footprint_for_building(kind)
	var frame := _prop_frame(Catalog.icon_for_building(kind))
	var scale := Catalog.building_sprite_scale(kind)
	return origin + Catalog.footprint_center(size) + _pad_nudge(frame, scale, size) + Catalog.building_draw_off(kind)


func _feature_draw_at(kind: int, origin: Vector2, ore: int = 0) -> Vector2:
	var size := Catalog.footprint_for_feature(kind)
	var frame := FIRE_ANIM if kind == Catalog.FEAT_FIRE else _prop_frame(Catalog.icon_for_feature(kind, ore))
	var scale := Catalog.feature_sprite_scale(kind, ore)
	return origin + Catalog.footprint_center(size) + _pad_nudge(frame, scale, size) + Catalog.feature_draw_off(kind, ore)


func _item_draw_at(kind: int, origin: Vector2) -> Vector2:
	var frame := EGG_ANIM if kind == Catalog.ITEM_EGG else _prop_frame(Catalog.icon_for_item(kind))
	var scale := Catalog.item_sprite_scale(kind)
	return origin + _pad_nudge(frame, scale, Vector2i(1, 1)) + Catalog.item_draw_off(kind)


func _prop_front_sort_y(world_center: Vector2) -> float:
	return _to_iso(world_center).y + 1.0


func _use_prop_anchor(pos: Vector2) -> Vector2:
	var sim: ThrongletSim = ThrongletSimServer
	var best := Vector2.ZERO
	var best_d := 28.0
	var found := false
	for b in sim.buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind != Catalog.BLD_TUB and kind != Catalog.BLD_ROUND:
			continue
		var center := Vector2(float(b.x), float(b.y))
		if kind == Catalog.BLD_TUB:
			center += Catalog.TUB_SEAT_OFF
		var limit := 18.0 if kind == Catalog.BLD_TUB else 28.0
		var d := pos.distance_to(center)
		if d <= limit and d < best_d:
			best_d = d
			best = _building_draw_at(kind, Vector2(float(b.x), float(b.y)))
			found = true
	return best if found else Vector2.INF


const _BIG := {
	Catalog.ICON_TREE: 0,
	Catalog.ICON_ROCK: 1,
	Catalog.ICON_ORE_ROCK: 2,
	Catalog.ICON_NODE: 3,
	Catalog.ICON_SUPER: 4,
	Catalog.ICON_APPLE_TREE: 5,
	Catalog.ICON_TUB: 6,
	Catalog.ICON_ROUND: 7,
	Catalog.ICON_DWELL: 8,
	Catalog.ICON_FANCY: 9,
	Catalog.ICON_MINE: 10,
	Catalog.ICON_MINE2: 11,
	Catalog.ICON_FACTORY: 12,
	Catalog.ICON_FACTORY2: 13,
	Catalog.ICON_THEATRE: 14,
	Catalog.ICON_CANNON: 15,
	Catalog.ICON_MARKET: 16,
	Catalog.ICON_MONOLITH: 17,
	Catalog.ICON_STATUE: 18,
	Catalog.ICON_GOO: 19,
	Catalog.ICON_BIGROCK: 20,
	Catalog.ICON_COSMETIC: 21,
	Catalog.ICON_COSMETIC_BAD: 22,
	Catalog.ICON_ORE_MEGA: 23,
	Catalog.ICON_ORE_SUPER: 24,
	Catalog.ICON_ORE_ULTRA: 25,
	Catalog.ICON_WOOD_STATUE: 26,
	Catalog.ICON_FIRE: 27,
	Catalog.ICON_TOTEM: 28,
	Catalog.ICON_CURER: 29,
	Catalog.ICON_JACK: 30,
	Catalog.ICON_SUPERBUG: 31,
	Catalog.ICON_THEATRE2: 32,
	Catalog.ICON_MAW: 33,
	Catalog.ICON_MSTUMP: 34,
	Catalog.ICON_MNODE: 35,
}


func _throng_dirty(clean: float) -> float:
	return 1.0 - clampf(clean / 100.0, 0.0, 1.0)


func _throng_sprite_scale(frame: int) -> float:
	if frame == 652 or frame == 653:
		return 0.7
	return THRONG_SPRITE_SCALE


func _throng_sprite_off(frame: int) -> Vector2:
	if frame >= 229 and frame <= 262:
		return Vector2(21.0, 21.0)
	if frame >= 263 and frame <= 298:
		return Vector2(24.0, 24.0)
	if frame >= 342 and frame <= 349:
		return Vector2(15.0, 15.0)
	if frame >= 492 and frame <= 494:
		return Vector2(3.0, 3.0)
	if frame >= 540 and frame <= 547:
		return Vector2(-8.0, -4.0)
	return Vector2.ZERO


func _sync_monolith(id: int, world_pos: Vector2) -> void:
	var node: Node2D = _monoliths.get(id)
	if node == null:
		node = (load("res://monolith_prop.gd") as GDScript).new()
		world_layer.add_child(node)
		_monoliths[id] = node
	node.position = _to_iso(world_pos)
	node.visible = true
	node.set_meta("seen", true)


func _paint_props(draws: Array) -> void:
	var live: Array = []
	for id in _monoliths.keys():
		var node: Node2D = _monoliths[id]
		if not bool(node.get_meta("seen", false)):
			node.visible = false
			continue
		node.set_meta("seen", false)
		live.append({"sy": node.position.y, "node": node})
	live.sort_custom(func(a, b): return float(a.sy) < float(b.sy))
	var cursor := 0
	var order: Array = []
	for i in live.size():
		var chunk: Array = []
		var sy := float(live[i].sy)
		while cursor < draws.size() and float(draws[cursor].get("sy", draws[cursor].p.y)) <= sy:
			chunk.append(draws[cursor])
			cursor += 1
		var band := _prop_band(i)
		_write_mesh(band.multimesh, chunk)
		band.visible = true
		order.append(band)
		order.append(live[i].node)
	var rest: Array = []
	while cursor < draws.size():
		rest.append(draws[cursor])
		cursor += 1
	var tail := _prop_band(live.size())
	_write_mesh(tail.multimesh, rest)
	tail.visible = true
	order.append(tail)
	for j in range(live.size() + 1, _prop_bands.size()):
		_write_mesh(_prop_bands[j].multimesh, [])
		_prop_bands[j].visible = false
	for i in order.size():
		world_layer.move_child(order[i], i)


func _prop_band(index: int) -> MultiMeshInstance2D:
	while _prop_bands.size() <= index:
		var band := MultiMeshInstance2D.new()
		band.material = world.material
		band.texture = world.texture
		band.multimesh = _mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
		world_layer.add_child(band)
		_prop_bands.append(band)
	return _prop_bands[index]


func _write_mesh(mesh: MultiMesh, draws: Array) -> void:
	var n := draws.size()
	if mesh.instance_count < n:
		mesh.instance_count = maxi(16, n)
	mesh.visible_instance_count = n
	var xf := Transform2D()
	for i in n:
		var sprite_scale := float(draws[i].get("scale", 1.0))
		var flip := float(draws[i].get("flip", 1.0))
		var rot := deg_to_rad(float(draws[i].get("rot", 0.0)))
		var center := Vector2(0, -WORLD_CELL * 0.5 * sprite_scale).rotated(rot)
		xf = Transform2D(rot, Vector2(sprite_scale * flip, sprite_scale), 0.0, draws[i].p + center)
		mesh.set_instance_transform_2d(i, xf)
		mesh.set_instance_custom_data(i, Color(float(draws[i].icon), float(draws[i].get("dirty", 0.0)), 0, 0))
		mesh.set_instance_color(i, draws[i].tint)


func _sync_hud(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	pop_label.text = "?" if sim.count_unknown else str(sim.living)
	var face_key := "base"
	if sim.living <= 0:
		face_key = "cry" if sim.peak > 0 else "base"
	elif sim.frozen:
		face_key = "trance"
	elif _camera_biome() == "epilogue":
		var faces := ["epilogue_caretaker", "epilogue_bewildered", "epilogue_angry", "epilogue_birthday", "epilogue_capitalist"]
		face_key = faces[int(Time.get_ticks_msec() / 2400) % faces.size()]
	elif POP_FACES.has(sim.mood_face):
		face_key = sim.mood_face
	if face_key != pop_face_key:
		pop_face_key = face_key
		pop_face.texture = _tex(POP_FACES[face_key])
	gem_panel.visible = sim.part_two
	gem_label.text = str(sim.gems)
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
		if _is_charge_tool(drag_id):
			if drag_id == Catalog.TOOL_GRAB:
				info = "MANO  MANTEN SOBRE OBJETOS DEL SUELO"
				if tool_charge > 0.0:
					info = "MANO  %.0f%%  x%d" % [tool_charge * 100.0, maxi(tool_charge_n, 1)]
			elif tool_charge > 0.0:
				info = "%s  %.0f%%" % [_kit_drag_label(), tool_charge * 100.0]
				if tool_charge_n > 1:
					info += "  x%d" % tool_charge_n
			else:
				info = "MANTEN SOBRE EL OBJETIVO  " + _kit_drag_label()
		else:
			info = "SUELTA EN LA REJILLA  " + _kit_drag_label()
	elif _is_charge_tool(tool) and tool_charge > 0.0:
		info = "CARGANDO  %.0f%%" % (tool_charge * 100.0)
		if tool_charge_n > 1:
			info += "  x%d" % tool_charge_n
	elif _want_place_grid():
		info = "REJILLA ACTIVA  SUELTA EN UNA CELDA"
	hint.text = info
	if sim.save_pulse != save_pulse_seen:
		save_pulse_seen = sim.save_pulse
		save_flash_t = 1.6
	if save_flash_t > 0.0:
		save_flash_t -= delta
	if save_icon != null:
		save_icon.visible = save_flash_t > 0.0 and menu_button != null and menu_button.visible
	for note in sim.take_notes():
		toast_queue.append(str(note))
		_play("console")
	if toast_t <= 0.0 and not toast_queue.is_empty():
		toast_msg = str(toast_queue.pop_front())
		toast_t = 2.8
	if toast_t > 0.0:
		toast_t -= delta
	toast.visible = toast_t > 0.0
	toast.text = toast_msg
	if bar_serial != sim.unlock_serial:
		bar_serial = sim.unlock_serial
		_rebuild_bars()
	_sync_market_sign(sim)
	_mark_selected()


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


func _build_console_frame(panel: Control, edge: float = 2.0, pattern: int = -1) -> void:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var fill := ColorRect.new()
	fill.color = Color(0.0, 0.02, 0.0, 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = edge
	fill.offset_top = edge
	fill.offset_right = -edge
	fill.offset_bottom = -edge
	frame.add_child(fill)
	var ink := Color(0.0, 224.0 / 255.0, 0.0)
	_console_rule(frame, true, false, edge, ink)
	_console_rule(frame, true, true, edge, ink)
	_console_rule(frame, false, false, edge, ink)
	_console_rule(frame, false, true, edge, ink)
	if pattern >= 0:
		panel.clip_contents = true
		panel.set_meta("pattern", pattern)
		_add_swirls(panel, pattern)
		_add_side_glyphs(panel, edge)
		_add_corner_glyphs(panel, pattern)


func _console_rule(frame: Control, horizontal: bool, at_end: bool, thick: float, ink: Color) -> void:
	var bar := ColorRect.new()
	bar.color = ink
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		bar.anchor_right = 1.0
		if at_end:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -thick
		else:
			bar.offset_bottom = thick
	elif at_end:
		bar.anchor_left = 1.0
		bar.anchor_right = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_left = -thick
	else:
		bar.anchor_bottom = 1.0
		bar.offset_right = thick
	frame.add_child(bar)


func _add_swirls(panel: Control, pattern: int) -> void:
	var atlas := "res://resources/src/ref/atlas/Sprites-ConsoleUI/"
	if pattern == 0:
		_swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background_Left.png", "swirl_l")
	_swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background_Right.png", "swirl_r")
	var line := _swirl_rect(panel, atlas + "UI_DialogueUI_E_SwirlFX_Background.png", "swirl_line")
	line.anchor_right = 1.0


func _swirl_rect(panel: Control, path: String, node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = _tex(path)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.anchor_top = 0.0
	rect.anchor_bottom = 0.0
	if node_name.ends_with("_r"):
		rect.anchor_left = 1.0
		rect.anchor_right = 1.0
	panel.add_child(rect)
	return rect


func _add_side_glyphs(panel: Control, edge: float) -> void:
	var atlas := "res://resources/src/ref/atlas/Sprites-ConsoleUI/"
	_side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Left_Background_Map.png", true, edge, "side_back_l")
	_side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Right_Background_Map.png", false, edge, "side_back_r")
	_side_glyph(panel, atlas + "UI_DialogueUI_UI_E_AddlGlyphs_Left_Foreground_Map.png", true, edge, "side_glyph_l")
	_side_glyph(panel, atlas + "UI_DialogueUI_E_AddlGlyphs_Right_Foreground_Map.png", false, edge, "side_glyph_r")


func _side_glyph(panel: Control, path: String, left: bool, edge: float, node_name: String) -> void:
	var strip := TextureRect.new()
	strip.name = node_name
	strip.texture = _tex(path)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.anchor_top = 0.0
	strip.anchor_bottom = 0.0
	if left:
		strip.anchor_left = 0.0
		strip.anchor_right = 0.0
	else:
		strip.anchor_left = 1.0
		strip.anchor_right = 1.0
	strip.offset_top = edge
	strip.offset_bottom = edge
	strip.set_meta("edge", edge)
	panel.add_child(strip)


func _add_corner_glyphs(panel: Control, pattern: int) -> void:
	var presets: Array[int] = [
		Control.PRESET_TOP_LEFT,
		Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT,
		Control.PRESET_BOTTOM_RIGHT,
	]
	for i in presets.size():
		var glyph := TextureRect.new()
		glyph.name = "corner_%d" % i
		glyph.set_anchors_preset(presets[i])
		glyph.flip_h = i == 0 or i == 2
		glyph.flip_v = i <= 1
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.self_modulate = Color(0.0, 1.0, 0.0)
		glyph.set_meta("corner", i)
		glyph.set_meta("phase", pattern * 2)
		if not console_glyphs.is_empty():
			glyph.texture = console_glyphs[i % console_glyphs.size()]
		console_corner_glyphs.append(glyph)
		panel.add_child(glyph)


func _fit_corner_glyphs(panel: Control, height: float) -> void:
	var size := minf(36.0, maxf(14.0, height * 0.42))
	for child in panel.get_children():
		var glyph := child as TextureRect
		if glyph == null or not str(glyph.name).begins_with("corner_"):
			continue
		var corner := int(glyph.get_meta("corner", 0))
		var right := corner == 1 or corner == 3
		var bottom := corner >= 2
		glyph.offset_left = -size if right else 0.0
		glyph.offset_right = 0.0 if right else size
		glyph.offset_top = -size if bottom else 0.0
		glyph.offset_bottom = 0.0 if bottom else size


func _fit_console_art(panel: Control, panel_h: float, slot_h: float) -> void:
	var pattern := int(panel.get_meta("pattern", 0))
	var shift_l := 0.0
	var shift_r := 0.0
	if pattern == 1:
		shift_l = 0.08
		shift_r = 0.62
	elif pattern == 2:
		shift_l = 0.48
		shift_r = 0.18
	elif pattern >= 3:
		shift_l = 0.72
		shift_r = 0.40
	var slide := 0.0 if pattern == 0 else float(pattern - 1) * slot_h
	_fit_swirls(panel, panel_h, slot_h, slide)
	_fit_side_glyphs(panel, panel_h, shift_l, shift_r)
	_fit_corner_glyphs(panel, slot_h)


func _fit_swirls(panel: Control, panel_h: float, slot_h: float, slide: float) -> void:
	var pattern := int(panel.get_meta("pattern", 0))
	var edge := 2.0
	var inner := maxf(8.0, panel_h - edge * 2.0)
	for child in panel.get_children():
		var rect := child as TextureRect
		if rect == null or not str(rect.name).begins_with("swirl_"):
			continue
		if str(rect.name) == "swirl_line":
			var along := 0.55 if pattern == 0 else float((pattern - 1) % 3) / 2.0
			var y := edge + maxf(0.0, slot_h - edge * 2.0 - 4.0) * along
			rect.offset_left = edge
			rect.offset_right = -edge
			rect.offset_top = y
			rect.offset_bottom = y + 4.0
			continue
		var tex := rect.texture
		if tex == null or tex.get_height() <= 0:
			continue
		var width := inner * float(tex.get_width()) / float(tex.get_height())
		rect.offset_top = edge - slide
		rect.offset_bottom = edge - slide + inner
		if str(rect.name).ends_with("_l"):
			rect.offset_left = edge
			rect.offset_right = edge + width
		else:
			rect.offset_right = -edge
			rect.offset_left = -(edge + width)


func _fit_side_glyphs(panel: Control, height: float, shift_l: float = 0.0, shift_r: float = 0.0) -> void:
	for child in panel.get_children():
		var strip := child as TextureRect
		if strip == null or not str(strip.name).begins_with("side_"):
			continue
		var tex := strip.texture
		if tex == null or tex.get_height() <= 0:
			continue
		var edge := float(strip.get_meta("edge", 3.0))
		var inner := maxf(8.0, height - edge * 2.0)
		var width := inner * float(tex.get_width()) / float(tex.get_height())
		var shift := shift_l if str(strip.name).ends_with("_l") else shift_r
		strip.offset_top = edge - shift * inner
		strip.offset_bottom = strip.offset_top + inner
		if str(strip.name).ends_with("_l"):
			strip.offset_left = edge
			strip.offset_right = edge + width
		else:
			strip.offset_right = -edge
			strip.offset_left = -(edge + width)


func _pin_glyphs(panel: Control, size: float) -> void:
	var corners: Array[int] = [
		Control.PRESET_TOP_LEFT,
		Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT,
		Control.PRESET_BOTTOM_RIGHT,
	]
	for i in corners.size():
		var glyph := TextureRect.new()
		glyph.set_anchors_preset(corners[i])
		glyph.flip_h = i == 1 or i == 3
		glyph.flip_v = i >= 2
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.offset_left = -size if glyph.flip_h else 0.0
		glyph.offset_right = 0.0 if glyph.flip_h else size
		glyph.offset_top = -size if glyph.flip_v else 0.0
		glyph.offset_bottom = 0.0 if glyph.flip_v else size
		if not console_glyphs.is_empty():
			glyph.texture = console_glyphs[i % console_glyphs.size()]
		panel.add_child(glyph)
		console_corner_glyphs.append(glyph)
	if size < 40.0:
		return
	for side in 2:
		var glyph := TextureRect.new()
		glyph.anchor_top = 0.5
		glyph.anchor_bottom = 0.5
		glyph.anchor_left = 0.0 if side == 0 else 1.0
		glyph.anchor_right = glyph.anchor_left
		glyph.flip_h = side == 1
		glyph.offset_left = -size if side == 1 else 0.0
		glyph.offset_right = 0.0 if side == 1 else size
		glyph.offset_top = -size * 0.5
		glyph.offset_bottom = size * 0.5
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not console_glyphs.is_empty():
			glyph.texture = console_glyphs[side % console_glyphs.size()]
		panel.add_child(glyph)
		console_corner_glyphs.append(glyph)


func _on_console_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var sim: ThrongletSim = ThrongletSimServer
	if sim.modal.is_empty():
		return
	var naming := str(sim.modal.get("event", "")) == "player_name" and str(sim.modal.get("step", "")) == "echo"
	if not naming and not sim.modal.has("lines"):
		return
	_play("console_select")
	sim.choose(0)
	get_viewport().set_input_as_handled()


func _sync_gaze() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.game_over or sim.modal.is_empty():
		if shown_event != "":
			_play("dialogue_out")
		gaze_panel.visible = false
		shown_event = ""
		shown_seq = 0
		console_line = ""
		return
	var event := str(sim.modal.event)
	var seq := int(sim.modal.get("seq", 1))
	if event != shown_event or seq != shown_seq:
		if event != shown_event:
			if shown_event != "":
				_play("dialogue_out")
			_play("dialogue_in")
		else:
			_play("console")
		shown_event = event
		shown_seq = seq
		for child in gaze_box.get_children():
			child.queue_free()
		var session := {
			"tree": str(sim.modal.get("tree", "")),
			"node": str(sim.modal.get("node", "")),
			"log": sim.modal.get("log", []),
			"seq": seq,
		}
		console_line = sim.address(DialogueBook.log_text(session)).replace("[", "(").replace("]", ")")
		console_reveal = 1
		var line_talk: bool = sim.modal.has("lines")
		if gaze_face != null:
			gaze_face.visible = not line_talk
			gaze_face.custom_minimum_size = Vector2.ZERO if line_talk else Vector2(72, 72)
			if not line_talk:
				var face_key := "epilogue_caretaker"
				if POP_FACES.has(sim.mood_face):
					face_key = sim.mood_face
				elif bool(sim.mutations.get("care", false)):
					face_key = "epilogue_caretaker"
				elif bool(sim.mutations.get("numb", false)) or bool(sim.mutations.get("hard", false)):
					face_key = "epilogue_angry"
				gaze_face.texture = _tex(POP_FACES[face_key])
		var choices: Array = [] if line_talk else DialogueBook.choices_of(session)
		var naming := event == "player_name"
		var name_step := str(sim.modal.get("step", ""))
		if naming:
			if gaze_face != null:
				gaze_face.visible = false
				gaze_face.custom_minimum_size = Vector2.ZERO
			if name_step == "ask":
				choices = [{"label": LineBook.row("SYS.PLAYERINPUT", 1)}]
			elif name_step == "confirm":
				choices = [
					{"label": LineBook.row("SYS.PLAYERINPUT", 3)},
					{"label": LineBook.row("SYS.PLAYERINPUT", 4)},
				]
			else:
				choices = []
			if name_edit != null:
				name_edit.visible = name_step == "ask"
				if name_step == "ask":
					name_edit.text = str(sim.modal.get("draft", ""))
					name_edit.grab_focus()
		elif name_edit != null:
			name_edit.visible = false
		var ink := Color(0.22, 0.86, 0.28)
		var flat := StyleBoxEmpty.new()
		flat.content_margin_left = 32
		flat.content_margin_right = 22
		flat.content_margin_top = 10
		flat.content_margin_bottom = 8
		for i in choices.size():
			var edge: Dictionary = choices[i] if choices[i] is Dictionary else {}
			var slot := Control.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.clip_contents = true
			_build_console_frame(slot, 2.0, i + 1)
			var button := Button.new()
			button.set_anchors_preset(Control.PRESET_FULL_RECT)
			button.text = str(edge.get("label", ""))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_color_override("font_color", ink)
			button.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.7))
			button.add_theme_color_override("font_focus_color", Color(0.7, 1.0, 0.7))
			button.add_theme_color_override("font_pressed_color", Color(0.1, 0.45, 0.16))
			button.add_theme_color_override("font_hover_pressed_color", Color(0.1, 0.45, 0.16))
			button.add_theme_stylebox_override("normal", flat)
			button.add_theme_stylebox_override("hover", flat)
			button.add_theme_stylebox_override("focus", flat)
			button.add_theme_stylebox_override("pressed", flat)
			button.add_theme_stylebox_override("hover_pressed", flat)
			var index := i
			button.pressed.connect(func():
				_play("console_select")
				if name_edit != null and name_edit.visible:
					ThrongletSimServer.modal["draft"] = name_edit.text
				ThrongletSimServer.choose(index)
			)
			slot.add_child(button)
			gaze_box.add_child(slot)
	if console_line != "":
		console_reveal = mini(console_line.length(), console_reveal + 4)
		gaze_text.clear()
		gaze_text.add_theme_font_size_override("normal_font_size", 16)
		gaze_text.add_theme_color_override("default_color", Color(0.22, 0.86, 0.28))
		gaze_text.append_text(console_line.substr(0, console_reveal))
	if not console_glyphs.is_empty():
		var tick := int(Time.get_ticks_msec() / 160)
		var alive: Array[TextureRect] = []
		for i in console_corner_glyphs.size():
			var glyph: TextureRect = console_corner_glyphs[i]
			if not is_instance_valid(glyph):
				continue
			var phase := int(glyph.get_meta("phase", 0))
			glyph.texture = console_glyphs[(tick + i + phase) % console_glyphs.size()]
			alive.append(glyph)
		console_corner_glyphs = alive
	gaze_panel.visible = true
	_layout_console()


func _layout_console() -> void:
	if gaze_log == null or gaze_box == null:
		return
	var width := gaze_panel.offset_right - gaze_panel.offset_left
	var count := 0
	for child in gaze_box.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	var gap := 4.0
	gaze_log.offset_left = 0.0
	gaze_log.offset_top = 0.0
	gaze_log.offset_bottom = 0.0
	var panel_h := gaze_panel.offset_bottom - gaze_panel.offset_top
	if count <= 0 or width < 32.0:
		gaze_log.offset_right = 0.0
		gaze_box.visible = false
		_fit_console_art(gaze_log, panel_h, panel_h)
		return
	var choice_w := int(width * 0.4)
	gaze_log.offset_right = -(choice_w + gap)
	gaze_box.visible = true
	gaze_box.offset_left = -choice_w
	gaze_box.offset_right = 0.0
	gaze_box.offset_top = 0.0
	gaze_box.offset_bottom = 0.0
	_fit_console_art(gaze_log, panel_h, panel_h)
	var slot_h := (panel_h - gap * float(count - 1)) / float(count)
	for child in gaze_box.get_children():
		if child is Control and not child.is_queued_for_deletion():
			_fit_console_art(child, panel_h, slot_h)


func _sync_focus(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.game_over:
		focus_on = false
		focus_hold = 0.0
		focus_dim.visible = false
		focus_frame.visible = false
		focus_box.visible = false
		task_panel.visible = false
		return
	var talk: bool = not sim.modal.is_empty() and Catalog.GAZE.has(str(sim.modal.event))
	var egg := _starter_egg()
	var falling := not egg.is_empty() and float(egg.get("air", 0.0)) > 0.0
	if falling:
		focus_hold = 0.45
	elif focus_hold > 0.0:
		focus_hold = maxf(0.0, focus_hold - delta)
	var show_egg: bool = not talk and not egg.is_empty() and (falling or focus_hold > 0.0)
	var show: bool = talk or show_egg or sim.tutorial_i >= 0
	if show and not focus_on:
		focus_on = true
	if not show and focus_on:
		focus_on = false
		focus_hold = 0.0
	focus_dim.visible = show
	focus_frame.visible = show
	focus_box.visible = show
	task_panel.visible = not talk and sim.tutorial_i < 0
	if show:
		focus_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		focus_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not show:
		return
	var frame := _focus_frame_rect(talk)
	_set_box(focus_frame, frame)
	if sign_button != null:
		var signing := sim.tutorial_i >= 0 and not talk
		sign_button.visible = signing
		if signing:
			sign_button.text = sim.tutorial_line()
			sign_button.position = frame.position + Vector2(40, frame.size.y - 98)
			sign_button.size = Vector2(frame.size.x - 80, 64)
	var inner := frame.grow(-22.0)
	var hole := inner
	if talk:
		var view := get_viewport_rect().size
		var console_h := maxf(132.0, round(view.y * 0.34))
		var text := Rect2(Vector2(8.0, view.y - console_h - 4.0), Vector2(view.x - 16.0, console_h))
		_set_box(gaze_panel, text)
		_layout_console()
		hole = Rect2(inner.position, Vector2(inner.size.x, maxf(64.0, text.position.y - inner.position.y)))
	var view_size := get_viewport_rect().size
	var uv_pos := hole.position / view_size
	var uv_end := hole.end / view_size
	focus_shade.set_shader_parameter("hole", Vector4(uv_pos.x, uv_pos.y, uv_end.x, uv_end.y))
	_set_box(focus_box, hole)
	var pix := Vector2i(maxi(int(hole.size.x), 8), maxi(int(hole.size.y), 8))
	if focus_port.size != pix:
		focus_port.size = pix
	var zoom := 2.7 if talk else 3.4
	var subject := _talk_iso() if talk else _egg_iso(egg)
	focus_cam_node.zoom = Vector2(zoom, zoom)
	focus_cam_node.position = subject.snapped(Vector2(1.0 / zoom, 1.0 / zoom))
	var anchor := _talk_world() if talk else Vector2(float(egg.x), float(egg.y))
	_paint_focus(anchor)
	_write_mesh(focus_mesh, _focus_draws())


func _focus_frame_rect(talk: bool) -> Rect2:
	var view := get_viewport_rect().size
	var size := Vector2(500, 340) if talk else Vector2(360, 220)
	var origin := (view - size) * 0.5
	if not talk:
		origin.y = maxf(origin.y, 68.0)
	else:
		origin.y = 8.0
	origin = origin.round()
	size = size.round()
	return Rect2(origin, size)


func _starter_egg() -> Dictionary:
	for it in ThrongletSimServer.items:
		if it.dead or int(it.kind) != Catalog.ITEM_EGG:
			continue
		if bool(it.get("fixed", false)):
			return it
	return {}


func _egg_iso(it: Dictionary) -> Vector2:
	var at := _to_iso(Vector2(float(it.x), float(it.y)))
	at.y -= float(it.get("air", 0.0)) + 8.0
	return at


func _talk_iso() -> Vector2:
	var at := _to_iso(_talk_world())
	at.y -= 14.0
	return at


func _talk_world() -> Vector2:
	var sim: ThrongletSim = ThrongletSimServer
	var sum := Vector2.ZERO
	var n := 0
	for key in sim.gaze_home.keys():
		var i := int(key)
		if i < 0 or i >= sim.slot_count:
			continue
		sum += Vector2(sim.pos_x[i], sim.pos_y[i])
		n += 1
	if n == 0:
		return Vector2(256, 256)
	return sum / float(n)


func _paint_focus(anchor: Vector2) -> void:
	focus_tilemap.clear()
	for cell in focus_path_nodes.keys():
		_drop_path_at(cell, false)
	var sim: ThrongletSim = ThrongletSimServer
	var key: String = sim.chunk_key_at(anchor.x, anchor.y)
	if sim.chunk_shown(key):
		_paint_chunk(key, false, focus_tilemap)


func _focus_sees(world_pos: Vector2, lift: float) -> bool:
	var at := _to_iso(world_pos)
	at.y -= lift
	var half := Vector2(focus_port.size) / focus_cam_node.zoom * 0.5 + Vector2(40.0, 48.0)
	var delta := at - focus_cam_node.position
	return absf(delta.x) <= half.x and absf(delta.y) <= half.y


func _focus_draws() -> Array:
	var sim: ThrongletSim = ThrongletSimServer
	var talk: bool = not sim.modal.is_empty() and Catalog.GAZE.has(str(sim.modal.event))
	var draws: Array = []
	var egg_front: Array = []
	var time := Time.get_ticks_msec() / 1000.0
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		if talk and _talk_hides_feat(int(feat.kind)):
			continue
		var p := Vector2(float(feat.x), float(feat.y))
		if int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		var feat_at := _feature_draw_at(int(feat.kind), p, int(feat.ore))
		if not _focus_sees(p, 0.0) and not _focus_sees(feat_at, 0.0):
			continue
		var feat_frame := _feature_frame(int(feat.kind), time, int(feat.ore))
		if feat_frame < 0:
			feat_frame = _prop_frame(Catalog.icon_for_feature(int(feat.kind), int(feat.ore)))
		if int(feat.kind) == Catalog.FEAT_FIRE and feat_frame < 0:
			feat_frame = FIRE_ANIM + int(time * 8.0) % 4
		_push_iso(draws, feat_at, feat_frame, Color.WHITE, 0.0, Catalog.feature_sprite_scale(int(feat.kind), int(feat.ore)))
		_push_glitch_fumes(draws, int(feat.kind), feat_at, time)
		_push_anomaly_ray(draws, int(feat.kind), feat_at)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var lift := float(it.get("air", 0.0))
		var p2 := _item_draw_at(int(it.kind), Vector2(float(it.x), float(it.y)))
		if not _focus_sees(p2, lift):
			continue
		var item_frame := _prop_frame(Catalog.icon_for_item(int(it.kind)))
		var item_scale := Catalog.item_sprite_scale(int(it.kind))
		if int(it.kind) == Catalog.ITEM_EGG:
			item_frame = _egg_frame(it)
			if lift > 0.0:
				_push_iso(egg_front, p2, item_frame, Color.WHITE, lift, item_scale)
				continue
		elif int(it.kind) == Catalog.ITEM_APPLE and lift > 0.0:
			_push_iso(egg_front, p2, item_frame, Color.WHITE, lift, item_scale)
			continue
		_push_iso(draws, p2, item_frame, Color.WHITE, lift, item_scale)
	for b in sim.buildings:
		if talk or b.dead or bool(b.get("lifted", false)):
			continue
		var p3 := Vector2(float(b.x), float(b.y))
		var b_kind := int(b.kind)
		var draw_at := _building_draw_at(b_kind, p3)
		if _focus_sees(p3, 0.0) or _focus_sees(draw_at, 0.0):
			_push_iso(draws, draw_at, _prop_frame(Catalog.icon_for_building(b_kind)), Color.WHITE, 0.0, Catalog.building_sprite_scale(b_kind))
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT:
			continue
		if talk and not sim.gaze_home.has(i):
			continue
		var pos := Vector2(sim.pos_x[i], sim.pos_y[i])
		if not _focus_sees(pos, 0.0):
			continue
		var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
		if sim.state[i] == Catalog.ST_DEAD:
			tint = Color.WHITE
		var throng_frame := _frame(i, time)
		_push_iso(draws, pos + _throng_sprite_off(throng_frame), throng_frame, tint, 0.0, _throng_sprite_scale(throng_frame))
		draws[draws.size() - 1]["flip"] = _throng_flip(i)
		draws[draws.size() - 1]["dirty"] = _throng_dirty(sim.clean[i])
	draws.sort_custom(func(a, b): return float(a.get("sy", a.p.y)) < float(b.get("sy", b.p.y)))
	draws.append_array(egg_front)
	return draws


func _talk_hides_feat(kind: int) -> bool:
	return kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD or kind == Catalog.FEAT_MONOLITH or kind == Catalog.FEAT_TOTEM


func _set_box(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y


func _kit_tabs() -> Array:
	return [
		{"label": "CUIDA", "title": "CUIDADOS", "tools": [Catalog.TOOL_APPLE, Catalog.TOOL_BALL, Catalog.TOOL_SPONGE], "builds": []},
		{"label": "UTIL", "title": "HERRAMIENTAS", "tools": [Catalog.TOOL_AXE, Catalog.TOOL_HAMMER, Catalog.TOOL_PICK, Catalog.TOOL_SAW, Catalog.TOOL_GRAB, Catalog.TOOL_MOP], "builds": []},
		{"label": "OBRA", "title": "CONSTRUCCION", "tools": [], "builds": [Catalog.BLD_DWELL, Catalog.BLD_FANCY, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2, Catalog.BLD_THEATRE, Catalog.BLD_MARKET, Catalog.BLD_FLOWER, Catalog.BLD_STATUE]},
		{"label": "HOGAR", "title": "CUIDADOS EXTRA", "tools": [], "builds": [Catalog.BLD_TUB, Catalog.BLD_APPLE, Catalog.BLD_ROUND]},
		{"label": "BUGS", "title": "ESPECIALES", "tools": [Catalog.TOOL_BUG, Catalog.TOOL_SWARM, Catalog.TOOL_TNT, Catalog.TOOL_NUKE], "builds": []},
	]


func _tool_entry(id: int) -> Dictionary:
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == id:
			return entry
	return {}


func _tab_ready(tab: Dictionary) -> bool:
	var sim: ThrongletSim = ThrongletSimServer
	for id in tab.tools:
		var entry := _tool_entry(int(id))
		if not entry.is_empty() and bool(sim.unlocks.get(str(entry.unlock), false)):
			return true
	for id in tab.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if not info.is_empty() and bool(sim.unlocks.get(str(info.unlock), false)):
			return true
	return false


func _ready_tabs() -> Array:
	var ready: Array = []
	var tabs := _kit_tabs()
	for i in tabs.size():
		if _tab_ready(tabs[i]):
			ready.append(i)
	return ready


func _tab_icon(label: String) -> String:
	match label:
		"CUIDA":
			return "res://resources/ui/tab_care.png"
		"UTIL":
			return "res://resources/ui/tab_tools.png"
		"OBRA":
			return "res://resources/ui/tab_build.png"
		"HOGAR":
			return "res://resources/ui/tab_home.png"
		_:
			return "res://resources/ui/tab_dev.png"


func _tray_face(icon: int, pad: float = 8.0) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.texture = _atlas_icon(icon)
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = pad
	glyph.offset_top = pad
	glyph.offset_right = -pad
	glyph.offset_bottom = -pad
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


func _tray_button() -> Button:
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


const TRAY_FRAME := 5


func _tray_tex(path: String, src_frame: int) -> Texture2D:
	var key := "%s#%d" % [path, src_frame]
	if textures.has(key):
		return textures[key]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return _tex(path)
	var width := maxi(img.get_width() * TRAY_FRAME / src_frame, TRAY_FRAME * 2 + 1)
	var height := maxi(img.get_height() * TRAY_FRAME / src_frame, TRAY_FRAME * 2 + 1)
	img.resize(width, height, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	textures[key] = tex
	return tex


func _tray_style(path: String, src_frame: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _tray_tex(path, src_frame)
	style.texture_margin_left = TRAY_FRAME
	style.texture_margin_top = TRAY_FRAME
	style.texture_margin_right = TRAY_FRAME
	style.texture_margin_bottom = TRAY_FRAME
	return style


func _tray_cell(icon: int, wide: float, tall: float, kind: String, glyph: Texture2D = null) -> Button:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(wide, tall)
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://resources/ui/toolbar_border.png"
	var src_frame := 20
	if kind == "all" or kind == "on":
		path = "res://resources/ui/toolbar_slot.png"
		src_frame = 24
	cell.add_theme_stylebox_override("panel", _tray_style(path, src_frame))
	if glyph != null:
		var face := _tray_face(0, 6.0)
		face.texture = glyph
		cell.add_child(face)
	elif icon >= 0:
		cell.add_child(_tray_face(icon))
	var button := _tray_button()
	cell.add_child(button)
	return button


func _rebuild_bars() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	for child in kit_tabs.get_children():
		child.queue_free()
	for child in kit_icons.get_children():
		child.queue_free()
	tool_buttons.clear()
	build_buttons.clear()
	var ready := _ready_tabs()
	if ready.is_empty():
		_set_kit_shown(false)
		return
	if not ready.has(kit_tab):
		kit_tab = int(ready[0])
	var tabs := _kit_tabs()
	kit_tabs.visible = ready.size() > 1
	var page: Dictionary = tabs[kit_tab]
	var count := 0
	var pending: Array = []
	for id in page.tools:
		var entry := _tool_entry(int(id))
		if entry.is_empty() or not bool(sim.unlocks.get(str(entry.unlock), false)):
			continue
		pending.append({"kind": "tool", "id": int(entry.tool), "icon": int(entry.icon)})
		count += 1
	for id in page.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if info.is_empty() or not bool(sim.unlocks.get(str(info.unlock), false)):
			continue
		var build_id := int(id)
		if build_id == Catalog.BLD_MARKET and sim.has_building_kind(Catalog.BLD_MARKET):
			continue
		pending.append({"kind": "build", "id": build_id, "icon": int(info.icon)})
		count += 1
	var tab_n := ready.size() if kit_tabs.visible else 0
	var tab_w := _row_span(tab_n, 44.0)
	var item_w := _row_span(maxi(count, 1), 54.0)
	var item_h := 44.0
	if kit_tabs.visible:
		for i in ready:
			var tab: Dictionary = tabs[i]
			var tab_i := int(i)
			var tab_kind := "on" if tab_i == kit_tab else "border"
			var tab_button := _tray_cell(0, 44.0, 44.0, tab_kind, _tex(_tab_icon(str(tab.label))))
			tab_button.pressed.connect(_set_kit_tab.bind(tab_i))
			kit_tabs.add_child(tab_button.get_parent())
	if kit_tabs.visible and tab_w > item_w:
		var gap := tab_w - item_w + float(TRAY_FRAME)
		kit_icons.add_child(_tray_cell(-1, gap, item_h, "border").get_parent())
		item_w = tab_w
	for item in pending:
		var face := _tray_cell(int(item.icon), 54.0, 44.0, "all")
		var item_id := int(item.id)
		if str(item.kind) == "tool":
			face.button_down.connect(_begin_kit_drag.bind("tool", item_id))
			tool_buttons[item_id] = face
		else:
			face.button_down.connect(_begin_kit_drag.bind("build", item_id))
			build_buttons[item_id] = face
		kit_icons.add_child(face.get_parent())
	var edge := -60.0
	var tab_h := 44.0
	var bar_w := maxf(tab_w, item_w)
	kit_panel.offset_right = edge
	kit_panel.offset_bottom = -8.0
	kit_panel.offset_left = edge - bar_w
	kit_panel.offset_top = -8.0 - item_h
	kit_tab_row.offset_right = edge
	kit_tab_row.offset_bottom = -8.0 - item_h + float(TRAY_FRAME)
	kit_tab_row.offset_left = edge - tab_w
	kit_tab_row.offset_top = kit_tab_row.offset_bottom - tab_h
	_set_kit_shown(kit_open)


func _set_kit_tab(index: int) -> void:
	kit_tab = index
	_rebuild_bars()


func _begin_kit_drag(kind: String, id: int) -> void:
	if ThrongletSimServer.frozen or ThrongletSimServer.paused:
		return
	_play("ui")
	kit_drag = {"type": kind, "id": id}
	if kind == "build":
		placing = id
		tool = Catalog.TOOL_EYE
	else:
		placing = -1
		tool = id


func _drop_scoop() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.has_scoop():
		return
	var at := _pointer()
	sim.scoop_drop(at.x, at.y)
	_clear_tool_charge()
	tool = Catalog.TOOL_EYE


func _cancel_kit_drag() -> void:
	if ThrongletSimServer.has_scoop():
		_drop_scoop()
	kit_drag = {}
	placing = -1
	_clear_tool_charge()
	tool = Catalog.TOOL_EYE


func _end_kit_drag() -> void:
	if kit_drag.is_empty():
		return
	var kind := str(kit_drag.get("type", ""))
	var id := int(kit_drag.get("id", -1))
	kit_drag = {}
	placing = -1
	var was_charge := _is_charge_tool(id)
	if id == Catalog.TOOL_GRAB and ThrongletSimServer.has_scoop():
		_drop_scoop()
		return
	_clear_tool_charge()
	if id < 0 or ThrongletSimServer.frozen or ThrongletSimServer.paused:
		tool = Catalog.TOOL_EYE
		return
	if was_charge:
		tool = Catalog.TOOL_EYE
		return
	if not _drop_on_island():
		tool = Catalog.TOOL_EYE
		return
	var place := id == Catalog.TOOL_TNT or kind == "build"
	var at := _grid_pointer() if place else _pointer()
	if kind == "build":
		ThrongletSimServer.place_building(id, at.x, at.y)
	elif kind == "tool":
		if id == Catalog.TOOL_SPONGE:
			ThrongletSimServer.scrub(at.x, at.y, 18.0)
		else:
			ThrongletSimServer.use_tool(id, at.x, at.y)
	tool = Catalog.TOOL_EYE


func _kit_drag_icon() -> int:
	if kit_drag.is_empty():
		return -1
	if str(kit_drag.get("type", "")) == "build":
		var info: Dictionary = Catalog.BUILD_INFO.get(int(kit_drag.id), {})
		return int(info.get("icon", -1))
	var entry := _tool_entry(int(kit_drag.id))
	return int(entry.get("icon", -1))


func _kit_drag_label() -> String:
	if kit_drag.is_empty():
		return ""
	if str(kit_drag.get("type", "")) == "build":
		var info: Dictionary = Catalog.BUILD_INFO.get(int(kit_drag.id), {})
		var wood_n := int(info.get("wood", 0))
		if wood_n <= 0:
			return "%s  (GRATIS)" % str(info.get("label", ""))
		return "%s  (%d MADERA)" % [str(info.get("label", "")), wood_n]
	var entry := _tool_entry(int(kit_drag.id))
	return str(entry.get("label", ""))


func _drop_on_island() -> bool:
	var mouse := get_viewport().get_mouse_position()
	for panel in [kit_panel, kit_tab_row, market_panel, gaze_panel, slots_panel, menu_dim]:
		if panel != null and panel.visible and panel.get_global_rect().has_point(mouse):
			return false
	return true


func _toggle_kit() -> void:
	_play("ui")
	kit_open = not kit_open
	if kit_open:
		_rebuild_bars()
	else:
		_set_kit_shown(false)


func _set_kit_shown(shown: bool) -> void:
	if kit_panel != null:
		kit_panel.visible = shown
	if kit_tab_row != null:
		kit_tab_row.visible = shown and kit_tabs != null and kit_tabs.visible


func _row_span(count: int, cell: float) -> float:
	if count <= 0:
		return 0.0
	return float(count) * cell - float(maxi(count - 1, 0)) * float(TRAY_FRAME)


func _mark_selected() -> void:
	var drag_tool := -1
	var drag_build := -1
	if not kit_drag.is_empty():
		if str(kit_drag.get("type", "")) == "tool":
			drag_tool = int(kit_drag.id)
		else:
			drag_build = int(kit_drag.id)
	for id in tool_buttons.keys():
		var button: Button = tool_buttons[id]
		button.modulate = Color(1, 1, 1) if int(id) == drag_tool else Color(0.7, 0.7, 0.75)
	for id in build_buttons.keys():
		var button2: Button = build_buttons[id]
		button2.modulate = Color(1, 0.95, 0.6) if int(id) == drag_build else Color(0.75, 0.75, 0.8)


func _hotkey(code: int) -> void:
	var order := [
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	]
	var tools: Array = []
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == Catalog.TOOL_EYE:
			continue
		if bool(ThrongletSimServer.unlocks.get(str(entry.unlock), false)):
			tools.append(int(entry.tool))
	for i in order.size():
		if code == order[i] and i < tools.size():
			_play("ui")
			_cancel_kit_drag()
			tool = int(tools[i])


func _build_marks() -> void:
	for _i in 3:
		var panel := PanelContainer.new()
		panel.visible = false
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 8
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_theme_stylebox_override("panel", _speech_bubble_style())
		var hold := CenterContainer.new()
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hold)
		var glyph := TextureRect.new()
		glyph.custom_minimum_size = Vector2(14, 14)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hold.add_child(glyph)
		var said := Label.new()
		said.visible = false
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(72, 0)
		said.add_theme_font_size_override("font_size", 16)
		said.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
		panel.add_child(said)
		bubble_labels.append(said)
		add_child(panel)
		bubble_panels.append(panel)
		bubble_icons.append(glyph)
		var tail := TextureRect.new()
		tail.texture = _tex("res://resources/ui/speech_bubble_tail.png")
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tail.z_index = 8
		tail.visible = false
		tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(tail)
		bubble_tails.append(tail)
	for _i in 24:
		var label := Label.new()
		label.theme = ui_theme
		label.text = "0/4"
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 8
		label.add_theme_color_override("font_color", Color.WHITE)
		add_child(label)
		full_labels.append(label)
	for _i in 12:
		var dash := Line2D.new()
		dash.width = 1.5
		dash.default_color = Color(1, 1, 1, 0.9)
		dash.z_index = 5
		dash.visible = false
		add_child(dash)
		ring_lines.append(dash)


func _build_glitch(root: Control) -> void:
	glitch_overlay = ColorRect.new()
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_overlay.visible = false
	glitch_overlay.z_index = 31
	var shader := load("res://resources/ui/fullscreen_glitch.gdshader") as Shader
	if shader != null:
		glitch_mat = ShaderMaterial.new()
		glitch_mat.shader = shader
		glitch_overlay.material = glitch_mat
	root.add_child(glitch_overlay)


func _hide_marks() -> void:
	for panel in bubble_panels:
		panel.visible = false
	for tail in bubble_tails:
		tail.visible = false
	for label in full_labels:
		label.visible = false
	for line in ring_lines:
		line.visible = false


func _sync_marks() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var view := _world_view()
	for i in bubble_panels.size():
		var panel: PanelContainer = bubble_panels[i]
		var glyph: TextureRect = bubble_icons[i]
		var tail: TextureRect = bubble_tails[i]
		if i >= sim.barks.size():
			panel.visible = false
			tail.visible = false
			if i < bubble_labels.size():
				bubble_labels[i].visible = false
			continue
		var bark: Dictionary = sim.barks[i]
		var at := Vector2(float(bark.x), float(bark.y))
		if not view.has_point(at):
			panel.visible = false
			tail.visible = false
			continue
		var said: Label = bubble_labels[i]
		var text := sim.address(str(bark.get("text", "")))
		var icon := int(bark.get("icon", -1))
		if text == "" and icon < 0:
			panel.visible = false
			tail.visible = false
			continue
		if text != "":
			said.text = text
			said.visible = true
			glyph.visible = false
		else:
			said.visible = false
			glyph.texture = _atlas_icon(icon)
			glyph.visible = true
		tail.visible = false
		var frame := int(Time.get_ticks_msec() / 120 + int(bark.get("id", 0))) % 5
		_apply_bubble_frame(panel, frame)
		panel.reset_size()
		var size := panel.get_combined_minimum_size()
		size.x = maxf(size.x, 36.0)
		size.y = maxf(size.y, 32.0)
		panel.size = size
		var tip := _to_iso(at) + Vector2(0, -22)
		panel.position = Vector2(tip.x - (size.x - 18.0), tip.y - size.y)
		panel.visible = true
		tail.visible = false
	var full_n := 0
	for b in sim.buildings:
		if full_n >= full_labels.size():
			break
		if b.dead:
			continue
		var cap_text: String = sim.occupancy_text(b)
		if cap_text == "":
			continue
		if not sim.chunk_shown(sim.chunk_key_at(float(b.x), float(b.y))):
			continue
		var at := Vector2(float(b.x), float(b.y))
		if not view.has_point(at):
			continue
		var label: Label = full_labels[full_n]
		label.visible = true
		label.text = cap_text
		label.position = _to_iso(at) + Vector2(-12, -28)
		full_n += 1
	for i in range(full_n, full_labels.size()):
		full_labels[i].visible = false
	var bld: Dictionary = sim.building_by_id.get(selected_bld, {})
	var show_ring := not bld.is_empty() and not bool(bld.get("dead", true))
	if show_ring:
		var pts := _iso_circle_points(Vector2(float(bld.x), float(bld.y)), 16.0, 24)
		for i in ring_lines.size():
			var dash: Line2D = ring_lines[i]
			dash.points = PackedVector2Array([pts[i * 2], pts[i * 2 + 1]])
			dash.visible = true
	else:
		for line in ring_lines:
			line.visible = false
	_sync_factory_mark(sim)
	_sync_building_alert(sim)


func _build_factory_slices() -> void:
	var src := _tex("res://resources/ui/factory_slice.png")
	if src == null:
		return
	var img := src.get_image()
	if img == null:
		return
	img = img.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	var count := ThrongletSimServer.FACTORY_WEDGES
	var parts: Array[Image] = []
	for _i in count:
		parts.append(Image.create(w, h, false, Image.FORMAT_RGBA8))
	var cx := (float(w) - 1.0) * 0.5
	var cy := (float(h) - 1.0) * 0.5
	var step := 360.0 / float(count)
	for y in h:
		for x in w:
			var px := img.get_pixel(x, y)
			if px.a <= 0.05:
				continue
			var deg := rad_to_deg(atan2(float(x) - cx, -(float(y) - cy)))
			if deg < 0.0:
				deg += 360.0
			var sector := int((deg + step * 0.5) / step) % count
			parts[sector].set_pixel(x, y, px)
	var fill_scale := 0.55 * (19.0 / 16.87)
	for part in parts:
		var slice := Sprite2D.new()
		slice.texture = ImageTexture.create_from_image(part)
		slice.visible = false
		slice.z_index = 6
		slice.scale = Vector2(fill_scale, fill_scale)
		slice.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(slice)
		factory_slices.append(slice)


func _sync_factory_mark(sim: ThrongletSim) -> void:
	if factory_frame == null:
		return
	var b: Dictionary = sim.building_by_id.get(selected_bld, {})
	var kind := int(b.get("kind", -1))
	var show := not b.is_empty() and not bool(b.get("dead", true)) and (kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2)
	if not show:
		for other in sim.buildings:
			if other.dead:
				continue
			var other_kind := int(other.kind)
			if other_kind != Catalog.BLD_FACTORY and other_kind != Catalog.BLD_FACTORY2:
				continue
			if int(other.get("buffer", 0)) <= 0:
				continue
			b = other
			show = true
			break
	factory_frame.visible = show
	var filled := 0
	if show:
		filled = mini(int(b.get("buffer", 0)), ThrongletSimServer.FACTORY_WEDGES)
	for i in factory_slices.size():
		factory_slices[i].visible = show and i < filled
	if not show:
		return
	var at := _to_iso(Vector2(float(b.x), float(b.y))) + Vector2(0, -28)
	factory_frame.position = at
	for slice in factory_slices:
		slice.position = at


func _sync_building_alert(sim: ThrongletSim) -> void:
	if pollution_bld == null:
		return
	var found := false
	for b in sim.buildings:
		if b.dead:
			continue
		if sim._tile_at(float(b.x), float(b.y)) != Catalog.TILE_GOO:
			continue
		pollution_bld.position = _to_iso(Vector2(float(b.x), float(b.y))) + Vector2(0, -36)
		pollution_bld.visible = true
		found = true
		break
	if not found:
		pollution_bld.visible = false


func _sync_glitch(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.glitch_t > 0.0:
		sim.glitch_t = maxf(0.0, sim.glitch_t - delta)
	var on: bool = sim.glitch_t > 0.0
	if glitch_overlay != null:
		glitch_overlay.visible = on
		if on and glitch_mat != null:
			glitch_mat.set_shader_parameter("intensity", clampf(sim.glitch_t / 1.4, 0.35, 1.0))


func _sync_need_bars() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var show: bool = selected >= 0 and selected < sim.slot_count and sim.state[selected] != Catalog.ST_VACANT
	need_show = show
	if not show:
		for node in need_backs:
			node.visible = false
		for node in need_fills:
			node.visible = false
		if pollution_mark != null:
			pollution_mark.visible = false
		return
	var origin := get_global_mouse_position()
	if not (sim.held_kind == "thronglet" and sim.held_ref == selected):
		origin = _to_iso(Vector2(sim.pos_x[selected], sim.pos_y[selected]))
	var at := origin + Vector2(-14, -42)
	var amounts := [sim.fed[selected], sim.amused[selected], sim.clean[selected]]
	var colors := [Color(0.86, 0.22, 0.24), Color(0.95, 0.72, 0.22), Color(0.32, 0.62, 0.9)]
	for i in 3:
		var y := float(i) * 8.0
		var back: Sprite2D = need_backs[i]
		back.position = at + Vector2(0, y)
		back.visible = true
		var width := clampf(amounts[i] / 100.0, 0.0, 1.0) * 26.0
		var fill: Polygon2D = need_fills[i]
		fill.color = colors[i]
		fill.visible = width >= 1.0
		if width < 1.0:
			continue
		fill.position = at + Vector2(2, y + 1)
		fill.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(width, 0), Vector2(width, 4), Vector2(0, 4),
		])
	if pollution_mark != null:
		var dirty := sim.state[selected] == Catalog.ST_LIVING and sim.clean[selected] < 40.0
		pollution_mark.visible = dirty
		pollution_mark.position = at + Vector2(-10, 10)


func _atlas_icon(icon: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _tex("res://resources/structures/structures_tileset.png")
	var col := icon % Catalog.ATLAS_COLUMNS
	var row := int(icon / Catalog.ATLAS_COLUMNS)
	atlas.region = Rect2(col * 16, row * 16, 16, 16)
	return atlas


func _market_has_stock(sim: ThrongletSim) -> bool:
	if not sim.has_building_kind(Catalog.BLD_MARKET):
		return false
	for key in Catalog.MARKET.keys():
		var row: Dictionary = Catalog.MARKET[key]
		if not bool(sim.unlocks.get(str(key), false)) and sim.gems >= int(row.cost):
			return true
	return false


func _sync_market_sign(sim: ThrongletSim) -> void:
	if market_signs == null:
		return
	var show := _market_has_stock(sim)
	var n := 0
	if show:
		for b in sim.buildings:
			if b.dead or int(b.kind) != Catalog.BLD_MARKET:
				continue
			var sprite: Sprite2D
			if n < market_signs.get_child_count():
				sprite = market_signs.get_child(n)
			else:
				sprite = Sprite2D.new()
				sprite.centered = true
				sprite.texture = _tex("res://resources/ui/new_item.png")
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.scale = Vector2(0.45, 0.45)
				market_signs.add_child(sprite)
			sprite.position = _to_iso(Vector2(float(b.x), float(b.y))) + Vector2(8, -46)
			sprite.visible = true
			n += 1
	for i in range(n, market_signs.get_child_count()):
		market_signs.get_child(i).visible = false


func _build_sky() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -1
	add_child(sky)
	var stars := TextureRect.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.texture = _tex("res://resources/tiles/space.png")
	stars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stars.stretch_mode = TextureRect.STRETCH_SCALE
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(stars)


func _build_world() -> void:
	tilemap = TileMapLayer.new()
	tilemap.tile_set = _make_tileset()
	tilemap.z_index = 0
	add_child(tilemap)
	pathmap = TileMapLayer.new()
	pathmap.tile_set = _make_path_tileset()
	pathmap.z_index = 1
	pathmap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(pathmap)
	path_root = Node2D.new()
	path_root.z_index = 1
	add_child(path_root)
	market_signs = Node2D.new()
	market_signs.z_index = 8
	add_child(market_signs)
	factory_frame = Sprite2D.new()
	factory_frame.texture = _tex("res://resources/ui/factory_frame.png")
	factory_frame.visible = false
	factory_frame.z_index = 6
	factory_frame.scale = Vector2(0.55, 0.55)
	factory_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(factory_frame)
	_build_factory_slices()
	pollution_mark = Sprite2D.new()
	pollution_mark.texture = _tex("res://resources/ui/pollution_throng.png")
	pollution_mark.visible = false
	pollution_mark.z_index = 7
	pollution_mark.scale = Vector2(0.28, 0.28)
	add_child(pollution_mark)
	pollution_bld = Sprite2D.new()
	pollution_bld.texture = _tex("res://resources/ui/pollution_building.png")
	pollution_bld.visible = false
	pollution_bld.z_index = 7
	pollution_bld.scale = Vector2(0.35, 0.35)
	add_child(pollution_bld)
	place_marks = Node2D.new()
	place_marks.z_index = 1
	add_child(place_marks)
	charge_area = Line2D.new()
	charge_area.z_index = 3
	charge_area.width = 2.5
	charge_area.joint_mode = Line2D.LINE_JOINT_ROUND
	charge_area.begin_cap_mode = Line2D.LINE_CAP_ROUND
	charge_area.end_cap_mode = Line2D.LINE_CAP_ROUND
	charge_area.visible = false
	add_child(charge_area)
	charge_ring = Line2D.new()
	charge_ring.z_index = 4
	charge_ring.width = 3.0
	charge_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	charge_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	charge_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	charge_ring.visible = false
	add_child(charge_ring)
	world_layer = Node2D.new()
	world_layer.z_index = 2
	add_child(world_layer)
	world = MultiMeshInstance2D.new()
	world.material = _material(16, ThrongClips.SHEET_ROWS)
	world.texture = _tex("res://resources/sprites/world_iso.png")
	world_mesh = _mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
	world.multimesh = world_mesh
	world_layer.add_child(world)
	_prop_bands = [world]
	var bar_colors := [
		Color(0.86, 0.22, 0.24),
		Color(0.95, 0.72, 0.22),
		Color(0.32, 0.62, 0.9),
	]
	for i in 3:
		var back := Sprite2D.new()
		back.texture = _tex("res://resources/ui/need_gauge.png")
		back.centered = false
		back.scale = Vector2(0.5, 0.5)
		back.z_index = 6
		back.visible = false
		add_child(back)
		need_backs.append(back)
		var fill := Polygon2D.new()
		fill.z_index = 7
		fill.color = bar_colors[i]
		fill.visible = false
		add_child(fill)
		need_fills.append(fill)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()


func _make_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(32, 16)
	var atlas := TileSetAtlasSource.new()
	var terrain := _tex("res://resources/tiles/terrain_tileset.png")
	atlas.texture = terrain
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in terrain.get_width() / 32:
		var coord := Vector2i(i, 0)
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
	return tileset


func _river_atlas(cell: Vector2i) -> int:
	var n := _shore(cell, 0, -1)
	var e := _shore(cell, 1, 0)
	var s := _shore(cell, 0, 1)
	var w := _shore(cell, -1, 0)
	var role := 0
	if n and e and not s and not w:
		role = 5
	elif n and w and not s and not e:
		role = 6
	elif s and e and not n and not w:
		role = 7
	elif s and w and not n and not e:
		role = 8
	elif n and not s:
		role = 1
	elif s and not n:
		role = 2
	elif w and not e:
		role = 3
	elif e and not w:
		role = 4
	var variant := absi(cell.x * 3 + cell.y * 5) % 4
	return RIVER_ATLAS + role * 4 + variant


func _shore(cell: Vector2i, dx: int, dy: int) -> bool:
	var at := Catalog.cell_world(cell + Vector2i(dx, dy))
	return ThrongletSimServer._tile_at(at.x, at.y) != Catalog.TILE_WATER


func _make_path_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(32, 16)
	var atlas := TileSetAtlasSource.new()
	var path_tex := _tex("res://resources/tiles/path_overlay.png")
	atlas.texture = path_tex
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in 15:
		atlas.create_tile(Vector2i(i, 0))
	return tileset


func _material(h_frames: int, v_frames: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://thronglet_shader.gdshader")
	mat.set_shader_parameter("h_frames", h_frames)
	mat.set_shader_parameter("v_frames", v_frames)
	mat.set_shader_parameter("dirt_tex", _tex("res://resources/sprites/world_iso_dirt.png"))
	return mat


func _mesh(colored: bool, size: Vector2) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = size
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_custom_data = true
	mesh.use_colors = colored
	mesh.mesh = quad
	mesh.instance_count = 16
	mesh.visible_instance_count = 0
	return mesh


func _ui_font() -> FontFile:
	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.oversampling = 1.0
	font.allow_system_fallback = false
	if font.load_dynamic_font("res://resources/ui/VT323-Regular.ttf") == OK:
		return font
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	if font.load_dynamic_font("res://resources/ui/aline_font.ttf") == OK:
		return font
	return null


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var theme := Theme.new()
	var font := _ui_font()
	if font != null:
		theme.default_font = font
		theme.default_font_size = 16
	var panel := _panel_style()
	var slot := _slot_style()
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
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_top.add_child(top_row)
	var badge := Control.new()
	# Native ThrongletCounter cell is 60x60; keep 1:1 so the cream ring is not cropped.
	badge.custom_minimum_size = Vector2(60, 60)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := TextureRect.new()
	ring.texture = _tex("res://resources/ui/thronglet_counter.png")
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
	pop_face.texture = _tex(POP_FACES["base"])
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
	gem_panel = PanelContainer.new()
	gem_panel.add_theme_stylebox_override("panel", _slot_style())
	gem_panel.visible = false
	var gem_row := HBoxContainer.new()
	gem_row.add_theme_constant_override("separation", 4)
	var gem_icon := TextureRect.new()
	gem_icon.texture = _atlas_icon(Catalog.ICON_GEM)
	gem_icon.custom_minimum_size = Vector2(16, 16)
	gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem_row.add_child(gem_icon)
	gem_label = Label.new()
	gem_label.text = "0"
	gem_row.add_child(gem_label)
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
	goal_panel.add_theme_stylebox_override("panel", _goal_outer_style())
	goal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cyan_panel := PanelContainer.new()
	cyan_panel.add_theme_stylebox_override("panel", _goal_cyan_style())
	cyan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", 0)
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_panel := PanelContainer.new()
	tag_panel.custom_minimum_size = Vector2(56, 0)
	tag_panel.add_theme_stylebox_override("panel", _goal_tag_style())
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_label := Label.new()
	tag_label.text = "TAREA"
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 13)
	tag_label.add_theme_color_override("font_color", _goal_ink())
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_child(tag_label)
	goal_row.add_child(tag_panel)
	var body_panel := PanelContainer.new()
	body_panel.custom_minimum_size = Vector2(280, 0)
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.add_theme_stylebox_override("panel", _goal_body_style())
	body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_label = Label.new()
	goal_label.text = ""
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	goal_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	goal_label.add_theme_font_size_override("font_size", 13)
	goal_label.add_theme_color_override("font_color", _goal_ink())
	goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_panel.add_child(goal_label)
	goal_row.add_child(body_panel)
	cyan_panel.add_child(goal_row)
	goal_panel.add_child(cyan_panel)
	goal_wrap.add_child(goal_panel)
	hud_top.add_child(goal_wrap)
	root.add_child(hud_top)

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
	kit_tabs.add_theme_constant_override("separation", -TRAY_FRAME)
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
	kit_icons.add_theme_constant_override("separation", -TRAY_FRAME)
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
	kit_button.texture_normal = _tex("res://resources/ui/toolbar_button.png")
	kit_button.pressed.connect(_toggle_kit)
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
	focus_stars.texture = _tex("res://resources/tiles/space.png")
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
	var focus_world := MultiMeshInstance2D.new()
	focus_world.z_index = 2
	focus_world.material = _material(16, ThrongClips.SHEET_ROWS)
	focus_world.texture = world.texture
	focus_mesh = _mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
	focus_world.multimesh = focus_mesh
	focus_port.add_child(focus_world)
	focus_cam_node = Camera2D.new()
	focus_port.add_child(focus_cam_node)
	root.add_child(focus_box)
	focus_cam_node.make_current()
	focus_frame = Panel.new()
	focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_frame.visible = false
	focus_frame.z_index = 32
	var border := _box_style("res://resources/ui/dialogue_frame.png", 22, 0)
	border.draw_center = false
	focus_frame.add_theme_stylebox_override("panel", border)
	root.add_child(focus_frame)

	var glyph_atlas := "res://resources/src/ref/atlas/Sprites-ConsoleUI/"
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
		var glyph_tex := _tex(glyph_atlas + sheet)
		if glyph_tex != null:
			console_glyphs.append(glyph_tex)
	gaze_panel = Control.new()
	gaze_panel.visible = false
	gaze_panel.z_index = 33
	gaze_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gaze_log = Control.new()
	gaze_log.set_anchors_preset(Control.PRESET_FULL_RECT)
	gaze_log.mouse_filter = Control.MOUSE_FILTER_STOP
	gaze_log.gui_input.connect(_on_console_input)
	_build_console_frame(gaze_log, 2.0, 0)
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
	gaze_text.scroll_active = false
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
	name_edit = LineEdit.new()
	name_edit.visible = false
	name_edit.max_length = 24
	name_edit.placeholder_text = ">>"
	name_edit.caret_blink = true
	name_edit.custom_minimum_size = Vector2(0, 22)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_override("font", _ui_font())
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
	_build_marks()
	_build_glitch(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	dim.z_index = 40
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_slots()
	)
	root.add_child(dim)
	menu_dim = dim
	menu_button = Button.new()
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_button.offset_left = -30
	menu_button.offset_top = 4
	menu_button.offset_right = -4
	menu_button.offset_bottom = 28
	menu_button.z_index = 42
	menu_button.pressed.connect(_toggle_slots)
	var empty := StyleBoxEmpty.new()
	menu_button.add_theme_stylebox_override("normal", empty)
	menu_button.add_theme_stylebox_override("hover", empty)
	menu_button.add_theme_stylebox_override("focus", empty)
	menu_button.add_theme_stylebox_override("pressed", empty)
	menu_button.add_theme_stylebox_override("hover_pressed", empty)
	var menu_icon := TextureRect.new()
	menu_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_icon.texture = _tex("res://resources/ui/menu_bars.png")
	menu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(menu_icon)
	root.add_child(menu_button)
	save_icon = TextureRect.new()
	save_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	save_icon.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_icon.offset_left = -54
	save_icon.offset_top = 4
	save_icon.offset_right = -32
	save_icon.offset_bottom = 28
	save_icon.z_index = 42
	save_icon.texture = _tex("res://resources/ui/save_disk.png")
	save_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	save_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	save_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	save_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_icon.visible = false
	root.add_child(save_icon)
	var pause_center := CenterContainer.new()
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.z_index = 41
	slots_panel = PanelContainer.new()
	slots_panel.visible = false
	slots_list = VBoxContainer.new()
	slots_list.add_theme_constant_override("separation", 3)
	slots_panel.add_child(slots_list)
	pause_center.add_child(slots_panel)
	over_panel = PanelContainer.new()
	over_panel.visible = false
	over_list = VBoxContainer.new()
	over_list.add_theme_constant_override("separation", 3)
	over_panel.add_child(over_list)
	pause_center.add_child(over_panel)
	root.add_child(pause_center)

	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_STOP
	title_root.visible = false
	title_root.z_index = 70
	_build_title_backdrop(title_root)
	_build_title_hud(title_root)
	_build_settings_menu(title_root)
	_build_video_library(title_root)
	root.add_child(title_root)
	_build_opening(root)
	if not ThrongletSimServer.testing:
		_load_prefs()
	_apply_crt()
	_apply_volumes()

	_rebuild_bars()


func _build_opening(root: Control) -> void:
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 128
	add_child(crt_layer)
	crt_overlay = ColorRect.new()
	crt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_overlay.visible = false
	var crt_mat := ShaderMaterial.new()
	crt_mat.shader = load("res://resources/ui/crt_overlay.gdshader")
	crt_overlay.material = crt_mat
	crt_layer.add_child(crt_overlay)

	dos_root = Control.new()
	dos_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_root.mouse_filter = Control.MOUSE_FILTER_STOP
	dos_root.visible = false
	dos_root.z_index = 72
	var dos_bg := ColorRect.new()
	dos_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_bg.color = Color(0, 0, 0, 1)
	dos_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dos_root.add_child(dos_bg)
	dos_label = Label.new()
	dos_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	dos_label.offset_left = 16
	dos_label.offset_top = 12
	dos_label.offset_right = -72
	dos_label.offset_bottom = -28
	dos_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dos_label.add_theme_font_override("font", _dos_font())
	dos_label.add_theme_font_size_override("font_size", 16)
	dos_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.4))
	dos_root.add_child(dos_label)
	var dos_face := TextureRect.new()
	dos_face.texture = _tex("res://resources/ui/face_base.png")
	dos_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dos_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dos_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dos_face.self_modulate = Color(0.35, 1.0, 0.4)
	dos_face.anchor_left = 1.0
	dos_face.anchor_right = 1.0
	dos_face.offset_left = -56
	dos_face.offset_top = 8
	dos_face.offset_right = -8
	dos_face.offset_bottom = 48
	dos_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dos_root.add_child(dos_face)
	root.add_child(dos_root)

	sign_button = Button.new()
	sign_button.visible = false
	sign_button.z_index = 34
	sign_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sign_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_button.add_theme_font_override("font", _ui_font())
	sign_button.add_theme_font_size_override("font_size", 14)
	var ink := Color(0.1, 0.07, 0.04)
	sign_button.add_theme_color_override("font_color", ink)
	sign_button.add_theme_color_override("font_hover_color", ink)
	sign_button.add_theme_color_override("font_pressed_color", ink)
	sign_button.add_theme_color_override("font_focus_color", ink)
	var wood := _box_style("res://resources/ui/sign_plank.png", 8, 6)
	sign_button.add_theme_stylebox_override("normal", wood)
	sign_button.add_theme_stylebox_override("hover", wood)
	sign_button.add_theme_stylebox_override("pressed", wood)
	sign_button.add_theme_stylebox_override("focus", wood)
	var arrow := TextureRect.new()
	arrow.texture = _tex("res://resources/ui/sign_arrow.png")
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_SCALE
	arrow.anchor_left = 1.0
	arrow.anchor_top = 1.0
	arrow.anchor_right = 1.0
	arrow.anchor_bottom = 1.0
	arrow.offset_left = -16.0
	arrow.offset_top = -12.0
	arrow.offset_right = -11.0
	arrow.offset_bottom = -9.0
	sign_button.add_child(arrow)
	sign_button.pressed.connect(_advance_sign)
	root.add_child(sign_button)


func _dos_font() -> FontFile:
	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if font.load_dynamic_font("res://resources/ui/PerfectDOSVGA437.ttf") == OK:
		return font
	return _ui_font()


func _begin_logo() -> void:
	boot = "logo"
	logo_started = false
	logo_wait = 0.0
	logo_video_playing = true
	in_title = true
	ThrongletSimServer.paused = true
	if title_root != null:
		title_root.visible = false
	if dos_root != null:
		dos_root.visible = false
	# No iniciar música de título durante el video del logo;
	# _sync_music() está bloqueado por logo_video_playing.
	if not _play_video("tuckersoft_logo_30fps_1MB", true):
		_begin_dos()
	else:
		# Subir el volumen del audio del video de Tuckersoft para que se escuche más claro.
		video_player.volume_db = 6.0


func _tick_logo(delta: float) -> void:
	if boot != "logo" or video_player == null:
		return
	logo_wait += delta
	if video_player.is_playing():
		logo_started = true
		return
	if logo_started:
		_begin_dos()
		return
	if logo_wait > 1.0 and video_player.stream != null:
		video_player.play()
	if logo_wait > 2.0:
		_begin_dos()


func _begin_dos() -> void:
	if boot != "logo":
		return
	boot = "dos"
	video_from_title = false
	if video_player != null:
		video_player.stop()
		video_player.visible = false
		var plate: ColorRect = video_player.get_meta("plate") as ColorRect
		if plate != null:
			plate.visible = false
	_show_dos()


func _show_dos() -> void:
	in_title = true
	ThrongletSimServer.paused = true
	_open_dos()


func _open_dos() -> void:
	dos_full = LineBook.row("SYS.GAME_INTRO", 3).replace("\\n", "\n")
	dos_full = dos_full.replace("\\\\", "\\").replace("\\\\", "\\")
	dos_shown = 0
	dos_hold = 0.0
	dos_label.text = ""
	dos_root.visible = true


func _tick_dos(delta: float) -> void:
	if dos_root == null or not dos_root.visible:
		return
	if dos_shown < dos_full.length():
		dos_shown = mini(dos_full.length(), dos_shown + 3)
		dos_label.text = dos_full.substr(0, dos_shown)
		return
	if ThrongletSimServer.testing:
		return
	dos_hold += delta
	if dos_hold > 1.2:
		_finish_dos()


func _finish_dos() -> void:
	if dos_root == null or not dos_root.visible:
		return
	dos_root.visible = false
	boot = ""
	if ThrongletSimServer.testing:
		return
	# MOV_01 plays once after the DOS boot, then the title.
	if _play_video("SEQ_1.5", true):
		return
	_show_title()


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://opening.cfg")
	captions_on = bool(cfg.get_value("opening", "captions", true))
	crt_on = bool(cfg.get_value("opening", "crt", true))
	sfx_vol = clampf(float(cfg.get_value("opening", "sfx", 1.0)), 0.0, 1.0)
	music_vol = clampf(float(cfg.get_value("opening", "music", 1.0)), 0.0, 1.0)
	var lang := str(cfg.get_value("opening", "lang", settings_lang))
	if lang in SETTINGS_LANGS:
		settings_lang = lang


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opening", "captions", captions_on)
	cfg.set_value("opening", "crt", crt_on)
	cfg.set_value("opening", "sfx", sfx_vol)
	cfg.set_value("opening", "music", music_vol)
	cfg.set_value("opening", "lang", settings_lang)
	cfg.save("user://opening.cfg")


func _apply_crt() -> void:
	if crt_overlay != null:
		crt_overlay.visible = crt_on


func _apply_volumes() -> void:
	if music != null:
		music.volume_db = -80.0 if music_vol <= 0.001 else linear_to_db(music_vol) - 6.0
	if amb != null:
		amb.volume_db = -80.0 if music_vol <= 0.001 else linear_to_db(music_vol) - 16.0
	if sting != null:
		sting.volume_db = -80.0 if sfx_vol <= 0.001 else linear_to_db(sfx_vol) - 4.0
	for raw in sfx_pool:
		var player := raw as AudioStreamPlayer
		if player != null:
			player.volume_db = -80.0 if sfx_vol <= 0.001 else linear_to_db(sfx_vol)


func _build_settings_menu(root: Control) -> void:
	title_menu = Control.new()
	title_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	title_menu.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	title_menu.add_child(dim)

	settings_shell = Control.new()
	settings_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_menu.add_child(settings_shell)

	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -210
	col.offset_right = 210
	col.offset_top = -128
	col.offset_bottom = 148
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_shell.add_child(col)

	var panel_wrap := Control.new()
	panel_wrap.custom_minimum_size = Vector2(420, 210)
	panel_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(panel_wrap)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 1)
	panel_style.border_color = Color(1, 1, 1, 1)
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	panel_wrap.add_child(panel)

	settings_body = VBoxContainer.new()
	settings_body.add_theme_constant_override("separation", 12)
	settings_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(settings_body)

	var logo := TextureRect.new()
	logo.texture = _tex_rgba("res://resources/ui/settings/tuckersoft.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.position = Vector2(8, -10)
	logo.size = Vector2(150, 20)
	panel_wrap.add_child(logo)

	var close := TextureButton.new()
	close.texture_normal = _tex_rgba("res://resources/ui/settings/close.png")
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -30
	close.offset_right = -4
	close.offset_top = -12
	close.offset_bottom = 16
	close.pressed.connect(func() -> void:
		_play("ui")
		_fill_title()
	)
	panel_wrap.add_child(close)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	foot.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(foot)

	var icons := [
		"res://resources/ui/settings/icon_mail.png",
		"res://resources/ui/settings/icon_cog.png",
		"res://resources/ui/settings/icon_sound.png",
		"res://resources/ui/settings/icon_edit.png",
	]
	settings_tabs.clear()
	for i in icons.size():
		var tab := TextureButton.new()
		tab.ignore_texture_size = true
		tab.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tab.custom_minimum_size = Vector2(36, 38)
		tab.pressed.connect(_settings_set_tab.bind(i))
		var icon := TextureRect.new()
		icon.texture = _tex_rgba(icons[i])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 6
		icon.offset_right = -6
		icon.offset_bottom = -6
		tab.add_child(icon)
		foot.add_child(tab)
		settings_tabs.append(tab)

	var ver := Label.new()
	ver.text = _game_version()
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.add_theme_font_override("font", _dos_font())
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	foot.add_child(ver)

	root.add_child(title_menu)


func _build_video_library(root: Control) -> void:
	video_library = Control.new()
	video_library.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_library.mouse_filter = Control.MOUSE_FILTER_STOP
	video_library.visible = false
	video_library.z_index = 5
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.15)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_video_library()
	)
	video_library.add_child(dim)

	video_library_shell = Control.new()
	video_library_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	video_library.add_child(video_library_shell)

	# Match original Window2 look at reference proportions (flat: cyan + white ring + shadow).
	var shadow := ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(73.0 / 255.0, 73.0 / 255.0, 73.0 / 255.0, 0.8)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(shadow)

	var chrome := ColorRect.new()
	chrome.name = "Chrome"
	chrome.color = VIDEO_SHELL_CYAN
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(chrome)

	var ring := ColorRect.new()
	ring.name = "Ring"
	ring.color = Color(1, 1, 1, 1)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(ring)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = VIDEO_SHELL_CYAN
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(fill)

	# White path strip — original has path on white, not on cyan.
	var title_bg := ColorRect.new()
	title_bg.name = "TitleBg"
	title_bg.color = Color(1, 1, 1, 1)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(title_bg)

	var title := Label.new()
	title.name = "Title"
	title.text = "C:\\BIN\\.SHELL\\"
	title.add_theme_font_override("font", _dos_font())
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(title)

	# White plate on cyan fill so the double cyan stroke reads clearly.
	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.color = Color(1, 1, 1, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_library_shell.add_child(plate)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 1)
	frame_style.border_color = VIDEO_SHELL_CYAN
	frame_style.set_border_width_all(1)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	video_library_shell.add_child(frame)

	var content := PanelContainer.new()
	content.name = "Content"
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(1, 1, 1, 1)
	content_style.border_color = VIDEO_SHELL_CYAN
	content_style.set_border_width_all(1)
	content_style.content_margin_left = 14
	content_style.content_margin_right = 14
	content_style.content_margin_top = 10
	content_style.content_margin_bottom = 8
	content.add_theme_stylebox_override("panel", content_style)
	frame.add_child(content)

	video_library_grid = GridContainer.new()
	video_library_grid.columns = 3
	video_library_grid.add_theme_constant_override("h_separation", 24)
	video_library_grid.add_theme_constant_override("v_separation", 6)
	video_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	video_library_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(video_library_grid)
	root.add_child(video_library)


func _layout_video_library_shell() -> void:
	if video_library_shell == null:
		return
	# Logical title UI size — not the stretched pixel buffer.
	var area := title_root.size if title_root != null else get_viewport_rect().size
	if area.x < 8.0 or area.y < 8.0:
		area = Vector2(640, 360)
	# Visible chrome (excludes drop shadow) — reference fills most of the screen.
	var chrome_size := Vector2(area.x * 0.88, area.y * 0.96)
	var shadow_o := Vector2(8, 8)
	var shell_size := chrome_size + shadow_o
	video_library_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	video_library_shell.size = shell_size
	video_library_shell.position = (area - chrome_size) * 0.5
	video_library_shell.clip_contents = false
	var border := 12.0
	var ring_w := 2.0
	var shadow := video_library_shell.get_node_or_null("Shadow") as Control
	if shadow != null:
		shadow.position = shadow_o
		shadow.size = chrome_size
	var chrome := video_library_shell.get_node_or_null("Chrome") as Control
	if chrome != null:
		chrome.position = Vector2.ZERO
		chrome.size = chrome_size
	var ring := video_library_shell.get_node_or_null("Ring") as Control
	if ring != null:
		ring.position = Vector2(border - ring_w, border - ring_w)
		ring.size = chrome_size - Vector2(border - ring_w, border - ring_w) * 2.0
	var fill := video_library_shell.get_node_or_null("Fill") as Control
	if fill != null:
		fill.position = Vector2(border, border)
		fill.size = chrome_size - Vector2(border, border) * 2.0
	var inner_pos := Vector2(border, border)
	var inner_size := chrome_size - Vector2(border, border) * 2.0
	var title_h := 18.0
	var cyan_gap := 10.0
	var side_pad := 6.0
	var title_bg := video_library_shell.get_node_or_null("TitleBg") as Control
	if title_bg != null:
		title_bg.position = inner_pos + Vector2(side_pad, 2)
		title_bg.size = Vector2(inner_size.x - side_pad * 2.0, title_h)
	var title := video_library_shell.get_node_or_null("Title") as Control
	if title != null:
		title.position = title_bg.position + Vector2(8, 0) if title_bg != null else inner_pos
		title.size = Vector2(inner_size.x - side_pad * 2.0 - 16, title_h)
	var top := inner_pos.y + 2 + title_h + cyan_gap
	var plate_pos := Vector2(inner_pos.x + side_pad, top)
	var plate_size := Vector2(inner_size.x - side_pad * 2.0, maxf(8.0, inner_pos.y + inner_size.y - top - 4))
	var plate := video_library_shell.get_node_or_null("Plate") as Control
	if plate != null:
		plate.position = plate_pos
		plate.size = plate_size
	var frame := video_library_shell.get_node_or_null("Frame") as Control
	if frame != null:
		frame.position = plate_pos
		frame.size = plate_size


func _open_video_library() -> void:
	_play("ui")
	if title_menu != null:
		title_menu.visible = false
	_fill_video_library()
	if video_library != null:
		video_library.visible = true
		_layout_video_library_shell()


func _close_video_library() -> void:
	_play("ui")
	if video_library != null:
		video_library.visible = false


func _video_unlocked(clip_id: String) -> bool:
	return bool(video_played.get(clip_id, false))


func _fill_video_library() -> void:
	if video_library_grid == null:
		return
	# free() immediately — queue_free leaves stale cells in the grid during layout.
	while video_library_grid.get_child_count() > 0:
		var child: Node = video_library_grid.get_child(0)
		video_library_grid.remove_child(child)
		child.free()
	for entry in VIDEO_LIBRARY:
		video_library_grid.add_child(_video_library_cell(entry))
	var exit_wrap := VBoxContainer.new()
	exit_wrap.add_theme_constant_override("separation", 2)
	exit_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	exit_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var exit_btn := Button.new()
	exit_btn.text = "EXIT"
	exit_btn.custom_minimum_size = Vector2(96, 64)
	exit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	exit_btn.add_theme_font_override("font", _dos_font())
	exit_btn.add_theme_font_size_override("font_size", 18)
	exit_btn.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_hover_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_pressed_color", VIDEO_SHELL_INK)
	exit_btn.add_theme_color_override("font_focus_color", VIDEO_SHELL_INK)
	var exit_style := StyleBoxTexture.new()
	exit_style.texture = _tex_rgba("res://resources/ui/video/exit.png")
	exit_style.texture_margin_left = 20
	exit_style.texture_margin_top = 20
	exit_style.texture_margin_right = 17
	exit_style.texture_margin_bottom = 18
	exit_style.set_content_margin_all(4)
	var exit_pressed := exit_style.duplicate()
	exit_pressed.texture = _tex_rgba("res://resources/ui/video/exit_pressed.png")
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	exit_btn.add_theme_stylebox_override("hover", exit_style)
	exit_btn.add_theme_stylebox_override("pressed", exit_pressed)
	exit_btn.add_theme_stylebox_override("focus", exit_style)
	exit_btn.pressed.connect(_close_video_library)
	exit_wrap.add_child(exit_btn)
	var exit_pad := Label.new()
	exit_pad.text = " "
	exit_pad.add_theme_font_override("font", _dos_font())
	exit_pad.add_theme_font_size_override("font_size", 10)
	exit_pad.modulate = Color(1, 1, 1, 0)
	exit_wrap.add_child(exit_pad)
	video_library_grid.add_child(exit_wrap)


func _video_library_cell(entry: Dictionary) -> VBoxContainer:
	var clip_id := str(entry.id)
	var unlocked := _video_unlocked(clip_id)
	var thumb_key := str(entry.thumb)
	var thumb_path := "res://resources/ui/video/%s_thumbnail%s.png" % [
		thumb_key,
		"" if unlocked else "_locked",
	]
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var btn := TextureButton.new()
	btn.texture_normal = _tex_rgba(thumb_path)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.custom_minimum_size = Vector2(96, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_video_library_pick.bind(clip_id, unlocked))
	cell.add_child(btn)
	var label := Label.new()
	label.text = str(entry.label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _dos_font())
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", VIDEO_SHELL_INK)
	cell.add_child(label)
	return cell


func _video_library_pick(clip_id: String, unlocked: bool) -> void:
	_play("ui")
	if not unlocked:
		return
	if video_library != null:
		video_library.visible = false
	video_from_library = true
	if not _play_video(clip_id, true):
		video_from_library = false
		_open_video_library()


func _settings_set_tab(index: int) -> void:
	_play("ui")
	settings_tab = index
	_fill_settings()


func _settings_sync_tabs() -> void:
	for i in settings_tabs.size():
		var tab: TextureButton = settings_tabs[i]
		var path := "res://resources/ui/settings/tab_selected.png" if i == settings_tab else "res://resources/ui/settings/tab_unselected.png"
		tab.texture_normal = _tex_rgba(path)


func _game_version() -> String:
	# Prefer the latest git tag when running from a checkout; else project.godot.
	var git_v := _git_tag_version()
	if git_v != "":
		return git_v
	var v := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	return v if v != "" else "0.0.0"


func _git_tag_version() -> String:
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "describe", "--tags", "--abbrev=0"]), out, true, false)
	if code != 0 or out.is_empty():
		return ""
	var v := str(out[0]).strip_edges()
	if v.begins_with("v") or v.begins_with("V"):
		v = v.substr(1)
	return v


func _settings_blue_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _tex_rgba("res://resources/ui/settings/button.png")
	# 2px blue rim + 1px white frame; keep the fill stretchable
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _settings_blue_button(text: String, call: Callable, min_w: float = 150.0) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(min_w, 28)
	var style := _settings_blue_style()
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_font_override("font", _dos_font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 1.0))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.pressed.connect(func() -> void:
		_play("ui")
		call.call()
	)
	return button


func _settings_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _dos_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _settings_check_row(text: String, on: bool, call: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _settings_label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var box := TextureButton.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.ignore_texture_size = true
	box.stretch_mode = TextureButton.STRETCH_SCALE
	box.texture_normal = _tex_rgba(
		"res://resources/ui/settings/checkbox_on.png" if on else "res://resources/ui/settings/checkbox.png"
	)
	box.pressed.connect(func() -> void:
		_play("ui")
		call.call()
	)
	row.add_child(box)
	return row


func _settings_slider_row(text: String, value: float, call: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _settings_label(text)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var minus := TextureButton.new()
	minus.texture_normal = _tex_rgba("res://resources/ui/settings/slider_minus.png")
	minus.ignore_texture_size = true
	minus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	minus.custom_minimum_size = Vector2(14, 14)
	minus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minus.pressed.connect(func() -> void:
		_play("ui")
		call.call(clampf(value - 0.1, 0.0, 1.0))
		_fill_settings()
	)
	row.add_child(minus)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 20)
	slider.add_theme_stylebox_override("slider", _settings_slider_track())
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.add_theme_icon_override("grabber", _tex_rgba("res://resources/ui/settings/slider_thumb.png"))
	slider.add_theme_icon_override("grabber_highlight", _tex_rgba("res://resources/ui/settings/slider_thumb.png"))
	slider.value_changed.connect(func(v: float) -> void:
		call.call(v)
	)
	row.add_child(slider)
	var plus := TextureButton.new()
	plus.texture_normal = _tex_rgba("res://resources/ui/settings/slider_plus.png")
	plus.ignore_texture_size = true
	plus.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	plus.custom_minimum_size = Vector2(14, 14)
	plus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plus.pressed.connect(func() -> void:
		_play("ui")
		call.call(clampf(value + 0.1, 0.0, 1.0))
		_fill_settings()
	)
	row.add_child(plus)
	return row


func _settings_slider_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.set_content_margin_all(0)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _fill_settings() -> void:
	if title_hud != null:
		title_hud.visible = false
	if title_menu != null:
		title_menu.visible = true
	if settings_shell != null:
		settings_shell.visible = true
	_settings_sync_tabs()
	_clear_menu(settings_body)
	match settings_tab:
		0:
			_fill_settings_mail()
		1:
			_fill_settings_cog()
		2:
			_fill_settings_sound()
		_:
			_fill_settings_edit()


func _fill_settings_mail() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var support := _settings_blue_button(LineBook.row("SYS.SETTINGS", 10), _settings_support, 240)
	support.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(support)
	var faq := _settings_blue_button(LineBook.row("SYS.SETTINGS", 11), _settings_faq, 240)
	faq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(faq)
	settings_body.add_child(stack)


func _fill_settings_cog() -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 8), _settings_achievements, 160))
	grid.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 12), _settings_credits, 120))
	settings_body.add_child(grid)
	settings_body.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 4), _settings_ask_reset, 160))
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extras.add_child(_settings_blue_button("DEV", _enter_dev, 70))
	extras.add_child(_settings_blue_button("SALIR", _quit_game, 80))
	settings_body.add_child(extras)


func _fill_settings_sound() -> void:
	settings_body.add_child(_settings_slider_row(LineBook.row("SYS.SETTINGS", 2), sfx_vol, _set_sfx_vol))
	settings_body.add_child(_settings_slider_row(LineBook.row("SYS.SETTINGS", 1), music_vol, _set_music_vol))


func _fill_settings_edit() -> void:
	settings_body.add_child(_settings_check_row(LineBook.row("SYS.SETTINGS", 13), captions_on, _toggle_captions))
	settings_body.add_child(_settings_check_row(LineBook.row("SYS.SETTINGS", 14), crt_on, _toggle_crt))
	var lang := HBoxContainer.new()
	lang.add_theme_constant_override("separation", 12)
	lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _settings_label(LineBook.row("SYS.SETTINGS", 0))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang.add_child(label)
	lang.add_child(_settings_blue_button(settings_lang, _settings_languages, 120))
	settings_body.add_child(lang)


func _settings_languages() -> void:
	_clear_menu(settings_body)
	settings_body.add_child(_settings_label(LineBook.row("SYS.SETTINGS", 0)))
	for name in SETTINGS_LANGS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_settings_blue_button(name, _settings_pick_lang.bind(name), 160))
		if name == settings_lang:
			var mark := TextureRect.new()
			mark.texture = _tex_rgba("res://resources/ui/settings/checkbox_on.png")
			mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.custom_minimum_size = Vector2(24, 24)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(mark)
		settings_body.add_child(row)
	settings_body.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 3), _fill_settings, 160))


func _settings_pick_lang(name: String) -> void:
	if name in SETTINGS_LANGS:
		settings_lang = name
		_save_prefs()
	_fill_settings()


func _set_sfx_vol(value: float) -> void:
	sfx_vol = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_prefs()


func _set_music_vol(value: float) -> void:
	music_vol = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_prefs()


func _settings_support() -> void:
	OS.shell_open("https://support.nightschoolstudio.com/")


func _settings_faq() -> void:
	OS.shell_open("https://www.nightschoolstudio.com/thronglets")


func _settings_achievements() -> void:
	_clear_menu(settings_body)
	settings_body.add_child(_settings_label("LOGROS"))
	settings_body.add_child(_settings_label("—"))
	settings_body.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 3), _fill_settings, 160))


func _settings_credits() -> void:
	_clear_menu(settings_body)
	settings_body.add_child(_settings_label("CREDITOS"))
	settings_body.add_child(_settings_label("Night School Studio"))
	settings_body.add_child(_settings_label("Thronglets: Infinite"))
	settings_body.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 3), _fill_settings, 160))


func _settings_ask_reset() -> void:
	_clear_menu(settings_body)
	settings_body.add_child(_settings_label(LineBook.row("SYS.SETTINGS", 5)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 6), _settings_reset, 80))
	row.add_child(_settings_blue_button(LineBook.row("SYS.SETTINGS", 7), _fill_settings, 80))
	settings_body.add_child(row)


func _settings_reset() -> void:
	# Restablecer progreso: borrar todas las partidas guardadas (incluido el
	# guardado legado) y volver al título. No se inicia una partida nueva
	# automáticamente; el usuario elige comenzar una desde el menú principal.
	ThrongletSimServer.clear_saves()
	_show_title()


func _toggle_captions() -> void:
	captions_on = not captions_on
	_save_prefs()
	_fill_settings()


func _toggle_crt() -> void:
	crt_on = not crt_on
	_apply_crt()
	_save_prefs()
	_fill_settings()


func _sync_tutorial() -> void:
	if in_title or ThrongletSimServer.testing:
		return
	if ThrongletSimServer.tutorial_i >= 0:
		_set_hud_shown(false)


func _set_hud_shown(shown: bool) -> void:
	if hud_top != null:
		hud_top.visible = shown
	if menu_button != null:
		menu_button.visible = shown
	if save_icon != null and not shown:
		save_icon.visible = false
	if not shown:
		_set_kit_shown(false)


func _advance_sign() -> void:
	ThrongletSimServer.advance_tutorial()
	if ThrongletSimServer.tutorial_i < 0:
		_set_hud_shown(true)
		if sign_button != null:
			sign_button.visible = false


func _show_title() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	sim.cancel_hold()
	in_title = true
	sim.paused = true
	market_open = false
	_cancel_kit_drag()
	kit_open = false
	if kit_panel:
		_set_kit_shown(false)
	if slots_panel:
		slots_panel.visible = false
	if menu_dim:
		menu_dim.visible = false
	title_root.visible = true
	title_layout_size = Vector2.ZERO
	# El video del logo terminó; permitir música de título en el menú principal
	logo_video_playing = false
	_fill_title()
	# Fade-in de la música al mostrar el título principal tras el DOS
	if music != null:
		var tween: Tween = create_tween()
		tween.tween_property(music, "volume_db", -6.0, 1.0)


func _build_title_backdrop(root: Control) -> void:
	title_clouds.clear()
	title_time = 0.0
	title_layout_size = Vector2.ZERO
	var stage := Control.new()
	stage.name = "TitleBackdrop"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)

	var sky := _title_sprite("res://resources/ui/menu/sky_gradient.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(sky)

	title_flare = _title_sprite("res://resources/ui/menu/sun_flare.png", true)
	title_flare.stretch_mode = TextureRect.STRETCH_SCALE
	# Soft alpha lives in the PNG; mix keeps the falloff (ADD washed it to solid white).
	title_flare.modulate = Color(1, 1, 1, 1)
	stage.add_child(title_flare)

	var cloud_layer := Control.new()
	cloud_layer.name = "TitleClouds"
	cloud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_layer.clip_contents = false
	stage.add_child(cloud_layer)
	# 3 elliptical sky lanes; 2 clouds per lane, same right→left upper-arc direction.
	var cloud_tracks := [
		{"path": "res://resources/ui/menu/cloud_3.png", "width": 0.20, "cy": 0.13, "rx": 0.50, "ry": 0.045, "speed": 0.045, "phase": 0.10},
		{"path": "res://resources/ui/menu/cloud_2.png", "width": 0.28, "cy": 0.25, "rx": 0.56, "ry": 0.065, "speed": 0.038, "phase": 0.25},
		{"path": "res://resources/ui/menu/cloud_1.png", "width": 0.34, "cy": 0.37, "rx": 0.62, "ry": 0.080, "speed": 0.030, "phase": 0.40},
	]
	for track in cloud_tracks:
		for twin in [0.0, 0.5]:
			var cloud := _title_sprite(str(track.path), true)
			cloud.stretch_mode = TextureRect.STRETCH_SCALE
			cloud_layer.add_child(cloud)
			title_clouds.append({
				"node": cloud,
				"phase": float(track.phase) + twin,
				"speed": float(track.speed),
				"width": float(track.width),
				"cy": float(track.cy),
				"rx": float(track.rx),
				"ry": float(track.ry),
			})

	title_grass = _title_sprite("res://resources/ui/menu/grass.png", true)
	title_grass.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(title_grass)

	var cast := Control.new()
	cast.name = "TitleCast"
	cast.set_anchors_preset(Control.PRESET_FULL_RECT)
	cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(cast)

	title_front = _title_sprite("res://resources/ui/menu/thronglet_front.png", true)
	title_front.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_front)

	title_side = _title_sprite("res://resources/ui/menu/thronglet_side.png", true)
	title_side.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_side)

	title_egg = _title_sprite("res://resources/ui/menu/egg.png", true)
	title_egg.stretch_mode = TextureRect.STRETCH_SCALE
	cast.add_child(title_egg)

	title_logo = _title_sprite("res://resources/ui/menu/logo.png", true)
	title_logo.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(title_logo)


func _build_title_hud(root: Control) -> void:
	title_hud = Control.new()
	title_hud.name = "TitleHud"
	title_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_hud)
	title_bars = _title_icon_button("res://resources/ui/menu_bars.png", _fill_settings)
	# Keep tan bars readable under the green CRT wash.
	title_bars.modulate = Color(1.25, 1.05, 0.85)
	title_hud.add_child(title_bars)
	title_start = _title_wood_button(_title_press_start)
	title_hud.add_child(title_start)
	title_video = _title_icon_button("res://resources/ui/menu/video.png", _title_press_video, false)
	title_video.flat = false
	# Same OldOS cyan 9-slice used by the task banner (UI_OldOS_Button).
	var video_plate := _oldos_plate_style(4)
	title_video.add_theme_stylebox_override("normal", video_plate)
	title_video.add_theme_stylebox_override("hover", video_plate)
	title_video.add_theme_stylebox_override("pressed", video_plate)
	title_video.add_theme_stylebox_override("focus", video_plate)
	title_video.add_theme_stylebox_override("hover_pressed", video_plate)
	title_hud.add_child(title_video)


func _title_wood_button(call: Callable) -> Button:
	# High-res wood panel (same source as sign_plank); 9-slice keeps edges crisp.
	var button := Button.new()
	button.flat = false
	button.text = "Comenzar"
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", _ui_font())
	button.add_theme_font_size_override("font_size", 22)
	var ink := Color(1.0, 1.0, 0.96)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.78))
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", Color(0.14, 0.08, 0.04))
	var wood := _box_style("res://resources/ui/menu/start.png", 8, 0)
	button.add_theme_stylebox_override("normal", wood)
	button.add_theme_stylebox_override("hover", wood)
	button.add_theme_stylebox_override("pressed", wood)
	button.add_theme_stylebox_override("focus", wood)
	button.add_theme_stylebox_override("hover_pressed", wood)
	if call.is_valid():
		button.pressed.connect(func() -> void:
			# Sonido del botón de empezar/continuar (siempre ui_game_continue)
			_play_sfx_then("ui_game_continue", call)
		)
	return button


func _title_icon_button(path: String, call: Callable, fill: bool = false) -> Button:
	var button := Button.new()
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("hover_pressed", empty)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.texture = _tex_rgba(path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE if fill else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	button.set_meta("icon", icon)
	if call.is_valid():
		button.pressed.connect(func() -> void:
			_play("ui")
			call.call()
		)
	return button


func _title_press_start() -> void:
	if _continue_game():
		return
	_start_new_game()


func _title_press_video() -> void:
	_open_video_library()


func _title_sprite(path: String, keep_alpha: bool = false) -> TextureRect:
	var node := TextureRect.new()
	node.texture = _tex_rgba(path) if keep_alpha else _tex(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _title_fit(node: TextureRect, height: float) -> Vector2:
	var tex: Texture2D = node.texture
	if tex == null or tex.get_height() < 1:
		return Vector2(height, height)
	var aspect := float(tex.get_width()) / float(tex.get_height())
	return Vector2(height * aspect, height)


func _title_place(node: TextureRect, center: Vector2, size: Vector2) -> void:
	node.size = size
	node.position = Vector2(center.x - size.x * 0.5, center.y - size.y)


func _sync_title_layout(area: Vector2) -> void:
	if title_flare == null:
		return
	# Flare: compact backlight behind the cast (ref is smaller than full-screen wash).
	var flare_size := Vector2(area.x * 0.78, area.y * 0.58)
	title_flare.size = flare_size
	title_flare.position = Vector2((area.x - flare_size.x) * 0.5, area.y * 0.22)

	# Full grass sprite, bottom-aligned (COVERED was clipping the tree tops).
	var grass_tex: Texture2D = title_grass.texture
	var grass_aspect := 2.285
	if grass_tex != null and grass_tex.get_height() > 0:
		grass_aspect = float(grass_tex.get_width()) / float(grass_tex.get_height())
	var grass_h := area.x / grass_aspect
	title_grass.size = Vector2(area.x, grass_h)
	title_grass.position = Vector2(0.0, area.y - grass_h)

	# Shared ground line under egg + thronglets.
	var feet := area.y * 0.60
	var front_size := _title_fit(title_front, area.y * 0.355)
	var side_size := _title_fit(title_side, area.y * 0.285)
	var egg_size := _title_fit(title_egg, area.y * 0.180)
	_title_place(title_front, Vector2(area.x * 0.515, feet), front_size)
	_title_place(title_side, Vector2(area.x * 0.665, feet), side_size)
	_title_place(title_egg, Vector2(area.x * 0.365, feet), egg_size)

	# Logo larger, closer to ref (~half screen wide).
	var logo_size := _title_fit(title_logo, area.y * 0.21)
	if logo_size.x > area.x * 0.58 and title_logo.texture != null:
		logo_size.x = area.x * 0.58
		logo_size.y = logo_size.x * float(title_logo.texture.get_height()) / float(title_logo.texture.get_width())
	title_logo.size = logo_size
	title_logo.position = Vector2((area.x - logo_size.x) * 0.5, area.y * 0.035)

	_sync_title_hud(area)


func _tick_title(delta: float) -> void:
	if title_root == null or not title_root.visible:
		return
	title_time += delta
	var area := title_root.size
	if area.x < 8.0 or area.y < 8.0:
		return
	if area != title_layout_size:
		title_layout_size = area
		_sync_title_layout(area)
	# Full off-screen→off-screen X; Y follows the ellipse while inside its span.
	var cx := area.x * 0.5
	for cloud in title_clouds:
		var node: TextureRect = cloud.node
		var tex: Texture2D = node.texture
		if tex == null:
			continue
		var tw := area.x * float(cloud.width)
		var th := tw * float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
		var t: float = fposmod(float(cloud.phase) + title_time * float(cloud.speed), 1.0)
		var x := lerpf(area.x, -tw, t)
		var cloud_cx := x + tw * 0.5
		var rx_px := area.x * float(cloud.rx)
		var nx := clampf((cloud_cx - cx) / maxf(rx_px, 1.0), -1.0, 1.0)
		var y := area.y * float(cloud.cy) - area.y * float(cloud.ry) * sqrt(1.0 - nx * nx) - th * 0.5
		node.position = Vector2(x, y)
		node.size = Vector2(tw, th)


func _enter_game() -> void:
	in_title = false
	title_root.visible = false
	ThrongletSimServer.paused = false


func _reset_camera() -> void:
	zoom_level = 2.0
	dragging = false
	if camera == null:
		return
	camera.position = _to_iso(Vector2(256, 256))
	camera.zoom = Vector2(zoom_level, zoom_level)
	cam_from = camera.position


func _start_new_game() -> void:
	ThrongletSimServer.new_game()
	_reset_camera()
	_enter_game()


func _enter_dev() -> void:
	if dev_on and dev_bench != null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	sim.cancel_hold()
	sim.paused = true
	dev_on = true
	in_title = false
	if title_root:
		title_root.visible = false
	market_open = false
	_cancel_kit_drag()
	kit_open = false
	_blank_play_ui()
	if charge_ring:
		charge_ring.visible = false
	if charge_area:
		charge_area.visible = false
	for back in need_backs:
		back.visible = false
	for fill in need_fills:
		fill.visible = false
	_hide_marks()
	for plate in biome_plates:
		plate.visible = false
	for id in _monoliths.keys():
		var node: Node2D = _monoliths[id]
		node.visible = false
	dev_bench = DevBench.new()
	dev_bench.setup(self)
	add_child(dev_bench)
	dev_bench.open()


func _leave_dev() -> void:
	if not dev_on:
		return
	dev_on = false
	if dev_bench != null:
		dev_bench.close()
		dev_bench.queue_free()
		dev_bench = null
	_paint_props([])
	painted.clear()
	seen_epoch = -1
	if tilemap:
		tilemap.clear()
	_restore_play_ui()
	_show_title()


func _blank_play_ui() -> void:
	dev_hud_vis.clear()
	if ui == null or ui.get_child_count() == 0:
		return
	var root := ui.get_child(0)
	for child in root.get_children():
		dev_hud_vis[child.get_instance_id()] = child.visible
		child.visible = false


func _restore_play_ui() -> void:
	if ui == null or ui.get_child_count() == 0:
		return
	var root := ui.get_child(0)
	for child in root.get_children():
		var id := child.get_instance_id()
		if dev_hud_vis.has(id):
			child.visible = bool(dev_hud_vis[id])
	dev_hud_vis.clear()


func _sync_title_hud(area: Vector2) -> void:
	if title_hud == null:
		return
	# Fractions from original start-screen capture (menu bars / Start / shorts / profile).
	var bars_s := Vector2(area.x * 0.048, area.x * 0.040)
	title_bars.size = bars_s
	title_bars.position = Vector2(area.x * 0.022, area.y * 0.038)
	var start_s := Vector2(area.x * 0.265, area.y * 0.155)
	title_start.size = start_s
	title_start.position = Vector2(area.x * 0.383, area.y * 0.755)
	var video_s := Vector2(area.x * 0.128, area.y * 0.150)
	title_video.size = video_s
	title_video.position = Vector2(area.x * 0.795, area.y * 0.725)
	# Cam sits at ~55% of the plate height, with clear margin inside the dashed ring.
	var video_icon: TextureRect = title_video.get_meta("icon") as TextureRect
	if video_icon != null:
		var inset := video_s.y * 0.22
		video_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video_icon.offset_left = inset
		video_icon.offset_top = inset
		video_icon.offset_right = -inset
		video_icon.offset_bottom = -inset


func _fill_title() -> void:
	if title_menu != null:
		title_menu.visible = false
	if settings_shell != null:
		settings_shell.visible = false
	if title_hud != null:
		title_hud.visible = true
	title_layout_size = Vector2.ZERO
	# Cambiar texto del botón según si hay partida para continuar
	if title_start != null:
		title_start.text = "Continuar" if _has_continue() else "Comenzar"


func _has_continue() -> bool:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		return true
	return sim.has_checkpoint()


func _continue_game() -> bool:
	if not _has_continue():
		return false
	if ThrongletSimServer.resume_last():
		_enter_game()
		return true
	if ThrongletSimServer.load_checkpoint():
		_enter_game()
		return true
	return false


func _toggle_slots() -> void:
	if ThrongletSimServer.game_over:
		return
	_play("ui")
	if slots_panel.visible:
		_close_slots()
	else:
		_open_menu()


func _open_menu() -> void:
	slots_panel.visible = true
	menu_dim.visible = true
	ThrongletSimServer.paused = true
	market_open = false
	_clear_tool_charge()
	tool = Catalog.TOOL_EYE
	_cancel_kit_drag()
	kit_open = false
	_set_kit_shown(false)
	_show_menu()


func _close_slots() -> void:
	slots_panel.visible = false
	menu_dim.visible = false
	ThrongletSimServer.paused = false


func _show_menu() -> void:
	_clear_menu(slots_list)
	_menu_label(slots_list, "PAUSA")
	_menu_button(slots_list, "CONTINUAR", _close_slots)
	_menu_button(slots_list, "SALIR DE LA PARTIDA", _leave_to_title)
	_menu_button(slots_list, "SALIR DEL JUEGO", _quit_game)


func _clear_menu(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _menu_label(list: VBoxContainer, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", _menu_ink())
	list.add_child(title)


func _menu_button(list: VBoxContainer, text: String, call: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(180, 0)
	button.disabled = disabled
	var hover := _slot_style()
	hover.modulate_color = Color(1.0, 0.82, 0.45)
	var pressed := _slot_style()
	pressed.modulate_color = Color(0.55, 0.34, 0.18)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var ink := _menu_ink()
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.32, 0.22))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.82))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.94, 0.82))
	button.pressed.connect(func() -> void:
		_play("ui")
		call.call()
	)
	list.add_child(button)


func _sync_game_over() -> void:
	if over_panel == null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	var show: bool = sim.game_over and not in_title
	if over_panel.visible == show:
		return
	over_panel.visible = show
	if not show:
		return
	_play("gameover")
	gaze_panel.visible = false
	kit_open = false
	_set_kit_shown(false)
	market_open = false
	if market_panel:
		market_panel.visible = false
	slots_panel.visible = false
	if menu_dim:
		menu_dim.visible = false
	_fill_game_over()


func _fill_game_over() -> void:
	_clear_menu(over_list)
	_menu_label(over_list, "GAME OVER")
	_menu_label(over_list, "EL ULTIMO MULTI HA MUERTO")
	_menu_button(over_list, "EMPEZAR DE NUEVO", _game_over_restart)
	var rows: Array = ThrongletSimServer.list_checkpoints()
	if rows.is_empty():
		_menu_label(over_list, "NO HAY GUARDADOS")
		return
	_menu_label(over_list, "ULTIMOS GUARDADOS")
	for i in rows.size():
		var row: Dictionary = rows[i]
		_menu_button(over_list, _checkpoint_text(i, row), _game_over_load_slot.bind(int(row.i)))


func _checkpoint_text(order: int, row: Dictionary) -> String:
	var living := int(row.get("living", 0))
	if order == 0:
		return "ULTIMO  POB %d" % living
	return "ANTERIOR %d  POB %d" % [order, living]


func _game_over_restart() -> void:
	over_panel.visible = false
	_start_new_game()


func _game_over_load_slot(index: int) -> void:
	if not ThrongletSimServer.load_slot(index):
		return
	over_panel.visible = false
	_enter_game()


func _leave_to_title() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		sim.save_progress()
	_show_title()


func _quit_game() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.session_live and not sim.game_over:
		sim.save_progress()
	get_tree().quit()


func _save_current() -> void:
	ThrongletSimServer.save_progress()


func _tex(path: String) -> Texture2D:
	if textures.has(path):
		return textures[path]
	var tex: Texture2D = load(path)
	if tex == null or tex.get_width() < 1:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	textures[path] = tex
	return tex


func _tex_rgba(path: String) -> Texture2D:
	var key := path + "::rgba"
	if textures.has(key):
		return textures[key]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return _tex(path)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	textures[key] = tex
	return tex


func _menu_ink() -> Color:
	return Color(0.28, 0.14, 0.05)


func _panel_style() -> StyleBoxTexture:
	var style := _box_style("res://resources/ui/ui_frame_9patch.png", 8, 8)
	style.content_margin_top = 14
	return style


func _slot_style() -> StyleBoxTexture:
	return _box_style("res://resources/ui/ui_slot.png", 4, 3)


func _choice_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_content_margin_all(3)
	return style


func _goal_ink() -> Color:
	return Color(0.188, 0.322, 0.416)


func _oldos_plate_style(pad: int = 3) -> StyleBoxTexture:
	# Unity UI_OldOS_Button borders: L=20 B=18 R=17 T=20
	var style := StyleBoxTexture.new()
	style.texture = _tex_rgba("res://resources/ui/ui_oldos_button.png")
	style.texture_margin_left = 20
	style.texture_margin_right = 17
	style.texture_margin_top = 20
	style.texture_margin_bottom = 18
	style.set_content_margin_all(pad)
	return style


func _goal_outer_style() -> StyleBoxFlat:
	# Original GOAL banner: thick white plate + drop shadow.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(3)
	style.shadow_color = Color(0.22, 0.22, 0.2, 0.7)
	style.shadow_size = 2
	style.shadow_offset = Vector2(3, 3)
	style.set_content_margin_all(3)
	return style


func _goal_cyan_style() -> StyleBoxFlat:
	# Thin cyan ring inside the white plate (original inner stroke).
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(88.0 / 255.0, 192.0 / 255.0, 216.0 / 255.0, 1)
	style.set_border_width_all(2)
	style.set_content_margin_all(2)
	return style


func _goal_tag_style() -> StyleBoxTexture:
	return _box_style("res://resources/ui/ui_goal_tag.png", 0, 3)


func _goal_body_style() -> StyleBoxTexture:
	return _box_style("res://resources/ui/ui_goal_body.png", 0, 3)


func _box_style(path: String, edge: int, pad: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _tex(path)
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	style.texture_margin_top = edge
	style.texture_margin_bottom = edge
	style.set_content_margin_all(pad)
	return style


func _speech_bubble_style() -> StyleBoxTexture:
	var style := _box_style("res://resources/ui/speech_bubble_0.png", 7, 4)
	_bubble_margins(style, 0)
	return style


func _bubble_margins(style: StyleBoxTexture, frame: int) -> void:
	# Unity border of UI_SpeechBubble_Spritesheet: left, right, top, bottom.
	# The tail sits in the right and bottom patches, so those do not stretch.
	var edges := [
		[7, 23, 7, 14],
		[6, 22, 6, 13],
		[8, 24, 8, 15],
		[7, 23, 7, 15],
		[8, 24, 8, 15],
	]
	var edge: Array = edges[frame]
	style.texture_margin_left = int(edge[0])
	style.texture_margin_right = int(edge[1])
	style.texture_margin_top = int(edge[2])
	style.texture_margin_bottom = int(edge[3])
	style.content_margin_left = 6
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = int(edge[3])


func _apply_bubble_frame(panel: PanelContainer, frame: int) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null:
		return
	style.texture = _tex("res://resources/ui/speech_bubble_%d.png" % frame)
	_bubble_margins(style, frame)


func _tick_shot() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if shot_board == null:
		if sim.shot_throng >= 0:
			selected = sim.shot_throng
		if sim.shot_factory >= 0:
			selected_bld = sim.shot_factory
		var reach := sim.shot_span
		var half_w := reach * sqrt(2.0)
		var half_h := reach * 0.70710678
		var view := get_viewport_rect().size
		var zoom := minf(view.x / (half_w * 2.0 + 64.0), view.y / (half_h * 2.0 + 96.0))
		if shot_path_saved:
			zoom_level = 4.0
			camera.zoom = Vector2(4.0, 4.0)
			camera.position = _to_iso(sim.shot_path)
		else:
			zoom_level = zoom
			camera.zoom = Vector2(zoom, zoom)
			camera.position = _to_iso(sim.shot_focus)
		shot_frames += 1
		if not shot_dos_saved:
			if ui != null:
				ui.visible = true
			_open_dos()
			dos_shown = dos_full.length()
			dos_label.text = dos_full
			if shot_frames < 4:
				return
			if not _save_shot(get_viewport(), "res://shots/dos.png"):
				get_tree().quit(1)
				return
			_finish_dos()
			shot_dos_saved = true
			shot_frames = 0
			return
		if not shot_title_saved:
			in_title = true
			if ui != null:
				ui.visible = true
			title_root.visible = true
			crt_on = true
			_apply_crt()
			_fill_title()
			title_layout_size = Vector2.ZERO
			_tick_title(0.0)
			if shot_frames < 8:
				return
			if not _save_shot(get_viewport(), "res://shots/title.png"):
				get_tree().quit(1)
				return
			shot_title_saved = true
			shot_frames = 0
			return
		if not shot_settings_saved:
			in_title = true
			title_root.visible = true
			crt_on = true
			_apply_crt()
			var settings_shots := [
				{"tab": 0, "path": "res://shots/settings_mail.png"},
				{"tab": 1, "path": "res://shots/settings_cog.png"},
				{"tab": 2, "path": "res://shots/settings_sound.png"},
				{"tab": 3, "path": "res://shots/settings.png"},
			]
			var shot_i := mini(shot_frames / 4, settings_shots.size() - 1)
			var spec: Dictionary = settings_shots[shot_i]
			settings_tab = int(spec.tab)
			crt_on = true
			_apply_crt()
			_fill_settings()
			if shot_frames % 4 != 3:
				return
			if not _save_shot(get_viewport(), str(spec.path)):
				get_tree().quit(1)
				return
			if shot_i < settings_shots.size() - 1:
				return
			crt_on = false
			_apply_crt()
			title_root.visible = false
			in_title = false
			shot_settings_saved = true
			shot_frames = 0
			return
		if not shot_video_saved:
			in_title = true
			title_root.visible = true
			crt_on = true
			_apply_crt()
			_fill_title()
			if title_menu != null:
				title_menu.visible = false
			if title_hud != null:
				title_hud.visible = true
			if video_library_grid == null or video_library_grid.get_child_count() == 0:
				video_played["SEQ_1.5"] = true
				_fill_video_library()
			if video_library != null:
				video_library.visible = true
				_layout_video_library_shell()
			if shot_frames < 8:
				return
			if not _save_shot(get_viewport(), "res://shots/video_library.png"):
				get_tree().quit(1)
				return
			if video_library != null:
				video_library.visible = false
			title_root.visible = false
			in_title = false
			shot_video_saved = true
			shot_frames = 0
			return
		if not shot_sign_saved:
			sim.tutorial_i = 2
			_set_hud_shown(false)
			_sync_focus(0.0)
			if shot_frames < 4:
				return
			if not _save_shot(get_viewport(), "res://shots/sign.png"):
				get_tree().quit(1)
				return
			sim.tutorial_i = -1
			if sign_button != null:
				sign_button.visible = false
			_set_hud_shown(true)
			_sync_focus(0.0)
			shot_sign_saved = true
			shot_frames = 0
			return
		if not shot_hud_saved:
			# After egg fall finishes, capture task HUD with dialogue glitch cleared.
			sim.glitch_t = 0.0
			if glitch_overlay != null:
				glitch_overlay.visible = false
			sim.modal = {}
			sim.talk_pending = {}
			sim.frozen = false
			sim.tutorial_i = -1
			if sign_button != null:
				sign_button.visible = false
			if not shot_egg_done:
				var egg := _starter_egg()
				if egg.is_empty():
					sim._spawn_starter_egg()
					egg = _starter_egg()
				if float(egg.get("air", 0.0)) <= 0.0 and focus_hold <= 0.0 and shot_frames == 1:
					egg.air = 140.0
					egg.x = 256.0
					egg.y = 256.0
				var egg_air := float(egg.get("air", 0.0))
				if egg_air > 0.0:
					egg.air = maxf(0.0, egg_air - 6.0)
					focus_hold = 0.45
					if ui != null:
						ui.visible = true
					_set_hud_shown(true)
					_sync_focus(0.016)
					return
				if focus_hold > 0.0:
					focus_hold = maxf(0.0, focus_hold - 0.016)
					_sync_focus(0.016)
					return
				shot_egg_done = true
				shot_frames = 0
				return
			focus_on = false
			if focus_dim != null:
				focus_dim.visible = false
			if focus_frame != null:
				focus_frame.visible = false
			if focus_box != null:
				focus_box.visible = false
			if sim.barks.is_empty() and sim.shot_throng >= 0:
				sim.barks.append({
					"id": sim.shot_throng,
					"icon": Catalog.ICON_APPLE,
					"t": 30.0,
					"x": sim.pos_x[sim.shot_throng],
					"y": sim.pos_y[sim.shot_throng],
				})
			if ui != null:
				ui.visible = true
			_set_hud_shown(true)
			kit_open = true
			kit_tab = 0
			_set_kit_shown(true)
			_sync_hud(0.0)
			_sync_focus(0.0)
			if task_panel != null:
				task_panel.visible = true
			if shot_frames < 12:
				return
			if not _save_shot(get_viewport(), "res://shots/hud_task.png"):
				get_tree().quit(1)
				return
			shot_hud_saved = true
			sim.barks.clear()
			shot_frames = 0
			return
		if not shot_console_saved:
			if ui != null:
				ui.visible = true
			kit_open = false
			_set_kit_shown(false)
			if sim.modal.is_empty():
				sim._queue_talk("first_born", {})
				shot_frames = 0
				return
			_sync_gaze()
			_sync_focus(0.0)
			# Wait out dialogue-open glitch before capture.
			if sim.glitch_t > 0.0 or shot_frames < 24:
				return
			if not _save_shot(get_viewport(), "res://shots/console.png"):
				get_tree().quit(1)
				return
			sim.modal = {}
			sim.frozen = false
			sim._restore_gaze()
			if ui != null:
				ui.visible = false
			shot_console_saved = true
			shot_frames = 0
			return
		if not shot_name_saved:
			if ui != null:
				ui.visible = true
			if sim.modal.is_empty():
				sim._open_name_ask()
				sim.glitch_t = 0.0
				sim.modal["draft"] = "Ana"
				shot_frames = 0
				return
			_sync_gaze()
			_sync_focus(0.0)
			if shot_frames < 24:
				return
			if not _save_shot(get_viewport(), "res://shots/name.png"):
				get_tree().quit(1)
				return
			sim.modal = {}
			sim.frozen = false
			sim._restore_gaze()
			if name_edit != null:
				name_edit.visible = false
			if ui != null:
				ui.visible = false
			shot_name_saved = true
			shot_frames = 0
			return
		if not shot_path_saved:
			if shot_frames < 12:
				return
			if not _save_shot(get_viewport(), "res://shots/island_all.png"):
				get_tree().quit(1)
				return
			camera.position = _to_iso(sim.shot_path)
			camera.zoom = Vector2(4.0, 4.0)
			zoom_level = 4.0
			shot_path_saved = true
			shot_frames = 0
			return
		if shot_frames < 6:
			return
		if not _save_shot(get_viewport(), "res://shots/path_zoom.png"):
			get_tree().quit(1)
			return
		_build_asset_shot()
		shot_frames = 0
		return
	shot_frames += 1
	if shot_frames < 4:
		return
	shot_done = true
	var ok := _save_shot(shot_board, "res://shots/wired_assets.png")
	get_tree().quit(0 if ok else 1)


func _save_shot(source: Viewport, path: String) -> bool:
	var image := source.get_texture().get_image()
	if image == null or image.get_width() < 2:
		print("SHOT FAIL no image %s" % path)
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var err := image.save_png(path)
	print("SHOT %s path=%s size=%sx%s" % ["OK" if err == OK else "FAIL", path, image.get_width(), image.get_height()])
	return err == OK


func _build_asset_shot() -> void:
	var board := SubViewport.new()
	board.size = Vector2i(960, 980)
	board.disable_3d = true
	board.transparent_bg = false
	board.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(board)
	shot_board = board
	var sheet := MultiMeshInstance2D.new()
	sheet.texture = world.texture
	sheet.material = world.material
	sheet.multimesh = _mesh(true, Vector2(WORLD_CELL, WORLD_CELL))
	board.add_child(sheet)
	var samples: Array = [
		["idle", ThrongClips.frame_at("ThrongA_Default", 0), 0.0],
		["talk", ThrongClips.frame_at("ThrongA_Talk", 2), 0.0],
		["dead", ThrongClips.frame_at("ThrongA_Dead_001", 0), 0.0],
		["bones", ThrongClips.frame_at("ThrongA_Bones", 0), 0.0],
		["sing", ThrongClips.frame_at("Throng_Sing_Spritesheet", 2), 0.0],
		["kick", ThrongClips.frame_at("ThrongA_Bored_KickRock", 6), 0.0],
		["ghost", ThrongClips.frame_at("ThrongA_Default_Ghost", 0), 0.0],
		["outline", ThrongClips.frame_at("Thronglet_Outline", 0), 0.0],
		["celebrate", ThrongClips.frame_at("ThrongA_Celebrate_Spritesheet", 4), 0.0],
		["shrug", ThrongClips.frame_at("ThrongA_Shrug", 1), 0.0],
		["think", ThrongClips.frame_at("ThrongA_DeepThought_Spritesheet", 1), 0.0],
		["jump", ThrongClips.frame_at("ThrongA_Jump", 0), 0.0],
		["dirty", ThrongClips.frame_at("ThrongA_Default", 0), 1.0],
		["bubble", AssetFrames.frame(AssetFrames.BUBBLE, AssetFrames.BUBBLE_N, 0), 0.0],
		["foam", AssetFrames.frame(AssetFrames.BUBBLE_LIGHT, AssetFrames.BUBBLE_LIGHT_N, 1), 0.0],
		["clean", AssetFrames.frame(AssetFrames.CLEAN, AssetFrames.CLEAN_N, 1), 0.0],
		["splash", AssetFrames.frame(AssetFrames.SPLASH, AssetFrames.SPLASH_N, 1), 0.0],
		["smoke", AssetFrames.frame(AssetFrames.SMOKE, AssetFrames.SMOKE_N, 1), 0.0],
		["aura", AssetFrames.frame(AssetFrames.AURA, AssetFrames.AURA_N, 1), 0.0],
		["spark", AssetFrames.frame(AssetFrames.SPARK, AssetFrames.SPARK_N, 1), 0.0],
		["glitch", AssetFrames.frame(AssetFrames.GLITCH, AssetFrames.GLITCH_N, 3), 0.0],
		["tile", AssetFrames.frame(AssetFrames.TILE_GLITCH, AssetFrames.TILE_GLITCH_N, 1), 0.0],
		["hand", AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, 1), 0.0],
		["fire", AssetFrames.FIRE, 0.0],
		["blob", AssetFrames.FIRE_BLOB, 0.0],
		["house", AssetFrames.GLITCH_HOUSE, 0.0],
		["gtree", AssetFrames.GLITCH_TREE, 0.0],
		["treec", AssetFrames.GLITCH_TREE_C, 0.0],
		["treed", AssetFrames.GLITCH_TREE_D, 0.0],
		["waste", AssetFrames.WASTE_TREE, 0.0],
		["wasteb", AssetFrames.WASTE_TREE_B, 0.0],
		["anomaly", AssetFrames.ANOMALY, 0.0],
		["ray", AssetFrames.ANOMALY_RAY, 0.0],
		["epilogue", AssetFrames.EPILOGUE, 0.0],
		["rotten", AssetFrames.ROTTEN_APPLE, 0.0],
		["mount", AssetFrames.MOUNT_BIG, 0.0],
		["fumes", AssetFrames.FUMES, 0.0],
		["grass", AssetFrames.GRASS_PATCH, 0.0],
		["suds", AssetFrames.SUDS, 0.0],
	]
	var draws: Array = []
	var labels := CanvasLayer.new()
	board.add_child(labels)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(root)
	var theme := Theme.new()
	var font := _ui_font()
	if font != null:
		theme.default_font = font
		theme.default_font_size = 16
	root.theme = theme
	var scale := 0.55
	var cols := 8
	for i in samples.size():
		var sample: Array = samples[i]
		var col := i % cols
		var row := int(i / cols)
		var center := Vector2(56 + col * 116, 58 + row * 108)
		var frame := int(sample[1])
		if frame < 0:
			continue
		draws.append({
			"p": center + Vector2(0, WORLD_CELL * 0.5 * scale),
			"icon": frame,
			"tint": Color.WHITE,
			"scale": scale,
			"dirty": float(sample[2]),
		})
		var tag := Label.new()
		tag.text = str(sample[0])
		tag.position = center + Vector2(-40, 34)
		tag.size = Vector2(80, 12)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(tag)
	_write_mesh(sheet.multimesh, draws)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 820)
	panel.custom_minimum_size = Vector2(620, 120)
	if ResourceLoader.exists("res://resources/ui/wood_panel.png"):
		panel.add_theme_stylebox_override("panel", _box_style("res://resources/ui/wood_panel.png", 24, 24))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var quote := Label.new()
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.custom_minimum_size = Vector2(540, 70)
	quote.add_theme_font_size_override("font_size", 16)
	var line := LineBook.line_for("shot_check")
	quote.text = line if line != "" else "SIN LINEA"
	margin.add_child(quote)
	root.add_child(panel)
	var faces := ["epilogue_angry", "epilogue_bewildered", "epilogue_caretaker", "epilogue_birthday", "epilogue_capitalist"]
	for i in faces.size():
		var face := TextureRect.new()
		face.texture = _tex(POP_FACES[faces[i]])
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.position = Vector2(660 + (i % 3) * 96, 820 + int(i / 3) * 70)
		face.size = Vector2(88, 64)
		root.add_child(face)
	var plates: PackedStringArray = _biome_plate_paths("epilogue")
	plates.append_array(_biome_plate_paths("anomaly"))
	for i in plates.size():
		var plate := TextureRect.new()
		plate.texture = _tex(plates[i])
		plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		plate.position = Vector2(16 + i * 100, 760)
		plate.size = Vector2(92, 28)
		root.add_child(plate)


func _build_audio() -> void:
	for _i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_pool.append(player)
	music = AudioStreamPlayer.new()
	music.volume_db = -6.0
	add_child(music)
	amb = AudioStreamPlayer.new()
	amb.volume_db = -16.0
	add_child(amb)
	sting = AudioStreamPlayer.new()
	sting.volume_db = -4.0
	add_child(sting)
	_fill_bank()
	_build_video()


func _fill_bank() -> void:
	sfx_bank["chop"] = _clips(PackedStringArray(["tree_chop.wav", "tree_chop__01.wav", "tree_chop__02.wav"]))
	sfx_bank["saw"] = _clips(_seq("sfx_chainsaw_cut_", 1, 4))
	sfx_bank["hammer"] = _clips(_seq("sfx_hammer_hit_", 1, 4))
	sfx_bank["pick"] = _clips(_seq("sfx_pickaxe_hit_", 1, 6))
	sfx_bank["rock_break"] = _clips(PackedStringArray([
		"sfx_rock_break_01.wav", "sfx_rock_break_02.wav", "sfx_rock_break_04.wav",
		"sfx_rock_break_05.wav", "sfx_rock_break_06.wav",
	]))
	sfx_bank["rock_crack"] = _clips(_seq("sfx_rock_crack_", 1, 6))
	sfx_bank["stump"] = _clips(_seq("sfx_tree_stump_destroy_", 1, 4))
	sfx_bank["mop"] = _clips(_seq("sfx_mop_use_", 1, 6))
	sfx_bank["scrub"] = _clips(PackedStringArray(["thronglet_scrub_a.wav"]))
	sfx_bank["egg_fall"] = _clips(PackedStringArray(["sfx_egg_fall_01.wav"]))
	sfx_bank["egg_land"] = _clips(PackedStringArray(["sfx_egg_impact_grass_01.wav"]))
	sfx_bank["egg_crack"] = _clips(PackedStringArray(["egg_crack.wav"]))
	sfx_bank["egg_hatch"] = _clips(PackedStringArray(["egg_hatch.wav"]))
	sfx_bank["hatch"] = _clips(PackedStringArray(["hatch_success_stinger.wav"]))
	sfx_bank["mitosis"] = _clips(PackedStringArray(["mitosis_small_pop.wav"]))
	sfx_bank["apple"] = _clips(PackedStringArray(["apple_chomps.wav"]))
	sfx_bank["ball"] = _clips(PackedStringArray(["ball_kick_a.wav"]))
	sfx_bank["grab"] = _clips(PackedStringArray(["sfx_grabber_pickUp.wav"]))
	sfx_bank["release"] = _clips(PackedStringArray(["sfx_grabber_release.wav"]))
	sfx_bank["wood_grab"] = _clips(_seq("sfx_thronglet_lumber_grab_", 1, 6))
	sfx_bank["wood_drop"] = _clips(_seq("sfx_thronglet_lumber_drop_", 1, 6))
	sfx_bank["bone_grab"] = _clips(_seq("sfx_thronglet_bones_grab_", 1, 6))
	sfx_bank["bone_drop"] = _clips(_seq("sfx_thronglet_bones_drop_", 1, 6))
	sfx_bank["bridge_wood"] = _clips(_seq("sfx_bridge_wood_segment_complete_", 1, 4))
	sfx_bank["bridge_bone"] = _clips(_seq("sfx_bridge_bones_segment_complete_", 1, 4))
	sfx_bank["place_house"] = _clips(_seq("sfx_house_place_", 1, 3))
	sfx_bank["place_tub"] = _clips(_seq("sfx_bathtub_place_", 1, 5))
	sfx_bank["place_round"] = _clips(_seq("sfx_roundabout_place_", 1, 3))
	sfx_bank["place_factory"] = _clips(_seq("sfx_factory_place_", 1, 3))
	sfx_bank["place_mine"] = _clips(_seq("sfx_mine_place_", 1, 3))
	sfx_bank["place_theatre"] = _clips(_seq("sfx_theatre_place_", 1, 3))
	sfx_bank["place_statue"] = _clips(PackedStringArray(["sfx_sculpture_place.wav"]))
	sfx_bank["place_apple"] = _clips(_seq("sfx_tree_apple_plant_", 1, 4))
	sfx_bank["place"] = _clips(PackedStringArray(["sfx_general_tool_use.wav"]))
	sfx_bank["tub_in"] = _clips(_seq("sfx_bathtub_enter_", 1, 6))
	sfx_bank["tub_out"] = _clips(_seq("sfx_bathtub_exit_", 1, 6))
	sfx_bank["round_start"] = _clips(_seq("sfx_roundabout_start_", 1, 4))
	sfx_bank["tnt_place"] = _clips(PackedStringArray(["sfx_dynamite_place.wav"]))
	sfx_bank["tnt_arm"] = _clips(PackedStringArray(["sfx_dynamite_activate.wav"]))
	sfx_bank["explode"] = _clips(PackedStringArray(["sfx_dynamite_explode_st.wav"]))
	sfx_bank["nuke"] = _clips(PackedStringArray(["sfx_nuke_explode.wav"]))
	sfx_bank["bones"] = _clips(_seq("sfx_thronglet_bones_drop_", 1, 6))
	sfx_bank["deflesh"] = _clips(PackedStringArray(["deflesh_a.wav"]))
	sfx_bank["crush"] = _clips(PackedStringArray(["thronglet_crush.wav"]))
	sfx_bank["fire_start"] = _clips(_seq("sfx_fire_start_", 1, 5))
	sfx_bank["fire_out"] = _clips(_seq("sfx_fire_extinguish_", 1, 5))
	sfx_bank["heal"] = _clips(_seq("sfx_healerHeart_activate_", 1, 6))
	sfx_bank["monolith_in"] = _clips(PackedStringArray(["sfx_monolith_appear.wav"]))
	sfx_bank["monolith"] = _clips(PackedStringArray(["sfx_monolith_interact.wav"]))
	sfx_bank["unlock"] = _clips(PackedStringArray(["sfx_general_unlock.wav"]))
	sfx_bank["unlock_axe"] = _clips(PackedStringArray(["sfx_axe_unlock.wav"]))
	sfx_bank["unlock_hammer"] = _clips(PackedStringArray(["sfx_hammer_unlock.wav"]))
	sfx_bank["unlock_pickaxe"] = _clips(PackedStringArray(["sfx_pickaxe_unlock.wav"]))
	sfx_bank["unlock_mop"] = _clips(PackedStringArray(["sfx_mop_unlock.wav"]))
	sfx_bank["unlock_chainsaw"] = _clips(PackedStringArray(["sfx_chainsaw_unlock.wav"]))
	sfx_bank["unlock_grabber"] = _clips(PackedStringArray(["sfx_grabber_unlock.wav"]))
	sfx_bank["unlock_nuke"] = _clips(PackedStringArray(["sfx_nuke_unlock.wav"]))
	sfx_bank["unlock_tnt"] = _clips(PackedStringArray(["sfx_dynamite_unlock.wav"]))
	sfx_bank["unlock_bathtub"] = _clips(PackedStringArray(["sfx_bathtub_unlock.wav"]))
	sfx_bank["unlock_roundabout"] = _clips(PackedStringArray(["sfx_roundabout_unlock.wav"]))
	sfx_bank["unlock_apple_tree"] = _clips(PackedStringArray(["sfx_tree_apple_unlock.wav"]))
	sfx_bank["unlock_fire"] = _clips(PackedStringArray(["sfx_fire_unlock.wav"]))
	sfx_bank["unlock_bug"] = _clips(PackedStringArray(["sfx_ladybug_unlock.wav"]))
	sfx_bank["ui"] = _clips(PackedStringArray(["ui_click_messy.wav"]))
	sfx_bank["locked"] = _clips(PackedStringArray(["ui_tool_unavailable.wav"]))
	sfx_bank["error"] = _clips(PackedStringArray(["ui_error.wav"]))
	sfx_bank["talk"] = _clips(PackedStringArray(["sfx_text_bubble_open.wav"]))
	sfx_bank["bird"] = _clips(_seq("ambScatter_act1n2_bird_", 1, 8))
	sfx_bank["voice_prrr"] = _clips(_seq("vo_thronglet_prrr_", 1, 13))
	sfx_bank["voice_sing"] = _clips(_seq("vo_thronglet_sing_", 1, 6))
	sfx_bank["voice_sing"].append_array(_clips(_seq("vo_throng_sing_group_small_", 1, 13)))
	sfx_bank["dialogue_in"] = _clips(_seq("ui_dialogue_frame_in_", 1, 7))
	sfx_bank["dialogue_out"] = _clips(_seq("ui_dialogue_frame_out_", 1, 8))
	sfx_bank["console"] = _clips(_seq("ui_console_new_line_", 1, 4))
	sfx_bank["console_select"] = _clips(PackedStringArray(["ui_console_select.wav", "ui_console_prompt.wav"]))
	sfx_bank["speed"] = _clips(_seq("sfx_thronglet_speed_run_", 1, 6))
	sfx_bank["superore"] = _clips(_seq("sfx_superOre_lift_", 1, 6))
	sfx_bank["superore"].append_array(_clips(_seq("sfx_superOre_drop_", 1, 4)))
	sfx_bank["splash"] = _clips(_seq("sfx_water_splash_", 1, 4))
	sfx_bank["uplink"] = _clips(_seq("sfx_uplink_add_negative_", 1, 3))
	sfx_bank["uplink"].append_array(_clips(_seq("sfx_uplink_add_positive_", 1, 3)))
	sfx_bank["uplink"].append_array(_clips(_seq("sfx_uplink_add_thronglet_single_", 1, 3)))
	sfx_bank["gameover"] = _clips(PackedStringArray([
		"sfx_data_overload_gameOver_1stPopUp_head.wav",
		"sfx_data_overload_gameOver_1stPopUp_lp.wav",
	]))
	sfx_bank["gameover"].append_array(_clips(_seq("sfx_data_overload_gameOver_popUp_other_", 1, 6)))
	sfx_bank["monolith_reveal"] = _clips(PackedStringArray(["monolith_reveal_nobeat_nobar.ogg"]))
	sfx_bank["nuked"] = _clips(PackedStringArray(["thronglets_nuked_nobpm_nobar.ogg"]))
	sfx_bank["artifact_finale"] = _clips(PackedStringArray(["artifact_finale_140bpm_44bar.ogg"]))
	sfx_bank["finale_outro"] = _clips(PackedStringArray(["finale_outro.ogg"]))
	sfx_bank["code_layer"] = _clips(PackedStringArray([
		"code_layer_in_a.ogg",
		"code_layer_loop_120bpm_23bar.ogg",
		"code_layer_out_a.ogg",
	]))
	# --- Ambientes ---
	sfx_bank["amb_spot_market_lp"] = _clips(PackedStringArray(["amb_spot_market_lp.ogg"]))
	sfx_bank["amb_spot_mine_lp"] = _clips(PackedStringArray(["amb_spot_mine_lp.wav"]))
	sfx_bank["amb_spot_mountainVoidOpening_lp"] = _clips(PackedStringArray(["amb_spot_mountainVoidOpening_lp.wav"]))
	sfx_bank["amb_spot_pollution"] = _clips(PackedStringArray(["amb_spot_pollution.ogg"]))
	sfx_bank["ambBed_act1n2_barrenWind"] = _clips(PackedStringArray(["ambBed_act1n2_barrenWind.ogg"]))
	sfx_bank["ambBed_act1n2_softWindBirds_lp"] = _clips(PackedStringArray(["ambBed_act1n2_softWindBirds_lp.ogg"]))
	sfx_bank["ambBed_act3_lp"] = _clips(PackedStringArray(["ambBed_act3_lp.ogg"]))
	sfx_bank["throngletville_amb_st"] = _clips(PackedStringArray(["throngletville_amb_st.ogg"]))
	sfx_bank["venice_three_84dot5bpm_58bar"] = _clips(PackedStringArray(["venice_three_84dot5bpm_58bar.ogg"]))

	# --- Música y stingers ---
	sfx_bank["music_title"] = _clips(PackedStringArray(["thronglets_title_theme_180bpm_24bar.ogg"]))
	sfx_bank["music_megafm_a"] = _clips(PackedStringArray(["thronglets_megafm_a_140bpm_72bar.ogg"]))
	sfx_bank["music_megafm_b"] = _clips(PackedStringArray(["thronglets_megafm_b_140bpm_88bar.ogg"]))
	sfx_bank["music_fieldwork"] = _clips(PackedStringArray(["fieldwork_140bpm_108bar.ogg"]))
	sfx_bank["music_wasteland_one"] = _clips(PackedStringArray(["wasteland_one_160bpm_134bar.ogg"]))
	sfx_bank["music_wasteland_two"] = _clips(PackedStringArray(["wasteland_part_two_160bpm_156bar.ogg"]))
	sfx_bank["music_toward_artifact"] = _clips(PackedStringArray(["toward_the_artifact_140bpm_208bar.ogg"]))
	sfx_bank["music_finale"] = _clips(PackedStringArray(["thronglets_finale_76bpm_74bar.ogg"]))
	sfx_bank["music_artifact_finale"] = _clips(PackedStringArray(["artifact_finale_140bpm_44bar.ogg"]))
	sfx_bank["music_actIII_millions_A"] = _clips(PackedStringArray(["actIII_millions_oneshot_A.ogg"]))
	sfx_bank["music_actIII_millions_B"] = _clips(PackedStringArray(["actIII_millions_oneshot_B.ogg"]))
	sfx_bank["music_actIII_millions_C"] = _clips(PackedStringArray(["actIII_millions_oneshot_C.ogg"]))
	sfx_bank["music_artifact_reveal"] = _clips(PackedStringArray(["artifact_reveal_140bpm_10bar.ogg"]))
	sfx_bank["music_artifact_hum"] = _clips(PackedStringArray(["artifact_hum_loop.ogg"]))
	sfx_bank["music_nuked"] = _clips(PackedStringArray(["thronglets_nuked_nobpm_nobar.ogg"]))
	sfx_bank["music_actii_intro"] = _clips(PackedStringArray(["act_ii_intro_welcome_progress_nobpm_nobar.ogg"]))
	sfx_bank["music_wasteland_intro"] = _clips(PackedStringArray(["wasteland_intro_oneshot.ogg"]))
	sfx_bank["music_code_layer_in"] = _clips(PackedStringArray(["code_layer_in_a.ogg"]))
	sfx_bank["music_code_layer_loop"] = _clips(PackedStringArray(["code_layer_loop_120bpm_23bar.ogg"]))
	sfx_bank["music_code_layer_out"] = _clips(PackedStringArray(["code_layer_out_a.ogg"]))
	sfx_bank["music_tnt_multmel"] = _clips(PackedStringArray(["tnt_multmel_108bbpm_88bar.ogg"]))
	sfx_bank["music_finale_outro"] = _clips(PackedStringArray(["finale_outro.ogg"]))

	# --- UI ---
	sfx_bank["ui_button_click"] = _clips(PackedStringArray(["code_layer_in_a.ogg"]))
	sfx_bank["ui_game_continue"] = _clips(PackedStringArray(["ui_game_continue.wav"]))
	sfx_bank["ui_game_continue_broken"] = _clips(PackedStringArray(["ui_game_continue_broken.wav"]))
	sfx_bank["ui_click_messy_0"] = _clips(PackedStringArray(["ui_click_messy_0.wav"]))
	sfx_bank["ui_click_messy"] = _clips(PackedStringArray(["ui_click_messy.wav"]))
	sfx_bank["ui_console_prompt"] = _clips(PackedStringArray(["ui_console_prompt.wav"]))
	sfx_bank["ui_dialogue_frame_in"] = _clips(_seq("ui_dialogue_frame_in_", 1, 7))
	sfx_bank["ui_dialogue_frame_out"] = _clips(_seq("ui_dialogue_frame_out_", 1, 8))
	sfx_bank["ui_droplet_up"] = _clips(PackedStringArray(["ui_droplet_up.wav"]))
	sfx_bank["ui_error"] = _clips(PackedStringArray(["ui_error.wav"]))
	sfx_bank["ui_fm_bump"] = _clips(PackedStringArray(["ui_fm_bump.wav"]))
	sfx_bank["ui_slide_a"] = _clips(PackedStringArray(["ui_slide_a.wav"]))
	sfx_bank["ui_tool_unavailable"] = _clips(PackedStringArray(["ui_tool_unavailable.wav"]))
	sfx_bank["ui_act2_tutorial_window_open"] = _clips(PackedStringArray(["ui_act2_tutorial_window_open.wav"]))
	sfx_bank["ui_act2_tutorial_window_close"] = _clips(PackedStringArray(["ui_act2_tutorial_window_close.wav"]))
	sfx_bank["ui_act2_tutorial_window_lp"] = _clips(PackedStringArray(["ui_act2_tutorial_window_lp.wav"]))

	# --- Herramientas y construcciones ---
	sfx_bank["sfx_axe_unlock"] = _clips(PackedStringArray(["sfx_axe_unlock.wav"]))
	sfx_bank["sfx_bathtub_enter"] = _clips(_seq("sfx_bathtub_enter_", 1, 6))
	sfx_bank["sfx_bathtub_exit"] = _clips(_seq("sfx_bathtub_exit_", 1, 6))
	sfx_bank["sfx_bathtub_place"] = _clips(_seq("sfx_bathtub_place_", 1, 5))
	sfx_bank["sfx_bathtub_unlock"] = _clips(PackedStringArray(["sfx_bathtub_unlock.wav"]))
	sfx_bank["sfx_bridge_bones_segment_complete"] = _clips(_seq("sfx_bridge_bones_segment_complete_", 1, 4))
	sfx_bank["sfx_bridge_wood_segment_complete"] = _clips(_seq("sfx_bridge_wood_segment_complete_", 1, 4))
	sfx_bank["sfx_camera_move_lp"] = _clips(PackedStringArray(["sfx_camera_move_lp.wav"]))
	sfx_bank["sfx_cannon_place"] = _clips(PackedStringArray(["sfx_cannon_place.wav"]))
	sfx_bank["sfx_cannon_shot"] = _clips(_seq("sfx_cannon_shot_", 1, 6))
	sfx_bank["sfx_cannon_unlock"] = _clips(PackedStringArray(["sfx_cannon_unlock.wav"]))
	sfx_bank["sfx_chainsaw_cut"] = _clips(_seq("sfx_chainsaw_cut_", 1, 4))
	sfx_bank["sfx_chainsaw_unlock"] = _clips(PackedStringArray(["sfx_chainsaw_unlock.wav"]))
	sfx_bank["sfx_computer_loading_windows_appear_lp"] = _clips(PackedStringArray(["sfx_computer_loading_windows_appear_lp.wav"]))
	sfx_bank["sfx_computer_skipButton_click"] = _clips(PackedStringArray(["sfx_computer_skipButton_click.wav"]))
	sfx_bank["sfx_cutscene_nuke_result_lp_st"] = _clips(PackedStringArray(["sfx_cutscene_nuke_result_lp_st.wav"]))
	sfx_bank["sfx_dynamite_activate"] = _clips(PackedStringArray(["sfx_dynamite_activate.wav"]))
	sfx_bank["sfx_dynamite_explode_st"] = _clips(PackedStringArray(["sfx_dynamite_explode_st.wav"]))
	sfx_bank["sfx_dynamite_place"] = _clips(PackedStringArray(["sfx_dynamite_place.wav"]))
	sfx_bank["sfx_dynamite_select"] = _clips(PackedStringArray(["sfx_dynamite_select.wav"]))
	sfx_bank["sfx_dynamite_unlock"] = _clips(PackedStringArray(["sfx_dynamite_unlock.wav"]))
	sfx_bank["sfx_eden_artifact_presence_lp"] = _clips(PackedStringArray(["sfx_eden_artifact_presence_lp.wav"]))
	sfx_bank["sfx_eden_artifact_reach_st"] = _clips(PackedStringArray(["sfx_eden_artifact_reach_st.wav"]))
	sfx_bank["sfx_eden_artifact_thronglets_eyesGlow_st"] = _clips(PackedStringArray(["sfx_eden_artifact_thronglets_eyesGlow_st.wav"]))
	sfx_bank["sfx_eden_artifact_thronglets_glow_st"] = _clips(PackedStringArray(["sfx_eden_artifact_thronglets_glow_st.wav"]))
	sfx_bank["sfx_egg_fall_01"] = _clips(PackedStringArray(["sfx_egg_fall_01.wav"]))
	sfx_bank["sfx_egg_impact_grass_01"] = _clips(PackedStringArray(["sfx_egg_impact_grass_01.wav"]))
	sfx_bank["sfx_factory_place"] = _clips(_seq("sfx_factory_place_", 1, 3))
	sfx_bank["sfx_fire_extinguish"] = _clips(_seq("sfx_fire_extinguish_", 1, 5))
	sfx_bank["sfx_fire_lp_01"] = _clips(PackedStringArray(["sfx_fire_lp_01.wav"]))
	sfx_bank["sfx_fire_start"] = _clips(_seq("sfx_fire_start_", 1, 5))
	sfx_bank["sfx_fire_unlock"] = _clips(PackedStringArray(["sfx_fire_unlock.wav"]))
	sfx_bank["sfx_general_tool_grab"] = _clips(PackedStringArray(["sfx_general_tool_grab.wav"]))
	sfx_bank["sfx_general_tool_use"] = _clips(PackedStringArray(["sfx_general_tool_use.wav"]))
	sfx_bank["sfx_general_unlock"] = _clips(PackedStringArray(["sfx_general_unlock.wav"]))
	sfx_bank["sfx_glitch_special_dialUp"] = _clips(PackedStringArray(["sfx_glitch_special_dialUp.wav"]))
	sfx_bank["sfx_grabber_pickUp"] = _clips(PackedStringArray(["sfx_grabber_pickUp.wav"]))
	sfx_bank["sfx_grabber_release"] = _clips(PackedStringArray(["sfx_grabber_release.wav"]))
	sfx_bank["sfx_grabber_unlock"] = _clips(PackedStringArray(["sfx_grabber_unlock.wav"]))
	sfx_bank["sfx_hammer_hit"] = _clips(_seq("sfx_hammer_hit_", 1, 4))
	sfx_bank["sfx_hammer_unlock"] = _clips(PackedStringArray(["sfx_hammer_unlock.wav"]))
	sfx_bank["sfx_healerHeart_activate"] = _clips(_seq("sfx_healerHeart_activate_", 1, 6))
	sfx_bank["sfx_healerHeart_grab"] = _clips(PackedStringArray(["sfx_healerHeart_grab.wav"]))
	sfx_bank["sfx_healerHeart_place"] = _clips(PackedStringArray(["sfx_healerHeart_place.wav"]))
	sfx_bank["sfx_healerHeart_unlock"] = _clips(PackedStringArray(["sfx_healerHeart_unlock.wav"]))
	sfx_bank["sfx_house_place"] = _clips(_seq("sfx_house_place_", 1, 3))
	sfx_bank["sfx_intro_linear01_console_st"] = _clips(PackedStringArray(["sfx_intro_linear01_console_st.wav"]))
	sfx_bank["sfx_item_buy"] = _clips(PackedStringArray(["sfx_item_buy.wav"]))
	sfx_bank["sfx_item_unlock_glitch_layer"] = _clips(PackedStringArray(["sfx_item_unlock_glitch_layer.wav"]))
	sfx_bank["sfx_ladybug_grab"] = _clips(PackedStringArray(["sfx_ladybug_grab.wav"]))
	sfx_bank["sfx_ladybug_unlock"] = _clips(PackedStringArray(["sfx_ladybug_unlock.wav"]))
	sfx_bank["sfx_levelStart_eden_st"] = _clips(PackedStringArray(["sfx_levelStart_eden_st.wav"]))
	sfx_bank["sfx_mine_place"] = _clips(_seq("sfx_mine_place_", 1, 3))
	sfx_bank["sfx_monolith_appear"] = _clips(PackedStringArray(["sfx_monolith_appear.wav"]))
	sfx_bank["sfx_monolith_interact"] = _clips(PackedStringArray(["sfx_monolith_interact.wav"]))
	sfx_bank["sfx_mop_grab_01"] = _clips(PackedStringArray(["sfx_mop_grab_01.wav"]))
	sfx_bank["sfx_mop_unlock"] = _clips(PackedStringArray(["sfx_mop_unlock.wav"]))
	sfx_bank["sfx_mop_use"] = _clips(_seq("sfx_mop_use_", 1, 6))
	sfx_bank["sfx_mountain_explode_st"] = _clips(PackedStringArray(["sfx_mountain_explode_st.wav"]))
	sfx_bank["sfx_nuke_countdown_lp"] = _clips(PackedStringArray(["sfx_nuke_countdown_lp.wav"]))
	sfx_bank["sfx_nuke_explode"] = _clips(PackedStringArray(["sfx_nuke_explode.wav"]))
	sfx_bank["sfx_nuke_place"] = _clips(PackedStringArray(["sfx_nuke_place.wav"]))
	sfx_bank["sfx_nuke_select"] = _clips(PackedStringArray(["sfx_nuke_select.wav"]))
	sfx_bank["sfx_nuke_unlock"] = _clips(PackedStringArray(["sfx_nuke_unlock.wav"]))
	sfx_bank["sfx_pickaxe_hit"] = _clips(_seq("sfx_pickaxe_hit_", 1, 6))
	sfx_bank["sfx_pickaxe_unlock"] = _clips(PackedStringArray(["sfx_pickaxe_unlock.wav"]))
	sfx_bank["sfx_quietPopUp_musicGlitch"] = _clips(PackedStringArray(["sfx_quietPopUp_musicGlitch.wav"]))
	sfx_bank["sfx_rock_break"] = _clips(PackedStringArray([
		"sfx_rock_break_01.wav", "sfx_rock_break_02.wav", "sfx_rock_break_04.wav",
		"sfx_rock_break_05.wav", "sfx_rock_break_06.wav",
	]))
	sfx_bank["sfx_rock_crack"] = _clips(_seq("sfx_rock_crack_", 1, 6))
	sfx_bank["sfx_roundabout_place"] = _clips(_seq("sfx_roundabout_place_", 1, 3))
	sfx_bank["sfx_roundabout_start"] = _clips(_seq("sfx_roundabout_start_", 1, 4))
	sfx_bank["sfx_roundabout_unlock"] = _clips(PackedStringArray(["sfx_roundabout_unlock.wav"]))
	sfx_bank["sfx_sculpture_place"] = _clips(PackedStringArray(["sfx_sculpture_place.wav"]))
	sfx_bank["sfx_sculpture_select"] = _clips(PackedStringArray(["sfx_sculpture_select.wav"]))
	sfx_bank["sfx_superOre_drop"] = _clips(_seq("sfx_superOre_drop_", 1, 4))
	sfx_bank["sfx_superOre_lift"] = _clips(_seq("sfx_superOre_lift_", 1, 6))
	sfx_bank["sfx_teleport_appear"] = _clips(PackedStringArray(["sfx_teleport_appear.wav"]))
	sfx_bank["sfx_teleport_doorAppear"] = _clips(PackedStringArray(["sfx_teleport_doorAppear.wav"]))
	sfx_bank["sfx_teleport_doorClose"] = _clips(PackedStringArray(["sfx_teleport_doorClose.wav"]))
	sfx_bank["sfx_teleport_galaxy_presence_lp"] = _clips(PackedStringArray(["sfx_teleport_galaxy_presence_lp.wav"]))
	sfx_bank["sfx_teleport_lp"] = _clips(PackedStringArray(["sfx_teleport_lp.wav"]))
	sfx_bank["sfx_teleport_thronglet_disappear"] = _clips(PackedStringArray(["sfx_teleport_thronglet_disappear.wav"]))
	sfx_bank["sfx_text_bubble_close"] = _clips(PackedStringArray(["sfx_text_bubble_close.wav"]))
	sfx_bank["sfx_text_bubble_next"] = _clips(PackedStringArray(["sfx_text_bubble_next.wav"]))
	sfx_bank["sfx_text_bubble_open"] = _clips(PackedStringArray(["sfx_text_bubble_open.wav"]))
	sfx_bank["sfx_theatre_place"] = _clips(_seq("sfx_theatre_place_", 1, 3))
	sfx_bank["sfx_thonglePackage_close"] = _clips(PackedStringArray(["sfx_thonglePackage_close.wav"]))
	sfx_bank["sfx_thonglePackage_loading_lp"] = _clips(PackedStringArray(["sfx_thonglePackage_loading_lp.wav"]))
	sfx_bank["sfx_thonglePackage_open"] = _clips(PackedStringArray(["sfx_thonglePackage_open.wav"]))
	sfx_bank["sfx_thronglet_bones_drop"] = _clips(_seq("sfx_thronglet_bones_drop_", 1, 6))
	sfx_bank["sfx_thronglet_bones_grab"] = _clips(_seq("sfx_thronglet_bones_grab_", 1, 6))
	sfx_bank["sfx_thronglet_emoji_01"] = _clips(PackedStringArray(["sfx_thronglet_emoji_01.wav"]))
	sfx_bank["sfx_thronglet_eyeGlow"] = _clips(PackedStringArray(["sfx_thronglet_eyeGlow.wav"]))
	sfx_bank["sfx_thronglet_lumber_drop"] = _clips(_seq("sfx_thronglet_lumber_drop_", 1, 6))
	sfx_bank["sfx_thronglet_lumber_grab"] = _clips(_seq("sfx_thronglet_lumber_grab_", 1, 6))
	sfx_bank["sfx_thronglet_speed_run"] = _clips(_seq("sfx_thronglet_speed_run_", 1, 6))
	sfx_bank["sfx_tree_apple_plant"] = _clips(_seq("sfx_tree_apple_plant_", 1, 4))
	sfx_bank["sfx_tree_apple_unlock"] = _clips(PackedStringArray(["sfx_tree_apple_unlock.wav"]))
	sfx_bank["sfx_tree_stump_destroy"] = _clips(_seq("sfx_tree_stump_destroy_", 1, 4))
	sfx_bank["sfx_uplink_add_bomb"] = _clips(PackedStringArray(["sfx_uplink_add_bomb.wav"]))
	sfx_bank["sfx_uplink_add_negative"] = _clips(_seq("sfx_uplink_add_negative_", 1, 3))
	sfx_bank["sfx_uplink_add_positive"] = _clips(_seq("sfx_uplink_add_positive_", 1, 3))
	sfx_bank["sfx_uplink_add_thronglet_multiple_lp_noHearts"] = _clips(PackedStringArray(["sfx_uplink_add_thronglet_multiple_lp_noHearts.wav"]))
	sfx_bank["sfx_uplink_add_thronglet_single"] = _clips(_seq("sfx_uplink_add_thronglet_single_", 1, 3))
	sfx_bank["sfx_uplink_googlyEyes_appear"] = _clips(PackedStringArray(["sfx_uplink_googlyEyes_appear.wav"]))
	sfx_bank["sfx_uplink_grab"] = _clips(PackedStringArray(["sfx_uplink_grab.wav"]))
	sfx_bank["sfx_uplink_place"] = _clips(PackedStringArray(["sfx_uplink_place.wav"]))
	sfx_bank["sfx_uplink_unlock"] = _clips(PackedStringArray(["sfx_uplink_unlock.wav"]))
	sfx_bank["sfx_water_splash"] = _clips(_seq("sfx_water_splash_", 1, 4))

	# --- Thronglets (voces y sonidos) ---
	sfx_bank["thronglet_crush"] = _clips(PackedStringArray(["thronglet_crush.wav"]))
	sfx_bank["thronglet_glitch_a"] = _clips(PackedStringArray(["thronglet_glitch_a.wav"]))
	sfx_bank["thronglet_glitch_b"] = _clips(PackedStringArray(["thronglet_glitch_b.wav"]))
	sfx_bank["thronglet_glitch_c"] = _clips(PackedStringArray(["thronglet_glitch_c.wav"]))
	sfx_bank["thronglet_glitch_d"] = _clips(PackedStringArray(["thronglet_glitch_d.wav"]))
	sfx_bank["thronglet_glitch_e"] = _clips(PackedStringArray(["thronglet_glitch_e.wav"]))
	sfx_bank["thronglet_jump_megafm"] = _clips(PackedStringArray(["thronglet_jump_megafm.wav"]))
	sfx_bank["thronglet_scrub_a"] = _clips(PackedStringArray(["thronglet_scrub_a.wav"]))
	sfx_bank["WaterSplashBeep"] = _clips(PackedStringArray(["WaterSplashBeep.wav"]))
	sfx_bank["artifact_hum_loop"] = _clips(PackedStringArray(["artifact_hum_loop.ogg"]))
	sfx_bank["hatch_success_stinger"] = _clips(PackedStringArray(["hatch_success_stinger.wav"]))
	sfx_bank["monolith_reveal_nobeat_nobar"] = _clips(PackedStringArray(["monolith_reveal_nobeat_nobar.ogg"]))

	# --- Voces de thronglets ---
	sfx_bank["vo_throng_sing_group_small"] = _clips(_seq("vo_throng_sing_group_small_", 1, 13))
	sfx_bank["vo_thronglet_prrr"] = _clips(_seq("vo_thronglet_prrr_", 1, 13))
	sfx_bank["vo_thronglet_sing"] = _clips(_seq("vo_thronglet_sing_", 1, 6))
	sfx_bank["vo_thronglet_upset_04"] = _clips(PackedStringArray(["vo_thronglet_upset_04.wav"]))
	sfx_bank["vo_thronglet_upset_06"] = _clips(PackedStringArray(["vo_thronglet_upset_06.wav"]))
	sfx_bank["vo_thronglet_upset_09"] = _clips(PackedStringArray(["vo_thronglet_upset_09.wav"]))
	sfx_bank["vo_thronglet_upset_11"] = _clips(PackedStringArray(["vo_thronglet_upset_11.wav"]))
	sfx_bank["vo_thronglet_upset_12"] = _clips(PackedStringArray(["vo_thronglet_upset_12.wav"]))

	_fill_loose_clips()
	sfx_bank["voice_upset"] = _clips(PackedStringArray([
		"vo_thronglet_upset_04.wav", "vo_thronglet_upset_06.wav", "vo_thronglet_upset_09.wav",
		"vo_thronglet_upset_11.wav", "vo_thronglet_upset_12.wav",
	]))


func _seq(prefix: String, first: int, last: int) -> PackedStringArray:
	var names := PackedStringArray()
	for i in range(first, last + 1):
		names.append("%s%02d.wav" % [prefix, i])
	return names


func _fill_loose_clips() -> void:
	var packed := {}
	for key in sfx_bank.keys():
		for stream in sfx_bank[key]:
			packed[stream] = true
	var dir := DirAccess.open("res://resources/audio")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".ogg")):
			var stream := _load_stream(file_name)
			if stream != null and not packed.has(stream):
				sfx_bank[file_name.get_basename()] = [stream]
				packed[stream] = true
		file_name = dir.get_next()


func _build_video() -> void:
	video_player = VideoStreamPlayer.new()
	video_player.visible = false
	video_player.z_index = 80
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.finished.connect(_on_video_finished)
	var layer := CanvasLayer.new()
	layer.layer = 1000
	add_child(layer)
	captions_layer = layer
	var plate := ColorRect.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.color = Color(0, 0, 0, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	video_player.set_meta("plate", plate)
	layer.add_child(plate)
	layer.add_child(video_player)
	captions_label = _make_captions_label()
	layer.add_child(captions_label)


func _make_captions_label() -> Label:
	var label := Label.new()
	# Bottom-wide with negative offsets keeps text above the screen edge.
	# z_index must beat video_player (80) or the full-rect video covers the text.
	label.z_index = 90
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 80
	label.offset_right = -80
	label.offset_top = -160
	label.offset_bottom = -48
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _ui_font())
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _ensure_captions_label() -> void:
	if captions_label != null and is_instance_valid(captions_label):
		return
	if captions_layer == null:
		var new_layer := CanvasLayer.new()
		new_layer.layer = 1000
		add_child(new_layer)
		captions_layer = new_layer
	captions_label = _make_captions_label()
	captions_layer.add_child(captions_label)


func _caption_table_for(base: String) -> String:
	# MOV_01..MOV_08 map to SEQ_1.5..SEQ_8.3 and localization tables SUB_SEQ_1..8.
	if not base.begins_with("SEQ_"):
		return ""
	var seq_n := int(base.substr(4).get_slice(".", 0))
	if seq_n < 1:
		return ""
	return "SUB_SEQ_%d" % seq_n


func _caption_display_text(raw: String) -> String:
	return str(raw).strip_edges().replace("\\n", "\n")


func _clear_captions() -> void:
	captions_lines.clear()
	captions_ends.clear()
	captions_index = -1
	if captions_label != null:
		captions_label.visible = false
		captions_label.text = ""


func _show_captions_for(base: String) -> void:
	_ensure_captions_label()
	_clear_captions()
	if captions_label == null or not captions_on:
		return
	var table := _caption_table_for(base)
	if table == "":
		return
	var weights: Array = []
	var total_weight := 0.0
	var i := 0
	while true:
		var raw := LineBook.row(table, i)
		if raw == "":
			break
		var text := _caption_display_text(raw)
		i += 1
		if text == "":
			continue
		captions_lines.append(text)
		var weight := maxf(24.0, float(text.length()))
		weights.append(weight)
		total_weight += weight
	if captions_lines.is_empty() or total_weight <= 0.0:
		return
	var duration := 0.0
	if video_player != null:
		duration = video_player.get_stream_length()
	if duration <= 0.05:
		duration = total_weight * 0.08
	var cursor := 0.0
	for weight in weights:
		cursor += duration * (float(weight) / total_weight)
		captions_ends.append(cursor)
	_apply_caption_at(0.0)


func _apply_caption_at(pos: float) -> void:
	if captions_label == null or captions_lines.is_empty():
		return
	var idx := 0
	while idx < captions_ends.size() and pos >= float(captions_ends[idx]):
		idx += 1
	if idx >= captions_lines.size():
		idx = captions_lines.size() - 1
	if idx == captions_index:
		return
	captions_index = idx
	captions_label.text = str(captions_lines[idx])
	captions_label.visible = true
	captions_label.move_to_front()


func _tick_captions() -> void:
	if not captions_on or captions_lines.is_empty():
		return
	if video_player == null or not video_player.visible or not video_player.is_playing():
		return
	_apply_caption_at(video_player.stream_position)


func _play_video(base: String, from_title: bool) -> bool:
	var path := "res://resources/video/" + base + ".ogv"
	if not ResourceLoader.exists(path):
		return false
	var stream: VideoStream = load(path)
	if stream == null:
		return false
	video_player.stream = stream
	video_player.visible = true
	var plate: ColorRect = video_player.get_meta("plate") as ColorRect
	if plate != null:
		plate.visible = false
	if music != null:
		var tween: Tween = create_tween()
		tween.tween_property(music, "volume_db", -80.0, 0.5)
	if sting != null:
		var tween2: Tween = create_tween()
		tween2.tween_property(sting, "volume_db", -80.0, 0.5)
	video_player.play()
	video_played[base] = true
	video_from_title = from_title
	_show_captions_for(base)
	return true


func _on_video_finished() -> void:
	# Siempre limpiar video y plate al terminar
	if video_player != null:
		video_player.visible = false
		var plate: ColorRect = video_player.get_meta("plate") as ColorRect
		if plate != null:
			plate.visible = false
	_clear_captions()
	# Si el video del logo aún no empezó, salir sin avanzar
	if boot == "logo" and not logo_started:
		return
	# Restaurar música después del video (solo si no es el logo intro)
	if boot != "logo":
		if music != null:
			var tween: Tween = create_tween()
			tween.tween_property(music, "volume_db", -6.0, 1.0)
		if sting != null:
			var tween2: Tween = create_tween()
			tween2.tween_property(sting, "volume_db", -4.0, 1.0)
	if boot == "logo":
		video_player.volume_db = 0.0
		_begin_dos()
		return
	if video_from_library:
		video_from_library = false
		_show_title()
		_open_video_library()
		return
	if video_from_title:
		video_from_title = false
		_show_title()


func _maybe_play_sequence(mode: String) -> void:
	var clips := {
		"mountain": "SEQ_2.1",
		"glitch": "ConsoleText",
		"anomaly": "SEQ_7.3",
		"epilogue": "SEQ_8.3",
	}
	if not clips.has(mode) or video_played.has(mode):
		return
	if _play_video(str(clips[mode]), false):
		video_played[mode] = true
		if mode == "glitch":
			_play_file("code_layer_in_a.ogg", false)
		elif mode == "epilogue":
			_play("artifact_finale")
			_play("finale_outro")


func _clips(names: PackedStringArray) -> Array:
	var out: Array = []
	for clip_name in names:
		var stream := _load_stream(clip_name)
		if stream != null:
			out.append(stream)
	return out


func _load_stream(clip_name: String) -> AudioStream:
	var path := "res://resources/audio/" + clip_name
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream != null:
			return stream
	if clip_name.ends_with(".wav"):
		return _load_wav(path)
	return null


# Carga WAVs sin .import (dumps Unity con headers rotos o aún no reimportados).
func _load_wav(path: String) -> AudioStream:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw := file.get_buffer(file.get_length())
	file.close()
	if raw.size() < 44:
		return null
	var data_offset := -1
	var data_size := 0
	var cursor := 12
	while cursor + 8 <= raw.size():
		var chunk_id := String(raw.slice(cursor, cursor + 4).get_string_from_ascii())
		var chunk_size := int(raw.decode_u32(cursor + 4))
		if chunk_id == "data":
			data_offset = cursor + 8
			data_size = chunk_size if chunk_size > 0 else raw.size() - data_offset
			break
		cursor += 8 + chunk_size + (chunk_size & 1)
	if data_offset < 0:
		return null
	var channels := int(raw.decode_u16(22))
	var mix_rate := int(raw.decode_u32(24))
	var bits := int(raw.decode_u16(34))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = mix_rate if mix_rate > 0 else 44100
	wav.stereo = channels > 1
	wav.data = raw.slice(data_offset, mini(data_offset + data_size, raw.size()))
	return wav


func _play(name: String) -> void:
	if name.begins_with("unlock_") and not _has_clip(name):
		name = "unlock"
	if not _has_clip(name):
		return
	var clips: Array = sfx_bank[name]
	var stream: AudioStream = clips[randi() % clips.size()]
	var player := _free_sfx()
	player.stream = stream
	player.play()


# Reproduce un SFX y ejecuta `callback` al terminar. Hace fade-out de la música del menú.
func _play_sfx_then(name: String, callback: Callable) -> void:
	if music != null:
		var music_tween := create_tween()
		music_tween.tween_property(music, "volume_db", -80.0, 0.5)

	var wait_time := 0.35
	if _has_clip(name):
		_play(name)
		var stream: AudioStream = sfx_bank[name][0]
		if stream != null:
			wait_time = maxf(stream.get_length(), 0.1)
	else:
		_play("ui")

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		if callback.is_valid():
			callback.call()
	)
	timer.start()


func _has_clip(name: String) -> bool:
	if not sfx_bank.has(name):
		return false
	var clips: Array = sfx_bank[name]
	return not clips.is_empty()


func _free_sfx() -> AudioStreamPlayer:
	for raw in sfx_pool:
		var player := raw as AudioStreamPlayer
		if player != null and not player.playing:
			return player
	return sfx_pool[0] as AudioStreamPlayer


func _sync_music() -> void:
	if logo_video_playing:
		return
	var mode := "title"
	if not in_title:
		mode = _camera_biome()
		if mode == "":
			mode = "meadow"
	if mode == music_mode:
		_sync_spot_amb()
		return
	var previous := music_mode
	music_mode = mode
	_play_biome_bed(mode)
	_play_biome_stinger(mode, previous)
	_sync_spot_amb()
	_maybe_play_sequence(mode)


func _play_biome_bed(mode: String) -> void:
	if mode == "title":
		_loop_bed(music, "thronglets_title_theme_180bpm_24bar.ogg")
		amb.stop()
	elif mode == "mountain":
		_loop_bed(music, "thronglets_megafm_b_140bpm_88bar.ogg")
		_loop_bed(amb, "amb_spot_mountainVoidOpening_lp.wav")
	elif mode == "glitch":
		_loop_bed(music, "wasteland_one_160bpm_134bar.ogg")
		_loop_bed(amb, "ambBed_act3_lp.ogg")
	elif mode == "anomaly":
		_loop_bed(music, "wasteland_part_two_160bpm_156bar.ogg")
		_loop_bed(amb, "amb_spot_pollution.ogg")
	elif mode == "epilogue":
		_loop_bed(music, "toward_the_artifact_140bpm_208bar.ogg")
		_loop_bed(amb, "artifact_hum_loop.ogg")
	elif mode == "waste":
		_loop_bed(music, "wasteland_one_160bpm_134bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_barrenWind.ogg")
	else:
		_loop_bed(music, "fieldwork_140bpm_108bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_softWindBirds_lp.ogg")


func _play_biome_stinger(mode: String, previous: String) -> void:
	if previous == "":
		return
	var once := {
		"mountain": "thronglets_megafm_a_140bpm_72bar.ogg",
		"glitch": "actIII_millions_oneshot_A.ogg",
		"anomaly": "artifact_reveal_140bpm_10bar.ogg",
		"epilogue": "thronglets_finale_76bpm_74bar.ogg",
	}
	if once.has(mode):
		_play_file(str(once[mode]), false)


func _sync_spot_amb() -> void:
	if in_title or music_mode == "mountain" or music_mode == "glitch" or music_mode == "anomaly" or music_mode == "epilogue":
		return
	var spot := _near_spot()
	if spot == spot_mode:
		return
	spot_mode = spot
	if spot == "mine":
		_loop_bed(amb, "amb_spot_mine_lp.wav")
	elif spot == "market":
		_loop_bed(amb, "amb_spot_market_lp.ogg")
	elif spot == "pollution":
		_loop_bed(amb, "amb_spot_pollution.ogg")
	elif music_mode == "waste":
		_loop_bed(amb, "ambBed_act1n2_barrenWind.ogg")
	else:
		_loop_bed(amb, "ambBed_act1n2_softWindBirds_lp.ogg")


func _near_spot() -> String:
	var sim: ThrongletSim = ThrongletSimServer
	var at := _from_iso(camera.position)
	var mine := false
	var market := false
	for building in sim.buildings:
		if bool(building.get("dead", false)):
			continue
		var kind := int(building.get("kind", -1))
		var dist := at.distance_to(Vector2(float(building.x), float(building.y)))
		if dist > 180.0:
			continue
		if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			mine = true
		elif kind == Catalog.BLD_MARKET:
			market = true
	if mine:
		return "mine"
	if market:
		return "market"
	return ""


func _play_file(file_name: String, looped: bool) -> void:
	var loaded: AudioStream = load("res://resources/audio/" + file_name)
	if loaded == null:
		return
	var stream := loaded
	if loaded is AudioStreamOggVorbis:
		var ogg := loaded.duplicate() as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = looped
			stream = ogg
	if sting == null:
		return
	sting.stream = stream
	sting.play()


func _loop_bed(player: AudioStreamPlayer, file_name: String) -> void:
	var loaded: AudioStream = load("res://resources/audio/" + file_name)
	if loaded == null:
		return
	var stream := loaded
	if loaded is AudioStreamOggVorbis:
		var ogg := loaded.duplicate() as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
			stream = ogg
	player.stream = stream
	player.play()


func _tick_birds(delta: float) -> void:
	if music_mode != "field":
		return
	bird_wait -= delta
	if bird_wait > 0.0:
		return
	bird_wait = randf_range(7.0, 14.0)
	_play("bird")
