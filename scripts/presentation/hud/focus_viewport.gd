extends RefCounted
class_name FocusViewport

const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")

## Main host owning focus layers, gaze console, tutorial sign, and anim time.
var host: Node2D
## World camera rig used to center the focus cam on talk or egg subjects.
var cam_rig: CameraRig
## Repaints one terrain chunk into the focus tilemap around the anchor.
var on_paint_chunk: Callable
## Uploads the focus hole draw list to focus multimesh bands.
var on_write_focus_draws: Callable
## Host hook returning iso anchor for a world feature kind.
var on_feature_draw_at: Callable
## Host hook resolving animated feature frames at focus anim time.
var on_feature_anim: Callable
## Host hook mapping catalog icons to multimesh atlas frames.
var on_prop_frame: Callable
## Host hook appending one sorted iso draw dict to a list.
var on_push_iso: Callable
## Host hook for glitch building/tree fume overlays in the focus view.
var on_push_glitch_fumes: Callable
## Host hook for anomaly ray animation in the focus view.
var on_push_anomaly_ray: Callable
## Host hook for ground item draw anchors.
var on_item_draw_at: Callable
## Host hook for egg wobble strip state on focus items.
var on_egg_anim: Callable
## Host hook for ripe apple prop frame selection.
var on_apple_frame: Callable
## Host hook for idle building sprite anchors in the hole.
var on_building_draw_at: Callable
## Host hook for per-throng body clip at focus anim time.
var on_throng_frame: Callable
## Host hook for throng scale and offset from a body frame.
var on_throng_sprite_look: Callable
## Host hook drawing blood pool under corpses visible in focus.
var on_push_corpse_blood: Callable
## Host hook for horizontal flip on throng instances.
var on_throng_flip: Callable
## Host hook encoding cleanliness dirty flag on throng draws.
var on_throng_dirty: Callable
## Repositions gaze log and choice console chrome during talk mode.
var on_layout_console: Callable
## Sets a Control's offsets from a screen Rect2 for dim or frame boxes.
var on_set_box: Callable

## Binds focus overlay state to the main presentation host and camera.
func setup(p_host: Node2D, p_cam_rig: CameraRig) -> void:
	host = p_host
	cam_rig = p_cam_rig

## Drives focus overlay, camera, and sub-viewport draws.
func sync_focus(delta: float) -> void:
	var sim: ThrongletSim = ThrongletSimServer
	if sim.game_over:
		host.focus_on = false
		host.focus_hold = 0.0
		host.focus_dim.visible = false
		host.focus_frame.visible = false
		host.focus_box.visible = false
		host.task_panel.visible = false
		return
	var event = str(sim.modal.get("event", "")) if not sim.modal.is_empty() else ""
	var monolith_reveal = event == "monolith_appear"
	var talk: bool = not sim.modal.is_empty() and Catalog.GAZE.has(event)
	var egg = starter_egg()
	var falling = not egg.is_empty() and float(egg.get("air", 0.0)) > 0.0
	if falling:
		host.focus_hold = 0.45
	elif host.focus_hold > 0.0:
		host.focus_hold = maxf(0.0, host.focus_hold - delta)
	var show_egg: bool = not talk and not egg.is_empty() and (falling or host.focus_hold > 0.0)
	var show: bool = talk or show_egg or sim.tutorial_i >= 0
	var show_focus_overlay = show and not monolith_reveal
	if show and not host.focus_on:
		host.focus_on = true
	if not show and host.focus_on:
		host.focus_on = false
		host.focus_hold = 0.0
	host.focus_dim.visible = show_focus_overlay
	host.focus_frame.visible = show_focus_overlay
	host.focus_box.visible = show_focus_overlay
	host.task_panel.visible = not talk and sim.tutorial_i < 0
	if show_focus_overlay:
		host.focus_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		host.focus_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not show:
		return
	if monolith_reveal:
		var view = host.get_viewport_rect().size
		var console_h = maxf(132.0, round(view.y * 0.34))
		var text = Rect2(Vector2(8.0, view.y - console_h - 4.0), Vector2(view.x - 16.0, console_h))
		on_set_box.call(host.gaze_panel, text)
		on_layout_console.call()
		return
	var frame = focus_frame_rect(talk)
	on_set_box.call(host.focus_frame, frame)
	if host.boot_seq.sign_button != null:
		var signing = sim.tutorial_i >= 0 and not talk
		host.boot_seq.sign_button.visible = signing
		if signing:
			host.boot_seq.sign_button.text = sim.tutorial_line()
			host.boot_seq.sign_button.position = frame.position + Vector2(40, frame.size.y - 98)
			host.boot_seq.sign_button.size = Vector2(frame.size.x - 80, 64)
	var inner = frame.grow(-22.0)
	var hole = inner
	if talk:
		var view = host.get_viewport_rect().size
		var console_h = maxf(132.0, round(view.y * 0.34))
		var text = Rect2(Vector2(8.0, view.y - console_h - 4.0), Vector2(view.x - 16.0, console_h))
		on_set_box.call(host.gaze_panel, text)
		on_layout_console.call()
		hole = Rect2(inner.position, Vector2(inner.size.x, maxf(64.0, text.position.y - inner.position.y)))
	var view_size = host.get_viewport_rect().size
	var uv_pos = hole.position / view_size
	var uv_end = hole.end / view_size
	host.focus_shade.set_shader_parameter("hole", Vector4(uv_pos.x, uv_pos.y, uv_end.x, uv_end.y))
	on_set_box.call(host.focus_box, hole)
	var pix = Vector2i(maxi(int(hole.size.x), 8), maxi(int(hole.size.y), 8))
	if host.focus_port.size != pix:
		host.focus_port.size = pix
	var zoom = 2.7 if talk else 3.4
	var subject = talk_iso() if talk else egg_iso(egg)
	host.focus_cam_node.zoom = Vector2(zoom, zoom)
	host.focus_cam_node.position = subject.snapped(Vector2(1.0 / zoom, 1.0 / zoom))
	var anchor = talk_world() if talk else Vector2(float(egg.x), float(egg.y))
	paint_focus(anchor)
	on_write_focus_draws.call(focus_draws())


## Screen rect for the focus picture frame.
func focus_frame_rect(talk: bool) -> Rect2:
	var view = host.get_viewport_rect().size
	var size = Vector2(500, 340) if talk else Vector2(360, 220)
	var origin = (view - size) * 0.5
	if not talk:
		origin.y = maxf(origin.y, 68.0)
	else:
		origin.y = 8.0
	origin = origin.round()
	size = size.round()
	return Rect2(origin, size)


## Fixed starter egg item dictionary if present.
func starter_egg() -> Dictionary:
	for it in ThrongletSimServer.items:
		if it.dead or int(it.kind) != Catalog.ITEM_EGG:
			continue
		if bool(it.get("fixed", false)):
			return it
	return {}


## Isometric screen point for a falling egg.
func egg_iso(it: Dictionary) -> Vector2:
	var at = host.cam_rig.to_iso(Vector2(float(it.x), float(it.y)))
	at.y -= float(it.get("air", 0.0)) + 8.0
	return at


## Isometric anchor for gaze dialogue crowd.
func talk_iso() -> Vector2:
	var at = host.cam_rig.to_iso(talk_world())
	at.y -= 14.0
	return at


## Average world position of gaze-home thronglets.
func talk_world() -> Vector2:
	var sim: ThrongletSim = ThrongletSimServer
	var sum = Vector2.ZERO
	var n = 0
	for key in sim.gaze_home.keys():
		var i = int(key)
		if i < 0 or i >= sim.slot_count:
			continue
		sum += Vector2(sim.pos_x[i], sim.pos_y[i])
		n += 1
	if n == 0:
		return Vector2(256, 256)
	return sum / float(n)


## Paints terrain chunk into the focus tilemap.
func paint_focus(anchor: Vector2) -> void:
	host.focus_tilemap.clear()
	host.path_overlay.clear_focus_paths()
	var sim: ThrongletSim = ThrongletSimServer
	var key: String = sim.chunk_key_at(anchor.x, anchor.y)
	if sim.chunk_shown(key):
		on_paint_chunk.call(key, false, host.focus_tilemap)


## Whether a world point is inside the focus viewport.
func focus_sees(world_pos: Vector2, lift: float) -> bool:
	var at = host.cam_rig.to_iso(world_pos)
	at.y -= lift
	var half = Vector2(host.focus_port.size) / host.focus_cam_node.zoom * 0.5 + Vector2(40.0, 48.0)
	var delta = at - host.focus_cam_node.position
	return absf(delta.x) <= half.x and absf(delta.y) <= half.y


## Builds y-sorted draw list for the focus hole.
func focus_draws() -> Array:
	var sim: ThrongletSim = ThrongletSimServer
	var talk: bool = not sim.modal.is_empty() and Catalog.GAZE.has(str(sim.modal.event))
	var draws: Array = []
	var egg_front: Array = []
	var time = host.anim_time
	for feat in sim.features:
		if feat.dead or bool(feat.get("lifted", false)):
			continue
		if talk and talk_hides_feat(int(feat.kind)):
			continue
		var p = Vector2(float(feat.x), float(feat.y))
		if int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		var feat_at = on_feature_draw_at.call(int(feat.kind), p, int(feat.ore))
		if not focus_sees(p, 0.0) and not focus_sees(feat_at, 0.0):
			continue
		var feat_anim = on_feature_anim.call(int(feat.kind), time, int(feat.ore))
		var feat_frame = int(feat_anim.get("frame", -1))
		var feat_scale = Catalog.feature_sprite_scale(int(feat.kind), int(feat.ore))
		var feat_off = Vector2.ZERO
		var feat_rot = 0.0
		if feat_frame < 0:
			feat_frame = on_prop_frame.call(Catalog.icon_for_feature(int(feat.kind), int(feat.ore)))
		elif not feat_anim.is_empty():
			var feat_tune_id = str(feat_anim.get("id", ""))
			var feat_idx = int(feat_anim.get("idx", 0))
			feat_scale *= AnimTune.frame_scale(feat_tune_id, feat_idx)
			feat_off = AnimTune.frame_offset(feat_tune_id, feat_idx)
			feat_rot = AnimTune.frame_rot(feat_tune_id, feat_idx)
		var feat_sort_y = NAN
		if sim._ore_tier(int(feat.kind)) > 0:
			feat_sort_y = -1000000.0
		on_push_iso.call(draws, feat_at, feat_frame, Color.WHITE, 0.0, feat_scale, feat_sort_y, Color.TRANSPARENT, feat_off, feat_rot)
		on_push_glitch_fumes.call(draws, int(feat.kind), feat_at, time)
		on_push_anomaly_ray.call(draws, int(feat.kind), feat_at, time)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var lift = float(it.get("air", 0.0))
		var p2 = on_item_draw_at.call(int(it.kind), Vector2(float(it.x), float(it.y)))
		if not focus_sees(p2, lift):
			continue
		var item_frame = on_prop_frame.call(Catalog.icon_for_item(int(it.kind)))
		var item_scale = Catalog.item_sprite_scale(int(it.kind))
		var item_off = Vector2.ZERO
		var item_rot = 0.0
		if int(it.kind) == Catalog.ITEM_EGG:
			var egg = on_egg_anim.call(it)
			var egg_idx = int(egg.get("idx", 0))
			item_frame = int(egg.get("frame", AnimTune.sheet_frame("egg")))
			item_scale = AnimTune.frame_scale("egg", egg_idx)
			item_off = AnimTune.frame_offset("egg", egg_idx)
			item_rot = AnimTune.frame_rot("egg", egg_idx)
			if lift > 0.0:
				on_push_iso.call(egg_front, p2, item_frame, Color.WHITE, lift, item_scale, NAN, Color.TRANSPARENT, item_off, item_rot)
				continue
			on_push_iso.call(draws, p2, item_frame, Color.WHITE, lift, item_scale, NAN, Color.TRANSPARENT, item_off, item_rot)
			continue
		elif int(it.kind) == Catalog.ITEM_APPLE:
			item_frame = on_apple_frame.call(it)
			if lift > 14.0:
				on_push_iso.call(egg_front, p2, item_frame, Color.WHITE, lift, item_scale)
				continue
			on_push_iso.call(draws, p2, item_frame, Color.WHITE, lift, item_scale)
			continue
		on_push_iso.call(draws, p2, item_frame, Color.WHITE, lift, item_scale)
	for b in sim.buildings:
		if talk or b.dead or bool(b.get("lifted", false)):
			continue
		var p3 = Vector2(float(b.x), float(b.y))
		var b_kind = int(b.kind)
		var draw_at = on_building_draw_at.call(b_kind, p3)
		if focus_sees(p3, 0.0) or focus_sees(draw_at, 0.0):
			var bld_frame = on_prop_frame.call(Catalog.icon_for_building(b_kind))
			var focus_sort_y = NAN
			if b_kind == Catalog.BLD_MINE or b_kind == Catalog.BLD_MINE2:
				focus_sort_y = -1000000.0
			on_push_iso.call(draws, draw_at, bld_frame, Color.WHITE, 0.0, Catalog.building_sprite_scale(b_kind), focus_sort_y)
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT:
			continue
		if sim.held_kind == "thronglet" and i == sim.held_ref:
			continue
		if talk and not sim.gaze_home.has(i):
			continue
		var pos = Vector2(sim.pos_x[i], sim.pos_y[i])
		if not focus_sees(pos, 0.0):
			continue
		var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
		if sim.state[i] == Catalog.ST_DEAD:
			tint = Color.WHITE
		var throng_frame = on_throng_frame.call(i, time)
		var throng_look = on_throng_sprite_look.call(throng_frame)
		var throng_sort_y = host.cam_rig.to_iso(pos).y
		if sim.state[i] == Catalog.ST_DEAD:
			on_push_corpse_blood.call(draws, sim, i, pos, throng_sort_y)
		on_push_iso.call(draws, pos + throng_look.off, throng_frame, tint, 0.0, float(throng_look.scale), throng_sort_y)
		draws[draws.size() - 1]["flip"] = on_throng_flip.call(i)
		draws[draws.size() - 1]["dirty"] = on_throng_dirty.call(sim.clean[i])
	draws.sort_custom(func(a, b): return float(a.get("sy", a.p.y)) < float(b.get("sy", b.p.y)))
	draws.append_array(egg_front)
	return draws


## Feature kinds hidden during gaze talk mode.
func talk_hides_feat(kind: int) -> bool:
	return kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD or kind == Catalog.FEAT_MONOLITH or kind == Catalog.FEAT_TOTEM
