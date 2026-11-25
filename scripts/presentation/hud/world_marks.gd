extends RefCounted
class_name WorldMarks

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")

## World or HUD host receiving mark nodes and reading cam_rig each sync.
var host: Node2D
## Camera used to project mark anchors from world feet to screen space.
var cam_rig: CameraRig
## Speech bubble PanelContainers pooled for simultaneous throng barks.
var bubble_panels: Array = []
## Reserved tail TextureRects (tips baked into bubble frames).
var bubble_tails: Array = []
## Glyph TextureRects inside each bubble showing the bark icon.
var bubble_icons: Array = []
## Optional text labels kept off panels for icon-only bark sizing.
var bubble_labels: Array = []
## LLENO / occupancy text labels above full visit buildings.
var full_labels: Array = []
## NinePatch gauge backplates for mine and home capacity bars.
var cap_tracks: Array = []
## NinePatch fill strips showing occupancy fraction on cap tracks.
var cap_fills: Array = []
## Dashed Line2D segments outlining selected building reach ellipses.
var ring_lines: Array = []
## Fullscreen HUD ColorRect toggled during sim glitch events.
var glitch_overlay: ColorRect
## Shader material driving glitch intensity from sim.glitch_t.
var glitch_mat: ShaderMaterial
## Pooled factory progress overlays (frame Sprite2D plus wedge slices).
var factory_marks: Array = []
## Pre-cut wedge textures from factory_slice.png per process sector.
var _factory_slice_texs: Array[Texture2D] = []
## Active factory wedge sprites for the current sync (first filled factory).
var factory_slices: Array[Sprite2D] = []
## Dirty-throng pollution icon following the selected agent in world space.
var pollution_mark: Sprite2D
## Building pollution warning sprite parked above the first polluted bld.
var pollution_bld: Sprite2D
## Container for "new item" markers above market buildings.
var market_signs: Node2D
## Need-card gauge fill NinePatchRects for fed, amused, and clean stats.
var need_fills: Array = []
## Selected-throng needs tooltip grid parented on the HUD root.
var need_card: Control
## Info-pin glyph hovering above the need card header.
var need_icon: TextureRect
## Floating panel listing agent tasks when focus mode is off.
var agent_task_panel: PanelContainer
## Title label at the top of the agent task panel.
var agent_task_title: Label
## Body rows under the task title (rebuilt by the host each sync).
var agent_task_rows: Array[Label] = []
## Cached AtlasTexture slices from structures_tileset for generic icons.
var _atlas_tex_cache := {}
## Cached textures for speech-bubble bark glyph ids.
var _bark_tex_cache := {}
## Decoded bark icon sheet pixels for nearest-neighbor glyph crops.
var _bark_atlas_img: Image
## Host hook for idle building sprite anchors on capacity marks.
var on_building_draw_at: Callable
## Host hook for active building anchors when guests occupy visit sites.
var on_building_active_draw_at: Callable
## Host hook building reach ellipse points for selection ring dashes.
var on_iso_ellipse_points: Callable
## Host hook hiding barks for thronglets inside visit buildings.
var on_throng_hidden_indoors: Callable

## Registers the world host and camera used to position every mark overlay.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host
	cam_rig = p_cam_rig

## Spawns pollution sprites and market sign root.
func attach_world_nodes(world_host: Node2D, p_ui_assets) -> void:
	host = world_host
	market_signs = Node2D.new()
	market_signs.z_index = 8
	world_host.add_child(market_signs)
	# TODO: fixed HUD position, do not attach it.
	pollution_mark = Sprite2D.new()
	pollution_mark.texture = p_ui_assets.tex("res://resources/ui/pollution_throng.png")
	pollution_mark.visible = false
	pollution_mark.z_index = 7
	pollution_mark.scale = Vector2(0.28, 0.28)
	world_host.add_child(pollution_mark)
	pollution_bld = Sprite2D.new()
	pollution_bld.texture = p_ui_assets.tex("res://resources/ui/pollution_building.png")
	pollution_bld.visible = false
	pollution_bld.z_index = 7
	pollution_bld.scale = Vector2(0.35, 0.35)
	world_host.add_child(pollution_bld)
	ensure_factory_slice_texs()

## Creates speech bubbles, capacity labels, and ring dashes.
func build_marks() -> void:
	for _i in 3:
		var panel := PanelContainer.new()
		panel.visible = false
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 8
		panel.clip_contents = true
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_theme_stylebox_override("panel", host.ui_assets.speech_bubble_style())

		var hold := CenterContainer.new()
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.clip_contents = true
		panel.add_child(hold)

		var glyph := TextureRect.new()
		glyph.custom_minimum_size = Vector2(16, 16)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hold.add_child(glyph)

		var said := Label.new()
		said.visible = false
		said.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble_labels.append(said)
		host.add_child(panel)
		bubble_panels.append(panel)
		bubble_icons.append(glyph)

		var tail := TextureRect.new()
		tail.visible = false
		bubble_tails.append(tail)
	for _i in 24:
		var label := Label.new()
		label.theme = host.ui_theme
		label.text = "0/4"
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 8
		label.add_theme_color_override("font_color", Color.WHITE)
		host.add_child(label)
		full_labels.append(label)
	build_capacity_bars(24)
	for _i in 12:
		var dash := Line2D.new()
		dash.width = 1.5
		dash.default_color = Color(1, 1, 1, 0.9)
		dash.z_index = 5
		dash.visible = false
		host.add_child(dash)
		ring_lines.append(dash)


## Fullscreen glitch shader overlay on the HUD root.
func build_glitch(root: Control) -> void:
	host.glitch_overlay = ColorRect.new()
	host.glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.glitch_overlay.visible = false
	host.glitch_overlay.z_index = 31
	var shader := load("res://resources/ui/fullscreen_glitch.gdshader") as Shader
	if shader != null:
		host.glitch_mat = ShaderMaterial.new()
		host.glitch_mat.shader = shader
		host.glitch_overlay.material = host.glitch_mat
	root.add_child(host.glitch_overlay)


## Turns off all world overlay widgets.
func hide_marks() -> void:
	for panel in bubble_panels:
		panel.visible = false
	for tail in bubble_tails:
		tail.visible = false
	for label in full_labels:
		label.visible = false
	for track in cap_tracks:
		track.visible = false
	for fill in cap_fills:
		fill.visible = false
	for line in ring_lines:
		line.visible = false
	hide_factory_marks()


## Updates bubbles, rings, factory marks, and alerts.
func sync_marks() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var view: Rect2 = host.cam_rig.world_view()
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
		var throng_id := int(bark.get("id", -1))
		# Prefer live feet: gaze teleport moves pos_* while bark.x/y can lag while frozen.
		var at := Vector2(float(bark.x), float(bark.y))
		var tip_lift := 14.0
		if throng_id >= 0 and throng_id < sim.slot_count and sim.state[throng_id] == Catalog.ST_LIVING:
			if on_throng_hidden_indoors.call(sim, throng_id):
				panel.visible = false
				tail.visible = false
				if i < bubble_labels.size():
					bubble_labels[i].visible = false
				continue
			at = Vector2(sim.pos_x[throng_id], sim.pos_y[throng_id])
		if not view.has_point(at):
			panel.visible = false
			tail.visible = false
			continue
		var said: Label = bubble_labels[i]
		var icon := int(bark.get("icon", -1))
		if icon < 0:
			panel.visible = false
			tail.visible = false
			said.visible = false
			continue
		said.visible = false
		tail.visible = false
		glyph.custom_minimum_size = Vector2(16, 16)
		glyph.size = Vector2(16, 16)
		var icon_changed := int(glyph.get_meta("bark_icon", -999)) != icon
		if icon_changed:
			glyph.texture = bark_icon(icon)
			glyph.set_meta("bark_icon", icon)
		glyph.visible = true
		var frame := int(host.anim_time * 1000.0 / 160.0 + int(bark.get("id", 0))) % 5
		var frame_changed := int(panel.get_meta("bark_frame", -1)) != frame
		if frame_changed:
			host.ui_assets.apply_bubble_frame(panel, frame)
			panel.set_meta("bark_frame", frame)
		var size: Vector2
		if icon_changed or frame_changed or not panel.has_meta("bark_size"):
			panel.reset_size()
			size = panel.get_combined_minimum_size()
			# Keep near native Unity frame size so the hooked pico is not 9-slice-stretched.
			size.x = maxf(size.x, 38.0)
			size.y = maxf(size.y, 40.0)
			panel.size = size
			panel.set_meta("bark_size", size)
		else:
			size = panel.get_meta("bark_size") as Vector2
		var tip: Vector2 = host.cam_rig.to_iso(at) + Vector2(0, -tip_lift)
		panel.position = Vector2(tip.x - size.x * 0.5, tip.y - size.y)
		panel.visible = true
	sync_capacity_marks(sim, view)
	var bld: Dictionary = sim.building_by_id.get(host.selected_bld, {})
	var show_ring := not bld.is_empty() and not bool(bld.get("dead", true))
	if show_ring:
		var size := Catalog.footprint_for_building(int(bld.kind))
		var center := Vector2(float(bld.x), float(bld.y)) + Catalog.footprint_center(size)
		var reach := Catalog.building_reach(int(bld.kind))
		var pts: PackedVector2Array = on_iso_ellipse_points.call(center, reach.x, reach.y, 24)
		for i in ring_lines.size():
			var dash: Line2D = ring_lines[i]
			dash.points = PackedVector2Array([pts[i * 2], pts[i * 2 + 1]])
			dash.visible = true
	else:
		for line in ring_lines:
			line.visible = false
	sync_factory_mark(sim)
	sync_building_alert(sim)


## Preallocates nine-patch capacity gauge widgets.
func build_capacity_bars(n: int) -> void:
	var gauge_tex: Texture2D = host.ui_assets.tex_rgba("res://resources/ui/tooltip_gauge.png")
	cap_tracks.clear()
	cap_fills.clear()
	for _i in n:
		var track := NinePatchRect.new()
		track.texture = gauge_tex
		track.patch_margin_left = 4
		track.patch_margin_right = 4
		track.size = Vector2(52, 10)
		track.visible = false
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.z_index = 7
		track.modulate = Color(0.15, 0.15, 0.18, 0.92)
		host.add_child(track)
		cap_tracks.append(track)
		var fill := NinePatchRect.new()
		fill.texture = gauge_tex
		fill.patch_margin_left = 4
		fill.patch_margin_right = 4
		fill.size = Vector2(52, 10)
		fill.visible = false
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.z_index = 8
		host.add_child(fill)
		cap_fills.append(fill)


## Positions capacity bars and full labels on buildings.
func sync_capacity_marks(sim: ThrongletSim, view: Rect2) -> void:
	var full_n := 0
	var bar_n := 0
	const BAR_W := 52.0
	const BAR_H := 10.0
	for b in sim.buildings:
		if b.dead:
			continue
		if not sim.has_method("capacity_info"):
			continue
		var info: Dictionary = sim.capacity_info(b)
		if info.is_empty():
			continue
		var origin := Vector2(float(b.x), float(b.y))
		if not sim.chunk_shown(sim.chunk_key_at(origin.x, origin.y)):
			continue
		var kind := int(b.kind)
		var visit := bool(info.get("visit", false))
		var mine := bool(info.get("mine", false))
		var cap := maxi(1, int(info.cap))
		var n := clampi(int(info.n), 0, cap)
		var full := bool(info.full)
		# Anchor on the drawn sprite (roof/pad), not the footprint corner.
		var mark_world: Vector2 = on_building_draw_at.call(kind, origin)
		if visit and n > 0 and Catalog.building_has_active(kind):
			mark_world = on_building_active_draw_at.call(kind, origin)
		if not (view.has_point(origin) or view.has_point(mark_world)):
			continue
		# Houses/theatre need more lift so the bar sits over the chimney like the video.
		var screen_lift := 56.0 if visit else 30.0
		var screen: Vector2 = host.cam_rig.to_iso(mark_world) + Vector2(0, -screen_lift)
		# Same gauge for mines and visit homes/theatre (fill level); LLENO only when full.
		var show_bar := mine or visit
		if show_bar and bar_n < cap_tracks.size():
			var track: NinePatchRect = cap_tracks[bar_n]
			var fill: NinePatchRect = cap_fills[bar_n]
			track.position = screen + Vector2(-BAR_W * 0.5, -6.0)
			track.size = Vector2(BAR_W, BAR_H)
			track.visible = true
			var amount := float(n) / float(cap)
			var width := BAR_W * amount
			if amount > 0.0:
				width = maxf(width, 10.0)
			fill.position = track.position
			fill.size = Vector2(width, BAR_H)
			fill.visible = amount >= 0.02
			fill.modulate = Color(0.95, 0.28, 0.28) if full else Color(91.0 / 255.0, 198.0 / 255.0, 230.0 / 255.0)
			bar_n += 1
		var cap_text: String = sim.occupancy_text(b)
		if cap_text != "" and full_n < full_labels.size():
			var label: Label = full_labels[full_n]
			label.visible = true
			label.text = cap_text
			label.position = screen + Vector2(-18, -22.0 if show_bar else -8.0)
			full_n += 1
	for i in range(bar_n, cap_tracks.size()):
		cap_tracks[i].visible = false
		cap_fills[i].visible = false
	for i in range(full_n, full_labels.size()):
		full_labels[i].visible = false


## Slices factory pie texture into wedge textures.
func ensure_factory_slice_texs() -> void:
	if not _factory_slice_texs.is_empty():
		return
	var src: Texture2D = host.ui_assets.tex("res://resources/ui/factory_slice.png")
	if src == null:
		return
	var img: Image = src.get_image()
	if img == null:
		return
	img = img.duplicate()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var count := ThrongletSimServer.FACTORY_WEDGES
	var parts: Array[Image] = []
	for _i in count:
		parts.append(Image.create(w, h, false, Image.FORMAT_RGBA8))
	var cx := (float(w) - 1.0) * 0.5
	var cy := (float(h) - 1.0) * 0.5
	var step := 360.0 / float(count)
	for y in h:
		for x in w:
			var px: Color = img.get_pixel(x, y)
			if px.a <= 0.05:
				continue
			var deg := rad_to_deg(atan2(float(x) - cx, -(float(y) - cy)))
			if deg < 0.0:
				deg += 360.0
			var sector := int((deg + step * 0.5) / step) % count
			parts[sector].set_pixel(x, y, px)
	for part in parts:
		_factory_slice_texs.append(ImageTexture.create_from_image(part))


## Spawns one factory frame and wedge sprite set.
func make_factory_mark() -> Dictionary:
	ensure_factory_slice_texs()
	var fill_scale := 0.55 * (19.0 / 16.87)
	var frame := Sprite2D.new()
	frame.texture = host.ui_assets.tex("res://resources/ui/factory_frame.png")
	frame.visible = false
	frame.z_index = 6
	frame.scale = Vector2(0.55, 0.55)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.add_child(frame)
	var slices: Array[Sprite2D] = []
	for tex in _factory_slice_texs:
		var slice := Sprite2D.new()
		slice.texture = tex
		slice.visible = false
		slice.z_index = 6
		slice.scale = Vector2(fill_scale, fill_scale)
		slice.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.add_child(slice)
		slices.append(slice)
	return {"frame": frame, "slices": slices, "id": -1}


## Hides all factory progress overlays.
func hide_factory_marks() -> void:
	factory_slices = []
	for mark in factory_marks:
		var frame: Sprite2D = mark.frame
		frame.visible = false
		mark.id = -1
		for slice in mark.slices:
			(slice as Sprite2D).visible = false


## Updates factory wedge fill from process progress.
func sync_factory_mark(sim: ThrongletSim) -> void:
	ensure_factory_slice_texs()
	var view: Rect2 = host.cam_rig.world_view()
	var cull_view: bool = view.size.x > 1.0 and view.size.y > 1.0
	var used := 0
	factory_slices = []
	for b in sim.buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		if kind != Catalog.BLD_FACTORY and kind != Catalog.BLD_FACTORY2:
			continue
		# Every factory shows its own frame; wedges fill with process time.
		var at_world := Vector2(float(b.x), float(b.y))
		if not sim.chunk_shown(sim.chunk_key_at(at_world.x, at_world.y)):
			continue
		if cull_view and not view.has_point(at_world):
			continue
		while factory_marks.size() <= used:
			factory_marks.append(make_factory_mark())
		var mark: Dictionary = factory_marks[used]
		var frame: Sprite2D = mark.frame
		var slices: Array = mark.slices
		var progress := 0.0
		if sim.has_method("factory_process_progress"):
			progress = float(sim.factory_process_progress(b))
		var filled := clampi(
			int(floor(progress * float(ThrongletSimServer.FACTORY_WEDGES) + 0.001)),
			0,
			ThrongletSimServer.FACTORY_WEDGES
		)
		var at: Vector2 = host.cam_rig.to_iso(at_world) + Vector2(0, -28)
		frame.position = at
		frame.visible = true
		mark.id = int(b.id)
		for i in slices.size():
			var slice: Sprite2D = slices[i]
			slice.position = at
			slice.visible = i < filled
		if factory_slices.is_empty():
			factory_slices = slices
		used += 1
	for i in range(used, factory_marks.size()):
		var spare: Dictionary = factory_marks[i]
		(spare.frame as Sprite2D).visible = false
		spare.id = -1
		for slice in spare.slices:
			(slice as Sprite2D).visible = false


## Shows pollution icon on a polluted building.
func sync_building_alert(sim: ThrongletSim) -> void:
	if pollution_bld == null:
		return
	var found := false
	for b in sim.buildings:
		if b.dead:
			continue
		if not sim.building_is_polluted(b):
			continue
		pollution_bld.position = host.cam_rig.to_iso(Vector2(float(b.x), float(b.y))) + Vector2(0, -36)
		pollution_bld.visible = true
		found = true
		break
	if not found:
		pollution_bld.visible = false


## Steps glitch timer and shader intensity.
func sync_glitch(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.glitch_t > 0.0:
		sim.glitch_t = maxf(0.0, sim.glitch_t - delta)
	var on: bool = sim.glitch_t > 0.0
	if host.glitch_overlay != null:
		host.glitch_overlay.visible = on
		if on and host.glitch_mat != null:
			host.glitch_mat.set_shader_parameter("intensity", clampf(sim.glitch_t / 1.4, 0.35, 1.0))


## Agent task list panel on the HUD root.
func build_task_panel(root: Control) -> void:
	agent_task_rows.clear()
	agent_task_panel = PanelContainer.new()
	agent_task_panel.visible = false
	agent_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agent_task_panel.z_index = 18
	agent_task_panel.custom_minimum_size = Vector2(188, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.1, 0.82)
	style.border_color = Color(0.35, 0.85, 1.0, 0.9)
	style.set_border_width_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	agent_task_panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.name = "body"
	body.add_theme_constant_override("separation", 3)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agent_task_panel.add_child(body)
	agent_task_title = Label.new()
	agent_task_title.text = "TAREAS"
	agent_task_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agent_task_title.add_theme_font_size_override("font_size", 14)
	agent_task_title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	agent_task_title.add_theme_color_override("font_outline_color", Color.BLACK)
	agent_task_title.add_theme_constant_override("outline_size", 2)
	body.add_child(agent_task_title)
	root.add_child(agent_task_panel)


## Selected thronglet needs tooltip card.
func build_need_card(root: Control) -> void:
	host.need_fills.clear()
	const GRID_W := 210.0
	const GRID_H := 108.0
	const PAD := 7.0
	const TOP := 25.0
	const CARD_W := GRID_W + PAD * 2.0
	const CARD_H := GRID_H + TOP + PAD
	const COL_SPLIT := 105.0
	const ROW_H := GRID_H / 3.0
	const GAUGE_W := 72.0
	const GAUGE_H := 12.0
	const ICON := 52.0
	const CARD_SCALE := 0.75
	host.need_card = Control.new()
	host.need_card.visible = false
	host.need_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.need_card.z_index = 18
	host.need_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.need_card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	host.need_card.size = Vector2(CARD_W, CARD_H)
	host.need_card.scale = Vector2(CARD_SCALE, CARD_SCALE)
	host.need_card.set_meta("card_scale", CARD_SCALE)
	root.add_child(host.need_card)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxTexture.new()
	style.texture = host.ui_assets.tex("res://resources/ui/tooltip_panel.png")
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", style)
	host.need_card.add_child(panel)
	const LINE := 2.0
	const LINE_COLOR := Color(255.0 / 255.0, 203.0 / 255.0, 0.0)
	var vline := ColorRect.new()
	vline.color = LINE_COLOR
	vline.position = Vector2(PAD + COL_SPLIT - LINE * 0.5, TOP)
	vline.size = Vector2(LINE, GRID_H)
	vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.need_card.add_child(vline)
	for r in 2:
		var hline := ColorRect.new()
		hline.color = LINE_COLOR
		hline.position = Vector2(PAD, TOP + ROW_H * float(r + 1) - LINE * 0.5)
		hline.size = Vector2(GRID_W, LINE)
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.need_card.add_child(hline)
	var names := ["ALIMENTADO", "ENTRETENIDO", "ASEADO"]
	var font: Font = host.ui_assets.ui_font()
	var gauge_tex: Texture2D = host.ui_assets.tex_rgba("res://resources/ui/tooltip_gauge.png")
	var right_w := GRID_W - COL_SPLIT
	var gauge_x := PAD + COL_SPLIT + (right_w - GAUGE_W) * 0.5
	for i in 3:
		var row_y := TOP + ROW_H * float(i)
		var tag := Label.new()
		tag.text = names[i]
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.position = Vector2(PAD, row_y)
		tag.size = Vector2(COL_SPLIT, ROW_H)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if font != null:
			tag.add_theme_font_override("font", font)
		tag.add_theme_font_size_override("font_size", 16)
		tag.add_theme_constant_override("line_spacing", -6)
		tag.add_theme_color_override("font_color", Color(0.06, 0.06, 0.08))
		host.need_card.add_child(tag)
		var gauge_y := row_y + (ROW_H - GAUGE_H) * 0.5
		var track := NinePatchRect.new()
		track.texture = gauge_tex
		track.patch_margin_left = 4
		track.patch_margin_right = 4
		track.position = Vector2(gauge_x, gauge_y)
		track.size = Vector2(GAUGE_W, GAUGE_H)
		track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.modulate = Color(0.62, 0.62, 0.64)
		host.need_card.add_child(track)
		var fill := NinePatchRect.new()
		fill.texture = gauge_tex
		fill.patch_margin_left = 4
		fill.patch_margin_right = 4
		fill.position = Vector2(gauge_x, gauge_y)
		fill.size = Vector2(0.0, GAUGE_H)
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.visible = false
		fill.modulate = Color(91.0 / 255.0, 198.0 / 255.0, 230.0 / 255.0)
		fill.set_meta("gauge_w", GAUGE_W)
		host.need_card.add_child(fill)
		host.need_fills.append(fill)
	host.need_icon = TextureRect.new()
	host.need_icon.texture = host.ui_assets.tex("res://resources/ui/tooltip_info.png")
	host.need_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.need_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.need_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.need_icon.size = Vector2(ICON, ICON)
	host.need_icon.position = Vector2((CARD_W - ICON) * 0.5, -ICON * 0.5)
	host.need_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.need_card.add_child(host.need_icon)


## Fills need gauges and pollution throng marker.
func sync_need_bars() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var show: bool = host.selected >= 0 and host.selected < sim.slot_count and sim.state[host.selected] != Catalog.ST_VACANT
	host.need_show = show
	if host.need_card != null:
		host.need_card.visible = show
	if not show:
		if pollution_mark != null:
			pollution_mark.visible = false
		return
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	var card_scale: float = float(host.need_card.get_meta("card_scale", 1.0))
	var card_size: Vector2 = host.need_card.size * card_scale
	if card_size.x < 1.0:
		card_size = host.need_card.get_combined_minimum_size() * card_scale
	var icon_over := 0.0
	if host.need_icon != null:
		icon_over = maxf(0.0, -host.need_icon.position.y) * card_scale
	const HUD_LEFT := 36.0
	host.need_card.position = Vector2(HUD_LEFT, (view.y - card_size.y) * 0.5 + icon_over * 0.35)
	var amounts := [sim.fed[host.selected], sim.amused[host.selected], sim.clean[host.selected]]
	for i in 3:
		var fill: NinePatchRect = host.need_fills[i]
		var amount: float = clampf(amounts[i] / 100.0, 0.0, 1.0)
		var gauge_w: float = float(fill.get_meta("gauge_w"))
		var width := gauge_w * amount
		# Keep enough width for the 9-patch caps so a low need reads as a stub, not a dot.
		if amount > 0.0:
			width = maxf(width, 10.0)
		fill.size = Vector2(width, fill.size.y)
		fill.visible = amount >= 0.02
		# Original: cyan gauges; low needs tip red (video 68:00).
		if amounts[i] < 35.0:
			fill.modulate = Color(0.95, 0.28, 0.28)
		else:
			fill.modulate = Color(91.0 / 255.0, 198.0 / 255.0, 230.0 / 255.0)
	if pollution_mark != null:
		var origin: Vector2 = host.cam_rig.to_iso(Vector2(sim.pos_x[host.selected], sim.pos_y[host.selected]))
		var dirty := sim.state[host.selected] == Catalog.ST_LIVING and sim.clean[host.selected] < 40.0
		pollution_mark.visible = dirty
		pollution_mark.position = origin + Vector2(-24, -28)


## AtlasTexture slice from the structures tileset.
func atlas_icon(icon: int) -> AtlasTexture:
	if _atlas_tex_cache.has(icon):
		return _atlas_tex_cache[icon]
	var atlas := AtlasTexture.new()
	atlas.atlas = host.ui_assets.tex("res://resources/structures/structures_tileset.png")
	var col := icon % Catalog.ATLAS_COLUMNS
	var row := int(icon / Catalog.ATLAS_COLUMNS)
	atlas.region = Rect2(col * 16, row * 16, 16, 16)
	_atlas_tex_cache[icon] = atlas
	return atlas


## Texture for a speech-bubble glyph icon.
func bark_icon(icon: int) -> Texture2D:
	if _bark_tex_cache.has(icon):
		return _bark_tex_cache[icon]
	var tex: Texture2D
	if not Catalog.BARK_ICON_RECT.has(icon):
		tex = atlas_icon(icon)
	else:
		# Load source pixels once so CompressedTexture2D.get_image() is not required.
		if _bark_atlas_img == null or _bark_atlas_img.is_empty():
			var path := ProjectSettings.globalize_path(Catalog.BARK_ICON_ATLAS)
			_bark_atlas_img = Image.load_from_file(path)
		if _bark_atlas_img == null or _bark_atlas_img.is_empty():
			var atlas := AtlasTexture.new()
			atlas.atlas = host.ui_assets.tex(Catalog.BARK_ICON_ATLAS)
			atlas.region = Catalog.BARK_ICON_RECT[icon]
			tex = atlas
		else:
			var region: Rect2 = Catalog.BARK_ICON_RECT[icon]
			var crop := _bark_atlas_img.get_region(Rect2i(region))
			const BARK_GLYPH := 16
			crop.resize(BARK_GLYPH, BARK_GLYPH, Image.INTERPOLATE_NEAREST)
			tex = ImageTexture.create_from_image(crop)
	_bark_tex_cache[icon] = tex
	return tex


## Whether the market can sell something new.
func market_has_stock(sim: ThrongletSim) -> bool:
	if not sim.has_building_kind(Catalog.BLD_MARKET):
		return false
	for key in Catalog.MARKET.keys():
		var row: Dictionary = Catalog.MARKET[key]
		if not bool(sim.unlocks.get(str(key), false)) and sim.gems >= int(row.cost):
			return true
	return false


## New-item signs above market buildings.
func sync_market_sign(sim: ThrongletSim) -> void:
	if market_signs == null:
		return
	var show := market_has_stock(sim)
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
				sprite.texture = host.ui_assets.tex("res://resources/ui/new_item.png")
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.scale = Vector2(0.45, 0.45)
				market_signs.add_child(sprite)
			sprite.position = host.cam_rig.to_iso(Vector2(float(b.x), float(b.y))) + Vector2(8, -46)
			sprite.visible = true
			n += 1
	for i in range(n, market_signs.get_child_count()):
		market_signs.get_child(i).visible = false
