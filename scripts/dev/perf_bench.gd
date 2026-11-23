extends Node

# Automated thronglet performance harness.
# Driven by CLI: godot --path . -- --perf [--perf-count=50] [--perf-seconds=4] [--perf-busy]

const DEFAULT_COUNT := 50
const DEFAULT_SECONDS := 4.0
const WARMUP_SECONDS := 1.0
const REPORT_PATH := "res://shots/perf_report.json"

var main = null
var count := DEFAULT_COUNT
var sample_seconds := DEFAULT_SECONDS
var out_path := REPORT_PATH
var busy := false
var busy_scale := 1
var busy_stats := {}
var phase := "boot"
var phase_t := 0.0
var zoom_cases: Array = []
var case_i := 0
var samples: PackedFloat32Array = PackedFloat32Array()
var frame_ms_samples: PackedFloat32Array = PackedFloat32Array()
var sync_ms_samples: PackedFloat32Array = PackedFloat32Array()
var results: Array = []
var spawned := false
var last_usec := 0
var done := false


func setup(host) -> void:
	main = host
	var args := OS.get_cmdline_user_args()
	count = int(_arg(args, "--perf-count", str(DEFAULT_COUNT)))
	sample_seconds = float(_arg(args, "--perf-seconds", str(DEFAULT_SECONDS)))
	out_path = str(_arg(args, "--perf-out", REPORT_PATH))
	busy = args.has("--perf-busy")
	busy_scale = maxi(1, int(_arg(args, "--perf-busy-scale", "1")))
	# V-Sync caps FPS to the display refresh; disable so high-count pass thresholds are reachable.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	zoom_cases = [
		{"name": "zoom_mid", "zoom": 2.0},
		{"name": "zoom_out", "zoom": 0.55},
		{"name": "zoom_in", "zoom": 3.5},
	]
	last_usec = Time.get_ticks_usec()
	print("PERF BENCH start count=%s seconds=%s busy=%s scale=%s" % [count, sample_seconds, busy, busy_scale])


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
	var sync_ms := float(main.get_meta("perf_sync_ms", 0.0))
	match phase:
		"boot":
			_boot()
		"warmup":
			phase_t += delta
			if phase_t >= WARMUP_SECONDS:
				_begin_case(0)
		"sample":
			# Skip the first half-second so zoom/camera settle does not poison fps_min.
			if phase_t >= 0.5:
				samples.append(float(Engine.get_frames_per_second()))
				frame_ms_samples.append(frame_ms)
				sync_ms_samples.append(sync_ms)
			phase_t += delta
			if phase_t >= sample_seconds:
				_finish_case()
		"write":
			_write_report()
			phase = "quit"
		"quit":
			_quit()


func _boot() -> void:
	var sim = ThrongletSimServer
	if sim == null or main.cam_rig == null:
		return
	if not spawned:
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
		main.cam_rig.set_zoom(2.0)
		main.cam_rig.focus_world(Vector2(256, 256))
		if busy:
			busy_stats = sim.debug_perf_busy(Vector2(256, 256), busy_scale)
			# Force path/world sprites to rebuild for the stamped wear cells.
			main.seen_epoch = -1
		sim.debug_spawn(count, Vector2(256, 256))
		spawned = true
		print("PERF BENCH spawned living=%s features=%s items=%s buildings=%s busy=%s" % [
			sim.living, sim.features.size(), sim.items.size(), sim.buildings.size(), busy_stats
		])
	phase = "warmup"
	phase_t = 0.0


func _begin_case(index: int) -> void:
	case_i = index
	if case_i >= zoom_cases.size():
		phase = "write"
		return
	var row: Dictionary = zoom_cases[case_i]
	main.cam_rig.set_zoom(float(row.zoom))
	main.cam_rig.focus_world(Vector2(256, 256))
	samples = PackedFloat32Array()
	frame_ms_samples = PackedFloat32Array()
	sync_ms_samples = PackedFloat32Array()
	phase = "sample"
	phase_t = 0.0
	print("PERF BENCH case %s zoom=%s" % [row.name, row.zoom])


func _finish_case() -> void:
	var row: Dictionary = zoom_cases[case_i]
	var stats := _stats(samples)
	var frame_stats := _stats(frame_ms_samples)
	var sync_stats := _stats(sync_ms_samples)
	var entry := {
		"name": str(row.name),
		"zoom": float(row.zoom),
		"living": int(ThrongletSimServer.living),
		"fps_avg": float(stats.avg),
		"fps_min": float(stats.minv),
		"fps_p1": float(stats.p1),
		"frame_ms_avg": float(frame_stats.avg),
		"frame_ms_max": float(frame_stats.maxv),
		"sync_ms_avg": float(sync_stats.avg),
		"sync_ms_max": float(sync_stats.maxv),
		"samples": samples.size(),
	}
	results.append(entry)
	print(
		"PERF BENCH result %s fps_avg=%.1f fps_min=%.1f frame_ms=%.2f sync_ms=%.2f"
		% [entry.name, entry.fps_avg, entry.fps_min, entry.frame_ms_avg, entry.sync_ms_avg]
	)
	_begin_case(case_i + 1)


func _stats(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "minv": 0.0, "maxv": 0.0, "p1": 0.0}
	var sum := 0.0
	var minv := values[0]
	var maxv := values[0]
	var sorted: Array = []
	for v in values:
		sum += v
		minv = minf(minv, v)
		maxv = maxf(maxv, v)
		sorted.append(v)
	sorted.sort()
	var p1_i := clampi(int(floor(float(sorted.size()) * 0.01)), 0, sorted.size() - 1)
	return {
		"avg": sum / float(values.size()),
		"minv": minv,
		"maxv": maxv,
		"p1": float(sorted[p1_i]),
	}


func _write_report() -> void:
	var path_cells := 0
	for _k in ThrongletSimServer.wear.keys():
		if int(ThrongletSimServer.wear[_k]) >= ThrongletSimServer.WEAR_NEED:
			path_cells += 1
	var report := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"count_requested": count,
		"busy": busy,
		"busy_scale": busy_scale,
		"busy_stats": busy_stats,
		"living": int(ThrongletSimServer.living),
		"slot_count": int(ThrongletSimServer.slot_count),
		"features": ThrongletSimServer.features.size(),
		"items": ThrongletSimServer.items.size(),
		"buildings": ThrongletSimServer.buildings.size(),
		"path_cells": path_cells,
		"headless": DisplayServer.get_name() == "headless",
		"godot": Engine.get_version_info(),
		"cases": results,
		"pass": _passes(results),
	}
	var text := JSON.stringify(report, "\t")
	var abs_path := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(abs_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
		print("PERF BENCH wrote %s" % abs_path)
	else:
		push_error("PERF BENCH failed to write %s" % out_path)
	print("PERF BENCH PASS=%s" % str(report.pass))


func _passes(cases: Array) -> bool:
	# Cap target is Catalog.MAX_SLOTS (120k): hold near vsync, including zoomed out.
	var living_n := int(ThrongletSimServer.living)
	var mid_need := 100.0 if living_n >= 50000 else (70.0 if living_n >= 5000 else 55.0)
	var out_need := 100.0 if living_n >= 50000 else (60.0 if living_n >= 5000 else 45.0)
	for raw in cases:
		var c: Dictionary = raw
		if str(c.name) == "zoom_out" and float(c.fps_avg) < out_need:
			return false
		if str(c.name) == "zoom_mid" and float(c.fps_avg) < mid_need:
			return false
		# Ignore single-frame hitches; use 1st percentile when at the slot cap.
		if living_n >= 120000 and float(c.get("fps_p1", c.fps_min)) < 90.0:
			return false
	return true


func _quit() -> void:
	done = true
	var code := 0 if _passes(results) else 2
	print("PERF BENCH quit code=%s" % code)
	get_tree().quit(code)
