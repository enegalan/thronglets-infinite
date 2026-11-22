class_name ItemPhysics
extends RefCounted

const ITEM_GRAVITY := 520.0
const ITEM_RESTITUTION := 0.38
const ITEM_MIN_BOUNCE_VZ := 32.0
const ITEM_BOUNCE_H_DAMP := 0.62
const ITEM_AIR_DRAG := 0.9
const ITEM_GROUND_DRAG := 5.5
const ITEM_WALL_BOUNCE := 0.30
const ITEM_RADIUS := 5.5
const ITEM_PAIR_RESTITUTION := 0.34
const ITEM_THRONG_PUSH := 56.0
const ITEM_DROP_HEIGHT := 26.0
const ITEM_VOID_KILL_AIR := -84.0

var sim


func _init(sim_ref) -> void:
	sim = sim_ref


func has_physics(it: Dictionary) -> bool:
	return int(it.kind) != Catalog.ITEM_EGG and not bool(it.get("fixed", false))


func launch_item(it: Dictionary, air: float, vz: float, vx: float, vy: float) -> void:
	if it.is_empty():
		return
	it.air = maxf(0.0, air)
	it.vz = vz
	it.vx = vx
	it.vy = vy
	it.falling_void = false


func obstacle_blocked(px: float, py: float) -> bool:
	var cell: Vector2i = sim._cell_vec(px, py)
	var tile: int = sim._tile_at_cell(cell)
	if tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE:
		return true
	if sim.feature_cell.has(cell):
		var feat = sim.feature_by_id.get(int(sim.feature_cell[cell]), {})
		if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
			return true
	if sim.building_cell.has(cell):
		var b = sim.building_by_id.get(int(sim.building_cell[cell]), {})
		if not b.is_empty() and not b.dead and Catalog.building_blocks(int(b.kind)):
			return true
	return false


func tick_items(dt: float) -> void:
	var step_dt := minf(dt, 0.05)
	var phys_items: Array = []
	var frame_i := int(sim.frame_i)
	for it in sim.items:
		if it.dead or it.held:
			continue
		if int(it.kind) == Catalog.ITEM_EGG:
			sim._tick_egg(it, step_dt)
			continue
		if not has_physics(it):
			continue
		it.rest = maxf(0.0, float(it.get("rest", 0.0)) - step_dt)
		var kind := int(it.kind)
		if kind == Catalog.ITEM_BALL:
			it.life = maxf(0.0, float(it.get("life", sim.BALL_LIFE)) - step_dt)
			if float(it.life) <= 0.0:
				it.claimer = -1
				it.dead = true
				continue
			# Ambient fun near a resting ball; every 4 frames with scaled dose.
			if ((frame_i + int(it.id)) & 3) == 0:
				sim._boost(float(it.x), float(it.y), 28.0, 2, 0.0, 0.0, 80.0 * step_dt, 0.0)
		var air := float(it.get("air", 0.0))
		var vz := float(it.get("vz", 0.0))
		var vx := float(it.get("vx", 0.0))
		var vy := float(it.get("vy", 0.0))
		var falling_void := bool(it.get("falling_void", false))
		var moving := absf(vx) + absf(vy) > 0.05 or absf(vz) > 0.05 or air > 0.0 or falling_void or float(it.get("rest", 0.0)) > 0.0
		# Quiet ground piles: rare cliff/water check, skip collision passes.
		if not moving:
			if ((frame_i + int(it.id)) & 7) == 0:
				var ground: int = sim._tile_at_cell(sim._cell_vec(float(it.x), float(it.y)))
				if ground == Catalog.TILE_VOID or ground == Catalog.TILE_FOG:
					it.falling_void = true
					it.vz = -15.0
					it.claimer = -1
				elif ground == Catalog.TILE_WATER:
					sim._pop(float(it.x), float(it.y), AssetFrames.SPLASH)
					sim.sfx_queue.append("splash")
					it.claimer = -1
					it.dead = true
			continue
		if falling_void:
			vz -= ITEM_GRAVITY * step_dt
			air += vz * step_dt
			it.x = float(it.x) + vx * step_dt
			it.y = float(it.y) + vy * step_dt
			var void_drag := exp(-0.4 * step_dt)
			it.vx = vx * void_drag
			it.vy = vy * void_drag
			it.air = air
			it.vz = vz
			if air <= ITEM_VOID_KILL_AIR:
				it.claimer = -1
				it.dead = true
			continue
		# Horizontal integration (obstacle bounces are handled via smooth perimeter collision below).
		if absf(vx) > 0.05 or absf(vy) > 0.05:
			it.x = float(it.x) + vx * step_dt
			it.y = float(it.y) + vy * step_dt
		# Vertical gravity, ground bounce, and cliff-edge / water detection.
		if air > 0.0 or vz > 0.0:
			vz -= ITEM_GRAVITY * step_dt
			air += vz * step_dt
			if air <= 0.0:
				var tile: int = sim._tile_at_cell(sim._cell_vec(float(it.x), float(it.y)))
				if tile == Catalog.TILE_VOID or tile == Catalog.TILE_FOG:
					falling_void = true
					it.falling_void = true
					it.claimer = -1
				elif tile == Catalog.TILE_WATER:
					sim._pop(float(it.x), float(it.y), AssetFrames.SPLASH)
					sim.sfx_queue.append("splash")
					it.claimer = -1
					it.dead = true
					continue
				else:
					var impact := -vz
					if impact > ITEM_MIN_BOUNCE_VZ:
						air = maxf(0.05, -air * ITEM_RESTITUTION)
						vz = impact * ITEM_RESTITUTION
						vx *= ITEM_BOUNCE_H_DAMP
						vy *= ITEM_BOUNCE_H_DAMP
						if impact > 65.0 and kind == Catalog.ITEM_BALL:
							sim.sfx_queue.append("ball")
					else:
						air = 0.0
						vz = 0.0
		else:
			var ground2: int = sim._tile_at_cell(sim._cell_vec(float(it.x), float(it.y)))
			if ground2 == Catalog.TILE_VOID or ground2 == Catalog.TILE_FOG:
				it.falling_void = true
				it.vz = minf(vz, -15.0)
				it.claimer = -1
				continue
			elif ground2 == Catalog.TILE_WATER:
				sim._pop(float(it.x), float(it.y), AssetFrames.SPLASH)
				sim.sfx_queue.append("splash")
				it.claimer = -1
				it.dead = true
				continue
		var drag := exp(-(ITEM_AIR_DRAG if air > 0.0 else ITEM_GROUND_DRAG) * step_dt)
		vx *= drag
		vy *= drag
		if air <= 0.0 and absf(vx) + absf(vy) < 1.5:
			vx = 0.0
			vy = 0.0
		it.air = air
		it.vz = vz
		it.vx = vx
		it.vy = vy
		phys_items.append(it)
	if phys_items.is_empty():
		return
	_resolve_item_obstacle_collisions(phys_items)
	_resolve_item_collisions(phys_items)
	_resolve_thronglet_item_bumps(phys_items)


func _resolve_item_obstacle_collisions(phys_items: Array) -> void:
	for it in phys_items:
		if it.dead:
			continue
		var center_cell: Vector2i = sim._cell_vec(float(it.x), float(it.y))
		var boxes: Array = []
		var seen_feats := {}
		var seen_blds := {}
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var c: Vector2i = center_cell + Vector2i(ox, oy)
				if sim.feature_cell.has(c):
					var fid := int(sim.feature_cell[c])
					if not seen_feats.has(fid):
						seen_feats[fid] = true
						var feat = sim.feature_by_id.get(fid, {})
						if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
							var size: Vector2i = Catalog.footprint_for_feature(int(feat.kind))
							var bcenter: Vector2 = sim._cell_world(sim._cell_vec(float(feat.x), float(feat.y))) + Catalog.footprint_center(size)
							var is_tree := int(feat.kind) == Catalog.FEAT_TREE
							boxes.append({
								"cx": bcenter.x,
								"cy": bcenter.y,
								"hw": float(size.x) * float(Catalog.TILE) * 0.5,
								"hh": float(size.y) * float(Catalog.TILE) * 0.5,
								"top_h": 18.0 if is_tree else 16.0,
								"is_tree": is_tree,
							})
				if sim.building_cell.has(c):
					var bid := int(sim.building_cell[c])
					if not seen_blds.has(bid):
						seen_blds[bid] = true
						var b = sim.building_by_id.get(bid, {})
						if not b.is_empty() and not b.dead and Catalog.building_blocks(int(b.kind)):
							var size: Vector2i = Catalog.footprint_for_building(int(b.kind))
							var bcenter: Vector2 = sim._cell_world(sim._cell_vec(float(b.x), float(b.y))) + Catalog.footprint_center(size)
							var is_tree := int(b.kind) == Catalog.BLD_APPLE
							boxes.append({
								"cx": bcenter.x,
								"cy": bcenter.y,
								"hw": float(size.x) * float(Catalog.TILE) * 0.5,
								"hh": float(size.y) * float(Catalog.TILE) * 0.5,
								"top_h": 18.0 if is_tree else 22.0,
								"is_tree": is_tree,
							})
				var tile: int = sim._tile_at_cell(c)
				if tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE:
					var cw: Vector2 = sim._cell_world(c)
					boxes.append({
						"cx": cw.x,
						"cy": cw.y,
						"hw": float(Catalog.TILE) * 0.5,
						"hh": float(Catalog.TILE) * 0.5,
						"top_h": 16.0,
						"is_tree": false,
					})
		for box in boxes:
			var air := float(it.get("air", 0.0))
			if int(it.kind) == Catalog.ITEM_APPLE and bool(box.is_tree) and air > float(box.top_h):
				continue
			if air > float(box.top_h) + 2.0:
				continue
			var ox := float(box.cx)
			var oy := float(box.cy)
			var hw := float(box.hw)
			var hh := float(box.hh)
			var cx := clampf(float(it.x), ox - hw, ox + hw)
			var cy := clampf(float(it.y), oy - hh, oy + hh)
			var dx := float(it.x) - cx
			var dy := float(it.y) - cy
			var d2 := dx * dx + dy * dy
			if d2 >= ITEM_RADIUS * ITEM_RADIUS:
				continue
			var nx := 0.0
			var ny := 0.0
			if d2 < 0.0001:
				var rx := float(it.x) - ox
				var ry := float(it.y) - oy
				var rlen := sqrt(rx * rx + ry * ry)
				if rlen < 0.5:
					var ang := randf() * TAU
					nx = cos(ang)
					ny = sin(ang)
				else:
					nx = rx / rlen
					ny = ry / rlen
				var edge_dist := minf(hw / maxf(0.001, absf(nx)), hh / maxf(0.001, absf(ny))) + ITEM_RADIUS * 0.65
				it.x = ox + nx * edge_dist
				it.y = oy + ny * edge_dist
				var impact_vz := absf(float(it.get("vz", 0.0)))
				it.vz = maxf(float(it.get("vz", 0.0)), impact_vz * 0.45 + 52.0)
				it.air = maxf(air, 1.0)
				it.vx = float(it.get("vx", 0.0)) + nx * 42.0
				it.vy = float(it.get("vy", 0.0)) + ny * 42.0
				if int(it.kind) == Catalog.ITEM_BALL:
					sim.sfx_queue.append("ball")
			else:
				var d := sqrt(d2)
				nx = dx / d
				ny = dy / d
				it.x = cx + nx * ITEM_RADIUS
				it.y = cy + ny * ITEM_RADIUS
				var vx := float(it.get("vx", 0.0))
				var vy := float(it.get("vy", 0.0))
				var vn := vx * nx + vy * ny
				if vn < 0.0:
					var bounce := maxf(ITEM_WALL_BOUNCE, 0.55)
					vx -= (1.0 + bounce) * vn * nx
					vy -= (1.0 + bounce) * vn * ny
					it.vx = vx
					it.vy = vy
					var speed_in := -vn
					if speed_in > 18.0 or float(it.get("vz", 0.0)) < -18.0:
						it.vz = maxf(float(it.get("vz", 0.0)), absf(float(it.get("vz", 0.0))) * 0.35 + minf(54.0, speed_in * 0.45 + 22.0))
						it.air = maxf(air, 0.6)
						if int(it.kind) == Catalog.ITEM_BALL and speed_in > 28.0:
							sim.sfx_queue.append("ball")


func _resolve_item_collisions(phys_items: Array) -> void:
	var n := phys_items.size()
	var min_d := ITEM_RADIUS * 2.0
	var min_d2 := min_d * min_d
	for a_idx in n:
		var a: Dictionary = phys_items[a_idx]
		if a.dead:
			continue
		for b_idx in range(a_idx + 1, n):
			var b: Dictionary = phys_items[b_idx]
			if b.dead:
				continue
			var air_a := float(a.get("air", 0.0))
			var air_b := float(b.get("air", 0.0))
			if absf(air_a - air_b) > 11.0:
				continue
			var dx := float(b.x) - float(a.x)
			var dy := float(b.y) - float(a.y)
			var d2 := dx * dx + dy * dy
			if d2 >= min_d2:
				continue
			var nx := 1.0
			var ny := 0.0
			var d := 0.0
			if d2 < 0.0001:
				var ang := randf() * TAU
				nx = cos(ang)
				ny = sin(ang)
			else:
				d = sqrt(d2)
				nx = dx / d
				ny = dy / d
			var push := (min_d - d) * 0.5
			var ax_new := float(a.x) - nx * push
			var ay_new := float(a.y) - ny * push
			var bx_new := float(b.x) + nx * push
			var by_new := float(b.y) + ny * push
			if air_a > 12.0 or not obstacle_blocked(ax_new, ay_new):
				a.x = ax_new
				a.y = ay_new
			if air_b > 12.0 or not obstacle_blocked(bx_new, by_new):
				b.x = bx_new
				b.y = by_new
			var avx := float(a.get("vx", 0.0))
			var avy := float(a.get("vy", 0.0))
			var bvx := float(b.get("vx", 0.0))
			var bvy := float(b.get("vy", 0.0))
			var rvn := (bvx - avx) * nx + (bvy - avy) * ny
			if rvn < 0.0:
				var imp := -(1.0 + ITEM_PAIR_RESTITUTION) * rvn * 0.5
				avx -= imp * nx
				avy -= imp * ny
				bvx += imp * nx
				bvy += imp * ny
			# Vertical drop onto another item gently separates and softly bounces both apart
			var avz := float(a.get("vz", 0.0))
			var bvz := float(b.get("vz", 0.0))
			var scatter := 26.0 * ITEM_PAIR_RESTITUTION
			if air_a > air_b + 1.5 and avz < -20.0:
				a.vz = maxf(avz, absf(avz) * (0.2 + 0.3 * ITEM_PAIR_RESTITUTION) + 20.0 * ITEM_PAIR_RESTITUTION)
				b.vz = maxf(bvz, 18.0 * ITEM_PAIR_RESTITUTION)
				b.air = maxf(air_b, 0.3)
				avx -= nx * scatter
				avy -= ny * scatter
				bvx += nx * scatter
				bvy += ny * scatter
			elif air_b > air_a + 1.5 and bvz < -20.0:
				b.vz = maxf(bvz, absf(bvz) * (0.2 + 0.3 * ITEM_PAIR_RESTITUTION) + 20.0 * ITEM_PAIR_RESTITUTION)
				a.vz = maxf(avz, 18.0 * ITEM_PAIR_RESTITUTION)
				a.air = maxf(air_a, 0.3)
				avx -= nx * scatter
				avy -= ny * scatter
				bvx += nx * scatter
				bvy += ny * scatter
			elif d < min_d * 0.75:
				var nudge := 12.0 * ITEM_PAIR_RESTITUTION
				avx -= nx * nudge
				avy -= ny * nudge
				bvx += nx * nudge
				bvy += ny * nudge
			a.vx = avx
			a.vy = avy
			b.vx = bvx
			b.vy = bvy


func _resolve_thronglet_item_bumps(phys_items: Array) -> void:
	for it in phys_items:
		if it.dead or int(it.kind) != Catalog.ITEM_BALL or float(it.get("air", 0.0)) > 10.0 or float(it.get("rest", 0.0)) > 0.0:
			continue
		var ix := float(it.x)
		var iy := float(it.y)
		for raw in sim.query_radius(ix, iy, 12.0):
			var tid := int(raw)
			if tid < 0 or tid >= sim.slot_count or sim.state[tid] != Catalog.ST_LIVING:
				continue
			if absf(sim.dir_x[tid]) + absf(sim.dir_y[tid]) <= 0.1:
				continue
			var dx: float = ix - sim.pos_x[tid]
			var dy: float = iy - sim.pos_y[tid]
			var d2: float = dx * dx + dy * dy
			if d2 >= 90.25:
				continue
			var dir := Vector2(dx, dy)
			if dir.length_squared() < 0.25:
				dir = Vector2(sim.dir_x[tid], sim.dir_y[tid])
			else:
				dir = (dir.normalized() + Vector2(sim.dir_x[tid], sim.dir_y[tid]) * 0.5).normalized()
			it.vx = dir.x * ITEM_THRONG_PUSH
			it.vy = dir.y * ITEM_THRONG_PUSH
			it.vz = maxf(float(it.get("vz", 0.0)), 68.0)
			it.air = maxf(float(it.get("air", 0.0)), 0.5)
			it.rest = 0.35
			sim.amused[tid] = minf(100.0, sim.amused[tid] + sim.BALL_KICK_FUN * 0.5)
			sim.sfx_queue.append("ball")
			break
