class_name SimBuildingSim
extends RefCounted

## Building visitors, mines, factories, pollution, and occupancy.

var sim


## Stores the simulation server used for building simulation.
func _init(sim_ref) -> void:
	sim = sim_ref

## Bathtub building dict when the agent is the seated occupant.
func seat_of(i: int) -> Dictionary:
	if i < 0 or i >= sim.link_tub.size():
		return {}
	var bid = sim.link_tub[i]
	if bid < 0:
		return {}
	var b: Dictionary = sim.building_by_id.get(bid, {})
	if b.is_empty() or b.dead or int(b.kind) != Catalog.BLD_TUB or int(b.get("occupant", -1)) != i:
		sim.link_tub[i] = -1
		return {}
	return b



## Interior guest of a visit building (hides thought bubbles off-world).
func indoors(i: int) -> bool:
	# Guest of a visit building (home / theatre / mine). Roundabout and tub keep
	# their on-world animations; flower/statue auras never register guests.
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	var visit = _guest_building(i)
	if visit.is_empty():
		return false
	return not _visit_rule(int(visit.kind)).is_empty()



## Roundabout building while the agent is in the play-on-ride act.
func ride_of(i: int) -> Dictionary:
	if i < 0 or i >= sim.slot_count or int(sim.act[i]) != sim.ACT_PLAY:
		return {}
	return sim.agent_tick._ride_building(i)



## Whether play act still owns a claimed ball item link.
func has_ball(i: int) -> bool:
	if i < 0 or i >= sim.link_ball.size() or int(sim.act[i]) != sim.ACT_PLAY:
		return false
	var iid = sim.link_ball[i]
	if iid < 0:
		return false
	var it: Dictionary = sim.item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_BALL or int(it.get("claimer", -1)) != i:
		sim.link_ball[i] = -1
		return false
	return true



## Per-building guest caps, stay, cooldown, and need-restore rates.
func _visit_rule(kind: int) -> Dictionary:
	if kind == Catalog.BLD_DWELL:
		return {"cap": 4, "stay": 18.0, "cool": 14.0, "fed": 8.0, "clean": 8.0, "fun": 0.0}
	if kind == Catalog.BLD_FANCY:
		return {"cap": 10, "stay": 24.0, "cool": 12.0, "fed": 10.0, "clean": 12.0, "fun": 0.0}
	if kind == Catalog.BLD_THEATRE:
		return {"cap": 18, "stay": 30.0, "cool": 10.0, "fed": 0.0, "clean": 0.0, "fun": 9.0}
	if kind == Catalog.BLD_MINE:
		return {"cap": 2, "stay": sim.MINE_DIG_TIME, "cool": 0.6, "fed": 0.0, "clean": 0.0, "fun": 0.0}
	if kind == Catalog.BLD_MINE2:
		return {"cap": 6, "stay": sim.MINE_DIG_TIME * 0.7, "cool": 0.4, "fed": 0.0, "clean": 0.0, "fun": 0.0}
	return {}



## Whether building kind uses theatre-style show visit rules.
func _is_show(kind: int) -> bool:
	return kind == Catalog.BLD_THEATRE



## Whether building kind is a diggable mine variant.
func _is_mine_kind(kind: int) -> bool:
	return kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2



## Ore buffer capacity for the mine building tier.
func _mine_stock_cap(b: Dictionary) -> int:
	return sim.MINE_STOCK_CAP2 if int(b.kind) == Catalog.BLD_MINE2 else sim.MINE_STOCK_CAP



## Ore feature kind mapped to mine placement tier.
func _ore_tier(kind: int) -> int:
	if kind == Catalog.FEAT_NODE or kind == Catalog.FEAT_MNODE:
		return 1
	if kind == Catalog.FEAT_SUPER:
		return 2
	if kind == Catalog.FEAT_ORE_MEGA:
		return 3
	if kind == Catalog.FEAT_ORE_SUPER:
		return 4
	if kind == Catalog.FEAT_ORE_ULTRA:
		return 5
	return 0



## Boulder feature kinds that respond to hammer/pick, not ore nodes.
func _is_rock(kind: int) -> bool:
	return kind == Catalog.FEAT_ROCK or kind == Catalog.FEAT_BIGROCK



## Guest visit duration scaled by active colony mutations.
func _stay_for(kind: int, base: float) -> float:
	if _is_show(kind):
		return base
	var stay = base
	var home = kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY
	if bool(sim.mutations.get("care", false)):
		stay *= 1.35
	if home and bool(sim.mutations.get("short_rest", false)):
		stay *= 0.55
	elif bool(sim.mutations.get("hard", false)):
		stay *= 0.6
	return stay



## Whether agent id is listed on a building guest roster.
func _is_guest(b: Dictionary, i: int) -> bool:
	for guest in b.get("guests", []):
		if int(guest.id) == i:
			return true
	return false



## Living agents currently counted as building guests.
func _live_guests(b: Dictionary) -> int:
	var n = 0
	for guest in b.get("guests", []):
		var id = int(guest.id)
		if id >= 0 and id < sim.slot_count and sim.state[id] == Catalog.ST_LIVING:
			n += 1
	return n



## Whether agent is on post-visit re-entry cooldown for a building.
func _banned(b: Dictionary, i: int) -> bool:
	for away in b.get("away", []):
		if int(away.id) == i and float(away.t) > 0.0:
			return true
	return false



## Pollution, capacity, ban, and roster checks before admitting a guest.
func _can_enter(b: Dictionary, i: int) -> bool:
	if building_is_polluted(b):
		return false
	var rule = _visit_rule(int(b.kind))
	if rule.is_empty():
		return true
	if _is_guest(b, i):
		return true
	if _banned(b, i):
		return false
	return _live_guests(b) < int(rule.cap)



## Visit building hosting an agent, via link cache or roster scan.
func _guest_building(i: int) -> Dictionary:
	if i < 0 or i >= sim.link_guest.size():
		return {}
	var bid = sim.link_guest[i]
	if bid >= 0:
		var linked: Dictionary = sim.building_by_id.get(bid, {})
		if not linked.is_empty() and not linked.dead and _is_guest(linked, i):
			return linked
		sim.link_guest[i] = -1
	for b in sim.buildings:
		if b.dead:
			continue
		if _is_guest(b, i):
			sim.link_guest[i] = int(b.id)
			return b
	return {}



## Eject a guest to nearby walkable ground (tub exit splash when relevant).
func _push_out(b: Dictionary, i: int) -> void:
	var ang = randf() * TAU
	var nx = sim.pos_x[i] + cos(ang) * 22.0
	var ny = sim.pos_y[i] + sin(ang) * 22.0
	if not sim.collision._move_blocked(nx, ny):
		sim.spatial._set_agent_pos(i, nx, ny)
	if int(b.kind) == Catalog.BLD_TUB:
		sim.sfx_queue.append("tub_out")



## Remove guest from roster, start cooldown, and push them outside.
func _drop_guest(b: Dictionary, i: int) -> void:
	var guests: Array = []
	for guest in b.get("guests", []):
		if int(guest.id) != i:
			guests.append(guest)
	b.guests = guests
	if i >= 0 and i < sim.link_guest.size() and sim.link_guest[i] == int(b.id):
		sim.link_guest[i] = -1
	var away: Array = b.get("away", [])
	var rule = _visit_rule(int(b.kind))
	away.append({"id": i, "t": float(rule.get("cool", 8.0))})
	b.away = away
	_push_out(b, i)



## Admit agent to building guest list and wire guest link when allowed.
func _enter_visit(i: int, b: Dictionary) -> bool:
	if b.is_empty() or _is_guest(b, i) or not _can_enter(b, i):
		return false
	var rule = _visit_rule(int(b.kind))
	if rule.is_empty():
		return false
	var kind = int(b.kind)
	# Diggers reserve one stock unit for the whole stay.
	if _is_mine_kind(kind) and int(b.get("buffer", 0)) <= _live_guests(b):
		return false
	var guests: Array = b.get("guests", [])
	guests.append({"id": i, "left": _stay_for(kind, float(rule.stay))})
	b.guests = guests
	if i >= 0 and i < sim.link_guest.size():
		sim.link_guest[i] = int(b.id)
	if kind == Catalog.BLD_TUB:
		sim.sfx_queue.append("tub_in")
		sim.sfx_queue.append("splash")
	return true



## End of mine visit: spend buffer ore into carry when factory exists.
func _mine_finish_dig(b: Dictionary, id: int) -> void:
	if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_LIVING:
		return
	if sim.carry[id] != Catalog.CARRY_NONE:
		return
	if int(b.get("buffer", 0)) <= 0 or not _has_factory():
		return
	b.buffer = maxi(0, int(b.get("buffer", 0)) - 1)
	sim.world_entities._set_carry(id, Catalog.CARRY_ORE, _mine_value(b))
	sim.agent_tick._release_mine_job(id)



## Tick guest stay timers, apply visit need buffs, and eject when done.
func _tick_visit(b: Dictionary, dt: float) -> void:
	var rule = _visit_rule(int(b.kind))
	var kind = int(b.kind)
	var mine = _is_mine_kind(kind)
	var away: Array = []
	for ban in b.get("away", []):
		ban.t = float(ban.t) - dt
		if float(ban.t) > 0.0:
			away.append(ban)
	var kept: Array = []
	for guest in b.get("guests", []):
		var id = int(guest.id)
		if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_LIVING:
			if id >= 0 and id < sim.link_guest.size() and sim.link_guest[id] == int(b.id):
				sim.link_guest[id] = -1
			continue
		guest.left = float(guest.left) - dt
		if float(guest.left) <= 0.0:
			if id < sim.link_guest.size() and sim.link_guest[id] == int(b.id):
				sim.link_guest[id] = -1
			if mine:
				_mine_finish_dig(b, id)
			_push_out(b, id)
			away.append({"id": id, "t": float(rule.cool)})
			continue
		if float(rule.fed) > 0.0:
			sim.fed[id] = minf(100.0, sim.fed[id] + float(rule.fed) * dt)
		if float(rule.clean) > 0.0:
			sim.clean[id] = minf(100.0, sim.clean[id] + float(rule.clean) * dt)
		if float(rule.fun) > 0.0:
			sim.amused[id] = minf(100.0, sim.amused[id] + float(rule.fun) * dt)
			sim.buff_t[id] = maxf(sim.buff_t[id], 1.2)
		kept.append(guest)
	b.guests = kept
	b.away = away
	if not mine:
		b.active = not kept.is_empty()



## Pick valid ground near an apple tree for a falling fruit landing.
func _apple_land_spot(bx: float, by: float) -> Vector2:
	for _n in 8:
		var ang = randf() * TAU
		var rad = randf_range(Catalog.APPLE_LAND_MIN, Catalog.APPLE_LAND_MAX)
		var px = bx + cos(ang) * rad
		var py = by + sin(ang) * rad
		var at = Catalog.snap_world(px, py)
		if not sim.collision._blocked(at.x, at.y) and sim.collision._tile_holds(at.x, at.y):
			return at
	var fallback = Catalog.snap_world(bx, by + Catalog.APPLE_LAND_MIN)
	if not sim.collision._blocked(fallback.x, fallback.y) and sim.collision._tile_holds(fallback.x, fallback.y):
		return fallback
	return Catalog.snap_world(bx, by)



## Grow apple slots on tree buildings and launch ripe fruit with physics.
func _tick_apple_tree(b: Dictionary, dt: float) -> void:
	var fruits: Array = b.get("fruits", [])
	b.fruits = fruits
	var used = {}
	for fruit in fruits:
		used[int(fruit.slot)] = true
	var slot = 0
	while fruits.size() < 3 and slot < 3:
		if not used.has(slot):
			fruits.append({"slot": slot, "s": 0.15})
			used[slot] = true
		slot += 1
	for fruit in fruits:
		if float(fruit.s) < 1.0:
			fruit.s = minf(1.0, float(fruit.s) + dt * 0.28)
	b.timer = float(b.timer) - dt
	if float(b.timer) > 0.0:
		return
	var ripe = -1
	for n in fruits.size():
		if float(fruits[n].s) >= 1.0:
			ripe = n
			break
	if ripe < 0:
		return
	b.timer = 2.2
	var on_ground = 0
	for it in sim.items:
		if it.dead or int(it.kind) != Catalog.ITEM_APPLE or float(it.get("air", 0.0)) > 0.0:
			continue
		if sim.spatial._dist_point(float(b.x), float(b.y), float(it.x), float(it.y)) < 36.0:
			on_ground += 1
	if on_ground >= 4:
		b.timer = 1.0
		return
	var fruit: Dictionary = fruits[ripe]
	var fruit_slot = clampi(int(fruit.slot), 0, 2)
	fruits.remove_at(ripe)
	var spot: Vector2 = Catalog.APPLE_SPOTS[fruit_slot]
	var lift: float = Catalog.APPLE_LIFTS[fruit_slot]
	var start = Vector2(float(b.x) + spot.x, float(b.y) + spot.y)
	var dest = _apple_land_spot(float(b.x), float(b.y))
	var fall_t = sqrt(2.0 * maxf(lift, 1.0) / sim.item_physics.ITEM_GRAVITY)
	var dropped = sim.world_entities._add_item(Catalog.ITEM_APPLE, start.x, start.y, 1)
	sim.item_physics.launch_item(dropped, lift, 0.0, (dest.x - start.x) / fall_t, (dest.y - start.y) / fall_t)



## Whether tub, visit, or ride building has no remaining capacity.
func structure_full(b: Dictionary) -> bool:
	var kind = int(b.kind)
	if kind == Catalog.BLD_TUB:
		var occ = int(b.get("occupant", -1))
		return occ >= 0 and occ < sim.slot_count and sim.state[occ] == Catalog.ST_LIVING
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
		var rule = _visit_rule(kind)
		return _live_guests(b) >= int(rule.cap)
	if kind == Catalog.BLD_ROUND:
		return sim.agent_tick._taken_ride_slots(b).size() >= sim.agent_tick._ride_slot_count()
	return false



## Whether goo under footprint forces a visit building to shut down.
func building_is_polluted(b: Dictionary) -> bool:
	if b.is_empty() or bool(b.get("dead", false)):
		return false
	if not Catalog.building_has_goo(int(b.kind)):
		return false
	if b.has("polluted"):
		return bool(b.polluted)
	return _refresh_building_pollution(b)



## Recompute and cache goo-under-footprint for one building.
func _refresh_building_pollution(b: Dictionary) -> bool:
	var polluted = false
	if not b.is_empty() and not bool(b.get("dead", false)) and Catalog.building_has_goo(int(b.kind)):
		for cell in _footprint_cells(float(b.x), float(b.y), Catalog.footprint_for_building(int(b.kind))):
			if sim.collision._tile_at_cell(cell) == Catalog.TILE_GOO:
				polluted = true
				break
	b.polluted = polluted
	return polluted



## Clear cached pollution flags after terrain or footprint edits.
func _invalidate_building_pollution() -> void:
	for b in sim.buildings:
		b.erase("polluted")



## Eject guests and mark building inactive when pollution is detected.
func _shut_polluted_building(b: Dictionary) -> void:
	for guest in b.get("guests", []):
		var gid = int(guest.get("id", -1))
		if gid >= 0 and gid < sim.link_guest.size() and sim.link_guest[gid] == int(b.id):
			sim.link_guest[gid] = -1
	b.guests = []
	b.away = []
	b.active = false
	b.polluted = true
	if bool(b.get("incinerate", false)):
		b.incinerate = false
		b.burn = 0.0



## Per-building tick: food trees, mines, factories, tub, roundabout, visits.
func _tick_buildings(dt: float) -> void:
	for b in sim.buildings:
		if b.dead:
			continue
		if bool(b.get("lifted", false)):
			b.active = false
			continue
		var kind = int(b.kind)
		if _refresh_building_pollution(b):
			_shut_polluted_building(b)
			continue
		b.active = false
		if kind == Catalog.BLD_APPLE:
			_tick_apple_tree(b, dt)
		elif kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
			var stock_cap = _mine_stock_cap(b)
			var stock = int(b.get("buffer", 0))
			if stock < stock_cap:
				b.timer = float(b.timer) - dt
				if float(b.timer) <= 0.0:
					b.timer = sim.MINE_FILL_TIME
					b.buffer = mini(stock_cap, stock + 1)
			else:
				b.timer = sim.MINE_FILL_TIME
			_tick_visit(b, dt)
			b.active = _live_guests(b) > 0
		elif kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			var cycle = _factory_cycle_time(kind)
			var buffered = int(b.get("buffer", 0))
			if buffered > 0:
				if float(b.timer) > cycle:
					b.timer = cycle
				b.timer = float(b.timer) - dt
				if float(b.timer) <= 0.0:
					_factory_spend(b)
					var _g = sim.FACTORY_GEM_PAY2 if kind == Catalog.BLD_FACTORY2 else sim.FACTORY_GEM_PAY
					sim.gems += _g
					sim.total_gems_earned += _g
					b.active = true
					sim.dialogue._pop(float(b.x), float(b.y) - 6.0, Catalog.ICON_GEM)
					if randf() < sim.FACTORY_GOO_CHANCE:
						sim.world_tick._spill_goo(float(b.x), float(b.y), 2 if kind == Catalog.BLD_FACTORY2 else 1)
					buffered = int(b.get("buffer", 0))
					b.timer = cycle if buffered > 0 else 0.25
				else:
					b.active = true
			else:
				b.timer = 0.25
			if bool(b.get("incinerate", false)):
				b.active = true
				b.burn = float(b.get("burn", 0.0)) + dt
				if float(b.burn) >= 3.0:
					var corpse = sim.world_entities._nearest_corpse(float(b.x), float(b.y), 90.0)
					if corpse >= 0:
						b.burn = 0.0
						sim.world_entities._vacate(corpse)
						var _gg = 5 if bool(sim.mutations.get("fuel", false)) else 3
						sim.gems += _gg
						sim.total_gems_earned += _gg
						sim.sfx_queue.append("bones")
		elif kind == Catalog.BLD_TUB:
			var occ = int(b.occupant)
			if occ >= 0 and occ < sim.slot_count and sim.state[occ] == Catalog.ST_LIVING and sim.spatial._dist_i(occ, float(b.x), float(b.y)) < 22.0:
				b.active = true
		elif kind == Catalog.BLD_ROUND:
			var spinning = false
			for raw in sim.agent_tick._rider_list(b):
				var rid = int(raw)
				if rid >= 0 and rid < sim.slot_count and sim.state[rid] == Catalog.ST_LIVING:
					spinning = true
					break
			# Drop seat claims from thronglets who wandered off before mounting.
			var mid = sim.agent_tick._ride_center_of(b)
			var claims: Variant = b.get("ride_slot", {})
			if claims is Dictionary:
				var keep_claims = {}
				for key in claims.keys():
					var who = int(key)
					if who < 0 or who >= sim.slot_count or sim.state[who] != Catalog.ST_LIVING:
						continue
					if sim.agent_tick._is_rider(b, who) or sim.spatial._dist_i(who, mid.x, mid.y) <= 40.0:
						keep_claims[who] = int(claims[key])
				b.ride_slot = keep_claims
			# Spin only while someone is actually seated. Approachers leave it idle.
			b.active = spinning
			if spinning:
				b.spin = float(b.get("spin", 0.0)) + float(sim._ride_cfg().get("spin_speed", Catalog.ROUND_SPIN_RATE)) * dt
		elif kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY or _is_show(kind):
			_tick_visit(b, dt)



## UI-facing mine buffer or visit occupancy counts for a building.
func capacity_info(b: Dictionary) -> Dictionary:
	if b.is_empty() or bool(b.get("dead", false)):
		return {}
	var kind = int(b.kind)
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		return {}
	if _is_mine_kind(kind):
		var cap = _mine_stock_cap(b)
		var n = clampi(int(b.get("buffer", 0)), 0, cap)
		return {"n": n, "cap": cap, "full": n >= cap, "mine": true, "visit": false}
	if kind != Catalog.BLD_DWELL and kind != Catalog.BLD_FANCY and kind != Catalog.BLD_THEATRE:
		return {}
	var rule = _visit_rule(kind)
	if rule.is_empty():
		return {}
	var cap2 = int(rule.cap)
	var n2 = clampi(_live_guests(b), 0, cap2)
	return {"n": n2, "cap": cap2, "full": n2 >= cap2, "mine": false, "visit": true}



## Pulse flower, statue, and wood building fun auras each frame.
func _tick_auras(dt: float) -> void:
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		var kind = int(b.kind)
		if kind == Catalog.BLD_FLOWER:
			_boost(float(b.x), float(b.y), 28.0, 3, 0.0, 0.0, 3.5 * dt, 0.0, sim.ACT_PLAY)
		elif kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
			_boost(float(b.x), float(b.y), 36.0, 4, 0.0, 0.0, 5.0 * dt, 0.8, sim.ACT_PLAY)



## Restore needs for nearest living agents inside a capped radius.
func _boost(x: float, y: float, radius: float, limit: int, fed_r: float, clean_r: float, fun_r: float, buff: float, mark_act: int = 0) -> void:
	var ids = sim.spatial.query_radius(x, y, radius)
	var scored: Array = []
	for id in ids:
		if sim.state[int(id)] != Catalog.ST_LIVING:
			continue
		scored.append({"id": int(id), "d": sim.spatial._dist_i(int(id), x, y)})
	scored.sort_custom(func(a, b): return float(a.d) < float(b.d))
	var n = mini(limit, scored.size())
	for k in n:
		var id = int(scored[k].id)
		if fed_r > 0.0:
			sim.fed[id] = minf(100.0, sim.fed[id] + fed_r)
		if clean_r > 0.0:
			sim.clean[id] = minf(100.0, sim.clean[id] + clean_r)
		if fun_r > 0.0:
			sim.amused[id] = minf(100.0, sim.amused[id] + fun_r)
		if buff > 0.0:
			sim.buff_t[id] = maxf(sim.buff_t[id], buff)
		if mark_act > 0:
			sim.act[id] = mark_act
			sim.act_t[id] = maxf(sim.act_t[id], 0.35)



## Full footprint placement check for new builds or building relocation.
func _building_spot_free(id: int, x: float, y: float, kind: int = -1) -> bool:
	var b = sim.building_by_id.get(id, {})
	var size_kind = kind
	if size_kind < 0:
		size_kind = int(b.get("kind", -1)) if not b.is_empty() else -1
	if size_kind < 0:
		return sim.world_entities._building_at(x, y, 14.0).is_empty()
	var cells = _footprint_cells(x, y, Catalog.footprint_for_building(size_kind))
	if not _footprint_holds(cells):
		return false
	var mine = size_kind == Catalog.BLD_MINE or size_kind == Catalog.BLD_MINE2
	var anchor = sim.spatial._cell_vec(x, y)
	var mine_feat_id = -1
	if mine:
		mine_feat_id = int(sim.feature_cell.get(anchor, -1))
		var mine_feat = sim.feature_by_id.get(mine_feat_id, {})
		if mine_feat.is_empty() or mine_feat.dead or _ore_tier(int(mine_feat.kind)) == 0:
			mine_feat_id = -1
		# Fresh campaign mines must sit on an ore node; sandbox may place freely.
		# Relocated mines already consumed theirs.
		if not sim.sandbox_mode and id < 0 and mine_feat_id < 0:
			return false
	for cell in cells:
		var at = sim.world_entities._cell_world(cell)
		if not sim.revealed.has(sim.spatial._ck_of(at.x, at.y)):
			return false
		var bid = int(sim.building_cell.get(cell, -1))
		if bid >= 0 and bid != id:
			return false
		var fid = int(sim.feature_cell.get(cell, -1))
		if fid >= 0:
			# Ore nodes are multi-cell; a mine may cover every cell of the same node.
			if mine and fid == mine_feat_id:
				pass
			else:
				var feat = sim.feature_by_id.get(fid, {})
				if feat.is_empty() or feat.dead or not sim.collision._pad_feature_soft(int(feat.kind)):
					return false
		if sim.collision._pad_item_blocks(at.x, at.y):
			return false
	return true



## Grid cells covered by a snapped footprint at a world anchor.
func _footprint_cells(x: float, y: float, size: Vector2i) -> Array[Vector2i]:
	var origin = sim.spatial._cell_vec(x, y)
	var cells: Array[Vector2i] = []
	for offset in Catalog.footprint_offsets(size):
		cells.append(origin + offset)
	return cells



## Every cell in a footprint sits on holdable ground.
func _footprint_holds(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var at = sim.world_entities._cell_world(cell)
		if not sim.collision._tile_holds(at.x, at.y):
			return false
	return true



## Remove a building from the per-cell building index.
func _unbind_building(b: Dictionary) -> void:
	var id = int(b.id)
	var doomed: Array = []
	for cell in sim.building_cell.keys():
		if int(sim.building_cell[cell]) == id:
			doomed.append(cell)
	for cell in doomed:
		sim.building_cell.erase(cell)



## Place building footprint, clear soft pad clutter, and index cells.
func _bind_building_at(b: Dictionary, x: float, y: float) -> bool:
	var cells = _footprint_cells(x, y, Catalog.footprint_for_building(int(b.kind)))
	if not _footprint_holds(cells):
		return false
	for cell in cells:
		var bid = int(sim.building_cell.get(cell, -1))
		if bid >= 0 and bid != int(b.id):
			return false
		var fid = int(sim.feature_cell.get(cell, -1))
		if fid >= 0:
			var feat = sim.feature_by_id.get(fid, {})
			if feat.is_empty() or feat.dead or not sim.collision._pad_feature_soft(int(feat.kind)):
				return false
	sim.collision._clear_pad_soft(cells)
	_unbind_building(b)
	b.x = x
	b.y = y
	for cell in cells:
		sim.building_cell[cell] = int(b.id)
	return true



## World positions of all cells in a building or feature footprint.
func footprint_world(kind: int, x: float, y: float, is_building: bool = true) -> Array:
	var size = Catalog.footprint_for_building(kind) if is_building else Catalog.footprint_for_feature(kind)
	var out: Array = []
	for cell in _footprint_cells(x, y, size):
		out.append(sim.world_entities._cell_world(cell))
	return out



## Short LLENO label for building UI when guest capacity is saturated.
func occupancy_text(b: Dictionary) -> String:
	var info = capacity_info(b)
	if info.is_empty():
		return ""
	if bool(info.full):
		return "LLENO"
	return ""



## Reserves a bathtub occupant slot and link_tub entry for bath seek and soak logic.
func _claim_tub(i: int, tub: Dictionary) -> void:
	var occ = int(tub.occupant)
	if occ == i:
		if i < sim.link_tub.size():
			sim.link_tub[i] = int(tub.id)
		return
	if occ >= 0 and occ != i:
		return
	_release_claim(i)
	tub.occupant = i
	tub.bath_t = -1.0
	sim.claim[i] = int(tub.id)
	if i < sim.link_tub.size():
		sim.link_tub[i] = int(tub.id)



## Drops an agent's building claim, ending tub soak and queuing tub-out SFX when needed.
func _release_claim(i: int) -> void:
	if i < 0 or i >= sim.claim.size():
		return
	var bid = sim.claim[i]
	sim.claim[i] = -1
	if i < sim.link_tub.size() and (bid < 0 or sim.link_tub[i] == bid):
		sim.link_tub[i] = -1
	if bid < 0:
		return
	var b = sim.building_by_id.get(bid, {})
	if not b.is_empty() and int(b.occupant) == i:
		var soaking = int(b.kind) == Catalog.BLD_TUB and float(b.get("bath_t", -1.0)) >= 0.0
		b.occupant = -1
		b.bath_t = -1.0
		b.active = false
		if soaking:
			sim.sfx_queue.append("tub_out")



## Picks the closest bath building within range, optionally ignoring other occupants.
func _nearest_tub(i: int, allow_busy: bool = false) -> Dictionary:
	var best = {}
	var best_d = 999999.0
	for b in sim.blds_tub:
		if b.dead:
			continue
		var occ = int(b.occupant)
		if occ >= 0 and occ != i and not allow_busy:
			continue
		var d = sim.spatial._dist_i(i, float(b.x), float(b.y))
		if d < best_d and d < 280.0:
			best_d = d
			best = b
	return best



## Returns the pre-indexed building array for one or two catalog kinds.
func _buildings_for_kinds(kinds: Array) -> Array:
	if kinds.size() == 1:
		match int(kinds[0]):
			Catalog.BLD_TUB:
				return sim.blds_tub
			Catalog.BLD_ROUND:
				return sim.blds_round
			Catalog.BLD_DWELL, Catalog.BLD_FANCY:
				return sim.blds_home
			Catalog.BLD_MINE, Catalog.BLD_MINE2:
				return sim.blds_mine
			Catalog.BLD_THEATRE:
				return sim.blds_show
	if kinds.size() == 2:
		var a = int(kinds[0])
		var b = int(kinds[1])
		if (a == Catalog.BLD_DWELL and b == Catalog.BLD_FANCY) or (b == Catalog.BLD_DWELL and a == Catalog.BLD_FANCY):
			return sim.blds_home
		if (a == Catalog.BLD_MINE and b == Catalog.BLD_MINE2) or (b == Catalog.BLD_MINE and a == Catalog.BLD_MINE2):
			return sim.blds_mine
	return sim.buildings



## Nearest enterable, unpolluted building whose kind is in the filter list.
func _nearest_building_kinds(x: float, y: float, kinds: Array, max_dist: float, who: int = -1) -> Dictionary:
	var best = {}
	var best_d = max_dist
	for b in _buildings_for_kinds(kinds):
		if b.dead or not kinds.has(int(b.kind)):
			continue
		if building_is_polluted(b):
			continue
		if who >= 0 and not _can_enter(b, who):
			continue
		var d = sim.spatial._dist_point(x, y, float(b.x), float(b.y))
		if d < best_d:
			best_d = d
			best = b
	return best



## Fed, fun, and clean threshold required before an agent may start ACT_WORK.
func _work_need() -> float:
	if bool(sim.mutations.get("hard", false)):
		return 32.0
	if bool(sim.mutations.get("care", false)):
		return 65.0
	return 50.0



## Whether a living agent meets work_need and may mine or haul for a building.
func _work_ready(i: int) -> bool:
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	var need = _work_need()
	return sim.fed[i] >= need and sim.amused[i] >= need and sim.clean[i] >= need



## Counts ready ACT_WORK agents in radius to enforce mine and factory job caps.
func _workers_near(b: Dictionary, cap: int) -> int:
	var radius = sim.agent_tick._work_radius(b) + 8.0
	var ids = sim.spatial.query_radius(float(b.x), float(b.y), radius)
	var n = 0
	for id in ids:
		var who = int(id)
		if int(sim.act[who]) != sim.ACT_WORK:
			continue
		if not _work_ready(who):
			continue
		n += 1
		if n >= cap:
			break
	return n



## Maps mine building kind and ore node tier to stock payout value.
func _mine_value(b: Dictionary) -> int:
	var node = int(b.get("node", 1))
	var mine = 1 if int(b.kind) == Catalog.BLD_MINE else 2
	if mine == 1 and node == 1:
		return 1
	if mine == 2 and node == 2:
		return 3
	if node >= 3:
		return node
	return 2



## Public probe whether the colony currently owns a building of this kind.
func has_building_kind(kind: int) -> bool:
	return _has_building(kind)



## Scans live buildings for a catalog kind (unlocks and milestone checks).
func _has_building(kind: int) -> bool:
	for b in sim.buildings:
		if not b.dead and int(b.kind) == kind:
			return true
	return false



## Clears the cached factory-present flag after building set changes.
func _invalidate_factory_cache() -> void:
	sim._has_factory_known = false



## Cached check that a live factory or factory2 exists for haul and unlock logic.
func _has_factory() -> bool:
	if sim._has_factory_known:
		return sim._has_factory_cache
	sim._has_factory_cache = false
	for b in sim.buildings:
		if b.dead:
			continue
		var kind = int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			sim._has_factory_cache = true
			break
	sim._has_factory_known = true
	return sim._has_factory_cache



## Returns or creates the FIFO ore token pile array on a factory building.
func _factory_pile(b: Dictionary) -> Array:
	var found = b.get("pile", [])
	if found is Array:
		return found
	var fresh: Array = []
	b.pile = fresh
	return fresh



## Seconds per ore processing cycle for factory versus factory2.
func _factory_cycle_time(kind: int) -> float:
	return sim.FACTORY_PROCESS_TIME2 if kind == Catalog.BLD_FACTORY2 else sim.FACTORY_PROCESS_TIME



## UI progress 0–1 through the current factory processing timer.
func factory_process_progress(b: Dictionary) -> float:
	# 0 at cycle start → 1 when the current ore is about to become energy.
	if b.is_empty() or bool(b.get("dead", true)):
		return 0.0
	if int(b.get("buffer", 0)) <= 0:
		return 0.0
	var cycle = _factory_cycle_time(int(b.kind))
	if cycle <= 0.01:
		return 0.0
	return clampf(1.0 - float(b.get("timer", 0.0)) / cycle, 0.0, 1.0)



## Pushes ore tokens onto the factory pile and starts the timer when idle.
func _factory_stack(b: Dictionary, n: int) -> void:
	var pile = _factory_pile(b)
	var was_empty = pile.is_empty() and int(b.get("buffer", 0)) <= 0
	var start = pile.size()
	for k in n:
		pile.append(start + k + 1)
	b.pile = pile
	b.buffer = pile.size()
	# First ore in an idle factory starts a fresh process cycle.
	if was_empty and n > 0:
		b.timer = _factory_cycle_time(int(b.kind))



## Pops one processed ore from pile or buffer when energy is granted.
func _factory_spend(b: Dictionary) -> void:
	var pile = _factory_pile(b)
	if pile.is_empty():
		b.buffer = maxi(0, int(b.get("buffer", 0)) - 1)
		return
	pile.pop_front()
	b.pile = pile
	b.buffer = pile.size()



