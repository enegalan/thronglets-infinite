class_name SimSpatial
extends RefCounted

## Spatial hash, chunk queries, and client pull helpers.

var sim


## Stores the simulation server used for spatial queries.
func _init(sim_ref) -> void:
	sim = sim_ref

## Tells the renderer whether a chunk key has left fog and has terrain data.
func chunk_shown(ck: String) -> bool:
	return sim.revealed.has(ck)



## True when world coordinates sit on a revealed island home chunk (spawn chunk semantics).
func chunk_at_home(x: float, y: float) -> bool:
	var c = _chunk_at(x, y)
	var key = _ck(c.x, c.y)
	return sim.revealed.has(key) and sim.island_gen.is_island_chunk(c.x, c.y)



## Resolves world coordinates to the chunk string key used in reveal and paint maps.
func chunk_key_at(x: float, y: float) -> String:
	var c = _chunk_at(x, y)
	return _ck(c.x, c.y)



## Reveals every island chunk overlapping a camera or brush rectangle for fog-of-war.
func explore_rect(rect: Rect2) -> void:
	if rect.size == Vector2.ZERO:
		return
	var size = float(Catalog.TILE * Catalog.CHUNK)
	var x0 = int(floor(rect.position.x / size))
	var y0 = int(floor(rect.position.y / size))
	var x1 = int(floor(rect.end.x / size))
	var y1 = int(floor(rect.end.y / size))
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			sim.world_entities._try_reveal(cx, cy)



## Spatial hash query over an axis-aligned view box; optional cap for AI sampling density.
func query_rect(rect: Rect2, limit: int = 0) -> Array:
	# AABB over hash cells — circle(half.diagonal) massively over-included at wide zooms.
	# limit > 0 stops early (AI priority / density sampling).
	var out: Array = []
	if sim.hash_head.is_empty() or rect.size == Vector2.ZERO:
		return out
	var pad = 8.0
	var x0 = int(floor((rect.position.x - pad) / Catalog.HASH_CELL))
	var y0 = int(floor((rect.position.y - pad) / Catalog.HASH_CELL))
	var x1 = int(floor((rect.end.x + pad) / Catalog.HASH_CELL))
	var y1 = int(floor((rect.end.y + pad) / Catalog.HASH_CELL))
	var hit = Rect2(rect.position - Vector2(pad, pad), rect.size + Vector2(pad * 2.0, pad * 2.0))
	var seen_bucket = {}
	for oy in range(y0, y1 + 1):
		for ox in range(x0, x1 + 1):
			var bucket = _bucket_cell(ox, oy)
			if seen_bucket.has(bucket):
				continue
			seen_bucket[bucket] = true
			var i = sim.hash_head[bucket]
			var guard = 0
			while i != -1 and guard < sim.slot_count + 2:
				guard += 1
				if i >= 0 and i < sim.slot_count and sim.state[i] != Catalog.ST_VACANT:
					if hit.has_point(Vector2(sim.pos_x[i], sim.pos_y[i])):
						out.append(i)
						if limit > 0 and out.size() >= limit:
							return out
				i = sim.hash_next[i] if i >= 0 and i < sim.hash_next.size() else -1
	return out



## Returns agent slot ids within a circle using hash buckets, deduping bucket visits.
func query_radius(x: float, y: float, radius: float) -> Array:
	var out: Array = []
	if sim.hash_head.is_empty():
		return out
	var reach = int(ceil(radius / Catalog.HASH_CELL))
	var cx = int(floor(x / Catalog.HASH_CELL))
	var cy = int(floor(y / Catalog.HASH_CELL))
	var r2 = radius * radius
	var seen_bucket = {}
	for oy in range(cy - reach, cy + reach + 1):
		for ox in range(cx - reach, cx + reach + 1):
			var bucket = _bucket_cell(ox, oy)
			if seen_bucket.has(bucket):
				continue
			seen_bucket[bucket] = true
			var i = sim.hash_head[bucket]
			var guard = 0
			while i != -1 and guard < sim.slot_count + 2:
				guard += 1
				if i >= 0 and i < sim.slot_count and sim.state[i] != Catalog.ST_VACANT:
					var dx = sim.pos_x[i] - x
					var dy = sim.pos_y[i] - y
					if dx * dx + dy * dy <= r2:
						out.append(i)
				i = sim.hash_next[i] if i >= 0 and i < sim.hash_next.size() else -1
	return out



## Picks the nearest agent under the cursor for tools, preferring living over corpses when allowed.
func find_thronglet(x: float, y: float, radius: float, living_only: bool) -> int:
	var ids = query_radius(x, y, radius)
	var best_live = -1
	var best_dead = -1
	var live_d = radius * radius
	var dead_d = radius * radius
	for id in ids:
		var dx = sim.pos_x[int(id)] - x
		var dy = sim.pos_y[int(id)] - y
		var d = dx * dx + dy * dy
		if sim.state[int(id)] == Catalog.ST_LIVING and d <= live_d:
			live_d = d
			best_live = int(id)
		elif sim.state[int(id)] == Catalog.ST_DEAD and d <= dead_d:
			dead_d = d
			best_dead = int(id)
	if living_only:
		return best_live
	if best_live >= 0:
		return best_live
	return best_dead



## Drains the one-shot narrative note queue to the HUD and clears it for the next frame.
func take_notes() -> Array:
	var copy = sim.notes.duplicate()
	sim.notes.clear()
	return copy



## Drains pending sound cue ids accumulated during the sim step for the audio layer.
func take_sfx() -> Array:
	var copy = sim.sfx_queue.duplicate()
	sim.sfx_queue.clear()
	return copy



## Hands off chunk keys that need terrain repaint this frame, then clears the dirty set.
func take_dirty() -> Array:
	var copy = sim.dirty_chunks.duplicate()
	sim.dirty_chunks.clear()
	return copy



## Returns packed tile ids for a loaded chunk, or empty if the chunk is not materialized.
func chunk_tiles(ck: String) -> PackedByteArray:
	if not sim.chunks.has(ck):
		return PackedByteArray()
	return sim.chunks[ck].tiles



## Tile-space origin of a chunk from its string key for aligning tilemaps and props.
func chunk_origin(ck: String) -> Vector2i:
	var c = _parse_ck(ck)
	return Vector2i(c.x * Catalog.CHUNK, c.y * Catalog.CHUNK)



## Removes an agent from its spatial hash bucket linked list.
func _hash_unlink(i: int) -> void:
	if i < 0 or i >= sim.hash_cell.size():
		return
	var b = sim.hash_cell[i]
	if b < 0:
		return
	var prev = -1
	var cur = sim.hash_head[b]
	var guard = 0
	while cur != -1 and guard < sim.slot_count + 2:
		guard += 1
		if cur == i:
			if prev < 0:
				sim.hash_head[b] = sim.hash_next[i]
			else:
				sim.hash_next[prev] = sim.hash_next[i]
			break
		prev = cur
		cur = sim.hash_next[cur] if cur >= 0 and cur < sim.hash_next.size() else -1
	sim.hash_cell[i] = -1
	sim.hash_next[i] = -1



## Inserts an agent into the hash grid bucket for query_radius lookups.
func _hash_link(i: int) -> void:
	if i < 0 or i >= sim.slot_count or sim.state[i] == Catalog.ST_VACANT:
		return
	var b = _bucket(sim.pos_x[i], sim.pos_y[i])
	if i >= sim.hash_cell.size():
		return
	sim.hash_cell[i] = b
	sim.hash_next[i] = sim.hash_head[b]
	sim.hash_head[b] = i



## Re-buckets an agent after movement crosses a hash cell boundary.
func _hash_relocate(i: int) -> void:
	if i < 0 or i >= sim.hash_cell.size():
		return
	if sim.state[i] == Catalog.ST_VACANT:
		_hash_unlink(i)
		return
	var b = _bucket(sim.pos_x[i], sim.pos_y[i])
	if sim.hash_cell[i] == b:
		return
	_hash_unlink(i)
	_hash_link(i)



## Updates agent coordinates and refreshes spatial hash indexing.
func _set_agent_pos(i: int, x: float, y: float) -> void:
	if i < 0 or i >= sim.slot_count:
		return
	sim.pos_x[i] = x
	sim.pos_y[i] = y
	_hash_relocate(i)



## Rebuilds the full agent spatial hash after load or shot sandbox resets.
func _rebuild_hash() -> void:
	if sim.hash_cell.size() != sim.slot_count:
		sim.hash_cell.resize(sim.slot_count)
	if sim.hash_next.size() != sim.slot_count:
		sim.hash_next.resize(sim.slot_count)
	sim.hash_head.fill(-1)
	sim.hash_cell.fill(-1)
	sim.hash_next.fill(-1)
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT:
			continue
		_hash_link(i)



## Deterministic chunk-local RNG float seeded from world seed and coordinates.
func _rand(cx: int, cy: int, lx: int, ly: int, salt: int) -> float:
	sim._rng.seed = int(sim.world_seed) ^ (cx * 83492791) ^ (cy * 19349663) ^ (lx * 97) ^ (ly * 57) ^ (salt * 131)
	return sim._rng.randf()



## Spatial hash bucket index for a world position.
func _bucket(px: float, py: float) -> int:
	return _bucket_cell(int(floor(px / Catalog.HASH_CELL)), int(floor(py / Catalog.HASH_CELL)))



## Hash bucket from pre-quantized hash cell coordinates.
func _bucket_cell(cx: int, cy: int) -> int:
	return (cx * 73856093 ^ cy * 19349663) & (Catalog.HASH_SIZE - 1)



## Maps world position to chunk grid indices.
func _chunk_at(px: float, py: float) -> Vector2i:
	return Vector2i(_floor_div(_cell_of(px), Catalog.CHUNK), _floor_div(_cell_of(py), Catalog.CHUNK))



## Chunk dictionary key string for a world point.
func _ck_of(px: float, py: float) -> String:
	var c = _chunk_at(px, py)
	return _ck(c.x, c.y)



## Intra-chunk tile offset for a world position.
func _local_cell(px: float, py: float) -> Vector2i:
	var c = _chunk_at(px, py)
	return Vector2i(_cell_of(px) - c.x * Catalog.CHUNK, _cell_of(py) - c.y * Catalog.CHUNK)



## Converts world pixels to integer tile cell coordinates.
func _cell_vec(px: float, py: float) -> Vector2i:
	return Vector2i(_cell_of(px), _cell_of(py))



## Converts one world axis coordinate to a tile index.
func _cell_of(p: float) -> int:
	return int(floor(p / float(Catalog.TILE)))



## Floor division that behaves correctly for negative chunk indexing.
func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))



## World-space center of a chunk for camera and spawn math.
func _chunk_center(cx: int, cy: int) -> Vector2:
	var size = float(Catalog.CHUNK * Catalog.TILE)
	return Vector2(float(cx) * size + size * 0.5, float(cy) * size + size * 0.5)



## Formats chunk coordinates as the chunks dictionary key.
func _ck(cx: int, cy: int) -> String:
	return "%d,%d" % [cx, cy]



## Parses a chunk key string back into chunk grid indices.
func _parse_ck(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))



## Positive modular arithmetic for wrapping indices.
func _pmod(a: int, m: int) -> int:
	var r = a % m
	if r < 0:
		r += m
	return r



## Distance from agent slot i to a world point.
func _dist_i(i: int, x: float, y: float) -> float:
	var dx = sim.pos_x[i] - x
	var dy = sim.pos_y[i] - y
	return sqrt(dx * dx + dy * dy)



## Euclidean distance between two world points.
func _dist_point(x0: float, y0: float, x1: float, y1: float) -> float:
	var dx = x0 - x1
	var dy = y0 - y1
	return sqrt(dx * dx + dy * dy)



## Flags a chunk key for renderer and sync dirty propagation.
func _mark_dirty(ck: String) -> void:
	if not sim.dirty_chunks.has(ck):
		sim.dirty_chunks.append(ck)



## Coerces serialized arrays to PackedFloat32Array for agent stat columns.
func _as_f32(value) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value
	var out = PackedFloat32Array()
	if value == null:
		return out
	for v in value:
		out.append(float(v))
	return out



## Coerces serialized arrays to PackedInt32Array for integral agent fields.
func _as_i32(value) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value
	var out = PackedInt32Array()
	if value == null:
		return out
	for v in value:
		out.append(int(v))
	return out



