extends RefCounted
class_name KitToolbar

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const ProgressionManager := preload("res://scripts/core/progression_manager.gd")

## Main scene node owning kit panels, drag state, and tool selection.
var host: Node2D
## Camera used when kit drags release tools or buildings on the island.
var cam_rig: CameraRig
## Nine-slice border width in pixels for scaled toolbar frame art.
const TRAY_FRAME := 5
## Resized tray border textures keyed by asset path and source frame size.
var _tray_tex_cache := {}
## Host hook: true when a kit tool id uses hold-to-charge instead of click.
var on_is_charge_tool: Callable
## Host hook that resets charge progress when a drag ends or cancels.
var on_clear_tool_charge: Callable
## Host hook true when the pointer is over the island, not blocking UI.
var on_drop_on_island: Callable
## Host hook that returns an atlas Texture2D for icons without HQ PNGs.
var on_atlas_icon: Callable

## Wires host and camera references used for kit drag placement.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host
	cam_rig = p_cam_rig

## Sets control offsets from a screen Rect2.
func set_box(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y


## Tab metadata for tools, builds, and sandbox props.
func kit_tabs() -> Array:
	var tabs: Array = [
		{"label": "CUIDA", "title": "CUIDADOS", "tools": [Catalog.TOOL_APPLE, Catalog.TOOL_BALL, Catalog.TOOL_SPONGE], "builds": [], "props": []},
		{"label": "UTIL", "title": "HERRAMIENTAS", "tools": [Catalog.TOOL_AXE, Catalog.TOOL_HAMMER, Catalog.TOOL_PICK, Catalog.TOOL_SAW, Catalog.TOOL_GRAB, Catalog.TOOL_MOP], "builds": [], "props": []},
		{"label": "HOGAR", "title": "CUIDADOS EXTRA", "tools": [], "builds": [Catalog.BLD_TUB, Catalog.BLD_APPLE, Catalog.BLD_ROUND], "props": []},
		{"label": "OBRA", "title": "CONSTRUCCION", "tools": [], "builds": [Catalog.BLD_DWELL, Catalog.BLD_FANCY, Catalog.BLD_MINE, Catalog.BLD_MINE2, Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2, Catalog.BLD_THEATRE, Catalog.BLD_MARKET], "props": []},
		{"label": "DECOR", "title": "DECORACION", "tools": [], "builds": [Catalog.BLD_FLOWER, Catalog.BLD_STATUE], "props": []},
		{"label": "BUGS", "title": "ESPECIALES", "tools": [Catalog.TOOL_BUG, Catalog.TOOL_SWARM, Catalog.TOOL_TNT, Catalog.TOOL_NUKE], "builds": [], "props": []},
	]
	if ThrongletSimServer.sandbox_mode:
		tabs.append({
			"label": "MAPA",
			"title": "TERRENO",
			"tools": [],
			"builds": [],
			"props": ["tree", "rock", "ore", "flower", "water", "grass", "thronglet"],
		})
	return tabs


## Label and icon for a sandbox terrain prop.
func sandbox_prop_info(prop: String) -> Dictionary:
	match prop:
		"tree":
			return {"label": "ARBOL", "icon": Catalog.ICON_TREE}
		"rock":
			return {"label": "ROCA", "icon": Catalog.ICON_ROCK}
		"ore":
			return {"label": "MINERAL", "icon": Catalog.ICON_ORE_ROCK}
		"flower":
			return {"label": "FLOR", "icon": Catalog.ICON_FLOWER}
		"water":
			return {"label": "AGUA", "icon": Catalog.ICON_SPONGE}
		"grass":
			return {"label": "HIERBA", "icon": Catalog.ICON_APPLE_TREE}
		"thronglet":
			return {"label": "THRONGLET", "icon": Catalog.ICON_EGG}
		_:
			return {}


## Catalog tool row for an id.
func tool_entry(id: int) -> Dictionary:
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == id:
			return entry
	return {}


## Whether a tab has any unlocked visible entry.
func tab_ready(tab: Dictionary) -> bool:
	var sim: ThrongletSim = ThrongletSimServer
	if not tab.get("props", []).is_empty() and sim.sandbox_mode:
		return true
	for id in tab.tools:
		var entry := tool_entry(int(id))
		if not entry.is_empty():
			var ukey := str(entry.get("unlock", ""))
			if ukey == "" or (bool(sim.unlocks.get(ukey, false)) and not ProgressionManager.replaced_by_unlocked(sim, ukey)):
				return true
	for id in tab.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if not info.is_empty():
			var bkey := str(info.get("unlock", ""))
			if bkey == "" or bool(sim.unlocks.get(bkey, false)):
				return true
	return false


## Indices of tabs that have unlockable content.
func ready_tabs() -> Array:
	var ready: Array = []
	var tabs := kit_tabs()
	for i in tabs.size():
		if tab_ready(tabs[i]):
			ready.append(i)
	return ready


## Toolbar tab texture path for a label key.
func tab_icon(label: String) -> String:
	match label:
		"MAPA":
			return "res://resources/ui/tab_build.png"
		"CUIDA":
			return "res://resources/ui/tab_care.png"
		"UTIL":
			return "res://resources/ui/tab_tools.png"
		"OBRA":
			return "res://resources/ui/tab_build.png"
		"HOGAR":
			return "res://resources/ui/tab_home.png"
		"DECOR":
			return "res://resources/ui/tab_decor.png"
		_:
			return "res://resources/ui/tab_dev.png"


## Centered icon TextureRect padded inside a cell.
func tray_face(icon: int, pad: float = 8.0) -> TextureRect:
	var glyph := TextureRect.new()
	var hq := Catalog.menu_icon_path(icon)
	if hq != "":
		glyph.texture = host.ui_assets.tex(hq)
	else:
		glyph.texture = on_atlas_icon.call(icon)
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = pad
	glyph.offset_top = pad
	glyph.offset_right = -pad
	glyph.offset_bottom = -pad
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glyph


## Flat full-rect button overlay for a tray cell.
func tray_button() -> Button:
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


## Nearest-scaled nine-slice source texture.
func tray_tex(path: String, src_frame: int) -> Texture2D:
	var key := "%s#%d" % [path, src_frame]
	if _tray_tex_cache.has(key):
		return _tray_tex_cache[key]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return host.ui_assets.tex(path)
	var width := maxi(img.get_width() * TRAY_FRAME / src_frame, TRAY_FRAME * 2 + 1)
	var height := maxi(img.get_height() * TRAY_FRAME / src_frame, TRAY_FRAME * 2 + 1)
	img.resize(width, height, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_tray_tex_cache[key] = tex
	return tex


## Nine-patch stylebox from tray border assets.
func tray_style(path: String, src_frame: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tray_tex(path, src_frame)
	style.texture_margin_left = TRAY_FRAME
	style.texture_margin_top = TRAY_FRAME
	style.texture_margin_right = TRAY_FRAME
	style.texture_margin_bottom = TRAY_FRAME
	return style


## Panel plus icon and invisible press button.
func tray_cell(icon: int, wide: float, tall: float, kind: String, glyph: Texture2D = null) -> Button:
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(wide, tall)
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "res://resources/ui/toolbar_border.png"
	var src_frame := 20
	if kind == "all" or kind == "on":
		path = "res://resources/ui/toolbar_slot.png"
		src_frame = 24
	cell.add_theme_stylebox_override("panel", tray_style(path, src_frame))
	if glyph != null:
		var face := tray_face(0, 6.0)
		face.texture = glyph
		cell.add_child(face)
	elif icon >= 0:
		cell.add_child(tray_face(icon))
	var button := tray_button()
	cell.add_child(button)
	return button


## Gem or wood cost row on a build cell.
func tray_price_row(cell: Panel, resource: String, amount: int) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 4.0
	row.offset_right = -4.0
	row.offset_top = -16.0
	row.offset_bottom = -2.0
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	if resource == "wood":
		icon.texture = on_atlas_icon.call(Catalog.ICON_WOOD)
	else:
		icon.texture = on_atlas_icon.call(Catalog.ICON_GEM)
	icon.custom_minimum_size = Vector2(12, 12)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	cell.add_child(row)


## Rebuilds tab row and current page item tray.
func rebuild_bars() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	for child in host.kit_tabs.get_children():
		child.queue_free()
	for child in host.kit_icons.get_children():
		child.queue_free()
	host.tool_buttons.clear()
	host.build_buttons.clear()
	var ready := ready_tabs()
	if ready.is_empty():
		set_kit_shown(false)
		return
	if not ready.has(host.kit_tab):
		host.kit_tab = int(ready[0])
	var tabs := kit_tabs()
	host.kit_tabs.visible = ready.size() > 1
	var page: Dictionary = tabs[host.kit_tab]
	var count := 0
	var pending: Array = []
	for id in page.tools:
		var entry := tool_entry(int(id))
		if entry.is_empty():
			continue
		var ukey := str(entry.get("unlock", ""))
		if not (ukey == "" or (bool(sim.unlocks.get(ukey, false)) and not ProgressionManager.replaced_by_unlocked(sim, ukey))):
			continue
		pending.append({"kind": "tool", "id": int(entry.tool), "icon": int(entry.icon)})
		count += 1
	for id in page.builds:
		var info: Dictionary = Catalog.BUILD_INFO.get(int(id), {})
		if info.is_empty():
			continue
		var bkey := str(info.get("unlock", ""))
		if not (bkey == "" or bool(sim.unlocks.get(bkey, false))):
			continue
		var build_id := int(id)
		if build_id == Catalog.BLD_MARKET and sim.has_building_kind(Catalog.BLD_MARKET):
			continue
		pending.append({"kind": "build", "id": build_id, "icon": int(info.icon)})
		count += 1
	for prop in page.get("props", []):
		var pinfo := sandbox_prop_info(str(prop))
		if pinfo.is_empty():
			continue
		pending.append({"kind": "prop", "prop": str(prop), "icon": int(pinfo.icon)})
		count += 1
	var tab_n := ready.size() if host.kit_tabs.visible else 0
	var tab_w := row_span(tab_n, 44.0)
	var item_w := row_span(maxi(count, 1), 54.0)
	var item_h := 44.0
	if host.kit_tabs.visible:
		for i in ready:
			var tab: Dictionary = tabs[i]
			var tab_i := int(i)
			var tab_kind := "on" if tab_i == host.kit_tab else "border"
			var tab_button := tray_cell(0, 44.0, 44.0, tab_kind, host.ui_assets.tex(tab_icon(str(tab.label))))
			tab_button.pressed.connect(set_kit_tab.bind(tab_i))
			host.kit_tabs.add_child(tab_button.get_parent())
	if host.kit_tabs.visible and tab_w > item_w:
		var gap := tab_w - item_w + float(TRAY_FRAME)
		host.kit_icons.add_child(tray_cell(-1, gap, item_h, "border").get_parent())
		item_w = tab_w
	for item in pending:
		var face := tray_cell(int(item.icon), 54.0, 44.0, "all")
		var cell: Panel = face.get_parent()
		if str(item.kind) == "prop":
			face.button_down.connect(begin_kit_prop_drag.bind(str(item.prop)))
		else:
			var item_id := int(item.id)
			if str(item.kind) == "tool":
				face.button_down.connect(begin_kit_drag.bind("tool", item_id))
				host.tool_buttons[item_id] = face
			else:
				face.button_down.connect(begin_kit_drag.bind("build", item_id))
				host.build_buttons[item_id] = face
				var info: Dictionary = Catalog.BUILD_INFO.get(item_id, {})
				var pid := str(info.get("unlock", ""))
				if pid != "":
					var cost := ProgressionManager.placement_cost(sim, pid)
					var resource := str(cost.get("resource", ""))
					if resource == "gem" or resource == "wood":
						tray_price_row(cell, resource, int(cost.get("amount", 0)))
		host.kit_icons.add_child(cell)
	var edge := -60.0
	var tab_h := 44.0
	var bar_w := maxf(tab_w, item_w)
	host.kit_panel.offset_right = edge
	host.kit_panel.offset_bottom = -8.0
	host.kit_panel.offset_left = edge - bar_w
	host.kit_panel.offset_top = -8.0 - item_h
	host.kit_tab_row.offset_right = edge
	host.kit_tab_row.offset_bottom = -8.0 - item_h + float(TRAY_FRAME)
	host.kit_tab_row.offset_left = edge - tab_w
	host.kit_tab_row.offset_top = host.kit_tab_row.offset_bottom - tab_h
	set_kit_shown(host.kit_open)


## Switches kit page and refreshes the tray.
func set_kit_tab(index: int) -> void:
	host.kit_tab = index
	rebuild_bars()


## Starts sandbox prop drag from the kit.
func begin_kit_prop_drag(prop: String) -> void:
	if ThrongletSimServer.frozen or ThrongletSimServer.paused:
		return
	if not ThrongletSimServer.sandbox_mode:
		return
	on_clear_tool_charge.call()
	host.kit_drag = {"type": "prop", "prop": prop}
	host.placing = -1
	host.tool = Catalog.TOOL_EYE


## Starts tool or building drag from the kit.
func begin_kit_drag(kind: String, id: int) -> void:
	if ThrongletSimServer.frozen or ThrongletSimServer.paused:
		return
	host.media.play("ui")
	host.kit_drag = {"type": kind, "id": id}
	if kind == "build":
		host.placing = id
		host.tool = Catalog.TOOL_EYE
	else:
		host.placing = -1
		host.tool = id


## Drops scooped items at the pointer.
func drop_scoop() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if not sim.has_scoop():
		return
	var at: Vector2 = host.cam_rig.pointer_world()
	sim.scoop_drop(at.x, at.y)
	on_clear_tool_charge.call()
	host.tool = Catalog.TOOL_EYE


## Clears kit drag and resets to eye tool.
func cancel_kit_drag() -> void:
	if ThrongletSimServer.has_scoop():
		drop_scoop()
	host.kit_drag = {}
	host.placing = -1
	on_clear_tool_charge.call()
	host.tool = Catalog.TOOL_EYE


## Applies placement or tool use on mouse release.
func end_kit_drag() -> void:
	if host.kit_drag.is_empty():
		return
	var kind := str(host.kit_drag.get("type", ""))
	var id := int(host.kit_drag.get("id", -1))
	var prop := str(host.kit_drag.get("prop", ""))
	host.kit_drag = {}
	host.placing = -1
	# Building ids collide with host.tool ids (factory==saw=8). Only tools charge.
	var was_charge: bool = kind == "tool" and bool(on_is_charge_tool.call(id))
	if kind == "tool" and id == Catalog.TOOL_GRAB and ThrongletSimServer.has_scoop():
		drop_scoop()
		return
	on_clear_tool_charge.call()
	if ThrongletSimServer.frozen or ThrongletSimServer.paused:
		host.tool = Catalog.TOOL_EYE
		return
	if kind == "prop":
		if prop != "" and on_drop_on_island.call():
			var at: Vector2 = host.cam_rig.grid_pointer_world()
			ThrongletSimServer.sandbox_place_prop(prop, at.x, at.y)
		host.tool = Catalog.TOOL_EYE
		return
	if id < 0:
		host.tool = Catalog.TOOL_EYE
		return
	if was_charge:
		host.tool = Catalog.TOOL_EYE
		return
	if not on_drop_on_island.call():
		host.tool = Catalog.TOOL_EYE
		return
	var place := (kind == "tool" and id == Catalog.TOOL_TNT) or kind == "build"
	var at: Vector2 = host.cam_rig.grid_pointer_world() if place else host.cam_rig.pointer_world()
	if kind == "build":
		ThrongletSimServer.place_building(id, at.x, at.y)
	elif kind == "tool":
		if id == Catalog.TOOL_SPONGE:
			# Hold already scrubbed via _process; release ends suds and pops sparkles if cleaned.
			ThrongletSimServer.sponge_release()
		else:
			ThrongletSimServer.use_tool(id, at.x, at.y)
	host.tool = Catalog.TOOL_EYE


## Atlas icon index for the active kit drag.
func kit_drag_icon() -> int:
	if host.kit_drag.is_empty():
		return -1
	if str(host.kit_drag.get("type", "")) == "prop":
		return int(sandbox_prop_info(str(host.kit_drag.get("prop", ""))).get("icon", -1))
	if str(host.kit_drag.get("type", "")) == "build":
		var info: Dictionary = Catalog.BUILD_INFO.get(int(host.kit_drag.get("id", -1)), {})
		return int(info.get("icon", -1))
	var entry := tool_entry(int(host.kit_drag.get("id", -1)))
	return int(entry.get("icon", -1))


## HUD label text for the active kit drag.
func kit_drag_label() -> String:
	if host.kit_drag.is_empty():
		return ""
	if str(host.kit_drag.get("type", "")) == "prop":
		return str(sandbox_prop_info(str(host.kit_drag.get("prop", ""))).get("label", ""))
	if str(host.kit_drag.get("type", "")) == "build":
		var info: Dictionary = Catalog.BUILD_INFO.get(int(host.kit_drag.get("id", -1)), {})
		var pid := str(info.get("unlock", ""))
		var cost := ProgressionManager.placement_cost(ThrongletSimServer, pid)
		var amount := int(cost.get("amount", 0))
		var resource := str(cost.get("resource", ""))
		if resource == "gem":
			return "%s  (%d GEMAS)" % [str(info.get("label", "")), amount]
		if resource == "wood":
			if amount <= 0:
				return "%s  (GRATIS)" % str(info.get("label", ""))
			return "%s  (%d MADERA)" % [str(info.get("label", "")), amount]
		return "%s  (GRATIS)" % str(info.get("label", ""))
	var entry := tool_entry(int(host.kit_drag.get("id", -1)))
	return str(entry.get("label", ""))


## Swaps replaced or locked tools to eye.
func sync_active_tool() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if host.tool == Catalog.TOOL_EYE:
		return
	if not sim._tool_open(host.tool):
		var rep := replacement_tool_for(host.tool)
		if rep >= 0 and sim._tool_open(rep):
			host.tool = rep
		else:
			host.tool = Catalog.TOOL_EYE


## Upgraded tool id for an unlock key.
func replacement_tool_for(tool_id: int) -> int:
	var key := ""
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) == tool_id:
			key = str(entry.get("unlock", ""))
			break
	if key == "":
		return -1
	var rep_key := ProgressionManager.replacement_for(ThrongletSimServer, key)
	if rep_key == "":
		return -1
	for entry in Catalog.TOOL_INFO:
		if str(entry.get("unlock", "")) == rep_key:
			return int(entry.tool)
	return -1


## Opens or closes the kit toolbar panel.
func toggle_kit() -> void:
	host.media.play("ui")
	host.kit_open = not host.kit_open
	if host.kit_open:
		rebuild_bars()
	else:
		set_kit_shown(false)


## Visibility for kit panel and tab row.
func set_kit_shown(shown: bool) -> void:
	if host.kit_panel != null:
		host.kit_panel.visible = shown
	if host.kit_tab_row != null:
		host.kit_tab_row.visible = shown and host.kit_tabs != null and host.kit_tabs.visible


## Total width of N tray cells minus frame overlap.
func row_span(count: int, cell: float) -> float:
	if count <= 0:
		return 0.0
	return float(count) * cell - float(maxi(count - 1, 0)) * float(TRAY_FRAME)


## Highlights dragged tool and build buttons.
func mark_selected() -> void:
	var drag_tool := -1
	var drag_build := -1
	if not host.kit_drag.is_empty():
		var drag_type := str(host.kit_drag.get("type", ""))
		if drag_type == "tool":
			drag_tool = int(host.kit_drag.get("id", -1))
		elif drag_type == "build":
			drag_build = int(host.kit_drag.get("id", -1))
	for id in host.tool_buttons.keys():
		var button: Button = host.tool_buttons[id]
		button.modulate = Color(1, 1, 1) if int(id) == drag_tool else Color(0.7, 0.7, 0.75)
	for id in host.build_buttons.keys():
		var button2: Button = host.build_buttons[id]
		button2.modulate = Color(1, 0.95, 0.6) if int(id) == drag_build else Color(0.75, 0.75, 0.8)


## Digit hotkeys select unlocked tools in order.
func hotkey(code: int) -> void:
	var order := [
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	]
	var tools: Array = []
	for entry in Catalog.TOOL_INFO:
		var tid := int(entry.tool)
		if tid == Catalog.TOOL_EYE:
			continue
		var ukey := str(entry.get("unlock", ""))
		if ukey == "" or (bool(ThrongletSimServer.unlocks.get(ukey, false)) and not ProgressionManager.replaced_by_unlocked(ThrongletSimServer, ukey)):
			tools.append(tid)
	for i in order.size():
		if code == order[i] and i < tools.size():
			host.media.play("ui")
			cancel_kit_drag()
			host.tool = int(tools[i])
