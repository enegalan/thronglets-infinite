class_name SimWorldTick
extends RefCounted

## Per-frame world systems: trees, props, monoliths, egg, corpses, auras.

var sim


## Stores the simulation server used for world ticks.
func _init(sim_ref) -> void:
	sim = sim_ref

## Regrow stumps into trees and expire queued tree seed plantings.
func _tick_trees(dt: float) -> void:
	for feat in sim.features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_STUMP:
			continue
		var grow = float(feat.get("grow", Catalog.TREE_REGROW))
		grow -= dt
		if grow > 0.0:
			feat.grow = grow
			continue
		feat.grow = 0.0
		feat.kind = Catalog.FEAT_TREE
		feat.hp = 1
		feat.rooted = true
		sim.feat_mesh_epoch += 1
	if sim.tree_seeds.is_empty():
		return
	var kept: Array = []
	for seed in sim.tree_seeds:
		var left = float(seed.get("t", 0.0)) - dt
		if left > 0.0:
			seed.t = left
			kept.append(seed)
			continue
		_try_plant_tree(float(seed.x), float(seed.y))
	sim.tree_seeds = kept



## Spawn a tree feature when the tile is clear of blockers.
func _try_plant_tree(x: float, y: float) -> void:
	if sim.collision._blocked(x, y):
		return
	if not sim.world_entities._feature_at(x, y, 6.0).is_empty():
		return
	if not sim.world_entities._building_at(x, y, 10.0).is_empty():
		return
	sim.world_entities._add_feature(Catalog.FEAT_TREE, x, y, 1, 0, true)



## Airborne egg item fall and landing prompt when it touches ground.
func _tick_egg(it: Dictionary, dt: float) -> void:
	it.shake = maxf(0.0, float(it.get("shake", 0.0)) - dt)
	var air = float(it.get("air", 0.0))
	if air <= 0.0:
		return
	var fall = float(it.get("fall", 0.0)) + 220.0 * dt
	it.fall = fall
	air = maxf(0.0, air - fall * dt)
	it.air = air
	if air <= 0.0:
		it.air = 0.0
		it.fall = 0.0
		sim.notes.append("TOCA EL HUEVO CON LA MANO PARA AYUDAR.")
		sim.sfx_queue.append("egg_land")



## South footprint edge used as haul loot approach point for a building.
func _loot_spot(b: Dictionary) -> Vector2:
	var size = Catalog.footprint_for_building(int(b.kind))
	var south = float(size.y) * float(Catalog.TILE)
	var spot = Vector2(float(b.x), float(b.y) + south)
	if not sim.collision._blocked(spot.x, spot.y):
		return spot
	return sim.collision._approach_spot(float(b.x), float(b.y), south + 8.0)



## Decays corpse timers and vacates slots when bodies expire from neglect.
func _tick_corpses(dt: float) -> void:
	if sim.dead_ids.is_empty():
		return
	var k = 0
	while k < sim.dead_ids.size():
		var id = int(sim.dead_ids[k])
		if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_DEAD:
			sim.world_entities._dead_remove_at(k)
			continue
		sim.starve[id] = maxf(0.0, sim.starve[id] - dt)
		if sim.starve[id] <= 0.0:
			sim.world_entities._vacate(id)
			continue
		k += 1



## Factory mishap paints nearby grass/dirt with goo tiles once the mop is owned.
func _spill_goo(x: float, y: float, amount: int) -> void:
	# Goo must not grow before the mop, or the player cannot clean it.
	if not bool(sim.unlocks.get("mop", false)):
		if sim.dialogue._grant("mop", "", false):
			sim.notes.append("LLEGA LA FREGONA. APROVECHA PARA LIMPIAR EN ÁREAS SUCIAS.")
			sim.dialogue._reflect("goo")
		return
	for _n in amount:
		var ang = randf() * TAU
		var dist = randf_range(16.0, 54.0)
		var gx = x + cos(ang) * dist
		var gy = y + sin(ang) * dist
		var tile = sim.collision._tile_at(gx, gy)
		if tile == Catalog.TILE_GRASS or tile == Catalog.TILE_DIRT or tile == Catalog.TILE_BLOOM:
			var cell = sim.spatial._cell_vec(gx, gy)
			sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_GOO, false)
			sim.goo_count += 1



## Per-frame aura on fire, totem, and curer features: soiling, fun boost, heal SFX.
func _tick_props(dt: float) -> void:
	for feat in sim.features:
		if feat.dead:
			continue
		var kind = int(feat.kind)
		if kind == Catalog.FEAT_FIRE:
			var ids = sim.spatial.query_radius(float(feat.x), float(feat.y), 28.0)
			for raw in ids:
				var id = int(raw)
				if sim.state[id] == Catalog.ST_LIVING:
					sim.clean[id] = maxf(0.0, sim.clean[id] - 8.0 * dt)
		elif kind == Catalog.FEAT_TOTEM:
			sim.building_sim._boost(float(feat.x), float(feat.y), 32.0, 4, 0.0, 0.0, 4.0 * dt, 0.0, sim.ACT_PLAY)
		elif kind == Catalog.FEAT_CURER:
			sim.building_sim._boost(float(feat.x), float(feat.y), 28.0, 3, 1.5 * dt, 5.0 * dt, 0.0, 0.0, sim.ACT_BATH)
			var healed = false
			for raw in sim.spatial.query_radius(float(feat.x), float(feat.y), 28.0):
				if sim.state[int(raw)] == Catalog.ST_LIVING:
					healed = true
					break
			if healed:
				feat.snd = float(feat.get("snd", 0.0)) - dt
				if float(feat.snd) <= 0.0:
					feat.snd = 5.0
					sim.sfx_queue.append("heal")



## Advances monolith spawn animation and fires _touch_monolith when a living agent enters range.
func _tick_monoliths(dt: float, allow_touch: bool = true) -> void:
	var to_touch: Array = []
	for feat in sim.features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_MONOLITH:
			continue
		if not feat.has("spawn_progress"):
			feat.spawn_progress = 1.0
		if not feat.has("spawn_dur"):
			feat.spawn_dur = 1.4
		feat.age = float(feat.get("age", 0.0)) + dt
		var dur = maxf(0.01, float(feat.spawn_dur))
		feat.spawn_progress = minf(1.0, float(feat.spawn_progress) + dt / dur)
		feat.particle_t = maxf(0.0, float(feat.get("particle_t", 0.0)) - dt)
		if not allow_touch or bool(feat.get("triggered", false)):
			continue
		if float(feat.spawn_progress) < 1.0:
			continue
		var fx = float(feat.x)
		var fy = float(feat.y)
		for raw in sim.spatial.query_radius(fx, fy, 28.0):
			var i = int(raw)
			if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
				continue
			to_touch.append(feat)
			break
	for feat in to_touch:
		if feat.dead or bool(feat.get("triggered", false)):
			continue
		feat.triggered = true
		sim.dialogue._touch_monolith(feat)



