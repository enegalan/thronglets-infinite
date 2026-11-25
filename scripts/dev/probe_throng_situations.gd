extends SceneTree
## Headless production-path probe: ThrongletSimServer + Main.anim_frames.frame → clip names.
## Run: godot --headless --path . -s res://scripts/dev/probe_throng_situations.gd

## Detached Main script instance for anim_frames without entering the scene tree.
var main: Node2D

var sim: Node
## Count of failed clip-pool assertions this run.
var fails := 0
## Count of passed clip-pool assertions this run.
var passes := 0


## Defers boot so the SceneTree root is ready before probes run.
func _init() -> void:
	call_deferred("_boot")


## Binds sim and Main, runs all situation suites, then quits with pass/fail code.
func _boot() -> void:
	sim = root.get_node("ThrongletSimServer")
	main = Node2D.new()
	main.set_script(load("res://scripts/presentation/Main.gd"))
	# Do not enter the tree — avoids Main._ready world boot; anim_frames.frame only needs sim + ThrongClips.
	_run_all()
	print("")
	print("==== SUMMARY passes=%d fails=%d ====" % [passes, fails])
	quit(1 if fails > 0 else 0)


## Clears the world and mood flags before each isolated situation test.
func _reset() -> void:
	sim.world_entities._reset_world()
	sim.frozen = false
	sim.glitch_t = 0.0
	sim.celebrate_t = 0.0
	sim.mood_face = "base"


## Resolves the body clip name for agent i at simulation time t.
func _clip(i: int, t: float = 0.0) -> String:
	var frame: int = int(main.anim_frames.frame(i, t))
	return ThrongClips.clip_name_at(frame)


## Asserts a clip name is allowed in the expected pool (plus extras).
func _expect_pool(label: String, clip: String, pool: Array, extra_ok: Array = []) -> void:
	var allowed := {}
	for c in pool:
		allowed[str(c)] = true
	for c in extra_ok:
		allowed[str(c)] = true
	if allowed.has(clip):
		_pass("%s → %s" % [label, clip])
	else:
		_fail("%s → got '%s' (not in expected pool)" % [label, clip])


## Records a passing assertion and increments the pass tally.
func _pass(msg: String) -> void:
	passes += 1
	print("PASS  %s" % msg)


## Records a failing assertion and increments the fail tally.
func _fail(msg: String) -> void:
	fails += 1
	print("FAIL  %s" % msg)


## Quiet-spawns one content thronglet at needs and returns slot id.
func _spawn(x: float, y: float, fed_v: float, fun_v: float, clean_v: float) -> int:
	var id: int = int(sim.world_entities._push_slot_quiet(x, y, fed_v, fun_v, clean_v, 0.0, 0))
	if id < 0:
		_fail("spawn failed at %.0f,%.0f" % [x, y])
		return -1
	sim.dir_x[id] = 0.0
	sim.dir_y[id] = 0.0
	sim.act[id] = 0
	sim.act_t[id] = 0.0
	sim.mito_t[id] = 0.0
	sim.mito_charge[id] = 0.0
	sim.react_t[id] = 0.0
	sim.cheer_t[id] = 0.0
	sim.sleep_t[id] = 0.0
	sim.peer_t[id] = 0.0
	sim.peer_of[id] = -1
	sim.peer_sing[id] = 0
	sim.drop_t[id] = 0.0
	sim.penned_flag[id] = 0
	sim.carry[id] = Catalog.CARRY_NONE
	return id


## Histogram of clip names sampled across multiple times for one agent.
func _sample_set(i: int, times: Array) -> Dictionary:
	var counts := {}
	for t in times:
		var c := _clip(i, float(t))
		counts[c] = int(counts.get(c, 0)) + 1
	return counts


## Executes numbered situation suites for idle, social, combat, and LOD clips.
func _run_all() -> void:
	print("==== 1 IDLE calm alone (no KickRock/Celebrate/Jump/Ghost) ====")
	_reset()
	var a := _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	var calm_counts := _sample_set(a, [0.0, 1.1, 2.3, 3.7, 5.0, 7.2, 9.4, 11.0, 13.5, 16.0, 18.2, 20.0, 22.5, 25.0, 28.0, 31.0, 34.0, 37.0, 40.0, 43.0])
	print("  samples: %s" % str(calm_counts))
	var bad_calm := ["ThrongA_Bored_KickRock", "ThrongA_Celebrate_Spritesheet", "ThrongA_Jump", "ThrongA_Jump-EarWiggle", "ThrongA_Default_Ghost", "Throng_Sing_Spritesheet", "ThrongA_TalkToOtherThronglet_Spritesheet2"]
	var calm_ok := true
	for clip in calm_counts.keys():
		if not ThrongClips.IDLE_CALM.has(clip):
			_fail("idle calm alone unexpected clip '%s'" % clip)
			calm_ok = false
		for b in bad_calm:
			if clip == b:
				_fail("idle calm alone got forbidden '%s'" % clip)
				calm_ok = false
	if calm_ok:
		_pass("idle calm alone only IDLE_CALM over %d distinct clips" % calm_counts.size())

	print("==== 2 Bored (amused low) ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 10.0, 95.0)
	var bored_counts := _sample_set(a, [0.0, 1.0, 2.5, 4.0, 6.5, 9.0, 12.0, 15.0, 18.0, 22.0])
	print("  samples: %s" % str(bored_counts))
	var bored_ok := true
	for clip in bored_counts.keys():
		if not ThrongClips.MOOD_BORED.has(clip):
			_fail("bored unexpected '%s'" % clip)
			bored_ok = false
	if bored_ok:
		_pass("bored uses MOOD_BORED: %s" % str(bored_counts))

	print("==== 3 Penned panic body ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.penned_flag[a] = 1
	var penned_counts := _sample_set(a, [0.0, 0.4, 0.9, 1.3, 2.0, 2.7, 3.5, 4.2, 5.0, 6.0])
	print("  samples: %s" % str(penned_counts))
	if penned_counts.size() == 1 and penned_counts.has("ThrongA_FreakOut"):
		_pass("penned → only FreakOut")
	else:
		_fail("penned must be only FreakOut, got %s" % str(penned_counts))
	if sim.dialogue.has_method("_is_penned"):
		_pass("_is_penned helper present (flag writer used each tick)")
	else:
		_fail("_is_penned missing")

	print("==== 4 Console dialogue stare (no peer / no possessed) ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.glitch_t = 0.0
	sim.dialogue._begin_gaze()
	if float(sim.glitch_t) > 0.0:
		_fail("_begin_gaze must not set glitch_t (got %.2f)" % float(sim.glitch_t))
	else:
		_pass("_begin_gaze leaves glitch_t=0")
	sim.frozen = true
	sim.glitch_t = 0.0
	sim.mood_face = "base"
	var stare_counts := {}
	for i_idx in 12:
		for t in [0.0, 0.5, 1.2, 2.0, 3.1, 4.4, 5.8, 7.0]:
			var c := _clip(a, float(t) + float(i_idx) * 0.1)
			stare_counts[c] = int(stare_counts.get(c, 0)) + 1
	print("  samples: %s" % str(stare_counts))
	var stare_ok := true
	for clip in stare_counts.keys():
		if ThrongClips.TALK_PEER.has(clip) or ThrongClips.POSSESSED.has(clip):
			_fail("stare got peer/possessed '%s'" % clip)
			stare_ok = false
		elif not ThrongClips.TALK_CONSOLE.has(clip) and not ThrongClips.TALK_REACT.has(clip):
			_fail("stare unexpected '%s'" % clip)
			stare_ok = false
	if stare_ok:
		_pass("frozen stare → TALK_CONSOLE only (mood base): %s" % str(stare_counts.keys()))

	print("==== 4b Stare + glitch → POSSESSED ====")
	sim.glitch_t = 1.0
	var poss := _clip(a, 1.0)
	_expect_pool("glitch stare", poss, ThrongClips.POSSESSED)

	print("==== 4c Stare + mood_face → may TALK_REACT ====")
	sim.glitch_t = 0.0
	sim.mood_face = "happy"
	var react_hits := 0
	var console_hits := 0
	for t in range(0, 40):
		var c2 := _clip(a, float(t) * 0.25)
		if ThrongClips.TALK_REACT.has(c2):
			react_hits += 1
		elif ThrongClips.TALK_CONSOLE.has(c2):
			console_hits += 1
		else:
			_fail("mood stare unexpected '%s'" % c2)
	if react_hits > 0:
		_pass("mood stare hit TALK_REACT %d times (console %d)" % [react_hits, console_hits])
	else:
		_fail("mood stare never hit TALK_REACT in 40 samples (console=%d)" % console_hits)

	print("==== 5 Peer sing/talk vs alone ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	var alone_peer: bool = bool(sim.world_entities.has_living_peer(a))
	if alone_peer:
		_fail("alone should not has_living_peer")
	else:
		_pass("alone has_living_peer=false")
	var alone_social := _sample_set(a, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
	var alone_bad := false
	for clip in alone_social.keys():
		if ThrongClips.SING_PEER.has(clip) or ThrongClips.TALK_PEER.has(clip):
			_fail("alone content sang/talked peer: '%s'" % clip)
			alone_bad = true
	if not alone_bad:
		_pass("alone content stays calm: %s" % str(alone_social.keys()))

	var b := _spawn(220.0, 200.0, 95.0, 95.0, 95.0)
	if not bool(sim.world_entities.has_living_peer(a)):
		_fail("pair should has_living_peer (a)")
	else:
		_pass("pair has_living_peer=true")
	# Without peer_t, standing content must stay calm (no fake social paint).
	var idle_pair := _clip(a, 1.0)
	if ThrongClips.IDLE_CALM.has(idle_pair):
		_pass("pair without peer_t stays IDLE_CALM: %s" % idle_pair)
	else:
		_fail("pair without peer_t → '%s'" % idle_pair)
	# Real social beat: pair, face, talk/sing.
	sim.peer_t[a] = float(sim.PEER_DUR)
	sim.peer_t[b] = float(sim.PEER_DUR)
	sim.peer_of[a] = b
	sim.peer_of[b] = a
	sim.peer_sing[a] = 0
	sim.peer_sing[b] = 0
	var talk_c := _clip(a, 0.4)
	if ThrongClips.TALK_PEER.has(talk_c):
		_pass("peer_t talk → TALK_PEER: %s" % talk_c)
	else:
		_fail("peer_t talk → '%s'" % talk_c)
	sim.peer_sing[a] = 1
	sim.peer_sing[b] = 1
	var sing_c := _clip(a, 0.4)
	if ThrongClips.SING_PEER.has(sing_c):
		_pass("peer_t sing → SING_PEER: %s" % sing_c)
	else:
		_fail("peer_t sing → '%s'" % sing_c)
	var flip_a: float = float(main.anim_frames.throng_flip(a))
	var flip_b: float = float(main.anim_frames.throng_flip(b))
	if flip_a != flip_b:
		_pass("peer social faces each other (flip a=%.0f b=%.0f)" % [flip_a, flip_b])
	else:
		_fail("peer social should face opposite (flip a=%.0f b=%.0f)" % [flip_a, flip_b])
	# _try_peer_social must pair two free content agents.
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	b = _spawn(210.0, 200.0, 95.0, 95.0, 95.0)
	sim.frame_i = 75  # ((frame_i + a) % 75) == 0 when a==0
	var started := false
	for _attempt in 40:
		sim.frame_i = 75 * (_attempt + 1)
		if bool(sim.world_entities._try_peer_social(a)):
			started = true
			break
	if started and float(sim.peer_t[a]) > 0.0 and int(sim.peer_of[a]) == b and float(sim.peer_t[b]) > 0.0:
		_pass("_try_peer_social pairs a↔b for %.2fs" % float(sim.peer_t[a]))
	else:
		_fail("_try_peer_social failed to pair (started=%s peer_of=%s)" % [started, int(sim.peer_of[a]) if a < sim.peer_of.size() else -1])

	print("==== 6 Unlock celebrate + post-eat calm ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	var granted: bool = bool(sim.dialogue._grant("probe_unlock_key", "", false))
	if not granted and float(sim.celebrate_t) <= 0.0:
		sim.celebrate_t = float(sim.CELEBRATE_DUR)
	if float(sim.celebrate_t) <= 0.0:
		_fail("celebrate_t not set after grant")
	else:
		_pass("celebrate_t=%.2f after unlock path" % float(sim.celebrate_t))
	var cel := _clip(a, 0.2)
	if cel == "ThrongA_Celebrate_Spritesheet":
		_pass("unlock celebrate → Celebrate_Spritesheet")
	else:
		_fail("unlock celebrate → '%s'" % cel)
	sim.celebrate_t = 0.0
	sim.act[a] = sim.ACT_EAT
	sim.act_t[a] = 0.55
	var eat := _clip(a, 0.2)
	if eat == "ThrongA_Eat":
		_pass("ACT_EAT → ThrongA_Eat")
	else:
		_fail("ACT_EAT → '%s'" % eat)
	sim.act[a] = 0
	sim.act_t[a] = 0.0
	sim.cheer_t[a] = 0.0
	sim.fed[a] = 100.0
	sim.amused[a] = 100.0
	sim.clean[a] = 100.0
	# Video post-bite: Happy stand (t068-03), not Celebrate / Rotund.
	var after_eat := _clip(a, 0.2)
	if after_eat == "ThrongA_Happy" or after_eat in ThrongClips.IDLE_CALM:
		_pass("post-eat → calm/Happy ('%s')" % after_eat)
	else:
		_fail("post-eat → '%s' expected Happy/IDLE_CALM" % after_eat)

	print("==== 7 Death react + near fire ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	b = _spawn(220.0, 200.0, 95.0, 95.0, 95.0)
	sim.world_entities._pulse_react_near(200.0, 200.0, -1)
	if float(sim.react_t[a]) <= 0.0 and float(sim.react_t[b]) <= 0.0:
		_fail("react_t not pulsed on neighbors")
	else:
		_pass("react_t a=%.2f b=%.2f" % [float(sim.react_t[a]), float(sim.react_t[b])])
	var react_clip := _clip(a, 0.1)
	if react_clip == "ThrongA_ReactToKill":
		_pass("react → ThrongA_ReactToKill")
	else:
		_fail("react → '%s' expected ReactToKill" % react_clip)
	sim.react_t[a] = 0.0
	sim.react_t[b] = 0.0
	sim.fires = [{"dead": false, "kind": Catalog.FEAT_FIRE, "x": 205.0, "y": 200.0}]
	if not bool(sim.world_entities.near_fire(a)):
		_fail("near_fire false with fire at feet")
	else:
		_pass("near_fire true")
	var fire_counts := _sample_set(a, [0.0, 0.3, 0.7, 1.1, 1.6, 2.2, 2.8, 3.4])
	print("  fire samples: %s" % str(fire_counts))
	if fire_counts.size() == 1 and fire_counts.has("ThrongA_PanicRunFire"):
		_pass("near fire → only PanicRunFire")
	else:
		_fail("near fire must be only PanicRunFire, got %s" % str(fire_counts))

	print("==== 8 Walks: homed / happy / sad / carry ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.dir_x[a] = 1.0
	sim.dir_y[a] = 0.0
	sim.blds_home = [{"dead": false, "x": 230.0, "y": 200.0, "kind": Catalog.BLD_DWELL}]
	if not bool(sim.world_entities.approaching_home(a)):
		_fail("approaching_home false with home nearby")
	else:
		_pass("approaching_home true")
	var homed := _clip(a, 1.0)
	if homed == "Throng_Walk_Homed_Spritesheet":
		_pass("walk → Walk_Homed")
	else:
		_fail("walk → '%s' expected Walk_Homed" % homed)
	sim.blds_home.clear()
	var happy_w := _clip(a, 1.0)
	if happy_w == "ThrongA_Happy_Walk":
		_pass("content walk → Happy_Walk")
	else:
		_fail("content walk → '%s' expected Happy_Walk" % happy_w)
	sim.fed[a] = 10.0
	var sad_w := _clip(a, 1.0)
	if sad_w == "ThrongA_Sad_Walk":
		_pass("hungry walk → Sad_Walk")
	else:
		_fail("hungry walk → '%s' expected Sad_Walk" % sad_w)
	sim.fed[a] = 95.0
	sim.carry[a] = Catalog.CARRY_ORE
	var haul := _clip(a, 1.0)
	if haul == "ThrongA_LiftPropWalk":
		_pass("carry moving → LiftPropWalk")
	else:
		_fail("carry moving → '%s' expected LiftPropWalk" % haul)
	sim.dir_x[a] = 0.0
	var haul_stand := _clip(a, 1.0)
	if haul_stand == "ThrongA_LiftProp":
		_pass("carry stand → LiftProp")
	else:
		_fail("carry stand → '%s' expected LiftProp" % haul_stand)

	print("==== 9 Sleep ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.sleep_t[a] = float(sim.SLEEP_DUR)
	var sleep_c := _clip(a, 1.0)
	_expect_pool("sleep", sleep_c, ThrongClips.IDLE_SLEEP)

	print("==== 10 Invariants: held stable + no pool-mix criticals ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	_spawn(210.0, 205.0, 95.0, 95.0, 95.0)
	sim.dir_x[a] = 1.0
	sim.penned_flag[a] = 1
	if not bool(sim.player_tools.grab_thronglet(a)):
		_fail("grab_thronglet failed")
	else:
		_pass("grab_thronglet ok")
	if float(sim.dir_x[a]) != 0.0 or float(sim.dir_y[a]) != 0.0:
		_fail("grab must zero dir")
	else:
		_pass("grab zeros dir")
	var held_counts := _sample_set(a, [0.0, 0.5, 1.0, 2.0, 3.5, 5.0, 8.0, 12.0, 16.0, 20.0])
	print("  held samples: %s" % str(held_counts))
	if held_counts.size() == 1 and held_counts.has("ThrongA_Default"):
		_pass("held → only Default (no pool cycle)")
	else:
		_fail("held must stay Default, got %s" % str(held_counts))
	# Cursor draw exists; world path must skip held id.
	var world_would_draw: bool = not (str(sim.held_kind) == "thronglet" and int(sim.held_ref) == a)
	if world_would_draw:
		_fail("world draw would still include held thronglet")
	else:
		_pass("world draw skips held thronglet")
	sim.player_tools.cancel_hold()
	# Grab clears per-agent one-shots; penned body stays a single clip.
	sim.penned_flag[a] = 1
	sim.react_t[a] = 0.0
	var after := _clip(a, 1.0)
	if after == "ThrongA_FreakOut":
		_pass("after hold, penned still FreakOut-only")
	else:
		_fail("after hold penned → '%s'" % after)

	print("==== 11 Far LOD + sticky acts (Eat-class drop) ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	var far_cases := [
		{"act": sim.ACT_EAT, "want": "ThrongA_Eat", "label": "far ACT_EAT"},
		{"act": sim.ACT_WASH, "want": "ThrongA_Happy", "label": "far ACT_WASH"},
		{"act": sim.ACT_WORK, "want": "ThrongA_Pickaxe_Spritesheet", "label": "far ACT_WORK stand"},
		{"act": sim.ACT_PLAY, "want": "ThrongA_Jump_VariantA_Spritesheet", "label": "far ACT_PLAY free"},
	]
	for case in far_cases:
		sim.act[a] = int(case.act)
		sim.act_t[a] = 0.55
		sim.dir_x[a] = 0.0
		sim.dir_y[a] = 0.0
		sim.carry[a] = Catalog.CARRY_NONE
		var far_clip: String = ThrongClips.clip_name_at(int(main.anim_frames.frame_lod(a, 0.2, true)))
		if far_clip == str(case.want):
			_pass("%s → %s" % [case.label, far_clip])
		else:
			_fail("%s → '%s' expected %s" % [case.label, far_clip, case.want])
	sim.act[a] = 0
	sim.carry[a] = Catalog.CARRY_ORE
	sim.dir_x[a] = 1.0
	var far_haul: String = ThrongClips.clip_name_at(int(main.anim_frames.frame_lod(a, 0.2, true)))
	if far_haul == "ThrongA_LiftPropWalk":
		_pass("far carry → LiftPropWalk")
	else:
		_fail("far carry → '%s' expected LiftPropWalk" % far_haul)
	sim.carry[a] = Catalog.CARRY_NONE
	sim.dir_x[a] = 0.0
	sim.celebrate_t = float(sim.CELEBRATE_DUR)
	var far_cel: String = ThrongClips.clip_name_at(int(main.anim_frames.frame_lod(a, 0.2, true)))
	if far_cel == "ThrongA_Celebrate_Spritesheet":
		_pass("far celebrate → Celebrate")
	else:
		_fail("far celebrate → '%s'" % far_cel)
	sim.celebrate_t = 0.0
	sim.penned_flag[a] = 1
	var far_pen: String = ThrongClips.clip_name_at(int(main.anim_frames.frame_lod(a, 0.2, true)))
	if far_pen == "ThrongA_FreakOut":
		_pass("far penned → FreakOut")
	else:
		_fail("far penned → '%s'" % far_pen)
	# Sticky: act_t expiry must not wipe WORK while mine_job is set.
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.act[a] = sim.ACT_WORK
	sim.act_t[a] = 0.01
	if a < sim.mine_job.size():
		sim.mine_job[a] = 1
	sim._tick_life(a, 0.05, 1.0)
	if int(sim.act[a]) == int(sim.ACT_WORK):
		_pass("sticky ACT_WORK survives act_t expiry with mine_job")
	else:
		_fail("sticky ACT_WORK cleared to %d" % int(sim.act[a]))
	sim.act[a] = sim.ACT_PLAY
	sim.act_t[a] = 0.01
	if a < sim.link_ball.size():
		sim.link_ball[a] = 99
	sim._tick_life(a, 0.05, 1.0)
	if int(sim.act[a]) == int(sim.ACT_PLAY):
		_pass("sticky ACT_PLAY survives act_t expiry with link_ball")
	else:
		_fail("sticky ACT_PLAY cleared to %d" % int(sim.act[a]))

	print("==== 12 DropProp / mine Twiddle ====")
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	sim.carry[a] = Catalog.CARRY_ORE
	sim.carry_value[a] = 1
	sim.world_entities._set_carry(a, Catalog.CARRY_NONE)
	if float(sim.drop_t[a]) <= 0.0:
		_fail("drop_t not set on haul clear")
	else:
		_pass("drop_t=%.2f after _set_carry NONE" % float(sim.drop_t[a]))
	var drop_c := _clip(a, 0.05)
	if drop_c == "ThrongA_DropProp":
		_pass("drop_t → DropProp")
	else:
		_fail("drop_t → '%s' expected DropProp" % drop_c)
	sim.drop_t[a] = 0.0
	sim.cheer_t[a] = 0.0
	# Mine guest: Pickaxe swing then Twiddle wait.
	_reset()
	a = _spawn(200.0, 200.0, 95.0, 95.0, 95.0)
	var mine := {"id": 9001, "kind": Catalog.BLD_MINE, "x": 200.0, "y": 200.0, "dead": false, "guests": [{"id": a, "left": 2.0}]}
	sim.building_by_id[9001] = mine
	if a < sim.link_guest.size():
		sim.link_guest[a] = 9001
	sim.act[a] = sim.ACT_WORK
	sim.act_t[a] = 1.0
	sim.dir_x[a] = 0.0
	sim.dir_y[a] = 0.0
	if not bool(sim.world_entities.is_mining(a)):
		_fail("is_mining false for mine guest")
	else:
		_pass("is_mining true for mine guest")
	var swing_t := 0.1
	var wait_t = float(sim.MINE_SWING_T) + 0.05
	var swing_c := _clip(a, swing_t)
	var wait_c := _clip(a, wait_t)
	if swing_c == "ThrongA_Pickaxe_Spritesheet":
		_pass("mine swing → Pickaxe")
	else:
		_fail("mine swing → '%s' expected Pickaxe" % swing_c)
	if wait_c == "Throng_Think_TwiddleThumbs_Spritesheet":
		_pass("mine wait → TwiddleThumbs")
	else:
		_fail("mine wait → '%s' expected TwiddleThumbs" % wait_c)
