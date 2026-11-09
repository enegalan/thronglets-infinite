extends Node2D

var camera: Camera2D
var tilemap: TileMapLayer
var world: MultiMeshInstance2D
var world_mesh: MultiMesh

var tool := Catalog.TOOL_EYE
var placing := -1
var selected := -1
var zoom_i := 2
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
var gem_panel: PanelContainer
var gem_label: Label
var goal_label: Label
var hint: Label
var toast: Label
var inspect_box: Label
var inspect_panel: PanelContainer
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
var slots_panel: PanelContainer
var slots_list: VBoxContainer
var menu_dim: ColorRect
var tool_buttons := {}
var build_buttons := {}
var sfx := {}
var textures := {}


func _ready() -> void:
	_build_sky()
	_build_world()
	_build_audio()
	_build_ui()
	camera.position = _to_iso(Vector2(256, 256))
	camera.zoom = Vector2(zoom_i, zoom_i)
	if ThrongletSimServer.testing:
		in_title = false
	else:
		_show_title()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if placing >= 0:
			_drop_build()
		elif ThrongletSimServer.is_holding():
			_hand_release()


func _unhandled_input(event: InputEvent) -> void:
	if in_title:
		return
	var sim := ThrongletSimServer
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		dragging = event.pressed
		drag_from = event.position
		cam_from = camera.position
		if event.pressed:
			placing = -1
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_i = mini(4, zoom_i + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_i = maxi(1, zoom_i - 1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_save_current()
		elif event.keycode == KEY_F9:
			_toggle_slots()
		elif event.keycode == KEY_F8:
			sim.debug_spawn(10000, _from_iso(camera.position))
		elif event.keycode == KEY_ESCAPE:
			if slots_panel.visible:
				_close_slots()
			else:
				market_open = false
				placing = -1
				tool = Catalog.TOOL_EYE
		else:
			_hotkey(event.keycode)
		return
	if sim.frozen or sim.paused or in_title:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placing < 0 and tool == Catalog.TOOL_EYE:
			_hand_press()
			return
		if placing < 0:
			_world_click()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_hand_release()


func _process(delta: float) -> void:
	if in_title:
		return
	var sim := ThrongletSimServer
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
	_sync_world()
	_sync_actors()
	_sync_hud(delta)
	_sync_market()
	_sync_gaze()
	for name in sim.take_sfx():
		_play(str(name))


func _world_click() -> void:
	var sim := ThrongletSimServer
	var at := _pointer()
	sim.use_tool(tool, at.x, at.y)


func _hand_press() -> void:
	var sim := ThrongletSimServer
	var at := _pointer()
	hand_from = get_viewport().get_mouse_position()
	if sim.grab_at(at.x, at.y):
		if sim.held_kind == "thronglet":
			selected = sim.held_ref
		return
	var hit := sim.eye_use(at.x, at.y)
	var kind := str(hit.get("type", ""))
	if kind == "thronglet":
		selected = int(hit.id)
	elif kind == "market":
		market_open = true
		selected = -1
	else:
		selected = -1


func _hand_release() -> void:
	var sim := ThrongletSimServer
	if not sim.is_holding():
		return
	var short_click := get_viewport().get_mouse_position().distance_to(hand_from) < 12.0
	if not _drop_on_island():
		sim.cancel_hold()
		return
	var at := _pointer()
	var hit := sim.release_at(at.x, at.y, short_click)
	var kind := str(hit.get("type", ""))
	if kind == "thronglet":
		selected = int(hit.id)
	elif kind == "market":
		market_open = true
		selected = -1


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
	camera.position += keys * 220.0 * delta / float(zoom_i)
	if dragging:
		var drag := get_viewport().get_mouse_position() - drag_from
		camera.position = cam_from - drag / float(zoom_i)
	camera.zoom = Vector2(float(zoom_i), float(zoom_i))
	var step := 1.0 / float(zoom_i)
	camera.position = camera.position.snapped(Vector2(step, step))


func _iso_view() -> Rect2:
	var size := get_viewport_rect().size / float(zoom_i)
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


func _sync_world() -> void:
	var sim := ThrongletSimServer
	if sim.paint_epoch != seen_epoch:
		seen_epoch = sim.paint_epoch
		painted.clear()
		tilemap.clear()
	for ck in sim.take_dirty():
		_paint_chunk(str(ck), false)
	var rect := _world_view().grow(128.0)
	var size := float(Catalog.TILE * Catalog.CHUNK)
	var x0 := int(floor(rect.position.x / size))
	var y0 := int(floor(rect.position.y / size))
	var x1 := int(floor(rect.end.x / size))
	var y1 := int(floor(rect.end.y / size))
	for cy in range(y0 - 1, y1 + 2):
		for cx in range(x0 - 1, x1 + 2):
			var ck := "%d,%d" % [cx, cy]
			if sim.revealed.has(ck):
				if str(painted.get(ck, "")) != "real":
					_paint_chunk(ck, false)
			elif str(painted.get(ck, "")) != "fog":
				_paint_chunk(ck, true)


func _paint_chunk(ck: String, fog: bool) -> void:
	var origin := ThrongletSimServer.chunk_origin(ck)
	if fog:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				tilemap.erase_cell(origin + Vector2i(lx, ly))
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
				tilemap.erase_cell(cell)
			else:
				tilemap.set_cell(cell, 0, Vector2i(tile, 0))
	painted[ck] = "real"


func _sync_actors() -> void:
	var sim := ThrongletSimServer
	var view := _world_view().grow(64.0)
	var draws: Array = []
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		var p := Vector2(float(feat.x), float(feat.y))
		if view.has_point(p):
			_push_iso(draws, p, _prop_frame(Catalog.icon_for_feature(int(feat.kind), int(feat.ore))), Color.WHITE)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var p2 := Vector2(float(it.x), float(it.y))
		if view.has_point(p2):
			_push_iso(draws, p2, _prop_frame(Catalog.icon_for_item(int(it.kind))), Color.WHITE)
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		var p3 := Vector2(float(b.x), float(b.y))
		if view.has_point(p3):
			_push_iso(draws, p3, _prop_frame(Catalog.icon_for_building(int(b.kind))), Color.WHITE)
	var hand := sim.hand_item()
	if not hand.is_empty():
		draws.append({
			"p": get_global_mouse_position(),
			"icon": _prop_frame(Catalog.icon_for_item(int(hand.kind))),
			"tint": Color.WHITE,
		})
	if sim.held_kind == "rock":
		var rock = sim.feature_by_id.get(sim.held_ref, {})
		if not rock.is_empty():
			draws.append({
				"p": get_global_mouse_position(),
				"icon": _prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))),
				"tint": Color.WHITE,
			})
	elif sim.held_kind == "building":
		var carried = sim.building_by_id.get(sim.held_ref, {})
		if not carried.is_empty():
			draws.append({
				"p": get_global_mouse_position(),
				"icon": _prop_frame(Catalog.icon_for_building(int(carried.kind))),
				"tint": Color.WHITE,
			})
	if placing >= 0 and Catalog.BUILD_INFO.has(placing):
		var built: Dictionary = Catalog.BUILD_INFO[placing]
		var ghost := Color(1, 1, 1, 0.8)
		if _drop_on_island():
			_push_iso(draws, _pointer(), _prop_frame(int(built.icon)), ghost)
		else:
			draws.append({
				"p": get_global_mouse_position(),
				"icon": _prop_frame(int(built.icon)),
				"tint": ghost,
			})
	var time := Time.get_ticks_msec() / 1000.0
	for id in sim.query_rect(view):
		var i := int(id)
		if sim.held_kind == "thronglet" and i == sim.held_ref:
			continue
		var pos := Vector2(sim.pos_x[i], sim.pos_y[i])
		if sim.shake_t[i] > 0.0:
			pos += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
		if sim.state[i] == Catalog.ST_DEAD:
			tint = Color.WHITE
		elif sim.clean[i] < 12.0:
			tint = Color(0.62, 0.82, 0.34)
		var lift := 0.0
		if sim.act_t[i] > 0.0:
			lift = sin(time * 16.0 + float(i)) * 3.5
		_push_iso(draws, pos, _frame(i, time), tint, lift)
		if sim.carry[i] != Catalog.CARRY_NONE:
			_push_iso(draws, pos, _carry_icon(int(sim.carry[i])), Color.WHITE, 12.0)
		if int(sim.act[i]) == ThrongletSimServer.ACT_WASH:
			var bub := Vector2(cos(time * 14.0) * 7.0, sin(time * 14.0) * 4.0)
			_push_iso(draws, pos + bub, Catalog.ICON_SPONGE, Color(1, 1, 1, 0.85), 8.0)
	if sim.held_kind == "thronglet" and sim.held_ref >= 0 and sim.held_ref < sim.slot_count:
		var hi := sim.held_ref
		var htint: Color = Catalog.TINTS[int(sim.tint[hi]) % Catalog.TINTS.size()]
		draws.append({
			"p": get_global_mouse_position(),
			"icon": _frame(hi, time),
			"tint": htint,
		})
	for pop in sim.pops:
		var fade := clampf(float(pop.t) / 0.55, 0.0, 1.0)
		_push_iso(draws, Vector2(float(pop.x), float(pop.y)), int(pop.icon), Color(1, 1, 1, fade), float(pop.lift))
	draws.sort_custom(func(a, b): return float(a.p.y) < float(b.p.y))
	_write_mesh(world_mesh, draws)


func _frame(i: int, time: float) -> int:
	var sim := ThrongletSimServer
	if sim.state[i] == Catalog.ST_DEAD:
		return Catalog.FRAME_CORPSE
	if sim.frozen or (sim.sponge_id == i and sim.sponge_hold > 0.0):
		return Catalog.FRAME_STARE
	if sim.mito_t[i] > 0.0:
		return 16 + int(time * 10.0) % 4
	var doing := int(sim.act[i])
	if doing == ThrongletSimServer.ACT_EAT or doing == ThrongletSimServer.ACT_BATH or doing == ThrongletSimServer.ACT_WASH:
		return Catalog.FRAME_STARE
	if doing == ThrongletSimServer.ACT_PLAY or doing == ThrongletSimServer.ACT_WORK:
		return int(time * 12.0 + float(i)) % 4
	if sim.clean[i] < 12.0:
		return Catalog.FRAME_SICK
	var row := 0
	if absf(sim.dir_x[i]) > absf(sim.dir_y[i]):
		row = 2 if sim.dir_x[i] >= 0.0 else 3
	else:
		row = 0 if sim.dir_y[i] >= 0.0 else 1
	return row * 4 + int(time * 8.0 + float(i)) % 4


func _prop_frame(icon: int) -> int:
	if _BIG.has(icon):
		return 64 + int(_BIG[icon])
	return 24 + icon


func _carry_icon(kind: int) -> int:
	if kind == Catalog.CARRY_BONE:
		return Catalog.ICON_BONE
	if kind == Catalog.CARRY_ORE:
		return Catalog.ICON_ORE
	return Catalog.ICON_WOOD


func _push_iso(draws: Array, world_pos: Vector2, frame: int, tint: Color, lift: float = 0.0) -> void:
	var at := _to_iso(world_pos)
	at.y -= lift
	draws.append({"p": at, "icon": frame, "tint": tint})


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
}


func _write_mesh(mesh: MultiMesh, draws: Array) -> void:
	var n := draws.size()
	if mesh.instance_count < n:
		mesh.instance_count = maxi(16, n)
	mesh.visible_instance_count = n
	var xf := Transform2D()
	for i in n:
		xf.origin = draws[i].p + Vector2(0, -16)
		mesh.set_instance_transform_2d(i, xf)
		mesh.set_instance_custom_data(i, Color(float(draws[i].icon), 0, 0, 0))
		mesh.set_instance_color(i, draws[i].tint)


func _sync_hud(delta: float) -> void:
	var sim := ThrongletSimServer
	pop_label.text = str(sim.living)
	gem_panel.visible = sim.part_two
	gem_label.text = str(sim.gems)
	goal_label.text = "TAREA  " + sim.goal_line()
	res_label.text = "MADERA %d   HUESO %d   MINERAL %d   MUERTOS %d" % [
		sim.count_item(Catalog.ITEM_WOOD),
		sim.count_item(Catalog.ITEM_BONE),
		sim.count_item(Catalog.ITEM_ORE),
		sim.count_dead(),
	]
	var info := ""
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == tool:
			info = str(entry.hint)
			break
	if placing >= 0 and Catalog.BUILD_INFO.has(placing):
		info = "SUELTA " + str(Catalog.BUILD_INFO[placing].label)
	hint.text = info
	if selected >= 0:
		var data := sim.inspect(selected)
		if data.is_empty():
			selected = -1
			inspect_box.text = ""
		else:
			inspect_box.text = "THRONGLET #%d  %s\nCOMIDA %d%%\nDIVERSION %d%%\nLIMPIEZA %d%%\nFELICIDAD %d%%" % [
				int(data.id),
				str(data.status),
				int(data.fed),
				int(data.amused),
				int(data.clean),
				int(data.happy),
			]
	else:
		inspect_box.text = ""
	inspect_panel.visible = selected >= 0
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
	market_panel.visible = market_open and bool(sim.unlocks.get("market", false))
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
	if sim.modal.is_empty():
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
			var index := i
			button.pressed.connect(func(): ThrongletSimServer.choose(index))
			gaze_box.add_child(button)
	gaze_panel.visible = true


func _kit_tabs() -> Array:
	return [
		{"label": "CUIDA", "title": "CUIDADOS", "tools": [Catalog.TOOL_EYE, Catalog.TOOL_APPLE, Catalog.TOOL_BALL, Catalog.TOOL_SPONGE], "builds": []},
		{"label": "UTIL", "title": "HERRAMIENTAS", "tools": [Catalog.TOOL_AXE, Catalog.TOOL_HAMMER, Catalog.TOOL_PICK, Catalog.TOOL_SAW, Catalog.TOOL_GRAB, Catalog.TOOL_MOP], "builds": []},
		{"label": "OBRA", "title": "CONSTRUCCION", "tools": [], "builds": [Catalog.BLD_DWELL, Catalog.BLD_FANCY, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2, Catalog.BLD_THEATRE, Catalog.BLD_CANNON, Catalog.BLD_MARKET, Catalog.BLD_FLOWER, Catalog.BLD_STATUE]},
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
		button.pressed.connect(_pick_tool.bind(tool_id))
		kit_icons.add_child(button)
		tool_buttons[tool_id] = button
	for id in current.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if info.is_empty() or not bool(sim.unlocks.get(str(info.unlock), false)):
			continue
		var build_id := int(id)
		var button2 := _icon_button(str(info.label), int(info.icon))
		button2.button_down.connect(_begin_build_drag.bind(build_id))
		button2.button_up.connect(_drop_build)
		kit_icons.add_child(button2)
		build_buttons[build_id] = button2
	if str(current.label) == "OBRA" and bool(sim.unlocks.get("market", false)):
		var market := Button.new()
		market.text = "MERCADO"
		market.pressed.connect(func(): market_open = not market_open)
		kit_icons.add_child(market)


func _set_kit_tab(index: int) -> void:
	kit_tab = index
	_rebuild_bars()


func _pick_tool(id: int) -> void:
	tool = id
	placing = -1


func _begin_build_drag(id: int) -> void:
	placing = id
	tool = Catalog.TOOL_EYE


func _drop_build() -> void:
	var kind := placing
	placing = -1
	if kind < 0 or ThrongletSimServer.frozen or ThrongletSimServer.paused:
		return
	if not _drop_on_island():
		return
	var at := _pointer()
	ThrongletSimServer.place_building(kind, at.x, at.y)


func _drop_on_island() -> bool:
	var mouse := get_viewport().get_mouse_position()
	for panel in [kit_panel, market_panel, gaze_panel, slots_panel, menu_dim, inspect_panel]:
		if panel.visible and panel.get_global_rect().has_point(mouse):
			return false
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or hovered.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return true
	return not hovered.get_global_rect().has_point(mouse)


func _toggle_kit() -> void:
	kit_open = not kit_open
	kit_panel.visible = kit_open
	if kit_open:
		_rebuild_bars()


func _mark_selected() -> void:
	for id in tool_buttons.keys():
		var button: Button = tool_buttons[id]
		button.modulate = Color(1, 1, 1) if int(id) == tool and placing < 0 else Color(0.65, 0.65, 0.7)
	for id in build_buttons.keys():
		var button2: Button = build_buttons[id]
		button2.modulate = Color(1, 0.95, 0.6) if int(id) == placing else Color(0.75, 0.75, 0.8)


func _hotkey(code: int) -> void:
	var order := [
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	]
	var tools: Array = []
	for entry in Catalog.TOOL_INFO:
		if bool(ThrongletSimServer.unlocks.get(str(entry.unlock), false)):
			tools.append(int(entry.tool))
	for i in order.size():
		if code == order[i] and i < tools.size():
			tool = int(tools[i])
			placing = -1


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
	world = MultiMeshInstance2D.new()
	world.z_index = 1
	world.material = _material(16, 6)
	world.texture = _tex("res://resources/sprites/world_iso.png")
	world_mesh = _mesh(true, 32)
	world.multimesh = world_mesh
	add_child(world)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()


func _make_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(32, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = _tex("res://resources/tiles/terrain_tileset.png")
	atlas.texture_region_size = Vector2i(32, 32)
	tileset.add_source(atlas, 0)
	for i in Catalog.TILE_COUNT:
		var coord := Vector2i(i, 0)
		if not atlas.has_tile(coord):
			atlas.create_tile(coord)
	return tileset


func _material(h_frames: int, v_frames: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://thronglet_shader.gdshader")
	mat.set_shader_parameter("h_frames", h_frames)
	mat.set_shader_parameter("v_frames", v_frames)
	return mat


func _mesh(colored: bool, size: int) -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
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

	var top_row := HBoxContainer.new()
	top_row.position = Vector2(6, 6)
	top_row.add_theme_constant_override("separation", 6)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(40, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := TextureRect.new()
	ring.texture = _tex("res://resources/ui/ui_circle.png")
	ring.custom_minimum_size = Vector2(40, 40)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(ring)
	var face := TextureRect.new()
	var face_tex := AtlasTexture.new()
	face_tex.atlas = _tex("res://resources/sprites/thronglet_spritesheet.png")
	face_tex.region = Rect2(0, 0, 16, 16)
	face.texture = face_tex
	face.modulate = Color(1.0, 0.86, 0.28)
	face.position = Vector2(12, 4)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(face)
	pop_label = Label.new()
	pop_label.position = Vector2(0, 22)
	pop_label.size = Vector2(40, 12)
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
	goal_panel.add_theme_stylebox_override("panel", _slot_style())
	goal_label = Label.new()
	goal_label.text = "TAREA"
	goal_panel.add_child(goal_label)
	top_row.add_child(goal_panel)
	root.add_child(top_row)

	inspect_panel = PanelContainer.new()
	inspect_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inspect_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inspect_panel.offset_left = -150
	inspect_panel.offset_top = 32
	inspect_panel.offset_right = -4
	inspect_panel.visible = false
	inspect_box = Label.new()
	inspect_panel.add_child(inspect_box)
	root.add_child(inspect_panel)

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

	gaze_panel = PanelContainer.new()
	gaze_panel.set_anchors_preset(Control.PRESET_CENTER)
	gaze_panel.offset_left = -150
	gaze_panel.offset_top = -70
	gaze_panel.offset_right = 150
	gaze_panel.offset_bottom = 70
	gaze_panel.visible = false
	var gaze_margin := MarginContainer.new()
	gaze_margin.add_theme_constant_override("margin_left", 6)
	gaze_margin.add_theme_constant_override("margin_right", 6)
	gaze_margin.add_theme_constant_override("margin_top", 6)
	gaze_margin.add_theme_constant_override("margin_bottom", 6)
	var gaze_col := VBoxContainer.new()
	gaze_text = Label.new()
	gaze_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gaze_text.custom_minimum_size = Vector2(280, 0)
	gaze_col.add_child(gaze_text)
	gaze_box = VBoxContainer.new()
	gaze_col.add_child(gaze_box)
	gaze_margin.add_child(gaze_col)
	gaze_panel.add_child(gaze_margin)
	root.add_child(gaze_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
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
	menu_button.pressed.connect(_toggle_slots)
	for i in 3:
		var bar := ColorRect.new()
		bar.color = Color(0.28, 0.16, 0.08)
		bar.position = Vector2(5, 6 + i * 5)
		bar.size = Vector2(16, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		menu_button.add_child(bar)
	root.add_child(menu_button)
	slots_panel = PanelContainer.new()
	slots_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	slots_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	slots_panel.grow_vertical = Control.GROW_DIRECTION_END
	slots_panel.offset_left = -230
	slots_panel.offset_top = 32
	slots_panel.offset_right = -4
	slots_panel.offset_bottom = 230
	slots_panel.visible = false
	slots_list = VBoxContainer.new()
	slots_panel.add_child(slots_list)
	root.add_child(slots_panel)

	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_STOP
	title_root.visible = false
	var title_bg := ColorRect.new()
	title_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_bg.color = Color(0.02, 0.025, 0.05, 1)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(title_bg)
	var title_panel := PanelContainer.new()
	title_panel.set_anchors_preset(Control.PRESET_CENTER)
	title_panel.offset_left = -120
	title_panel.offset_top = -80
	title_panel.offset_right = 120
	title_panel.offset_bottom = 90
	title_list = VBoxContainer.new()
	title_panel.add_child(title_list)
	title_root.add_child(title_panel)
	root.add_child(title_root)

	_rebuild_bars()


func _show_title() -> void:
	var sim := ThrongletSimServer
	sim.cancel_hold()
	in_title = true
	sim.paused = true
	market_open = false
	placing = -1
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
	for child in title_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "THRONGLETS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_list.add_child(title)
	if _has_continue():
		_title_button("CONTINUAR", _continue_game)
	_title_button("NUEVA PARTIDA", func():
		ThrongletSimServer.new_game()
		_enter_game()
	)
	_title_button("CARGAR", _fill_title_slots)
	_title_button("SALIR", _quit_game)


func _title_button(text: String, call: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(call)
	title_list.add_child(button)


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
	for child in title_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "CARGAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_list.add_child(title)
	for row in ThrongletSimServer.list_slots():
		var index := int(row.i)
		var line := HBoxContainer.new()
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(row.used):
			button.text = "RANURA %d  POB %d" % [index + 1, int(row.living)]
			button.pressed.connect(_title_load.bind(index))
			var erase := Button.new()
			erase.text = "BORRAR"
			erase.pressed.connect(_title_delete.bind(index))
			line.add_child(button)
			line.add_child(erase)
		else:
			button.text = "RANURA %d  VACIA" % [index + 1]
			button.disabled = true
			line.add_child(button)
		title_list.add_child(line)
	_title_button("VOLVER", _fill_title)


func _title_load(index: int) -> void:
	if not ThrongletSimServer.load_slot(index):
		return
	_enter_game()


func _title_delete(index: int) -> void:
	ThrongletSimServer.delete_slot(index)
	_fill_title_slots()


func _toggle_slots() -> void:
	if slots_panel.visible:
		_close_slots()
	else:
		_open_menu()


func _open_menu() -> void:
	slots_panel.visible = true
	menu_dim.visible = true
	ThrongletSimServer.paused = true
	market_open = false
	placing = -1
	kit_open = false
	kit_panel.visible = false
	_show_menu()


func _close_slots() -> void:
	slots_panel.visible = false
	menu_dim.visible = false
	ThrongletSimServer.paused = false


func _show_menu() -> void:
	for child in slots_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "MENU"
	slots_list.add_child(title)
	_menu_button("CONTINUAR", _close_slots)
	_menu_button("GUARDAR", func(): _fill_slots(true))
	_menu_button("CARGAR", func(): _fill_slots(false))
	_menu_button("BORRAR", _fill_delete)
	_menu_button("SALIR DE LA PARTIDA", _show_title)
	_menu_button("SALIR DEL JUEGO", _quit_game)


func _menu_button(text: String, call: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(call)
	slots_list.add_child(button)


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
	for child in slots_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "GUARDAR" if saving else "CARGAR"
	slots_list.add_child(title)
	for row in ThrongletSimServer.list_slots():
		var index := int(row.i)
		var line := HBoxContainer.new()
		var label := Label.new()
		if bool(row.used):
			label.text = "RANURA %d  POB %d" % [index + 1, int(row.living)]
		else:
			label.text = "RANURA %d  VACIA" % [index + 1]
		line.add_child(label)
		var button := Button.new()
		if saving:
			button.text = "GUARDAR"
			button.pressed.connect(_save_row.bind(index))
		else:
			button.text = "CARGAR"
			button.disabled = not bool(row.used)
			button.pressed.connect(_load_row.bind(index))
		line.add_child(button)
		if bool(row.used):
			var erase := Button.new()
			erase.text = "BORRAR"
			erase.pressed.connect(_delete_row.bind(index, saving))
			line.add_child(erase)
		slots_list.add_child(line)
	_menu_button("VOLVER", _show_menu)


func _fill_delete() -> void:
	for child in slots_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "BORRAR"
	slots_list.add_child(title)
	var any := false
	for row in ThrongletSimServer.list_slots():
		if not bool(row.used):
			continue
		any = true
		var index := int(row.i)
		var button := Button.new()
		button.text = "RANURA %d  POB %d" % [index + 1, int(row.living)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_delete_row.bind(index, false))
		slots_list.add_child(button)
	if not any:
		var empty := Label.new()
		empty.text = "NO HAY PARTIDAS"
		slots_list.add_child(empty)
	_menu_button("VOLVER", _show_menu)


func _save_row(index: int) -> void:
	ThrongletSimServer.save_slot(index)
	_fill_slots(true)


func _load_row(index: int) -> void:
	ThrongletSimServer.load_slot(index)
	_close_slots()


func _delete_row(index: int, saving: bool) -> void:
	ThrongletSimServer.delete_slot(index)
	if slots_list.get_child_count() > 0 and str(slots_list.get_child(0).text) == "BORRAR":
		_fill_delete()
	else:
		_fill_slots(saving)


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
	sfx["mitosis"] = _player(_tone(740.0, 70, 0.2, false) , "mitosis")
	sfx["chop"] = _player(_tone(180.0, 45, 0.18, true), "chop")
	sfx["mop"] = _player(_tone(420.0, 90, 0.16, false), "mop")
	sfx["gaze"] = _player(_tone(90.0, 420, 0.22, false), "gaze")
	sfx["place"] = _player(_tone(560.0, 60, 0.16, false), "place")
	sfx["death"] = _player(_tone(120.0, 180, 0.2, false), "death")
	sfx["explode"] = _player(_tone(70.0, 220, 0.24, true), "explode")


func _player(stream: AudioStream, node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	add_child(player)
	return player


func _tone(freq: float, ms: int, volume: float, noise: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * float(ms) / 1000.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var step := freq / float(rate)
	var rng := RandomNumberGenerator.new()
	for i in count:
		var env := 1.0 - float(i) / float(count)
		var sample := 0.0
		if noise:
			sample = rng.randf_range(-1.0, 1.0)
		else:
			sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var value := int(clamp(sample * env * volume * 32767.0, -32767.0, 32767.0))
		bytes.encode_s16(i * 2, value)
		phase += step
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _play(name: String) -> void:
	if sfx.has(name):
		sfx[name].play()
