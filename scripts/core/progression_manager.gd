class_name ProgressionManager


static func condition_met(sim, cond: Dictionary) -> bool:
	var t: int = int(cond.get("type", -1))
	if t == ProgressionCatalog.ConditionType.POPULATION:
		return sim.living >= int(cond.get("min", 0))
	if t == ProgressionCatalog.ConditionType.GEMS_EARNED:
		return sim.total_gems_earned >= int(cond.get("total", 0))
	if t == ProgressionCatalog.ConditionType.METRIC_THRESHOLD:
		var metric := str(cond.get("metric", ""))
		var want := float(cond.get("min", 0.0))
		return metric_value(sim, metric) >= want
	if t == ProgressionCatalog.ConditionType.UNLOCKED:
		return bool(sim.unlocks.get(str(cond.get("itemId", "")), false))
	return false

static func metric_value(sim, metric: String) -> float:
	if metric == "pollution":
		return pollution_percent(sim)
	if metric == "deaths":
		return float(sim.deaths_total)
	if metric == "trees_cut":
		return float(sim.trees_chopped)
	return 0.0

static func pollution_percent(sim) -> float:
	# Pollution as percentage of walkable/known land cells covered by goo, scaled for thresholds.
	# Spec: mop unlock at pollution >= 25 (%). Use goo_count vs a reasonable baseline.
	var base := float(maxi(1, sim._walk_cells()))
	var goo := float(sim.goo_count)
	return clampf((goo / base) * 100.0, 0.0, 100.0)

static func can_unlock(sim, id: String) -> bool:
	if bool(sim.unlocks.get(id, false)):
		return false
	var e := ProgressionCatalog.by_id(id)
	if e.is_empty():
		return false
	var conds: Array = e.get("unlockConditions", [])
	for c in conds:
		if not condition_met(sim, c):
			return false
	return true

static func effective_tool_unlock(sim, id: String) -> bool:
	# A tool is available if unlocked and not superseded by an unlocked replacement.
	if not bool(sim.unlocks.get(id, false)):
		return false
	return not replaced_by_unlocked(sim, id)

static func replaced_by_unlocked(sim, id: String) -> bool:
	for e in ProgressionCatalog.CATALOG:
		if str(e.get("replaces", "")) == id and bool(sim.unlocks.get(str(e.id), false)):
			return true
	return false

static func replacement_for(sim, id: String) -> String:
	for e in ProgressionCatalog.CATALOG:
		if str(e.get("replaces", "")) == id:
			return str(e.id)
	return ""

static func building_count(sim, build_kind: int) -> int:
	var n := 0
	for b in sim.buildings:
		if not b.dead and int(b.kind) == build_kind:
			n += 1
	return n

static func build_kind_for_id(id: String) -> int:
	match id:
		"bathtub": return Catalog.BLD_TUB
		"apple_tree": return Catalog.BLD_APPLE
		"roundabout": return Catalog.BLD_ROUND
		"mine": return Catalog.BLD_MINE
		"dwelling": return Catalog.BLD_DWELL
		"factory": return Catalog.BLD_FACTORY
		"theatre": return Catalog.BLD_THEATRE
		"factory2": return Catalog.BLD_FACTORY2
		"mine2": return Catalog.BLD_MINE2
		"fancy": return Catalog.BLD_FANCY
	return -1

static func scaled_cost(sim, id: String) -> int:
	var e := ProgressionCatalog.by_id(id)
	if e.is_empty():
		return 0
	var base := int(e.get("baseGemCost", 0))
	var mult := float(e.get("costMultiplier", 1.0))
	if mult <= 1.0 or str(e.get("category", "")) != "building":
		return base
	var kind := build_kind_for_id(id)
	if kind < 0:
		return base
	var count := building_count(sim, kind)
	return int(round(float(base) * pow(mult, float(count))))

static func evaluate_unlocks(sim, announce: bool = true) -> Array[String]:
	var granted: Array[String] = []
	var changed := true
	while changed:
		changed = false
		for e in ProgressionCatalog.CATALOG:
			var id := str(e.id)
			if can_unlock(sim, id):
				sim.unlocks[id] = true
				sim.unlock_serial += 1
				granted.append(id)
				changed = true
				if announce:
					_on_granted(sim, id)
	return granted


static func apply_progression_hooks(sim, announce: bool = true) -> void:
	# Narrative/world side effects not modeled in the progression catalog.
	# Tutorial gate: axe unlocks once the colony has reached 6 (peak), even if pop later drops.
	if sim.peak >= 6 and not bool(sim.unlocks.get("axe", false)):
		sim._grant("axe", "", announce)
	if sim.peak >= 25:
		sim._ensure_monolith(1)
	if sim._has_building(Catalog.BLD_ROUND) and sim.peak >= 12 and not sim.part_two:
		sim._expand_super_island(announce)
	if announce and sim.peak >= 12 and sim._ethics_choice("what_is_care") == -1 and sim.living >= 3:
		sim._queue_talk("what_is_care", {})
	elif announce and sim.peak >= 8 and sim.living >= 2:
		sim._queue_ambient_talk()

	sim._check_milestones(announce)

static func _on_granted(sim, id: String) -> void:
	sim.sfx_queue.append("unlock_" + id)
	if Catalog.UNLOCK_TALK.has(id):
		sim._queue_talk(str(Catalog.UNLOCK_TALK[id]), {})
	elif ProgressionCatalog.by_id(id).has("name"):
		sim.notes.append("DESBLOQUEADO: " + str(ProgressionCatalog.by_id(id).name))
	# Auto-upgrade: when a replacement tool unlocks, ensure active selection moves if needed handled in UI.

static func tool_area_radius(id: String) -> int:
	var e := ProgressionCatalog.by_id(id)
	if e.is_empty():
		return 0
	return int(e.get("areaRadius", 0))
