class_name SimAgentTick
extends RefCounted

## Agent AI: LOD ticks, needs, seeks, mitosis, rides, mood.

var sim


## Stores the simulation server used for agent AI.
func _init(sim_ref) -> void:
	sim = sim_ref

## Updates every living thronglet with full AI or budgeted LOD when the colony is huge.
func _tick_agents(delta: float) -> void:
	if sim.living_ids.is_empty():
		return
	var n = sim.living_ids.size()
	var decay = _decay_scale()
	_ensure_agent_done_frame()
	# Mid-game: every thronglet gets real _walk/_decide — LOD made them freeze on trees.
	if n <= sim.AGENT_FULL_CAP:
		for raw in sim.living_ids:
			var i_full = int(raw)
			if i_full < 0 or i_full >= sim.slot_count or sim.state[i_full] != Catalog.ST_LIVING:
				continue
			if sim.held_kind == "thronglet" and i_full == sim.held_ref:
				continue
			_tick_one(i_full, delta, decay, true)
			_sample_mood(i_full)
		_publish_mood()
		return
	var sticky_left = sim.AGENT_STICKY_BUDGET
	var seek_left = sim.AGENT_SEEK_BUDGET
	var cheap_left = sim.AGENT_CHEAP_BUDGET
	# 1) Sticky goals — haul/mine first, then any active seek (needs _walk to peel buildings).
	if n <= sim.AGENT_STICKY_SCAN_CAP:
		for pass_i in 2:
			if sticky_left <= 0:
				break
			var hard_pass = pass_i == 0
			for raw_goal in sim.living_ids:
				if sticky_left <= 0:
					break
				var ig = int(raw_goal)
				if ig < 0 or ig >= sim.slot_count or sim.state[ig] != Catalog.ST_LIVING:
					continue
				if sim.held_kind == "thronglet" and ig == sim.held_ref:
					continue
				_ensure_agent_done_frame()
				if sim._agent_done_frame[ig] == sim.frame_i:
					continue
				if hard_pass:
					if not _agent_has_hard_goal(ig):
						continue
				elif not _agent_has_goal(ig):
					continue
				_tick_one(ig, delta, decay, true)
				_ensure_agent_done_frame()
				sim._agent_done_frame[ig] = sim.frame_i
				sticky_left -= 1
				_sample_mood(ig)
	# 2) Near camera: rotate idle seeks; leftovers coast so the view stays alive.
	var near_ids: Array = []
	if sim.view_rect.size != Vector2.ZERO:
		near_ids = sim.spatial.query_rect(sim.view_rect.grow(sim.AGENT_NEAR_PAD), sim.AGENT_NEAR_BUDGET)
	var near_n = near_ids.size()
	if near_n > 0:
		var near_base = sim.frame_i % near_n
		for j in near_n:
			var i = int(near_ids[(near_base + j) % near_n])
			if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
				continue
			if sim.held_kind == "thronglet" and i == sim.held_ref:
				continue
			_ensure_agent_done_frame()
			if sim._agent_done_frame[i] == sim.frame_i:
				continue
			if seek_left > 0:
				_tick_one(i, delta, decay, true)
				_ensure_agent_done_frame()
				sim._agent_done_frame[i] = sim.frame_i
				seek_left -= 1
				_sample_mood(i)
			else:
				# Life still advances when seek budget is exhausted; only AI seeks are deferred.
				_tick_one(i, delta, decay, false)
				sim._agent_done_frame[i] = sim.frame_i
	# 3) Far / overflow: fixed rotating budgets — cost flat at 50k-120k.
	# Re-read living_ids.size() — sticky/near ticks can kill and shrink the list.
	n = sim.living_ids.size()
	if n <= 0:
		_publish_mood()
		return
	_ensure_agent_done_frame()
	if seek_left > 0:
		var base = int((sim.frame_i * sim.AGENT_SEEK_BUDGET) % n)
		var far_period = maxi(1, int(ceil(float(n) / float(sim.AGENT_SEEK_BUDGET))))
		var life_dt = delta * float(far_period)
		for j2 in seek_left:
			var live_n2 = sim.living_ids.size()
			if live_n2 <= 0:
				break
			var i2 = int(sim.living_ids[(base + j2) % live_n2])
			if i2 < 0 or i2 >= sim.slot_count or sim.state[i2] != Catalog.ST_LIVING:
				continue
			if sim.held_kind == "thronglet" and i2 == sim.held_ref:
				continue
			_ensure_agent_done_frame()
			if sim._agent_done_frame[i2] == sim.frame_i:
				continue
			if not _tick_life(i2, life_dt, decay):
				sim._agent_done_frame[i2] = sim.frame_i
				continue
			sim.tick_stamp[i2] = sim.frame_i
			if _tick_busy(i2, delta, true):
				_tick_decide(i2, delta)
			sim._agent_done_frame[i2] = sim.frame_i
			_sample_mood(i2)
	if cheap_left > 0:
		n = sim.living_ids.size()
		if n <= 0:
			_publish_mood()
			return
		var cbase = int((sim.frame_i * sim.AGENT_CHEAP_BUDGET) % n)
		var cheap_period = maxi(1, int(ceil(float(n) / float(sim.AGENT_CHEAP_BUDGET))))
		var cheap_life_dt = delta * float(cheap_period)
		for j3 in cheap_left:
			var live_n3 = sim.living_ids.size()
			if live_n3 <= 0:
				break
			var i3 = int(sim.living_ids[(cbase + j3) % live_n3])
			if i3 < 0 or i3 >= sim.slot_count or sim.state[i3] != Catalog.ST_LIVING:
				continue
			if sim.held_kind == "thronglet" and i3 == sim.held_ref:
				continue
			_ensure_agent_done_frame()
			if sim._agent_done_frame[i3] == sim.frame_i:
				continue
			if not _tick_life(i3, cheap_life_dt, decay):
				sim._agent_done_frame[i3] = sim.frame_i
				continue
			sim.tick_stamp[i3] = sim.frame_i
			_tick_busy_or_coast(i3, delta)
			sim._agent_done_frame[i3] = sim.frame_i
	_publish_mood()



## Resizes the per-slot once-per-frame guard array when thronglet capacity grows.
func _ensure_agent_done_frame() -> void:
	var need = sim.slot_count
	if sim._agent_done_frame.size() == need:
		return
	var old = sim._agent_done_frame.size()
	sim._agent_done_frame.resize(need)
	for k in range(old, need):
		sim._agent_done_frame[k] = -1



## Whether this agent must run full pathing each frame due to haul, mine job, or item claim.
func _agent_has_hard_goal(i: int) -> bool:
	if i < 0 or i >= sim.slot_count:
		return false
	if i < sim.mine_job.size() and int(sim.mine_job[i]) >= 0:
		return true
	if i < sim.carry.size() and sim.carry[i] != Catalog.CARRY_NONE:
		return true
	if i < sim.link_claim.size() and sim.link_claim[i] >= 0:
		return true
	return false



## True when the thronglet is seeking or holding a goal that needs continuous movement.
func _agent_has_goal(i: int) -> bool:
	# Any active walk needs every-frame _walk — coast cannot peel around buildings.
	if _agent_has_hard_goal(i):
		return true
	if i < sim.seek_t.size() and sim.seek_t[i] > 0.0:
		return true
	return false



## Tallies this agent into colony mood histogram buckets from fed, fun, and clean needs.
func _sample_mood(i: int) -> void:
	if sim.state[i] != Catalog.ST_LIVING:
		return
	var fed_v = sim.fed[i]
	var fun_v = sim.amused[i]
	var clean_v = sim.clean[i]
	if fed_v < 8.0 or fun_v < 8.0 or clean_v < 8.0:
		sim._mood_freak += 1
	elif fed_v < 25.0 or clean_v < 12.0:
		sim._mood_cry += 1
	elif fun_v < 25.0:
		sim._mood_sus += 1
	elif fed_v >= Catalog.NEED_OK and fun_v >= Catalog.NEED_OK and clean_v >= Catalog.NEED_OK:
		sim._mood_happy += 1
	else:
		sim._mood_base += 1



## Picks the dominant colony mood face for UI from aggregated need samples this frame.
func _publish_mood() -> void:
	var best = "base"
	var best_n = -1
	var bins: Array = [
		["freak", sim._mood_freak],
		["cry", sim._mood_cry],
		["suspicious", sim._mood_sus],
		["happy", sim._mood_happy],
		["base", sim._mood_base],
	]
	for row in bins:
		var n = int(row[1])
		if n > best_n:
			best_n = n
			best = str(row[0])
	sim.mood_face = best if best_n > 0 else "base"
	sim._mood_base = 0
	sim._mood_happy = 0
	sim._mood_cry = 0
	sim._mood_sus = 0
	sim._mood_freak = 0



## Full per-agent tick: needs decay, sticky actions, then seek decisions when allowed.
func _tick_one(i: int, dt: float, decay: float = -1.0, allow_seek: bool = true) -> void:
	if i < 0 or i >= sim.slot_count:
		return
	if sim.tick_stamp[i] == sim.frame_i:
		return
	sim.tick_stamp[i] = sim.frame_i
	if sim.state[i] != Catalog.ST_LIVING:
		return
	if sim.held_kind == "thronglet" and i == sim.held_ref:
		return
	if decay < 0.0:
		decay = _decay_scale()
	if not _tick_life(i, dt, decay):
		return
	if not allow_seek:
		_tick_busy_or_coast(i, dt)
		return
	if not _tick_busy(i, dt, true):
		return
	_tick_decide(i, dt)



## Decays needs, starvation, mitosis, social freezes; returns false when movement should stop.
func _tick_life(i: int, dt: float, decay: float) -> bool:
	# Returns false when the agent should not move/decide further this tick.
	if sim.mito_t[i] > 0.0:
		sim.mito_t[i] = maxf(0.0, sim.mito_t[i] - dt)
		if sim.mito_t[i] <= 0.0:
			_finish_mitosis(i)
		return false
	if sim.mito_charge[i] > 0.0:
		# The mitosis sheet already plays while charging, so stay put for the
		# whole buildup + split instead of walking through the animation.
		sim.mito_charge[i] = minf(sim.MITOSIS_CHARGE, sim.mito_charge[i] + dt)
		if sim.mito_charge[i] >= sim.MITOSIS_CHARGE:
			sim.mito_charge[i] = 0.0
			_start_mitosis(i)
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		sim.act[i] = 0
		sim.act_t[i] = 0.0
		sim.shake_t[i] = 0.0
		return false
	sim.fed[i] = maxf(0.0, sim.fed[i] - sim.DECAY_FED * decay * dt)
	sim.amused[i] = maxf(0.0, sim.amused[i] - sim.DECAY_FUN * decay * dt)
	sim.clean[i] = maxf(0.0, sim.clean[i] - sim.DECAY_CLEAN * decay * dt)
	# Goo check is relatively rare terrain; skip most cheap frames via id phase.
	if ((sim.frame_i + i) & 7) == 0:
		var tile = sim.collision._tile_at(sim.pos_x[i], sim.pos_y[i])
		if tile == Catalog.TILE_GOO:
			var goo_hit = 0.35 if bool(sim.mutations.get("adapt", false)) else 0.9
			sim.clean[i] = maxf(0.0, sim.clean[i] - goo_hit * dt * 8.0)
			sim.fed[i] = maxf(0.0, sim.fed[i] - 0.35 * dt * 8.0)
	if sim.fed[i] <= 0.0 or sim.amused[i] <= 0.0 or sim.clean[i] <= 0.0:
		sim.starve[i] += dt
		if sim.starve[i] >= sim.STARVE_GRACE:
			sim.world_entities._die_neglect(i)
			return false
	else:
		sim.starve[i] = 0.0
	if sim.fed[i] < Catalog.NEED_HUNGRY:
		sim.hungry_t[i] += dt
	else:
		sim.hungry_t[i] = 0.0
	if sim.bark_cool[i] > 0.0:
		sim.bark_cool[i] = maxf(0.0, sim.bark_cool[i] - dt)
	elif ((sim.frame_i + i) & 15) == 0:
		sim.dialogue._maybe_bark(i)
	sim.world_entities._ensure_agent_timers(i)
	if sim.react_t[i] > 0.0:
		sim.react_t[i] = maxf(0.0, sim.react_t[i] - dt)
	if sim.cheer_t[i] > 0.0:
		sim.cheer_t[i] = maxf(0.0, sim.cheer_t[i] - dt)
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
	# Sing bark: stay put until the bocadillo (and its one-shot clip) ends.
	if sim.dialogue.bark_sing_of(i) != "":
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
	if sim.drop_t[i] > 0.0:
		sim.drop_t[i] = maxf(0.0, sim.drop_t[i] - dt)
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
	if sim.peer_t[i] > 0.0:
		sim.peer_t[i] = maxf(0.0, sim.peer_t[i] - dt)
		if sim.peer_t[i] <= 0.0:
			sim.world_entities._clear_peer_social(i)
		else:
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0
	if sim.sleep_t[i] > 0.0:
		sim.sleep_t[i] = maxf(0.0, sim.sleep_t[i] - dt)
	elif sim.act[i] == 0 and sim.peer_t[i] <= 0.0 and sim.drop_t[i] <= 0.0 and sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK:
		if ((sim.frame_i + i) % 180) == 0 and randf() < 0.08:
			sim.sleep_t[i] = sim.SLEEP_DUR
	if sim.act_t[i] > 0.0:
		sim.act_t[i] = maxf(0.0, sim.act_t[i] - dt)
	# Sticky acts are held by claim/seat/job — cheap/far ticks must not wipe the body clip.
	# Clear when timer is already 0 and sticky no longer applies (e.g. orphan ACT_EAT).
	if sim.act_t[i] <= 0.0 and int(sim.act[i]) != 0 and not _act_is_sticky(i):
		sim.act[i] = 0
	if sim.shake_t[i] > 0.0:
		sim.shake_t[i] = maxf(0.0, sim.shake_t[i] - dt)
		sim.act[i] = sim.ACT_WASH
		sim.act_t[i] = 0.2
	# Re-assert wash for the whole sponge hold (even if act_t just hit 0 above).
	if i == sim.sponge_id and sim.sponge_hold > 0.0:
		sim.act[i] = sim.ACT_WASH
		sim.act_t[i] = maxf(sim.act_t[i], 0.35)
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return false
	if sim.act[i] == sim.ACT_WASH:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return false
	if sim.cheer_t[i] > 0.0:
		return false
	if sim.dialogue.bark_sing_of(i) != "":
		return false
	sim.cool[i] = maxf(0.0, sim.cool[i] - dt)
	return true



## Whether the current body action must persist while tied to food, tub, ride, ball, or mine.
func _act_is_sticky(i: int) -> bool:
	match int(sim.act[i]):
		sim.ACT_EAT:
			# Only while a claimed apple is still in bite range — avoids orphan Eat clips
			# on the full AI path (n <= AGENT_FULL_CAP never runs _continue_eat alone).
			var apple = _claimed_apple(i)
			return not apple.is_empty() and sim.spatial._dist_i(i, float(apple.x), float(apple.y)) < 12.0
		# WASH is refreshed by scrub/shake act_t — never sticky or it loops forever.
		sim.ACT_BATH:
			return (i < sim.link_tub.size() and sim.link_tub[i] >= 0) \
				or (i < sim.link_guest.size() and sim.link_guest[i] >= 0)
		sim.ACT_PLAY:
			if i < sim.link_ball.size() and int(sim.link_ball[i]) >= 0:
				return true
			return (i < sim.link_ride.size() and sim.link_ride[i] >= 0) \
				or (i < sim.link_guest.size() and sim.link_guest[i] >= 0)
		sim.ACT_WORK:
			return (i < sim.link_guest.size() and sim.link_guest[i] >= 0) \
				or (i < sim.mine_job.size() and int(sim.mine_job[i]) >= 0)
		_:
			return false



## Low-budget motion: finish eats and building visits, else coast along seek or wander heading.
func _tick_busy_or_coast(i: int, dt: float) -> void:
	# Cheap ticks still advance sticky interactions so body clips do not flicker to idle/walk.
	if i < sim.drop_t.size() and sim.drop_t[i] > 0.0:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return
	if sim.dialogue.bark_sing_of(i) != "":
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
		return
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return
	if sim.act[i] == sim.ACT_EAT and _continue_eat(i, dt):
		return
	if _continue_sticky_play_or_work(i, dt):
		return
	# Most agents are free walkers: skip tub/ride/guest scans via O(1) link checks.
	var linked = (i < sim.link_tub.size() and sim.link_tub[i] >= 0) \
		or (i < sim.link_ride.size() and sim.link_ride[i] >= 0) \
		or (i < sim.link_guest.size() and sim.link_guest[i] >= 0)
	if linked:
		if not _tick_busy(i, dt, false):
			return
	elif sim.mito_charge[i] > 0.0:
		return
	if sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]):
		sim.collision._unstick(i)
	var speed = sim.MOVE_SPEED
	if sim.buff_t[i] > 0.0:
		speed = 36.0
		sim.buff_t[i] = maxf(0.0, sim.buff_t[i] - dt)
	if i < sim.seek_t.size() and sim.seek_t[i] > 0.0:
		sim.seek_t[i] = maxf(0.0, sim.seek_t[i] - dt)
		sim.agent_move._coast(i, sim.seek_x[i], sim.seek_y[i], speed, dt)
	else:
		if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) < 0.01:
			sim.agent_move._pick_wander(i)
		sim.agent_move._coast_dir(i, speed, dt)



## Handles bath, carousel, and guest-building occupancy; may charge mitosis when needs are met.
func _tick_busy(i: int, dt: float, hard_unstick: bool) -> bool:
	# Tub / ride / guest. Returns false when occupied for the rest of the tick.
	var tub_here = sim.building_sim.seat_of(i)
	var in_tub = not tub_here.is_empty() and float(tub_here.get("bath_t", -1.0)) >= 0.0
	var on_ride = not _ride_building(i).is_empty()
	if not in_tub and not on_ride and sim.collision._move_blocked(sim.pos_x[i], sim.pos_y[i]):
		if hard_unstick:
			sim.collision._unstick(i)
		else:
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0
			if i < sim.seek_t.size():
				sim.seek_t[i] = 0.0
	var visit = sim.building_sim._guest_building(i)
	if not visit.is_empty():
		var visit_kind = int(visit.kind)
		var visit_rule = sim.building_sim._visit_rule(visit_kind)
		var served_fed = float(visit_rule.get("fed", 0.0)) > 0.0
		var served_clean = float(visit_rule.get("clean", 0.0)) > 0.0
		var served_fun = float(visit_rule.get("fun", 0.0)) > 0.0
		var leave = false
		if sim.fed[i] < Catalog.NEED_HUNGRY and not served_fed:
			leave = true
		elif sim.clean[i] < Catalog.NEED_SEEK and not served_clean:
			leave = true
		elif sim.amused[i] < Catalog.NEED_FUN and not served_fun:
			leave = true
		if leave:
			sim.building_sim._drop_guest(visit, i)
		else:
			var door = sim.collision._approach_building(visit, i)
			var at_door = sim.spatial._dist_i(i, float(door.x), float(door.y)) < float(Catalog.TILE) * 1.25
			if not sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], visit) and not at_door:
				if i < sim.seek_t.size() and sim.seek_t[i] > 0.0:
					sim.agent_move._coast(i, sim.seek_x[i], sim.seek_y[i], sim.MOVE_SPEED, dt)
				elif hard_unstick:
					sim.agent_move._walk(i, float(door.x), float(door.y), sim.MOVE_SPEED, dt)
			else:
				if sim.building_sim._is_show(visit_kind):
					sim.act[i] = sim.ACT_PLAY
				elif sim.building_sim._is_mine_kind(visit_kind):
					sim.act[i] = sim.ACT_WORK
				else:
					sim.act[i] = sim.ACT_BATH
				sim.act_t[i] = 0.4
			return false
	var tub_seat = sim.building_sim.seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		_do_bath(i, tub_seat, dt)
		return false
	var riding_b = _ride_building(i)
	if not riding_b.is_empty():
		_do_roundabout_ride(i, riding_b, dt)
		return false
	var ready = sim.fed[i] >= Catalog.NEED_OK and sim.amused[i] >= Catalog.NEED_OK and sim.clean[i] >= Catalog.NEED_OK and sim.cool[i] <= 0.0
	if ready:
		sim.mito_charge[i] = minf(sim.MITOSIS_CHARGE, sim.mito_charge[i] + dt)
		if sim.mito_charge[i] >= sim.MITOSIS_CHARGE:
			sim.mito_charge[i] = 0.0
			_start_mitosis(i)
			return false
	else:
		sim.mito_charge[i] = maxf(0.0, sim.mito_charge[i] - dt * 1.5)
	return true



## Priority planner: hunger, hygiene, haul, fun, mining, top-up needs, peers, then wander.
func _tick_decide(i: int, dt: float) -> void:
	if i < sim.drop_t.size() and sim.drop_t[i] > 0.0:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return
	# Full AI path never hits _tick_busy_or_coast — keep chewing / clear orphan ACT_EAT here.
	if sim.act[i] == sim.ACT_EAT and _continue_eat(i, dt):
		_release_mine_job(i)
		return
	var speed = sim.MOVE_SPEED
	if sim.buff_t[i] > 0.0:
		speed = 36.0
		sim.buff_t[i] = maxf(0.0, sim.buff_t[i] - dt)
	# Distress first. Then haul / mine while needs are good enough (_work_ready).
	# Mitosis polish (NEED_OK) waits — otherwise a tub/ride keeps them from ever mining.
	# Wood/bone claims must drop when leaving haul, or one stuck rider locks every plank.
	if sim.fed[i] < Catalog.NEED_HUNGRY:
		sim.building_sim._release_claim(i)
		if _seek_food(i, speed, dt):
			_release_mine_job(i)
			return
		_release_item_claims(i)
	if sim.clean[i] < Catalog.NEED_SEEK:
		if _seek_clean(i, speed, dt):
			_release_item_claims(i)
			_release_mine_job(i)
			return
	# Finish a load already in hand before topping fun — otherwise the haul starves.
	if sim.carry[i] != Catalog.CARRY_NONE and _try_haul(i, speed, dt):
		_release_mine_job(i)
		return
	if sim.amused[i] < Catalog.NEED_FUN:
		_release_item_claims(i)
		if _tend_fun(i, speed, dt):
			_release_mine_job(i)
			return
	if _try_haul(i, speed, dt):
		_release_mine_job(i)
		return
	if _seek_mine(i, speed, dt):
		_release_item_claims(i)
		return
	if sim.fed[i] < Catalog.NEED_OK or sim.clean[i] < Catalog.NEED_OK or sim.amused[i] < Catalog.NEED_OK:
		var lack_fed = Catalog.NEED_OK - sim.fed[i]
		var lack_clean = Catalog.NEED_OK - sim.clean[i]
		var lack_fun = Catalog.NEED_OK - sim.amused[i]
		if lack_fed >= lack_clean and lack_fed >= lack_fun:
			if _seek_food(i, speed, dt):
				_release_mine_job(i)
				return
			_release_item_claims(i)
		elif lack_clean >= lack_fun:
			if _seek_clean(i, speed, dt):
				_release_item_claims(i)
				_release_mine_job(i)
				return
			sim.building_sim._release_claim(i)
		else:
			_release_item_claims(i)
			if _tend_fun(i, speed, dt):
				_release_mine_job(i)
				return
		if sim.fed[i] < Catalog.NEED_OK and _seek_food(i, speed, dt):
			_release_mine_job(i)
			return
		if sim.clean[i] < Catalog.NEED_OK and _seek_clean(i, speed, dt):
			_release_item_claims(i)
			_release_mine_job(i)
			return
		if sim.amused[i] < Catalog.NEED_OK:
			_release_item_claims(i)
			if _tend_fun(i, speed, dt):
				_release_mine_job(i)
				return
	else:
		_release_item_claims(i)
		sim.building_sim._release_claim(i)
	_release_mine_job(i)
	_release_item_claims(i)
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		return
	if sim.world_entities._try_peer_social(i):
		return
	sim.agent_move._wander(i, speed, dt)



## Begins the split animation when colony space allows and clears competing jobs.
func _start_mitosis(i: int) -> void:
	if sim.world_entities._space_blocks_mitosis(i):
		sim.cool[i] = Catalog.MITOSIS_WAIT
		return
	_release_item_claims(i)
	_release_mine_job(i)
	sim.cool[i] = Catalog.MITOSIS_WAIT
	sim.mito_charge[i] = 0.0
	sim.mito_t[i] = sim.MITOSIS_ANIM



## Spawns a daughter thronglet beside the parent and plays colony growth feedback.
func _finish_mitosis(i: int) -> void:
	if sim.world_entities._space_blocks_mitosis(i):
		return
	var x = sim.pos_x[i] + sim.MITOSIS_OFFSET
	var y = sim.pos_y[i]
	if sim.collision._move_blocked(x, y):
		x = sim.pos_x[i]
		y = sim.pos_y[i]
	sim.world_entities._push_slot(x, y, 70.0, 70.0, 70.0, Catalog.MITOSIS_WAIT, int(sim.tint[i]))
	sim.sfx_queue.append("mitosis")
	sim.sfx_queue.append("uplink")



## Routes a hungry agent to the nearer of a claimable apple or a resting home visit.
func _seek_food(i: int, speed: float, dt: float) -> bool:
	var apple = _nearest_apple(i, 240.0)
	var home = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i)
	var apple_d = 999999.0 if apple.is_empty() else sim.spatial._dist_i(i, float(apple.x), float(apple.y))
	var home_d = 999999.0 if home.is_empty() else sim.spatial._dist_i(i, float(home.x), float(home.y))
	if apple.is_empty() and home.is_empty():
		return false
	# Prefer the nearer option; houses feed while resting.
	if home_d + 8.0 < apple_d:
		_release_item_claims(i)
		return _approach_home_visit(i, home, speed, dt)
	if apple.is_empty():
		return _approach_home_visit(i, home, speed, dt)
	if not _claim_apple(i, apple):
		if not home.is_empty():
			return _approach_home_visit(i, home, speed, dt)
		return false
	var tx = float(apple.x)
	var ty = float(apple.y)
	if apple_d < 12.0:
		_chew_apple(i, apple, dt)
		return true
	sim.agent_move._walk(i, tx, ty, speed, dt)
	return true



## Returns the ground apple this slot owns via link_claim, or empty if stale.
func _claimed_apple(i: int) -> Dictionary:
	if i < 0 or i >= sim.link_claim.size():
		return {}
	var iid = int(sim.link_claim[i])
	if iid < 0:
		return {}
	var it: Dictionary = sim.item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_APPLE:
		return {}
	if int(it.get("claimer", -1)) != i:
		return {}
	return it



## Bite animation that refills fed and may despawn the apple when bites are exhausted.
func _chew_apple(i: int, apple: Dictionary, dt: float) -> void:
	# Eat while biting; on bite land return to idle (video: Happy stand, not Celebrate/Rotund).
	sim.act[i] = sim.ACT_EAT
	sim.act_t[i] = 0.55
	sim.dir_x[i] = 0.0
	sim.dir_y[i] = 0.0
	var progress = float(apple.get("bite", 0.0)) + dt
	apple.bite = progress
	if progress < 0.45:
		return
	apple.bite = 0.0
	var left = int(apple.get("bites_left", 1)) - 1
	apple.bites_left = left
	sim.fed[i] = 100.0
	sim.act[i] = 0
	sim.act_t[i] = 0.0
	sim.sfx_queue.append("apple")
	sim.hungry_t[i] = 0.0
	_release_item_claims(i)
	if left <= 0:
		apple.dead = true
		apple.claimer = -1
	else:
		apple.claimer = -1



## Keeps chewing an in-range claimed apple across busy or cheap agent ticks.
func _continue_eat(i: int, dt: float) -> bool:
	var apple = _claimed_apple(i)
	if apple.is_empty():
		sim.act[i] = 0
		sim.act_t[i] = 0.0
		return false
	if sim.spatial._dist_i(i, float(apple.x), float(apple.y)) >= 12.0:
		return false
	_chew_apple(i, apple, dt)
	return true



## Maintains ball play or mine commute animations when full seek AI is skipped.
func _continue_sticky_play_or_work(i: int, dt: float) -> bool:
	# Keep ACT_PLAY / ACT_WORK body clips alive when seek budget skips full AI.
	var ball = _linked_ball(i)
	if not ball.is_empty():
		sim.act[i] = sim.ACT_PLAY
		sim.act_t[i] = maxf(sim.act_t[i], 0.35)
		var bd = sim.spatial._dist_i(i, float(ball.x), float(ball.y))
		if bd >= 16.0:
			sim.agent_move._walk(i, float(ball.x), float(ball.y), sim.MOVE_SPEED, dt)
		else:
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0
			sim.amused[i] = minf(100.0, sim.amused[i] + sim.PLAY_AURA_FUN * dt)
		return true
	if i < sim.mine_job.size() and int(sim.mine_job[i]) >= 0 and sim.carry[i] == Catalog.CARRY_NONE:
		var mine: Dictionary = sim.building_by_id.get(int(sim.mine_job[i]), {})
		if mine.is_empty() or mine.dead:
			_release_mine_job(i)
			return false
		sim.act[i] = sim.ACT_WORK
		sim.act_t[i] = maxf(sim.act_t[i], 0.35)
		if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], mine) or sim.building_sim._is_guest(mine, i):
			sim.dir_x[i] = 0.0
			sim.dir_y[i] = 0.0
			return true
		var spot = sim.collision._approach_building(mine, i)
		sim.agent_move._walk(i, float(spot.x), float(spot.y), sim.MOVE_SPEED, dt)
		return true
	return false



## Resolves the ball item this agent is kicking via link_ball and claimer consistency.
func _linked_ball(i: int) -> Dictionary:
	if i < 0 or i >= sim.link_ball.size():
		return {}
	var iid = int(sim.link_ball[i])
	if iid < 0:
		return {}
	var it: Dictionary = sim.item_by_id.get(iid, {})
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_BALL:
		sim.link_ball[i] = -1
		return {}
	if int(it.get("claimer", -1)) != i:
		sim.link_ball[i] = -1
		return {}
	return it



## Walks to a dwelling rim and enters as guest for passive fed recovery indoors.
func _approach_home_visit(i: int, home: Dictionary, speed: float, dt: float) -> bool:
	if home.is_empty():
		return false
	sim.building_sim._release_claim(i)
	var edge = sim.collision._approach_building(home, i)
	var at_rim = sim.spatial._dist_i(i, float(edge.x), float(edge.y)) < 10.0
	if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], home) or at_rim:
		if sim.building_sim._enter_visit(i, home):
			sim.act[i] = sim.ACT_BATH
			sim.act_t[i] = 0.4
			return true
		return false
	sim.agent_move._walk(i, float(edge.x), float(edge.y), speed, dt)
	return true



## Finds the closest unheld apple respecting rival hunger priority and airborne items.
func _nearest_apple(i: int, max_dist: float) -> Dictionary:
	var best = {}
	var best_d = max_dist
	for it in sim.items_apple:
		if it.dead or it.held:
			continue
		if float(it.get("air", 0.0)) > 0.0:
			continue
		var who = int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if who < sim.slot_count and sim.state[who] == Catalog.ST_LIVING and not _food_priority_beats(i, who):
				continue
			if who < 0 or who >= sim.slot_count or sim.state[who] != Catalog.ST_LIVING:
				_clear_item_claimer(it)
		var d = sim.spatial._dist_i(i, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best



## Breaks apple claim ties by hunger timers and fed levels between two living agents.
func _food_priority_beats(a: int, b: int) -> bool:
	if b < 0 or b >= sim.slot_count or sim.state[b] != Catalog.ST_LIVING:
		return true
	if sim.fed[b] >= Catalog.NEED_HUNGRY:
		return true
	if sim.fed[a] >= Catalog.NEED_HUNGRY:
		return false
	if sim.hungry_t[a] > sim.hungry_t[b] + 0.05:
		return true
	if sim.hungry_t[b] > sim.hungry_t[a] + 0.05:
		return false
	if sim.fed[a] < sim.fed[b] - 0.5:
		return true
	if sim.fed[b] < sim.fed[a] - 0.5:
		return false
	return a < b



## Reserves a ground apple for this agent, preempting weaker rivals when rules allow.
func _claim_apple(i: int, apple: Dictionary) -> bool:
	if apple.is_empty():
		return false
	var who = int(apple.get("claimer", -1))
	if who == i:
		return true
	if who >= 0 and who != i and who < sim.slot_count and sim.state[who] == Catalog.ST_LIVING:
		if not _food_priority_beats(i, who):
			return false
	_release_item_claims(i)
	_bind_item_claimer(apple, i)
	return true



## Returns the kind-partitioned live item list used for fast nearby pickup queries.
func _items_of_kind(kind: int) -> Array:
	match kind:
		Catalog.ITEM_APPLE:
			return sim.items_apple
		Catalog.ITEM_BALL:
			return sim.items_ball
		Catalog.ITEM_WOOD:
			return sim.items_wood
		Catalog.ITEM_BONE:
			return sim.items_bone
		Catalog.ITEM_ORE:
			return sim.items_ore
	return sim.items



## Nearest ground item of [param kind] that is unclaimed or has a releasable claimer.
func _nearest_free_item(i: int, kind: int, max_dist: float) -> Dictionary:
	var best = {}
	var best_d = max_dist
	for it in _items_of_kind(kind):
		if it.dead or it.held or int(it.kind) != kind:
			continue
		if bool(it.get("falling_void", false)) or float(it.get("air", 0.0)) > 4.0:
			continue
		var who = int(it.get("claimer", -1))
		if who >= 0 and who != i:
			if _item_claim_holds(who):
				continue
			_clear_item_claimer(it)
		var d = sim.spatial._dist_i(i, float(it.x), float(it.y))
		if d < best_d:
			best_d = d
			best = it
	return best



## Whether another agent's claim on haul or play items should block this pickup attempt.
func _item_claim_holds(who: int) -> bool:
	# Keep the lock while this thronglet can still walk haul this tick.
	# NEED_OK thronglets also haul; dropping the lock there left every plank
	# free each frame and nobody finished the walk-pickup.
	if who < 0 or who >= sim.slot_count or sim.state[who] != Catalog.ST_LIVING:
		return false
	if sim.mito_t[who] > 0.0 or sim.shake_t[who] > 0.0:
		return false
	if not _ride_building(who).is_empty():
		return false
	if not sim.building_sim.seat_of(who).is_empty():
		return false
	if sim.fed[who] < Catalog.NEED_HUNGRY or sim.clean[who] < Catalog.NEED_SEEK or sim.amused[who] < Catalog.NEED_FUN:
		return false
	return true



## Attempts exclusive reservation of a world item for haul or ball play.
func _claim_item(i: int, item: Dictionary) -> void:
	if item.is_empty():
		return
	var who = int(item.get("claimer", -1))
	if who == i:
		return
	if who >= 0 and who != i and _item_claim_holds(who):
		return
	_release_item_claims(i)
	_bind_item_claimer(item, i)



## Writes claimer on the item and syncs link_claim/link_ball back-pointers for the slot.
func _bind_item_claimer(item: Dictionary, i: int) -> void:
	var prev = int(item.get("claimer", -1))
	if prev >= 0 and prev != i and prev < sim.link_claim.size():
		if sim.link_claim[prev] == int(item.id):
			sim.link_claim[prev] = -1
		if sim.link_ball[prev] == int(item.id):
			sim.link_ball[prev] = -1
	item.claimer = i
	if i < 0 or i >= sim.link_claim.size():
		return
	sim.link_claim[i] = int(item.id)
	sim.link_ball[i] = int(item.id) if int(item.kind) == Catalog.ITEM_BALL else -1



## Frees an item's claim and clears the prior owner's link slots when stale.
func _clear_item_claimer(item: Dictionary) -> void:
	var who = int(item.get("claimer", -1))
	item.claimer = -1
	if who < 0 or who >= sim.link_claim.size():
		return
	if sim.link_claim[who] == int(item.id):
		sim.link_claim[who] = -1
	if sim.link_ball[who] == int(item.id):
		sim.link_ball[who] = -1



## Drops all world-item reservations held by this thronglet slot.
func _release_item_claims(i: int) -> void:
	if i < 0 or i >= sim.link_claim.size():
		return
	var iid = sim.link_claim[i]
	sim.link_claim[i] = -1
	sim.link_ball[i] = -1
	if iid < 0:
		return
	var it: Dictionary = sim.item_by_id.get(iid, {})
	if not it.is_empty() and int(it.get("claimer", -1)) == i:
		it.claimer = -1



## Directs a dirty agent to an open tub or home visit for hygiene recovery.
func _seek_clean(i: int, speed: float, dt: float) -> bool:
	var tub = sim.building_sim._nearest_tub(i)
	var home = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i)
	var use_tub = false
	var target = {}
	var best = 999999.0
	if not tub.is_empty():
		best = sim.spatial._dist_i(i, float(tub.x), float(tub.y))
		target = tub
		use_tub = true
	if not home.is_empty():
		var d2 = sim.spatial._dist_i(i, float(home.x), float(home.y))
		if d2 < best:
			best = d2
			target = home
			use_tub = false
	if target.is_empty():
		sim.building_sim._release_claim(i)
		return false
	if use_tub:
		sim.building_sim._claim_tub(i, target)
		if int(target.get("occupant", -1)) != i:
			# Tub taken by someone else: don't camp at the rim walking in
			# place. Release and do something else this tick; retry next time.
			sim.building_sim._release_claim(i)
			return false
		# Tub is free (or already ours): go bathe if within reach.
		var edge = sim.collision._approach_building(target, i)
		var at_rim = sim.spatial._dist_i(i, float(edge.x), float(edge.y)) < 10.0
		if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], target) or at_rim:
			_do_bath(i, target, dt)
			return true
		sim.agent_move._walk(i, float(edge.x), float(edge.y), speed, dt)
		return true
	return _approach_home_visit(i, target, speed, dt)



## Seats the agent in a tub and raises clean until soak goals or minimum stay are met.
func _do_bath(i: int, b: Dictionary, dt: float) -> void:
	if b.is_empty():
		return
	sim.building_sim._claim_tub(i, b)
	if int(b.get("occupant", -1)) != i:
		return
	var age = float(b.get("bath_t", -1.0))
	if age < 0.0:
		b.bath_t = 0.0
		sim.sfx_queue.append("tub_in")
		sim.sfx_queue.append("splash")
	else:
		b.bath_t = age + dt
	sim.act[i] = sim.ACT_BATH
	sim.act_t[i] = 0.55
	if i < sim.seek_t.size():
		sim.seek_t[i] = 0.0
	var seat = Vector2(float(b.x), float(b.y)) + Catalog.TUB_SEAT_OFF
	sim.spatial._set_agent_pos(i, seat.x, seat.y)
	sim.dir_x[i] = 0.0
	sim.dir_y[i] = 0.0
	b.active = true
	sim.clean[i] = minf(100.0, sim.clean[i] + sim.BATH_CLEAN_RATE * dt)
	if sim.clean[i] >= sim.BATH_DONE and float(b.bath_t) >= sim.BATH_MIN_STAY:
		_finish_bath(i, b)



## Ejects a clean bather to the building rim with sparkle feedback and frees the tub.
func _finish_bath(i: int, b: Dictionary) -> void:
	var rim = sim.collision._approach_building(b, i)
	sim.building_sim._release_claim(i)
	if i < sim.seek_t.size():
		sim.seek_t[i] = 0.0
	sim.spatial._set_agent_pos(i, float(rim.x), float(rim.y))
	sim.act[i] = sim.ACT_BATH
	sim.act_t[i] = 0.35
	sim.dialogue._pop(sim.pos_x[i], sim.pos_y[i], AssetFrames.CLEAN, 1.0, i, 0.9, "bath")



## Picks a carousel with a free seat within range, skipping full rides unless already boarding.
func _nearest_roundabout(i: int, max_dist: float) -> Dictionary:
	var best = {}
	var best_d = max_dist
	var slots_n = _ride_slot_count()
	for b in sim.blds_round:
		if b.dead or bool(b.get("lifted", false)):
			continue
		# Already boarding/riding this one: keep going. Otherwise skip full rides
		# so seekers do not camp the rim walking in place (same as busy tubs).
		var mine = _is_rider(b, i) or _ride_slot_of(b, i) >= 0
		if not mine and _taken_ride_slots(b).size() >= slots_n:
			continue
		var d = sim.spatial._dist_i(i, float(b.x), float(b.y))
		if d < best_d:
			best_d = d
			best = b
	return best



## Normalizes the building's rider id array for carousel occupancy bookkeeping.
func _rider_list(b: Dictionary) -> Array:
	var raw = b.get("riders", [])
	if raw is Array:
		return raw
	return []



## True when thronglet [param i] is listed as seated on carousel building [param b].
func _is_rider(b: Dictionary, i: int) -> bool:
	for raw in _rider_list(b):
		if int(raw) == i:
			return true
	return false



## Adds or removes a thronglet from the ride roster and updates link_ride occupancy.
func _set_rider(b: Dictionary, i: int, on: bool, clear_slot: bool = true) -> void:
	var kept: Array = []
	for raw in _rider_list(b):
		if int(raw) != i:
			kept.append(int(raw))
	if on:
		kept.append(i)
		if i >= 0 and i < sim.link_ride.size():
			sim.link_ride[i] = int(b.id)
	else:
		_set_ride_age(b, i, -1.0)
		if clear_slot:
			_set_ride_slot(b, i, -1)
		if i >= 0 and i < sim.link_ride.size() and sim.link_ride[i] == int(b.id):
			sim.link_ride[i] = -1
	b.riders = kept



## Resolves which carousel this agent is riding, refreshing link_ride when needed.
func _ride_building(i: int) -> Dictionary:
	if i < 0 or i >= sim.link_ride.size():
		return {}
	var bid = sim.link_ride[i]
	if bid >= 0:
		var linked: Dictionary = sim.building_by_id.get(bid, {})
		if not linked.is_empty() and not linked.dead and not bool(linked.get("lifted", false)) and _is_rider(linked, i):
			return linked
		sim.link_ride[i] = -1
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if _is_rider(b, i):
			sim.link_ride[i] = int(b.id)
			return b
	return {}



## Removes the agent from any carousel rider list and clears link_ride.
func _clear_ride(i: int) -> void:
	if i >= 0 and i < sim.link_ride.size() and sim.link_ride[i] >= 0:
		var b: Dictionary = sim.building_by_id.get(sim.link_ride[i], {})
		if not b.is_empty() and _is_rider(b, i):
			_set_rider(b, i, false)
			return
	for b in sim.buildings:
		if _is_rider(b, i):
			_set_rider(b, i, false)



## World center of a building's footprint cells for ride geometry and approach math.
func _footprint_center_of(b: Dictionary) -> Vector2:
	var size = Catalog.footprint_for_building(int(b.kind))
	var cells = sim.building_sim._footprint_cells(float(b.x), float(b.y), size)
	if cells.is_empty():
		return Vector2(float(b.x), float(b.y))
	var acc = Vector2.ZERO
	for cell in cells:
		acc += sim.world_entities._cell_world(cell)
	return acc / float(cells.size())



## Orbit hub of the carousel using lab-tuned offset from the building anchor.
func _ride_center_of(b: Dictionary) -> Vector2:
	var car = sim._ride_cfg()
	var off: Vector2 = car.get("center_offset", Catalog.ROUND_RIDE_OFF)
	return Vector2(float(b.x), float(b.y)) + off



## Seat ring radius from carousel slot count and spacing in TiovivoLabTune.
func _ride_radius(_b: Dictionary) -> float:
	var car = sim._ride_cfg()
	return TiovivoLabTune.seat_radius(int(car.get("slots", Catalog.ROUND_RIDE_SLOTS)), float(car.get("seat_spacing", 0.0)))



## Number of simultaneous seats on the roundabout from tuned or default slot count.
func _ride_slot_count() -> int:
	return maxi(1, int(sim._ride_cfg().get("slots", Catalog.ROUND_RIDE_SLOTS)))



## Seconds this rider has been on the carousel since boarding, or -1 if not tracked.
func _ride_age_of(b: Dictionary, i: int) -> float:
	var ages: Variant = b.get("ride_age", {})
	if ages is Dictionary and ages.has(i):
		return float(ages[i])
	return -1.0



## Stores per-rider dwell time on the building for min-stay and fun completion rules.
func _set_ride_age(b: Dictionary, i: int, age: float) -> void:
	var ages: Dictionary = {}
	var raw: Variant = b.get("ride_age", {})
	if raw is Dictionary:
		ages = (raw as Dictionary).duplicate()
	if age < 0.0:
		ages.erase(i)
	else:
		ages[i] = age
	b.ride_age = ages



## Reserved seat index for this agent while approaching or riding, or -1 if none.
func _ride_slot_of(b: Dictionary, i: int) -> int:
	var slots: Variant = b.get("ride_slot", {})
	if slots is Dictionary and slots.has(i):
		return int(slots[i])
	return -1



## Assigns or clears a carousel seat reservation before boarding completes.
func _set_ride_slot(b: Dictionary, i: int, slot: int) -> void:
	var slots: Dictionary = {}
	var raw: Variant = b.get("ride_slot", {})
	if raw is Dictionary:
		slots = (raw as Dictionary).duplicate()
	if slot < 0:
		slots.erase(i)
	else:
		slots[i] = slot
	b.ride_slot = slots



## Map of occupied seat indices to living riders, optionally ignoring one agent.
func _taken_ride_slots(b: Dictionary, except_i: int = -1) -> Dictionary:
	var taken = {}
	var raw: Variant = b.get("ride_slot", {})
	if raw is Dictionary:
		for key in raw.keys():
			var who = int(key)
			if who == except_i:
				continue
			if who < 0 or who >= sim.slot_count or sim.state[who] != Catalog.ST_LIVING:
				continue
			taken[int(raw[key])] = who
	return taken



## Shortest absolute angle difference on the circle for seat scoring.
func _ang_delta(a: float, b: float) -> float:
	var d = fposmod(a - b + PI, TAU) - PI
	return absf(d)



## Chooses a free carousel seat favoring spacing from others and alignment with approach angle.
func _pick_ride_slot(b: Dictionary, approach_ang: float) -> int:
	var n = _ride_slot_count()
	var taken = _taken_ride_slots(b)
	var best = -1
	var best_score = -INF
	for slot in n:
		if taken.has(slot):
			continue
		var slot_ang = _ride_slot_ang(b, slot)
		var near = _ang_delta(slot_ang, approach_ang)
		var sep = TAU
		for other in taken.keys():
			sep = minf(sep, _ang_delta(slot_ang, _ride_slot_ang(b, int(other))))
		# Prefer max separation from seated riders; break ties toward the approach.
		var score = sep * 100.0 - near
		if taken.is_empty():
			score = -near
		if score > best_score:
			best_score = score
			best = slot
	return best



## World angle of a seat on the spinning carousel ring from lab base offset and spin.
func _ride_slot_ang(b: Dictionary, slot: int) -> float:
	# Angle follows building spin plus the tuned base offset, matching the lab.
	var car = sim._ride_cfg()
	var n = maxf(1.0, float(_ride_slot_count()))
	var base = deg_to_rad(float(car.get("slot_base_deg", 0.0)))
	return float(b.get("spin", 0.0)) + base + float(slot) * TAU / n



## World position of a carousel seat on the orbit ring around the ride center.
func _ride_slot_pos(b: Dictionary, slot: int) -> Vector2:
	var center = _ride_center_of(b)
	var ang = _ride_slot_ang(b, slot)
	var r = _ride_radius(b)
	return Vector2(center.x + cos(ang) * r, center.y + sin(ang) * r)



## Teleports the agent onto a seat facing the ring tangent when the spot is unobstructed.
func _place_on_ride_slot(i: int, b: Dictionary, slot: int) -> bool:
	var seat = _ride_slot_pos(b, slot)
	if sim.collision._ride_spot_blocked(seat.x, seat.y, b):
		return false
	var ang = _ride_slot_ang(b, slot)
	sim.spatial._set_agent_pos(i, seat.x, seat.y)
	sim.dir_x[i] = cos(ang + PI * 0.5)
	sim.dir_y[i] = sin(ang + PI * 0.5)
	return true



## Dismounts to the building approach rim and clears ride slot, age, and play action state.
func _leave_ride(i: int, b: Dictionary) -> void:
	_set_rider(b, i, false)
	_set_ride_age(b, i, -1.0)
	if int(sim.act[i]) == sim.ACT_PLAY:
		sim.act[i] = 0
		sim.act_t[i] = 0.0
	# Step off onto the approach rim. Do not teleport far away.
	var rim = sim.collision._approach_building(b, i)
	if sim.collision._move_blocked(float(rim.x), float(rim.y)):
		rim = sim.collision._approach_spot(float(b.x), float(b.y), _ride_radius(b) + 10.0, i)
	if sim.collision._move_blocked(float(rim.x), float(rim.y)):
		return
	sim.spatial._set_agent_pos(i, float(rim.x), float(rim.y))
	sim.dir_x[i] = 0.0
	sim.dir_y[i] = 0.0



## Fixed compass boarding point outside the ring for a reserved seat, not tied to spin.
func _ride_gate_pos(b: Dictionary, slot: int) -> Vector2:
	# Fixed compass gate (no spin). A spinning gate makes approachers chase forever.
	var center = _ride_center_of(b)
	var n = float(_ride_slot_count())
	var ang = float(slot) * TAU / n
	var reach = _ride_radius(b) + 14.0
	var gate = Vector2(center.x + cos(ang) * reach, center.y + sin(ang) * reach)
	if sim.collision._move_blocked(gate.x, gate.y):
		return sim.collision._approach_building(b, -1)
	return gate



## Full carousel state machine: approach gate, seat, amuse, and leave when fun goals hit.
func _do_roundabout_ride(i: int, b: Dictionary, dt: float) -> void:
	_release_item_claims(i)
	var center = _ride_center_of(b)
	var orbit_r = _ride_radius(b)
	var dx = sim.pos_x[i] - center.x
	var dy = sim.pos_y[i] - center.y
	var dist = sqrt(dx * dx + dy * dy)
	var ang = atan2(dy, dx)
	if dist < 1.0:
		ang = float(i) * 1.7
	# Approaching: keep a reserved seat and walk to that gate before stepping on.
	if dist > orbit_r + 2.0:
		if _is_rider(b, i):
			_set_rider(b, i, false, false)
		_set_ride_age(b, i, -1.0)
		var slot = _ride_slot_of(b, i)
		if slot < 0 or _taken_ride_slots(b, i).has(slot):
			slot = _pick_ride_slot(b, ang)
			if slot < 0:
				# Full: do not camp the approach rim. Seek will pick other fun.
				sim.dir_x[i] = 0.0
				sim.dir_y[i] = 0.0
				return
			_set_ride_slot(b, i, slot)
		var gate = _ride_gate_pos(b, slot)
		var gate_d = sim.spatial._dist_point(sim.pos_x[i], sim.pos_y[i], gate.x, gate.y)
		# Hold at the reserved gate, then step onto that seat only.
		if gate_d > 5.0 and not sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], b):
			sim.agent_move._walk(i, float(gate.x), float(gate.y), sim.MOVE_SPEED, dt)
			return
		var seat = _ride_slot_pos(b, slot)
		if sim.collision._ride_spot_blocked(seat.x, seat.y, b) or not _place_on_ride_slot(i, b, slot):
			# Seat unusable — drop claim and retry next tick.
			_set_ride_slot(b, i, -1)
			return
		if int(sim.act[i]) != sim.ACT_PLAY:
			sim.sfx_queue.append("round_start")
		sim.act[i] = sim.ACT_PLAY
		sim.act_t[i] = 0.55
		_set_rider(b, i, true)
		_set_ride_age(b, i, 0.0)
		sim.amused[i] = minf(100.0, sim.amused[i] + sim._ride_fun_rate() * dt)
		b.active = true
		return
	var was_rider = _is_rider(b, i)
	if int(sim.act[i]) != sim.ACT_PLAY:
		sim.sfx_queue.append("round_start")
	sim.act[i] = sim.ACT_PLAY
	sim.act_t[i] = 0.55
	var slot = _ride_slot_of(b, i)
	if slot < 0 or _taken_ride_slots(b, i).has(slot):
		slot = _pick_ride_slot(b, ang)
	if slot < 0:
		_leave_ride(i, b)
		return
	_set_ride_slot(b, i, slot)
	_set_rider(b, i, true)
	var age = _ride_age_of(b, i)
	if not was_rider or age < 0.0:
		age = 0.0
	else:
		age += dt
	_set_ride_age(b, i, age)
	if not _place_on_ride_slot(i, b, slot):
		_leave_ride(i, b)
		return
	sim.amused[i] = minf(100.0, sim.amused[i] + sim._ride_fun_rate() * dt)
	b.active = true
	if sim.amused[i] >= sim._ride_done_need() and age >= sim._ride_min_stay_need():
		_leave_ride(i, b)



## Continues an active ride or searches for balls, shows, and carousels to raise amusement.
func _tend_fun(i: int, speed: float, dt: float) -> bool:
	var riding_b = _ride_building(i)
	if not riding_b.is_empty():
		_do_roundabout_ride(i, riding_b, dt)
		return true
	return _seek_fun(i, speed, dt)



## Picks the best fun source nearby: carousel, kickball, theatre, or aura buildings.
func _seek_fun(i: int, speed: float, dt: float) -> bool:
	var round = _nearest_roundabout(i, 320.0)
	var ball = _nearest_free_item(i, Catalog.ITEM_BALL, 260.0)
	var play = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_THEATRE, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD], 320.0, i)
	var tx = 0.0
	var ty = 0.0
	var best = 999999.0
	var radius = 16.0
	var use_ball = false
	var use_round = false
	var play_kind = -1
	if not round.is_empty():
		best = sim.spatial._dist_i(i, float(round.x), float(round.y))
		tx = float(round.x)
		ty = float(round.y)
		radius = 18.0
		use_round = true
	if not ball.is_empty():
		var d_ball = sim.spatial._dist_i(i, float(ball.x), float(ball.y))
		if d_ball < best:
			best = d_ball
			tx = float(ball.x)
			ty = float(ball.y)
			radius = 16.0
			use_ball = true
			use_round = false
	if not play.is_empty():
		var d2 = sim.spatial._dist_i(i, float(play.x), float(play.y))
		if d2 < best:
			best = d2
			tx = float(play.x)
			ty = float(play.y)
			play_kind = int(play.kind)
			if sim.building_sim._is_show(play_kind):
				radius = 52.0
			else:
				radius = 22.0
			use_ball = false
			use_round = false
	if best > 900000.0:
		return false
	if use_round:
		var rim = sim.collision._approach_building(round, i)
		if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], round) or sim.spatial._dist_i(i, float(rim.x), float(rim.y)) < 10.0:
			_do_roundabout_ride(i, round, dt)
			# Boarded or still holding a seat claim.
			if _is_rider(round, i) or _ride_slot_of(round, i) >= 0:
				return true
			# Full at the gate: fall through to ball / play buildings.
			use_round = false
			best = 999999.0
			if not ball.is_empty():
				best = sim.spatial._dist_i(i, float(ball.x), float(ball.y))
				tx = float(ball.x)
				ty = float(ball.y)
				radius = 16.0
				use_ball = true
			if not play.is_empty():
				var d_play = sim.spatial._dist_i(i, float(play.x), float(play.y))
				if d_play < best:
					best = d_play
					tx = float(play.x)
					ty = float(play.y)
					play_kind = int(play.kind)
					if sim.building_sim._is_show(play_kind):
						radius = 52.0
					else:
						radius = 22.0
					use_ball = false
			if best > 900000.0:
				return false
		else:
			sim.agent_move._walk(i, float(rim.x), float(rim.y), speed, dt)
			return true
	if use_ball:
		_claim_item(i, ball)
	else:
		_release_item_claims(i)
	# Theatre: enter at the approach rim like homes/mines. Pad edges are often
	# blocked, so _approach_building sits just outside the reach ellipse and a
	# strict inside-only check leaves thronglets camping the door forever.
	# Rim must match _walk's give-up distance (TILE*1.25): walk stops before 10px.
	if not use_ball and not play.is_empty() and play_kind >= 0 and sim.building_sim._is_show(play_kind):
		var show_edge = sim.collision._approach_building(play, i)
		var at_rim = sim.spatial._dist_i(i, float(show_edge.x), float(show_edge.y)) < float(Catalog.TILE) * 1.25
		if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], play) or at_rim:
			if sim.building_sim._enter_visit(i, play):
				sim.act[i] = sim.ACT_PLAY
				sim.act_t[i] = 0.4
				return true
			return false
		sim.agent_move._walk(i, float(show_edge.x), float(show_edge.y), speed, dt)
		return true
	if not use_ball and not play.is_empty() and play_kind >= 0 and sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], play):
		sim.act[i] = sim.ACT_PLAY
		sim.act_t[i] = 0.55
		sim.amused[i] = minf(100.0, sim.amused[i] + sim.PLAY_AURA_FUN * dt)
		return true
	if best < radius:
		sim.act[i] = sim.ACT_PLAY
		sim.act_t[i] = 0.55
		if use_ball and int(ball.get("claimer", -1)) == i:
			if float(ball.get("rest", 0.0)) <= 0.0:
				var kx = float(ball.x) - sim.pos_x[i]
				var ky = float(ball.y) - sim.pos_y[i]
				var kl = sqrt(kx * kx + ky * ky)
				if kl < 1.0:
					var kick_ang = randf() * TAU
					kx = cos(kick_ang)
					ky = sin(kick_ang)
					kl = 1.0
				ball.vx = kx / kl * 96.0
				ball.vy = ky / kl * 78.0
				ball.vz = maxf(float(ball.get("vz", 0.0)), 105.0)
				ball.air = maxf(float(ball.get("air", 0.0)), 1.0)
				ball.rest = 0.7
				ball.life = sim.BALL_LIFE
				sim.amused[i] = minf(100.0, sim.amused[i] + sim.BALL_KICK_FUN)
				sim.dir_x[i] = 0.0
				sim.dir_y[i] = 0.0
				sim.dialogue._pop(sim.pos_x[i], sim.pos_y[i] - 6.0, Catalog.ICON_BALL, Catalog.BALL_SPRITE_SCALE)
				sim.sfx_queue.append("ball")
			elif best > 4.0:
				sim.agent_move._walk(i, tx, ty, speed * 1.15, dt)
			else:
				sim.dir_x[i] = 0.0
				sim.dir_y[i] = 0.0
			return true
		sim.amused[i] = minf(100.0, sim.amused[i] + sim.PLAY_AURA_FUN * dt)
		return true
	var walk_to = sim.collision._approach_building(play, i) if not use_ball and not play.is_empty() else Vector2(tx, ty)
	sim.agent_move._walk(i, float(walk_to.x), float(walk_to.y), speed, dt)
	return true



## Delivers carried ore to a factory or seeks ground ore when industry exists and hands are free.
func _try_haul(i: int, speed: float, dt: float) -> bool:
	if sim.carry[i] != Catalog.CARRY_NONE:
		_release_item_claims(i)
		return _deliver(i, speed, dt)
	if sim.building_sim._has_factory():
		var ore = _nearest_free_item(i, Catalog.ITEM_ORE, Catalog.NEAR_BUILDING)
		if not ore.is_empty():
			return _walk_pickup(i, ore, Catalog.CARRY_ORE, speed, dt)
	return false



## Walks to a claimed haul item and lifts it into carry state when in pickup range.
func _walk_pickup(i: int, item: Dictionary, carry_kind: int, speed: float, dt: float) -> bool:
	_claim_item(i, item)
	var tx = float(item.x)
	var ty = float(item.y)
	if sim.spatial._dist_i(i, tx, ty) < 8.0:
		if item.dead or item.held:
			return false
		if int(item.get("claimer", -1)) != i:
			# Stale living claim without a hold — take it and finish the grab.
			if _item_claim_holds(int(item.get("claimer", -1))):
				return false
			item.claimer = i
		sim.world_entities._set_carry(i, carry_kind, int(item.value))
		item.claimer = -1
		item.dead = true
		sim.world_entities._invalidate_item_counts()
		if carry_kind == Catalog.CARRY_WOOD:
			sim.sfx_queue.append("wood_grab")
		elif carry_kind == Catalog.CARRY_BONE:
			sim.sfx_queue.append("bone_grab")
		_release_item_claims(i)
		return true
	sim.agent_move._walk(i, tx, ty, speed, dt)
	return true



## Pathfinds ore haulers to a factory rim and feeds the building buffer on arrival.
func _deliver(i: int, speed: float, dt: float) -> bool:
	var factory = {}
	if sim.carry[i] == Catalog.CARRY_ORE:
		factory = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_FACTORY, Catalog.BLD_FACTORY2], 4000.0)
		if factory.is_empty():
			sim.world_entities._set_carry(i, Catalog.CARRY_NONE)
			return false
	else:
		sim.world_entities._set_carry(i, Catalog.CARRY_NONE)
		return false
	# Walk to a free rim spot — the factory pad center is blocked and mid-path
	# shore gaps need local inland waypoints or haulers oscillate forever.
	var spot = sim.collision._approach_building(factory, i)
	var tx = float(spot.x)
	var ty = float(spot.y)
	if sim.agent_move._haul_path_blocked(i, tx, ty):
		var via = sim.agent_move._haul_waypoint(i, tx, ty)
		tx = via.x
		ty = via.y
	sim.act[i] = sim.ACT_WORK
	sim.act_t[i] = 0.3
	sim.agent_move._walk(i, tx, ty, speed, dt)
	if (
		sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], factory)
		or sim.spatial._dist_i(i, float(spot.x), float(spot.y)) < 12.0
		or sim.spatial._dist_i(i, float(factory.x), float(factory.y)) < 72.0
	):
		sim.building_sim._factory_stack(factory, maxi(1, sim.carry_value[i]))
		factory.active = true
		sim.world_entities._set_carry(i, Catalog.CARRY_NONE)
	return true



## Effective work reach of a building kind for mine assignment and guest checks.
func _work_radius(b: Dictionary) -> float:
	var reach = Catalog.building_reach(int(b.kind))
	return maxf(reach.x, reach.y)



## Assigns or clears a thronglet's mine building job and updates per-mine worker counts.
func _set_mine_job(i: int, bid: int) -> void:
	if i < 0 or i >= sim.mine_job.size():
		return
	var prev = int(sim.mine_job[i])
	if prev == bid:
		return
	if prev >= 0:
		sim.mine_job_n[prev] = maxi(0, int(sim.mine_job_n.get(prev, 0)) - 1)
	sim.mine_job[i] = bid
	if bid >= 0:
		sim.mine_job_n[bid] = int(sim.mine_job_n.get(bid, 0)) + 1



## Clears this agent's reserved mine work slot when priorities or capacity change.
func _release_mine_job(i: int) -> void:
	_set_mine_job(i, -1)



## Count of thronglets currently assigned to dig at mine building [param b].
func _mine_jobs(b: Dictionary) -> int:
	return int(sim.mine_job_n.get(int(b.id), 0))



## Sends work-ready agents to a stocked mine with capacity, entering as guests to dig.
func _seek_mine(i: int, speed: float, dt: float) -> bool:
	# Dirty / hungry thronglets must not mine. Jobs are claimed on the walk so
	# the whole colony cannot rush the rim before ACT_WORK sticks.
	if not sim.building_sim._work_ready(i) or not sim.building_sim._has_factory() or sim.carry[i] != Catalog.CARRY_NONE:
		_release_mine_job(i)
		return false
	var mine = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		_release_mine_job(i)
		return false
	if sim.building_sim._is_guest(mine, i):
		sim.act[i] = sim.ACT_WORK
		sim.act_t[i] = 0.5
		return true
	var stock = int(mine.get("buffer", 0))
	var digging = sim.building_sim._live_guests(mine)
	# Each digger needs a reserved stock unit waiting inside.
	if stock <= digging:
		_release_mine_job(i)
		return false
	var cap = 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	var bid = int(mine.id)
	var already = int(sim.mine_job[i]) == bid
	if digging + _mine_jobs(mine) >= cap and not already:
		_release_mine_job(i)
		return false
	_set_mine_job(i, bid)
	var spot = sim.collision._approach_building(mine, i)
	var tx = float(spot.x)
	var ty = float(spot.y)
	if sim.collision._inside_building_reach(sim.pos_x[i], sim.pos_y[i], mine) or sim.spatial._dist_i(i, tx, ty) < 8.0:
		if sim.building_sim._enter_visit(i, mine):
			_release_mine_job(i)
			sim.act[i] = sim.ACT_WORK
			sim.act_t[i] = 0.5
			return true
		_release_mine_job(i)
		return false
	sim.act[i] = sim.ACT_WORK
	sim.act_t[i] = 0.5
	sim.agent_move._walk(i, tx, ty, speed, dt)
	return true



## Builds a polyline the client can draw for path debug: current cell, seek target, and BFS waypoints.
func debug_agent_path(i: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	if i < 0 or i >= sim.slot_count or sim.state[i] == Catalog.ST_VACANT:
		return pts
	var fx = sim.pos_x[i]
	var fy = sim.pos_y[i]
	pts.append(Vector2(fx, fy))
	var has_seek = i < sim.seek_t.size() and sim.seek_t[i] > 0.0
	if not has_seek and not _agent_has_hard_goal(i):
		if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) > 0.05:
			pts.append(Vector2(fx + sim.dir_x[i] * 28.0, fy + sim.dir_y[i] * 28.0))
		return pts
	var tx = sim.seek_x[i] if i < sim.seek_x.size() else fx
	var ty = sim.seek_y[i] if i < sim.seek_y.size() else fy
	var cells = sim.agent_move._bfs_path_cells(sim.spatial._cell_vec(fx, fy), sim.spatial._cell_vec(tx, ty))
	for cell in cells:
		var at = sim.world_entities._cell_world(cell)
		if pts[pts.size() - 1].distance_squared_to(at) > 0.25:
			pts.append(at)
	var goal = Vector2(tx, ty)
	var last = pts[pts.size() - 1]
	# Do not draw a fake chord through blockers when BFS stopped short of the goal.
	if last.distance_squared_to(goal) > 1.0 and sim.agent_move._axis_clear(last.x, last.y, goal.x, goal.y):
		pts.append(goal)
	return pts



## Whether this agent could start a food seek right now (apple or home visit in range).
func _debug_can_food(i: int) -> bool:
	if not _nearest_apple(i, 240.0).is_empty():
		return true
	return not sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i).is_empty()



## Whether bathing is actionable: tub seat, nearby tub building, or home visit.
func _debug_can_clean(i: int) -> bool:
	var tub_seat = sim.building_sim.seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		return true
	if not sim.building_sim._nearest_tub(i).is_empty():
		return true
	return not sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_DWELL, Catalog.BLD_FANCY], 280.0, i).is_empty()



## Whether fun seeks are viable: ride, roundabout, ball, or amusement buildings nearby.
func _debug_can_fun(i: int) -> bool:
	if not _ride_building(i).is_empty():
		return true
	if not _nearest_roundabout(i, 320.0).is_empty():
		return true
	if not _nearest_free_item(i, Catalog.ITEM_BALL, 260.0).is_empty():
		return true
	return not sim.building_sim._nearest_building_kinds(
		sim.pos_x[i], sim.pos_y[i],
		[Catalog.BLD_THEATRE, Catalog.BLD_FLOWER, Catalog.BLD_STATUE, Catalog.BLD_WOOD],
		320.0, i
	).is_empty()



## Whether hauling/mining logistics apply: already carrying or ore pickup with a factory online.
func _debug_can_haul(i: int) -> bool:
	if i < sim.carry.size() and sim.carry[i] != Catalog.CARRY_NONE:
		return true
	if not sim.building_sim._has_factory():
		return false
	return not _nearest_free_item(i, Catalog.ITEM_ORE, Catalog.NEAR_BUILDING).is_empty()



## Whether mine guest work is allowed given stock, capacity, and current mine job links.
func _debug_can_mine(i: int) -> bool:
	if not sim.building_sim._work_ready(i) or not sim.building_sim._has_factory() or sim.carry[i] != Catalog.CARRY_NONE:
		return false
	var mine = sim.building_sim._nearest_building_kinds(sim.pos_x[i], sim.pos_y[i], [Catalog.BLD_MINE, Catalog.BLD_MINE2], 360.0)
	if mine.is_empty():
		return false
	if sim.building_sim._is_guest(mine, i):
		return true
	var stock = int(mine.get("buffer", 0))
	var digging = sim.building_sim._live_guests(mine)
	if stock <= digging:
		return false
	var cap = 6 if int(mine.kind) == Catalog.BLD_MINE2 else 2
	var already = i < sim.mine_job.size() and int(sim.mine_job[i]) == int(mine.id)
	if digging + _mine_jobs(mine) >= cap and not already:
		return false
	return true



## Ranks need-driven tasks with the same gating as _tick_decide so overlays show real priorities.
func debug_agent_tasks(i: int) -> Array:
	# Mirrors _tick_decide: urgency only counts when the seek can actually run.
	var out: Array = []
	if i < 0 or i >= sim.slot_count or sim.state[i] == Catalog.ST_VACANT:
		return out
	var fed_v = sim.fed[i]
	var clean_v = sim.clean[i]
	var fun_v = sim.amused[i]
	var carrying = i < sim.carry.size() and sim.carry[i] != Catalog.CARRY_NONE
	var mining = i < sim.mine_job.size() and int(sim.mine_job[i]) >= 0
	var in_tub = false
	var on_ride = false
	var tub_seat = sim.building_sim.seat_of(i)
	if not tub_seat.is_empty() and float(tub_seat.get("bath_t", -1.0)) >= 0.0:
		in_tub = true
	if not _ride_building(i).is_empty():
		on_ride = true
	var can_food = _debug_can_food(i)
	var can_clean = _debug_can_clean(i)
	var can_fun = _debug_can_fun(i)
	var can_haul = _debug_can_haul(i)
	var can_mine = _debug_can_mine(i)
	var food_p = 0.0
	if can_food:
		if fed_v < Catalog.NEED_HUNGRY:
			food_p = 1000.0 + (Catalog.NEED_HUNGRY - fed_v)
		elif fed_v < Catalog.NEED_OK:
			food_p = 300.0 + (Catalog.NEED_OK - fed_v)
	var clean_p = 0.0
	if can_clean:
		if clean_v < Catalog.NEED_SEEK:
			clean_p = 900.0 + (Catalog.NEED_SEEK - clean_v)
		elif clean_v < Catalog.NEED_OK:
			clean_p = 300.0 + (Catalog.NEED_OK - clean_v)
		if in_tub:
			clean_p = maxf(clean_p, 950.0)
	var fun_p = 0.0
	if can_fun:
		if fun_v < Catalog.NEED_FUN:
			fun_p = 700.0 + (Catalog.NEED_FUN - fun_v)
		elif fun_v < Catalog.NEED_OK:
			fun_p = 300.0 + (Catalog.NEED_OK - fun_v)
		if on_ride:
			fun_p = maxf(fun_p, 750.0)
	var haul_p = 0.0
	if can_haul:
		haul_p = 800.0 if carrying else 50.0
	var mine_p = 0.0
	if can_mine:
		mine_p = 550.0 if mining else 500.0
	var wander_p = 10.0
	# Same gate order as _tick_decide, skipping seeks that would return false.
	var active = "wander"
	if in_tub and can_clean:
		active = "clean"
	elif on_ride and can_fun:
		active = "fun"
	elif fed_v < Catalog.NEED_HUNGRY and can_food:
		active = "food"
	elif clean_v < Catalog.NEED_SEEK and can_clean:
		active = "clean"
	elif carrying and can_haul:
		active = "haul"
	elif fun_v < Catalog.NEED_FUN and can_fun:
		active = "fun"
	elif can_haul:
		active = "haul"
	elif can_mine:
		active = "mine"
	elif fed_v < Catalog.NEED_OK or clean_v < Catalog.NEED_OK or fun_v < Catalog.NEED_OK:
		var lack_fed = Catalog.NEED_OK - fed_v if can_food else -1.0
		var lack_clean = Catalog.NEED_OK - clean_v if can_clean else -1.0
		var lack_fun = Catalog.NEED_OK - fun_v if can_fun else -1.0
		if lack_fed >= lack_clean and lack_fed >= lack_fun and lack_fed >= 0.0:
			active = "food"
		elif lack_clean >= lack_fun and lack_clean >= 0.0:
			active = "clean"
		elif lack_fun >= 0.0:
			active = "fun"
	var rows: Array = [
		{"id": "food", "label": "COMER", "priority": food_p, "active": active == "food"},
		{"id": "clean", "label": "BANARSE", "priority": clean_p, "active": active == "clean"},
		{"id": "fun", "label": "DIVERTIRSE", "priority": fun_p, "active": active == "fun"},
		{"id": "haul", "label": "ACARREAR", "priority": haul_p, "active": active == "haul"},
		{"id": "mine", "label": "MINAR", "priority": mine_p, "active": active == "mine"},
		{"id": "wander", "label": "VAGAR", "priority": wander_p, "active": active == "wander"},
	]
	for row in rows:
		# Drop targets the agent cannot act on right now (busy tub, no mine stock, …).
		if float(row.priority) <= 0.0 and str(row.id) != "wander":
			continue
		out.append(row)
	out.sort_custom(func(a, b): return float(a.priority) > float(b.priority))
	return out



## Per-frame cache of need decay multiplier from care/hard ethics mutations and moral tone.
func _decay_scale() -> float:
	if sim._decay_scale_frame == sim.frame_i:
		return sim._decay_scale_cached
	var scale = 1.0
	if bool(sim.mutations.get("care", false)) or sim.moral > 0:
		scale *= 0.9
	if bool(sim.mutations.get("hard", false)) or bool(sim.mutations.get("numb", false)) or sim.moral < 0:
		scale *= 1.12
	sim._decay_scale_frame = sim.frame_i
	sim._decay_scale_cached = scale
	return scale



