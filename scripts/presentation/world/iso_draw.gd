extends RefCounted
class_name IsoDraw

const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")
const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const ThrongAnimFrames := preload("res://scripts/presentation/anim/throng_anim_frames.gd")
const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")

## Camera that converts world feet to iso screen coordinates and sort keys.
var cam_rig: CameraRig
## Host exposing prop frame hooks and animation tick helpers.
var host: Node2D
## Optional delegate for prop frames and throng sprite metrics when bound.
var anim_frames: ThrongAnimFrames = null

## Prop atlas frame id to art-center offset for pad_nudge footprint alignment.
const CENTER := {
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



## Appends one sorted iso draw dict for [param world_pos] and atlas [param frame].
func push_iso(draws: Array, world_pos: Vector2, frame: int, tint: Color, lift: float = 0.0, sprite_scale: float = 1.0, sort_y: float = NAN, outline: Color = Color.TRANSPARENT, offset: Vector2 = Vector2.ZERO, rot: float = 0.0) -> void:
	var at := cam_rig.to_iso(world_pos + offset)
	var draw_p := Vector2(at.x, at.y - lift)
	var sy := at.y if is_nan(sort_y) else sort_y
	var d := {"p": draw_p, "sy": sy, "icon": frame, "tint": tint, "scale": sprite_scale}
	if outline.a > 0.0:
		d["outline"] = outline
	if not is_zero_approx(rot):
		d["rot"] = rot
	draws.append(d)

## Stacks bath foam bubbles around [param pos].
func paint_suds(draws: Array, pos: Vector2, sort_y: float, time: float, s: float = 1.0) -> void:
	var suds_idx := 0
	var base := AssetFrames.frame(AssetFrames.SUDS, AssetFrames.SUDS_N, suds_idx)
	var base_id := "suds"
	if base < 0:
		base = AssetFrames.frame(AssetFrames.BUBBLE, AssetFrames.BUBBLE_N, 0)
		base_id = "bubble"
	if base < 0:
		return
	var foam_fps := float(AnimTune.get_tune("foam").get("fps", 8.0))
	for i in 3:
		var phase := time * 3.0 + float(i) * TAU / 3.0
		var wob := Vector2(cos(phase) * 5.0, sin(phase * 1.3) * 2.5 - 3.0)
		var foam_idx := posmod(int(time * foam_fps) + i, maxi(AssetFrames.BUBBLE_LIGHT_N, 1))
		var frame := AssetFrames.frame(AssetFrames.BUBBLE_LIGHT, AssetFrames.BUBBLE_LIGHT_N, foam_idx)
		var frame_id := "foam"
		var frame_idx := foam_idx
		if frame < 0:
			frame = base
			frame_id = base_id
			frame_idx = 0
		var alpha := 0.75 + 0.2 * sin(phase)
		var scale := (0.85 + 0.1 * float(i % 2)) * s * AnimTune.frame_scale(frame_id, frame_idx)
		var off := wob + AnimTune.frame_offset(frame_id, frame_idx)
		push_iso(draws, pos + off, frame, Color(1, 1, 1, alpha), 6.0 + float(i) * 2.0, scale, sort_y, Color.TRANSPARENT, Vector2.ZERO, AnimTune.frame_rot(frame_id, frame_idx))

## Single sponge-wash bubble cluster at scrub position [param pos].
func paint_sponge_suds(draws: Array, pos: Vector2, sort_y: float, time: float, tune: Dictionary = {}) -> void:
	# One atlas cell is already a full bubble cluster — do not stack several cells.
	# Bench and live scrub both call this so fx_x/fx_y/scale/lift stay identical.
	var wash_tune: Dictionary = tune if not tune.is_empty() else EffectTune.get_tune("act:sponge")
	var s := float(wash_tune.get("scale", 0.45))
	var tip := Vector2(float(wash_tune.get("fx_x", 7.0)), float(wash_tune.get("fx_y", 7.0)))
	var body_lift := 6.0 + float(wash_tune.get("lift", 0.0))
	var bubble_fps := float(AnimTune.get_tune("bubble").get("fps", 8.0))
	var idx := posmod(int(time * bubble_fps), maxi(AssetFrames.BUBBLE_N, 1))
	var cluster := AssetFrames.frame(AssetFrames.BUBBLE, AssetFrames.BUBBLE_N, idx)
	if cluster < 0:
		cluster = AssetFrames.frame(AssetFrames.BUBBLE_LIGHT, AssetFrames.BUBBLE_LIGHT_N, idx)
	if cluster < 0:
		return
	push_iso(draws, pos + tip, cluster, Color(1, 1, 1, 0.92), body_lift, s, sort_y)

## Clean-sparkle FX at [param pos] from tune or [param progress].
func paint_clean_sparkle(draws: Array, pos: Vector2, sort_y: float, tune: Dictionary, fade: float = 1.0, progress: float = -1.0, time: float = 0.0) -> void:
	var clean_n := maxi(AssetFrames.CLEAN_N, 1)
	var clean_idx := 0
	if progress < 0.0:
		var fps := float(AnimTune.get_tune("clean").get("fps", 10.0))
		clean_idx = posmod(int(time * fps), clean_n)
	else:
		clean_idx = clampi(int(progress * float(clean_n)), 0, clean_n - 1)
	var frame := AssetFrames.frame(AssetFrames.CLEAN, clean_n, clean_idx)
	if frame < 0:
		return
	var sparkle_scale := float(tune.get("scale", 0.28)) * AnimTune.frame_scale("clean", clean_idx)
	var sparkle_off := Vector2(float(tune.get("fx_x", 9.0)), float(tune.get("fx_y", 9.0))) + AnimTune.frame_offset("clean", clean_idx)
	var sparkle_lift := float(tune.get("lift", 10.0))
	push_iso(draws, pos + sparkle_off, frame, Color(1, 1, 1, fade), sparkle_lift, sparkle_scale, sort_y, Color.TRANSPARENT, Vector2.ZERO, AnimTune.frame_rot("clean", clean_idx))


## Vertical bob/lift from effect tune at [param time].
func effect_look_lift(tune: Dictionary, time: float, phase: float = 0.0) -> float:
	var amp := float(tune.get("lift", 0.0))
	var bob := float(tune.get("bob", 0.0))
	if bob <= 0.0:
		return amp
	if amp <= 0.0:
		return absf(sin(time * bob + phase)) * 1.5
	return sin(time * bob + phase) * amp

## Draws anomaly ray overlay when [param kind] is FEAT_ANOMALY.
func push_anomaly_ray(draws: Array, kind: int, at: Vector2, time: float) -> void:
	if kind != Catalog.FEAT_ANOMALY:
		return
	var idx := posmod(host.anim_frames.anim_tick("anomaly_ray", time), maxi(AssetFrames.ANOMALY_RAY_N, 1))
	var frame := AssetFrames.frame(AssetFrames.ANOMALY_RAY, AssetFrames.ANOMALY_RAY_N, idx)
	push_iso(draws, at, frame, Color.WHITE, 0.0, AnimTune.frame_scale("anomaly_ray", idx), NAN, Color.TRANSPARENT, AnimTune.frame_offset("anomaly_ray", idx), AnimTune.frame_rot("anomaly_ray", idx))
	draws[draws.size() - 1]["sy"] = float(draws[draws.size() - 1].get("sy", 0.0)) + 0.5

## Draws glitch building/tree fume puffs at [param at].
func push_glitch_fumes(draws: Array, kind: int, at: Vector2, time: float) -> void:
	if kind != Catalog.FEAT_GLITCH_HOUSE and kind != Catalog.FEAT_GLITCH_TREE:
		return
	var idx := posmod(host.anim_frames.anim_tick("fumes", time), maxi(AssetFrames.FUMES_N, 1))
	var frame := AssetFrames.frame(AssetFrames.FUMES, AssetFrames.FUMES_N, idx)
	if frame >= 0:
		push_iso(draws, at + Vector2(0, -18), frame, Color.WHITE, 0.0, AnimTune.frame_scale("fumes", idx), NAN, Color.TRANSPARENT, AnimTune.frame_offset("fumes", idx), AnimTune.frame_rot("fumes", idx))

## Screen-space polyline for a world circle using the shared ellipse sampler.
func iso_circle_points(world_center: Vector2, radius: float, steps: int) -> PackedVector2Array:
	return iso_ellipse_points(world_center, radius, radius, steps)

## Stacks ore sprite layers beside factory [param b] at [param at].
func push_factory_pile(draws: Array, b: Dictionary, at: Vector2) -> void:
	var stacked := int(b.get("buffer", 0))
	if b.has("pile") and b.get("pile") is Array:
		stacked = (b.get("pile") as Array).size()
	if stacked <= 0:
		return
	# Right of the factory wall. Layer 0 is the first deposit and stays on the ground.
	var ore_at := at + Vector2(24.0, -10.0)
	var ore_sy := cam_rig.to_iso(ore_at).y
	var frame: int = host.anim_frames.prop_frame(Catalog.ICON_ORE_ULTRA)
	# 120 layers at 6px clear the view at the widest zoom. The rest stay in the pile.
	var drawn := mini(stacked, 120)
	for layer in drawn:
		push_iso(draws, ore_at, frame, Color.WHITE, float(layer) * 6.0, Catalog.ORE_CLUSTER_SPRITE_SCALE, ore_sy + float(drawn - layer) * 0.05)

## Footprint padding offset for atlas [param frame] and [param size].
func pad_nudge(frame: int, scale: float, size: Vector2i) -> Vector2:
	var raw: Vector2 = CENTER.get(frame, Vector2.ZERO)
	var dsy := (raw.x + raw.y) * 0.5
	var half_h := 4.0 * float(size.x + size.y)
	if dsy > half_h and dsy > 0.0:
		raw *= half_h / dsy
	return raw * scale


## Idle building sprite anchor in world space.
func building_draw_at(kind: int, origin: Vector2) -> Vector2:
	var size := Catalog.footprint_for_building(kind)
	var frame: int = host.anim_frames.prop_frame(Catalog.icon_for_building(kind))
	var scale := Catalog.building_sprite_scale(kind)
	return origin + Catalog.footprint_center(size) + pad_nudge(frame, scale, size) + Catalog.building_draw_off(kind)


## Active/working building sprite anchor in world space.
func building_active_draw_at(kind: int, origin: Vector2) -> Vector2:
	var size := Catalog.footprint_for_building(kind)
	var frame: int = host.anim_frames.prop_frame(Catalog.icon_for_building(kind))
	var scale := Catalog.building_sprite_scale(kind)
	var off := Catalog.active_building_draw_off(kind)
	if off == Vector2.ZERO:
		off = Catalog.building_draw_off(kind)
	return origin + Catalog.footprint_center(size) + pad_nudge(frame, scale, size) + off


## Feature sprite anchor for [param kind] at [param origin].
func feature_draw_at(kind: int, origin: Vector2, ore: int = 0) -> Vector2:
	var size := Catalog.footprint_for_feature(kind)
	var frame: int = AssetFrames.FIRE if kind == Catalog.FEAT_FIRE else host.anim_frames.prop_frame(Catalog.icon_for_feature(kind, ore))
	var scale := Catalog.feature_sprite_scale(kind, ore)
	var extra := Vector2.ZERO
	if kind == Catalog.FEAT_SUPER:
		extra = Vector2(9.0, 9.0)
	elif kind == Catalog.FEAT_FLOWER:
		extra = Vector2(3.0, 3.0)
	return origin + Catalog.footprint_center(size) + pad_nudge(frame, scale, size) + Catalog.feature_draw_off(kind, ore) + extra

## Ground item sprite anchor for [param kind] at [param origin].
func item_draw_at(kind: int, origin: Vector2) -> Vector2:
	var frame: int = AnimTune.sheet_frame("egg") if kind == Catalog.ITEM_EGG else host.anim_frames.prop_frame(Catalog.icon_for_item(kind))
	var scale := Catalog.item_sprite_scale(kind)
	return origin + pad_nudge(frame, scale, Vector2i(1, 1)) + Catalog.item_draw_off(kind)

## Sort Y one step in front of [param world_center] in iso space.
func prop_front_sort_y(world_center: Vector2) -> float:
	return cam_rig.to_iso(world_center).y + 1.0

## Nearby carousel draw point for sort, or Vector2.INF if none.
func use_prop_anchor(pos: Vector2) -> Vector2:
	var sim: ThrongletSim = ThrongletSimServer
	var best := Vector2.ZERO
	var best_d := 28.0
	var found := false
	for b in sim.buildings:
		if b.dead:
			continue
		var kind := int(b.kind)
		# Tubs: only seated bathers are forced in front (handled in ACT_BATH). A proximity
		# anchor here would also pull nearby thronglets standing behind the tub in front,
		# which becomes obvious when they freeze in place during mitosis.
		if kind != Catalog.BLD_ROUND:
			continue
		var origin := Vector2(float(b.x), float(b.y))
		var center := origin + Catalog.ROUND_RIDE_OFF
		var limit := 28.0
		var d := pos.distance_to(center)
		if d <= limit and d < best_d:
			best_d = d
			best = building_draw_at(kind, origin)
			found = true
	return best if found else Vector2.INF

## True when solid land sits southeast of [param world_pos] (void depth).
func void_behind_cliff(world_pos: Vector2) -> bool:
	var sim: ThrongletSim = ThrongletSimServer
	var cell := sim._cell_vec(world_pos.x, world_pos.y)
	for off in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var at := Catalog.cell_world(cell + off)
		var tile := sim._tile_at(at.x, at.y)
		if tile != Catalog.TILE_VOID and tile != Catalog.TILE_FOG:
			return true
	return false

## Wires presentation host, camera, and shared prop or throng frame resolver.
func setup(p_host: Node2D, p_cam_rig: CameraRig, p_anim: ThrongAnimFrames) -> void:
	host = p_host
	cam_rig = p_cam_rig
	anim_frames = p_anim


## Resolves a catalog icon to a multimesh atlas frame via anim_frames.
func prop_frame(icon: int) -> int:
	return anim_frames.prop_frame(icon)


## Returns the looping strip index for a tuned animation id at [param time].
func anim_tick(tune_id: String, time: float) -> int:
	return anim_frames.anim_tick(tune_id, time)


## Scale and iso offset for a throng body frame used when placing sprites.
func throng_sprite_look(frame: int) -> Dictionary:
	return anim_frames.throng_sprite_look(frame)


## Iso-space polyline approximating a world-space ellipse.
func iso_ellipse_points(world_center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not is_finite(world_center.x) or not is_finite(world_center.y):
		return pts
	if not is_finite(rx) or not is_finite(ry) or steps < 2:
		return pts
	for i in steps + 1:
		var ang := TAU * float(i) / float(steps)
		var world := world_center + Vector2(cos(ang) * rx, sin(ang) * ry)
		var iso := cam_rig.to_iso(world)
		if is_finite(iso.x) and is_finite(iso.y):
			pts.append(iso)
	return pts

