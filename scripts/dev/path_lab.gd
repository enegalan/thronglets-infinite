extends Node2D

## Path piece lab. Thin trails (4 cardinals) + filled plazas (diagonals / blob).
## Any solid block adapts: 2x2, 2x3, 2xN, 4x4… outer corners use tile 9 rotated,
## edges/inners/solid pull the fill atlas tiles. Writes res://dev/path_lab.json.

const PathLabTune := preload("res://scripts/data/tune/path_lab_tune.gd")
const PathOverlay := preload("res://scripts/presentation/world/path_overlay.gd")

## Thin-mask gallery origin (4×4 clusters of 3×3 stubs).
const GALLERY_ORIGIN := Vector2i(2, 6)
## Cell stride between thin gallery clusters.
const CLUSTER_STRIDE := 4
## Filled plaza demos origin (2x2, 2x3, 3x3, 4x4, 2x5).
const FILL_ORIGIN := Vector2i(2, 24)
## Paint playground origin.
const PAINT_ORIGIN := Vector2i(22, 8)
## Paint playground size in cells.
const PAINT_SIZE := Vector2i(14, 14)

## Ordered fill plaza demos: solid rects + stepped 2x2+stub (T → tile 14).
const FILL_DEMOS := [
	{"label": "2x2", "size": Vector2i(2, 2)},
	{"label": "2x3", "size": Vector2i(2, 3)},
	{"label": "3x2", "size": Vector2i(3, 2)},
	{"label": "3x3", "size": Vector2i(3, 3)},
	{"label": "2x5", "size": Vector2i(2, 5)},
	{"label": "4x4", "size": Vector2i(4, 4)},
	# Extra cell east of top-right → former corner becomes fill_t_n (tile 14).
	{"label": "2x2+E", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0)]},
	{"label": "2x2+S", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]},
]

## Main scene host (DevBench.main).
var main = null
## Owning DevBench for mode navigation callbacks.
var bench = null
## In-memory path lab config mirrored to JSON.
var cfg: Dictionary = {}
## Selected type id (thin_XX or fill_*).
var selected_id := "thin_00"
## Ordered type ids for << / >> navigation.
var type_ids: Array = []
## Guard suppressing cfg write-back while UI is being populated.
var _fill := false
## Left rail listing every type.
var rail: PanelContainer
## Bottom inspector + actions.
var bar: PanelContainer
## Scroll list of type buttons.
var list: VBoxContainer
## Type id → Button.
var type_buttons := {}
## Title on the bottom bar.
var name_label: Label
## Status / save outcome line.
var status_label: Label
## Atlas tile index spin.
var tile_spin: SpinBox
## Horizontal flip toggle.
var flip_h: CheckBox
## Vertical flip toggle.
var flip_v: CheckBox
## 90° CCW rotation count (0–3).
var rot_spin: SpinBox
## Live piece string readout.
var piece_label: Label
## Raw atlas tile preview TextureRect.
var atlas_preview: TextureRect
## Baked iso preview TextureRect.
var iso_preview: TextureRect
## Local PathOverlay baker.
var baker: PathOverlay
## Gallery/paint path sprites keyed by cell.
var sprites := {}
## Floating caption rows drawn in _draw.
var captions: Array = []
## Clickable gallery hotspots: cell → type id.
var hotspots := {}
## Paint-mode worn cells.
var paint_cells := {}
## Theme shared with DevBench.
var theme: Theme


## Attaches to Main/DevBench and builds UI + baker.
func setup(host, owner_bench, ui_theme: Theme) -> void:
	main = host
	bench = owner_bench
	theme = ui_theme
	z_index = 7
	baker = PathOverlay.new()
	baker.setup(null, self, null, self, main.ui_assets, main.cam_rig)
	cfg = PathLabTune.load_saved()
	_rebuild_type_ids()
	_build_ui()
	visible = false


## Shows the path lab UI and paints gallery + playground.
func open() -> void:
	cfg = PathLabTune.load_saved()
	_rebuild_type_ids()
	visible = true
	if rail:
		rail.visible = true
	if bar:
		bar.visible = true
	_fill_ui()
	_rebuild_world()
	_set_status("LAB PATH LISTO")


## Hides UI and clears lab sprites/captions.
func close() -> void:
	visible = false
	if rail:
		rail.visible = false
	if bar:
		bar.visible = false
	_clear_world()


## Frees UI panels owned on Main's HUD root.
func dispose() -> void:
	close()
	if rail != null:
		rail.queue_free()
		rail = null
	if bar != null:
		bar.queue_free()
		bar = null


## True while the path lab UI is visible.
func is_open() -> bool:
	return visible


## Per-frame redraw of selection highlight overlays.
func tick() -> void:
	if not visible:
		return
	queue_redraw()


## Left-click: select gallery type or toggle paint cells.
func handle_click(_shift: bool) -> void:
	if not visible or main == null:
		return
	var cell: Vector2i = _cursor_cell()
	if hotspots.has(cell):
		_select_id(str(hotspots[cell]))
		return
	if _in_paint(cell):
		var key := "%d,%d" % [cell.x, cell.y]
		if paint_cells.has(key):
			paint_cells.erase(key)
		else:
			paint_cells[key] = true
		_rebuild_world()
		var card := _mask_from_worn(cell, paint_cells) if paint_cells.has(key) else 0
		var diag := _diag_from_worn(cell, paint_cells) if paint_cells.has(key) else 0
		var tid := PathLabTune.type_id(card, diag) if paint_cells.has(key) else "-"
		_set_status("PINTURA %s @ %d,%d → %s" % [
			"ON" if paint_cells.has(key) else "OFF", cell.x, cell.y, tid
		])


## Builds left type list and bottom inspector.
func _build_ui() -> void:
	var root: Control = main.ui.get_child(0)

	rail = PanelContainer.new()
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = 4
	rail.offset_top = 4
	rail.offset_right = 230
	rail.offset_bottom = -4
	rail.mouse_filter = Control.MOUSE_FILTER_STOP
	rail.theme = theme
	rail.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	rail.add_child(scroll)
	root.add_child(rail)

	var hint := Label.new()
	hint.text = "Sendas finas (cardinales) + rellenos (diagonales). Cualquier bloque 2x2 / 2x3 / 2xN / 4x4 adapta esquinas (tile 9 rotado), bordes e interior. Pintura libre a la derecha. GUARDAR → dev/path_lab.json."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(hint)

	_section(list, "FINAS")
	for mask in range(16):
		_add_type_button(PathLabTune.thin_id(mask))
	_section(list, "RELLENO (blob)")
	for id in PathLabTune.FILL_IDS:
		_add_type_button(id)

	bar = PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 238
	bar.offset_top = -150
	bar.offset_right = -4
	bar.offset_bottom = -4
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.theme = theme
	bar.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	name_label = Label.new()
	name_label.clip_text = true
	box.add_child(name_label)

	var edit := HBoxContainer.new()
	edit.add_theme_constant_override("separation", 6)
	atlas_preview = TextureRect.new()
	atlas_preview.custom_minimum_size = Vector2(48, 48)
	atlas_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	atlas_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	atlas_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edit.add_child(atlas_preview)
	iso_preview = TextureRect.new()
	iso_preview.custom_minimum_size = Vector2(72, 40)
	iso_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	iso_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	iso_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	edit.add_child(iso_preview)

	tile_spin = _spin(0, PathLabTune.TILE_COUNT - 1, 1, true)
	tile_spin.tooltip_text = "Indice del tile en path_overlay.png (0..14)"
	flip_h = CheckBox.new()
	flip_h.text = "H"
	flip_h.focus_mode = Control.FOCUS_NONE
	flip_v = CheckBox.new()
	flip_v.text = "V"
	flip_v.focus_mode = Control.FOCUS_NONE
	rot_spin = _spin(0, 3, 1, true)
	rot_spin.tooltip_text = "Rotaciones 90 deg CCW (r)"
	piece_label = Label.new()
	piece_label.custom_minimum_size = Vector2(80, 0)
	_pair(edit, "TILE", tile_spin)
	edit.add_child(flip_h)
	edit.add_child(flip_v)
	_pair(edit, "R", rot_spin)
	edit.add_child(piece_label)
	box.add_child(edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.add_child(_btn("<<", _select_prev))
	actions.add_child(_btn(">>", _select_next))
	actions.add_child(_btn("DEFAULT", _reset_selected))
	actions.add_child(_btn("DEFAULT ALL", _reset_all))
	actions.add_child(_btn("LIMPIAR PINTURA", _clear_paint))
	actions.add_child(_btn("GUARDAR JSON", _save))
	actions.add_child(_btn("CARGAR JSON", _load))
	actions.add_child(_btn("PROPS", func(): bench._show_props()))
	actions.add_child(_btn("ANIM", func(): bench._show_throng()))
	actions.add_child(_btn("EFFECTS", func(): bench._show_effects()))
	actions.add_child(_btn("LAB TIOVIVO", func(): bench._show_lab()))
	actions.add_child(_btn("MENU", main._leave_dev))
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	actions.add_child(status_label)
	box.add_child(actions)
	bar.add_child(box)
	root.add_child(bar)

	tile_spin.value_changed.connect(_on_edit)
	flip_h.toggled.connect(func(_on): _on_edit(0.0))
	flip_v.toggled.connect(func(_on): _on_edit(0.0))
	rot_spin.value_changed.connect(_on_edit)


## Rebuilds ordered type id list.
func _rebuild_type_ids() -> void:
	type_ids.clear()
	for mask in range(16):
		type_ids.append(PathLabTune.thin_id(mask))
	for id in PathLabTune.FILL_IDS:
		type_ids.append(id)


## Section title in the rail.
func _section(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


## Adds one type button to the rail list.
func _add_type_button(id: String) -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.pressed.connect(_select_id.bind(id))
	list.add_child(btn)
	type_buttons[id] = btn


## Syncs inspector + type list from cfg.
func _fill_ui() -> void:
	_fill = true
	_refresh_type_buttons()
	_fill_inspector()
	_fill = false


## Updates every type button caption with current piece.
func _refresh_type_buttons() -> void:
	for id in type_buttons.keys():
		var btn: Button = type_buttons[id]
		var piece := _piece_for_id(str(id))
		btn.text = "%s  [%s]" % [PathLabTune.label_for_id(str(id)), piece]
		btn.tooltip_text = "%s → %s" % [id, piece]
		btn.modulate = Color(1.2, 1.05, 0.7) if str(id) == selected_id else Color.WHITE


## Fills spins/toggles from the selected type piece.
func _fill_inspector() -> void:
	var piece := _piece_for_id(selected_id)
	var parsed := PathLabTune.parse_piece(piece)
	_fill = true
	tile_spin.value = int(parsed.index)
	var ops := str(parsed.ops)
	flip_h.button_pressed = ops.contains("h")
	flip_v.button_pressed = ops.contains("v")
	rot_spin.value = ops.count("r")
	_fill = false
	piece_label.text = piece
	name_label.text = "LAB PATH  -  %s  (%s)" % [PathLabTune.label_for_id(selected_id), selected_id]
	_refresh_previews(piece)


## Selects a type id and refreshes inspector + highlight.
func _select_id(id: String) -> void:
	if not type_buttons.has(id):
		return
	selected_id = id
	_fill_inspector()
	_refresh_type_buttons()
	_rebuild_world()
	queue_redraw()


## Previous type in the ordered list.
func _select_prev() -> void:
	var i := type_ids.find(selected_id)
	if i < 0:
		i = 0
	_select_id(str(type_ids[(i + type_ids.size() - 1) % type_ids.size()]))


## Next type in the ordered list.
func _select_next() -> void:
	var i := type_ids.find(selected_id)
	if i < 0:
		i = 0
	_select_id(str(type_ids[(i + 1) % type_ids.size()]))


## Writes inspector edits into cfg and rebuilds world preview.
func _on_edit(_v: float) -> void:
	if _fill:
		return
	var ops := ""
	for _i in int(rot_spin.value):
		ops += "r"
	if flip_h.button_pressed:
		ops += "h"
	if flip_v.button_pressed:
		ops += "v"
	var piece := PathLabTune.encode_piece(int(tile_spin.value), ops)
	_set_piece_for_id(selected_id, piece)
	piece_label.text = piece
	_refresh_type_buttons()
	_refresh_previews(piece)
	_rebuild_world()
	_set_status("EDIT %s -> %s" % [selected_id, piece])


## Restores shipped default piece for the selected type.
func _reset_selected() -> void:
	var piece := ""
	if selected_id.begins_with("thin_"):
		piece = PathLabTune.DEFAULT_THIN[clampi(int(selected_id.substr(5)), 0, 15)]
	else:
		piece = str(PathLabTune.DEFAULT_FILL.get(selected_id, "8"))
	_set_piece_for_id(selected_id, piece)
	_fill_inspector()
	_refresh_type_buttons()
	_rebuild_world()
	_set_status("DEFAULT %s" % selected_id)


## Restores all shipped default pieces.
func _reset_all() -> void:
	cfg = PathLabTune.defaults()
	_fill_ui()
	_rebuild_world()
	_set_status("DEFAULT ALL")


## Clears paint playground cells.
func _clear_paint() -> void:
	paint_cells.clear()
	_rebuild_world()
	_set_status("PINTURA LIMPIA")


## Saves cfg to dev/path_lab.json and refreshes Main overlay pieces.
func _save() -> void:
	var path := PathLabTune.save_file(cfg)
	if path == "":
		_set_status("ERROR AL GUARDAR")
		return
	if main.path_overlay != null:
		main.path_overlay.path_iso.clear()
	_set_status("GUARDADO: %s" % path)


## Reloads cfg from disk.
func _load() -> void:
	cfg = PathLabTune.load_saved()
	_fill_ui()
	_rebuild_world()
	_set_status("CARGADO dev/path_lab.json")


## Reads piece string for a type id from cfg.
func _piece_for_id(id: String) -> String:
	if id.begins_with("thin_"):
		var mask := clampi(int(id.substr(5)), 0, 15)
		var thin = cfg.get("thin", cfg.get("pieces", []))
		if typeof(thin) == TYPE_ARRAY and thin.size() > mask:
			var row = thin[mask]
			if typeof(row) == TYPE_DICTIONARY and row.has("piece"):
				return str(row.piece)
			if typeof(row) == TYPE_STRING:
				return str(row)
		return PathLabTune.DEFAULT_THIN[mask]
	var fill = cfg.get("fill", [])
	if typeof(fill) == TYPE_ARRAY:
		for row in fill:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
				return str(row.get("piece", PathLabTune.DEFAULT_FILL.get(id, "8")))
	return str(PathLabTune.DEFAULT_FILL.get(id, "8"))


## Writes piece string for a type id into cfg.
func _set_piece_for_id(id: String, piece: String) -> void:
	if cfg.is_empty():
		cfg = PathLabTune.defaults()
	if id.begins_with("thin_"):
		var mask := clampi(int(id.substr(5)), 0, 15)
		if not cfg.has("thin") or typeof(cfg.thin) != TYPE_ARRAY:
			cfg = PathLabTune.defaults()
		var thin: Array = cfg.thin
		while thin.size() < 16:
			var m := thin.size()
			thin.append({
				"mask": m,
				"id": PathLabTune.thin_id(m),
				"label": PathLabTune.label_for(m),
				"kind": PathLabTune.kind_for(m),
				"dirs": PathLabTune.mask_dirs(m),
				"piece": PathLabTune.DEFAULT_THIN[m],
			})
		var row: Dictionary = thin[mask] if typeof(thin[mask]) == TYPE_DICTIONARY else {}
		row.mask = mask
		row.id = PathLabTune.thin_id(mask)
		row.label = PathLabTune.label_for(mask)
		row.kind = PathLabTune.kind_for(mask)
		row.dirs = PathLabTune.mask_dirs(mask)
		row.piece = piece
		thin[mask] = row
		cfg.thin = thin
		return
	if not cfg.has("fill") or typeof(cfg.fill) != TYPE_ARRAY:
		cfg = PathLabTune.defaults()
	var fill: Array = cfg.fill
	var found := false
	for i in fill.size():
		var row: Dictionary = fill[i]
		if str(row.get("id", "")) == id:
			row.piece = piece
			fill[i] = row
			found = true
			break
	if not found:
		fill.append({
			"id": id,
			"label": PathLabTune.label_for_id(id),
			"kind": "relleno",
			"piece": piece,
		})
	cfg.fill = fill


## Updates raw atlas + baked iso preview textures.
func _refresh_previews(piece: String) -> void:
	baker.path_iso.clear()
	var parsed := PathLabTune.parse_piece(piece)
	var raw := baker.path_raw(int(parsed.index))
	var ops := str(parsed.ops)
	for i in ops.length():
		raw = baker.path_turn(raw, ops.substr(i, 1))
	atlas_preview.texture = ImageTexture.create_from_image(raw)
	iso_preview.texture = baker.path_iso_tex(piece)


## Rebuilds thin gallery + fill demos + paint playground.
func _rebuild_world() -> void:
	_clear_world()
	if main == null:
		return
	main.path_overlay.clear_paths(main.pathmap)
	hotspots.clear()

	# Thin gallery: 4x4 clusters with stub neighbors (no diagonals → thin types).
	for mask in range(16):
		var cluster := Vector2i(mask % 4, int(mask / 4))
		var center := GALLERY_ORIGIN + cluster * CLUSTER_STRIDE + Vector2i(1, 1)
		var worn := {("%d,%d" % [center.x, center.y]): true}
		if mask & PathLabTune.N:
			worn["%d,%d" % [center.x, center.y - 1]] = true
		if mask & PathLabTune.E:
			worn["%d,%d" % [center.x + 1, center.y]] = true
		if mask & PathLabTune.S:
			worn["%d,%d" % [center.x, center.y + 1]] = true
		if mask & PathLabTune.W:
			worn["%d,%d" % [center.x - 1, center.y]] = true
		_stamp_worn(worn, PathLabTune.thin_id(mask), center)

	# Fill plaza demos: solid rectangles + stepped stubs.
	var cursor := FILL_ORIGIN
	for demo in FILL_DEMOS:
		var worn := {}
		var span := Vector2i.ZERO
		if demo.has("cells"):
			for offset in demo.cells:
				var o: Vector2i = offset
				worn["%d,%d" % [cursor.x + o.x, cursor.y + o.y]] = true
				span.x = maxi(span.x, o.x + 1)
				span.y = maxi(span.y, o.y + 1)
		else:
			var size: Vector2i = demo.size
			span = size
			for y in size.y:
				for x in size.x:
					worn["%d,%d" % [cursor.x + x, cursor.y + y]] = true
		_stamp_worn(worn, "", Vector2i(-999, -999))
		_place_label(cursor + Vector2i(0, -1), str(demo.label), false)
		for key in worn.keys():
			var parts := str(key).split(",")
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			hotspots[cell] = PathLabTune.type_id(_mask_from_worn(cell, worn), _diag_from_worn(cell, worn))
		cursor.x += span.x + 2

	# Paint playground
	_stamp_worn(paint_cells, "", Vector2i(-999, -999), true)


## Stamps sprites/labels for every cell in [param worn].
func _stamp_worn(worn: Dictionary, force_id: String, highlight_cell: Vector2i, label_all: bool = false) -> void:
	for key in worn.keys():
		var parts := str(key).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var card := _mask_from_worn(cell, worn)
		var diag := _diag_from_worn(cell, worn)
		var tid := force_id if force_id != "" and cell == highlight_cell else PathLabTune.type_id(card, diag)
		var piece := _piece_for_id(tid)
		var highlight := (force_id != "" and cell == highlight_cell and force_id == selected_id) \
			or (tid == selected_id)
		_place_sprite(cell, piece, highlight)
		if force_id != "" and cell == highlight_cell:
			hotspots[cell] = force_id
			_place_label(cell, PathLabTune.label_for_id(force_id), force_id == selected_id)
		elif label_all:
			_place_label(cell, PathLabTune.label_for_id(tid), tid == selected_id)
		elif tid.begins_with("fill_") and highlight:
			_place_label(cell, PathLabTune.label_for_id(tid), true)


## Frees lab sprites and caption rows.
func _clear_world() -> void:
	for cell in sprites.keys():
		var spr: Sprite2D = sprites[cell]
		if is_instance_valid(spr):
			spr.queue_free()
	sprites.clear()
	captions.clear()
	hotspots.clear()


## Spawns a path sprite at [param cell] with [param piece].
func _place_sprite(cell: Vector2i, piece: String, highlight: bool) -> void:
	if sprites.has(cell):
		# Prefer the later stamp (fill demos / paint overwrite thin if overlap).
		var old: Sprite2D = sprites[cell]
		if is_instance_valid(old):
			old.queue_free()
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = baker.path_iso_tex(piece)
	spr.position = main.cam_rig.to_iso(Catalog.cell_world(cell))
	spr.scale = Vector2(1.12, 1.12)
	if highlight:
		spr.modulate = Color(1.15, 1.05, 0.75)
	add_child(spr)
	sprites[cell] = spr


## Queues a floating caption above [param cell].
func _place_label(cell: Vector2i, text: String, selected: bool) -> void:
	var iso: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(cell))
	captions.append({
		"pos": iso + Vector2(0, -22),
		"text": text,
		"selected": selected,
	})


## Cardinal neighbor mask from a worn-cell dictionary.
func _mask_from_worn(cell: Vector2i, worn: Dictionary) -> int:
	var mask := 0
	if worn.has("%d,%d" % [cell.x, cell.y - 1]):
		mask |= PathLabTune.N
	if worn.has("%d,%d" % [cell.x + 1, cell.y]):
		mask |= PathLabTune.E
	if worn.has("%d,%d" % [cell.x, cell.y + 1]):
		mask |= PathLabTune.S
	if worn.has("%d,%d" % [cell.x - 1, cell.y]):
		mask |= PathLabTune.W
	return mask


## Counted diagonal mask (blob rule) from a worn-cell dictionary.
func _diag_from_worn(cell: Vector2i, worn: Dictionary) -> int:
	var n := worn.has("%d,%d" % [cell.x, cell.y - 1])
	var e := worn.has("%d,%d" % [cell.x + 1, cell.y])
	var s := worn.has("%d,%d" % [cell.x, cell.y + 1])
	var w := worn.has("%d,%d" % [cell.x - 1, cell.y])
	var diag := 0
	if n and e and worn.has("%d,%d" % [cell.x + 1, cell.y - 1]):
		diag |= PathLabTune.NE
	if s and e and worn.has("%d,%d" % [cell.x + 1, cell.y + 1]):
		diag |= PathLabTune.SE
	if s and w and worn.has("%d,%d" % [cell.x - 1, cell.y + 1]):
		diag |= PathLabTune.SW
	if n and w and worn.has("%d,%d" % [cell.x - 1, cell.y - 1]):
		diag |= PathLabTune.NW
	return diag


## Whether [param cell] is inside the paint playground.
func _in_paint(cell: Vector2i) -> bool:
	return cell.x >= PAINT_ORIGIN.x and cell.y >= PAINT_ORIGIN.y \
		and cell.x < PAINT_ORIGIN.x + PAINT_SIZE.x and cell.y < PAINT_ORIGIN.y + PAINT_SIZE.y


## Grid cell under the current pointer.
func _cursor_cell() -> Vector2i:
	var at: Vector2 = main.cam_rig.grid_pointer_world()
	var tile := float(Catalog.TILE)
	return Vector2i(int(floor(at.x / tile)), int(floor(at.y / tile)))


## Draws gallery/paint frames, captions, and selection ring.
func _draw() -> void:
	if not visible or main == null:
		return
	var poly: PackedVector2Array = main.placement_overlay.place_cell_poly()
	var font: Font = ThemeDB.fallback_font
	if main.ui_theme != null and main.ui_theme.default_font != null:
		font = main.ui_theme.default_font
	if not poly.is_empty():
		for y in PAINT_SIZE.y:
			for x in PAINT_SIZE.x:
				_stroke_cell(PAINT_ORIGIN + Vector2i(x, y), poly, Color(0.35, 0.7, 1.0, 0.18), Color(0, 0, 0, 0))
		# Outline fill demos
		var cursor := FILL_ORIGIN
		for demo in FILL_DEMOS:
			var span := Vector2i.ONE
			if demo.has("cells"):
				for offset in demo.cells:
					var o: Vector2i = offset
					_stroke_cell(cursor + o, poly, Color(1.0, 0.7, 0.25, 0.35), Color(0, 0, 0, 0))
					span.x = maxi(span.x, o.x + 1)
					span.y = maxi(span.y, o.y + 1)
			else:
				var size: Vector2i = demo.size
				span = size
				for y in size.y:
					for x in size.x:
						_stroke_cell(cursor + Vector2i(x, y), poly, Color(1.0, 0.7, 0.25, 0.35), Color(0, 0, 0, 0))
			cursor.x += span.x + 2
	for row in captions:
		var text := str(row.text)
		var pos: Vector2 = row.pos
		var selected := bool(row.selected)
		var color := Color(1.0, 0.92, 0.45) if selected else Color(0.95, 0.9, 0.8)
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var at := pos - Vector2(size.x * 0.5, 0)
		draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	var g_title: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(GALLERY_ORIGIN + Vector2i(1, -1)))
	draw_string(font, g_title + Vector2(1, 1), "FINAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.85))
	draw_string(font, g_title, "FINAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.75))
	var f_title: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(FILL_ORIGIN + Vector2i(0, -2)))
	draw_string(font, f_title + Vector2(1, 1), "RELLENOS 2xN / MxN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.85))
	draw_string(font, f_title, "RELLENOS 2xN / MxN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.75, 0.35))
	var p_title: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(PAINT_ORIGIN + Vector2i(0, -1)))
	draw_string(font, p_title + Vector2(1, 1), "PINTURA (click)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.85))
	draw_string(font, p_title, "PINTURA (click)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.85, 1.0))


## Strokes one iso cell diamond.
func _stroke_cell(cell: Vector2i, poly: PackedVector2Array, edge: Color, fill: Color) -> void:
	var pts := PackedVector2Array()
	var origin: Vector2 = main.cam_rig.to_iso(Catalog.cell_world(cell))
	for p in poly:
		pts.append(origin + p)
	if fill.a > 0.0:
		draw_colored_polygon(pts, fill)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], edge, 1.2)


## Status line helper.
func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


## Themed button helper.
func _btn(text: String, call: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	return button


## Bounded SpinBox helper.
func _spin(lo: float, hi: float, step: float, whole: bool = false) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = lo
	box.max_value = hi
	box.step = step if whole else 0.01
	box.rounded = whole
	box.custom_minimum_size = Vector2(52, 22)
	box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return box


## Labeled spin row helper.
func _pair(row: HBoxContainer, title: String, box: SpinBox) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(28, 0)
	row.add_child(label)
	row.add_child(box)
