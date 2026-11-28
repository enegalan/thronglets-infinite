class_name SimPlayerTools
extends RefCounted

## Player tool actions: scoop, scrub, hand, placement, demolitions.

var sim


## Stores the simulation server used for tool side effects.
func _init(sim_ref) -> void:
	sim = sim_ref

## Player tool dispatch: drops, terrain tools, confirms, and side effects.
func use_tool(tool: int, x: float, y: float) -> void:
	if sim.frozen:
		return
	if not _tool_open(tool):
		sim.sfx_queue.append("locked")
		return
	if tool == Catalog.TOOL_APPLE:
		sim.dialogue._know_count()
		_drop_loose(Catalog.ITEM_APPLE, x, y, 1)
	elif tool == Catalog.TOOL_BALL:
		sim.dialogue._know_count()
		_drop_loose(Catalog.ITEM_BALL, x, y, 1)
	elif tool == Catalog.TOOL_SPONGE:
		sim.notes.append("MANTEN LA ESPONJA Y FROTA PARA LAVAR.")
	elif tool == Catalog.TOOL_AXE:
		_tool_axe(x, y)
	elif tool == Catalog.TOOL_HAMMER:
		_tool_hammer(x, y)
	elif tool == Catalog.TOOL_BUG:
		_tool_bug(x, y)
	elif tool == Catalog.TOOL_PICK:
		_tool_pick(x, y)
	elif tool == Catalog.TOOL_SAW:
		_tool_saw(x, y)
	elif tool == Catalog.TOOL_GRAB:
		scoop_gather(x, y)
	elif tool == Catalog.TOOL_MOP:
		_mop(x, y)
	elif tool == Catalog.TOOL_SWARM:
		_tool_swarm(x, y)
	elif tool == Catalog.TOOL_TNT:
		_tool_tnt(x, y)
	elif tool == Catalog.TOOL_NUKE:
		var c = sim.spatial._chunk_at(x, y)
		sim.dialogue._confirm("nuke", {"op": "nuke", "cx": c.x, "cy": c.y})



## Spawn a loose item at the cursor with terrain checks and physics launch.
func _drop_loose(kind: int, x: float, y: float, value: int) -> void:
	var at = Vector2(x, y)
	if Catalog.item_snaps_grid(kind):
		at = Catalog.snap_world(x, y)
	var ground = sim.collision._tile_at(at.x, at.y)
	var physics_drop = kind != Catalog.ITEM_EGG
	# Physics items can be dropped onto water/void and will fall/splash or fall away.
	var terrain_blocked = Catalog.tile_blocks(ground)
	if physics_drop and (ground == Catalog.TILE_WATER or ground == Catalog.TILE_VOID):
		terrain_blocked = false
	var bad_ground = not sim.revealed.has(sim.spatial._ck_of(at.x, at.y)) or terrain_blocked
	if physics_drop:
		bad_ground = bad_ground or ground == Catalog.TILE_FOG
	else:
		bad_ground = bad_ground or ground == Catalog.TILE_WATER or ground == Catalog.TILE_VOID or ground == Catalog.TILE_FOG
	if bad_ground or (not physics_drop and (not _can_drop(at.x, at.y) or sim.item_physics.obstacle_blocked(at.x, at.y))):
		sim.notes.append("AHI NO.")
		sim.sfx_queue.append("error")
		return
	var it = sim.world_entities._add_item(kind, at.x, at.y, value)
	sim.item_physics.launch_item(it, sim.item_physics.ITEM_DROP_HEIGHT, 0.0, 0.0, 0.0)
	if kind == Catalog.ITEM_BALL:
		it.life = sim.BALL_LIFE
		it.rest = 0.0
		sim.notes.append("LOS MULTIS JUEGAN SI LES FALTA DIVERSION.")
	sim.sfx_queue.append("ball" if kind == Catalog.ITEM_BALL else "place")



## Axe trees, reject cosmetic trees, or leave mountain stumps.
func _tool_axe(x: float, y: float) -> void:
	var feat = _axe_feature_at(x, y)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_TREE:
		var tx = float(feat.x)
		var ty = float(feat.y)
		_chop(feat)
		_splash_kill(tx, ty, 20.0)
		sim.sfx_queue.append("chop")
		return
	if not feat.is_empty() and (int(feat.kind) == Catalog.FEAT_COSMETIC or int(feat.kind) == Catalog.FEAT_COSMETIC_BAD):
		sim.dialogue._pop(float(feat.x), float(feat.y), Catalog.ICON_FX_CHOP)
		sim.notes.append("ESTE ARBOL NO DA MADERA.")
		sim.sfx_queue.append("chop")
		return
	if feat.is_empty() and sim.collision._tile_at(x, y) == Catalog.TILE_MOUNTAIN:
		var at = Catalog.snap_world(x, y)
		if not sim.world_entities._add_feature(Catalog.FEAT_MSTUMP, at.x, at.y, 1, 0, true).is_empty():
			sim.dialogue._pop(at.x, at.y, Catalog.ICON_FX_CHOP)
			sim.sfx_queue.append("chop")



## Fell a tree into a regrowing stump, drop wood, and hook progression.
func _chop(feat: Dictionary) -> void:
	feat.kind = Catalog.FEAT_STUMP
	feat.grow = Catalog.TREE_REGROW
	# Far-view MultiMesh caches sprites by epoch — kind changes must dirty it.
	sim.feat_mesh_epoch += 1
	var wood_it = sim.world_entities._add_item(Catalog.ITEM_WOOD, float(feat.x) + 8.0, float(feat.y), 1)
	sim.item_physics.launch_item(wood_it, 6.0, randf_range(85.0, 115.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
	sim.dialogue._pop(float(feat.x), float(feat.y), Catalog.ICON_FX_CHOP)
	sim.trees_chopped += 1
	sim.cap_told = false
	sim.dialogue._refresh_pop_gates()
	if sim.trees_chopped >= 12:
		sim.dialogue._grant("grabber", "DOCE ARBOLES. LA MANO JUNTA LO SUELTO.")



## Hammer loose ore patches, world features, or demolish buildings.
func _tool_hammer(x: float, y: float) -> void:
	# Ore piles near mines: smash a whole patch into energy, not one crystal per click.
	if sim.part_two and _smash_ore_near(x, y) > 0:
		sim.sfx_queue.append("hammer")
		return
	var feat = sim.world_entities._feature_at(x, y, 14.0)
	if not feat.is_empty():
		_hammer_feature(feat)
		sim.sfx_queue.append("hammer")
		return
	var b = sim.world_entities._building_at(x, y, 16.0)
	if not b.is_empty():
		sim.world_entities._remove_building(b)
		sim.sfx_queue.append("hammer")
		return



## Convert nearby ore pile items into energy gems in one stroke.
func _smash_ore_near(x: float, y: float) -> int:
	var gained = 0
	var smashed = 0
	for it in sim.items:
		if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
			continue
		if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
			continue
		gained += maxi(1, int(it.value))
		it.dead = true
		smashed += 1
		sim.dialogue._pop(float(it.x), float(it.y), Catalog.ICON_FX_HAMMER)
	if smashed <= 0:
		return 0
	sim.gems += gained
	sim.total_gems_earned += gained
	if smashed == 1:
		sim.notes.append("EL MINERAL SUELTA ENERGIA.")
	else:
		sim.notes.append("%d MINERAL → +%d ENERGIA." % [smashed, gained])
	return smashed



## Hammer outcomes per feature kind: rocks, stumps, fire, monolith guard.
func _hammer_feature(feat: Dictionary) -> void:
	var kind = int(feat.kind)
	if kind == Catalog.FEAT_MONOLITH:
		sim.notes.append("NO CEDE.")
		return
	if kind == Catalog.FEAT_TREE:
		sim.notes.append("ESO QUIERE EL HACHA.")
		return
	if kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP or kind == Catalog.FEAT_FLOWER or kind == Catalog.FEAT_FIRE or kind == Catalog.FEAT_TOTEM or kind == Catalog.FEAT_CURER or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		if kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
			if kind == Catalog.FEAT_STUMP:
				sim.stumps_cleared += 1
				sim.tree_seeds.append({"x": float(feat.x), "y": float(feat.y), "t": Catalog.TREE_REPLANT})
				sim.dialogue._refresh_pop_gates()
			sim.sfx_queue.append("stump")
		elif kind == Catalog.FEAT_FIRE:
			sim.sfx_queue.append("fire_out")
		sim.dialogue._pop(float(feat.x), float(feat.y), Catalog.ICON_FX_HAMMER)
		sim.world_entities._kill_feature(feat)
		return
	if sim.building_sim._ore_tier(kind) > 0:
		sim.notes.append("AHI VA UNA MINA.")
		return
	if sim.building_sim._is_rock(kind):
		sim.dialogue._pop(float(feat.x), float(feat.y), Catalog.ICON_FX_HAMMER)
		if kind == Catalog.FEAT_ROCK and not sim.part_two:
			sim.sfx_queue.append("rock_break")
			sim.world_entities._kill_feature(feat)
			return
		feat.hp = int(feat.hp) - 1
		if int(feat.hp) <= 0:
			sim.sfx_queue.append("rock_break")
		else:
			sim.sfx_queue.append("rock_crack")
		if int(feat.hp) <= 0:
			var ore_n = int(feat.ore)
			if ore_n > 0:
				var ore_it = sim.world_entities._add_item(Catalog.ITEM_ORE, float(feat.x), float(feat.y), ore_n if kind == Catalog.FEAT_BIGROCK else maxi(3, ore_n))
				sim.item_physics.launch_item(ore_it, 6.0, randf_range(85.0, 115.0), randf_range(-34.0, 34.0), randf_range(-34.0, 34.0))
			sim.world_entities._kill_feature(feat)
		return



## Pick rocks, stumps, and ore; plant mountain ore nodes when needed.
func _tool_pick(x: float, y: float) -> void:
	# Ore piles: pick can also collect energy (additive with hammer).
	if sim.part_two and _smash_ore_near(x, y) > 0:
		sim.sfx_queue.append("pick")
		return
	var hit = false
	for feat in sim.features:
		if feat.dead:
			continue
		var kind = int(feat.kind)
		if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) > Catalog.PICK_RADIUS:
			continue
		if sim.building_sim._is_rock(kind):
			_hammer_feature(feat)
			hit = true
			if kind == Catalog.FEAT_ORE_MEGA or kind == Catalog.FEAT_ORE_SUPER or kind == Catalog.FEAT_ORE_ULTRA:
				sim.sfx_queue.append("superore")
		elif kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
			_hammer_feature(feat)
			hit = true
	if not hit and sim.collision._tile_at(x, y) == Catalog.TILE_MOUNTAIN:
		var at = Catalog.snap_world(x, y)
		if not sim.world_entities._add_feature(Catalog.FEAT_MNODE, at.x, at.y, 3, 1, true).is_empty():
			sim.dialogue._pop(at.x, at.y, Catalog.ICON_FX_HAMMER)
			hit = true
	if hit:
		sim.sfx_queue.append("pick")



## Saw every tree in radius and splash-kill agents in the cut zone.
func _tool_saw(x: float, y: float) -> void:
	var hit = false
	for feat in sim.features:
		if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
			continue
		if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.SAW_RADIUS:
			_chop(feat)
			hit = true
	if hit:
		_splash_kill(x, y, Catalog.SAW_RADIUS)
		sim.sfx_queue.append("saw")



## Hold-to-use UI anchor: target key, hit count, and radius for a tool.
func charge_tool_target(tool: int, x: float, y: float) -> Dictionary:
	if tool == Catalog.TOOL_AXE:
		var tree = _axe_feature_at(x, y)
		if tree.is_empty() or int(tree.kind) != Catalog.FEAT_TREE:
			return {}
		return {"key": "feat:%d" % int(tree.id), "x": float(tree.x), "y": float(tree.y), "n": 1}
	if tool == Catalog.TOOL_HAMMER:
		if sim.part_two:
			var ore_n = sim.world_entities._count_items_near(Catalog.ITEM_ORE, x, y, Catalog.HAMMER_ORE_RADIUS)
			if ore_n > 0:
				return {
					"key": "ore:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
					"x": x,
					"y": y,
					"n": ore_n,
					"radius": Catalog.HAMMER_ORE_RADIUS,
				}
		var feat = sim.world_entities._feature_at(x, y, 14.0)
		if not feat.is_empty() and int(feat.kind) != Catalog.FEAT_TREE and int(feat.kind) != Catalog.FEAT_MONOLITH and sim.building_sim._ore_tier(int(feat.kind)) == 0:
			return {"key": "feat:%d" % int(feat.id), "x": float(feat.x), "y": float(feat.y), "n": 1}
		var b = sim.world_entities._building_at(x, y, 16.0)
		if not b.is_empty():
			return {"key": "bld:%d" % int(b.id), "x": float(b.x), "y": float(b.y), "n": 1}
		return {}
	if tool == Catalog.TOOL_PICK:
		if sim.part_two:
			var ore_n = sim.world_entities._count_items_near(Catalog.ITEM_ORE, x, y, Catalog.HAMMER_ORE_RADIUS)
			if ore_n > 0:
				return {
					"key": "ore:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
					"x": x,
					"y": y,
					"n": ore_n,
					"radius": Catalog.HAMMER_ORE_RADIUS,
				}
		var targets = 0
		for feat in sim.features:
			if feat.dead:
				continue
			var kind = int(feat.kind)
			if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) > Catalog.PICK_RADIUS:
				continue
			if sim.building_sim._is_rock(kind) or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP:
				targets += 1
		if targets <= 0:
			return {}
		return {"key": "pick:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": targets, "radius": Catalog.PICK_RADIUS}
	if tool == Catalog.TOOL_SAW:
		var trees = _count_features_near(Catalog.FEAT_TREE, x, y, Catalog.SAW_RADIUS)
		if trees <= 0:
			return {}
		return {"key": "saw:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))], "x": x, "y": y, "n": trees, "radius": Catalog.SAW_RADIUS}
	if tool == Catalog.TOOL_MOP:
		var dirty = 0
		for id in sim.spatial.query_radius(x, y, Catalog.MOP_RADIUS):
			if sim.state[int(id)] == Catalog.ST_LIVING and sim.clean[int(id)] < 100.0:
				dirty += 1
		var goo = _count_goo_near(x, y, Catalog.MOP_RADIUS)
		var n = dirty + goo
		if n <= 0:
			n = 1
		return {
			"key": "mop:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.MOP_RADIUS,
		}
	if tool == Catalog.TOOL_GRAB:
		if has_scoop():
			return {}
		var n = _count_scoopables(x, y, Catalog.GRAB_RADIUS)
		return {
			"key": "grab:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.GRAB_RADIUS,
		}
	if tool == Catalog.TOOL_SWARM:
		var n = sim.spatial.query_radius(x, y, Catalog.SWARM_RADIUS).size()
		return {
			"key": "swarm:%d:%d" % [int(floor(x / 8.0)), int(floor(y / 8.0))],
			"x": x,
			"y": y,
			"n": n,
			"radius": Catalog.SWARM_RADIUS,
		}
	return {}



## Enumerate entities a charged tool stroke will hit for VFX and validation.
func area_tool_hits(tool: int, x: float, y: float) -> Array:
	var hits: Array = []
	if tool == Catalog.TOOL_PICK:
		if sim.part_two:
			for it in sim.items:
				if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
					continue
				if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
					continue
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
			if not hits.is_empty():
				return hits
		for feat in sim.features:
			if feat.dead:
				continue
			var kind = int(feat.kind)
			if not (sim.building_sim._is_rock(kind) or kind == Catalog.FEAT_STUMP or kind == Catalog.FEAT_MSTUMP):
				continue
			if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.PICK_RADIUS:
				hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
		if hits.is_empty() and sim.collision._tile_at(x, y) == Catalog.TILE_MOUNTAIN:
			hits.append({"what": "mountain"})
		return hits
	if tool == Catalog.TOOL_SAW:
		for feat in sim.features:
			if feat.dead or int(feat.kind) != Catalog.FEAT_TREE:
				continue
			if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) <= Catalog.SAW_RADIUS:
				hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
		return hits
	if tool == Catalog.TOOL_MOP:
		for id in sim.spatial.query_radius(x, y, Catalog.MOP_RADIUS):
			var i = int(id)
			if sim.state[i] == Catalog.ST_LIVING and sim.clean[i] < 100.0:
				hits.append({"what": "throng", "id": i, "x": sim.pos_x[i], "y": sim.pos_y[i]})
		if _count_goo_near(x, y, Catalog.MOP_RADIUS) > 0:
			hits.append({"what": "goo"})
		return hits
	if tool == Catalog.TOOL_SPONGE:
		for id in sim.spatial.query_radius(x, y, Catalog.SPONGE_RADIUS):
			var i = int(id)
			if sim.state[i] == Catalog.ST_LIVING and sim.mito_t[i] <= 0.0 and sim.clean[i] < 100.0:
				hits.append({"what": "throng", "id": i, "x": sim.pos_x[i], "y": sim.pos_y[i]})
		return hits
	if tool == Catalog.TOOL_SWARM:
		for id in sim.spatial.query_radius(x, y, Catalog.SWARM_RADIUS):
			if sim.state[int(id)] != Catalog.ST_VACANT:
				hits.append({"what": "throng", "id": int(id)})
		return hits
	if tool == Catalog.TOOL_GRAB:
		for it in sim.items:
			if it.dead or it.held:
				continue
			var kind = int(it.kind)
			if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
				continue
			if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) <= Catalog.GRAB_RADIUS:
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
		for i in sim.slot_count:
			if sim.state[i] != Catalog.ST_DEAD:
				continue
			if sim.spatial._dist_i(i, x, y) <= Catalog.GRAB_RADIUS:
				hits.append({"what": "throng", "id": i, "x": sim.pos_x[i], "y": sim.pos_y[i]})
		return hits
	if tool == Catalog.TOOL_AXE:
		var tree = _axe_feature_at(x, y)
		if not tree.is_empty() and int(tree.kind) == Catalog.FEAT_TREE:
			hits.append({"what": "feat", "id": int(tree.id), "x": float(tree.x), "y": float(tree.y)})
		return hits
	if tool == Catalog.TOOL_HAMMER:
		if sim.part_two:
			for it in sim.items:
				if it.dead or it.held or int(it.kind) != Catalog.ITEM_ORE:
					continue
				if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) > Catalog.HAMMER_ORE_RADIUS:
					continue
				hits.append({"what": "item", "id": int(it.id), "x": float(it.x), "y": float(it.y)})
			if not hits.is_empty():
				return hits
		var feat = sim.world_entities._feature_at(x, y, 14.0)
		if not feat.is_empty() and int(feat.kind) != Catalog.FEAT_TREE and int(feat.kind) != Catalog.FEAT_MONOLITH and sim.building_sim._ore_tier(int(feat.kind)) == 0:
			hits.append({"what": "feat", "id": int(feat.id), "x": float(feat.x), "y": float(feat.y)})
			return hits
		var b = sim.world_entities._building_at(x, y, 16.0)
		if not b.is_empty():
			hits.append({"what": "bld", "id": int(b.id), "x": float(b.x), "y": float(b.y)})
		return hits
	return hits



## Count goo tiles in radius (sizes mop charge bars).
func _count_goo_near(x: float, y: float, radius: float) -> int:
	var n = 0
	var c0 = sim.spatial._cell_vec(x - radius, y - radius)
	var c1 = sim.spatial._cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx = float(cx * Catalog.TILE + 8)
			var wy = float(cy * Catalog.TILE + 8)
			if sim.spatial._dist_point(x, y, wx, wy) > radius:
				continue
			if sim.collision._tile_at(wx, wy) == Catalog.TILE_GOO:
				n += 1
	return n



## Count living features of a kind within radius.
func _count_features_near(kind: int, x: float, y: float, radius: float) -> int:
	var n = 0
	for feat in sim.features:
		if feat.dead or int(feat.kind) != kind:
			continue
		if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) <= radius:
			n += 1
	return n



## Count haulable items and corpses in grab-tool radius.
func _count_scoopables(x: float, y: float, radius: float) -> int:
	var n = 0
	for it in sim.items:
		if it.dead or it.held:
			continue
		var kind = int(it.kind)
		if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
			continue
		if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) <= radius:
			n += 1
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_DEAD:
			continue
		if sim.spatial._dist_i(i, x, y) <= radius:
			n += 1
	return n



## Whether grab tool is dragging a scoop pile of items or corpses.
func has_scoop() -> bool:
	return not sim.scoop_item_ids.is_empty() or not sim.scoop_dead_ids.is_empty()



## Vacuum wood, bone, ore, and corpses into orbiting scoop follow mode.
func scoop_gather(x: float, y: float) -> int:
	if sim.frozen or has_scoop() or sim.hand_id != -1 or sim.held_kind != "":
		return 0
	var got = 0
	for it in sim.items:
		if it.dead or it.held:
			continue
		var kind = int(it.kind)
		if kind != Catalog.ITEM_WOOD and kind != Catalog.ITEM_BONE and kind != Catalog.ITEM_ORE:
			continue
		if sim.spatial._dist_point(x, y, float(it.x), float(it.y)) > Catalog.GRAB_RADIUS:
			continue
		it.held = true
		sim.scoop_item_ids.append(int(it.id))
		got += 1
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_DEAD:
			continue
		if sim.spatial._dist_i(i, x, y) > Catalog.GRAB_RADIUS:
			continue
		sim.scoop_dead_ids.append(i)
		got += 1
	if got > 0:
		scoop_follow(x, y)
		sim.sfx_queue.append("grab")
	return got



## Orbit scooped items and corpses around the cursor each frame.
func scoop_follow(x: float, y: float) -> void:
	var i = 0
	for raw in sim.scoop_item_ids:
		var it = sim.item_by_id.get(int(raw), {})
		if it.is_empty() or it.dead:
			continue
		var ang = float(i) * 0.85
		var rad = 3.0 + float(i % 3) * 2.0
		it.x = x + cos(ang) * rad
		it.y = y + sin(ang) * rad
		i += 1
	for raw2 in sim.scoop_dead_ids:
		var id = int(raw2)
		if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_DEAD:
			continue
		var ang2 = float(i) * 0.85
		sim.pos_x[id] = x + cos(ang2) * 4.0
		sim.pos_y[id] = y + sin(ang2) * 4.0
		i += 1



## Scatter scooped pickups at release with physics and valid placement tries.
func scoop_drop(x: float, y: float) -> void:
	if not has_scoop():
		return
	for raw in sim.scoop_item_ids:
		var it = sim.item_by_id.get(int(raw), {})
		if it.is_empty() or it.dead:
			continue
		it.held = false
		var dropped = false
		for _try in 8:
			var ox = randf_range(-30.0, 30.0)
			var oy = randf_range(-30.0, 30.0)
			var px = x + ox
			var py = y + oy
			if Catalog.item_snaps_grid(int(it.kind)):
				var snapped = Catalog.snap_world(px, py)
				px = snapped.x
				py = snapped.y
			var s_ground = sim.collision._tile_at(px, py)
			var scoop_physics = int(it.kind) != Catalog.ITEM_EGG
			var s_bad = s_ground == Catalog.TILE_WATER or s_ground == Catalog.TILE_VOID or s_ground == Catalog.TILE_FOG or Catalog.tile_blocks(s_ground)
			if s_bad or (not scoop_physics and sim.item_physics.obstacle_blocked(px, py)):
				continue
			it.x = px
			it.y = py
			dropped = true
			break
		if not dropped:
			it.x = x + randf_range(-12.0, 12.0)
			it.y = y + randf_range(-12.0, 12.0)
		var sang = randf() * TAU
		var sspd = randf_range(24.0, 58.0)
		sim.item_physics.launch_item(it, randf_range(18.0, 30.0), randf_range(25.0, 65.0), cos(sang) * sspd, sin(sang) * sspd)
	for raw2 in sim.scoop_dead_ids:
		var id = int(raw2)
		if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_DEAD:
			continue
		var placed = false
		for _try2 in 8:
			var dx = x + randf_range(-30.0, 30.0)
			var dy = y + randf_range(-30.0, 30.0)
			if sim.collision._blocked(dx, dy):
				continue
			sim.pos_x[id] = dx
			sim.pos_y[id] = dy
			placed = true
			break
		if not placed:
			sim.pos_x[id] = x + randf_range(-10.0, 10.0)
			sim.pos_y[id] = y + randf_range(-10.0, 10.0)
	sim.scoop_item_ids.clear()
	sim.scoop_dead_ids.clear()
	sim.sfx_queue.append("release")



## Open confirm to debug-act on one thronglet under the cursor.
func _tool_bug(x: float, y: float) -> void:
	var id = sim.spatial.find_thronglet(x, y, 14.0, false)
	if id < 0:
		return
	sim.dialogue._confirm("bug", {"op": "bug", "id": id})



## Open confirm for area swarm celebration at a world point.
func _tool_swarm(x: float, y: float) -> void:
	sim.dialogue._confirm("bug", {"op": "swarm", "x": x, "y": y})



## Place new TNT charge or detonate existing charge at snap point.
func _tool_tnt(x: float, y: float) -> void:
	var at = Catalog.snap_world(x, y)
	x = at.x
	y = at.y
	var charge = sim.world_entities._nearest_item(x, y, Catalog.ITEM_TNT, 14.0)
	if not charge.is_empty():
		_detonate(charge)
		return
	if not _can_drop(x, y) or not sim.world_entities._item_spot_free(x, y):
		sim.notes.append("AHI NO.")
		sim.sfx_queue.append("error")
		return
	var tnt_it = sim.world_entities._add_item(Catalog.ITEM_TNT, x, y, 1)
	sim.item_physics.launch_item(tnt_it, 18.0, 0.0, 0.0, 0.0)
	sim.notes.append("CARGA COLOCADA. PULSALA PARA DETONARLA.")
	sim.sfx_queue.append("tnt_place")



## TNT blast: kill features, reshape tiles, splash agents; story monolith hook.
func _detonate(charge: Dictionary) -> void:
	var x = float(charge.x)
	var y = float(charge.y)
	charge.dead = true
	sim.dialogue._pop(x, y, Catalog.ICON_FX_BOOM)
	sim.tnt_used += 1
	for feat in sim.features:
		if feat.dead or int(feat.kind) == Catalog.FEAT_MONOLITH:
			continue
		if sim.spatial._dist_point(x, y, float(feat.x), float(feat.y)) <= 56.0:
			sim.world_entities._kill_feature(feat)
	_explode_tiles(x, y, 56.0)
	_splash_kill(x, y, 34.0)
	if sim.tnt_used == 1:
		sim.dialogue._ensure_monolith(2)
		sim.notes.append("LA DINAMITA NO BASTA. OTRO MONOLITO APARECE.")
	sim.sfx_queue.append("tnt_arm")
	sim.sfx_queue.append("explode")



## Blast disk converts mountain, rubble, and goo tiles to dirt.
func _explode_tiles(x: float, y: float, radius: float) -> void:
	var c0 = sim.spatial._cell_vec(x - radius, y - radius)
	var c1 = sim.spatial._cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx = float(cx * Catalog.TILE + 8)
			var wy = float(cy * Catalog.TILE + 8)
			if sim.spatial._dist_point(x, y, wx, wy) > radius:
				continue
			var tile = sim.collision._tile_at(wx, wy)
			if tile == Catalog.TILE_MOUNTAIN or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_GOO:
				sim.collision._set_world_cell(cx, cy, Catalog.TILE_DIRT, true)



## Mop goo tiles and max clean for nearby living agents instantly.
func _mop(x: float, y: float) -> void:
	var radius = Catalog.MOP_RADIUS
	var c0 = sim.spatial._cell_vec(x - radius, y - radius)
	var c1 = sim.spatial._cell_vec(x + radius, y + radius)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var wx = float(cx * Catalog.TILE + 8)
			var wy = float(cy * Catalog.TILE + 8)
			if sim.spatial._dist_point(x, y, wx, wy) > radius:
				continue
			if sim.collision._tile_at(wx, wy) == Catalog.TILE_GOO:
				var base = sim.collision._base_at(wx, wy)
				if base == Catalog.TILE_GOO or base == Catalog.TILE_MOUNTAIN:
					base = Catalog.TILE_DIRT
				sim.collision._set_world_cell(cx, cy, base, false)
	sim.goo_count = sim.world_entities._count_goo()
	var ids = sim.spatial.query_radius(x, y, radius)
	for id in ids:
		var tid = int(id)
		if sim.state[tid] == Catalog.ST_LIVING and sim.mito_t[tid] <= 0.0:
			var was_dirty = sim.clean[tid] < 100.0
			sim.clean[tid] = 100.0
			if was_dirty:
				_finish_wash(tid)  # mop has no hold — sparkle immediately
	sim.sfx_queue.append("mop")



## Sponge drag: lock wash target, gain clean while rubbing, queue sparkle FX.
func scrub(x: float, y: float, stroke: float, rubbing: bool = false) -> void:
	if sim.frozen:
		return
	var sponge_tune: Dictionary = EffectTune.get_tune("act:sponge")
	var stroke_min = float(sponge_tune.get("stroke_min", sim.SCRUB_STROKE_MIN))
	var stroke_cap = float(sponge_tune.get("stroke_cap", 6.0))
	var gain_mul = float(sponge_tune.get("gain", 1.25))
	var radius = float(sponge_tune.get("radius", Catalog.SPONGE_RADIUS))
	var ids = sim.spatial.query_radius(x, y, radius)
	if ids.is_empty():
		# Left every thronglet — drop wash pose; pending sparkles wait for release.
		if sim.sponge_id >= 0:
			_clear_wash_pose(sim.sponge_id)
			sim.sponge_id = -1
		sim.sponge_hold = 0.0
		return
	sim.sponge_hold = 0.55
	var scrubbing = rubbing or stroke >= stroke_min
	var target = _scrub_pick_target(ids)
	if target < 0:
		if sim.sponge_id >= 0:
			_clear_wash_pose(sim.sponge_id)
			sim.sponge_id = -1
		return
	# Only the thronglet under the sponge shows suds; leave prior targets.
	if sim.sponge_id >= 0 and sim.sponge_id != target:
		_clear_wash_pose(sim.sponge_id)
	sim.sponge_id = target
	sim.act[target] = sim.ACT_WASH
	sim.dir_x[target] = 0.0
	sim.dir_y[target] = 0.0
	if not scrubbing:
		sim.act_t[target] = maxf(sim.act_t[target], 0.35)
		return
	sim.dialogue._know_count()
	var gain = minf(stroke, stroke_cap) * gain_mul
	if sim.clean[target] < 100.0:
		sim.clean[target] = minf(100.0, sim.clean[target] + gain)
		if sim.clean[target] >= 100.0:
			_queue_wash_fx(target)
	sim.act_t[target] = 0.85
	if int(sim.frame_i) % 3 == 0:
		sim.sfx_queue.append("scrub")



## Keep sponge on current target if still in range, else nearest washable agent.
func _scrub_pick_target(ids: Array) -> int:
	# Prefer current sponge_id if still in range; else nearest living thronglet.
	for raw in ids:
		var id = int(raw)
		if id == sim.sponge_id and sim.state[id] == Catalog.ST_LIVING and sim.mito_t[id] <= 0.0:
			return id
	for raw2 in ids:
		var id2 = int(raw2)
		if sim.state[id2] != Catalog.ST_LIVING or sim.mito_t[id2] > 0.0:
			continue
		return id2
	return -1



## Whether post-wash sparkle FX is already queued for an agent.
func _wash_fx_queued(id: int) -> bool:
	for pending in sim.wash_fx_pending:
		if int(pending) == id:
			return true
	return false



## Freeze agent and queue wash-complete sparkle pending sponge release.
func _queue_wash_fx(id: int) -> void:
	sim.world_entities._ensure_agent_timers(id)
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0
	if _wash_fx_queued(id):
		return
	sim.wash_fx_pending.append(id)



## End scrub hold: clear pose and fire sparkles for all queued clean agents.
func sponge_release() -> void:
	# End scrub pose; sparkles for every thronglet cleaned during this hold.
	var pending: Array = sim.wash_fx_pending.duplicate()
	sim.wash_fx_pending.clear()
	if sim.sponge_id >= 0:
		_clear_wash_pose(sim.sponge_id)
		sim.sponge_id = -1
	sim.sponge_hold = 0.0
	for raw in pending:
		_finish_wash(int(raw))



## Complete one wash: clear act, cheer timer, and spawn clean sparkle pop.
func _finish_wash(id: int) -> void:
	_clear_wash_pose(id)
	if sim.sponge_id == id:
		sim.sponge_id = -1
		sim.sponge_hold = 0.0
	sim.world_entities._ensure_agent_timers(id)
	_pop_wash_sparkle(id)
	sim.cheer_t[id] = sim.WASH_FX_LIFE
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0



## Spawn clean sparkle pop tied to an agent without duplicating.
func _pop_wash_sparkle(id: int) -> void:
	if id < 0 or id >= sim.slot_count:
		return
	for pop in sim.pops:
		if str(pop.get("kind", "")) == "wash" and int(pop.get("throng_id", -1)) == id:
			return
	sim.dialogue._pop(sim.pos_x[id], sim.pos_y[id], AssetFrames.CLEAN, 1.0, id, sim.WASH_FX_LIFE, "wash")



## Drop wash action state without running full finish celebration.
func _clear_wash_pose(id: int) -> void:
	if id < 0 or id >= sim.slot_count:
		return
	sim.shake_t[id] = 0.0
	if sim.act[id] == sim.ACT_WASH:
		sim.act[id] = 0
		sim.act_t[id] = 0.0



## Eye-tool inspect: monolith, factory burn, market, blurb, or thronglet pick.
func eye_use(x: float, y: float) -> Dictionary:
	if sim.frozen:
		return {"type": "frozen"}
	var feat = sim.world_entities._feature_at(x, y, 14.0)
	if not feat.is_empty() and int(feat.kind) == Catalog.FEAT_MONOLITH:
		sim.dialogue._touch_monolith(feat)
		return {"type": "monolith"}
	var b = sim.world_entities._building_at(x, y, 16.0)
	if not b.is_empty():
		var kind = int(b.kind)
		if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
			if not bool(b.get("incinerate", false)):
				sim.dialogue._confirm("burn", {"op": "burn", "id": int(b.id)})
			else:
				sim.notes.append("LA FABRICA INCINERA CADAVERES.")
			return {"type": "factory", "id": int(b.id)}
		if kind == Catalog.BLD_MARKET:
			return {"type": "market", "id": int(b.id)}
		_describe_building(b)
		return {"type": "building", "id": int(b.id), "kind": kind}
	var id = sim.spatial.find_thronglet(x, y, 12.0, false)
	if id >= 0:
		return {"type": "thronglet", "id": id}
	return {"type": "empty"}



## Push flavor notes describing what a building does when inspected.
func _describe_building(b: Dictionary) -> void:
	var kind = int(b.kind)
	match kind:
		Catalog.BLD_APPLE:
			sim.notes.append("EL MANZANO CRIA MANZANAS. CRECEN Y CAEN.")
		Catalog.BLD_TUB:
			sim.notes.append("LA BANERA LIMPIA A QUIÉN SE METE.")
		Catalog.BLD_ROUND:
			sim.notes.append("EL TIOVIVO SUBE LA DIVERSION. LOS MULTIS GIRAN ALREDEDOR.")
		Catalog.BLD_DWELL:
			sim.notes.append("VIVIENDA. CUPO 4. COMEN, SE LAVAN Y DESCANSAN UN RATO.")
		Catalog.BLD_FANCY:
			sim.notes.append("VIVIENDA DE LUJO. CABEN MÁS; COMEN Y SE LAVAN MEJOR.")
		Catalog.BLD_MINE, Catalog.BLD_MINE2:
			sim.notes.append("LA MINA SE LLENA SOLA. CON FABRICA, LOS MULTIS ENTRAN Y SACAN MINERAL.")
		Catalog.BLD_THEATRE:
			sim.notes.append("EL TEATRO TIENE CUPO. LA FUNCION ACABA Y SALEN.")
		Catalog.BLD_FLOWER:
			sim.notes.append("LA FLOR DA UN POCO DE ALEGRIA.")
		Catalog.BLD_STATUE:
			sim.notes.append("LA ESCULTURA ANIMA Y ACELERA A LOS CERCANOS.")
		_:
			if Catalog.BUILD_INFO.has(kind):
				sim.notes.append(str(Catalog.BUILD_INFO[kind].label))



## Pick up a ground item into the hand slot (blocks fixed and eggs).
func take_hand(x: float, y: float) -> bool:
	if sim.hand_id != -1 or sim.frozen:
		return false
	var it = sim.world_entities._item_at(x, y, 10.0)
	if it.is_empty():
		return false
	if bool(it.get("fixed", false)) or int(it.kind) == Catalog.ITEM_EGG:
		return false
	it.held = true
	sim.hand_id = int(it.id)
	var held_kind_now = int(it.kind)
	if held_kind_now == Catalog.ITEM_WOOD:
		sim.sfx_queue.append("wood_grab")
	elif held_kind_now == Catalog.ITEM_BONE:
		sim.sfx_queue.append("bone_grab")
	else:
		sim.sfx_queue.append("grab")
	return true



## Release hand-held item with optional throw velocity.
func drop_hand(x: float, y: float, throw_vx: float = 0.0, throw_vy: float = 0.0) -> void:
	if sim.hand_id == -1:
		return
	var it = sim.item_by_id.get(sim.hand_id, {})
	if it.is_empty() or it.dead:
		sim.hand_id = -1
		return
	var at = Vector2(x, y)
	# Fix (1): don't clear hand/held state if egg can't be dropped onto obstacle.
	if int(it.kind) == Catalog.ITEM_EGG and sim.item_physics.obstacle_blocked(at.x, at.y):
		return
	sim.hand_id = -1
	it.held = false
	var drop_tile = sim.collision._tile_at(at.x, at.y)
	if drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG or drop_tile == Catalog.TILE_WATER:
		it.x = at.x
		it.y = at.y
		sim.item_physics.launch_item(it, 14.0, 0.0, clampf(throw_vx, -180.0, 180.0), clampf(throw_vy, -180.0, 180.0))
		return
	it.x = at.x
	it.y = at.y
	sim.item_physics.launch_item(it, 16.0, 20.0, clampf(throw_vx, -180.0, 180.0), clampf(throw_vy, -180.0, 180.0))
	if int(it.kind) == Catalog.ITEM_WOOD:
		sim.sfx_queue.append("wood_drop")
	elif int(it.kind) == Catalog.ITEM_BONE:
		sim.sfx_queue.append("bone_drop")
	else:
		sim.sfx_queue.append("place")



## Whether player holds an item, scoop pile, or lifted agent/feature.
func is_holding() -> bool:
	return sim.held_kind != "" or sim.hand_id != -1 or has_scoop()



## Lift a living agent into held state and clear movement, acts, and barks.
func grab_thronglet(id: int) -> bool:
	if sim.frozen or is_holding():
		return false
	if id < 0 or id >= sim.slot_count or sim.state[id] != Catalog.ST_LIVING:
		return false
	if sim.mito_t[id] > 0.0 or sim.mito_charge[id] > 0.0:
		return false
	sim.held_kind = "thronglet"
	sim.held_ref = id
	sim.held_x = sim.pos_x[id]
	sim.held_y = sim.pos_y[id]
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0
	sim.act[id] = 0
	sim.act_t[id] = 0.0
	sim.world_entities._ensure_agent_timers(id)
	sim.cheer_t[id] = 0.0
	sim.react_t[id] = 0.0
	sim.drop_t[id] = 0.0
	sim.world_entities._clear_peer_social(id)
	sim.dialogue.clear_bark(id)
	return true



## Cursor grab: thronglet, movable rock, egg hatch help, or hand item.
func grab_at(x: float, y: float) -> bool:
	if sim.frozen or is_holding():
		return false
	var id = sim.spatial.find_thronglet(x, y, 14.0, true)
	if id >= 0:
		return grab_thronglet(id)
	var feat = sim.world_entities._feature_at(x, y, 14.0)
	if not feat.is_empty():
		if not sim.world_entities._feature_movable(feat):
			return false
		sim.held_kind = "rock"
		sim.held_ref = int(feat.id)
		sim.held_x = float(feat.x)
		sim.held_y = float(feat.y)
		feat.lifted = true
		sim.feat_mesh_epoch += 1
		sim.world_entities._unbind_feature(feat)
		return true
	var it = sim.world_entities._item_at(x, y, 10.0)
	if not it.is_empty() and (bool(it.get("fixed", false)) or int(it.kind) == Catalog.ITEM_EGG):
		if int(it.kind) == Catalog.ITEM_EGG:
			sim.dialogue._help_egg(it)
		return false
	return take_hand(x, y)



## Valid stand or drop tile for agents, including mine walk pads and shore lip.
func _thronglet_ground_ok(px: float, py: float) -> bool:
	# Mine zones are walkable ground pads: allow dropping/standing on them.
	if sim.collision._on_mine_pad(px, py):
		return sim.revealed.has(sim.spatial._ck_of(px, py)) and not Catalog.tile_blocks(sim.collision._tile_at(px, py))
	return _can_drop(px, py)



## Spiral search for legal thronglet placement near a bad release point.
func _find_safe_thronglet_spot(x: float, y: float) -> Vector2:
	for ring in 32:
		var rays = 1 if ring == 0 else 12
		for i in rays:
			var ang = float(i) * TAU / float(maxi(rays, 1))
			var r = float(ring) * 10.0
			var at = Vector2(x + cos(ang) * r, y + sin(ang) * r)
			if _thronglet_ground_ok(at.x, at.y):
				return at
	return Vector2(INF, INF)



## Release hand item, held thronglet, or rock with void and water safety.
func release_at(x: float, y: float, short_click: bool, _allow_use: bool = true, throw_vx: float = 0.0, throw_vy: float = 0.0) -> Dictionary:
	if sim.hand_id != -1:
		var it = sim.item_by_id.get(sim.hand_id, {})
		var ix = x
		var iy = y
		var tvx = 0.0 if short_click else throw_vx
		var tvy = 0.0 if short_click else throw_vy
		if short_click and not it.is_empty():
			ix = float(it.x)
			iy = float(it.y)
		drop_hand(ix, iy, tvx, tvy)
		return {}
	if sim.held_kind == "":
		return {}
	var px = sim.held_x if short_click else x
	var py = sim.held_y if short_click else y
	var kind = sim.held_kind
	var id = sim.held_ref
	if kind != "thronglet" and not short_click:
		var snapped = Catalog.snap_world(px, py)
		px = snapped.x
		py = snapped.y
	if kind == "thronglet" and id >= 0 and id < sim.slot_count and sim.state[id] == Catalog.ST_LIVING:
		if short_click:
			if _thronglet_ground_ok(px, py):
				sim.spatial._set_agent_pos(id, px, py)
		else:
			var drop_tile = sim.collision._tile_at(px, py)
			if drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG:
				sim.spatial._set_agent_pos(id, px, py)
				sim.world_entities._fall_void(px, py)
				sim.world_entities._vacate(id)
			elif drop_tile == Catalog.TILE_WATER or not _thronglet_ground_ok(px, py):
				var safe = _find_safe_thronglet_spot(px, py)
				if is_inf(safe.x):
					safe = _find_safe_thronglet_spot(sim.held_x, sim.held_y)
				if not is_inf(safe.x):
					sim.spatial._set_agent_pos(id, safe.x, safe.y)
				elif drop_tile == Catalog.TILE_VOID or drop_tile == Catalog.TILE_FOG:
					sim.spatial._set_agent_pos(id, px, py)
					sim.world_entities._fall_void(px, py)
					sim.world_entities._vacate(id)
				else:
					if _thronglet_ground_ok(sim.held_x, sim.held_y):
						sim.spatial._set_agent_pos(id, sim.held_x, sim.held_y)
					else:
						sim.spatial._set_agent_pos(id, px, py)
			else:
				sim.spatial._set_agent_pos(id, px, py)
	elif kind == "rock":
		var feat = sim.feature_by_id.get(id, {})
		if not feat.is_empty() and not feat.dead:
			if sim.collision._tile_at(px, py) == Catalog.TILE_VOID or not sim.collision._land_inland(px, py):
				sim.world_entities._fall_void(px, py)
				sim.world_entities._kill_feature(feat)
			elif not _can_drop(px, py) or not sim.world_entities._stands(px, py, sim.world_entities._span_for_feature(int(feat.kind))) or not sim.world_entities._bind_feature_at(feat, px, py):
				feat.x = sim.held_x
				feat.y = sim.held_y
				sim.world_entities._bind_feature_at(feat, sim.held_x, sim.held_y)
			feat.lifted = false
			sim.feat_mesh_epoch += 1
	_clear_held()
	if short_click and kind == "thronglet":
		return {"type": "thronglet", "id": id}
	return {}



## Cancel drag by short-click release at original grab position.
func cancel_hold() -> void:
	if not is_holding():
		return
	release_at(sim.held_x, sim.held_y, true, false)



## Reset held_kind and held_ref without moving world entities.
func _clear_held() -> void:
	sim.held_kind = ""
	sim.held_ref = -1



## Revealed chunk tile that is not movement-blocked for placement.
func _can_drop(x: float, y: float, allow_ore: bool = false, allow_soft: bool = false) -> bool:
	return sim.revealed.has(sim.spatial._ck_of(x, y)) and not sim.collision._blocked(x, y, allow_ore, allow_soft)



## Whether a relocated feature fits without cell ownership conflicts.
func can_drop_feature(id: int, x: float, y: float) -> bool:
	var feat = sim.feature_by_id.get(id, {})
	if feat.is_empty() or feat.dead:
		return false
	var at = Catalog.snap_world(x, y)
	if not _can_drop(at.x, at.y) or not sim.world_entities._stands(at.x, at.y, sim.world_entities._span_for_feature(int(feat.kind))):
		return false
	var cells = sim.building_sim._footprint_cells(at.x, at.y, Catalog.footprint_for_feature(int(feat.kind)))
	for cell in cells:
		var owner = int(sim.feature_cell.get(cell, -1))
		if owner >= 0 and owner != id:
			return false
		if int(sim.building_cell.get(cell, -1)) >= 0:
			return false
	return true



## Item dict for the object currently held in the hand slot.
func hand_item() -> Dictionary:
	if sim.hand_id == -1:
		return {}
	return sim.item_by_id.get(sim.hand_id, {})



## Whether a tool is unlocked and not superseded by progression.
func _tool_open(tool: int) -> bool:
	for entry in Catalog.TOOL_INFO:
		if int(entry.tool) != tool:
			continue
		var key = str(entry.get("unlock", ""))
		if key == "":
			return true
		if not bool(sim.unlocks.get(key, false)):
			return false
		return not ProgressionManager.replaced_by_unlocked(sim, key)
	return true



## Placement sound id chosen from building kind.
func _place_sfx(kind: int) -> String:
	if kind == Catalog.BLD_DWELL or kind == Catalog.BLD_FANCY:
		return "place_house"
	if kind == Catalog.BLD_TUB:
		return "place_tub"
	if kind == Catalog.BLD_ROUND:
		return "place_round"
	if kind == Catalog.BLD_FACTORY or kind == Catalog.BLD_FACTORY2:
		return "place_factory"
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		return "place_mine"
	if kind == Catalog.BLD_THEATRE:
		return "place_theatre"
	if kind == Catalog.BLD_STATUE or kind == Catalog.BLD_WOOD:
		return "place_statue"
	if kind == Catalog.BLD_APPLE:
		return "place_apple"
	return "place"



## Spend costs, validate spot, consume ore node, and spawn a building.
func place_building(kind: int, x: float, y: float) -> bool:
	if sim.frozen:
		return false
	if not Catalog.BUILD_INFO.has(kind):
		return false
	var at = Catalog.snap_world(x, y)
	var info: Dictionary = Catalog.BUILD_INFO[kind]
	if not bool(sim.unlocks.get(str(info.unlock), false)):
		sim.notes.append("AUN NO ESTA DESBLOQUEADO.")
		sim.sfx_queue.append("error")
		return false
	if kind == Catalog.BLD_MARKET and sim.building_sim._has_building(Catalog.BLD_MARKET):
		sim.notes.append("SOLO PUEDE HABER UN MERCADO.")
		return false
	var node = 0
	var ore_feat = {}
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		if sim.sandbox_mode:
			node = 1 if kind == Catalog.BLD_MINE else 2
		else:
			ore_feat = sim.world_entities._feature_at(at.x, at.y, 12.0)
			if ore_feat.is_empty() or sim.building_sim._ore_tier(int(ore_feat.kind)) == 0:
				sim.notes.append("LA MINA SOLO VA SOBRE UN NODO.")
				sim.sfx_queue.append("error")
				return false
			node = sim.building_sim._ore_tier(int(ore_feat.kind))
			at = Catalog.snap_world(float(ore_feat.x), float(ore_feat.y))
	var allow_ore = not ore_feat.is_empty()
	if not _can_drop(at.x, at.y, allow_ore, true) or not sim.building_sim._building_spot_free(-1, at.x, at.y, kind):
		sim.notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sim.sfx_queue.append("error")
		return false
	var costs = sim.dialogue._building_costs(kind)
	var gem_cost = int(costs.gem)
	var wood_cost = int(costs.wood)
	if gem_cost > 0 and sim.gems < gem_cost:
		sim.notes.append("FALTAN GEMAS (%d)." % gem_cost)
		sim.sfx_queue.append("error")
		return false
	if not sim.world_entities._consume_kind(Catalog.ITEM_WOOD, wood_cost, at.x, at.y):
		sim.notes.append("FALTA MADERA.")
		sim.sfx_queue.append("error")
		return false
	if gem_cost > 0:
		sim.gems -= gem_cost
	if allow_ore:
		sim.world_entities._kill_feature(ore_feat)
	var b = sim.world_entities._add_building(kind, at.x, at.y)
	if b.is_empty():
		if gem_cost > 0:
			sim.gems += gem_cost
		sim.notes.append("AHI NO SE PUEDE CONSTRUIR.")
		sim.sfx_queue.append("error")
		return false
	b.node = node
	sim.sfx_queue.append(_place_sfx(kind))
	sim.dialogue._refresh_pop_gates()
	return true



## Unified snap-point validity for building placement or item drops.
func spot_ok(x: float, y: float, building_id: int = -1, ignore_item_id: int = -1, build_kind: int = -1) -> bool:
	var at = Catalog.snap_world(x, y)
	var allow_ore = build_kind == Catalog.BLD_MINE or build_kind == Catalog.BLD_MINE2
	if not allow_ore and building_id >= 0:
		var held = sim.building_by_id.get(building_id, {})
		var held_kind = int(held.get("kind", -1))
		allow_ore = held_kind == Catalog.BLD_MINE or held_kind == Catalog.BLD_MINE2
	var placing_bld = building_id >= 0 or build_kind >= 0
	if not _can_drop(at.x, at.y, allow_ore, placing_bld):
		return false
	if placing_bld:
		var kind = build_kind
		if kind < 0:
			var held = sim.building_by_id.get(building_id, {})
			kind = int(held.get("kind", -1))
		if not sim.building_sim._building_spot_free(building_id, at.x, at.y, kind):
			return false
		if ignore_item_id >= 0:
			for cell in sim.building_sim._footprint_cells(at.x, at.y, Catalog.footprint_for_building(kind)):
				var mid = sim.world_entities._cell_world(cell)
				var other = sim.world_entities._item_at(mid.x, mid.y, 10.0)
				if not other.is_empty() and int(other.id) != ignore_item_id:
					return false
		return true
	if not sim.world_entities._item_spot_free(at.x, at.y, ignore_item_id):
		return false
	return int(sim.building_cell.get(sim.spatial._cell_vec(at.x, at.y), -1)) < 0



## Affordable building placement including campaign mine-node rules.
func can_place_building(kind: int, x: float, y: float) -> bool:
	if kind == Catalog.BLD_MARKET and sim.building_sim._has_building(Catalog.BLD_MARKET):
		return false
	if not sim.dialogue._can_afford_building(kind):
		return false
	var at = Catalog.snap_world(x, y)
	if kind == Catalog.BLD_MINE or kind == Catalog.BLD_MINE2:
		if not sim.sandbox_mode:
			var feat = sim.world_entities._feature_at(at.x, at.y, 12.0)
			if feat.is_empty() or sim.building_sim._ore_tier(int(feat.kind)) == 0:
				return false
			at = Catalog.snap_world(float(feat.x), float(feat.y))
	return spot_ok(at.x, at.y, -1, -1, kind)



## Market purchase: spend gems, grant unlock, refresh progression gates.
func buy(key: String) -> bool:
	if not sim.building_sim._has_building(Catalog.BLD_MARKET):
		sim.notes.append("COLOCA EL MERCADO PRIMERO.")
		return false
	if not Catalog.MARKET.has(key):
		return false
	if bool(sim.unlocks.get(key, false)):
		return false
	var cost = int(Catalog.MARKET[key].cost)
	var pc = ProgressionCatalog.by_id(key)
	if not pc.is_empty():
		cost = maxi(cost, int(pc.get("baseGemCost", cost)))
	if sim.gems < cost:
		sim.notes.append("FALTAN GEMAS.")
		return false
	sim.gems -= cost
	sim.dialogue._grant(key, "COMPRADO: " + str(Catalog.MARKET[key].label))
	ProgressionManager.evaluate_unlocks(sim, true)
	return true



## Radial wipe of every agent in swarm radius without per-kill bug progression.
func _swarm(x: float, y: float) -> void:
	var ids = sim.spatial.query_radius(x, y, Catalog.SWARM_RADIUS)
	for id in ids:
		if sim.state[int(id)] != Catalog.ST_VACANT:
			sim.world_entities._deflesh(int(id), false)
	if sim.part_two:
		sim.bug_uses += 1
		if sim.bug_uses >= 3:
			sim.dialogue._grant("swarm", "EL BICHO, TRES VECES. EL ENJAMBRE ABRE UN RADIO.")



## Cleans one chunk of goo/rubble, removes props and corpses, keeps living colony intact.
func _nuke(cx: int, cy: int) -> void:
	var ck = sim.spatial._ck(cx, cy)
	if not sim.chunks.has(ck):
		return
	var tiles: PackedByteArray = sim.chunks[ck].tiles
	var base: PackedByteArray = sim.chunks[ck].base
	for i in tiles.size():
		var tile = int(tiles[i])
		if tile == Catalog.TILE_GOO or tile == Catalog.TILE_RUBBLE or tile == Catalog.TILE_MOUNTAIN:
			var restore = int(base[i])
			if restore == Catalog.TILE_GOO or restore == Catalog.TILE_RUBBLE or restore == Catalog.TILE_MOUNTAIN:
				restore = Catalog.TILE_DIRT
			tiles[i] = restore
			base[i] = restore
	for feat in sim.features:
		if feat.dead:
			continue
		if int(feat.cx) == cx and int(feat.cy) == cy and int(feat.kind) != Catalog.FEAT_MONOLITH:
			sim.world_entities._kill_feature(feat)
	for it in sim.items:
		if it.dead or it.held:
			continue
		var ic = sim.spatial._chunk_at(float(it.x), float(it.y))
		if ic.x == cx and ic.y == cy and int(it.kind) != Catalog.ITEM_TNT:
			it.dead = true
	for i in sim.slot_count:
		if sim.state[i] != Catalog.ST_DEAD:
			continue
		var cc = sim.spatial._chunk_at(sim.pos_x[i], sim.pos_y[i])
		if cc.x == cx and cc.y == cy:
			sim.world_entities._vacate(i)
	sim.goo_count = sim.world_entities._count_goo()
	sim.spatial._mark_dirty(ck)
	var mid = float(cx * Catalog.CHUNK + Catalog.CHUNK / 2) * float(Catalog.TILE)
	sim.dialogue._pop(mid, float(cy * Catalog.CHUNK + Catalog.CHUNK / 2) * float(Catalog.TILE), Catalog.ICON_FX_BOOM)
	sim.notes.append("EL SECTOR QUEDA LIMPIO. LA COLONIA SIGUE.")
	sim.sfx_queue.append("nuke")
	sim.sfx_queue.append("nuked")



## Violent area kill that marks corpses bloody and may trigger tool ethics reflection.
func _splash_kill(x: float, y: float, radius: float) -> void:
	var ids = sim.spatial.query_radius(x, y, radius)
	var any = false
	for id in ids:
		if sim.state[int(id)] == Catalog.ST_LIVING:
			sim.world_entities._become_corpse(int(id), true)
			any = true
	if any:
		sim.sfx_queue.append("bones")
		sim.dialogue._reflect("tool")



## Resolves chop target: trunk under feet, cosmetic canopy, or tallest blocking tree crown.
func _axe_feature_at(x: float, y: float) -> Dictionary:
	var feat = sim.world_entities._feature_at(x, y, 14.0)
	var kind = int(feat.get("kind", -1))
	if kind == Catalog.FEAT_TREE or kind == Catalog.FEAT_COSMETIC or kind == Catalog.FEAT_COSMETIC_BAD:
		return feat
	var canopy = sim.dialogue._canopy_feature_at(x, y)
	if not canopy.is_empty():
		return canopy
	return feat



## Editor-style placement of trees, rocks, water, grass, thronglets, or flower building in sandbox.
func sandbox_place_prop(prop: String, x: float, y: float) -> bool:
	if not sim.sandbox_mode or sim.frozen:
		return false
	var at = Catalog.snap_world(x, y)
	if not sim.revealed.has(sim.spatial._ck_of(at.x, at.y)):
		return false
	match prop:
		"tree":
			if Catalog.tile_blocks(sim.collision._tile_at(at.x, at.y)):
				return false
			return not sim.world_entities._add_feature(Catalog.FEAT_TREE, at.x, at.y, 1, 0, true).is_empty()
		"rock":
			if Catalog.tile_blocks(sim.collision._tile_at(at.x, at.y)):
				return false
			return not sim.world_entities._add_feature(Catalog.FEAT_ROCK, at.x, at.y, 1, 0, true).is_empty()
		"ore":
			if Catalog.tile_blocks(sim.collision._tile_at(at.x, at.y)):
				return false
			return not sim.world_entities._add_feature(Catalog.FEAT_ROCK, at.x, at.y, 2, 1, true).is_empty()
		"flower":
			return place_building(Catalog.BLD_FLOWER, at.x, at.y)
		"water":
			var cell = sim.spatial._cell_vec(at.x, at.y)
			var tile = sim.collision._tile_at_cell(cell)
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_FOG:
				return false
			sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_WATER, true)
			var feat = sim.world_entities._feature_at(at.x, at.y, 8.0)
			if not feat.is_empty():
				sim.world_entities._kill_feature(feat)
			return true
		"grass":
			var cell = sim.spatial._cell_vec(at.x, at.y)
			var tile = sim.collision._tile_at_cell(cell)
			if tile == Catalog.TILE_VOID or tile == Catalog.TILE_FOG:
				return false
			sim.collision._set_world_cell(cell.x, cell.y, Catalog.TILE_GRASS, true)
			return true
		"thronglet":
			if Catalog.tile_blocks(sim.collision._tile_at(at.x, at.y)):
				return false
			var tint = randi() % Catalog.TINTS.size()
			return sim.world_entities._push_slot(at.x, at.y, 90.0, 90.0, 90.0, 8.0, tint) >= 0
		_:
			return false



