extends RefCounted
class_name WorldActorSync

const CameraRig := preload("res://scripts/presentation/camera/camera_rig.gd")
const ThrongletSim := preload("res://scripts/core/ThrongletSimServer.gd")
const AnimTune := preload("res://scripts/data/tune/anim_tune.gd")
const StructureTextures := preload("res://scripts/presentation/structures/structure_textures.gd")
const ThrongAnimFrames := preload("res://scripts/presentation/anim/throng_anim_frames.gd")
const DrawContext := preload("res://scripts/presentation/world/draw_context.gd")
const IsoDraw := preload("res://scripts/presentation/world/iso_draw.gd")
const WorldDrawer := preload("res://scripts/presentation/world/world_drawer.gd")

## Main presentation host owning layers, outlines, kit drag, and anim time.
var host: Node2D
## Camera used to grow the cull rect and map feet to iso screen space.
var cam_rig: CameraRig
## Iso placement helper for features, items, buildings, and throng bodies.
var iso: IsoDraw
## Uploads prop bands, void-back layers, and static feature batches.
var drawer: WorldDrawer
## Prop and throng atlas frame resolution for synced sprites.
var anim_frames: ThrongAnimFrames
## PNG structure atlases for animated or active building Sprite2D paths.
var structure_tex: StructureTextures


## Wires host, camera, drawer, and texture helpers.
func setup(
	p_host: Node2D,
	p_cam: CameraRig,
	p_iso: IsoDraw,
	p_drawer: WorldDrawer,
	p_anim: ThrongAnimFrames,
	p_struct: StructureTextures
) -> void:
	host = p_host
	cam_rig = p_cam
	iso = p_iso
	drawer = p_drawer
	anim_frames = p_anim
	structure_tex = p_struct


## Builds sorted draw lists for everything in view.
func sync() -> void:
	var sim: ThrongletSim = ThrongletSimServer
	var view = cam_rig.world_view().grow(64.0)
	var far_props = cam_rig.zoom_level < 2.5
	var ctx = DrawContext.make(host, cam_rig, host.anim_time, view, far_props)
	var draws: Array = ctx.draws
	var egg_front: Array = ctx.egg_front
	var void_back_draws: Array = ctx.void_back_draws
	var time_pre = ctx.anim_time
	var far_view = ctx.far_view
	ctx.drag_front = []
	var drag_front: Array = ctx.drag_front
	# far_view only affects thronglet anim LOD — never batch features into a stale MultiMesh.
	drawer.clear_feat_static()
	for feat in sim.features_in_rect(view):
		if bool(feat.get("lifted", false)):
			continue
		if not sim.chunk_shown(sim._ck(int(feat.cx), int(feat.cy))):
			continue
		var p = Vector2(float(feat.x), float(feat.y))
		var feat_kind = int(feat.kind)
		var fid = int(feat.id)
		if feat_kind == Catalog.FEAT_MONOLITH:
			sync_monolith(fid, p + Catalog.feature_draw_off(Catalog.FEAT_MONOLITH), feat, time_pre)
			continue
		var feat_at = iso.feature_draw_at(feat_kind, p, int(feat.ore))
		# Viewport cull only — never hide in-view props.
		if view.has_point(p) or view.has_point(feat_at):
			var feat_outline = Color.TRANSPARENT
			if host.outlined_feat_ids.has(fid):
				feat_outline = Color(0.35, 1.0, 0.45, 1.0)
			elif host.tool_charge > 0.02 and str(host.tool_charge_key).begins_with("feat:") and int(str(host.tool_charge_key).substr(5)) == fid:
				# Axe and hammer both charge on a single feature (tree / stump).
				feat_outline = Color(0.35, 1.0, 0.45, 1.0)
			var feat_anim = host.anim_frames.feature_anim(feat_kind, time_pre, int(feat.ore))
			var feat_frame = int(feat_anim.get("frame", -1))
			var feat_scale = Catalog.feature_sprite_scale(feat_kind, int(feat.ore))
			var feat_off = Vector2.ZERO
			var feat_rot = 0.0
			if feat_frame < 0:
				feat_frame = host.anim_frames.prop_frame(Catalog.icon_for_feature(feat_kind, int(feat.ore)))
			elif not feat_anim.is_empty():
				var feat_tune_id = str(feat_anim.get("id", ""))
				var feat_idx = int(feat_anim.get("idx", 0))
				feat_scale *= AnimTune.frame_scale(feat_tune_id, feat_idx)
				feat_off = AnimTune.frame_offset(feat_tune_id, feat_idx)
				feat_rot = AnimTune.frame_rot(feat_tune_id, feat_idx)
			var feat_sort_y = NAN
			if sim._ore_tier(feat_kind) > 0:
				# Mine zones (ore nodes) are ground zones: above ground, below sprites on top.
				feat_sort_y = -1000000.0
			iso.push_iso(draws, feat_at, feat_frame, Color.WHITE, 0.0, feat_scale, feat_sort_y, feat_outline, feat_off, feat_rot)
			iso.push_glitch_fumes(draws, feat_kind, feat_at, time_pre)
			iso.push_anomaly_ray(draws, feat_kind, feat_at, time_pre)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var falling_void = bool(it.get("falling_void", false))
		if not falling_void and not sim.chunk_at_home(float(it.x), float(it.y)):
			continue
		var world_pos = Vector2(float(it.x), float(it.y))
		var p2 = iso.item_draw_at(int(it.kind), world_pos)
		if view.has_point(p2):
			var lift = float(it.get("air", 0.0))
			var item_frame = host.anim_frames.prop_frame(Catalog.icon_for_item(int(it.kind)))
			var item_scale = Catalog.item_sprite_scale(int(it.kind))
			var item_outline = Color(0.35, 1.0, 0.45, 1.0) if host.outlined_item_ids.has(int(it.id)) else Color.TRANSPARENT
			var item_off = Vector2.ZERO
			var item_rot = 0.0
			if int(it.kind) == Catalog.ITEM_EGG:
				var egg = host.anim_frames.egg_anim(it)
				var egg_idx = int(egg.get("idx", 0))
				item_frame = int(egg.get("frame", AnimTune.sheet_frame("egg")))
				item_scale = AnimTune.frame_scale("egg", egg_idx)
				item_off = AnimTune.frame_offset("egg", egg_idx)
				item_rot = AnimTune.frame_rot("egg", egg_idx)
				if float(it.get("shake", 0.0)) > 0.0:
					p2 += Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
				if lift > 0.0:
					iso.push_iso(egg_front, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
					continue
			elif int(it.kind) == Catalog.ITEM_APPLE:
				item_frame = host.anim_frames.apple_frame(it)
				if falling_void:
					if iso.void_behind_cliff(world_pos):
						iso.push_iso(void_back_draws, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
					else:
						iso.push_iso(draws, p2, item_frame, Color.WHITE, lift, item_scale, cam_rig.to_iso(world_pos).y + 120.0, item_outline, item_off, item_rot)
					continue
				if lift > 14.0:
					iso.push_iso(egg_front, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
					continue
				iso.push_iso(draws, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
				continue
			elif falling_void:
				if iso.void_behind_cliff(world_pos):
					iso.push_iso(void_back_draws, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
				else:
					iso.push_iso(draws, p2, item_frame, Color.WHITE, lift, item_scale, cam_rig.to_iso(world_pos).y + 120.0, item_outline, item_off, item_rot)
				continue
			iso.push_iso(draws, p2, item_frame, Color.WHITE, lift, item_scale, NAN, item_outline, item_off, item_rot)
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if not sim.chunk_at_home(float(b.x), float(b.y)):
			continue
		var p3 = Vector2(float(b.x), float(b.y))
		var b_kind = int(b.kind)
		var draw_at = iso.building_draw_at(b_kind, p3)
		if view.has_point(p3) or view.has_point(draw_at):
			var b_lift = 0.0
			var b_tint = Color.WHITE
			var b_frame = host.anim_frames.prop_frame(Catalog.icon_for_building(b_kind))
			var b_off = Vector2.ZERO
			var b_rot = 0.0
			var anim_idx = -1
			if b_kind == Catalog.BLD_FLOWER:
				anim_idx = posmod(int(time_pre * 6.0), StructureTextures.FLOWER_ANIM_N)
				b_off = AnimTune.frame_offset("flower", anim_idx)
			elif b_kind == Catalog.BLD_ROUND:
				# Disk wedges follow the same spin the riders orbit on.
				if bool(b.get("active", false)):
					var spin = float(b.get("spin", 0.0))
					anim_idx = posmod(int(floor(spin / (TAU / float(StructureTextures.ROUND_ANIM_N)))), StructureTextures.ROUND_ANIM_N)
				else:
					anim_idx = 0
				b_off = AnimTune.frame_offset("round", anim_idx)
				b_rot = AnimTune.frame_rot("round", anim_idx)
			if bool(b.get("active", false)) and b_kind != Catalog.BLD_APPLE:
				if b_kind == Catalog.BLD_TUB:
					b_tint = Color(0.85, 0.95, 1.0)
				elif b_kind != Catalog.BLD_ROUND and not Catalog.building_has_active(b_kind):
					b_lift = absf(sin(time_pre * 8.0 + float(b.id))) * 2.2
			var b_scale = Catalog.building_sprite_scale(b_kind)
			if b_kind == Catalog.BLD_ROUND and anim_idx >= 0:
				b_scale *= AnimTune.frame_scale("round", anim_idx)
			var b_sort_y = NAN
			if b_kind == Catalog.BLD_MINE or b_kind == Catalog.BLD_MINE2:
				# Mines are walkable ground pads: render above ground but below entities on top.
				b_sort_y = -1000000.0
			var polluted = sim.has_method("building_is_polluted") and bool(sim.building_is_polluted(b))
			var show_on = false
			if not polluted and Catalog.building_has_active(b_kind):
				if (
					b_kind == Catalog.BLD_DWELL
					or b_kind == Catalog.BLD_FANCY
					or b_kind == Catalog.BLD_THEATRE
				):
					show_on = (
						sim.has_method("_live_guests")
						and int(sim._live_guests(b)) > 0
					)
				else:
					show_on = bool(b.get("active", false))
			var sprite_tex: Texture2D = null
			if polluted:
				sprite_tex = host.structure_tex.goo_structure_texture(b_kind)
			elif anim_idx >= 0:
				sprite_tex = host.structure_tex.structure_anim_texture(b_kind, anim_idx)
			elif show_on:
				sprite_tex = host.structure_tex.active_structure_texture(b_kind)
			if sprite_tex == null:
				sprite_tex = host.structure_tex.idle_structure_texture(b_kind)
			if sprite_tex != null:
				var bid = int(b.id)
				var b_outline = Color.TRANSPARENT
				if host.outlined_bld_ids.has(bid):
					b_outline = Color(0.35, 1.0, 0.45, 1.0)
				elif host.tool_charge > 0.02 and str(host.tool_charge_key).begins_with("bld:") and int(str(host.tool_charge_key).substr(4)) == bid:
					b_outline = Color(0.35, 1.0, 0.45, 1.0)
				sync_active_building_sprite(bid, b_kind, p3, b_scale, b_sort_y, sprite_tex, b_tint, b_outline, b_off, b_rot)
			else:
				hide_active_building_sprite(int(b.id))
				var b_outline = Color.TRANSPARENT
				var bid = int(b.id)
				if host.outlined_bld_ids.has(bid):
					b_outline = Color(0.35, 1.0, 0.45, 1.0)
				elif host.tool_charge > 0.02 and str(host.tool_charge_key).begins_with("bld:") and int(str(host.tool_charge_key).substr(4)) == bid:
					b_outline = Color(0.35, 1.0, 0.45, 1.0)
				iso.push_iso(draws, draw_at, b_frame, b_tint, b_lift, b_scale, b_sort_y, b_outline, b_off, b_rot)
			if b_kind == Catalog.BLD_FACTORY or b_kind == Catalog.BLD_FACTORY2:
				iso.push_factory_pile(draws, b, draw_at)
			if b_kind == Catalog.BLD_APPLE:
				var fruit_sort = cam_rig.to_iso(Vector2(float(b.x), float(b.y))).y + 10.0
				for fruit in b.get("fruits", []):
					var slot = clampi(int(fruit.slot), 0, 2)
					var grown = clampf(float(fruit.s), 0.15, 1.0)
					iso.push_iso(
						draws,
						Vector2(float(b.x), float(b.y)) + Catalog.APPLE_SPOTS[slot],
						host.anim_frames.prop_frame(Catalog.ICON_APPLE),
						Color.WHITE,
						Catalog.APPLE_LIFTS[slot],
						Catalog.APPLE_SPRITE_SCALE * grown,
						fruit_sort
					)
	var grid_at = cam_rig.grid_pointer_world()
	var free_at = cam_rig.pointer_world()
	var hand: Dictionary = sim.hand_item()
	if not hand.is_empty():
		var hand_frame = host.anim_frames.prop_frame(Catalog.icon_for_item(int(hand.kind)))
		var hand_scale = Catalog.item_sprite_scale(int(hand.kind))
		var hand_off = Vector2.ZERO
		var hand_rot = 0.0
		if int(hand.kind) == Catalog.ITEM_APPLE:
			hand_frame = host.anim_frames.apple_frame(hand)
		elif int(hand.kind) == Catalog.ITEM_EGG:
			var egg = host.anim_frames.egg_anim(hand)
			var egg_idx = int(egg.get("idx", 0))
			hand_frame = int(egg.get("frame", AnimTune.sheet_frame("egg")))
			hand_scale = AnimTune.frame_scale("egg", egg_idx)
			hand_off = AnimTune.frame_offset("egg", egg_idx)
			hand_rot = AnimTune.frame_rot("egg", egg_idx)
		if host.tool_controller.drop_on_island():
			var hand_at = grid_at if Catalog.item_snaps_grid(int(hand.kind)) else free_at
			iso.push_iso(draws, iso.item_draw_at(int(hand.kind), hand_at), hand_frame, Color(1, 1, 1, 0.9), 10.0, hand_scale, NAN, Color.TRANSPARENT, hand_off, hand_rot)
		else:
			var hand_draw = {
				"p": host.get_global_mouse_position() + (cam_rig.to_iso(hand_off) - cam_rig.to_iso(Vector2.ZERO)),
				"icon": hand_frame,
				"tint": Color.WHITE,
				"scale": hand_scale,
			}
			if not is_zero_approx(hand_rot):
				hand_draw["rot"] = hand_rot
			draws.append(hand_draw)
	if sim.has_scoop():
		for raw in sim.scoop_item_ids:
			var scooped = sim.item_by_id.get(int(raw), {})
			if scooped.is_empty() or scooped.dead:
				continue
			var scooped_frame = host.anim_frames.prop_frame(Catalog.icon_for_item(int(scooped.kind)))
			var scooped_scale = Catalog.item_sprite_scale(int(scooped.kind))
			var scooped_off = Vector2.ZERO
			var scooped_rot = 0.0
			if int(scooped.kind) == Catalog.ITEM_APPLE:
				scooped_frame = host.anim_frames.apple_frame(scooped)
			elif int(scooped.kind) == Catalog.ITEM_EGG:
				var egg = host.anim_frames.egg_anim(scooped)
				var egg_idx = int(egg.get("idx", 0))
				scooped_frame = int(egg.get("frame", AnimTune.sheet_frame("egg")))
				scooped_scale = AnimTune.frame_scale("egg", egg_idx)
				scooped_off = AnimTune.frame_offset("egg", egg_idx)
				scooped_rot = AnimTune.frame_rot("egg", egg_idx)
			iso.push_iso(draws, iso.item_draw_at(int(scooped.kind), Vector2(float(scooped.x), float(scooped.y))), scooped_frame, Color(1, 1, 1, 0.92), 12.0, scooped_scale, NAN, Color.TRANSPARENT, scooped_off, scooped_rot)
	if sim.held_kind == "rock":
		var rock = sim.feature_by_id.get(sim.held_ref, {})
		if not rock.is_empty():
			if host.tool_controller.drop_on_island():
				iso.push_iso(draws, iso.feature_draw_at(int(rock.kind), grid_at, int(rock.ore)), host.anim_frames.prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))), Color(1, 1, 1, 0.9), 10.0, Catalog.feature_sprite_scale(int(rock.kind), int(rock.ore)))
			else:
				draws.append({
					"p": host.get_global_mouse_position(),
					"icon": host.anim_frames.prop_frame(Catalog.icon_for_feature(int(rock.kind), int(rock.ore))),
					"tint": Color.WHITE,
					"scale": Catalog.feature_sprite_scale(int(rock.kind), int(rock.ore)),
				})
	elif sim.held_kind == "building":
		var carried = sim.building_by_id.get(sim.held_ref, {})
		if not carried.is_empty():
			var carried_kind = int(carried.kind)
			var carried_scale = Catalog.building_sprite_scale(carried_kind)
			if host.tool_controller.drop_on_island():
				var carried_sort_y = NAN
				if carried_kind == Catalog.BLD_MINE or carried_kind == Catalog.BLD_MINE2:
					carried_sort_y = -1000000.0
				iso.push_iso(draws, iso.building_draw_at(carried_kind, grid_at), host.anim_frames.prop_frame(Catalog.icon_for_building(carried_kind)), Color(1, 1, 1, 0.9), 10.0, carried_scale, carried_sort_y)
			else:
				draws.append({
					"p": host.get_global_mouse_position(),
					"icon": host.anim_frames.prop_frame(Catalog.icon_for_building(carried_kind)),
					"tint": Color.WHITE,
					"scale": carried_scale,
				})
	drag_front.clear()
	hide_place_ghost_sprite()
	if not host.kit_drag.is_empty():
		var ghost = Color(1, 1, 1, 0.85)
		var drag_icon = host.kit_toolbar.kit_drag_icon()
		var drag_tool_id = int(host.kit_drag.get("id", -1)) if str(host.kit_drag.get("type", "")) == "tool" else -1
		if drag_icon >= 0 or drag_tool_id == Catalog.TOOL_GRAB:
			if host.tool_controller.want_place_grid() and host.tool_controller.drop_on_island():
				var ghost_kind = host.placing if str(host.kit_drag.get("type", "")) == "build" else -1
				if ghost_kind < 0 and str(host.kit_drag.get("type", "")) == "prop" and str(host.kit_drag.get("prop", "")) == "flower":
					ghost_kind = Catalog.BLD_FLOWER
				var ghost_scale = Catalog.building_sprite_scale(ghost_kind)
				var ghost_sort_y = NAN
				if ghost_kind == Catalog.BLD_MINE or ghost_kind == Catalog.BLD_MINE2:
					ghost_sort_y = -1000000.0
				# Buildings with loose PNGs preview as Sprite2D — same path as after place.
				if ghost_kind >= 0 and sync_place_ghost_sprite(ghost_kind, grid_at, ghost_scale, ghost):
					pass
				else:
					iso.push_iso(drag_front, iso.building_draw_at(ghost_kind, grid_at), host.anim_frames.prop_frame(drag_icon), ghost, 10.0, ghost_scale, ghost_sort_y)
			else:
				var drag_scale = 1.0
				var drag_frame = host.anim_frames.prop_frame(drag_icon) if drag_icon >= 0 else -1
				var drag_rot = 0.0
				var drag_off = Vector2.ZERO
				if str(host.kit_drag.get("type", "")) == "tool":
					var tid = int(host.kit_drag.get("id", -1))
					match tid:
						Catalog.TOOL_APPLE:
							drag_scale = Catalog.APPLE_SPRITE_SCALE
						Catalog.TOOL_BALL:
							drag_scale = Catalog.BALL_SPRITE_SCALE
						Catalog.TOOL_SPONGE:
							drag_scale = Catalog.SPONGE_SPRITE_SCALE
						_:
							drag_scale = Catalog.item_sprite_scale(tid)
					if tid == Catalog.TOOL_GRAB:
						var hand_anim = tid == host.tool_controller.charge_tool_id() and host.tool_charge > 0.0
						var hand_fps_drag = float(AnimTune.get_tune("hand").get("fps", 8.0))
						var hand_idx = int(host.anim_time * hand_fps_drag) % AssetFrames.HAND_N if hand_anim else 0
						drag_frame = AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, hand_idx)
						drag_scale = AnimTune.frame_scale("hand", hand_idx)
						drag_off = AnimTune.frame_offset("hand", hand_idx)
						drag_rot = AnimTune.frame_rot("hand", hand_idx)
				elif str(host.kit_drag.get("type", "")) == "build":
					drag_scale = Catalog.building_sprite_scale(int(host.kit_drag.get("id", -1)))
				if drag_frame >= 0:
					var drag_draw = {
						"p": host.get_global_mouse_position() + (cam_rig.to_iso(drag_off) - cam_rig.to_iso(Vector2.ZERO)),
						"icon": drag_frame,
						"tint": ghost,
						"scale": drag_scale,
					}
					if not is_zero_approx(drag_rot):
						drag_draw["rot"] = drag_rot
					drag_front.append(drag_draw)
	var time = time_pre
	# Crowd LOD only when the viewport is actually dense — not merely zoomed out.
	var visible_ids: Array = sim.query_rect(view, Catalog.DRAW_THRONG_DETAIL + 1)
	var crowd_mode = visible_ids.size() > Catalog.DRAW_THRONG_DETAIL
	clear_throng_crowd()
	if crowd_mode:
		var crowd_ids: Array = sim.query_rect(view)
		push_throng_crowd_draws(draws, crowd_ids, time, far_view)
	else:
		for id in visible_ids:
			var i = int(id)
			if sim.held_kind == "thronglet" and i == sim.held_ref:
				continue
			if throng_hidden_indoors(sim, i):
				continue
			var pos = Vector2(sim.pos_x[i], sim.pos_y[i])
			var tint: Color = Catalog.TINTS[int(sim.tint[i]) % Catalog.TINTS.size()]
			if sim.state[i] == Catalog.ST_DEAD:
				tint = Color.WHITE
			var lift = 0.0
			var doing = int(sim.act[i])
			var riding = false
			var prop_anchor = Vector2.INF
			var sort_y = NAN
			var ball_play: bool = doing == ThrongletSim.ACT_PLAY and sim.has_ball(i)
			if not sim.frozen:
				if not far_view and sim.shake_t[i] > 0.0:
					pos += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
				if doing == ThrongletSim.ACT_EAT:
					lift = iso.effect_look_lift(EffectTune.get_tune("act:eat"), time, float(i))
				elif doing == ThrongletSim.ACT_PLAY and ball_play:
					lift = iso.effect_look_lift(EffectTune.get_tune("act:ball"), time, float(i))
				elif doing == ThrongletSim.ACT_PLAY and not ball_play:
					var ride: Dictionary = sim.ride_of(i)
					if ride.is_empty():
						lift = iso.effect_look_lift(EffectTune.get_tune("act:play"), time, float(i))
					else:
						riding = true
						lift = iso.effect_look_lift(EffectTune.get_tune("act:round"), time, float(i))
						var seat = sim._ride_slot_of(ride, i)
						if seat >= 0:
							pos = sim._ride_slot_pos(ride, seat)
						else:
							var mid = sim._ride_center_of(ride)
							var ring = pos - mid
							var rr = sim._ride_radius(ride)
							if ring.length_squared() >= 0.25 and rr > 0.0:
								pos = mid + ring.normalized() * rr
							else:
								pos = mid
						prop_anchor = iso.building_active_draw_at(
							Catalog.BLD_ROUND, Vector2(float(ride.x), float(ride.y))
						)
				elif doing == ThrongletSimServer.ACT_BATH:
					var tub: Dictionary = sim.seat_of(i)
					if tub.is_empty():
						lift = absf(sin(time * 9.0 + float(i))) * 2.2
					else:
						var tub_origin = Vector2(float(tub.x), float(tub.y))
						pos = tub_origin + Catalog.TUB_SEAT_OFF
						var age = float(tub.get("bath_t", 0.0))
						if age < 0.0:
							lift = Catalog.TUB_ENTER_LIFT
						elif age < ThrongletSimServer.BATH_ENTER_T:
							lift = lerpf(Catalog.TUB_ENTER_LIFT, Catalog.TUB_SOAK_LIFT, age / ThrongletSimServer.BATH_ENTER_T)
						else:
							lift = Catalog.TUB_SOAK_LIFT
						prop_anchor = iso.building_draw_at(Catalog.BLD_TUB, tub_origin)
				elif doing == ThrongletSimServer.ACT_WASH:
					lift = iso.effect_look_lift(EffectTune.get_tune("act:sponge"), time, float(i))
				elif doing == ThrongletSimServer.ACT_WORK:
					lift = 0.0
				elif sim.act_t[i] > 0.0:
					lift = sin(time * 16.0 + float(i)) * 3.5
			if prop_anchor.x == INF:
				prop_anchor = iso.use_prop_anchor(pos)
			if is_nan(sort_y):
				sort_y = NAN if prop_anchor.x == INF else iso.prop_front_sort_y(prop_anchor)
			var throng_frame = host.anim_frames.frame_lod(i, time, far_view)
			var throng_look = host.anim_frames.throng_sprite_look(throng_frame)
			var throng_scale = float(throng_look.scale)
			var throng_off: Vector2 = throng_look.off
			var throng_at = pos if riding else pos + throng_off
			var throng_sort_y = sort_y if not is_nan(sort_y) else cam_rig.to_iso(pos).y
			var throng_outline = Color.TRANSPARENT
			if host.outlined_throng_ids.has(i):
				throng_outline = Color(0.35, 1.0, 0.45, 1.0)
			if sim.state[i] == Catalog.ST_DEAD:
				push_corpse_blood(draws, sim, i, pos, throng_sort_y)
			iso.push_iso(draws, throng_at, throng_frame, tint, lift, throng_scale, throng_sort_y, throng_outline)
			draws[draws.size() - 1]["flip"] = host.anim_frames.throng_flip(i)
			# Dirt is a needs signal — keep it at every zoom (far_view only LODs the clip).
			draws[draws.size() - 1]["dirty"] = host.anim_frames.throng_dirty(sim.clean[i])
			# Suds only on the thronglet currently under the sponge (not prior wash targets).
			if not sim.frozen and host.sponge_tracking and i == sim.sponge_id and sim.sponge_hold > 0.0:
				iso.paint_sponge_suds(draws, throng_at, throng_sort_y + 1.0, time)
			if sim.carry[i] != Catalog.CARRY_NONE:
				var carry_kind = int(sim.carry[i])
				var carry_icon = host.anim_frames.carry_icon(carry_kind)
				var carry_scale = Catalog.item_sprite_scale(host.anim_frames.carry_item(carry_kind))
				iso.push_iso(draws, pos, host.anim_frames.prop_frame(carry_icon), Color.WHITE, 12.0, carry_scale, sort_y)
	if sim.held_kind == "thronglet" and sim.held_ref >= 0 and sim.held_ref < sim.slot_count:
		var hi: int = sim.held_ref
		var htint: Color = Catalog.TINTS[int(sim.tint[hi]) % Catalog.TINTS.size()]
		var held_frame: int = host.anim_frames.frame(hi, time)
		draws.append({
			"p": host.get_global_mouse_position(),
			"sy": 1000000.0,
			"icon": held_frame,
			"tint": htint,
			"flip": host.anim_frames.throng_flip(hi),
			"dirty": host.anim_frames.throng_dirty(sim.clean[hi]),
			"scale": host.anim_frames.throng_sprite_scale(held_frame),
		})
		var hand_tune = AnimTune.get_tune("hand")
		var hand_fps = float(hand_tune.get("fps", 8.0))
		var hand_idx_h = int(time * hand_fps) % AssetFrames.HAND_N
		var hand_frame = AssetFrames.frame(AssetFrames.HAND, AssetFrames.HAND_N, hand_idx_h)
		if hand_frame >= 0:
			var hand_off_h = AnimTune.frame_offset("hand", hand_idx_h)
			draws.append({
				"p": host.get_global_mouse_position() + Vector2(10, 6) + (cam_rig.to_iso(hand_off_h) - cam_rig.to_iso(Vector2.ZERO)),
				"sy": 1000001.0,
				"icon": hand_frame,
				"tint": Color.WHITE,
				"flip": 1.0,
				"dirty": 0.0,
				"scale": AnimTune.frame_scale("hand", hand_idx_h),
				"rot": AnimTune.frame_rot("hand", hand_idx_h),
			})
	var bath_exit_tune: Dictionary = EffectTune.get_tune("act:bath_exit")
	var wash_sparkle_tune: Dictionary = EffectTune.get_tune("act:wash_sparkle")
	for pop in sim.pops:
		var pop_life = float(pop.get("life", 0.55))
		var fade = clampf(float(pop.t) / maxf(pop_life, 0.01), 0.0, 1.0)
		var picon = int(pop.icon)
		var frame = host.anim_frames.pop_frame(picon)
		var pop_scale = float(pop.get("scale", 1.0))
		var pop_off = Vector2.ZERO
		var pop_rot = 0.0
		var pop_lift = float(pop.lift)
		var pop_at = Vector2(float(pop.x), float(pop.y))
		var pop_elapsed = pop_life - float(pop.t)
		if picon == AssetFrames.SPLASH:
			var splash_fps = float(AnimTune.get_tune("splash").get("fps", 8.0))
			var splash_idx = int(pop_elapsed * splash_fps) % maxi(AssetFrames.SPLASH_N, 1)
			frame = AssetFrames.frame(AssetFrames.SPLASH, AssetFrames.SPLASH_N, splash_idx)
			if frame >= 0:
				pop_scale = AnimTune.frame_scale("splash", splash_idx)
				pop_off = AnimTune.frame_offset("splash", splash_idx)
				pop_rot = AnimTune.frame_rot("splash", splash_idx)
		elif picon == AssetFrames.CLEAN:
			# One-shot strip over pop life
			var sparkle_tune: Dictionary = wash_sparkle_tune if str(pop.get("kind", "")) == "wash" else bath_exit_tune
			var tid = int(pop.get("throng_id", -1))
			if tid >= 0 and tid < sim.slot_count and int(sim.state[tid]) == Catalog.ST_LIVING:
				pop_at = Vector2(sim.pos_x[tid], sim.pos_y[tid]) + host.anim_frames.throng_sprite_off(host.anim_frames.frame_lod(tid, time, far_view))
			iso.paint_clean_sparkle(draws, pop_at, NAN, sparkle_tune, fade, pop_elapsed / maxf(pop_life, 0.01))
			continue
		iso.push_iso(draws, pop_at + pop_off, frame, Color(1, 1, 1, fade), pop_lift, pop_scale, NAN, Color.TRANSPARENT, Vector2.ZERO, pop_rot)
	draws.sort_custom(func(a, b): return float(a.get("sy", a.p.y)) < float(b.get("sy", b.p.y)))
	draws.append_array(egg_front)
	draws.append_array(drag_front)
	drawer.paint_props(draws)
	drawer.write_void_draws(void_back_draws)

## Caches default crowd animation frames once.
func ensure_crowd_frames() -> void:
	if host._crowd_default_frame >= 0:
		return
	host._crowd_default_frame = ThrongClips.frame_at("ThrongA_Default", 0)
	host._crowd_walk_frame = ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", 0)
	host._crowd_sad_frame = ThrongClips.frame_at("ThrongA_Sad", 0)

## Hides the shared throng crowd multimesh.
func clear_throng_crowd() -> void:
	if host.throng_crowd_mesh == null:
		return
	host.throng_crowd_mesh.visible_instance_count = 0
	if host.throng_crowd != null:
		host.throng_crowd.visible = false

## Low-LOD thronglet icons for dense views.
func push_throng_crowd_draws(draws: Array, ids: Array, time: float, far_view: bool) -> void:
	# Cheap thronglet LOD into the shared prop draw list (y-sorted; every id is in-view).
	# Special bodies (act / carry / timers / panic) still go through anim_frames.frame_lod.
	ensure_crowd_frames()
	var sim: ThrongletSim = ThrongletSimServer
	var tint_n = Catalog.TINTS.size()
	var walk_tick = int(time * 8.0)
	for raw in ids:
		var i = int(raw)
		if sim.held_kind == "thronglet" and i == sim.held_ref:
			continue
		if throng_hidden_indoors(sim, i):
			continue
		var pos = Vector2(sim.pos_x[i], sim.pos_y[i])
		var frame = host._crowd_default_frame
		if sim.state[i] == Catalog.ST_DEAD:
			frame = ThrongClips.frame_at("ThrongA_Dead_001" if sim.dir_x[i] >= 0.0 else "ThrongA_Dead_002", 0)
		elif host.anim_frames.throng_special_body(sim, i):
			frame = host.anim_frames.frame_lod(i, time, far_view)
		elif absf(sim.dir_x[i]) + absf(sim.dir_y[i]) >= 0.01:
			frame = ThrongClips.frame_at("Throng_Walk_Anim_Spritesheet", walk_tick + i) if not far_view else host._crowd_walk_frame
		elif sim.clean[i] < 12.0 or sim.fed[i] < 25.0:
			frame = host._crowd_sad_frame
		var tint: Color = Color.WHITE if sim.state[i] == Catalog.ST_DEAD else Catalog.TINTS[int(sim.tint[i]) % tint_n]
		var flip = 1.0
		if not far_view and absf(sim.dir_x[i]) > absf(sim.dir_y[i]) and sim.dir_x[i] < 0.0:
			flip = -1.0
		if sim.state[i] == Catalog.ST_DEAD:
			push_corpse_blood(draws, sim, i, pos, cam_rig.to_iso(pos).y)
		iso.push_iso(draws, pos, frame, tint, 0.0, host.anim_frames.throng_sprite_scale(frame))
		draws[draws.size() - 1]["flip"] = flip
		draws[draws.size() - 1]["dirty"] = host.anim_frames.throng_dirty(sim.clean[i])
		# Carry must stay readable at any zoom — haul feedback is core gameplay.
		if sim.state[i] == Catalog.ST_LIVING and sim.carry[i] != Catalog.CARRY_NONE:
			var carry_kind = int(sim.carry[i])
			var carry_icon = host.anim_frames.carry_icon(carry_kind)
			var carry_scale = Catalog.item_sprite_scale(host.anim_frames.carry_item(carry_kind))
			iso.push_iso(draws, pos, host.anim_frames.prop_frame(carry_icon), Color.WHITE, 12.0, carry_scale)

## True when a living thronglet is inside a visit building.
func throng_hidden_indoors(sim: ThrongletSim, i: int) -> bool:
	# Inside a visit building (home / theatre / mine). Tub and roundabout stay visible.
	# Crowd path: O(1) guest link only — do not scan every building per agent.
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	if i >= sim.link_guest.size():
		return false
	var bid = int(sim.link_guest[i])
	if bid < 0:
		return false
	var visit = sim.building_by_id.get(bid, {})
	if visit.is_empty() or visit.dead:
		return false
	return not sim._visit_rule(int(visit.kind)).is_empty()

## Draws blood pool under a dead thronglet.
func push_corpse_blood(draws: Array, sim: ThrongletSim, i: int, pos: Vector2, sort_y: float) -> void:
	if i < 0 or i >= sim.bloody.size() or int(sim.bloody[i]) == 0:
		return
	var blood_frame = ThrongClips.frame_at("Throng_Prop_Blood_A", 0)
	var blood_look = host.anim_frames.throng_sprite_look(blood_frame)
	# Slightly behind the corpse so the pool sits on the ground under it.
	iso.push_iso(draws, pos, blood_frame, Color.WHITE, 0.0, float(blood_look.scale), sort_y - 0.5)

## Creates or updates a monolith prop node.
func sync_monolith(id: int, world_pos: Vector2, feat: Dictionary, t: float) -> void:
	var node: Node2D = host._monoliths.get(id)
	if node == null:
		node = (load("res://scripts/presentation/props/monolith_prop.gd") as GDScript).new()
		host.world_layer.add_child(node)
		host._monoliths[id] = node
	node.position = cam_rig.to_iso(world_pos)
	node.visible = true
	node.set_meta("seen", true)
	if node.has_method("sync_state"):
		node.sync_state(feat, t)

## Shows an animated or active building Sprite2D.
func sync_active_building_sprite(
	id: int,
	kind: int,
	origin: Vector2,
	sprite_scale: float,
	sort_y: float,
	tex: Texture2D = null,
	tint: Color = Color.WHITE,
	outline: Color = Color.TRANSPARENT,
	offset: Vector2 = Vector2.ZERO,
	rot: float = 0.0
) -> void:
	if tex == null:
		tex = host.structure_tex.idle_structure_texture(kind)
	if tex == null:
		hide_active_building_sprite(id)
		return
	var node: Sprite2D = host._building_active_sprites.get(id)
	if node == null:
		node = Sprite2D.new()
		node.centered = true
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.world_layer.add_child(node)
		host._building_active_sprites[id] = node
	node.texture = tex
	node.scale = Vector2(sprite_scale, sprite_scale)
	node.rotation_degrees = rot
	node.modulate = tint if outline.a <= 0.0 else outline
	var anchor = iso.building_active_draw_at(kind, origin)
	var screen_p = cam_rig.to_iso(anchor + offset)
	node.position = screen_p + host.structure_tex.structure_sprite_lift(tex, sprite_scale)
	var sy = sort_y if not is_nan(sort_y) else cam_rig.to_iso(anchor).y
	node.set_meta("sy", sy)
	node.visible = true
	node.set_meta("seen", true)

## Clears the loose PNG building overlay when the sim falls back to multimesh props.
func hide_active_building_sprite(id: int) -> void:
	if not host._building_active_sprites.has(id):
		return
	var node: Sprite2D = host._building_active_sprites[id]
	if is_instance_valid(node):
		node.visible = false
		node.set_meta("seen", false)

## Preview placement as a structure Sprite2D.
func sync_place_ghost_sprite(kind: int, origin: Vector2, sprite_scale: float, tint: Color) -> bool:
	var tex: Texture2D = null
	if kind == Catalog.BLD_FLOWER or kind == Catalog.BLD_ROUND:
		tex = host.structure_tex.structure_anim_texture(kind, 0)
	if tex == null:
		tex = host.structure_tex.idle_structure_texture(kind)
	if tex == null:
		hide_place_ghost_sprite()
		return false
	if host._place_ghost_sprite == null or not is_instance_valid(host._place_ghost_sprite):
		host._place_ghost_sprite = Sprite2D.new()
		host._place_ghost_sprite.centered = true
		host._place_ghost_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		host.world_layer.add_child(host._place_ghost_sprite)
	host._place_ghost_sprite.texture = tex
	host._place_ghost_sprite.scale = Vector2(sprite_scale, sprite_scale)
	host._place_ghost_sprite.modulate = tint
	var screen_p = cam_rig.to_iso(iso.building_active_draw_at(kind, origin))
	host._place_ghost_sprite.position = screen_p + host.structure_tex.structure_sprite_lift(tex, sprite_scale)
	host._place_ghost_sprite.set_meta("sy", screen_p.y)
	host._place_ghost_sprite.visible = true
	host._place_ghost_sprite.set_meta("seen", true)
	return true

## Dismisses the structure Sprite2D preview shown during kit placement drag.
func hide_place_ghost_sprite() -> void:
	if host._place_ghost_sprite == null or not is_instance_valid(host._place_ghost_sprite):
		host._place_ghost_sprite = null
		return
	host._place_ghost_sprite.visible = false
	host._place_ghost_sprite.set_meta("seen", false)
