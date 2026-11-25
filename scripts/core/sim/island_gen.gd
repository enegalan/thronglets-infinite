class_name IslandGen
extends RefCounted

# Home-island shape, water, prop scatter, and mine-node seeding.

var sim


## Binds this helper to the live simulation server instance.
func _init(sim_ref) -> void:
	sim = sim_ref


## World-space center X/Y used as the home island anchor.
func island_mid() -> float:
	return 256.0


## Base shoreline radius before land-tier expansion.
func island_reach() -> float:
	return 170.0 + float(sim.land_tier) * 48.0


## Width and height of one terrain chunk in world units.
func chunk_size_world() -> float:
	return float(Catalog.CHUNK * Catalog.TILE)


## True when a chunk overlaps the island footprint disk.
func chunk_intersects_disk(cx: int, cy: int, mid: float, reach: float) -> bool:
	var size := chunk_size_world()
	var min_x := float(cx) * size
	var min_y := float(cy) * size
	var max_x := min_x + size
	var max_y := min_y + size
	var qx := clampf(mid, min_x, max_x)
	var qy := clampf(mid, min_y, max_y)
	return sim.spatial._dist_point(mid, mid, qx, qy) <= reach


## True when a chunk should receive home-island terrain rules.
func is_island_chunk(cx: int, cy: int) -> bool:
	return chunk_intersects_disk(cx, cy, island_mid(), island_reach() + 40.0)


## True when world coordinates lie inside the egg clearing.
func near_spawn(x: float, y: float) -> bool:
	var mid := island_mid()
	return sim.spatial._dist_point(mid, mid, x, y) < sim.SPAWN_CLEAR


## Like near_spawn but in chunk-local coordinates for scatter.
func near_island_mid(px: float, py: float) -> bool:
	# Local-space helper for home-chunk scatter; prefer near_spawn for world checks.
	var mid := local_mid()
	return sim.spatial._dist_point(mid, mid, px, py) < sim.SPAWN_CLEAR


## Center of the current chunk in local tile space.
func local_mid() -> float:
	return chunk_size_world() * 0.5


## Removes props encroaching on the mandatory spawn clearing.
func clear_spawn() -> void:
	var doomed: Array = []
	for feat in sim.features:
		if feat.dead:
			continue
		if near_spawn(float(feat.x), float(feat.y)):
			doomed.append(feat)
	for feat in doomed:
		sim.world_entities._kill_feature(feat)


## Raises land tier, rebuilds shape, and may trigger part-two narrative.
func expand_super_island(announce: bool = true) -> void:
	var first: bool = not sim.part_two
	# Grow the main island.
	sim.land_tier = maxi(sim.land_tier, 3)
	var added: int = shape_island()
	if first:
		sim.dialogue._enter_part_two("LA ISLA CRECE Y SE ABRE UN NUEVO CAMINO.", true)
	elif announce and added > 0:
		sim.notes.append("LA ISLA CRECE.")


## Counts ore features already placed on a chunk.
func count_mine_nodes(cx: int, cy: int) -> int:
	var n := 0
	for feat in sim.features:
		if feat.dead:
			continue
		if int(feat.cx) != cx or int(feat.cy) != cy:
			continue
		if sim.building_sim._ore_tier(int(feat.kind)) > 0:
			n += 1
	return n


## Places super and standard mine nodes on a chunk if sparse.
func seed_mine_nodes(cx: int, cy: int) -> void:
	if bool(sim.sandbox_mode):
		return
	var ck: String = sim.spatial._ck(cx, cy)
	if not sim.chunks.has(ck):
		return
	var tiles = sim.chunks[ck].tiles
	var placed: int = count_mine_nodes(cx, cy)
	var want := 3
	var tries := 0
	while placed < want and tries < 400:
		tries += 1
		var lx := randi() % Catalog.CHUNK
		var ly := randi() % Catalog.CHUNK
		if not mine_spot_ok(cx, cy, lx, ly, tiles, 58.0):
			continue
		var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		var kind := Catalog.FEAT_SUPER if placed == 0 else Catalog.FEAT_NODE
		var ore := 2 if kind == Catalog.FEAT_SUPER else 1
		if sim.world_entities._add_feature(kind, wx, wy, 1, ore, true).is_empty():
			continue
		placed += 1
	if placed > 0:
		return
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not mine_spot_ok(cx, cy, lx, ly, tiles, 0.0):
				continue
			var fx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var fy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if not sim.world_entities._add_feature(Catalog.FEAT_SUPER, fx, fy, 1, 2, true).is_empty():
				return


## Validates a tile for mine placement away from cliffs and clutter.
func mine_spot_ok(cx: int, cy: int, lx: int, ly: int, tiles, mid_min: float) -> bool:
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var nx := lx + ox
			var ny := ly + oy
			if nx < 0 or ny < 0 or nx >= Catalog.CHUNK or ny >= Catalog.CHUNK:
				return false
			var tile := int(tiles[ny * Catalog.CHUNK + nx])
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE:
				return false
			var wx := float((cx * Catalog.CHUNK + nx) * Catalog.TILE + 8)
			var wy := float((cy * Catalog.CHUNK + ny) * Catalog.TILE + 8)
			var key := Vector2i(cx * Catalog.CHUNK + nx, cy * Catalog.CHUNK + ny)
			if sim.feature_cell.has(key):
				var feat = sim.feature_by_id.get(int(sim.feature_cell[key]), {})
				if not feat.is_empty() and not feat.dead:
					return false
			if not sim.world_entities._building_at(wx, wy, 10.0).is_empty():
				return false
	if mid_min > 0.0:
		var mid := float(Catalog.CHUNK * Catalog.TILE) * 0.5
		if sim.spatial._dist_point(mid, mid, float(lx * Catalog.TILE + 8), float(ly * Catalog.TILE + 8)) < mid_min:
			return false
	return true


## Returns whether a world point lies inside the wobbled island disk.
func disk_land(x: float, y: float, mid: float, reach: float, phase: float) -> bool:
	var ang := atan2(y - mid, x - mid)
	var wobble := sin(ang * 2.0 + phase) * 20.0 + sin(ang * 5.0 + phase * 1.4) * 10.0 + sin(ang * 7.0 + 0.8) * 5.0
	return sim.spatial._dist_point(mid, mid, x, y) <= reach + wobble


## Normalized ellipse distance used to carve bays and ponds.
func ellipse(px: float, py: float, center: Vector2, axis: Vector2, rx: float, ry: float) -> float:
	var rel := Vector2(px, py) - center
	var side := Vector2(-axis.y, axis.x)
	var u := rel.dot(axis) / rx
	var v := rel.dot(side) / ry
	return u * u + v * v


## True for inland grass, dirt, or bloom without blocking props.
func open_ground(cx: int, cy: int, lx: int, ly: int) -> bool:
	if lx < 0 or ly < 0 or lx >= Catalog.CHUNK or ly >= Catalog.CHUNK:
		return false
	var tile := int(sim.chunks[sim.spatial._ck(cx, cy)].tiles[ly * Catalog.CHUNK + lx])
	if tile != Catalog.TILE_GRASS and tile != Catalog.TILE_DIRT and tile != Catalog.TILE_BLOOM:
		return false
	var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
	var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
	return sim.collision._land_inland(wx, wy)


## Carves lakes and shore water on the home chunk tile buffer.
func paint_water(tiles: PackedByteArray, cx: int, cy: int) -> PackedByteArray:
	var outward := Vector2(1, 0)
	if absi(int(sim.world_seed)) % 2 == 1:
		outward = Vector2(-1, 0)
	var away := -outward
	if cx != 0 or cy != 0:
		away = outward
	var side := Vector2(-away.y, away.x)
	var mid := local_mid()
	var origin := Vector2(float(cx * Catalog.CHUNK * Catalog.TILE), float(cy * Catalog.CHUNK * Catalog.TILE))
	var lake := Vector2(mid, mid) + side * 78.0 + away * 24.0
	var made := 0
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not wet_cell(tiles, lx, ly, mid, origin, lake, side, lake, 64.0, 34.0, 26.0, 0.0):
				continue
			tiles[ly * Catalog.CHUNK + lx] = Catalog.TILE_WATER
			made += 1
	if made >= 10:
		return tiles
	var inland := Vector2(mid, mid) + side * 64.0
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var idx := ly * Catalog.CHUNK + lx
			var tile := int(tiles[idx])
			if tile != Catalog.TILE_GRASS and tile != Catalog.TILE_DIRT and tile != Catalog.TILE_BLOOM:
				continue
			var px := float(lx * Catalog.TILE + 8)
			var py := float(ly * Catalog.TILE + 8)
			if sim.spatial._dist_point(mid, mid, px, py) < 58.0:
				continue
			if sim.spatial._dist_point(inland.x, inland.y, px, py) > 40.0:
				continue
			var wx := origin.x + px
			var wy := origin.y + py
			if not sim.world_entities._feature_at(wx, wy, 6.0).is_empty() or not sim.world_entities._building_at(wx, wy, 8.0).is_empty():
				continue
			tiles[idx] = Catalog.TILE_WATER
	return tiles


## Decides whether a grass cell should become water in layout passes.
func wet_cell(tiles: PackedByteArray, lx: int, ly: int, mid: float, origin: Vector2, bay: Vector2, away: Vector2, pond: Vector2, camp: float, bay_rx: float, bay_ry: float, pond_r: float) -> bool:
	var idx := ly * Catalog.CHUNK + lx
	var tile := int(tiles[idx])
	if tile != Catalog.TILE_GRASS and tile != Catalog.TILE_DIRT and tile != Catalog.TILE_BLOOM:
		return false
	var px := float(lx * Catalog.TILE + 8)
	var py := float(ly * Catalog.TILE + 8)
	if sim.spatial._dist_point(mid, mid, px, py) < camp:
		return false
	var wx := origin.x + px
	var wy := origin.y + py
	if not sim.world_entities._feature_at(wx, wy, 6.0).is_empty() or not sim.world_entities._building_at(wx, wy, 8.0).is_empty():
		return false
	if ellipse(px, py, bay, away, bay_rx, bay_ry) <= 1.0:
		return true
	return sim.spatial._dist_point(pond.x, pond.y, px, py) <= pond_r


## Samples well-separated anchor points for groves and rock clusters.
func pick_points(cx: int, cy: int, want: int, min_mid: float, apart: float, salt: int) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var mid := local_mid()
	var n := 0
	while found.size() < want and n < 40:
		n += 1
		var lx := 3 + int(sim.spatial._rand(cx, cy, n, salt, 51) * 26.0)
		var ly := 3 + int(sim.spatial._rand(cx, cy, n, salt + 3, 52) * 26.0)
		var px := float(lx * Catalog.TILE + 8)
		var py := float(ly * Catalog.TILE + 8)
		if sim.spatial._dist_point(mid, mid, px, py) < min_mid:
			continue
		if not open_ground(cx, cy, lx, ly):
			continue
		var spot := Vector2(px, py)
		var ok := true
		for have in found:
			if have.distance_to(spot) < apart:
				ok = false
				break
		if ok:
			found.append(spot)
	return found


## Shortest distance from a point to any anchor in a list.
func nearest_point(px: float, py: float, points: Array[Vector2]) -> float:
	var best := 10000.0
	var at := Vector2(px, py)
	for p in points:
		best = minf(best, at.distance_to(p))
	return best


## Per-cell density jitter so forests clump instead of tiling evenly.
func tree_jitter(cx: int, cy: int, lx: int, ly: int) -> float:
	# 0.25..1.75 — same mean density, more patchy clumps and gaps.
	return 0.25 + float(sim.spatial._rand(cx, cy, lx, ly, 19)) * 1.5


## Stochastic tree roll from grove proximity and jitter.
func wants_tree(cx: int, cy: int, lx: int, ly: int) -> bool:
	var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
	var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
	if near_spawn(wx, wy):
		return false
	var px := float(lx * Catalog.TILE + 8)
	var py := float(ly * Catalog.TILE + 8)
	var near := nearest_point(px, py, pick_points(cx, cy, 6, sim.SPAWN_CLEAR + 8.0, 52.0, 2))
	var jitter := tree_jitter(cx, cy, lx, ly)
	var inner := 85.0 + float(sim.spatial._rand(cx, cy, lx, ly, 23)) * 50.0
	var outer := 120.0 + float(sim.spatial._rand(cx, cy, lx, ly, 29)) * 50.0
	if near < inner:
		return float(sim.spatial._rand(cx, cy, lx, ly, 1)) < 0.31 * jitter
	if near < outer:
		return float(sim.spatial._rand(cx, cy, lx, ly, 1)) < 0.14 * jitter
	return float(sim.spatial._rand(cx, cy, lx, ly, 1)) < 0.02 * jitter


## Counts live features of one kind on a chunk.
func count_kind_on(cx: int, cy: int, kind: int) -> int:
	var n := 0
	for feat in sim.features:
		if feat.dead or int(feat.cx) != cx or int(feat.cy) != cy:
			continue
		if int(feat.kind) == kind:
			n += 1
	return n


## Counts ore-bearing rocks and nodes on a chunk.
func count_ore_rocks_on(cx: int, cy: int) -> int:
	var n := 0
	for feat in sim.features:
		if feat.dead or int(feat.cx) != cx or int(feat.cy) != cy:
			continue
		var kind := int(feat.kind)
		if (kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK) and int(feat.ore) > 0:
			n += 1
		elif sim.building_sim._ore_tier(kind) > 0:
			n += 1
	return n


## Spiral search for an open inland cell near anchor points.
func free_land_near(cx: int, cy: int, points: Array[Vector2], n: int) -> Vector2:
	if points.is_empty():
		return Vector2(-1, -1)
	var origin: Vector2 = points[n % points.size()]
	var ang := float(n) * 2.399
	var dist := 12.0 + float(n % 6) * 16.0
	var px := origin.x + cos(ang) * dist
	var py := origin.y + sin(ang) * dist
	var lx := int(floor(px / float(Catalog.TILE)))
	var ly := int(floor(py / float(Catalog.TILE)))
	if not open_ground(cx, cy, lx, ly):
		return Vector2(-1, -1)
	# Spiral probe is continuous; park on the cell center so props stay on-grid.
	var wx := float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
	var wy := float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
	if near_spawn(wx, wy):
		return Vector2(-1, -1)
	if not sim.world_entities._feature_at(wx, wy, 10.0).is_empty():
		return Vector2(-1, -1)
	return Vector2(wx, wy)


## Desired tree, stone, and ore quotas from inland area.
func prop_targets(cx: int, cy: int) -> Dictionary:
	# Scale baselines with how much inland pad this chunk actually has.
	var inland := 0
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if open_ground(cx, cy, lx, ly):
				inland += 1
	var trees_want := mini(45, maxi(6, inland / 8))
	var stones_want := mini(50, maxi(8, inland / 8))
	var ore_want := mini(28, maxi(4, inland / 12))
	return {"trees": trees_want, "stones": stones_want, "ore": ore_want}


## Spawns missing trees and rocks until quotas are met.
func top_up_island(cx: int, cy: int, groves: Array[Vector2], rocks: Array[Vector2]) -> void:
	if bool(sim.sandbox_mode):
		return
	# Inland-only props (no cliff hang) leave less pad than the old coastal fill.
	# Keep the interior open for buildings, but guarantee a healthy baseline of trees and ores.
	var want: Dictionary = prop_targets(cx, cy)
	var trees := count_kind_on(cx, cy, Catalog.FEAT_TREE)
	var stones := count_kind_on(cx, cy, Catalog.FEAT_ROCK) + count_kind_on(cx, cy, Catalog.FEAT_BIGROCK)
	var ore_rocks := count_ore_rocks_on(cx, cy)
	var guard := 0
	while trees < int(want.trees) and guard < 160:
		guard += 1
		var spot := free_land_near(cx, cy, groves, guard)
		if spot.x < 0.0:
			continue
		if sim.world_entities._add_feature(Catalog.FEAT_TREE, spot.x, spot.y, 1, 0, true).is_empty():
			continue
		trees += 1
	guard = 0
	while stones < int(want.stones) and guard < 140:
		guard += 1
		var rock := free_land_near(cx, cy, rocks, guard + 3)
		if rock.x < 0.0:
			continue
		var ore := 1 if guard % 3 != 0 else 0
		if sim.world_entities._add_feature(Catalog.FEAT_ROCK, rock.x, rock.y, 1 + ore, ore, true).is_empty():
			continue
		stones += 1
		if ore > 0:
			ore_rocks += 1
	guard = 0
	while ore_rocks < int(want.ore) and guard < 140:
		guard += 1
		var rock := free_land_near(cx, cy, rocks, guard + 7)
		if rock.x < 0.0:
			continue
		if sim.world_entities._add_feature(Catalog.FEAT_ROCK, rock.x, rock.y, 2, 1, true).is_empty():
			continue
		ore_rocks += 1
		stones += 1


## Seeds trees and rocks only on newly revealed land cells.
func decorate_fresh(spots: Array[Vector2]) -> void:
	if bool(sim.sandbox_mode):
		return
	# Expansion rings are coastal-heavy; only inland fresh cells can host rooted props.
	for spot in spots:
		if near_spawn(spot.x, spot.y):
			continue
		if int(sim.collision._tile_at(spot.x, spot.y)) == Catalog.TILE_WATER:
			continue
		if not sim.collision._land_inland(spot.x, spot.y):
			continue
		var c: Vector2i = sim.spatial._chunk_at(spot.x, spot.y)
		var lx: int = int(sim.spatial._cell_of(spot.x)) - c.x * Catalog.CHUNK
		var ly: int = int(sim.spatial._cell_of(spot.y)) - c.y * Catalog.CHUNK
		var roll := float(sim.spatial._rand(c.x, c.y, lx, ly, 41))
		var tree_cut := 0.26 * tree_jitter(c.x, c.y, lx, ly)
		if roll < tree_cut:
			sim.world_entities._add_feature(Catalog.FEAT_TREE, spot.x, spot.y, 1, 0, true)
		elif roll < tree_cut + 0.20:
			sim.world_entities._add_feature(Catalog.FEAT_ROCK, spot.x, spot.y, 2, 1, true)
		elif roll < tree_cut + 0.30:
			sim.world_entities._add_feature(Catalog.FEAT_ROCK, spot.x, spot.y, 1, 0, true)
		elif roll < tree_cut + 0.34:
			sim.world_entities._scatter_one(c.x, c.y, spot.x, spot.y, lx, ly)


## Initial prop pass when a home chunk is first populated.
func scatter_island(cx: int, cy: int) -> void:
	if bool(sim.sandbox_mode):
		return
	var groves := pick_points(cx, cy, 6, sim.SPAWN_CLEAR + 8.0, 52.0, 2)
	var rocks := pick_points(cx, cy, 5, sim.SPAWN_CLEAR + 12.0, 72.0, 6)
	var origin := Vector2(float(cx * Catalog.CHUNK * Catalog.TILE), float(cy * Catalog.CHUNK * Catalog.TILE))
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			if not open_ground(cx, cy, lx, ly):
				continue
			var px := float(lx * Catalog.TILE + 8)
			var py := float(ly * Catalog.TILE + 8)
			var wx := origin.x + px
			var wy := origin.y + py
			if near_spawn(wx, wy):
				continue
			var grove := nearest_point(px, py, groves)
			var rock := nearest_point(px, py, rocks)
			var jitter := tree_jitter(cx, cy, lx, ly)
			var inner := 85.0 + float(sim.spatial._rand(cx, cy, lx, ly, 23)) * 50.0
			var outer := 120.0 + float(sim.spatial._rand(cx, cy, lx, ly, 29)) * 50.0
			if grove < inner and float(sim.spatial._rand(cx, cy, lx, ly, 1)) < 0.36 * jitter:
				sim.world_entities._add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif grove < outer and float(sim.spatial._rand(cx, cy, lx, ly, 1)) < 0.18 * jitter:
				sim.world_entities._add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif rock < 64.0 and sim.spatial._rand(cx, cy, lx, ly, 2) < 0.48:
				sim.world_entities._add_feature(Catalog.FEAT_ROCK, wx, wy, 2, 1, true)
			elif rock < 88.0 and sim.spatial._rand(cx, cy, lx, ly, 3) < 0.55:
				var ore := 1 if sim.spatial._rand(cx, cy, lx, ly, 7) < 0.62 else 0
				sim.world_entities._add_feature(Catalog.FEAT_ROCK, wx, wy, 1 + ore, ore, true)
			elif grove > 140.0:
				sim.world_entities._scatter_one(cx, cy, wx, wy, lx, ly)
	for rp in rocks:
		var bx := origin.x + rp.x
		var by := origin.y + rp.y
		if near_spawn(bx, by):
			continue
		sim.world_entities._add_feature(Catalog.FEAT_BIGROCK, bx, by, 4, 1, true)
	top_up_island(cx, cy, groves, rocks)


## Rebuilds void/grass/water to match tier; returns new land cell count.
func shape_island() -> int:
	if sim._shaping_island:
		return 0
	if not sim.chunks.has("0,0"):
		return 0
	sim._shaping_island = true
	var mid := island_mid()
	var reach := island_reach()
	var pad := 40.0
	var phase := float(absi(int(sim.world_seed) % 628)) * 0.01
	var size := chunk_size_world()
	var x0 := int(floor((mid - reach - pad) / size))
	var y0 := int(floor((mid - reach - pad) / size))
	var x1 := int(floor((mid + reach + pad) / size))
	var y1 := int(floor((mid + reach + pad) / size))
	var keep := {}
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_LIVING:
			continue
		keep_cell(keep, sim.pos_x[i], sim.pos_y[i])
	for b in sim.buildings:
		if b.dead:
			continue
		var foot: Vector2i = Catalog.footprint_for_building(int(b.kind))
		for cell in sim.building_sim._footprint_cells(float(b.x), float(b.y), foot):
			keep["%d,%d" % [cell.x, cell.y]] = true
	var changed := false
	var fresh: Array[Vector2] = []
	var new_chunks: Array[Vector2i] = []
	var touched: Array[Vector2i] = []
	# Disk scan creates/updates land; also revisit every existing chunk so shrinks void stale land.
	var scan: Array[Vector2i] = []
	var seen_ck := {}
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if not chunk_intersects_disk(cx, cy, mid, reach + pad):
				continue
			var key := "%d,%d" % [cx, cy]
			seen_ck[key] = true
			scan.append(Vector2i(cx, cy))
	for ck_existing in sim.chunks.keys():
		if seen_ck.has(ck_existing):
			continue
		var parts: PackedStringArray = str(ck_existing).split(",")
		if parts.size() < 2:
			continue
		seen_ck[str(ck_existing)] = true
		scan.append(Vector2i(int(parts[0]), int(parts[1])))
	for coord in scan:
		var cx: int = coord.x
		var cy: int = coord.y
		var in_disk := chunk_intersects_disk(cx, cy, mid, reach + pad)
		var ck: String = sim.spatial._ck(cx, cy)
		var was_new: bool = not sim.chunks.has(ck)
		if was_new and not in_disk:
			continue
		if in_disk:
			sim.world_entities._reveal(cx, cy)
			if was_new:
				new_chunks.append(Vector2i(cx, cy))
		var tiles = sim.chunks[ck].tiles
		var chunk_changed := false
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var gx := cx * Catalog.CHUNK + lx
				var gy := cy * Catalog.CHUNK + ly
				var wx := float(gx * Catalog.TILE + 8)
				var wy := float(gy * Catalog.TILE + 8)
				var land := in_disk and disk_land(wx, wy, mid, reach, phase)
				var idx := ly * Catalog.CHUNK + lx
				var tile := int(tiles[idx])
				var gkey := "%d,%d" % [gx, gy]
				if land:
					if tile == Catalog.TILE_VOID:
						tiles[idx] = Catalog.TILE_GRASS
						fresh.append(Vector2(wx, wy))
						chunk_changed = true
				elif not keep.has(gkey) and tile != Catalog.TILE_VOID:
					tiles[idx] = Catalog.TILE_VOID
					chunk_changed = true
		if chunk_changed or was_new:
			if cx == 0 and cy == 0 and not bool(sim.sandbox_mode):
				tiles = paint_water(tiles, 0, 0)
			sim.chunks[ck].tiles = tiles
			sim.chunks[ck].base = tiles.duplicate()
			sim.spatial._mark_dirty(ck)
			touched.append(Vector2i(cx, cy))
			if chunk_changed:
				changed = true
	if changed:
		sim.inland_cache.clear()
		sim.world_entities._invalidate_walk_cells()
	if not changed:
		sim._shaping_island = false
		return 0
	for feat in sim.features:
		if feat.dead:
			continue
		if int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		var under: int = int(sim.collision._tile_at(float(feat.x), float(feat.y)))
		if under == Catalog.TILE_VOID or under == Catalog.TILE_WATER:
			sim.world_entities._kill_feature(feat)
		elif bool(feat.get("rooted", false)) and not sim.world_entities._is_mine_node(int(feat.kind)) and not sim.collision._land_inland(float(feat.x), float(feat.y)):
			sim.world_entities._kill_feature(feat)
	var new_set := {}
	for c in new_chunks:
		if c.x == 0 and c.y == 0:
			continue
		new_set["%d,%d" % [c.x, c.y]] = true
		scatter_island(c.x, c.y)
		seed_mine_nodes(c.x, c.y)
	decorate_fresh(fresh)
	for c in touched:
		var groves: Array[Vector2] = pick_points(c.x, c.y, 6, sim.SPAWN_CLEAR + 8.0, 52.0, 2)
		var rocks: Array[Vector2] = pick_points(c.x, c.y, 5, sim.SPAWN_CLEAR + 12.0, 72.0, 6)
		top_up_island(c.x, c.y, groves, rocks)
		if count_mine_nodes(c.x, c.y) < 1:
			seed_mine_nodes(c.x, c.y)
	seed_mine_nodes(0, 0)
	sim._shaping_island = false
	return fresh.size()


## Marks a global cell that must stay land during shrink passes.
func keep_cell(keep: Dictionary, x: float, y: float) -> void:
	var gx: int = sim.spatial._cell_of(x)
	var gy: int = sim.spatial._cell_of(y)
	keep["%d,%d" % [gx, gy]] = true
