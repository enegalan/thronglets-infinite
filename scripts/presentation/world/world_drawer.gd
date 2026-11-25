extends RefCounted
class_name WorldDrawer

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const WorldBootstrap := preload("res://scripts/presentation/world/world_bootstrap.gd")
const IsoDraw := preload("res://scripts/presentation/world/iso_draw.gd")
const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")

## World-layer host holding multimesh bands, monoliths, and placement ghosts.
var host: Node2D
## Iso draw-at helpers for batched features and overlay pushes.
var iso: IsoDraw
## Bootstrap delegate for quad multimeshes and thronglet shader materials.
var world_boot: WorldBootstrap


## Binds the world host, iso drawer, and bootstrap.
func setup(p_host: Node2D, p_iso: IsoDraw, p_boot: WorldBootstrap) -> void:
	host = p_host
	iso = p_iso
	world_boot = p_boot


## Allocates a world-cell quad multimesh via bootstrap defaults and shader setup.
func mesh(colored: bool, size: Vector2) -> MultiMesh:
	return world_boot.mesh(colored, size)


## Shader material for atlas frames on prop bands.
func material(h_frames: int, v_frames: int) -> ShaderMaterial:
	return world_boot.material(h_frames, v_frames)

## Hides batched static feature multimesh bands.
func clear_feat_static() -> void:
	host._feat_static_active = false
	for band in host._feat_bands:
		if band != null and is_instance_valid(band):
			write_mesh(band.multimesh, [])
			band.visible = false
	if host.feat_static != null:
		host.feat_static.visible = false

## Rebuilds static feature bands when the sim epoch changes.
func ensure_feat_static() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if host.feat_static == null:
		return
	if host._feat_static_active and host._feat_static_epoch == sim.feat_mesh_epoch:
		return
	host._feat_static_epoch = sim.feat_mesh_epoch
	host._feat_static_active = true
	var by_frame := {}
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		var kind := int(feat.kind)
		if not feat_is_batchable(kind):
			continue
		if not sim.chunk_shown(sim._ck(int(feat.cx), int(feat.cy))):
			continue
		var ore := int(feat.ore)
		var origin := Vector2(float(feat.x), float(feat.y))
		var at: Vector2 = host.cam_rig.to_iso(iso.feature_draw_at(kind, origin, ore))
		var sprite_scale := Catalog.feature_sprite_scale(kind, ore)
		var frame: int = host.anim_frames.prop_frame(Catalog.icon_for_feature(kind, ore))
		if not by_frame.has(frame):
			by_frame[frame] = []
		by_frame[frame].append({
			"p": at,
			"icon": frame,
			"tint": Color.WHITE,
			"scale": sprite_scale,
		})
	var frames: Array = by_frame.keys()
	frames.sort()
	while host._feat_bands.size() < frames.size():
		var band := MultiMeshInstance2D.new()
		band.multimesh = mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
		host.feat_static.add_child(band)
		host._feat_bands.append(band)
	for i in host._feat_bands.size():
		var band: MultiMeshInstance2D = host._feat_bands[i]
		if i >= frames.size():
			write_mesh(band.multimesh, [])
			band.visible = false
			continue
		var frame := int(frames[i])
		bind_band_frame(band, frame)
		write_mesh(band.multimesh, by_frame[frame])
		band.visible = true
	host.feat_static.visible = not frames.is_empty()

## Whether a feature kind can live in the static batch.
func feat_is_batchable(kind: int) -> bool:
	# Quiet rooted props. Fire/monolith stay on the dynamic path.
	return kind != Catalog.FEAT_FIRE and kind != Catalog.FEAT_MONOLITH

## Adds distant fire animation and outline overlays.
func push_far_feat_overlays(draws: Array, view: Rect2, time_pre: float) -> void:
	# Far: bodies are in host.feat_static. Only animate fire and outline a few ids.
	var sim: ThrongletSim = ThrongletSimServer
	for feat in sim.fires:
		if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
			continue
		if not sim.chunk_shown(sim._ck(int(feat.cx), int(feat.cy))):
			continue
		var p := Vector2(float(feat.x), float(feat.y))
		var feat_at: Vector2 = iso.feature_draw_at(Catalog.FEAT_FIRE, p, 0)
		if not (view.has_point(p) or view.has_point(feat_at)):
			continue
		var feat_anim: Dictionary = host.anim_frames.feature_anim(Catalog.FEAT_FIRE, time_pre, 0)
		var feat_frame := int(feat_anim.get("frame", -1))
		var feat_scale := Catalog.feature_sprite_scale(Catalog.FEAT_FIRE, 0)
		var feat_off := Vector2.ZERO
		var feat_rot := 0.0
		if feat_frame < 0:
			feat_frame = host.anim_frames.prop_frame(Catalog.icon_for_feature(Catalog.FEAT_FIRE, 0))
		elif not feat_anim.is_empty():
			var feat_tune_id := str(feat_anim.get("id", ""))
			var feat_idx := int(feat_anim.get("idx", 0))
			feat_scale *= AnimTune.frame_scale(feat_tune_id, feat_idx)
			feat_off = AnimTune.frame_offset(feat_tune_id, feat_idx)
			feat_rot = AnimTune.frame_rot(feat_tune_id, feat_idx)
		iso.push_iso(draws, feat_at, feat_frame, Color.WHITE, 0.0, feat_scale, NAN, Color.TRANSPARENT, feat_off, feat_rot)
	var outline_ids: Array = host.outlined_feat_ids.keys()
	if host.tool_charge > 0.02 and str(host.tool_charge_key).begins_with("feat:"):
		outline_ids.append(int(str(host.tool_charge_key).substr(5)))
	for raw_id in outline_ids:
		var fid := int(raw_id)
		var feat = sim.feature_by_id.get(fid, {})
		if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
			continue
		var feat_kind := int(feat.kind)
		if feat_kind == Catalog.FEAT_FIRE or feat_kind == Catalog.FEAT_MONOLITH:
			continue
		if not sim.chunk_shown(sim._ck(int(feat.cx), int(feat.cy))):
			continue
		var p2 := Vector2(float(feat.x), float(feat.y))
		var feat_at2: Vector2 = iso.feature_draw_at(feat_kind, p2, int(feat.ore))
		if not (view.has_point(p2) or view.has_point(feat_at2)):
			continue
		var feat_scale2 := Catalog.feature_sprite_scale(feat_kind, int(feat.ore))
		var feat_frame2: int = host.anim_frames.prop_frame(Catalog.icon_for_feature(feat_kind, int(feat.ore)))
		var feat_sort_y := NAN
		if sim._ore_tier(feat_kind) > 0:
			feat_sort_y = -1000000.0
		iso.push_iso(draws, feat_at2, feat_frame2, Color.WHITE, 0.0, feat_scale2, feat_sort_y, Color(0.35, 1.0, 0.45, 1.0))
	# Keep already-tracked monolith sprites alive; discovery happens in near view.
	for mid in host._monoliths.keys():
		var mfeat = sim.feature_by_id.get(int(mid), {})
		if mfeat.is_empty() or mfeat.dead:
			continue
		var mp := Vector2(float(mfeat.x), float(mfeat.y))
		host.world_actor_sync.sync_monolith(int(mid), mp + Catalog.feature_draw_off(Catalog.FEAT_MONOLITH), mfeat, time_pre)

## Uploads void-back layer multimesh instances.
func write_void_draws(draws: Array) -> void:
	if host.void_back == null:
		return
	host._void_band_cursor = 0
	append_container_frame_runs(host.void_back, host._void_bands, "_void_band_cursor", draws)
	for j in range(host._void_band_cursor, host._void_bands.size()):
		write_mesh(host._void_bands[j].multimesh, [])
		host._void_bands[j].visible = false
	host.void_back.visible = host._void_band_cursor > 0

## Uploads focus-root multimesh instances.
func write_focus_draws(draws: Array) -> void:
	if host.focus_root == null:
		return
	host._focus_band_cursor = 0
	append_container_frame_runs(host.focus_root, host._focus_bands, "_focus_band_cursor", draws)
	for j in range(host._focus_band_cursor, host._focus_bands.size()):
		write_mesh(host._focus_bands[j].multimesh, [])
		host._focus_bands[j].visible = false

## Groups draws by icon into container band runs.
func append_container_frame_runs(root: Node2D, bands: Array, cursor_name: String, draws: Array) -> void:
	if draws.is_empty():
		return
	var run: Array = []
	var run_frame := int(draws[0].icon)
	for d in draws:
		var fr := int(d.icon)
		if fr != run_frame:
			emit_container_run(root, bands, cursor_name, run_frame, run)
			run = []
			run_frame = fr
		run.append(d)
	emit_container_run(root, bands, cursor_name, run_frame, run)

## Allocates one container band and writes a frame run.
func emit_container_run(root: Node2D, bands: Array, cursor_name: String, frame: int, run: Array) -> void:
	if run.is_empty():
		return
	var cursor := int(host.get(cursor_name))
	while bands.size() <= cursor:
		var band := MultiMeshInstance2D.new()
		band.multimesh = mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
		root.add_child(band)
		bands.append(band)
	var band2: MultiMeshInstance2D = bands[cursor]
	host.set(cursor_name, cursor + 1)
	bind_band_frame(band2, frame)
	write_mesh(band2.multimesh, run)
	band2.visible = true

## Sorts sprites and prop bands by draw depth.
func paint_props(draws: Array) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	# meta_only rows carry sort_y for Sprite2D props; never emit them as Multimesh icons.
	if not draws.is_empty():
		var paint: Array = []
		for d in draws:
			if bool(d.get("meta_only", false)):
				continue
			paint.append(d)
		draws = paint
	var live: Array = []
	for id in host._monoliths.keys():
		var node: Node2D = host._monoliths[id]
		if not bool(node.get_meta("seen", false)):
			node.visible = false
			continue
		node.set_meta("seen", false)
		live.append({"sy": node.position.y, "node": node})
	for id in host._building_active_sprites.keys():
		var bnode: Sprite2D = host._building_active_sprites[id]
		if bnode == null or not is_instance_valid(bnode):
			host._building_active_sprites.erase(id)
			continue
		if not bool(bnode.get_meta("seen", false)):
			var b = sim.building_by_id.get(id, {})
			if b.is_empty() or b.dead:
				bnode.queue_free()
				host._building_active_sprites.erase(id)
				continue
			bnode.visible = false
			continue
		bnode.set_meta("seen", false)
		var bsy := float(bnode.get_meta("sy", bnode.position.y))
		live.append({"sy": bsy, "node": bnode})
	if (
		host._place_ghost_sprite != null
		and is_instance_valid(host._place_ghost_sprite)
		and bool(host._place_ghost_sprite.get_meta("seen", false))
	):
		host._place_ghost_sprite.set_meta("seen", false)
		live.append({
			"sy": float(host._place_ghost_sprite.get_meta("sy", host._place_ghost_sprite.position.y)),
			"node": host._place_ghost_sprite,
		})
	host._band_cursor = 0
	var order: Array = []
	if live.is_empty():
		append_frame_runs(order, draws)
	else:
		live.sort_custom(func(a, b): return float(a.sy) < float(b.sy))
		var cursor := 0
		for i in live.size():
			var chunk: Array = []
			var sy := float(live[i].sy)
			while cursor < draws.size() and float(draws[cursor].get("sy", draws[cursor].p.y)) <= sy:
				chunk.append(draws[cursor])
				cursor += 1
			append_frame_runs(order, chunk)
			order.append(live[i].node)
		var rest: Array = []
		while cursor < draws.size():
			rest.append(draws[cursor])
			cursor += 1
		append_frame_runs(order, rest)
	for j in range(host._band_cursor, host._prop_bands.size()):
		write_mesh(host._prop_bands[j].multimesh, [])
		host._prop_bands[j].visible = false
	for i in order.size():
		if host.world_layer.get_child(i) != order[i]:
			host.world_layer.move_child(order[i], i)

## Groups world-layer draws by icon into runs.
func append_frame_runs(order: Array, draws: Array) -> void:
	if draws.is_empty():
		return
	var run: Array = []
	var run_frame := int(draws[0].icon)
	for d in draws:
		var fr := int(d.icon)
		if fr != run_frame:
			emit_prop_run(order, run_frame, run)
			run = []
			run_frame = fr
		run.append(d)
	emit_prop_run(order, run_frame, run)

## Emits one prop multimesh band into the sort order.
func emit_prop_run(order: Array, frame: int, run: Array) -> void:
	if run.is_empty():
		return
	var band := prop_band(host._band_cursor)
	host._band_cursor += 1
	bind_band_frame(band, frame)
	write_mesh(band.multimesh, run)
	band.visible = true
	order.append(band)

## Returns or grows the prop band at index.
func prop_band(index: int) -> MultiMeshInstance2D:
	while host._prop_bands.size() <= index:
		var band := MultiMeshInstance2D.new()
		band.multimesh = mesh(true, Vector2(WorldBootstrap.WORLD_CELL, WorldBootstrap.WORLD_CELL))
		host.world_layer.add_child(band)
		host._prop_bands.append(band)
	return host._prop_bands[index]

## Fills multimesh instances from draw dictionaries.
func write_mesh(mesh: MultiMesh, draws: Array) -> void:
	const OUTLINE_OFFS := [
		Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
	]
	var n := 0
	for d in draws:
		n += 9 if d.has("outline") else 1
	if mesh.instance_count < n:
		mesh.instance_count = maxi(16, n)
	mesh.visible_instance_count = n
	var xf := Transform2D()
	var i := 0
	for d in draws:
		var sprite_scale := float(d.get("scale", 1.0))
		var flip := float(d.get("flip", 1.0))
		var rot := deg_to_rad(float(d.get("rot", 0.0)))
		var center := Vector2(0, -WorldBootstrap.WORLD_CELL * 0.5 * sprite_scale).rotated(rot)
		var icon := int(d.icon)
		# Loose cell textures always sample frame 0; w=1 applies prop tint.
		var apply_tint := 0.0 if (icon < 24 or icon >= 144) else 1.0
		if d.has("outline"):
			var oc: Color = d["outline"]
			for o in OUTLINE_OFFS:
				xf = Transform2D(rot, Vector2(sprite_scale * flip, sprite_scale), 0.0, d.p + o + center)
				mesh.set_instance_transform_2d(i, xf)
				mesh.set_instance_custom_data(i, Color(0.0, 0.0, 1.0, 0.0))
				mesh.set_instance_color(i, oc)
				i += 1
		xf = Transform2D(rot, Vector2(sprite_scale * flip, sprite_scale), 0.0, d.p + center)
		mesh.set_instance_transform_2d(i, xf)
		mesh.set_instance_custom_data(i, Color(0.0, float(d.get("dirty", 0.0)), 0.0, apply_tint))
		mesh.set_instance_color(i, d.tint)
		i += 1

## Loads and caches a world cell texture by frame.
func cell_tex(frame: int) -> Texture2D:
	if host._cell_tex_cache.has(frame):
		return host._cell_tex_cache[frame]
	var path := "res://resources/sprites/world/world_cells/%04d.png" % frame
	var abs_path := ProjectSettings.globalize_path(path)
	var tex: Texture2D = null
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	host._cell_tex_cache[frame] = tex
	return tex

## Loads and caches dirt overlay for a cell frame.
func cell_dirt(frame: int) -> Texture2D:
	if host._cell_dirt_cache.has(frame):
		return host._cell_dirt_cache[frame]
	var path := "res://resources/sprites/world/world_cells_dirt/%04d.png" % frame
	var abs_path := ProjectSettings.globalize_path(path)
	var tex: Texture2D = null
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	host._cell_dirt_cache[frame] = tex
	return tex

## Sets band texture and shader for one cell frame.
func bind_band_frame(band: MultiMeshInstance2D, frame: int) -> void:
	band.texture = cell_tex(frame)
	var mat: ShaderMaterial = band.get_meta("own_mat") if band.has_meta("own_mat") else null
	if mat == null:
		mat = host.world_boot.material(1, 1)
		band.material = mat
		band.set_meta("own_mat", mat)
	mat.set_shader_parameter("h_frames", 1)
	mat.set_shader_parameter("v_frames", 1)
	var dirt := cell_dirt(frame)
	if dirt != null:
		mat.set_shader_parameter("dirt_tex", dirt)
