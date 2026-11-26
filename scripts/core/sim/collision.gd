class_name SimCollision
extends RefCounted

## Tile blocking, movement collision, pads, and cell helpers.

var sim


## Stores the simulation server used for collision queries.
func _init(sim_ref) -> void:
	sim = sim_ref

## Agent has at most one open neighbor — considered geometrically trapped.
func _corner_trap(i: int) -> bool:
	# Truly boxed in — a 1-tile corridor still has 2+ opens and must stay walkable.
	var open = 0
	for n in 8:
		var a = float(n) * TAU * 0.125
		if not _move_blocked(sim.pos_x[i] + cos(a) * 8.0, sim.pos_y[i] + sin(a) * 8.0):
			open += 1
	return open <= 1



## Nudge or teleport stuck agents toward clear space along open axes.
func _unstick(i: int) -> void:
	var prefer = sim.agent_move._shore_push(i)
	if prefer == Vector2.ZERO:
		prefer = sim.agent_move._inland_dir(i)
	var step = sim.agent_move._open_dir(i, prefer)
	if step == Vector2.ZERO:
		step = sim.agent_move._open_dir(i, sim.agent_move._inland_dir(i))
	var back = Vector2(-sim.dir_x[i], -sim.dir_y[i])
	if back.length_squared() > 0.2:
		back = back.normalized()
	else:
		back = Vector2.ZERO
	var candidates: Array[Vector2] = []
	if step != Vector2.ZERO:
		candidates.append(step)
	if prefer != Vector2.ZERO:
		candidates.append(prefer)
	for n in 16:
		var a = float(n) * (TAU / 16.0)
		candidates.append(Vector2(cos(a), sin(a)))
	var try_dist: Array[float] = [48.0, 40.0, 32.0, 24.0, 20.0, 16.0, 12.0, 10.0, 8.0, 6.0, 4.0]
	for dist in try_dist:
		var best = Vector2.ZERO
		var best_run = -1.0
		for cand in candidates:
			var nx: float = sim.pos_x[i] + cand.x * dist
			var ny: float = sim.pos_y[i] + cand.y * dist
			if _move_blocked(nx, ny):
				continue
			# Destination-only checks teleported through tree walls (enclosure escape).
			if not sim.agent_move._axis_clear(sim.pos_x[i], sim.pos_y[i], nx, ny):
				continue
			var run = _clear_run_at(nx, ny, cand.x, cand.y)
			var score = run + cand.dot(prefer) * 6.0 - cand.dot(back) * 10.0
			if score > best_run:
				best_run = score
				best = cand
		if best != Vector2.ZERO:
			sim.pos_x[i] = sim.pos_x[i] + best.x * dist
			sim.pos_y[i] = sim.pos_y[i] + best.y * dist
			sim.dir_x[i] = best.x
			sim.dir_y[i] = best.y
			sim.wander_t[i] = randf_range(0.7, 1.6)
			if i < sim.seek_t.size():
				sim.seek_t[i] = 0.0
			sim.spatial._hash_relocate(i)
			return
	for ring in range(1, 9):
		var rad = float(ring) * 8.0
		for n in 16:
			var a = float(n) * (TAU / 16.0)
			var nx2 = sim.pos_x[i] + cos(a) * rad
			var ny2 = sim.pos_y[i] + sin(a) * rad
			if _move_blocked(nx2, ny2):
				continue
			if not sim.agent_move._axis_clear(sim.pos_x[i], sim.pos_y[i], nx2, ny2):
				continue
			sim.pos_x[i] = nx2
			sim.pos_y[i] = ny2
			sim.dir_x[i] = cos(a)
			sim.dir_y[i] = sin(a)
			sim.wander_t[i] = randf_range(0.7, 1.6)
			if i < sim.seek_t.size():
				sim.seek_t[i] = 0.0
			sim.spatial._hash_relocate(i)
			return
	sim.wander_t[i] = 0.0



## Walkable distance along a ray before a blocker is hit (unstick scoring).
func _clear_run_at(px: float, py: float, dx: float, dy: float) -> float:
	var clear = 0.0
	var step = 8.0
	while clear + step <= 32.0:
		if _move_blocked(px + dx * (clear + step), py + dy * (clear + step)):
			return clear
		clear += step
	return 32.0



## Whether world point is on holdable ground (not void/water/fog).
func _tile_holds(px: float, py: float) -> bool:
	return _tile_holds_cell(sim.spatial._cell_vec(px, py))



## Tile type counts as solid ground for building and walking.
func _tile_holds_kind(tile: int) -> bool:
	return tile != Catalog.TILE_VOID and tile != Catalog.TILE_WATER and tile != Catalog.TILE_FOG



## Grid cell uses holdable ground for footprints and inland checks.
func _tile_holds_cell(cell: Vector2i) -> bool:
	return _tile_holds_kind(_tile_at_cell(cell))



## Invalidate inland cache for a cell and its Moore neighbors.
func _invalidate_inland_around(cell: Vector2i) -> void:
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			sim.inland_cache.erase(cell + Vector2i(ox, oy))



## World point sits on inland ground for buildings/rooted props (not agent walk).
func _land_inland(px: float, py: float) -> bool:
	return _land_inland_cell(sim.spatial._cell_vec(px, py))



## Cached Moore-neighbor pad so buildings/props avoid hanging over void/water.
func _land_inland_cell(cell: Vector2i) -> bool:
	# Center must hold, and no Moore neighbor may be void/water/fog.
	# Agents may still walk the shore/map-edge lip; this pad is placement-only.
	if sim.inland_cache.has(cell):
		return bool(sim.inland_cache[cell])
	var ok = true
	if not _tile_holds_cell(cell):
		ok = false
	else:
		for oy in range(-1, 2):
			if not ok:
				break
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				if not _tile_holds_cell(cell + Vector2i(ox, oy)):
					ok = false
					break
	sim.inland_cache[cell] = ok
	return ok



## Feature kinds auto-cleared when a building pad claims their cells.
func _pad_feature_soft(kind: int) -> bool:
	# Cleared when a building claims the pad. Ore nodes and monuments stay hard.
	return kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP \
		or kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK or kind == Catalog.FEAT_FLOWER \
		or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD or kind == Catalog.FEAT_FIRE



## Item kinds auto-removed when a building pad claims their cells.
func _pad_item_soft(kind: int) -> bool:
	# Ground clutter claimed with the pad. Ore / TNT / eggs stay hard.
	return kind == Catalog.ITEM_WOOD or kind == Catalog.ITEM_APPLE \
		or kind == Catalog.ITEM_BALL or kind == Catalog.ITEM_BONE



## Whether a hard item at a point blocks building pad placement.
func _pad_item_blocks(x: float, y: float, ignore_id: int = -1) -> bool:
	var other = sim.world_entities._item_at(x, y, 10.0)
	if other.is_empty() or int(other.id) == ignore_id:
		return false
	return not _pad_item_soft(int(other.kind))



## Kill soft features and items occupying cells in a building footprint.
func _clear_pad_soft(cells: Array[Vector2i]) -> void:
	# Pad claim only clears blockers. Wood comes from the axe, not from placement.
	var seen = {}
	var seen_item = {}
	for cell in cells:
		var fid = int(sim.feature_cell.get(cell, -1))
		if fid >= 0 and not seen.has(fid):
			seen[fid] = true
			var feat = sim.feature_by_id.get(fid, {})
			if not feat.is_empty() and not feat.dead and _pad_feature_soft(int(feat.kind)):
				sim.world_entities._kill_feature(feat)
		var at = sim.world_entities._cell_world(cell)
		var it = sim.world_entities._item_at(at.x, at.y, 10.0)
		if it.is_empty():
			continue
		var iid = int(it.id)
		if seen_item.has(iid) or it.dead or it.held:
			continue
		if not _pad_item_soft(int(it.kind)):
			continue
		seen_item[iid] = true
		it.dead = true
	if not seen_item.is_empty():
		sim.world_entities._invalidate_item_counts()



## Point probe for terrain, features, and buildings that block solid placement.
func _blocked(px: float, py: float, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	return _blocked_cell(sim.spatial._cell_vec(px, py), allow_ore, allow_soft)



## Cell blocking with ore-node walk exceptions and soft cosmetic pads.
func _blocked_cell(cell: Vector2i, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	var tile = _tile_at_cell(cell)
	if Catalog.tile_blocks(tile):
		return true
	if sim.feature_cell.has(cell):
		var feat = sim.feature_by_id.get(int(sim.feature_cell[cell]), {})
		if not feat.is_empty() and not feat.dead and Catalog.feature_blocks(int(feat.kind)):
			# Mine zones (ore nodes) are ground zones: walkable surface exception.
			if sim.building_sim._ore_tier(int(feat.kind)) > 0:
				return false
			if allow_soft and _pad_feature_soft(int(feat.kind)):
				return false
			return true
	if sim.building_cell.has(cell):
		var b = sim.building_by_id.get(int(sim.building_cell[cell]), {})
		if not b.is_empty() and not b.dead and Catalog.building_blocks(int(b.kind)):
			return true
	return false



## Whether world coordinates lie on a mine footprint walk pad.
func _on_mine_pad(px: float, py: float) -> bool:
	return _on_mine_pad_cell(sim.spatial._cell_vec(px, py))



## Cell-level mine pad test used by movement blocking exceptions.
func _on_mine_pad_cell(cell: Vector2i) -> bool:
	# Mine footprints are walkable ground pads above terrain.
	if sim.blds_mine.is_empty() or not sim.building_cell.has(cell):
		return false
	var b = sim.building_by_id.get(int(sim.building_cell[cell]), {})
	if b.is_empty() or b.dead:
		return false
	var kind = int(b.kind)
	return kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2



## Agent path blocking: pads, terrain/feature blocks, and save perf counters.
func _move_blocked(px: float, py: float) -> bool:
	if sim.save_perf_mode:
		sim.set_meta("_ap_move_n", int(sim.get_meta("_ap_move_n", 0)) + 1)
	var cell = sim.spatial._cell_vec(px, py)
	# Mine zones are walkable ground pads (exception): treat as passable ground
	# above terrain, ignoring pad footprint/feature hitboxes. Without a mine,
	# the ore/node feature remains and blocks in _blocked as usual.
	if _on_mine_pad_cell(cell):
		return Catalog.tile_blocks(_tile_at_cell(cell))
	# Shore / map-edge lip is walkable so agents can
	# reach items that land there. Inland pad stays for buildings/rooted props.
	return _blocked_cell(cell)



## Carousel walk test allowing only the painted ride disk and pad cells.
func _ride_spot_blocked(px: float, py: float, ride_b: Dictionary) -> bool:
	# Riders stand on their own pad / painted disk. Everything else still blocks.
	var cell = sim.spatial._cell_vec(px, py)
	if sim.building_cell.has(cell) and int(sim.building_cell[cell]) == int(ride_b.id):
		var tile = _tile_at(px, py)
		return Catalog.tile_blocks(tile)
	# Seat ring can sit a few px past the 2x2 cell pad; still treat as the ride.
	var mid = sim.agent_tick._ride_center_of(ride_b)
	var dx = px - mid.x
	var dy = py - mid.y
	var lim = sim.agent_tick._ride_radius(ride_b) + 3.0
	if dx * dx + dy * dy <= lim * lim:
		return Catalog.tile_blocks(_tile_at(px, py))
	return _move_blocked(px, py)



## Walkable stand on a circular approach ring around a world point.
func _approach_spot(x: float, y: float, radius: float, who: int = -1) -> Vector2:
	return _approach_ellipse(x, y, radius, radius, who)



## Walkable gate on the building reach ellipse for seek and work entry.
func _approach_building(b: Dictionary, who: int = -1) -> Vector2:
	var center = sim.agent_tick._footprint_center_of(b)
	var reach = Catalog.building_reach(int(b.kind))
	return _approach_ellipse(center.x, center.y, reach.x, reach.y, who)



## Point-in-ellipse test for at-building interactions and occupancy.
func _inside_building_reach(px: float, py: float, b: Dictionary) -> bool:
	var center = sim.agent_tick._footprint_center_of(b)
	var reach = Catalog.building_reach(int(b.kind))
	var rx = maxf(reach.x, 0.01)
	var ry = maxf(reach.y, 0.01)
	var u = (px - center.x) / rx
	var v = (py - center.y) / ry
	return u * u + v * v <= 1.0



## Samples an ellipse for the nearest unblocked stand tile toward an agent.
func _approach_ellipse(x: float, y: float, rx: float, ry: float, who: int = -1) -> Vector2:
	var best = Vector2(x, y)
	var best_d = 1.0e9
	var from = Vector2(x, y)
	if who >= 0 and who < sim.slot_count:
		from = Vector2(sim.pos_x[who], sim.pos_y[who])
	var ax = maxf(rx, 1.0)
	var ay = maxf(ry, 1.0)
	for n in 12:
		var ang = float(n) * (TAU / 12.0)
		var px = x + cos(ang) * ax
		var py = y + sin(ang) * ay
		if _move_blocked(px, py):
			continue
		var d = from.distance_squared_to(Vector2(px, py))
		if d < best_d:
			best_d = d
			best = Vector2(px, py)
	if best_d < 1.0e9:
		return best
	for grow in 2:
		var extra = 8.0 * float(grow + 1)
		for n in 12:
			var ang = float(n) * (TAU / 12.0)
			var px = x + cos(ang) * (ax + extra)
			var py = y + sin(ang) * (ay + extra)
			if _move_blocked(px, py):
				continue
			return Vector2(px, py)
	return best



## Surface tile at world pixels, including fog outside revealed chunks.
func _tile_at(px: float, py: float) -> int:
	return _tile_at_cell(sim.spatial._cell_vec(px, py))



## Chunk-local surface tile lookup with lazy chunk allocation.
func _tile_at_cell(cell: Vector2i) -> int:
	var chunk_x = sim.spatial._floor_div(cell.x, Catalog.CHUNK)
	var chunk_y = sim.spatial._floor_div(cell.y, Catalog.CHUNK)
	var ck = sim.spatial._ck(chunk_x, chunk_y)
	if not sim.revealed.has(ck):
		return Catalog.TILE_FOG
	var ch = sim.chunks.get(ck)
	if ch == null:
		sim.world_entities._ensure(chunk_x, chunk_y)
		ch = sim.chunks.get(ck)
		if ch == null:
			return Catalog.TILE_FOG
	var lx = cell.x - chunk_x * Catalog.CHUNK
	var ly = cell.y - chunk_y * Catalog.CHUNK
	return int(ch.tiles[ly * Catalog.CHUNK + lx])



## Underlying base terrain tile beneath the painted surface layer.
func _base_at(px: float, py: float) -> int:
	var c = sim.spatial._chunk_at(px, py)
	var ck = sim.spatial._ck(c.x, c.y)
	if not sim.chunks.has(ck):
		return Catalog.TILE_DIRT
	var local = sim.spatial._local_cell(px, py)
	return int(sim.chunks[ck].base[local.y * Catalog.CHUNK + local.x])



## Writes a tile into the chunk grid and invalidates inland, walk, and goo caches.
func _set_world_cell(cx: int, cy: int, tile: int, also_base: bool) -> void:
	var chunk_x = sim.spatial._floor_div(cx, Catalog.CHUNK)
	var chunk_y = sim.spatial._floor_div(cy, Catalog.CHUNK)
	var ck = sim.spatial._ck(chunk_x, chunk_y)
	if not sim.revealed.has(ck):
		return
	sim.world_entities._ensure(chunk_x, chunk_y)
	var lx = cx - chunk_x * Catalog.CHUNK
	var ly = cy - chunk_y * Catalog.CHUNK
	_set_local_tile(ck, lx, ly, tile, also_base)



## Low-level chunk tile write that marks chunk dirty and refreshes derived caches.
func _set_local_tile(ck: String, lx: int, ly: int, tile: int, also_base: bool) -> void:
	if not sim.chunks.has(ck):
		return
	var idx = ly * Catalog.CHUNK + lx
	var prev = int(sim.chunks[ck].tiles[idx])
	sim.chunks[ck].tiles[idx] = tile
	if also_base:
		sim.chunks[ck].base[idx] = tile
	if prev != tile:
		var c = sim.spatial._parse_ck(ck)
		_invalidate_inland_around(Vector2i(c.x * Catalog.CHUNK + lx, c.y * Catalog.CHUNK + ly))
		sim.world_entities._invalidate_walk_cells()
		if prev == Catalog.TILE_GOO or tile == Catalog.TILE_GOO:
			sim.building_sim._invalidate_building_pollution()
	sim.spatial._mark_dirty(ck)



