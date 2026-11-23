extends Node

# Load the player's live save and measure real-path FPS (full Main._process).
# CLI: godot --path . -- --save-perf [--save-slot=0] [--perf-seconds=3]

const DEFAULT_SECONDS := 3.0
const WARMUP_SECONDS := 1.5

var main = null
var slot := 0
var sample_seconds := DEFAULT_SECONDS
var phase := "boot"
var phase_t := 0.0
var zoom_cases: Array = []
var case_i := 0
var samples: PackedFloat32Array = PackedFloat32Array()
var frame_ms_samples: PackedFloat32Array = PackedFloat32Array()
var sync_ms_samples: PackedFloat32Array = PackedFloat32Array()
var world_ms_samples: PackedFloat32Array = PackedFloat32Array()
var step_ms_samples: PackedFloat32Array = PackedFloat32Array()
var results: Array = []
var loaded := false
var last_usec := 0
var done := false
var focus := Vector2(256, 256)


func setup(host) -> void:
	main = host
	var args := OS.get_cmdline_user_args()
	slot = int(_arg(args, "--save-slot", "0"))
	sample_seconds = float(_arg(args, "--perf-seconds", str(DEFAULT_SECONDS)))
	zoom_cases = [
		{"name": "zoom_mid", "zoom": 2.0},
		{"name": "zoom_out", "zoom": 0.55},
		{"name": "zoom_in", "zoom": 3.5},
	]
	last_usec = Time.get_ticks_usec()
	print("SAVE PERF start slot=%s seconds=%s" % [slot, sample_seconds])


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var prefix := key + "="
	for raw in args:
		var a := str(raw)
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func tick(delta: float) -> void:
	if done or main == null:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - last_usec) * 0.001
	last_usec = now
	var sync_ms := float(main.get_meta("save_perf_sync_ms", 0.0))
	var world_ms := float(main.get_meta("save_perf_world_ms", 0.0))
	var step_ms := float(main.get_meta("save_perf_step_ms", 0.0))
	match phase:
		"boot":
			_boot()
		"warmup":
			phase_t += delta
			if phase_t >= WARMUP_SECONDS:
				_begin_case(0)
		"sample":
			if phase_t >= 0.5:
				samples.append(float(Engine.get_frames_per_second()))
				frame_ms_samples.append(frame_ms)
				sync_ms_samples.append(sync_ms)
				world_ms_samples.append(world_ms)
				step_ms_samples.append(step_ms)
			phase_t += delta
			if phase_t >= sample_seconds:
				_finish_case()
		"quit":
			_quit()


func _boot() -> void:
	var sim = ThrongletSimServer
	if sim == null or main.cam_rig == null:
		return
	if not loaded:
		sim.paused = false
		sim.frozen = false
		sim.smoke_hold = false
		sim.modal = {}
		main.in_title = false
		if main.title_root != null:
			main.title_root.visible = false
		if main.ui != null:
			main.ui.visible = true
		main.show_fps = true
		main._apply_show_fps()
		if not sim.save_system.load_slot(slot):
			push_error("SAVE PERF failed to load slot %s path=%s" % [slot, sim.save_system.slot_path(slot)])
			done = true
			get_tree().quit(2)
			return
		sim.session_live = true
		sim.testing = true
		# Avoid writing over the player's save while measuring.
		sim.autosave_interval = 0.0
		main.seen_epoch = -1
		main._feat_static_epoch = -1
		main._clear_feat_static()
		focus = _living_focus(sim)
		main.cam_rig.set_zoom(2.0)
		main.cam_rig.focus_world(focus)
		# Reveal whatever the current view covers, same as normal play.
		sim.explore_rect(main.cam_rig.world_view().grow(8.0))
		loaded = true
		var n_hungry := 0
		var n_dirty := 0
		var n_bored := 0
		var n_ready := 0
		var n_carry := 0
		var n_mito := 0
		for i in sim.slot_count:
			if sim.state[i] != Catalog.ST_LIVING:
				continue
			if sim.fed[i] < Catalog.NEED_HUNGRY:
				n_hungry += 1
			if sim.clean[i] < Catalog.NEED_SEEK:
				n_dirty += 1
			if sim.amused[i] < Catalog.NEED_FUN:
				n_bored += 1
			if sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK:
				n_ready += 1
			if sim.carry[i] != Catalog.CARRY_NONE:
				n_carry += 1
			if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
				n_mito += 1
		var n_fact := 0
		for b in sim.buildings:
			if b.dead:
				continue
			var k := int(b.kind)
			if k == Catalog.BLD_FACTORY or k == Catalog.BLD_FACTORY2:
				n_fact += 1
		print(
			"SAVE PERF loaded living=%s peak=%s features=%s items=%s buildings=%s revealed=%s chunks=%s hungry=%s dirty=%s bored=%s ready=%s carry=%s mito=%s fact=%s mine=%s tub=%s round=%s home=%s"
			% [
				sim.living, sim.peak, sim.features.size(), sim.items.size(), sim.buildings.size(),
				sim.revealed.size(), sim.chunks.size(),
				n_hungry, n_dirty, n_bored, n_ready, n_carry, n_mito,
				n_fact, sim.blds_mine.size(), sim.blds_tub.size(), sim.blds_round.size(), sim.blds_home.size()
			]
		)
	phase = "warmup"
	phase_t = 0.0


func _living_focus(sim) -> Vector2:
	if sim.living <= 0 or sim.pos_x.is_empty():
		return Vector2(256, 256)
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_VACANT or sim.state[i] == Catalog.ST_DEAD:
			continue
		sx += sim.pos_x[i]
		sy += sim.pos_y[i]
		n += 1
		if n >= 64:
			break
	if n <= 0:
		return Vector2(256, 256)
	return Vector2(sx / float(n), sy / float(n))


func _begin_case(index: int) -> void:
	case_i = index
	if case_i >= zoom_cases.size():
		phase = "quit"
		return
	var row: Dictionary = zoom_cases[case_i]
	main.cam_rig.set_zoom(float(row.zoom))
	main.cam_rig.focus_world(focus)
	samples = PackedFloat32Array()
	frame_ms_samples = PackedFloat32Array()
	sync_ms_samples = PackedFloat32Array()
	world_ms_samples = PackedFloat32Array()
	step_ms_samples = PackedFloat32Array()
	phase = "sample"
	phase_t = 0.0
	print("SAVE PERF case %s zoom=%s" % [row.name, row.zoom])


func _finish_case() -> void:
	var row: Dictionary = zoom_cases[case_i]
	var entry := {
		"name": str(row.name),
		"zoom": float(row.zoom),
		"fps_avg": float(_stats(samples).avg),
		"fps_min": float(_stats(samples).minv),
		"frame_ms": float(_stats(frame_ms_samples).avg),
		"sync_ms": float(_stats(sync_ms_samples).avg),
		"world_ms": float(_stats(world_ms_samples).avg),
		"step_ms": float(_stats(step_ms_samples).avg),
	}
	results.append(entry)
	print(
		"SAVE PERF result %s fps_avg=%.1f fps_min=%.1f frame_ms=%.2f sync_ms=%.2f world_ms=%.2f step_ms=%.2f"
		% [entry.name, entry.fps_avg, entry.fps_min, entry.frame_ms, entry.sync_ms, entry.world_ms, entry.step_ms]
	)
	_begin_case(case_i + 1)


func _stats(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "minv": 0.0, "maxv": 0.0}
	var sum := 0.0
	var minv := values[0]
	var maxv := values[0]
	for v in values:
		sum += v
		minv = minf(minv, v)
		maxv = maxf(maxv, v)
	return {"avg": sum / float(values.size()), "minv": minv, "maxv": maxv}


func _quit() -> void:
	done = true
	print("SAVE PERF done cases=%s" % results.size())
	get_tree().quit(0)
