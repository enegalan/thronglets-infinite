extends Node2D

var camera: Camera2D
var tilemap: TileMapLayer
var world: MultiMeshInstance2D
var world_mesh: MultiMesh
var place_fill: Polygon2D
var place_edge: Line2D
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
const FIRE_ANIM := 140
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
}
var gem_panel: PanelContainer
var gem_label: Label
var goal_label: Label
var hint: Label
var toast: Label
var need_show := false
var need_backs: Array = []
var need_fills: Array = []
var bubble_labels: Array = []
var bubble_icons: Array = []
var full_labels: Array = []
var ring_lines: Array = []
var glitch_bars: Array = []
var glitch_label: Label
var ui_theme: Theme
var kit_panel: PanelContainer
var kit_tabs: HBoxContainer
var kit_icons: HFlowContainer
var res_label: Label
var kit_open := false
var kit_tab := 0
var in_title := true
var title_root: Control
var title_list: VBoxContainer
var hand_from := Vector2.ZERO
var sponge_last := Vector2.ZERO
var sponge_dir := Vector2.ZERO
var sponge_tracking := false
var market_panel: PanelContainer
var market_list: VBoxContainer
var gaze_panel: PanelContainer
var gaze_text: Label
var gaze_box: VBoxContainer
var focus_dim: ColorRect
var focus_frame: Panel
var focus_shade: ShaderMaterial
var focus_box: SubViewportContainer
var focus_port: SubViewport
var focus_tilemap: TileMapLayer
var focus_mesh: MultiMesh
var focus_cam_node: Camera2D
var task_panel: PanelContainer
var focus_on := false
var focus_hold := 0.0
var slots_panel: PanelContainer
var over_panel: PanelContainer
var over_list: VBoxContainer
var slots_list: VBoxContainer
var menu_dim: ColorRect
var pause_page := "root"
var tool_buttons := {}
var build_buttons := {}
var sfx_bank := {}
var sfx_pool: Array = []
var music: AudioStreamPlayer
var amb: AudioStreamPlayer
var music_mode := ""
var bird_wait := 8.0
var textures := {}


func _ready() -> void:
	_build_sky()
	_build_world()
	_build_audio()
	_build_ui()
	camera.position = _to_iso(Vector2(256, 256))
	camera.zoom = Vector2(zoom_level, zoom_level)
	if ThrongletSimServer.testing:
		in_title = false
	else:
		_show_title()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
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
	if in_title:
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
	if factor <= 0.0:
		return
	zoom_level = clampf(zoom_level * factor, ZOOM_MIN, ZOOM_MAX)


func _unhandled_input(event: InputEvent) -> void:
	if in_title or ThrongletSimServer.game_over:
		return
	var sim := ThrongletSimServer
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
				if pause_page == "root":
					_close_slots()
				else:
					_show_menu()
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
	_sync_music()
	_tick_birds(delta)
	if in_title:
		_sync_place_mark()
		if charge_ring != null:
			charge_ring.visible = false
		if charge_area != null:
			charge_area.visible = false
		if need_show:
			selected = -1
			_sync_need_bars()
		_hide_marks()
		return
	var sim := ThrongletSimServer
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
	_sync_world()
	_sync_actors()
	_sync_place_mark()
	_sync_charge_mark()
	_sync_hud(delta)
	_sync_need_bars()
	_sync_marks()
	_sync_glitch(delta)
	_sync_market()
	_sync_gaze()
	_sync_focus(delta)
	for name in sim.take_sfx():
		_play(str(name))


func _world_click() -> void:
	var sim := ThrongletSimServer
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
	var sim := ThrongletSimServer
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
	var sim := ThrongletSimServer
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
	var target := sim.charge_tool_target(used, at.x, at.y)
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


func _hand_press() -> void:
	var sim := ThrongletSimServer
	var at := _aim_thronglet(true)
	if _throng_under_cursor(true) < 0:
		var egg := _egg_under_cursor()
		if not egg.is_empty():
			at = Vector2(float(egg.x), float(egg.y))
	hand_from = get_viewport().get_mouse_position()
	if sim.grab_at(at.x, at.y):
		selected_bld = -1
		if sim.held_kind == "thronglet":
			selected = sim.held_ref
		else:
			selected = -1
		return
	var hit := sim.eye_use(at.x, at.y)
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
	var sim := ThrongletSimServer
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
		var held := sim.hand_item()
		if not held.is_empty() and Catalog.item_snaps_grid(int(held.kind)):
			at = _grid_pointer()
	var held_thronglet := sim.held_kind == "thronglet"
	var held_id := sim.held_ref
	var hit := sim.release_at(at.x, at.y, short_click)
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
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keys.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keys.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keys.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
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
	return Vector2(tile.x * 0.5 * (1.0 + cell.x - cell.y), tile.y * 0.5 * (1.0 + cell.x + cell.y))


func _from_iso(iso: Vector2) -> Vector2:
	var tile := Vector2(tilemap.tile_set.tile_size)
	var a := iso.x / (tile.x * 0.5) - 1.0
	var b := iso.y / (tile.y * 0.5) - 1.0
	var cell := Vector2((a + b) * 0.5, (b - a) * 0.5)
	return (cell + Vector2(0.5, 0.5)) * float(Catalog.TILE)


func _pointer() -> Vector2:
	return _from_iso(get_global_mouse_position())


func _aim_thronglet(living_only: bool) -> Vector2:
	var id := _throng_under_cursor(living_only)
	if id < 0:
		return _pointer()
	var sim := ThrongletSimServer
	return Vector2(sim.pos_x[id], sim.pos_y[id])


func _throng_under_cursor(living_only: bool) -> int:
	var sim := ThrongletSimServer
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
	var sim := ThrongletSimServer
	if not kit_drag.is_empty():
		if str(kit_drag.get("type", "")) == "build":
			return true
		return not _is_care_tool(int(kit_drag.get("id", -1))) and int(kit_drag.get("id", -1)) == Catalog.TOOL_TNT
	if sim.hand_id != -1:
		var hand := sim.hand_item()
		return not hand.is_empty() and Catalog.item_snaps_grid(int(hand.kind))
	if sim.held_kind == "building" or sim.held_kind == "rock":
		return true
	return tool == Catalog.TOOL_TNT


func _sync_world() -> void:
	var sim := ThrongletSimServer
	if sim.paint_epoch != seen_epoch:
		seen_epoch = sim.paint_epoch
		painted.clear()
		tilemap.clear()
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
	var origin := ThrongletSimServer.chunk_origin(ck)
	if fog:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				map.erase_cell(origin + Vector2i(lx, ly))
		if into == null:
			painted[ck] = "fog"
		return
	var tiles := ThrongletSimServer.chunk_tiles(ck)
	if tiles.is_empty():
		return
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile := int(tiles[ly * Catalog.CHUNK + lx])
			var cell := origin + Vector2i(lx, ly)
			if tile == Catalog.TILE_VOID:
				map.erase_cell(cell)
			else:
				var atlas_x := tile
				if tile == Catalog.TILE_GRASS:
					var pick := absi((lx * 13 + ly * 7) % 3)
					if pick == 1:
						atlas_x = 10
					elif pick == 2:
						atlas_x = 11
					var stage := ThrongletSimServer.wear_stage(cell.x, cell.y)
					if stage > 0:
						atlas_x = _wear_atlas(atlas_x, stage)
				map.set_cell(cell, 0, Vector2i(atlas_x, 0))
	if into == null:
		painted[ck] = "real"


func _sync_actors() -> void:
	var sim := ThrongletSimServer
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
		if view.has_point(p):
			var feat_frame := _prop_frame(Catalog.icon_for_feature(int(feat.kind), int(feat.ore)))
			if int(feat.kind) == Catalog.FEAT_FIRE:
				feat_frame = FIRE_ANIM + int(time_pre * 8.0) % 4
			_push_iso(draws, p, feat_frame, Color.WHITE)
	for it in sim.items:
		if it.dead or it.held:
			continue
		if not sim.chunk_shown(sim.chunk_key_at(float(it.x), float(it.y))):
			continue
		var p2 := Vector2(float(it.x), float(it.y))
		if view.has_point(p2):
			var egg_lift := float(it.get("air", 0.0))
			var item_frame := _prop_frame(Catalog.icon_for_item(int(it.kind)))
			if int(it.kind) == Catalog.ITEM_EGG:
				item_frame = _egg_frame(it)
				if float(it.get("shake", 0.0)) > 0.0:
					p2 += Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
				if egg_lift > 0.0:
					_push_iso(egg_front, p2, item_frame, Color.WHITE, egg_lift)
					continue
			elif int(it.kind) == Catalog.ITEM_BALL:
				var spd := absf(float(it.get("vx", 0.0))) + absf(float(it.get("vy", 0.0)))
				if spd > 2.0:
					egg_lift = absf(sin(time_pre * 14.0 + float(it.id))) * (3.0 if spd > 8.0 else 1.2)
					if spd > 8.0:
						p2 += Vector2(sin(time_pre * 20.0) * 1.0, cos(time_pre * 18.0) * 0.6)
			_push_iso(draws, p2, item_frame, Color.WHITE, egg_lift)
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if not sim.chunk_shown(sim.chunk_key_at(float(b.x), float(b.y))):
			continue
		var p3 := Vector2(float(b.x), float(b.y))
		if view.has_point(p3):
			var b_lift := 0.0
			var b_tint := Color.WHITE
			var b_kind := int(b.kind)
			var b_frame := _prop_frame(Catalog.icon_for_building(b_kind))
			if b_kind == Catalog.BLD_ROUND:
				b_frame = ROUND_ANIM + int(time_pre * 8.0) % 8
			if bool(b.get("active", false)):
				b_lift = absf(sin(time_pre * 8.0 + float(b.id))) * 2.2
				if b_kind == Catalog.BLD_TUB:
					b_tint = Color(0.85, 0.95, 1.0)
				elif b_kind == Catalog.BLD_FACTORY or b_kind == Catalog.BLD_FACTORY2:
					b_tint = Color(1.0, 0.9, 0.82)
				elif b_kind == Catalog.BLD_MINE or b_kind == Catalog.BLD_MINE2:
					b_tint = Color(1.0, 0.95, 0.75)
			_push_iso(draws, p3, b_frame, b_tint, b_lift)
			if b_kind == Catalog.BLD_APPLE:
				var spots := [Vector2(-10, 4), Vector2(10, 6), Vector2(0, 2)]
				var lifts := [34.0, 30.0, 40.0]
				for fruit in b.get("fruits", []):
					var slot := clampi(int(fruit.slot), 0, 2)
					var grown := clampf(float(fruit.s), 0.2, 1.0)
					_push_iso(
						draws,
						Vector2(float(b.x), float(b.y)) + spots[slot],
						_prop_frame(Catalog.ICON_APPLE),
						Color.WHITE,
						lifts[slot],
						0.7 + 0.3 * grown
					)
			if bool(b.get("active", false)) and (b_kind == Catalog.BLD_TUB or b_kind == Catalog.BLD_ROUND):
				var spark := Vector2(cos(time_pre * 10.0 + float(b.id)) * 10.0, sin(time_pre * 10.0) * 6.0)
				var spark_icon := Catalog.ICON_SPONGE if b_kind == Catalog.BLD_TUB else Catalog.ICON_BALL
				_push_iso(draws, Vector2(float(b.x), float(b.y)) + spark, _prop_frame(spark_icon), Color(1, 1, 1, 0.7), 10.0)
	var bridge := sim.bridge_marker()
	if not bridge.is_empty() and sim.chunk_shown(str(bridge.ck)):
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
	var hand := sim.hand_item()
	if not hand.is_empty():
		if _drop_on_island():
			var hand_at := grid_at if Catalog.item_snaps_grid(int(hand.kind)) else free_at
			_push_iso(draws, hand_at, _prop_frame(Catalog.icon_for_item(int(hand.kind))), Color(1, 1, 1, 0.9), 10.0)
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
			_push_iso(draws, Vector2(float(scooped.x), float(scooped.y)), _prop_frame(Catalog.icon_for_item(int(scooped.kind))), Color(1, 1, 1, 0.92), 12.0)
	if sim.held_kind == "rock":
		var rock = sim.feature_by_id.get(sim.held_ref, {})
		if not rock.is_empty():
			if _drop_on_island():
				_push_iso(draws, grid_at, _prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))), Color(1, 1, 1, 0.9), 10.0)
			else:
				draws.append({
					"p": get_global_mouse_position(),
					"icon": _prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))),
					"tint": Color.WHITE,
				})
	elif sim.held_kind == "building":
		var carried = sim.building_by_id.get(sim.held_ref, {})
		if not carried.is_empty():
			if _drop_on_island():
				_push_iso(draws, grid_at, _prop_frame(Catalog.icon_for_building(int(carried.kind))), Color(1, 1, 1, 0.9), 10.0)
			else:
				draws.append({
					"p": get_global_mouse_position(),
					"icon": _prop_frame(Catalog.icon_for_building(int(carried.kind))),
					"tint": Color.WHITE,
				})
	if not kit_drag.is_empty():
		var ghost := Color(1, 1, 1, 0.85)
		var drag_icon := _kit_drag_icon()
		if drag_icon >= 0:
			if _drop_on_island():
				var ghost_at := grid_at if _want_place_grid() else free_at
				_push_iso(draws, ghost_at, _prop_frame(drag_icon), ghost, 10.0)
			else:
				draws.append({
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
		elif sim.clean[i] < 12.0:
			tint = Color(0.62, 0.82, 0.34)
		var lift := 0.0
		var doing := int(sim.act[i])
		var seated := false
		var riding := false
		if not sim.frozen:
			if sim.shake_t[i] > 0.0:
				pos += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
			if doing == ThrongletSimServer.ACT_EAT:
				lift = sin(time * 10.0 + float(i)) * 1.0
			elif doing == ThrongletSimServer.ACT_PLAY:
				var ride := sim.ride_of(i)
				if ride.is_empty():
					lift = absf(sin(time * 14.0 + float(i))) * 5.5
					pos += Vector2(sin(time * 18.0 + float(i)) * 1.4, cos(time * 16.0 + float(i)) * 0.8)
				else:
					riding = true
					var center := Vector2(float(ride.x), float(ride.y))
					var off := pos - center
					if off.length() < 1.0:
						off = Vector2(12.0, 0.0)
					pos = center + off.normalized() * 12.0
					lift = absf(sin(time * 8.0 + float(i))) * 1.5
			elif doing == ThrongletSimServer.ACT_BATH:
				var tub := sim.seat_of(i)
				if tub.is_empty():
					lift = absf(sin(time * 9.0 + float(i))) * 2.2
				else:
					seated = true
					pos = Vector2(float(tub.x), float(tub.y))
					lift = -7.0
			elif doing == ThrongletSimServer.ACT_WORK:
				lift = absf(sin(time * 12.0 + float(i))) * 3.0
			elif sim.act_t[i] > 0.0:
				lift = sin(time * 16.0 + float(i)) * 3.5
		_push_iso(draws, pos, _frame(i, time), tint, lift)
		draws[draws.size() - 1]["flip"] = _throng_flip(i)
		if sim.carry[i] != Catalog.CARRY_NONE:
			_push_iso(draws, pos, _carry_icon(int(sim.carry[i])), Color.WHITE, 12.0)
		if not sim.frozen and doing == ThrongletSimServer.ACT_WASH:
			var bub := Vector2(cos(time * 14.0) * 7.0, sin(time * 14.0) * 4.0)
			_push_iso(draws, pos + bub, _prop_frame(Catalog.ICON_SPONGE), Color(1, 1, 1, 0.85), 8.0)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_BATH and not seated:
			var suds := Vector2(cos(time * 11.0 + float(i)) * 6.0, sin(time * 11.0) * 3.5)
			_push_iso(draws, pos + suds, _prop_frame(Catalog.ICON_SPONGE), Color(0.85, 0.95, 1.0, 0.8), 7.0)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_PLAY and not riding:
			var toy := Vector2(cos(time * 12.0 + float(i)) * 8.0, sin(time * 12.0) * 4.0)
			_push_iso(draws, pos + toy, _prop_frame(Catalog.ICON_BALL), Color(1, 1, 1, 0.9), 9.0 + lift)
		elif not sim.frozen and doing == ThrongletSimServer.ACT_WORK:
			var chip := Vector2(sin(time * 15.0 + float(i)) * 6.0, -4.0)
			_push_iso(draws, pos + chip, _prop_frame(Catalog.ICON_ORE), Color(1, 1, 1, 0.75), 8.0)
	if sim.held_kind == "thronglet" and sim.held_ref >= 0 and sim.held_ref < sim.slot_count:
		var hi := sim.held_ref
		var htint: Color = Catalog.TINTS[int(sim.tint[hi]) % Catalog.TINTS.size()]
		draws.append({
			"p": get_global_mouse_position(),
			"icon": _frame(hi, time),
			"tint": htint,
			"flip": _throng_flip(hi),
		})
	for pop in sim.pops:
		var fade := clampf(float(pop.t) / 0.55, 0.0, 1.0)
		_push_iso(draws, Vector2(float(pop.x), float(pop.y)), _pop_frame(int(pop.icon)), Color(1, 1, 1, fade), float(pop.lift))
	draws.sort_custom(func(a, b): return float(a.p.y) < float(b.p.y))
	draws.append_array(egg_front)
	_write_mesh(world_mesh, draws)


func _frame(i: int, time: float) -> int:
	var sim := ThrongletSimServer
	if sim.state[i] == Catalog.ST_DEAD:
		var clip := "ThrongA_Dead_001" if int(time * 2.0) % 2 == 0 else "ThrongA_Dead_002"
		return ThrongClips.frame_at(clip, 0)
	if sim.frozen:
		return ThrongClips.frame_at("ThrongA_Talk", int(time * 6.0))
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		var along := 1.0
		if sim.mito_t[i] <= 0.0:
			along = clampf(sim.mito_charge[i] / ThrongletSimServer.MITOSIS_CHARGE, 0.0, 0.999)
		return ThrongClips.frame_along("ThrongA_Mitosis_Spritesheet", along)
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if doing == ThrongletSimServer.ACT_EAT:
		return ThrongClips.frame_at("ThrongA_Eat", int(time * 6.0))
	if doing == ThrongletSimServer.ACT_BATH:
		return ThrongClips.frame_at("Throng_FallInBath_Spritesheet", int(time * 8.0))
	if doing == ThrongletSimServer.ACT_WASH:
		return ThrongClips.frame_at("ThrongA_Happy", int(time * 6.0))
	if doing == ThrongletSimServer.ACT_PLAY:
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
		return ThrongClips.frame_at("ThrongA_Happy", int(time * 6.0))
	if int(time + float(i) * 1.7) % 6 == 0:
		return ThrongClips.frame_at("ThrongA_Default Blink", 0)
	return ThrongClips.frame_at("ThrongA_Default", 0)


func _throng_flip(i: int) -> float:
	var sim := ThrongletSimServer
	if sim.state[i] != Catalog.ST_LIVING or sim.frozen:
		return 1.0
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return 1.0
	var doing := int(sim.act[i])
	var moving := absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01
	if doing == ThrongletSimServer.ACT_EAT or doing == ThrongletSimServer.ACT_BATH or doing == ThrongletSimServer.ACT_WASH or doing == ThrongletSimServer.ACT_PLAY:
		return 1.0
	if doing == ThrongletSimServer.ACT_WORK and not moving:
		return 1.0
	if not moving:
		return 1.0
	if absf(sim.dir_x[i]) > absf(sim.dir_y[i]) and sim.dir_x[i] < 0.0:
		return -1.0
	return 1.0


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


func _sync_place_mark() -> void:
	if place_fill == null or place_edge == null:
		return
	if not _want_place_grid():
		place_fill.visible = false
		place_edge.visible = false
		return
	var sim := ThrongletSimServer
	var at := _grid_pointer()
	var building_id := sim.held_ref if sim.held_kind == "building" else -1
	var ignore_item := sim.hand_id
	var ok := false
	if placing >= 0:
		ok = sim.can_place_building(placing, at.x, at.y)
	else:
		ok = sim.spot_ok(at.x, at.y, building_id, ignore_item)
	var poly := _place_cell_poly()
	place_fill.polygon = poly
	place_fill.color = Color(0.3, 1.0, 0.5, 0.55) if ok else Color(1.0, 0.25, 0.22, 0.55)
	place_fill.position = _to_iso(at)
	place_fill.visible = true
	place_edge.points = poly + PackedVector2Array([poly[0]])
	place_edge.default_color = Color(0.75, 1.0, 0.85, 1.0) if ok else Color(1.0, 0.55, 0.5, 1.0)
	place_edge.position = place_fill.position
	place_edge.visible = true


func _sync_charge_mark() -> void:
	if charge_ring == null or charge_area == null:
		return
	var sim := ThrongletSimServer
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
	var target := sim.charge_tool_target(used, at.x, at.y)
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


func _push_iso(draws: Array, world_pos: Vector2, frame: int, tint: Color, lift: float = 0.0, sprite_scale: float = 1.0) -> void:
	var at := _to_iso(world_pos)
	at.y -= lift
	draws.append({"p": at, "icon": frame, "tint": tint, "scale": sprite_scale})


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


func _write_mesh(mesh: MultiMesh, draws: Array) -> void:
	var n := draws.size()
	if mesh.instance_count < n:
		mesh.instance_count = maxi(16, n)
	mesh.visible_instance_count = n
	var xf := Transform2D()
	for i in n:
		var sprite_scale := float(draws[i].get("scale", 1.0))
		var flip := float(draws[i].get("flip", 1.0))
		xf = Transform2D(0.0, Vector2(sprite_scale * flip, sprite_scale), 0.0, draws[i].p + Vector2(0, -32.0 * sprite_scale))
		mesh.set_instance_transform_2d(i, xf)
		mesh.set_instance_custom_data(i, Color(float(draws[i].icon), 0, 0, 0))
		mesh.set_instance_color(i, draws[i].tint)


func _sync_hud(delta: float) -> void:
	var sim := ThrongletSimServer
	pop_label.text = str(sim.living)
	var face_key := "base"
	if sim.living <= 0:
		face_key = "cry" if sim.peak > 0 else "base"
	elif POP_FACES.has(sim.mood_face):
		face_key = sim.mood_face
	if face_key != pop_face_key:
		pop_face_key = face_key
		pop_face.texture = _tex(POP_FACES[face_key])
	gem_panel.visible = sim.part_two
	gem_label.text = str(sim.gems)
	goal_label.text = "TAREA  " + sim.goal_line()
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
	for note in sim.take_notes():
		toast_queue.append(str(note))
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
	_mark_selected()


func _sync_market() -> void:
	var sim := ThrongletSimServer
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


func _sync_gaze() -> void:
	var sim := ThrongletSimServer
	if sim.game_over or sim.modal.is_empty():
		gaze_panel.visible = false
		shown_event = ""
		return
	var event := str(sim.modal.event)
	if event != shown_event:
		shown_event = event
		for child in gaze_box.get_children():
			child.queue_free()
		var gaze: Dictionary = Catalog.GAZE[event]
		gaze_text.text = str(gaze.text)
		var choices: Array = gaze.choices
		for i in choices.size():
			var button := Button.new()
			button.text = str(choices[i])
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color(0.28, 0.14, 0.05))
			button.add_theme_color_override("font_focus_color", Color(0.28, 0.14, 0.05))
			button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.82))
			button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.94, 0.82))
			var hover := _choice_box(Color(1.0, 0.82, 0.45), Color(0.55, 0.36, 0.12))
			var pressed := _choice_box(Color(0.42, 0.24, 0.12), Color(0.22, 0.12, 0.06))
			button.add_theme_stylebox_override("normal", _choice_box(Color(0.62, 0.46, 0.30), Color(0.35, 0.22, 0.12)))
			button.add_theme_stylebox_override("hover", hover)
			button.add_theme_stylebox_override("focus", hover)
			button.add_theme_stylebox_override("pressed", pressed)
			button.add_theme_stylebox_override("hover_pressed", pressed)
			var index := i
			button.pressed.connect(func(): ThrongletSimServer.choose(index))
			gaze_box.add_child(button)
	gaze_panel.visible = true


func _sync_focus(delta: float) -> void:
	var sim := ThrongletSimServer
	if sim.game_over:
		focus_on = false
		focus_hold = 0.0
		focus_dim.visible = false
		focus_frame.visible = false
		focus_box.visible = false
		task_panel.visible = false
		return
	var talk := not sim.modal.is_empty() and Catalog.GAZE.has(str(sim.modal.event))
	var egg := _starter_egg()
	var falling := not egg.is_empty() and float(egg.get("air", 0.0)) > 0.0
	if falling:
		focus_hold = 0.45
	elif focus_hold > 0.0:
		focus_hold = maxf(0.0, focus_hold - delta)
	var show_egg := not talk and not egg.is_empty() and (falling or focus_hold > 0.0)
	var show := talk or show_egg
	if show and not focus_on:
		focus_on = true
	if not show and focus_on:
		focus_on = false
		focus_hold = 0.0
	focus_dim.visible = show
	focus_frame.visible = show
	focus_box.visible = show
	task_panel.visible = not talk
	if show:
		focus_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		focus_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not show:
		return
	var frame := _focus_frame_rect(talk)
	_set_box(focus_frame, frame)
	var inner := frame.grow(-22.0)
	var hole := inner
	if talk:
		var text_h := 124.0
		hole.size.y = maxf(64.0, inner.size.y - text_h)
		var text := Rect2(Vector2(inner.position.x, inner.position.y + hole.size.y), Vector2(inner.size.x, inner.size.y - hole.size.y))
		_set_box(gaze_panel, text)
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
	var sim := ThrongletSimServer
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
	var sim := ThrongletSimServer
	var key := sim.chunk_key_at(anchor.x, anchor.y)
	if sim.chunk_shown(key):
		_paint_chunk(key, false, focus_tilemap)


func _focus_sees(world_pos: Vector2, lift: float) -> bool:
	var at := _to_iso(world_pos)
	at.y -= lift
	var half := Vector2(focus_port.size) / focus_cam_node.zoom * 0.5 + Vector2(40.0, 48.0)
	var delta := at - focus_cam_node.position
	return absf(delta.x) <= half.x and absf(delta.y) <= half.y


func _focus_draws() -> Array:
	var sim := ThrongletSimServer
	var draws: Array = []
	var egg_front: Array = []
	var time := Time.get_ticks_msec() / 1000.0
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		var p := Vector2(float(feat.x), float(feat.y))
		if not _focus_sees(p, 0.0):
			continue
		var feat_frame := _prop_frame(Catalog.icon_for_feature(int(feat.kind), int(feat.ore)))
		if int(feat.kind) == Catalog.FEAT_FIRE:
			feat_frame = FIRE_ANIM + int(time * 8.0) % 4
		_push_iso(draws, p, feat_frame, Color.WHITE)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var lift := float(it.get("air", 0.0))
		var p2 := Vector2(float(it.x), float(it.y))
		if not _focus_sees(p2, lift):
			continue
		var item_frame := _prop_frame(Catalog.icon_for_item(int(it.kind)))
		if int(it.kind) == Catalog.ITEM_EGG:
			item_frame = _egg_frame(it)
			if lift > 0.0:
				_push_iso(egg_front, p2, item_frame, Color.WHITE, lift)
				continue
		_push_iso(draws, p2, item_frame, Color.WHITE, lift)
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		var p3 := Vector2(float(b.x), float(b.y))
		if _focus_sees(p3, 0.0):
			_push_iso(draws, p3, _prop_frame(Catalog.icon_for_building(int(b.kind))), Color.WHITE)
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT:
			continue
		var pos := Vector2(sim.pos_x[i], sim.pos_y[i])
		if not _focus_sees(pos, 0.0):
			continue
		var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
		if sim.state[i] == Catalog.ST_DEAD:
			tint = Color.WHITE
		_push_iso(draws, pos, _frame(i, time), tint, 0.0)
		draws[draws.size() - 1]["flip"] = _throng_flip(i)
	draws.sort_custom(func(a, b): return float(a.p.y) < float(b.p.y))
	draws.append_array(egg_front)
	return draws


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
	var sim := ThrongletSimServer
	for id in tab.tools:
		var entry := _tool_entry(int(id))
		if not entry.is_empty() and bool(sim.unlocks.get(str(entry.unlock), false)):
			return true
	for id in tab.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if not info.is_empty() and bool(sim.unlocks.get(str(info.unlock), false)):
			return true
	return false


func _rebuild_bars() -> void:
	var sim := ThrongletSimServer
	for child in kit_tabs.get_children():
		child.queue_free()
	for child in kit_icons.get_children():
		child.queue_free()
	tool_buttons.clear()
	build_buttons.clear()
	var tabs := _kit_tabs()
	var shown: Array = []
	for tab in tabs:
		if _tab_ready(tab):
			shown.append(tab)
	if shown.is_empty():
		return
	if kit_tab >= shown.size():
		kit_tab = 0
	for i in shown.size():
		var tab: Dictionary = shown[i]
		var tab_button := Button.new()
		tab_button.text = str(tab.label)
		tab_button.modulate = Color(1, 0.95, 0.6) if i == kit_tab else Color(0.75, 0.75, 0.8)
		tab_button.pressed.connect(_set_kit_tab.bind(i))
		kit_tabs.add_child(tab_button)
	var current: Dictionary = shown[kit_tab]
	for id in current.tools:
		var entry := _tool_entry(int(id))
		if entry.is_empty() or not bool(sim.unlocks.get(str(entry.unlock), false)):
			continue
		var tool_id := int(entry.tool)
		var button := _icon_button(str(entry.label), int(entry.icon))
		button.button_down.connect(_begin_kit_drag.bind("tool", tool_id))
		kit_icons.add_child(button)
		tool_buttons[tool_id] = button
	for id in current.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if info.is_empty() or not bool(sim.unlocks.get(str(info.unlock), false)):
			continue
		var build_id := int(id)
		if build_id == Catalog.BLD_MARKET and sim.has_building_kind(Catalog.BLD_MARKET):
			continue
		var button2 := _icon_button(str(info.label), int(info.icon))
		button2.button_down.connect(_begin_kit_drag.bind("build", build_id))
		kit_icons.add_child(button2)
		build_buttons[build_id] = button2
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
	var sim := ThrongletSimServer
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
	for panel in [kit_panel, market_panel, gaze_panel, slots_panel, menu_dim]:
		if panel != null and panel.visible and panel.get_global_rect().has_point(mouse):
			return false
	return true


func _toggle_kit() -> void:
	_play("ui")
	kit_open = not kit_open
	kit_panel.visible = kit_open
	if kit_open:
		_rebuild_bars()


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
		var label := Label.new()
		label.theme = ui_theme
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 8
		label.add_theme_color_override("font_color", Color.WHITE)
		add_child(label)
		bubble_labels.append(label)
		var flame := TextureRect.new()
		flame.texture = _tex("res://resources/src/ref/fire.png")
		flame.custom_minimum_size = Vector2(12, 14)
		flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flame.visible = false
		flame.z_index = 8
		add_child(flame)
		bubble_icons.append(flame)
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
	for _i in 8:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		root.add_child(bar)
		glitch_bars.append(bar)
	glitch_label = Label.new()
	glitch_label.theme = ui_theme
	glitch_label.text = "SISTEMA INESTABLE"
	glitch_label.visible = false
	glitch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitch_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.4))
	glitch_label.position = Vector2(200, 168)
	root.add_child(glitch_label)


func _hide_marks() -> void:
	for label in bubble_labels:
		label.visible = false
	for flame in bubble_icons:
		flame.visible = false
	for label in full_labels:
		label.visible = false
	for line in ring_lines:
		line.visible = false


func _sync_marks() -> void:
	var sim := ThrongletSimServer
	var view := _world_view()
	for i in bubble_labels.size():
		var label: Label = bubble_labels[i]
		if i >= sim.barks.size():
			label.visible = false
			if i < bubble_icons.size():
				bubble_icons[i].visible = false
			continue
		var bark: Dictionary = sim.barks[i]
		var at := Vector2(float(bark.x), float(bark.y))
		var flame: TextureRect = bubble_icons[i]
		if not view.has_point(at):
			label.visible = false
			flame.visible = false
			continue
		var spot := _to_iso(at) + Vector2(-8, -28)
		if int(bark.get("icon", -1)) == Catalog.ICON_FIRE:
			label.visible = false
			flame.visible = true
			flame.position = spot
			continue
		flame.visible = false
		label.visible = true
		label.text = str(bark.text)
		label.position = spot
	var full_n := 0
	for b in sim.buildings:
		if full_n >= full_labels.size():
			break
		if b.dead:
			continue
		var cap_text := sim.occupancy_text(b)
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


func _sync_glitch(delta: float) -> void:
	var sim := ThrongletSimServer
	if sim.glitch_t > 0.0:
		sim.glitch_t = maxf(0.0, sim.glitch_t - delta)
	var on := sim.glitch_t > 0.0
	if glitch_label != null:
		glitch_label.visible = on
	for i in glitch_bars.size():
		var bar: ColorRect = glitch_bars[i]
		bar.visible = on
		if not on:
			continue
		var h := 6 + (i % 3) * 8
		var y := float((int(Time.get_ticks_msec() / 35) + i * 47) % 340)
		bar.position = Vector2(-30.0 if i % 2 == 0 else 50.0, y)
		bar.size = Vector2(700, h)
		bar.color = Color(0.02, 0.08, 0.02, 0.82) if i % 2 == 0 else Color(0.15, 0.95, 0.35, 0.35)


func _sync_need_bars() -> void:
	var sim := ThrongletSimServer
	var show := selected >= 0 and selected < sim.slot_count and sim.state[selected] != Catalog.ST_VACANT
	need_show = show
	if not show:
		for node in need_backs:
			node.visible = false
		for node in need_fills:
			node.visible = false
		return
	var origin := get_global_mouse_position()
	if not (sim.held_kind == "thronglet" and sim.held_ref == selected):
		origin = _to_iso(Vector2(sim.pos_x[selected], sim.pos_y[selected]))
	var at := origin + Vector2(-8, -34)
	var amounts := [sim.fed[selected], sim.amused[selected], sim.clean[selected]]
	for i in 3:
		var y := float(i) * 5.0
		var back: Polygon2D = need_backs[i]
		back.position = at + Vector2(0, y)
		back.visible = true
		var width := clampf(amounts[i] / 100.0, 0.0, 1.0) * 16.0
		var fill: Polygon2D = need_fills[i]
		fill.visible = width >= 1.0
		if width < 1.0:
			continue
		fill.position = at + Vector2(0, y)
		fill.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(width, 0), Vector2(width, 3), Vector2(0, 3),
		])


func _atlas_icon(icon: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _tex("res://resources/structures/structures_tileset.png")
	var col := icon % Catalog.ATLAS_COLUMNS
	var row := int(icon / Catalog.ATLAS_COLUMNS)
	atlas.region = Rect2(col * 16, row * 16, 16, 16)
	return atlas


func _icon_button(text: String, icon: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = text
	button.icon = _atlas_icon(icon)
	button.custom_minimum_size = Vector2(28, 28)
	return button


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
	place_fill = Polygon2D.new()
	place_fill.z_index = 1
	place_fill.visible = false
	add_child(place_fill)
	place_edge = Line2D.new()
	place_edge.z_index = 1
	place_edge.width = 2.0
	place_edge.joint_mode = Line2D.LINE_JOINT_ROUND
	place_edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	place_edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	place_edge.visible = false
	add_child(place_edge)
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
	world = MultiMeshInstance2D.new()
	world.z_index = 2
	world.material = _material(16, ThrongClips.SHEET_ROWS)
	world.texture = _tex("res://resources/sprites/world_iso.png")
	world_mesh = _mesh(true, Vector2(64, 64))
	world.multimesh = world_mesh
	add_child(world)
	var bar_colors := [
		Color(0.86, 0.22, 0.24),
		Color(0.95, 0.72, 0.22),
		Color(0.32, 0.62, 0.9),
	]
	for i in 3:
		var back := Polygon2D.new()
		back.z_index = 6
		back.color = Color(0.16, 0.1, 0.07, 0.92)
		back.polygon = PackedVector2Array([Vector2(0, 0), Vector2(16, 0), Vector2(16, 3), Vector2(0, 3)])
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
	var terrain := _wear_texture(_tex("res://resources/tiles/terrain_tileset.png"))
	atlas.texture = terrain
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in terrain.get_width() / 32:
		var coord := Vector2i(i, 0)
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
	return tileset


func _wear_atlas(grass_x: int, stage: int) -> int:
	var which := 0
	if grass_x == 10:
		which = 1
	elif grass_x == 11:
		which = 2
	return 12 + which * ThrongletSimServer.WEAR_STEPS + stage - 1


func _wear_texture(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	var bases: Array[int] = [0, 10, 11]
	var steps := ThrongletSimServer.WEAR_STEPS
	var wide := Image.create(image.get_width() + bases.size() * steps * 32, image.get_height(), false, image.get_format())
	wide.blit_rect(image, Rect2i(0, 0, image.get_width(), image.get_height()), Vector2i.ZERO)
	var dirt := image.get_region(Rect2i(32, 0, 32, 32))
	var column := image.get_width() / 32
	for which in bases.size():
		var grass := image.get_region(Rect2i(bases[which] * 32, 0, 32, 32))
		for step in steps:
			var mixed := grass.duplicate()
			var amount := float(step + 1) / float(steps + 1)
			for y in 32:
				for x in 32:
					var a := grass.get_pixel(x, y)
					if a.a < 0.05:
						continue
					var b := dirt.get_pixel(x, y)
					if b.a < 0.05:
						continue
					mixed.set_pixel(x, y, a.lerp(b, amount))
			wide.blit_rect(mixed, Rect2i(0, 0, 32, 32), Vector2i((column + which * steps + step) * 32, 0))
	return ImageTexture.create_from_image(wide)


func _material(h_frames: int, v_frames: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://thronglet_shader.gdshader")
	mat.set_shader_parameter("h_frames", h_frames)
	mat.set_shader_parameter("v_frames", v_frames)
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


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var theme := Theme.new()
	var font := FontFile.new()
	if font.load_bitmap_font("res://resources/ui/pixel_font.fnt") == OK:
		theme.default_font = font
	theme.default_font_size = 8
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

	var top_row := HBoxContainer.new()
	top_row.position = Vector2(6, 6)
	top_row.add_theme_constant_override("separation", 6)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := TextureRect.new()
	ring.texture = _tex("res://resources/ui/ui_circle.png")
	ring.custom_minimum_size = Vector2(56, 56)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(ring)
	pop_face = TextureRect.new()
	pop_face.texture = _tex(POP_FACES["base"])
	pop_face_key = "base"
	pop_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pop_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pop_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pop_face.position = Vector2(6, 2)
	pop_face.size = Vector2(44, 38)
	pop_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(pop_face)
	pop_label = Label.new()
	pop_label.position = Vector2(0, 40)
	pop_label.size = Vector2(56, 12)
	pop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var goal_panel := PanelContainer.new()
	task_panel = goal_panel
	goal_panel.add_theme_stylebox_override("panel", _slot_style())
	goal_label = Label.new()
	goal_label.text = "TAREA"
	goal_panel.add_child(goal_label)
	top_row.add_child(goal_panel)
	root.add_child(top_row)

	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 44
	toast.offset_left = -160
	toast.offset_right = 160
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.visible = false
	root.add_child(toast)

	kit_panel = PanelContainer.new()
	kit_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_panel.offset_left = -220
	kit_panel.offset_top = -136
	kit_panel.offset_right = -6
	kit_panel.offset_bottom = -48
	kit_panel.add_theme_stylebox_override("panel", _box_style("res://resources/ui/ui_frame_9patch.png", 8, 4))
	kit_panel.visible = false
	var kit_box := VBoxContainer.new()
	kit_box.add_theme_constant_override("separation", 2)
	kit_tabs = HBoxContainer.new()
	kit_tabs.add_theme_constant_override("separation", 2)
	kit_box.add_child(kit_tabs)
	kit_icons = HFlowContainer.new()
	kit_icons.alignment = FlowContainer.ALIGNMENT_BEGIN
	kit_icons.custom_minimum_size = Vector2(180, 28)
	kit_box.add_child(kit_icons)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(180, 0)
	kit_box.add_child(hint)
	res_label = Label.new()
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kit_box.add_child(res_label)
	kit_panel.add_child(kit_box)
	root.add_child(kit_panel)
	var kit_button := TextureButton.new()
	kit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	kit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kit_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kit_button.offset_left = -42
	kit_button.offset_top = -42
	kit_button.offset_right = -6
	kit_button.offset_bottom = -6
	kit_button.ignore_texture_size = true
	kit_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	kit_button.texture_normal = _tex("res://resources/ui/ui_kit.png")
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
	var focus_world := MultiMeshInstance2D.new()
	focus_world.z_index = 2
	focus_world.material = _material(16, ThrongClips.SHEET_ROWS)
	focus_world.texture = world.texture
	focus_mesh = _mesh(true, Vector2(64, 64))
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

	gaze_panel = PanelContainer.new()
	gaze_panel.visible = false
	gaze_panel.z_index = 33
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.73, 0.59, 0.45)
	gaze_panel.add_theme_stylebox_override("panel", paper)
	var gaze_margin := MarginContainer.new()
	gaze_margin.add_theme_constant_override("margin_left", 16)
	gaze_margin.add_theme_constant_override("margin_right", 16)
	gaze_margin.add_theme_constant_override("margin_top", 16)
	gaze_margin.add_theme_constant_override("margin_bottom", 16)
	var gaze_col := VBoxContainer.new()
	gaze_text = Label.new()
	gaze_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gaze_text.add_theme_color_override("font_color", Color.WHITE)
	gaze_col.add_child(gaze_text)
	gaze_box = VBoxContainer.new()
	gaze_col.add_child(gaze_box)
	gaze_margin.add_child(gaze_col)
	gaze_panel.add_child(gaze_margin)
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
	var menu_button := Button.new()
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu_button.offset_left = -30
	menu_button.offset_top = 4
	menu_button.offset_right = -4
	menu_button.offset_bottom = 28
	menu_button.z_index = 42
	menu_button.pressed.connect(_toggle_slots)
	for i in 3:
		var bar := ColorRect.new()
		bar.color = Color(0.28, 0.16, 0.08)
		bar.position = Vector2(5, 6 + i * 5)
		bar.size = Vector2(16, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_button.add_child(bar)
	root.add_child(menu_button)
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
	title_root.z_index = 43
	var title_bg := ColorRect.new()
	title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bg.color = Color(0.02, 0.025, 0.05, 1)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(title_bg)
	var title_center := CenterContainer.new()
	title_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_col := VBoxContainer.new()
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 8)
	var logo := TextureRect.new()
	logo.texture = _tex("res://resources/ui/logo.png")
	logo.custom_minimum_size = Vector2(220, 64)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_col.add_child(logo)
	var title_panel := PanelContainer.new()
	title_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_list = VBoxContainer.new()
	title_list.add_theme_constant_override("separation", 3)
	title_panel.add_child(title_list)
	title_col.add_child(title_panel)
	title_center.add_child(title_col)
	title_root.add_child(title_center)
	root.add_child(title_root)

	_rebuild_bars()


func _show_title() -> void:
	var sim := ThrongletSimServer
	sim.cancel_hold()
	in_title = true
	sim.paused = true
	market_open = false
	_cancel_kit_drag()
	kit_open = false
	if kit_panel:
		kit_panel.visible = false
	if slots_panel:
		slots_panel.visible = false
	if menu_dim:
		menu_dim.visible = false
	title_root.visible = true
	_fill_title()


func _enter_game() -> void:
	in_title = false
	title_root.visible = false
	ThrongletSimServer.paused = false


func _fill_title() -> void:
	_clear_menu(title_list)
	if _has_continue():
		_menu_button(title_list, "CONTINUAR", _continue_game)
	_menu_button(title_list, "NUEVA PARTIDA", func():
		ThrongletSimServer.new_game()
		_enter_game()
	)
	_menu_button(title_list, "CARGAR", _fill_title_slots)
	_menu_button(title_list, "BORRAR", _fill_title_delete)
	_menu_button(title_list, "SALIR", _quit_game)


func _has_continue() -> bool:
	var sim := ThrongletSimServer
	if sim.session_live:
		return true
	for row in sim.list_slots():
		if bool(row.used):
			return true
	return false


func _continue_game() -> void:
	if not ThrongletSimServer.resume_last():
		return
	_enter_game()


func _fill_title_slots() -> void:
	_clear_menu(title_list)
	_menu_label(title_list, "CARGAR")
	for row in ThrongletSimServer.list_slots():
		var index := int(row.i)
		var used := bool(row.used)
		var text := _slot_text(index, row)
		_menu_button(title_list, text, _title_load.bind(index), not used)
	_menu_button(title_list, "VOLVER", _fill_title)


func _fill_title_delete() -> void:
	_clear_menu(title_list)
	_menu_label(title_list, "BORRAR")
	var any := false
	for row in ThrongletSimServer.list_slots():
		if not bool(row.used):
			continue
		any = true
		var index := int(row.i)
		_menu_button(title_list, _slot_text(index, row), _ask_title_delete.bind(index))
	if not any:
		_menu_label(title_list, "NO HAY PARTIDAS")
	_menu_button(title_list, "VOLVER", _fill_title)


func _ask_title_delete(index: int) -> void:
	_clear_menu(title_list)
	_menu_label(title_list, "BORRAR RANURA %d" % [index + 1])
	_menu_button(title_list, "BORRAR", _confirm_title_delete.bind(index))
	_menu_button(title_list, "VOLVER", _fill_title_delete)


func _confirm_title_delete(index: int) -> void:
	ThrongletSimServer.delete_slot(index)
	_fill_title_delete()


func _title_load(index: int) -> void:
	if not ThrongletSimServer.load_slot(index):
		return
	_enter_game()


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
	kit_panel.visible = false
	_show_menu()


func _close_slots() -> void:
	slots_panel.visible = false
	menu_dim.visible = false
	ThrongletSimServer.paused = false


func _show_menu() -> void:
	pause_page = "root"
	_clear_menu(slots_list)
	_menu_label(slots_list, "PAUSA")
	_menu_button(slots_list, "CONTINUAR", _close_slots)
	_menu_button(slots_list, "GUARDAR", func(): _fill_slots(true))
	_menu_button(slots_list, "CARGAR", func(): _fill_slots(false))
	_menu_button(slots_list, "SALIR DE LA PARTIDA", _show_title)
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
	button.add_theme_color_override("font_hover_color", Color(0.28, 0.14, 0.05))
	button.add_theme_color_override("font_focus_color", Color(0.28, 0.14, 0.05))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.82))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.94, 0.82))
	button.pressed.connect(func() -> void:
		_play("ui")
		call.call()
	)
	list.add_child(button)


func _slot_text(index: int, row: Dictionary) -> String:
	if bool(row.used):
		return "RANURA %d  POB %d" % [index + 1, int(row.living)]
	return "RANURA %d  VACIA" % [index + 1]


func _sync_game_over() -> void:
	if over_panel == null:
		return
	var show := ThrongletSimServer.game_over and not in_title
	if over_panel.visible == show:
		return
	over_panel.visible = show
	if not show:
		return
	gaze_panel.visible = false
	kit_open = false
	kit_panel.visible = false
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
	_menu_button(over_list, "CARGAR", _game_over_load, not ThrongletSimServer.has_checkpoint())


func _game_over_restart() -> void:
	ThrongletSimServer.new_game()
	over_panel.visible = false
	_enter_game()


func _game_over_load() -> void:
	if not ThrongletSimServer.load_checkpoint():
		return
	over_panel.visible = false
	_enter_game()


func _quit_game() -> void:
	var sim := ThrongletSimServer
	if sim.current_slot >= 0:
		sim.save_slot(sim.current_slot)
	get_tree().quit()


func _save_current() -> void:
	var index := ThrongletSimServer.current_slot
	if index < 0:
		index = 0
	ThrongletSimServer.save_slot(index)
	if slots_panel.visible:
		_fill_slots(true)


func _fill_slots(saving: bool) -> void:
	pause_page = "save" if saving else "load"
	_clear_menu(slots_list)
	_menu_label(slots_list, "GUARDAR" if saving else "CARGAR")
	for row in ThrongletSimServer.list_slots():
		var index := int(row.i)
		var used := bool(row.used)
		if saving:
			_menu_button(slots_list, _slot_text(index, row), _save_row.bind(index))
		else:
			_menu_button(slots_list, _slot_text(index, row), _load_row.bind(index), not used)
	_menu_button(slots_list, "VOLVER", _show_menu)


func _save_row(index: int) -> void:
	ThrongletSimServer.save_slot(index)
	_fill_slots(true)


func _load_row(index: int) -> void:
	ThrongletSimServer.load_slot(index)
	_close_slots()


func _tex(path: String) -> Texture2D:
	if textures.has(path):
		return textures[path]
	var tex: Texture2D = load(path)
	textures[path] = tex
	return tex


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


func _box_style(path: String, edge: int, pad: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _tex(path)
	style.texture_margin_left = edge
	style.texture_margin_right = edge
	style.texture_margin_top = edge
	style.texture_margin_bottom = edge
	style.set_content_margin_all(pad)
	return style


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
	_fill_bank()


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
	sfx_bank["voice_upset"] = _clips(PackedStringArray([
		"vo_thronglet_upset_04.wav", "vo_thronglet_upset_06.wav", "vo_thronglet_upset_09.wav",
		"vo_thronglet_upset_11.wav", "vo_thronglet_upset_12.wav",
	]))


func _seq(prefix: String, first: int, last: int) -> PackedStringArray:
	var names := PackedStringArray()
	for i in range(first, last + 1):
		names.append("%s%02d.wav" % [prefix, i])
	return names


func _clips(names: PackedStringArray) -> Array:
	var out: Array = []
	for clip_name in names:
		var stream: AudioStream = load("res://resources/audio/" + clip_name)
		if stream != null:
			out.append(stream)
	return out


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
	var mode := "title"
	if not in_title:
		mode = "waste" if ThrongletSimServer.part_two else "field"
	if mode == music_mode:
		return
	music_mode = mode
	if mode == "title":
		_loop_bed(music, "thronglets_title_theme_180bpm_24bar.ogg")
		amb.stop()
	elif mode == "waste":
		_loop_bed(music, "wasteland_one_160bpm_134bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_barrenWind.ogg")
	else:
		_loop_bed(music, "fieldwork_140bpm_108bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_softWindBirds_lp.ogg")


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
