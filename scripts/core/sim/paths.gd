class_name SimPaths
extends RefCounted

## Ground wear and path sampling.

var sim


## Stores the simulation server used for path wear.
func _init(sim_ref) -> void:
	sim = sim_ref

## Footstep wear on grass until a path forms and neighbor chunks need redraw.
func _wear_ground(i: int) -> void:
	var cell = sim.spatial._cell_vec(sim.pos_x[i], sim.pos_y[i])
	var key = "%d,%d" % [cell.x, cell.y]
	if str(sim.wear_from.get(i, "")) == key:
		return
	sim.wear_from[i] = key
	if sim.collision._tile_at(sim.pos_x[i], sim.pos_y[i]) != Catalog.TILE_GRASS:
		return
	var n = int(sim.wear.get(key, 0)) + 1
	if n > sim.WEAR_NEED:
		return
	sim.wear[key] = n
	if n == sim.WEAR_NEED:
		_mark_path(cell)



## Whether a map cell has been worn into a walked trail.
func path_at(cx: int, cy: int) -> bool:
	return int(sim.wear.get("%d,%d" % [cx, cy], 0)) >= sim.WEAR_NEED



## Dirty path cell plus cardinals so ground art can show trails.
func _mark_path(cell: Vector2i) -> void:
	var spots: Array[Vector2i] = [
		cell,
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
	]
	for spot in spots:
		sim.spatial._mark_dirty(sim.spatial._ck(sim.spatial._floor_div(spot.x, Catalog.CHUNK), sim.spatial._floor_div(spot.y, Catalog.CHUNK)))

