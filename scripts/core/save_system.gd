extends RefCounted
class_name SaveSystem

const SLOT_COUNT := 4
const LIVE_SLOT := 0
const SANDBOX_PATH := "user://thronglets_sandbox.save"

var _sim


func _init(sim) -> void:
	_sim = sim


func slot_path(index: int) -> String:
	return "user://thronglets_slot_%d.save" % index


func sandbox_path() -> String:
	return SANDBOX_PATH


func read_meta() -> Dictionary:
	if not FileAccess.file_exists("user://thronglets_slots.meta"):
		return {}
	var file := FileAccess.open("user://thronglets_slots.meta", FileAccess.READ)
	if file == null:
		return {}
	var data = file.get_var(true)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data


func write_meta(meta: Dictionary) -> void:
	var file := FileAccess.open("user://thronglets_slots.meta", FileAccess.WRITE)
	if file != null:
		file.store_var(meta, true)


func last_slot() -> int:
	var meta := read_meta()
	return int(meta.get("last", -1))


func clear_sandbox_save() -> void:
	var dir := DirAccess.open("user://")
	var path := sandbox_path()
	if dir != null and FileAccess.file_exists(path):
		dir.remove(path.get_file())


func clear_saves() -> void:
	var sim = _sim
	var dir := DirAccess.open("user://")
	for i in SLOT_COUNT:
		var path := slot_path(i)
		if dir != null and FileAccess.file_exists(path):
			dir.remove(path.get_file())
	write_meta({})
	sim.current_slot = -1
	sim.session_live = false
	sim.game_over = false


func clear_all_progress() -> void:
	clear_saves()
	clear_sandbox_save()


func has_sandbox_save() -> bool:
	return FileAccess.file_exists(sandbox_path())


func load_sandbox() -> bool:
	var sim = _sim
	if not has_sandbox_save():
		return false
	sim.save_path = sandbox_path()
	if not load_game():
		return false
	sim.current_slot = -1
	sim.sandbox_mode = true
	sim.unlock_serial += 1
	return true


func save_slot(index: int) -> bool:
	var sim = _sim
	if index < 0 or index >= SLOT_COUNT:
		return false
	sim.current_slot = index
	sim.save_path = slot_path(index)
	if not save_game():
		return false
	var meta := read_meta()
	meta["last"] = index
	meta[str(index)] = {"living": sim.living, "peak": sim.peak, "t": Time.get_unix_time_from_system()}
	write_meta(meta)
	sim.autosave_t = 0.0
	return true


func save_progress() -> bool:
	var sim = _sim
	# Sandbox keeps its own file so campaign slots / autosave history stay intact.
	if bool(sim.sandbox_mode):
		sim.current_slot = -1
		sim.save_path = sandbox_path()
		var ok := save_game()
		sim.autosave_t = 0.0
		return ok
	return save_slot(LIVE_SLOT)


func tick_autosave(delta: float) -> void:
	var sim = _sim
	if sim.testing or sim.game_over or not sim.session_live or sim.autosave_interval <= 0.0:
		return
	sim.autosave_t += delta
	if sim.autosave_t < sim.autosave_interval:
		return
	sim.autosave_t = 0.0
	if bool(sim.sandbox_mode):
		save_progress()
		return
	rotate_autosave_history()
	save_progress()


func rotate_autosave_history() -> void:
	var sim = _sim
	if not FileAccess.file_exists(slot_path(LIVE_SLOT)):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var meta := read_meta()
	for i in range(SLOT_COUNT - 1, LIVE_SLOT, -1):
		var src := slot_path(i - 1)
		var dst := slot_path(i)
		if FileAccess.file_exists(dst):
			dir.remove(dst.get_file())
		if FileAccess.file_exists(src):
			dir.rename(src.get_file(), dst.get_file())
		if meta.has(str(i - 1)):
			meta[str(i)] = meta[str(i - 1)]
		else:
			meta.erase(str(i))
	meta.erase(str(LIVE_SLOT))
	write_meta(meta)


func list_checkpoints() -> Array:
	var meta := read_meta()
	var out: Array = []
	for i in SLOT_COUNT:
		if not FileAccess.file_exists(slot_path(i)):
			continue
		var row: Dictionary = meta.get(str(i), {})
		out.append({
			"i": i,
			"living": int(row.get("living", 0)),
			"peak": int(row.get("peak", 0)),
			"t": float(row.get("t", 0.0)),
		})
	return out


func has_checkpoint() -> bool:
	return list_checkpoints().size() > 0


func load_checkpoint() -> bool:
	var rows := list_checkpoints()
	if rows.is_empty():
		return false
	return load_slot(int(rows[0].i))


func load_slot(index: int) -> bool:
	var sim = _sim
	if index < 0 or index >= SLOT_COUNT:
		return false
	sim.save_path = slot_path(index)
	if not load_game():
		return false
	sim.current_slot = index
	var meta := read_meta()
	meta["last"] = index
	write_meta(meta)
	sim.unlock_serial += 1
	return true


func resume_last() -> bool:
	if _sim.session_live:
		return true
	var last := last_slot()
	if last < 0:
		return false
	return load_slot(last)


func save_game() -> bool:
	var sim = _sim
	sim.cancel_hold()
	var gazing: bool = sim.frozen and not sim.gaze_home.is_empty()
	sim._restore_gaze()
	sim._compact(sim.items)
	sim._compact(sim.features)
	sim._compact(sim.buildings)
	var data := {
		"v": 1,
		"seed": sim.world_seed,
		"peak": sim.peak,
		"gems": sim.gems,
		"gems_peak": sim.gems_peak,
		"total_gems_earned": sim.total_gems_earned,
		"deaths_total": sim.deaths_total,
		"land_tier": sim.land_tier,
		"sandbox_mode": sim.sandbox_mode,
		"glitch_seen": sim.glitch_seen,
		"unlocks": sim.unlocks.duplicate(true),
		"ethics": sim.ethics.duplicate(true),
		"moral": sim.moral,
		"mutations": sim.mutations.duplicate(true),
		"talked_trees": sim.talked_trees.duplicate(true),
		"learn_talked": sim.learn_talked,
		"part_two": sim.part_two,
		"mountain_seen": sim.mountain_seen,
		"trees_chopped": sim.trees_chopped,
		"stumps_cleared": sim.stumps_cleared,
		"bug_uses": sim.bug_uses,
		"tnt_used": sim.tnt_used,
		"goo_count": sim.goo_count,
		"cap_told": sim.cap_told,
		"monoliths": sim.monolith_tier_spawned.duplicate(true),
		"pos_x": sim.pos_x,
		"pos_y": sim.pos_y,
		"dir_x": sim.dir_x,
		"dir_y": sim.dir_y,
		"fed": sim.fed,
		"amused": sim.amused,
		"clean": sim.clean,
		"cool": sim.cool,
		"starve": sim.starve,
		"hungry_t": sim.hungry_t,
		"wander_t": sim.wander_t,
		"mito_t": sim.mito_t,
		"mito_charge": sim.mito_charge,
		"shake_t": sim.shake_t,
		"buff_t": sim.buff_t,
		"react_t": sim.react_t,
		"cheer_t": sim.cheer_t,
		"sleep_t": sim.sleep_t,
		"peer_t": sim.peer_t,
		"peer_of": sim.peer_of,
		"peer_sing": sim.peer_sing,
		"drop_t": sim.drop_t,
		"rotund_t": sim.rotund_t,
		"state": sim.state,
		"carry": sim.carry,
		"carry_value": sim.carry_value,
		"tint": sim.tint,
		"claim": sim.claim,
		"act": sim.act,
		"act_t": sim.act_t,
		"items": sim.items.duplicate(true),
		"buildings": sim.buildings.duplicate(true),
		"features": sim.features.duplicate(true),
		"tree_seeds": sim.tree_seeds.duplicate(true),
		"chunks": sim.chunks.duplicate(true),
		"wear": sim.wear.duplicate(),
		"revealed": sim.revealed.duplicate(true),
		"player_name": sim.player_name,
		"tutorial_i": sim.tutorial_i,
		"count_unknown": sim.count_unknown,
	}
	var file := FileAccess.open(sim.save_path, FileAccess.WRITE)
	if file == null:
		sim.notes.append("NO SE PUDO GUARDAR.")
		if gazing:
			sim._line_up_gaze()
		return false
	file.store_var(data, true)
	sim.save_pulse += 1
	if gazing:
		sim._line_up_gaze()
	return true


func load_game() -> bool:
	var sim = _sim
	if not FileAccess.file_exists(sim.save_path):
		sim.notes.append("NO HAY PARTIDA.")
		return false
	var file := FileAccess.open(sim.save_path, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var(true)
	if typeof(data) != TYPE_DICTIONARY or int(data.get("v", 0)) != 1 or not data.has("pos_x"):
		sim.notes.append("PARTIDA ILEGIBLE.")
		return false
	sim._reset_world()
	sim.world_seed = int(data.get("seed", 1))
	sim.peak = int(data.get("peak", 0))
	sim.gems = int(data.get("gems", 0))
	sim.gems_peak = maxi(int(data.get("gems_peak", sim.gems)), sim.gems)
	sim.total_gems_earned = maxi(int(data.get("total_gems_earned", sim.gems_peak)), sim.gems_peak)
	sim.deaths_total = int(data.get("deaths_total", 0))
	sim.land_tier = int(data.get("land_tier", 0))
	sim.sandbox_mode = bool(data.get("sandbox_mode", false))
	sim.unlocks = data.get("unlocks", sim.unlocks)
	sim.glitch_seen = bool(data.get("glitch_seen", false))
	sim.ethics = data.get("ethics", [])
	sim.moral = int(data.get("moral", 0))
	sim.mutations = data.get("mutations", {})
	if typeof(sim.mutations) != TYPE_DICTIONARY:
		sim.mutations = {}
	sim.talked_trees = data.get("talked_trees", {})
	if typeof(sim.talked_trees) != TYPE_DICTIONARY:
		sim.talked_trees = {}
	sim.learn_talked = bool(data.get("learn_talked", false))
	sim.part_two = bool(data.get("part_two", false))
	sim.mountain_seen = bool(data.get("mountain_seen", false))
	sim.trees_chopped = int(data.get("trees_chopped", 0))
	sim.stumps_cleared = int(data.get("stumps_cleared", 0))
	sim.bug_uses = int(data.get("bug_uses", 0))
	sim.tnt_used = int(data.get("tnt_used", 0))
	sim.goo_count = int(data.get("goo_count", 0))
	sim.cap_told = bool(data.get("cap_told", false))
	sim.monolith_tier_spawned = data.get("monoliths", {})
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim.pos_x = sim._as_f32(data.pos_x)
	sim.pos_y = sim._as_f32(data.pos_y)
	sim.dir_x = sim._as_f32(data.dir_x)
	sim.dir_y = sim._as_f32(data.dir_y)
	sim.fed = sim._as_f32(data.fed)
	sim.amused = sim._as_f32(data.amused)
	sim.clean = sim._as_f32(data.clean)
	sim.cool = sim._as_f32(data.cool)
	sim.starve = sim._as_f32(data.starve)
	sim.hungry_t = sim._as_f32(data.get("hungry_t", []))
	sim.wander_t = sim._as_f32(data.wander_t)
	sim.mito_t = sim._as_f32(data.mito_t)
	sim.mito_charge = sim._as_f32(data.get("mito_charge", []))
	sim.shake_t = sim._as_f32(data.shake_t)
	sim.buff_t = sim._as_f32(data.buff_t)
	sim.react_t = sim._as_f32(data.get("react_t", []))
	sim.cheer_t = sim._as_f32(data.get("cheer_t", []))
	sim.sleep_t = sim._as_f32(data.get("sleep_t", []))
	sim.peer_t = sim._as_f32(data.get("peer_t", []))
	sim.peer_of = sim._as_i32(data.get("peer_of", []))
	sim.peer_sing = PackedByteArray()
	for raw_sing in data.get("peer_sing", []):
		sim.peer_sing.append(int(raw_sing))
	sim.drop_t = sim._as_f32(data.get("drop_t", []))
	sim.rotund_t = sim._as_f32(data.get("rotund_t", []))
	sim.state = sim._as_i32(data.state)
	sim.carry = sim._as_i32(data.carry)
	sim.carry_value = sim._as_i32(data.carry_value)
	sim.tint = sim._as_i32(data.tint)
	sim.claim = sim._as_i32(data.claim)
	sim.slot_count = sim.pos_x.size()
	sim.mine_job = PackedInt32Array()
	sim.mine_job.resize(sim.slot_count)
	sim.mine_job.fill(-1)
	sim.act = sim._as_i32(data.get("act", []))
	sim.act_t = sim._as_f32(data.get("act_t", []))
	while sim.act.size() < sim.slot_count:
		sim.act.append(0)
	while sim.act_t.size() < sim.slot_count:
		sim.act_t.append(0.0)
	while sim.avoid_t.size() < sim.slot_count:
		sim.avoid_t.append(0.0)
	while sim.mito_charge.size() < sim.slot_count:
		sim.mito_charge.append(0.0)
	while sim.hungry_t.size() < sim.slot_count:
		sim.hungry_t.append(0.0)
	while sim.react_t.size() < sim.slot_count:
		sim.react_t.append(0.0)
	while sim.cheer_t.size() < sim.slot_count:
		sim.cheer_t.append(0.0)
	while sim.sleep_t.size() < sim.slot_count:
		sim.sleep_t.append(0.0)
	while sim.peer_t.size() < sim.slot_count:
		sim.peer_t.append(0.0)
	while sim.peer_of.size() < sim.slot_count:
		sim.peer_of.append(-1)
	if sim.peer_sing.size() != sim.slot_count:
		var old_sing: PackedByteArray = sim.peer_sing
		sim.peer_sing = PackedByteArray()
		sim.peer_sing.resize(sim.slot_count)
		sim.peer_sing.fill(0)
		for s in mini(old_sing.size(), sim.slot_count):
			sim.peer_sing[s] = int(old_sing[s])
	while sim.drop_t.size() < sim.slot_count:
		sim.drop_t.append(0.0)
	while sim.rotund_t.size() < sim.slot_count:
		sim.rotund_t.append(0.0)
	sim.penned_flag = PackedByteArray()
	sim.penned_flag.resize(sim.slot_count)
	sim.penned_flag.fill(0)
	sim.items = data.get("items", [])
	sim.buildings = data.get("buildings", [])
	sim.features = data.get("features", [])
	sim.tree_seeds = data.get("tree_seeds", [])
	sim.chunks = data.get("chunks", {})
	sim.wear = data.get("wear", {})
	if typeof(sim.wear) != TYPE_DICTIONARY:
		sim.wear = {}
	sim.wear_from.clear()
	sim.revealed = data.get("revealed", {})
	sim.player_name = str(data.get("player_name", ""))
	sim.tutorial_i = int(data.get("tutorial_i", -1))
	sim.count_unknown = bool(data.get("count_unknown", false))
	sim._recount()
	sim._reindex()
	sim._refresh_pop_gates(false)
	sim._shape_island()
	sim._seed_mine_nodes(0, 0)
	sim._rebuild_hash()
	sim.paint_epoch += 1
	sim.dirty_chunks.clear()
	for key in sim.revealed.keys():
		sim.dirty_chunks.append(str(key))
	sim.frozen = false
	sim.game_over = false
	sim.paused = false
	sim.modal = {}
	sim.hand_id = -1
	sim._clear_held()
	sim.sponge_id = -1
	sim.sponge_hold = 0.0
	sim.notes.append("PARTIDA CARGADA.")
	sim.session_live = true
	if sim.living <= 0 and sim.peak > 0:
		sim._enter_game_over()
	return true
