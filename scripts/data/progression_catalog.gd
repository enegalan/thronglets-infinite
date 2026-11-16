class_name ProgressionCatalog

# Progression catalog for infinite mode. Unlock keys align with existing Catalog/sim keys.

enum ConditionType { POPULATION, GEMS_EARNED, METRIC_THRESHOLD, UNLOCKED }

static func cond_population(min_pop: int) -> Dictionary:
	return {"type": ConditionType.POPULATION, "min": min_pop}

static func cond_gems(total: int) -> Dictionary:
	return {"type": ConditionType.GEMS_EARNED, "total": total}

static func cond_metric(metric: String, min_value: float) -> Dictionary:
	return {"type": ConditionType.METRIC_THRESHOLD, "metric": metric, "min": min_value}

static func cond_unlocked(item_id: String) -> Dictionary:
	return {"type": ConditionType.UNLOCKED, "itemId": item_id}

static func entry(id: String, name: String, category: String, unlock_conditions: Array, base_gem_cost: int, cost_multiplier: float, area_radius: int, replaces: String = "") -> Dictionary:
	var e := {
		"id": id,
		"name": name,
		"category": category,
		"unlockConditions": unlock_conditions,
		"baseGemCost": base_gem_cost,
		"costMultiplier": cost_multiplier,
		"areaRadius": area_radius,
	}
	if replaces != "":
		e["replaces"] = replaces
	return e

const CATALOG: Array = [
	# Fase 1
	entry("apple", "Manzana", "tool", [], 0, 1.0, 0),
	entry("ball", "Pelota", "tool", [], 0, 1.0, 0),
	entry("sponge", "Esponja", "tool", [], 0, 1.0, 0),
	entry("bathtub", "Bañera", "building", [cond_population(6)], 0, 1.4, 1),
	entry("apple_tree", "Manzano", "building", [cond_population(10)], 0, 1.5, 2),
	entry("roundabout", "Carrusel", "building", [cond_population(15)], 10, 1.5, 2),
	entry("hammer", "Martillo", "tool", [cond_population(20)], 0, 1.0, 0),
	entry("axe", "Hacha", "tool", [cond_population(25)], 0, 1.0, 0),
	entry("bug", "El Bug", "tool", [cond_unlocked("axe")], 0, 1.0, 0),
	# Fase 2
	entry("pickaxe", "Pico", "tool", [cond_unlocked("hammer"), cond_gems(15)], 15, 1.0, 2, "hammer"),
	entry("mine", "Mina", "building", [cond_unlocked("pickaxe")], 50, 1.6, 1),
	entry("dwelling", "Vivienda", "building", [cond_gems(200)], 200, 1.65, 2),
	entry("factory", "Fábrica", "building", [cond_gems(300)], 300, 1.7, 2),
	entry("chainsaw", "Motosierra", "tool", [cond_unlocked("axe"), cond_gems(400)], 400, 1.0, 3, "axe"),
	entry("grabber", "El Recogedor", "tool", [cond_metric("trees_cut", 12)], 150, 1.0, 3),
	entry("mop", "Fregona", "tool", [cond_metric("pollution", 25)], 250, 1.0, 3, "sponge"),
	entry("theatre", "Teatro", "building", [cond_gems(1000)], 1000, 1.75, 3),
	entry("swarm", "Enjambre", "tool", [cond_unlocked("bug"), cond_gems(2500)], 2500, 1.0, 3, "bug"),
	entry("factory2", "Fábrica Mark II", "building", [cond_gems(5000)], 5000, 1.85, 2),
	entry("mine2", "Mina Mejorada", "building", [cond_gems(120000)], 120000, 1.9, 2),
	entry("fancy", "Vivienda de Lujo", "building", [cond_gems(200000)], 200000, 1.95, 3),
]

static func by_id(id: String) -> Dictionary:
	for e in CATALOG:
		if str(e.id) == id:
			return e
	return {}

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for e in CATALOG:
		out.append(str(e.id))
	return out

static func is_repeatable_building(id: String) -> bool:
	var e := by_id(id)
	if e.is_empty():
		return false
	return str(e.get("category", "")) == "building" and float(e.get("costMultiplier", 1.0)) > 1.0
