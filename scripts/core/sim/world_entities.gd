class_name SimWorldEntities
extends RefCounted

## Entity add/remove/kill, reset, indexes, and session bootstrap pieces.

var sim


## Stores the simulation server used for entity mutations.
func _init(sim_ref) -> void:
	sim = sim_ref

## Maximum living thronglets allowed from walkable open cells on the revealed island.
func colony_cap() -> int:
	return maxi(2, int(floor(float(_walk_cells()) / float(Catalog.SPACE_PER_THRONG))))



## Drops cached walkable-cell tally when terrain, props, or buildings change footprint.
func _invalidate_walk_cells() -> void:
	sim._walk_cells_cache = -1



## Counts unobstructed tile cells in revealed chunks for population cap and mitosis checks.
func _walk_cells() -> int:
	if sim.save_perf_mode:
		sim.set_meta("_ap_walk_cells_n", int(sim.get_meta("_ap_walk_cells_n", 0)) + 1)
	if sim._walk_cells_cache >= 0:
		return sim._walk_cells_cache
	var n = 0
	for ck in sim.revealed.keys():
		if not sim.chunks.has(ck):
			continue
		var origin = sim.spatial.chunk_origin(str(ck))
		var tiles: PackedByteArray = sim.chunks[ck].tiles
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var tile = int(tiles[ly * Catalog.CHUNK + lx])
				if Catalog.tile_blocks(tile):
					continue
				var cell = Vector2i(origin.x + lx, origin.y + ly)
				if sim.feature_cell.has(cell) or sim.building_cell.has(cell):
					continue
				n += 1
	sim._walk_cells_cache = n
	return n



## Blocks reproduction when at slot cap, colony cap, or local crowding around the parent.
func _space_blocks_mitosis(i: int) -> bool:
	if sim.slot_count >= Catalog.MAX_SLOTS or sim.living >= colony_cap():
		_tell_space_cap()
		return true
	if _count_living_near(sim.pos_x[i], sim.pos_y[i], Catalog.LOCAL_CROWD_R) >= Catalog.LOCAL_CROWD_N:
		_tell_space_cap()
		return true
	return false



## One-shot UI note and tutorial ping when mitosis fails for lack of buildable space.
func _tell_space_cap() -> void:
	if sim.cap_told:
		return
	sim.cap_told = true
	sim.notes.append("NO HAY SITIO: AMPLIA O DESPEJA TERRENO.")
	if not sim.learn_talked and sim.living >= 2 and not sim.testing:
		sim.learn_talked = true
		sim.dialogue._queue_talk("learn_self", {})



## Grow per-agent timer arrays when loading older saves missing fields.
func _ensure_agent_timers(i: int) -> void:
	# TODO: May be removed
	# Old saves lack react/cheer/sleep/peer/drop/penned arrays; grow on demand.
	while sim.react_t.size() <= i:
		sim.react_t.append(0.0)
	while sim.cheer_t.size() <= i:
		sim.cheer_t.append(0.0)
	while sim.sleep_t.size() <= i:
		sim.sleep_t.append(0.0)
	while sim.peer_t.size() <= i:
		sim.peer_t.append(0.0)
	while sim.peer_of.size() <= i:
		sim.peer_of.append(-1)
	while sim.peer_sing.size() <= i:
		sim.peer_sing.append(0)
	while sim.drop_t.size() <= i:
		sim.drop_t.append(0.0)
	while sim.penned_flag.size() <= i:
		sim.penned_flag.append(0)
	while sim.bloody.size() <= i:
		sim.bloody.append(0)



## Horizontal footprint span used when testing feature footing.
func _span_for_feature(kind: int) -> Vector2:
	if kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_FLOWER or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
		return Vector2(8.0, 14.0)
	if kind == Catalog.FEAT_BIGROCK:
		return Vector2(12.0, 22.0)
	return Vector2(16.0, 52.0)



## Multi-sample footing along feature height so sprites stand on solid cells.
func _stands(x: float, y: float, span: Vector2) -> bool:
	if not sim.collision._land_inland(x, y):
		return false
	var cols: Array[float] = [-span.x, 0.0, span.x]
	var rows: Array[float] = [0.0]
	var sy = -span.y
	while sy < -0.5:
		rows.append(sy)
		sy += 16.0
	var step = float(Catalog.TILE)
	for sx in cols:
		for row in rows:
			var dcx = sx / 32.0 + row / 16.0
			var dcy = row / 16.0 - sx / 32.0
			if not sim.collision._tile_holds(x + dcx * step, y + dcy * step):
				return false
	return true



## Whether another item occupies a point, optionally ignoring one id.
func _item_spot_free(x: float, y: float, ignore_id: int = -1) -> bool:
	var other = _item_at(x, y, 10.0)
	return other.is_empty() or int(other.id) == ignore_id



## World center position for a grid cell (catalog helper).
func _cell_world(cell: Vector2i) -> Vector2:
	return Catalog.cell_world(cell)



## Remove a world feature from the per-cell spatial index.
func _unbind_feature(feat: Dictionary) -> void:
	var id = int(feat.id)
	var doomed: Array = []
	for cell in sim.feature_cell.keys():
		if int(sim.feature_cell[cell]) == id:
			doomed.append(cell)
	for cell in doomed:
		sim.feature_cell.erase(cell)



## Snap, validate, and index a feature at a new world position.
func _bind_feature_at(feat: Dictionary, x: float, y: float) -> bool:
	var at = Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	var cells = sim.building_sim._footprint_cells(x, y, Catalog.footprint_for_feature(int(feat.kind)))
	if not sim.building_sim._footprint_holds(cells):
		return false
	for cell in cells:
		var owner = int(sim.feature_cell.get(cell, -1))
		if owner >= 0 and owner != int(feat.id):
			return false
		var bid = int(sim.building_cell.get(cell, -1))
		if bid >= 0:
			return false
	_feat_chunk_unindex(feat)
	_unbind_feature(feat)
	feat.x = x
	feat.y = y
	var c = sim.spatial._chunk_at(x, y)
	feat.cx = c.x
	feat.cy = c.y
	_feat_chunk_index(feat)
	for cell in cells:
		sim.feature_cell[cell] = int(feat.id)
	return true



## World tally for a loot kind, including wood/bone/ore on the ground plus agents currently hauling.
func count_item(kind: int) -> int:
	_ensure_item_counts()
	match kind:
		Catalog.ITEM_WOOD:
			return sim._item_count_wood
		Catalog.ITEM_BONE:
			return sim._item_count_bone
		Catalog.ITEM_ORE:
			return sim._item_count_ore
		_:
			if sim._item_count_other.has(kind):
				return int(sim._item_count_other[kind])
			var n = 0
			for it in sim.items:
				if not it.dead and not it.held and int(it.kind) == kind:
					n += 1
			sim._item_count_other[kind] = n
			return n



## Bumps the item-count cache generation so the next inventory read recomputes tallies.
func _invalidate_item_counts() -> void:
	sim._item_count_gen += 1



## Decrements global haul counters when an agent stops carrying wood, bone, or ore.
func _carry_dec(i: int) -> void:
	if i < 0 or i >= sim.carry.size():
		return
	match int(sim.carry[i]):
		Catalog.CARRY_WOOD:
			sim.carry_wood_n = maxi(0, sim.carry_wood_n - 1)
		Catalog.CARRY_BONE:
			sim.carry_bone_n = maxi(0, sim.carry_bone_n - 1)
		Catalog.CARRY_ORE:
			sim.carry_ore_n = maxi(0, sim.carry_ore_n - 1)



## Increments global haul counters when an agent's carry slot holds a resource.
func _carry_inc(i: int) -> void:
	if i < 0 or i >= sim.carry.size():
		return
	match int(sim.carry[i]):
		Catalog.CARRY_WOOD:
			sim.carry_wood_n += 1
		Catalog.CARRY_BONE:
			sim.carry_bone_n += 1
		Catalog.CARRY_ORE:
			sim.carry_ore_n += 1



## Assigns haul state on a slot, keeps aggregate counts in sync, and arms drop animation on release.
func _set_carry(i: int, kind: int, value: int = 0) -> void:
	if i < 0 or i >= sim.carry.size():
		return
	if int(sim.carry[i]) == kind and (kind == Catalog.CARRY_NONE or int(sim.carry_value[i]) == value):
		return
	var was_carrying = int(sim.carry[i]) != Catalog.CARRY_NONE
	_carry_dec(i)
	sim.carry[i] = kind
	sim.carry_value[i] = value if kind != Catalog.CARRY_NONE else 0
	_carry_inc(i)
	# DropProp one-shot when a haul leaves the hands.
	if was_carrying and kind == Catalog.CARRY_NONE:
		_ensure_agent_timers(i)
		sim.drop_t[i] = sim.DROP_DUR
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0



## Recounts every living agent's carry slot into the wood/bone/ore haul aggregates.
func _rebuild_carry_counts() -> void:
	sim.carry_wood_n = 0
	sim.carry_bone_n = 0
	sim.carry_ore_n = 0
	for raw in sim.living_ids:
		_carry_inc(int(raw))



## Refreshes cached ground-loot counts when generation changed, folding in carried stock.
func _ensure_item_counts() -> void:
	if sim._item_count_built == sim._item_count_gen:
		return
	sim._item_count_built = sim._item_count_gen
	sim._item_count_other.clear()
	var wood = 0
	var bone = 0
	var ore = 0
	for it in sim.items_wood:
		if not it.dead and not it.held:
			wood += 1
	for it in sim.items_bone:
		if not it.dead and not it.held:
			bone += 1
	for it in sim.items_ore:
		if not it.dead and not it.held:
			ore += 1
	sim._item_count_wood = wood + sim.carry_wood_n
	sim._item_count_bone = bone + sim.carry_bone_n
	sim._item_count_ore = ore + sim.carry_ore_n



## Returns how many corpse slots exist for rendering and neglect mechanics.
func count_dead() -> int:
	return sim.dead_n



## Places a building at a snapped point or searches outward rings until footprint fits.
func _try_add_building_near(kind: int, x: float, y: float) -> bool:
	if not _add_building(kind, x, y).is_empty():
		return true
	for ring in range(1, 8):
		for d in [
			Vector2(ring * 16, 0), Vector2(-ring * 16, 0),
			Vector2(0, ring * 16), Vector2(0, -ring * 16),
			Vector2(ring * 16, ring * 16), Vector2(-ring * 16, ring * 16),
			Vector2(ring * 16, -ring * 16), Vector2(-ring * 16, -ring * 16),
		]:
			var try_at = Catalog.snap_world(x + d.x, y + d.y)
			if not _add_building(kind, try_at.x, try_at.y).is_empty():
				return true
	return false



## Wipes saves and seeds a new campaign run with starter egg and default progression.
func new_game() -> void:
	# One run only: wipe the live save and its autosave history.
	sim.save_system.clear_saves()
	sim.current_slot = SaveSystem.LIVE_SLOT
	sim.ethics = []
	sim.sandbox_mode = false
	sim.dialogue._init_unlocks()
	sim.unlock_serial += 1
	sim.world_seed = randi()
	if sim.world_seed == 0:
		sim.world_seed = 1
	_bootstrap_new()
	sim.tutorial_i = 0
	sim.count_unknown = true
	sim.notes.append("PARTIDA NUEVA.")



## Starts sandbox mode with full unlocks, chosen island tier, and stripped campaign props.
func new_sandbox_game(tier: int = 2) -> void:
	sim.save_system.clear_sandbox_save()
	sim.current_slot = -1
	sim.save_path = sim.save_system.sandbox_path()
	sim.ethics = []
	sim.world_seed = randi()
	if sim.world_seed == 0:
		sim.world_seed = 1
	_bootstrap_sandbox(clampi(tier, sim.SANDBOX_TIER_MIN, sim.SANDBOX_TIER_MAX))
	sim.notes.append("SANDBOX.")



## Resizes the playable island in sandbox without wiping player-placed structures.
func set_sandbox_land_tier(tier: int) -> void:
	if not sim.sandbox_mode:
		return
	var next = clampi(tier, sim.SANDBOX_TIER_MIN, sim.SANDBOX_TIER_MAX)
	if next == sim.land_tier:
		return
	sim.land_tier = next
	# Shape removes props that lost land; do not strip player-placed features on resize.
	sim.island_gen.shape_island()
	sim.notes.append("ISLA %d" % sim.land_tier)



## Sandbox UI hook to expand land tier by one step.
func sandbox_grow() -> void:
	set_sandbox_land_tier(sim.land_tier + 1)



## Sandbox UI hook to contract land tier by one step.
func sandbox_shrink() -> void:
	set_sandbox_land_tier(sim.land_tier - 1)



## Executes destructive ethics or unlock actions (bug, swarm, burn, nuke) from dialogue choices.
func _apply_action(action: Dictionary) -> void:
	var op = str(action.get("op", ""))
	if op == "bug":
		_deflesh(int(action.get("id", -1)), true)
	elif op == "swarm":
		sim.player_tools._swarm(float(action.get("x", 0.0)), float(action.get("y", 0.0)))
	elif op == "burn":
		var b = sim.building_by_id.get(int(action.get("id", -1)), {})
		if not b.is_empty():
			b.incinerate = true
			sim.notes.append("LA FABRICA ACEPTA CADAVERES.")
	elif op == "nuke":
		sim.player_tools._nuke(int(action.get("cx", 0)), int(action.get("cy", 0)))



## Spawns the agent's haul as a world item with toss physics and clears carry state.
func _drop_carried(i: int) -> void:
	if i < 0 or i >= sim.slot_count or sim.carry[i] == Catalog.CARRY_NONE:
		return
	var kind = Catalog.ITEM_WOOD
	if sim.carry[i] == Catalog.CARRY_BONE:
		kind = Catalog.ITEM_BONE
	elif sim.carry[i] == Catalog.CARRY_ORE:
		kind = Catalog.ITEM_ORE
	var dropped_carry = _add_item(kind, sim.pos_x[i], sim.pos_y[i], maxi(1, sim.carry_value[i]))
	sim.item_physics.launch_item(dropped_carry, 6.0, randf_range(70.0, 100.0), randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
	_set_carry(i, Catalog.CARRY_NONE)



## Demolish/move prep: evicts guests, riders, and occupants then marks the building inactive.
func _lift_building(b: Dictionary) -> void:
	var occ = int(b.get("occupant", -1))
	if occ >= 0 and occ < sim.claim.size():
		sim.claim[occ] = -1
		if occ < sim.link_tub.size():
			sim.link_tub[occ] = -1
	for guest in b.get("guests", []):
		var gid = int(guest.get("id", -1))
		if gid >= 0 and gid < sim.link_guest.size() and sim.link_guest[gid] == int(b.id):
			sim.link_guest[gid] = -1
	for raw in sim.agent_tick._rider_list(b):
		var rid = int(raw)
		if rid >= 0 and rid < sim.link_ride.size() and sim.link_ride[rid] == int(b.id):
			sim.link_ride[rid] = -1
	b.occupant = -1
	b.bath_t = -1.0
	b.guests = []
	b.away = []
	b.riders = []
	b.ride_slot = {}
	b.ride_age = {}
	b.lifted = true
	b.active = false
	sim.building_sim._unbind_building(b)



## Bug tool removal: vacates the slot, drops bone loot, may count toward swarm unlock progress.
func _deflesh(id: int, count_use: bool) -> void:
	if id < 0 or id >= sim.slot_count or sim.state[id] == Catalog.ST_VACANT:
		return
	var x = sim.pos_x[id]
	var y = sim.pos_y[id]
	var was_living = sim.state[id] == Catalog.ST_LIVING
	var was_dead = sim.state[id] == Catalog.ST_DEAD
	sim.agent_tick._release_mine_job(id)
	sim.building_sim._release_claim(id)
	sim.agent_tick._release_item_claims(id)
	_drop_carried(id)
	sim.agent_tick._clear_ride(id)
	if was_living:
		sim.living -= 1
		sim.deaths_total += 1
		_living_remove(id)
	elif was_dead:
		sim.dead_n = maxi(0, sim.dead_n - 1)
		_dead_remove(id)
	if id < sim.bloody.size():
		sim.bloody[id] = 0
	sim.state[id] = Catalog.ST_VACANT
	sim.spatial._hash_unlink(id)
	var bone_it = _add_item(Catalog.ITEM_BONE, x, y, 1)
	sim.item_physics.launch_item(bone_it, 6.0, randf_range(80.0, 110.0), randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	sim.dialogue._pop(x, y, ThrongClips.frame_at("ThrongA_Bones", 0))
	if was_living:
		_pulse_react_near(x, y, id)
	if count_use and sim.part_two:
		sim.bug_uses += 1
		if sim.bug_uses >= 3:
			sim.dialogue._grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")
	sim.sfx_queue.append("deflesh")
	if was_living and sim.living <= 0:
		sim.dialogue._enter_game_over()



## Starvation or hygiene failure death path that queues neglect dialogue reflection.
func _die_neglect(i: int) -> void:
	_become_corpse(i, false)
	sim.sfx_queue.append("bones")
	sim.dialogue._reflect("neglect")



## Soft death: living slot becomes timed corpse with links cleared and colony tallies updated.
func _become_corpse(i: int, with_blood: bool = false) -> void:
	if sim.state[i] != Catalog.ST_LIVING:
		return
	var x = sim.pos_x[i]
	var y = sim.pos_y[i]
	sim.state[i] = Catalog.ST_DEAD
	sim.living -= 1
	sim.dead_n += 1
	sim.deaths_total += 1
	sim.starve[i] = sim.CORPSE_LIFE
	_ensure_agent_timers(i)
	sim.bloody[i] = 1 if with_blood else 0
	_living_remove(i)
	_dead_add(i)
	_set_carry(i, Catalog.CARRY_NONE)
	if absf(sim.dir_x[i]) < 0.01:
		sim.dir_x[i] = 1.0
	else:
		sim.dir_x[i] = 1.0 if sim.dir_x[i] >= 0.0 else -1.0
	sim.dir_y[i] = 0.0
	sim.agent_tick._release_mine_job(i)
	sim.building_sim._release_claim(i)
	sim.agent_tick._release_item_claims(i)
	sim.agent_tick._clear_ride(i)
	_pulse_react_near(x, y, i)
	if sim.living <= 0:
		sim.dialogue._enter_game_over()



## Brief frightened react timer on nearby living agents after a violent death in radius.
func _pulse_react_near(x: float, y: float, skip: int = -1) -> void:
	for id in sim.spatial.query_radius(x, y, sim.REACT_KILL_R):
		var j = int(id)
		if j == skip or j < 0 or j >= sim.slot_count:
			continue
		if sim.state[j] != Catalog.ST_LIVING:
			continue
		_ensure_agent_timers(j)
		sim.react_t[j] = sim.REACT_DUR



## Public check used by animation/logic for whether another living agent is close enough to socialize.
func has_living_peer(i: int, radius: float = 40.0) -> bool:
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	for id in sim.spatial.query_radius(sim.pos_x[i], sim.pos_y[i], radius):
		var j = int(id)
		if j != i and j >= 0 and j < sim.slot_count and sim.state[j] == Catalog.ST_LIVING:
			return true
	return false



## True when the agent is a guest at an active mine building (pickaxe work animation gate).
func is_mining(i: int) -> bool:
	# Guest of a mine / mine2 — dig stay uses Pickaxe ↔ Twiddle.
	if i < 0 or i >= sim.link_guest.size():
		return false
	var bid = int(sim.link_guest[i])
	if bid < 0:
		return false
	var b: Dictionary = sim.building_by_id.get(bid, {})
	if b.is_empty() or b.dead:
		return false
	return sim.building_sim._is_mine_kind(int(b.kind))



## All core needs at OK or better, so the agent may idly socialize instead of seeking.
func _peer_content(i: int) -> bool:
	return sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK



## Agent has no sticky act, haul, mitosis, sleep, facility link, or active social beat.
func _peer_free(i: int) -> bool:
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	if sim.act[i] != 0 or sim.carry[i] != Catalog.CARRY_NONE:
		return false
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return false
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		return false
	if i < sim.sleep_t.size() and sim.sleep_t[i] > 0.0:
		return false
	if i < sim.cheer_t.size() and sim.cheer_t[i] > 0.0:
		return false
	if i < sim.react_t.size() and sim.react_t[i] > 0.0:
		return false
	if i < sim.link_guest.size() and sim.link_guest[i] >= 0:
		return false
	if i < sim.link_tub.size() and sim.link_tub[i] >= 0:
		return false
	if i < sim.link_ride.size() and sim.link_ride[i] >= 0:
		return false
	return true



## Finds the closest eligible neighbor for a spontaneous talk or sing interaction.
func _nearest_peer_partner(i: int) -> int:
	var best = -1
	var best_d = sim.PEER_R
	for id in sim.spatial.query_radius(sim.pos_x[i], sim.pos_y[i], sim.PEER_R):
		var j = int(id)
		if j == i or j < 0 or j >= sim.slot_count:
			continue
		if not _peer_free(j) or not _peer_content(j):
			continue
		var d = sim.spatial._dist_i(i, sim.pos_x[j], sim.pos_y[j])
		if d < best_d:
			best_d = d
			best = j
	return best



## Rare idle beat: pairs two content agents, stops movement, and runs peer talk timers.
func _try_peer_social(i: int) -> bool:
	# Content thronglets stop, face a free peer, and hold a talk/sing beat.
	_ensure_agent_timers(i)
	if not _peer_free(i) or not _peer_content(i):
		return false
	# Sparse attempts so the colony does not freeze in chat clusters.
	if ((sim.frame_i + i) % 75) != 0 or randf() > 0.35:
		return false
	var j = _nearest_peer_partner(i)
	if j < 0:
		return false
	_ensure_agent_timers(j)
	var sing = 1 if randf() < 0.55 else 0
	sim.peer_t[i] = sim.PEER_DUR
	sim.peer_t[j] = sim.PEER_DUR
	sim.peer_of[i] = j
	sim.peer_of[j] = i
	sim.peer_sing[i] = sing
	sim.peer_sing[j] = sing
	sim.dir_x[i] = 0.0
	sim.dir_y[i] = 0.0
	sim.dir_x[j] = 0.0
	sim.dir_y[j] = 0.0
	if i < sim.seek_t.size():
		sim.seek_t[i] = 0.0
	if j < sim.seek_t.size():
		sim.seek_t[j] = 0.0
	return true



## Ends peer social state on one agent and mirrors cleanup on its paired partner.
func _clear_peer_social(i: int) -> void:
	if i < 0 or i >= sim.peer_t.size():
		return
	var j = int(sim.peer_of[i]) if i < sim.peer_of.size() else -1
	sim.peer_t[i] = 0.0
	sim.peer_of[i] = -1
	if i < sim.peer_sing.size():
		sim.peer_sing[i] = 0
	if j >= 0 and j < sim.peer_of.size() and int(sim.peer_of[j]) == i:
		sim.peer_t[j] = 0.0
		sim.peer_of[j] = -1
		if j < sim.peer_sing.size():
			sim.peer_sing[j] = 0



## Detects campfire features near an agent for mood, damage, or bark logic.
func near_fire(i: int, radius: float = 48.0) -> bool:
	if i < 0 or i >= sim.slot_count:
		return false
	for feat in sim.fires:
		if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
			continue
		if sim.spatial._dist_i(i, float(feat.x), float(feat.y)) < radius:
			return true
	return false



## True when a living agent is wandering toward a dwelling without being a building guest.
func approaching_home(i: int) -> bool:
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	if sim.link_guest[i] >= 0:
		return false
	for b in sim.blds_home:
		if b.dead:
			continue
		if sim.spatial._dist_i(i, float(b.x), float(b.y)) < 88.0:
			return true
	return false



## Registers a corpse slot id in the dead iteration list.
func _dead_add(i: int) -> void:
	sim.dead_ids.append(i)



## Removes one id from the dead list when the corpse is cleared or vacated.
func _dead_remove(i: int) -> void:
	for k in sim.dead_ids.size():
		if int(sim.dead_ids[k]) == i:
			_dead_remove_at(k)
			return



## Swap-removes index k from the dense dead id array.
func _dead_remove_at(k: int) -> void:
	var last = sim.dead_ids.size() - 1
	if k < 0 or k > last:
		return
	sim.dead_ids[k] = sim.dead_ids[last]
	sim.dead_ids.resize(last)



## Fully recycles a slot: clears links, haul, hash entry, and may trigger game over if last living.
func _vacate(i: int) -> void:
	if i < 0 or i >= sim.slot_count or sim.state[i] == Catalog.ST_VACANT:
		return
	var was_living = sim.state[i] == Catalog.ST_LIVING
	var was_dead = sim.state[i] == Catalog.ST_DEAD
	if was_living:
		sim.living -= 1
		_living_remove(i)
	elif was_dead:
		sim.dead_n = maxi(0, sim.dead_n - 1)
		_dead_remove(i)
	_set_carry(i, Catalog.CARRY_NONE)
	if i < sim.bloody.size():
		sim.bloody[i] = 0
	sim.state[i] = Catalog.ST_VACANT
	sim.agent_tick._release_mine_job(i)
	sim.building_sim._release_claim(i)
	sim.agent_tick._release_item_claims(i)
	sim.agent_tick._clear_ride(i)
	sim.spatial._hash_unlink(i)
	if was_living and sim.living <= 0:
		sim.dialogue._enter_game_over()



## Rolls newborn color variant when adapt/numb/hard mutations are active.
func _birth_tint(fallback: int) -> int:
	if bool(sim.mutations.get("adapt", false)) and randf() < 0.55:
		return Catalog.TINT_ADAPT
	if bool(sim.mutations.get("numb", false)) and randf() < 0.45:
		return Catalog.TINT_NUMB
	if bool(sim.mutations.get("hard", false)) and randf() < 0.35:
		return Catalog.TINT_NUMB
	return fallback % Catalog.TINTS.size()



## Delegates late-game super-island expansion to island_gen when milestones demand it.
func _expand_super_island(announce: bool = true) -> void:
	sim.island_gen.expand_super_island(announce)



## Scatters rooted rock nodes with ore on the home chunk after market unlock for mining tutorial.
func _seed_early_ore(want: int = 12) -> void:
	if want <= 0:
		return
	var placed = 0
	var c = Vector2i(0, 0)
	var ck = sim.spatial._ck(c.x, c.y)
	if not sim.chunks.has(ck):
		_ensure(c.x, c.y)
	var tiles = sim.chunks[ck].tiles
	for _try in 120:
		if placed >= want:
			break
		var lx = randi() % Catalog.CHUNK
		var ly = randi() % Catalog.CHUNK
		var tile = int(tiles[ly * Catalog.CHUNK + lx])
		if tile == Catalog.TILE_VOID or tile == Catalog.TILE_WATER:
			continue
		var wx = float((c.x * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy = float((c.y * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		if sim.collision._blocked(wx, wy):
			continue
		if sim.island_gen.near_spawn(wx, wy):
			continue
		if not _feature_at(wx, wy, 14.0).is_empty():
			continue
		if not _building_at(wx, wy, 14.0).is_empty():
			continue
		var feat = _add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 3, true)
		if not feat.is_empty():
			placed += 1



## Campaign world setup after reset: home reveal, starter egg, and live session flag.
func _bootstrap_new() -> void:
	var keep = sim.world_seed
	_reset_world()
	sim.world_seed = keep
	if sim.world_seed == 0:
		sim.world_seed = 1
	_reveal(0, 0)
	sim.island_gen.clear_spawn()
	_spawn_starter_egg()
	sim.spatial._rebuild_hash()
	sim.session_live = true



## Sandbox world setup: full unlocks, gem stipend, shaped island, stripped scatter props.
func _bootstrap_sandbox(tier: int) -> void:
	var keep = sim.world_seed
	_reset_world()
	sim.sandbox_mode = true
	sim.world_seed = keep
	if sim.world_seed == 0:
		sim.world_seed = 1
	sim.land_tier = clampi(tier, sim.SANDBOX_TIER_MIN, sim.SANDBOX_TIER_MAX)
	sim.dialogue._unlock_all()
	sim.gems = sim.SANDBOX_GEMS
	sim.gems_peak = sim.SANDBOX_GEMS
	sim.total_gems_earned = sim.SANDBOX_GEMS
	sim.part_two = true
	sim.tutorial_i = -1
	sim.count_unknown = false
	_reveal(0, 0)
	sim.island_gen.clear_spawn()
	sim.island_gen.shape_island()
	_sandbox_strip_props()
	sim.spatial._rebuild_hash()
	sim.session_live = true



## Removes procedurally scattered features so sandbox starts from a clean shaped island.
func _sandbox_strip_props() -> void:
	if not sim.sandbox_mode:
		return
	for feat in sim.features:
		if feat.dead:
			continue
		_kill_feature(feat)



## Drops the fixed falling egg item that begins the campaign before first hatch.
func _spawn_starter_egg() -> void:
	var it = _add_item(Catalog.ITEM_EGG, 256.0, 256.0, 0)
	it.fixed = true
	it.air = sim.EGG_FALL
	it.fall = 0.0
	it.hatch = 0
	it.need = sim.EGG_NEED
	it.shake = 0.0
	sim.notes.append("UN HUEVO CAE DEL CIELO.")
	sim.sfx_queue.append("egg_fall")



## Hard reset of all simulation containers, agent arrays, progression flags, and spatial indexes.
func _reset_world() -> void:
	sim.revealed.clear()
	sim.chunks.clear()
	sim.dirty_chunks.clear()
	sim.features.clear()
	sim.feature_by_id.clear()
	sim.feature_cell.clear()
	sim.features_by_chunk.clear()
	sim.inland_cache.clear()
	sim.tree_seeds.clear()
	sim.items.clear()
	sim.item_by_id.clear()
	sim.buildings.clear()
	sim.building_by_id.clear()
	sim.building_cell.clear()
	sim.next_feature_id = 1
	sim.next_item_id = 1
	sim.next_building_id = 1
	sim.hand_id = -1
	sim.player_tools._clear_held()
	sim.scoop_item_ids.clear()
	sim.scoop_dead_ids.clear()
	sim.sponge_id = -1
	sim.sponge_hold = 0.0
	sim.slot_count = 0
	sim.cursor = 0
	sim.mood_face = "base"
	sim._mood_base = 0
	sim._mood_happy = 0
	sim._mood_cry = 0
	sim._mood_sus = 0
	sim._mood_freak = 0
	sim.living = 0
	sim.dead_n = 0
	sim.dead_ids = PackedInt32Array()
	sim.carry_wood_n = 0
	sim.carry_bone_n = 0
	sim.carry_ore_n = 0
	_invalidate_item_counts()
	sim.peak = 0
	sim.gems = 0
	sim.gems_peak = 0
	sim.total_gems_earned = 0
	sim.deaths_total = 0
	sim.land_tier = 0
	sim.sandbox_mode = false
	sim._shaping_island = false
	sim.special_biomes = {}
	sim.glitch_seen = false
	sim.glitch_t = 0.0
	sim.gaze_home.clear()
	sim.barks.clear()
	sim.wash_fx_pending.clear()
	sim.wear.clear()
	sim.wear_from.clear()
	sim.trees_chopped = 0
	sim.stumps_cleared = 0
	sim.bug_uses = 0
	sim.tnt_used = 0
	sim.goo_count = 0
	sim.part_two = false
	sim.mountain_seen = false
	sim.cap_told = false
	sim.frozen = false
	sim.game_over = false
	sim.paused = false
	sim.autosave_t = 0.0
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim.player_name = ""
	sim.tutorial_i = -1
	sim.count_unknown = false
	sim.talked_trees = {}
	sim.learn_talked = false
	sim.moral = 0
	sim.mutations.clear()
	sim.monolith_tier_spawned.clear()
	sim.pos_x = PackedFloat32Array()
	sim.pos_y = PackedFloat32Array()
	sim.dir_x = PackedFloat32Array()
	sim.dir_y = PackedFloat32Array()
	sim.fed = PackedFloat32Array()
	sim.amused = PackedFloat32Array()
	sim.clean = PackedFloat32Array()
	sim.cool = PackedFloat32Array()
	sim.starve = PackedFloat32Array()
	sim.hungry_t = PackedFloat32Array()
	sim.wander_t = PackedFloat32Array()
	sim.avoid_t = PackedFloat32Array()
	sim.mito_t = PackedFloat32Array()
	sim.mito_charge = PackedFloat32Array()
	sim.shake_t = PackedFloat32Array()
	sim.buff_t = PackedFloat32Array()
	sim.react_t = PackedFloat32Array()
	sim.cheer_t = PackedFloat32Array()
	sim.sleep_t = PackedFloat32Array()
	sim.peer_t = PackedFloat32Array()
	sim.peer_of = PackedInt32Array()
	sim.peer_sing = PackedByteArray()
	sim.drop_t = PackedFloat32Array()
	sim.bloody = PackedByteArray()
	sim.state = PackedInt32Array()
	sim.carry = PackedInt32Array()
	sim.carry_value = PackedInt32Array()
	sim.tint = PackedInt32Array()
	sim.claim = PackedInt32Array()
	sim.mine_job = PackedInt32Array()
	sim.act = PackedInt32Array()
	sim.act_t = PackedFloat32Array()
	sim.tick_stamp = PackedInt32Array()
	sim.pops.clear()
	sim.wash_fx_pending.clear()
	sim.celebrate_t = 0.0
	sim.hash_next = PackedInt32Array()
	sim.hash_cell = PackedInt32Array()
	sim.link_tub = PackedInt32Array()
	sim.link_ride = PackedInt32Array()
	sim.link_guest = PackedInt32Array()
	sim.link_claim = PackedInt32Array()
	sim.link_ball = PackedInt32Array()
	sim.living_ids = PackedInt32Array()
	sim.living_at = PackedInt32Array()
	sim.bark_cool = PackedFloat32Array()
	sim.penned_flag = PackedByteArray()
	sim.fires.clear()
	sim.items_apple.clear()
	sim.items_ball.clear()
	sim.items_wood.clear()
	sim.items_bone.clear()
	sim.items_ore.clear()
	sim.blds_tub.clear()
	sim.blds_round.clear()
	sim.blds_home.clear()
	sim.blds_mine.clear()
	sim.blds_show.clear()
	sim.seek_x = PackedFloat32Array()
	sim.seek_y = PackedFloat32Array()
	sim.seek_t = PackedFloat32Array()
	sim.hash_head.fill(-1)
	sim.paint_epoch += 1
	sim.feat_mesh_epoch += 1



## Spawns a living agent and updates peak population gates when a new high is reached.
func _push_slot(x: float, y: float, fed_v: float, fun_v: float, clean_v: float, cool_v: float, tint_i: int) -> int:
	var id = _push_slot_quiet(x, y, fed_v, fun_v, clean_v, cool_v, tint_i)
	if id < 0:
		return -1
	if sim.living > sim.peak:
		sim.peak = sim.living
		sim.dialogue._refresh_pop_gates()
	return id



## Allocates parallel agent arrays and spatial hash link without milestone side effects.
func _push_slot_quiet(x: float, y: float, fed_v: float, fun_v: float, clean_v: float, cool_v: float, tint_i: int) -> int:
	if sim.slot_count >= Catalog.MAX_SLOTS:
		return -1
	var ang = randf() * TAU
	sim.pos_x.append(x)
	sim.pos_y.append(y)
	sim.dir_x.append(cos(ang))
	sim.dir_y.append(sin(ang))
	sim.fed.append(fed_v)
	sim.amused.append(fun_v)
	sim.clean.append(clean_v)
	sim.cool.append(cool_v)
	sim.starve.append(0.0)
	sim.hungry_t.append(0.0)
	sim.wander_t.append(randf_range(0.2, 1.2))
	sim.avoid_t.append(0.0)
	sim.mito_t.append(0.0)
	sim.mito_charge.append(0.0)
	sim.shake_t.append(0.0)
	sim.buff_t.append(0.0)
	sim.react_t.append(0.0)
	sim.cheer_t.append(0.0)
	sim.sleep_t.append(0.0)
	sim.peer_t.append(0.0)
	sim.peer_of.append(-1)
	sim.peer_sing.append(0)
	sim.drop_t.append(0.0)
	sim.bloody.append(0)
	sim.state.append(Catalog.ST_LIVING)
	sim.carry.append(Catalog.CARRY_NONE)
	sim.carry_value.append(0)
	sim.tint.append(_birth_tint(tint_i))
	sim.claim.append(-1)
	sim.mine_job.append(-1)
	sim.act.append(0)
	sim.act_t.append(0.0)
	sim.tick_stamp.append(0)
	sim.hash_next.append(-1)
	sim.hash_cell.append(-1)
	sim.link_tub.append(-1)
	sim.link_ride.append(-1)
	sim.link_guest.append(-1)
	sim.link_claim.append(-1)
	sim.link_ball.append(-1)
	sim.living_at.append(-1)
	sim.bark_cool.append(0.0)
	sim.penned_flag.append(0)
	sim.seek_x.append(0.0)
	sim.seek_y.append(0.0)
	sim.seek_t.append(0.0)
	var id = sim.slot_count
	sim.slot_count += 1
	sim.living += 1
	_living_add(id)
	sim.spatial._hash_link(id)
	return id



## Marks a chunk known, materializes terrain, and invalidates walk and inland caches on first sight.
func _reveal(cx: int, cy: int) -> void:
	var ck = sim.spatial._ck(cx, cy)
	var fresh = not sim.revealed.has(ck)
	sim.revealed[ck] = true
	_ensure(cx, cy)
	if not fresh:
		return
	sim.cap_told = false
	# Fog→land changes cliff margins on this chunk and its borders.
	sim.inland_cache.clear()
	_invalidate_walk_cells()
	sim.spatial._mark_dirty(ck)



## Reveals home or island chunks only, skipping pure ocean fog tiles.
func _try_reveal(cx: int, cy: int) -> void:
	if cx == 0 and cy == 0 or sim.island_gen.is_island_chunk(cx, cy):
		_reveal(cx, cy)



## Whether chunk coordinates have been pulled out of fog for simulation and rendering.
func _is_known_chunk(cx: int, cy: int) -> bool:
	return sim.revealed.has(sim.spatial._ck(cx, cy))



## Lazy chunk creation: biome fill, island shape on home chunk, scatter props, dirty mark.
func _ensure(cx: int, cy: int) -> void:
	var ck = sim.spatial._ck(cx, cy)
	if sim.chunks.has(ck):
		return
	var biome = _biome_formula(cx, cy)
	var tiles = _fill_tiles(cx, cy, biome)
	sim.chunks[ck] = {"biome": biome, "axis": "", "tiles": tiles, "base": tiles.duplicate()}
	if cx == 0 and cy == 0 and not sim._shaping_island:
		sim.island_gen.shape_island()
		if not sim.sandbox_mode:
			sim.island_gen.seed_mine_nodes(0, 0)
	if not sim._shaping_island and not sim.sandbox_mode:
		_scatter(cx, cy, biome)
	sim.spatial._mark_dirty(ck)



## Procedural tile buffer for a chunk from biome id and special circular patches.
func _fill_tiles(cx: int, cy: int, biome: String) -> PackedByteArray:
	var tiles = PackedByteArray()
	tiles.resize(Catalog.CHUNK * Catalog.CHUNK)
	var base = Catalog.TILE_GRASS
	if biome == "hills" or biome == "mountain":
		base = Catalog.TILE_DIRT
	elif biome == "bloom":
		base = Catalog.TILE_BLOOM
	for i in tiles.size():
		tiles[i] = Catalog.TILE_VOID
	if cx == 0 and cy == 0:
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				tiles[ly * Catalog.CHUNK + lx] = base
	elif sim.special_biomes.has(sim.spatial._ck(cx, cy)):
		var paint = Catalog.TILE_GRASS
		if biome == "mountain":
			paint = Catalog.TILE_DIRT
		elif biome == "glitch":
			paint = Catalog.TILE_GOO
		var mid = float(Catalog.CHUNK) * 0.5
		for ly in Catalog.CHUNK:
			for lx in Catalog.CHUNK:
				var dx = float(lx) - mid
				var dy = float(ly) - mid
				if dx * dx + dy * dy < mid * mid * 0.72:
					tiles[ly * Catalog.CHUNK + lx] = paint
	return tiles



## Feature kind filter for node, super, and mnode types used in mining placement rules.
func _is_mine_node(kind: int) -> bool:
	return kind == Catalog.FEAT_NODE or kind == Catalog.FEAT_SUPER or kind == Catalog.FEAT_MNODE



## Campaign spacing check so scatter does not stack props on adjacent feature cells.
func _feature_crowded(x: float, y: float, kind: int) -> bool:
	if _is_mine_node(kind):
		return false
	var cell = sim.spatial._cell_vec(x, y)
	var reach = 1 if kind == Catalog.FEAT_TREE else 2
	for oy in range(-reach, reach + 1):
		for ox in range(-reach, reach + 1):
			if ox == 0 and oy == 0:
				continue
			var key = Vector2i(cell.x + ox, cell.y + oy)
			if not sim.feature_cell.has(key):
				continue
			var feat = sim.feature_by_id.get(int(sim.feature_cell[key]), {})
			if feat.is_empty() or feat.dead:
				continue
			if kind == Catalog.FEAT_TREE and int(feat.kind) == Catalog.FEAT_TREE:
				continue
			return true
	return false



## Guards placement away from existing mine node footprints in neighboring cells.
func _near_mine_node(x: float, y: float) -> bool:
	var cell = sim.spatial._cell_vec(x, y)
	for oy in range(-3, 4):
		for ox in range(-3, 4):
			var key = Vector2i(cell.x + ox, cell.y + oy)
			if not sim.feature_cell.has(key):
				continue
			var feat = sim.feature_by_id.get(int(sim.feature_cell[key]), {})
			if not feat.is_empty() and not feat.dead and _is_mine_node(int(feat.kind)):
				return true
	return false



## Feedback when something steps off the island into void tiles without ending the run.
func _fall_void(x: float, y: float) -> void:
	sim.notes.append("SE CAE AL VACIO. LA PARTIDA SIGUE.")
	sim.sfx_queue.append("crush")



## Counts features of one kind on a chunk for scatter density caps.
func _count_kind_on(cx: int, cy: int, kind: int) -> int:
	return sim.island_gen.count_kind_on(cx, cy, kind)



## Low-rate roll for rare cosmetics, mega ores, fire, totem, and curer on one tile.
func _scatter_one(cx: int, cy: int, wx: float, wy: float, lx: int, ly: int) -> void:
	var roll = sim.spatial._rand(cx, cy, lx, ly, 31)
	if roll < 0.008:
		_add_feature(Catalog.FEAT_COSMETIC, wx, wy, 1, 0, true)
	elif roll < 0.012:
		_add_feature(Catalog.FEAT_COSMETIC_BAD, wx, wy, 1, 0, true)
	elif roll < 0.016:
		_add_feature(Catalog.FEAT_BIGROCK, wx, wy, 4, 1, true)
	elif roll < 0.019:
		_add_feature(Catalog.FEAT_ORE_MEGA, wx, wy, 1, 3, true)
	elif roll < 0.021:
		_add_feature(Catalog.FEAT_ORE_SUPER, wx, wy, 1, 4, true)
	elif roll < 0.023:
		_add_feature(Catalog.FEAT_ORE_ULTRA, wx, wy, 1, 5, true)
	elif roll < 0.026:
		if not _add_feature(Catalog.FEAT_FIRE, wx, wy, 1, 0, true).is_empty() and sim.session_live:
			sim.sfx_queue.append("fire_start")
	elif roll < 0.029:
		_add_feature(Catalog.FEAT_TOTEM, wx, wy, 1, 0, true)
	elif roll < 0.032:
		_add_feature(Catalog.FEAT_CURER, wx, wy, 1, 0, true)



## Fills a newly revealed chunk with biome-weighted trees, rocks, nodes, and rare props.
func _scatter(cx: int, cy: int, biome: String) -> void:
	if sim.island_gen.is_island_chunk(cx, cy):
		sim.island_gen.scatter_island(cx, cy)
		return
	_scatter_biome_props(cx, cy, biome)
	var spec: Dictionary = sim.biome_by_id.get(biome, {})
	var ck = sim.spatial._ck(cx, cy)
	for ly in Catalog.CHUNK:
		for lx in Catalog.CHUNK:
			var tile = int(sim.chunks[ck].tiles[ly * Catalog.CHUNK + lx])
			if tile == Catalog.TILE_WATER or tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_VOID:
				continue
			var wx = float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
			var wy = float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
			if not sim.collision._land_inland(wx, wy):
				continue
			# Jitter 0.25..1.75 keeps mean density but breaks uniform grid fills.
			var tree_chance = float(spec.get("tree", 0.0)) * (0.25 + sim.spatial._rand(cx, cy, lx, ly, 19) * 1.5)
			if sim.spatial._rand(cx, cy, lx, ly, 1) < tree_chance:
				_add_feature(Catalog.FEAT_TREE, wx, wy, 1, 0, true)
			elif sim.spatial._rand(cx, cy, lx, ly, 2) < float(spec.get("ore", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 2, 1, true)
			elif sim.spatial._rand(cx, cy, lx, ly, 3) < float(spec.get("rock", 0.0)):
				_add_feature(Catalog.FEAT_ROCK, wx, wy, 1, 0, true)
			elif sim.spatial._rand(cx, cy, lx, ly, 4) < float(spec.get("super", 0.0)):
				_add_feature(Catalog.FEAT_SUPER, wx, wy, 1, 2, true)
			elif sim.spatial._rand(cx, cy, lx, ly, 5) < float(spec.get("node", 0.0)):
				_add_feature(Catalog.FEAT_NODE, wx, wy, 1, 1, true)
			else:
				_scatter_one(cx, cy, wx, wy, lx, ly)



## Places a rooted feature when campaign spacing and footprint rules pass, then indexes cells.
func _add_feature(kind: int, x: float, y: float, hp: int, ore: int, rooted: bool = false) -> Dictionary:
	var at = Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	# Campaign keeps the egg clearing tree-free; sandbox places freely.
	if kind == Catalog.FEAT_TREE and not sim.sandbox_mode and sim.island_gen.near_spawn(x, y):
		return {}
	if rooted and not sim.sandbox_mode and not _stands(x, y, _span_for_feature(kind)):
		return {}
	if not _is_mine_node(kind) and _near_mine_node(x, y):
		return {}
	# Campaign scatter keeps props spaced; sandbox places adjacent rocks/trees freely.
	if not sim.sandbox_mode and _feature_crowded(x, y, kind):
		return {}
	var cells = sim.building_sim._footprint_cells(x, y, Catalog.footprint_for_feature(kind))
	if rooted and not sim.sandbox_mode and not sim.building_sim._footprint_holds(cells):
		return {}
	for cell in cells:
		if sim.feature_cell.has(cell) or sim.building_cell.has(cell):
			return {}
	var c = sim.spatial._chunk_at(x, y)
	var id = sim.next_feature_id
	sim.next_feature_id += 1
	var feat = {
		"id": id,
		"kind": kind,
		"x": x,
		"y": y,
		"hp": hp,
		"ore": ore,
		"cx": c.x,
		"cy": c.y,
		"dead": false,
		"rooted": rooted,
	}
	sim.features.append(feat)
	sim.feature_by_id[id] = feat
	_feat_chunk_index(feat)
	if kind == Catalog.FEAT_FIRE:
		sim.fires.append(feat)
	for cell in cells:
		sim.feature_cell[cell] = id
	sim.feat_mesh_epoch += 1
	_invalidate_walk_cells()
	return feat



## Removes a feature from the world, fires list, and spatial indexes when destroyed.
func _kill_feature(feat: Dictionary) -> void:
	if feat.is_empty() or feat.dead:
		return
	feat.dead = true
	sim.lists_dirty = true
	sim.feat_mesh_epoch += 1
	_feat_chunk_unindex(feat)
	if int(feat.kind) == Catalog.FEAT_FIRE:
		sim.fires.erase(feat)
	_unbind_feature(feat)
	sim.feature_by_id.erase(int(feat.id))
	sim.cap_told = false
	_invalidate_walk_cells()



## Spawns a ground item, registers it in item_by_id, and updates kind indexes and counts.
func _add_item(kind: int, x: float, y: float, value: int) -> Dictionary:
	var id = sim.next_item_id
	sim.next_item_id += 1
	var it = {"id": id, "kind": kind, "x": x, "y": y, "value": value, "held": false, "dead": false, "fixed": false, "air": 0.0, "vz": 0.0, "vx": 0.0, "vy": 0.0, "falling_void": false, "rest": 0.0}
	if kind == Catalog.ITEM_BALL:
		it.life = sim.BALL_LIFE
	if kind == Catalog.ITEM_APPLE:
		it.bites_left = 3
		it.bite = 0.0
	sim.items.append(it)
	sim.item_by_id[id] = it
	_index_item(it)
	_invalidate_item_counts()
	return it



## Places a building when the footprint binds, then indexes it and refreshes factory and walk caches.
func _add_building(kind: int, x: float, y: float) -> Dictionary:
	var id = sim.next_building_id
	sim.next_building_id += 1
	var b = {
		"id": id,
		"kind": kind,
		"x": x,
		"y": y,
		"timer": 1.5,
		"occupant": -1,
		"bath_t": -1.0,
		"node": 0,
		"buffer": 0,
		"burn": 0.0,
		"incinerate": false,
		"active": false,
		"dead": false,
	}
	if not sim.building_sim._bind_building_at(b, x, y):
		return {}
	sim.buildings.append(b)
	sim.building_by_id[id] = b
	_index_building(b)
	sim.building_sim._invalidate_factory_cache()
	_invalidate_walk_cells()
	return b



## Appends a live item dict into per-kind lists used for fast nearest-item seeks.
func _index_item(it: Dictionary) -> void:
	match int(it.kind):
		Catalog.ITEM_APPLE:
			sim.items_apple.append(it)
		Catalog.ITEM_BALL:
			sim.items_ball.append(it)
		Catalog.ITEM_WOOD:
			sim.items_wood.append(it)
		Catalog.ITEM_BONE:
			sim.items_bone.append(it)
		Catalog.ITEM_ORE:
			sim.items_ore.append(it)



## Routes a live building into per-kind lists for fast nearest-building queries.
func _index_building(b: Dictionary) -> void:
	match int(b.kind):
		Catalog.BLD_TUB:
			sim.blds_tub.append(b)
		Catalog.BLD_ROUND:
			sim.blds_round.append(b)
		Catalog.BLD_DWELL, Catalog.BLD_FANCY:
			sim.blds_home.append(b)
		Catalog.BLD_MINE, Catalog.BLD_MINE2:
			sim.blds_mine.append(b)
		Catalog.BLD_THEATRE:
			sim.blds_show.append(b)



## Rebuilds item and building kind buckets after load, deaths, or bulk edits.
func _rebuild_kind_indexes() -> void:
	sim.items_apple.clear()
	sim.items_ball.clear()
	sim.items_wood.clear()
	sim.items_bone.clear()
	sim.items_ore.clear()
	sim.blds_tub.clear()
	sim.blds_round.clear()
	sim.blds_home.clear()
	sim.blds_mine.clear()
	sim.blds_show.clear()
	_invalidate_item_counts()
	for it in sim.items:
		if it.dead:
			continue
		_index_item(it)
	for b in sim.buildings:
		if b.dead:
			continue
		_index_building(b)



## Marks a building dead, clears occupant claims, and refreshes walk and factory caches.
func _remove_building(b: Dictionary) -> void:
	b.dead = true
	sim.building_sim._unbind_building(b)
	sim.building_by_id.erase(int(b.id))
	sim.cap_told = false
	var occ = int(b.occupant)
	if occ >= 0 and occ < sim.claim.size():
		sim.claim[occ] = -1
	sim.building_sim._invalidate_factory_cache()
	_invalidate_walk_cells()



## Pays a recipe cost by removing nearby ground items then agents' carried haul stacks.
func _consume_kind(kind: int, count: int, near_x: float, near_y: float) -> bool:
	if count <= 0:
		return true
	_invalidate_item_counts()
	if count_item(kind) < count:
		return false
	var left = count
	var found: Array = []
	for it in sim.items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		found.append(it)
	found.sort_custom(func(a, b):
		var da = sim.spatial._dist_point(near_x, near_y, float(a.x), float(a.y))
		var db = sim.spatial._dist_point(near_x, near_y, float(b.x), float(b.y))
		return da < db
	)
	for it in found:
		if left <= 0:
			break
		it.dead = true
		left -= 1
	if left <= 0:
		_invalidate_item_counts()
		return true
	var carriers: Array = []
	for raw in sim.living_ids:
		var i = int(raw)
		if not _carry_matches(i, kind):
			continue
		carriers.append(i)
	carriers.sort_custom(func(a, b):
		return sim.spatial._dist_i(int(a), near_x, near_y) < sim.spatial._dist_i(int(b), near_x, near_y)
	)
	for i in carriers:
		if left <= 0:
			break
		_set_carry(int(i), Catalog.CARRY_NONE)
		left -= 1
	_invalidate_item_counts()
	return left <= 0



## Tests whether an agent's carried haul satisfies a requested ingredient kind.
func _carry_matches(i: int, kind: int) -> bool:
	if i < 0 or i >= sim.slot_count:
		return false
	if kind == Catalog.ITEM_WOOD:
		return sim.carry[i] == Catalog.CARRY_WOOD
	if kind == Catalog.ITEM_BONE:
		return sim.carry[i] == Catalog.CARRY_BONE
	if kind == Catalog.ITEM_ORE:
		return sim.carry[i] == Catalog.CARRY_ORE
	return false



## Closest unheld ground item of a kind within max_dist of a world point.
func _nearest_item(x: float, y: float, kind: int, max_dist: float) -> Dictionary:
	var best = {}
	var best_d = max_dist
	for it in sim.agent_tick._items_of_kind(kind):

		if it.dead or it.held or int(it.kind) != kind:
			continue
		var d = sim.spatial._dist_point(x, y, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best



## Proximity pick used by grab and tool code to resolve items under a point.
func _item_at(x: float, y: float, radius: float) -> Dictionary:
	return _nearest_item_any(x, y, radius)



## Nearest unheld item of any kind inside a radius for generic pickup queries.
func _nearest_item_any(x: float, y: float, radius: float) -> Dictionary:
	var best = {}
	var best_d = radius
	for it in sim.items:
		if it.dead or it.held:
			continue
		var d = sim.spatial._dist_point(x, y, float(it.x), float(it.y))
		if d <= best_d:
			best_d = d
			best = it
	return best



## Resolves features via cell ownership and footprint reach for tool and eye hits.
func _feature_at(x: float, y: float, radius: float) -> Dictionary:
	var cell = sim.spatial._cell_vec(x, y)
	var owned = int(sim.feature_cell.get(cell, -1))
	if owned >= 0:
		var hit = sim.feature_by_id.get(owned, {})
		if not hit.is_empty() and not hit.dead:
			return hit
	var best = {}
	var best_d = radius
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var key = Vector2i(cell.x + ox, cell.y + oy)
			if not sim.feature_cell.has(key):
				continue
			var feat = sim.feature_by_id.get(int(sim.feature_cell[key]), {})
			if feat.is_empty() or feat.dead:
				continue
			var size = Catalog.footprint_for_feature(int(feat.kind))
			var reach = radius + float(maxi(size.x, size.y) - 1) * float(Catalog.TILE) * 0.5
			var d = sim.spatial._dist_point(x, y, float(feat.x), float(feat.y))
			if d <= reach and d <= best_d:
				best_d = d
				best = feat
	return best



## Resolves buildings via building_cell or footprint distance for placement checks.
func _building_at(x: float, y: float, radius: float) -> Dictionary:
	var cell = sim.spatial._cell_vec(x, y)
	var owned = int(sim.building_cell.get(cell, -1))
	if owned >= 0:
		var hit = sim.building_by_id.get(owned, {})
		if not hit.is_empty() and not hit.dead:
			return hit
	var best = {}
	var best_d = radius
	for b in sim.buildings:
		if b.dead:
			continue
		var size = Catalog.footprint_for_building(int(b.kind))
		var reach = radius + float(maxi(size.x, size.y) - 1) * float(Catalog.TILE) * 0.5
		var d = sim.spatial._dist_point(x, y, float(b.x), float(b.y))
		if d <= reach and d <= best_d:
			best_d = d
			best = b
	return best



## Finds the closest living thronglet near a point inside the search radius.
func _nearest_living(x: float, y: float, radius: float) -> int:
	return sim.spatial.find_thronglet(x, y, radius, true)



## Finds the closest corpse agent for neglect and corpse interaction logic.
func _nearest_corpse(x: float, y: float, radius: float) -> int:
	var best = -1
	var best_d = radius
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_DEAD:
			continue
		var d = sim.spatial._dist_i(i, x, y)
		if d < best_d:
			best_d = d
			best = i
	return best



## True when any live egg item exists for hatch and progression gates.
func _has_egg() -> bool:
	for it in sim.items:
		if not it.dead and int(it.kind) == Catalog.ITEM_EGG:
			return true
	return false



## Tallies living agents inside a spatial query radius.
func _count_living_near(x: float, y: float, radius: float) -> int:
	var n = 0
	for id in sim.spatial.query_radius(x, y, radius):
		if sim.state[int(id)] == Catalog.ST_LIVING:
			n += 1
	return n



## Counts loose unheld ground items of a kind near a point.
func _count_items_near(kind: int, x: float, y: float, radius: float) -> int:
	var n = 0
	for it in sim.items:
		if it.dead or it.held or int(it.kind) != kind:
			continue
		if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) <= radius:
			n += 1
	return n



## Scans revealed chunks for pollution goo tiles used by mop limits and UI.
func _count_goo() -> int:
	var n = 0
	for ck in sim.chunks.keys():
		var tiles: PackedByteArray = sim.chunks[ck].tiles
		for tile in tiles:
			if int(tile) == Catalog.TILE_GOO:
				n += 1
	return n



## Registers a slot in the dense living_ids roster when an agent becomes alive.
func _living_add(i: int) -> void:
	if i < 0 or i >= sim.living_at.size():
		return
	if sim.living_at[i] >= 0:
		return
	sim.living_at[i] = sim.living_ids.size()
	sim.living_ids.append(i)



## Swap-removes a slot from living_ids when an agent dies or vacates.
func _living_remove(i: int) -> void:
	if i < 0 or i >= sim.living_at.size():
		return
	var at = sim.living_at[i]
	if at < 0:
		return
	var last_i = sim.living_ids.size() - 1
	var last = int(sim.living_ids[last_i])
	sim.living_ids[at] = last
	if last < sim.living_at.size():
		sim.living_at[last] = at
	sim.living_ids.resize(last_i)
	sim.living_at[i] = -1



## Whether a feature may be grabbed (loose rocks, not rooted terrain props).
func _feature_movable(feat: Dictionary) -> bool:
	if feat.is_empty() or feat.dead or bool(feat.get("rooted", false)):
		return false
	# Terrain trees stay planted. Only loose rocks can be carried.
	return int(feat.kind) == Catalog.FEAT_ROCK



## Marks trees, stumps, and cosmetics rooted so they cannot be dragged.
func _anchor_terrain_feature(feat: Dictionary) -> void:
	var kind = int(feat.kind)
	if kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		feat.rooted = true



## Adds a feature to its chunk bucket for culling and rect queries.
func _feat_chunk_index(feat: Dictionary) -> void:
	var ck = sim.spatial._ck(int(feat.cx), int(feat.cy))
	if not sim.features_by_chunk.has(ck):
		sim.features_by_chunk[ck] = []
	sim.features_by_chunk[ck].append(feat)



## Removes a feature from its chunk bucket when moved or killed.
func _feat_chunk_unindex(feat: Dictionary) -> void:
	var ck = sim.spatial._ck(int(feat.cx), int(feat.cy))
	var bucket = sim.features_by_chunk.get(ck, null)
	if bucket == null:
		return
	bucket.erase(feat)
	if bucket.is_empty():
		sim.features_by_chunk.erase(ck)



## Lists live features whose chunks overlap a camera or world rectangle.
func features_in_rect(rect: Rect2) -> Array:
	# Only features whose chunks overlap rect (+1 chunk pad for tall sprites).
	var out: Array = []
	if rect.size == Vector2.ZERO:
		return out
	var size = float(Catalog.TILE * Catalog.CHUNK)
	var x0 = int(floor(rect.position.x / size)) - 1
	var y0 = int(floor(rect.position.y / size)) - 1
	var x1 = int(floor(rect.end.x / size)) + 1
	var y1 = int(floor(rect.end.y / size)) + 1
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var bucket = sim.features_by_chunk.get(sim.spatial._ck(cx, cy), null)
			if bucket == null:
				continue
			for feat in bucket:
				if feat.dead:
					continue
				out.append(feat)
	return out



## Full world rebind after load: ids, cells, links, living roster, and spatial hash.
func _reindex() -> void:
	sim.feature_by_id.clear()
	sim.feature_cell.clear()
	sim.features_by_chunk.clear()
	sim.item_by_id.clear()
	sim.building_by_id.clear()
	sim.building_cell.clear()
	sim.fires.clear()
	sim.next_feature_id = 1
	sim.next_item_id = 1
	sim.next_building_id = 1
	for feat in sim.features:
		if feat.dead:
			continue
		_anchor_terrain_feature(feat)
		var at = Catalog.snap_world(float(feat.x), float(feat.y))
		feat.x = at.x
		feat.y = at.y
		var c = sim.spatial._chunk_at(float(feat.x), float(feat.y))
		feat.cx = c.x
		feat.cy = c.y
		sim.feature_by_id[int(feat.id)] = feat
		_feat_chunk_index(feat)
		if int(feat.kind) == Catalog.FEAT_FIRE:
			sim.fires.append(feat)
		for cell in sim.building_sim._footprint_cells(float(feat.x), float(feat.y), Catalog.footprint_for_feature(int(feat.kind))):
			sim.feature_cell[cell] = int(feat.id)
		sim.next_feature_id = maxi(sim.next_feature_id, int(feat.id) + 1)
	for it in sim.items:
		if it.dead:
			continue
		it.held = false
		sim.item_by_id[int(it.id)] = it
		sim.next_item_id = maxi(sim.next_item_id, int(it.id) + 1)
	for b in sim.buildings:
		if b.dead:
			continue
		sim.building_by_id[int(b.id)] = b
		for cell in sim.building_sim._footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
			sim.building_cell[cell] = int(b.id)
		sim.next_building_id = maxi(sim.next_building_id, int(b.id) + 1)
	sim.tick_stamp = PackedInt32Array()
	sim.tick_stamp.resize(sim.slot_count)
	while sim.act.size() < sim.slot_count:
		sim.act.append(0)
	while sim.act_t.size() < sim.slot_count:
		sim.act_t.append(0.0)
	while sim.avoid_t.size() < sim.slot_count:
		sim.avoid_t.append(0.0)
	_ensure_link_arrays()
	_rebuild_links()
	_rebuild_living()
	_rebuild_kind_indexes()
	sim.spatial._rebuild_hash()



## Sizes per-agent link, seek, and hash side arrays to slot_count.
func _ensure_link_arrays() -> void:
	var n = sim.slot_count
	if sim.link_tub.size() != n:
		sim.link_tub.resize(n)
		sim.link_tub.fill(-1)
	if sim.link_ride.size() != n:
		sim.link_ride.resize(n)
		sim.link_ride.fill(-1)
	if sim.link_guest.size() != n:
		sim.link_guest.resize(n)
		sim.link_guest.fill(-1)
	if sim.link_claim.size() != n:
		sim.link_claim.resize(n)
		sim.link_claim.fill(-1)
	if sim.link_ball.size() != n:
		sim.link_ball.resize(n)
		sim.link_ball.fill(-1)
	if sim.living_at.size() != n:
		sim.living_at.resize(n)
		sim.living_at.fill(-1)
	if sim.bark_cool.size() != n:
		sim.bark_cool.resize(n)
		sim.bark_cool.fill(0.0)
	if sim.seek_x.size() != n:
		sim.seek_x.resize(n)
		sim.seek_x.fill(0.0)
	if sim.seek_y.size() != n:
		sim.seek_y.resize(n)
		sim.seek_y.fill(0.0)
	if sim.seek_t.size() != n:
		sim.seek_t.resize(n)
		sim.seek_t.fill(0.0)
	if sim.hash_cell.size() != n:
		sim.hash_cell.resize(n)
		sim.hash_cell.fill(-1)
	if sim.hash_next.size() != n:
		sim.hash_next.resize(n)
		sim.hash_next.fill(-1)



## Reconstructs agent-building and agent-item links from saved occupant fields.
func _rebuild_links() -> void:
	_ensure_link_arrays()
	sim.link_tub.fill(-1)
	sim.link_ride.fill(-1)
	sim.link_guest.fill(-1)
	sim.link_claim.fill(-1)
	sim.link_ball.fill(-1)
	sim.mine_job_n.clear()
	for i in sim.mine_job.size():
		var bid = int(sim.mine_job[i])
		if bid < 0:
			continue
		sim.mine_job_n[bid] = int(sim.mine_job_n.get(bid, 0)) + 1
	sim.building_sim._invalidate_factory_cache()
	_invalidate_walk_cells()
	for b in sim.buildings:
		if b.dead:
			continue
		var bid = int(b.id)
		var occ = int(b.get("occupant", -1))
		if occ >= 0 and occ < sim.link_tub.size() and int(b.kind) == Catalog.BLD_TUB:
			sim.link_tub[occ] = bid
		for guest in b.get("guests", []):
			var gid = int(guest.get("id", -1))
			if gid >= 0 and gid < sim.link_guest.size():
				sim.link_guest[gid] = bid
		for raw in sim.agent_tick._rider_list(b):
			var rid = int(raw)
			if rid >= 0 and rid < sim.link_ride.size():
				sim.link_ride[rid] = bid
	for it in sim.items:
		if it.dead:
			continue
		var who = int(it.get("claimer", -1))
		if who < 0 or who >= sim.link_claim.size():
			continue
		sim.link_claim[who] = int(it.id)
		if int(it.kind) == Catalog.ITEM_BALL:
			sim.link_ball[who] = int(it.id)



## Rebuilds living_ids, dead counts, and legacy corpse starve timers.
func _rebuild_living() -> void:
	sim.living_ids = PackedInt32Array()
	if sim.living_at.size() != sim.slot_count:
		sim.living_at.resize(sim.slot_count)
	sim.living_at.fill(-1)
	sim.dead_n = 0
	sim.dead_ids = PackedInt32Array()
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_LIVING:
			_living_add(i)
		elif sim.state[i] == Catalog.ST_DEAD:
			sim.dead_n += 1
			_dead_add(i)
			# Legacy saves keep hunger-starve leftovers; clamp into corpse lifetime.
			if sim.starve[i] <= 0.0 or sim.starve[i] > sim.CORPSE_LIFE:
				sim.starve[i] = sim.CORPSE_LIFE



## Refreshes living tally, peak population, carry counts, and item tally caches.
func _recount() -> void:
	_rebuild_living()
	sim.living = sim.living_ids.size()
	sim.peak = maxi(sim.peak, sim.living)
	_rebuild_carry_counts()
	_invalidate_item_counts()



## Strips dead dictionaries from a features, items, or buildings array in place.
func _compact(list: Array) -> void:
	var w = 0
	for i in list.size():
		if not bool(list[i].get("dead", false)):
			list[w] = list[i]
			w += 1
	list.resize(w)



## Loads biomes.json into runtime tables for procedural chunk generation.
func _load_biomes() -> void:
	sim.biomes = []
	sim.biome_by_id = {}
	var file = FileAccess.open("res://data/biomes.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return
	sim.biomes = parsed
	for biome in sim.biomes:
		sim.biome_by_id[str(biome.id)] = biome



## Picks biome id for unrevealed chunks (meadow, grove, sea, special).
func _biome_formula(cx: int, cy: int) -> String:
	var special = str(sim.special_biomes.get(sim.spatial._ck(cx, cy), ""))
	if special != "":
		return special
	if cx == 0 and cy == 0:
		return "meadow"
	if sim.island_gen.is_island_chunk(cx, cy):
		return "grove"
	return "sea"



## Scatters glitch, anomaly, epilogue, and mountain décor when those biomes generate.
func _scatter_biome_props(cx: int, cy: int, biome: String) -> void:
	if biome != "glitch" and biome != "anomaly" and biome != "epilogue" and biome != "mountain":
		return
	var count = 4 if biome == "mountain" else 5
	for n in count:
		var lx = int(sim.spatial._rand(cx, cy, n, 0, 90) * float(Catalog.CHUNK))
		var ly = int(sim.spatial._rand(cx, cy, n, 1, 91) * float(Catalog.CHUNK))
		var wx = float((cx * Catalog.CHUNK + lx) * Catalog.TILE + 8)
		var wy = float((cy * Catalog.CHUNK + ly) * Catalog.TILE + 8)
		var kind = Catalog.FEAT_EPILOGUE
		var ore = n % 2
		if biome == "glitch":
			kind = Catalog.FEAT_GLITCH_HOUSE if n % 2 == 0 else Catalog.FEAT_GLITCH_TREE
			ore = 0 if kind == Catalog.FEAT_GLITCH_HOUSE else n % 5
		elif biome == "anomaly":
			kind = Catalog.FEAT_ANOMALY
			ore = n % 5
		elif biome == "mountain":
			kind = Catalog.FEAT_MOUNTAIN
			ore = n % 4
		_add_feature(kind, wx, wy, 1, ore, true)



## Biome name at world coordinates from chunk data or generation formula.
func biome_at(x: float, y: float) -> String:
	var cell = sim.spatial._chunk_at(x, y)
	return _biome_of(cell.x, cell.y)



## Biome string for chunk coords, preferring stored chunk.biome when revealed.
func _biome_of(cx: int, cy: int) -> String:
	var ck = sim.spatial._ck(cx, cy)
	if sim.chunks.has(ck):
		return str(sim.chunks[ck].biome)
	return _biome_formula(cx, cy)



