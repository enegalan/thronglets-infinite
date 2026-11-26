extends RefCounted
class_name PlacementOverlay

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const DashArea := preload("res://scripts/presentation/overlays/dash_area.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")

## Main scene node that owns tilemap, tools, and overlay child nodes.
var host: Node2D
## Camera used to project world footprints and tool radii into iso space.
var cam_rig: CameraRig
## Maximum hitbox debug marks drawn per frame to bound overlay cost.
const HITBOX_MARK_CAP := 900
## Parent node for green/red placement footprint diamonds.
var place_marks: Node2D
## Filled iso cells tinting valid or invalid placement spots.
var place_fills: Array[Polygon2D] = []
## Outlines drawn around each active placement cell.
var place_edges: Array[Line2D] = []
## Parent node for collision and sprite-alignment debug shapes.
var hitbox_marks: Node2D
## Semi-transparent fills for feature, building, and throng hitboxes.
var hitbox_fills: Array[Polygon2D] = []
## Edges outlining each visible debug hitbox cell.
var hitbox_edges: Array[Line2D] = []
## Iso polyline showing the selected thronglet’s planned path.
var agent_path_line: Line2D
## Screen-space panel listing AI task priorities for the selected throng.
var agent_task_panel: PanelContainer
## Header label on the agent debug task panel.
var agent_task_title: Label
## One label per row in the agent task priority list.
var agent_task_rows: Array[Label] = []
## Arc drawn while a charge tool fills toward release.
var charge_ring: Line2D
## Dashed loop previewing radius tools (pick, mop, swarm, etc.).
var charge_area: Node2D
## 0–1 ease-in scale when the area preview first appears for a tool.
var charge_area_anim := 1.0
## Last preview tool id so area animation resets on tool change.
var charge_area_key := ""
## Host hook mapping a feature kind to its sprite draw point for yellow debug.
var on_feature_draw_at: Callable
## Host hook returning which tool is currently charging, if any.
var on_charge_tool_id: Callable
## Host hook deciding whether grid-snapped placement diamonds should show.
var on_want_place_grid: Callable
## Host hook true when drops and tools should affect the island, not UI chrome.
var on_drop_on_island: Callable

## Wires the world host and camera rig used to project overlays.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host
	cam_rig = p_cam_rig

## Spawns placement, hitbox, path, and charge overlay nodes on [param world_host].
func attach_world_nodes(world_host: Node2D) -> void:
	place_marks = Node2D.new()
	place_marks.z_index = 1
	world_host.add_child(place_marks)
	hitbox_marks = Node2D.new()
	hitbox_marks.z_index = 5
	world_host.add_child(hitbox_marks)
	agent_path_line = Line2D.new()
	agent_path_line.z_index = 6
	agent_path_line.width = 2.5
	agent_path_line.default_color = Color(0.15, 0.95, 1.0, 0.95)
	agent_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	agent_path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	agent_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	agent_path_line.visible = false
	world_host.add_child(agent_path_line)
	charge_area = DashArea.new()
	charge_area.z_index = 3
	charge_area.visible = false
	world_host.add_child(charge_area)
	charge_ring = Line2D.new()
	charge_ring.z_index = 4
	charge_ring.width = 3.0
	charge_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	charge_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	charge_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	charge_ring.visible = false
	world_host.add_child(charge_ring)

## Returns the diamond polygon for one iso placement cell.
func place_cell_poly() -> PackedVector2Array:
	var tile := Vector2(host.tilemap.tile_set.tile_size)
	return PackedVector2Array([
		Vector2(0.0, -tile.y * 0.5),
		Vector2(tile.x * 0.5, 0.0),
		Vector2(0.0, tile.y * 0.5),
		Vector2(-tile.x * 0.5, 0.0),
	])


## Resolves building or rock kind for the current place/drag target.
func place_footprint_kind() -> Dictionary:
	var sim: ThrongletSim = ThrongletSimServer
	if host.placing >= 0:
		return {"building": true, "kind": host.placing}
	if sim.held_kind == "building":
		var b = sim.building_by_id.get(sim.held_ref, {})
		if not b.is_empty():
			return {"building": true, "kind": int(b.kind)}
	if sim.held_kind == "rock":
		var feat = sim.feature_by_id.get(sim.held_ref, {})
		if not feat.is_empty():
			return {"building": false, "kind": int(feat.kind)}
	return {"building": true, "kind": -1}


## Allocates up to [param n] placement fill and edge nodes.
func ensure_place_marks(n: int) -> void:
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


## Hides all placement footprint overlays.
func hide_place_marks() -> void:
	for fill in place_fills:
		fill.visible = false
	for edge in place_edges:
		edge.visible = false


## Allocates up to [param n] hitbox debug fill and edge nodes.
func ensure_hitbox_marks(n: int) -> void:
	while hitbox_fills.size() < n:
		var fill := Polygon2D.new()
		fill.z_index = 5
		hitbox_marks.add_child(fill)
		hitbox_fills.append(fill)
		var edge := Line2D.new()
		edge.z_index = 5
		edge.width = 1.5
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		hitbox_marks.add_child(edge)
		hitbox_edges.append(edge)


## Hides all hitbox debug overlays.
func hide_hitboxes() -> void:
	if hitbox_marks == null:
		return
	for fill in hitbox_fills:
		fill.visible = false
	for edge in hitbox_edges:
		edge.visible = false


## Hides agent path line and task panel.
func hide_agent_debug() -> void:
	if agent_path_line != null:
		agent_path_line.visible = false
	if agent_task_panel != null:
		agent_task_panel.visible = false


## Ensures the task panel has [param n] label rows.
func ensure_task_rows(n: int) -> void:
	while agent_task_rows.size() < n:
		var row := Label.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
		row.add_theme_color_override("font_outline_color", Color.BLACK)
		row.add_theme_constant_override("outline_size", 2)
		agent_task_panel.get_node("body").add_child(row)
		agent_task_rows.append(row)


## Updates path and task UI for the selected thronglet.
func sync_agent_debug() -> void:
	if agent_path_line == null or agent_task_panel == null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	var show: bool = host.prefs.show_hitboxes and not host.in_title \
		and host.selected >= 0 and host.selected < sim.slot_count and sim.state[host.selected] != Catalog.ST_VACANT
	if not show:
		hide_agent_debug()
		return
	var world_pts := sim.agent_tick.debug_agent_path(host.selected)
	if world_pts.size() < 2:
		agent_path_line.visible = false
	else:
		var iso_pts := PackedVector2Array()
		for p in world_pts:
			iso_pts.append(host.cam_rig.to_iso(p))
		agent_path_line.points = iso_pts
		agent_path_line.visible = true
	var tasks: Array = sim.agent_tick.debug_agent_tasks(host.selected)
	ensure_task_rows(tasks.size())
	agent_task_title.text = "TAREAS #%d" % host.selected
	for i in agent_task_rows.size():
		if i >= tasks.size():
			agent_task_rows[i].visible = false
			continue
		var task: Dictionary = tasks[i]
		var mark := ">" if bool(task.active) else " "
		agent_task_rows[i].text = "%s %-11s %6.1f" % [mark, str(task.label), float(task.priority)]
		agent_task_rows[i].add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.35) if bool(task.active) else Color(0.85, 0.88, 0.95)
		)
		agent_task_rows[i].visible = true
	agent_task_panel.reset_size()
	var panel_size := agent_task_panel.get_combined_minimum_size()
	agent_task_panel.size = panel_size
	var view: Vector2 = host.get_viewport().get_visible_rect().size
	agent_task_panel.position = Vector2(view.x - panel_size.x - 24.0, 72.0)
	agent_task_panel.visible = true


## Appends one hitbox mark unless the cap is reached.
func hitbox_push(marks: Array, pos: Vector2, fill_c: Color, edge_c: Color, scale: float = 1.0) -> void:
	if marks.size() >= HITBOX_MARK_CAP:
		return
	marks.append({"pos": pos, "fill": fill_c, "edge": edge_c, "scale": scale})


## Rebuilds visible hitbox overlays for features, buildings, and thronglets.
func sync_hitboxes() -> void:
	if hitbox_marks == null:
		return
	if not host.prefs.show_hitboxes or host.in_title:
		hide_hitboxes()
		return
	var sim: ThrongletSim = ThrongletSimServer
	var view: Rect2 = host.cam_rig.world_view().grow(32.0)
	var marks: Array = []
	var poly := place_cell_poly()
	for feat in sim.features:
		if feat.dead:
			continue
		var kind := int(feat.kind)
		if not Catalog.feature_blocks(kind):
			continue
		var origin := Vector2(float(feat.x), float(feat.y))
		if not view.has_point(origin):
			continue
		var fill_c := Color(0.15, 0.95, 0.45, 0.4)
		var edge_c := Color(0.55, 1.0, 0.7, 0.95)
		if kind == Catalog.FEAT_TREE:
			pass
		elif kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK:
			fill_c = Color(1.0, 0.55, 0.15, 0.35)
			edge_c = Color(1.0, 0.75, 0.35, 0.95)
		else:
			fill_c = Color(0.85, 0.25, 1.0, 0.35)
			edge_c = Color(0.95, 0.55, 1.0, 0.95)
		for spot in sim.building_sim.footprint_world(kind, origin.x, origin.y, false):
			hitbox_push(marks, host.cam_rig.to_iso(spot), fill_c, edge_c)
		# Yellow outline at sprite draw point — mismatch vs green cell = visual walk-through.
		if kind == Catalog.FEAT_TREE:
			var draw_at: Vector2 = host.cam_rig.to_iso(on_feature_draw_at.call(kind, origin, int(feat.ore)))
			hitbox_push(marks, draw_at, Color(1.0, 0.95, 0.2, 0.12), Color(1.0, 0.9, 0.1, 0.95), 0.55)
	for b in sim.buildings:
		if b.dead or not Catalog.building_blocks(int(b.kind)):
			continue
		var origin := Vector2(float(b.x), float(b.y))
		if not view.has_point(origin):
			continue
		for spot in sim.building_sim.footprint_world(int(b.kind), origin.x, origin.y, true):
			hitbox_push(marks, host.cam_rig.to_iso(spot), Color(0.25, 0.45, 1.0, 0.3), Color(0.55, 0.75, 1.0, 0.9))
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT:
			continue
		var at := Vector2(sim.pos_x[i], sim.pos_y[i])
		if not view.has_point(at):
			continue
		hitbox_push(marks, host.cam_rig.to_iso(at), Color(1.0, 0.2, 0.75, 0.55), Color(1.0, 0.55, 0.9, 1.0), 0.35)
	ensure_hitbox_marks(marks.size())
	for i in hitbox_fills.size():
		if i >= marks.size():
			hitbox_fills[i].visible = false
			hitbox_edges[i].visible = false
			continue
		var mark: Dictionary = marks[i]
		var s := float(mark.scale)
		var scaled := PackedVector2Array()
		for p in poly:
			scaled.append(p * s)
		hitbox_fills[i].polygon = scaled
		hitbox_fills[i].color = mark.fill
		hitbox_fills[i].position = mark.pos
		hitbox_fills[i].visible = true
		hitbox_edges[i].points = scaled + PackedVector2Array([scaled[0]])
		hitbox_edges[i].default_color = mark.edge
		hitbox_edges[i].position = mark.pos
		hitbox_edges[i].visible = true


## Updates placement footprint tint from validity under the cursor.
func sync_place_mark() -> void:
	if place_marks == null:
		return
	if not on_want_place_grid.call():
		hide_place_marks()
		return
	var sim: ThrongletSim = ThrongletSimServer
	var at: Vector2 = host.cam_rig.grid_pointer_world()
	var building_id: int = sim.held_ref if sim.held_kind == "building" else -1
	var ignore_item: int = sim.hand_id
	var info := place_footprint_kind()
	var kind: int = int(info.kind)
	var ok := false
	if not host.kit_drag.is_empty() and str(host.kit_drag.get("type", "")) == "prop":
		var prop := str(host.kit_drag.get("prop", ""))
		var tile := sim.collision._tile_at(at.x, at.y)
		if prop == "water" or prop == "grass":
			ok = tile != Catalog.TILE_VOID and tile != Catalog.TILE_FOG
		elif prop == "thronglet":
			ok = not Catalog.tile_blocks(tile)
		elif prop == "flower":
			ok = sim.player_tools.can_place_building(Catalog.BLD_FLOWER, at.x, at.y)
		else:
			ok = not Catalog.tile_blocks(tile) and sim.world_entities._feature_at(at.x, at.y, 8.0).is_empty()
	elif host.placing >= 0:
		ok = sim.player_tools.can_place_building(host.placing, at.x, at.y)
	elif kind >= 0 and bool(info.building):
		ok = sim.player_tools.spot_ok(at.x, at.y, building_id, ignore_item, kind)
	elif kind >= 0 and not bool(info.building):
		ok = sim.player_tools.can_drop_feature(sim.held_ref, at.x, at.y)
	else:
		ok = sim.player_tools.spot_ok(at.x, at.y, building_id, ignore_item)
	var spots: Array = [at]
	if kind >= 0:
		spots = sim.building_sim.footprint_world(kind, at.x, at.y, bool(info.building))
	ensure_place_marks(spots.size())
	var poly := place_cell_poly()
	var fill_c := Color(0.3, 1.0, 0.5, 0.55) if ok else Color(1.0, 0.25, 0.22, 0.55)
	var edge_c := Color(0.75, 1.0, 0.85, 1.0) if ok else Color(1.0, 0.55, 0.5, 1.0)
	for i in place_fills.size():
		if i >= spots.size():
			place_fills[i].visible = false
			place_edges[i].visible = false
			continue
		var pos: Vector2 = host.cam_rig.to_iso(spots[i])
		place_fills[i].polygon = poly
		place_fills[i].color = fill_c
		place_fills[i].position = pos
		place_fills[i].visible = true
		place_edges[i].points = poly + PackedVector2Array([poly[0]])
		place_edges[i].default_color = edge_c
		place_edges[i].position = pos
		place_edges[i].visible = true


## Draws tool radius, outlines, and charge ring from cursor state.
func sync_charge_mark(delta: float = 0.0) -> void:
	if charge_ring == null or charge_area == null:
		return
	var sim: ThrongletSim = ThrongletSimServer
	var at: Vector2 = host.cam_rig.pointer_world()
	if sim.player_tools.has_scoop() or not on_drop_on_island.call():
		charge_area.visible = false
		charge_area_key = ""
		charge_ring.visible = false
		host.outlined_feat_ids.clear()
		host.outlined_item_ids.clear()
		host.outlined_throng_ids.clear()
		host.outlined_bld_ids.clear()
		return
	var used: int = int(on_charge_tool_id.call())
	var preview_tool: int = used if used >= 0 else host.tool
	var target: Dictionary = {}
	if used >= 0 or preview_tool >= 0:
		target = sim.player_tools.charge_tool_target(preview_tool, at.x, at.y)
	var tx: float = float(target.get("x", at.x)) if not target.is_empty() else at.x
	var ty: float = float(target.get("y", at.y)) if not target.is_empty() else at.y
	var area_r := float(target.get("radius", 0.0)) if not target.is_empty() else 0.0
	# Always show area preview for tools that act in an area.
	match preview_tool:
		Catalog.TOOL_PICK:
			area_r = Catalog.PICK_RADIUS
			tx = at.x
			ty = at.y
		Catalog.TOOL_SAW:
			area_r = Catalog.SAW_RADIUS
			tx = at.x
			ty = at.y
		Catalog.TOOL_MOP:
			area_r = Catalog.MOP_RADIUS
			tx = at.x
			ty = at.y
		Catalog.TOOL_GRAB:
			area_r = Catalog.GRAB_RADIUS
			tx = at.x
			ty = at.y
		Catalog.TOOL_SWARM:
			area_r = Catalog.SWARM_RADIUS
			tx = at.x
			ty = at.y
		Catalog.TOOL_HAMMER:
			# Hammer shows area when smashing ore piles or generally in part_two.
			if area_r <= 0.0 and sim.part_two:
				area_r = Catalog.HAMMER_ORE_RADIUS
				tx = at.x
				ty = at.y
	var center: Vector2 = host.cam_rig.to_iso(Vector2(tx, ty))
	var show_area: bool = preview_tool != Catalog.TOOL_SPONGE and preview_tool >= 0 and area_r > 0.0
	# Area tools outline via radius hits; single-target tools (axe/hammer) via charge target.
	var outline_from_hits: bool = show_area or (preview_tool >= 0 and not target.is_empty())
	host.outlined_feat_ids.clear()
	host.outlined_item_ids.clear()
	host.outlined_throng_ids.clear()
	host.outlined_bld_ids.clear()
	var hits: Array = []
	if outline_from_hits:
		hits = sim.player_tools.area_tool_hits(preview_tool, tx, ty)
		for h in hits:
			var what := str(h.get("what", ""))
			if what == "feat" and h.has("id"):
				host.outlined_feat_ids[int(h.id)] = true
			elif what == "item" and h.has("id"):
				host.outlined_item_ids[int(h.id)] = true
			elif what == "throng" and h.has("id"):
				host.outlined_throng_ids[int(h.id)] = true
			elif what == "bld" and h.has("id"):
				host.outlined_bld_ids[int(h.id)] = true
	if not show_area:
		charge_area.visible = false
		charge_area_key = ""
	else:
		var key := "tool:%d" % preview_tool
		if charge_area_key != key:
			charge_area_key = key
			charge_area_anim = 0.0
		charge_area_anim = minf(1.0, charge_area_anim + delta / 0.16)
		var anim_scale := lerpf(0.9, 1.0, smoothstep(0.0, 1.0, charge_area_anim))
		var affectable := not hits.is_empty()
		var area_color := Color(0.35, 1.0, 0.45, 1.0) if affectable else Color.WHITE
		# Elliptical dashed area preview in world space.
		charge_area.visible = true
		var zoom_scale := 1.0
		if host.cam_rig != null:
			zoom_scale = float(host.cam_rig.zoom_level)
		elif host.camera != null:
			zoom_scale = float(host.camera.zoom.x)
		charge_area.call("set_area", iso_ellipse_points(Vector2(tx, ty), area_r * anim_scale, area_r * 0.82 * anim_scale, 48), area_color, true, zoom_scale)
	# Single-target hover highlight for bug host.tool.
	if preview_tool == Catalog.TOOL_BUG and not sim.player_tools.has_scoop():
		var bug_id := sim.spatial.find_thronglet(at.x, at.y, 14.0, false)
		if bug_id >= 0:
			host.outlined_throng_ids[bug_id] = true
	if used >= 0 and host.tool_charge > 0.02 and (used != Catalog.TOOL_GRAB or int(target.get("n", 0)) > 0):
		charge_ring.points = charge_arc_points(center, 18.0, host.tool_charge)
		charge_ring.default_color = Color(1.0, 0.92, 0.35, 0.95)
		charge_ring.visible = true
	else:
		charge_ring.visible = false


## Builds iso-space points along a world-space ellipse.
func iso_ellipse_points(world_center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not is_finite(world_center.x) or not is_finite(world_center.y):
		return pts
	if not is_finite(rx) or not is_finite(ry) or steps < 2:
		return pts
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		var world := world_center + Vector2(cos(ang) * rx, sin(ang) * ry)
		var iso: Vector2 = host.cam_rig.to_iso(world)
		if is_finite(iso.x) and is_finite(iso.y):
			pts.append(iso)
	return pts


## Iso points for a partial charge ring arc from [param progress].
func charge_arc_points(center_iso: Vector2, radius: float, progress: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var filled := clampf(progress, 0.0, 1.0)
	var steps := maxi(2, int(ceil(28.0 * filled)))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := -PI * 0.5 + TAU * filled * t
		pts.append(center_iso + Vector2(cos(ang), sin(ang)) * radius)
	return pts
