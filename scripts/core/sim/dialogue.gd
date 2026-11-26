class_name SimDialogue
extends RefCounted

## Talks, gaze, ethics, voice, barks, milestones, and narrative boot hooks.

var sim


## Stores the simulation server used for dialogue side effects.
func _init(sim_ref) -> void:
	sim = sim_ref

## Whether colony progression unlocked a thought-bubble topic.
func _thought_known(key: String) -> bool:
	return bool(sim.unlocks.get(key, false))



## Thought-bubble icon from needs, unlocks, hazards, and current action.
func _thought_icon(i: int) -> int:
	# Only desire things the colony has already discovered.
	var doing = int(sim.act[i])
	if not sim.fires.is_empty():
		for feat in sim.fires:
			if feat.dead or int(feat.kind) != Catalog.FEAT_FIRE:
				continue
			if sim.spatial._dist_i(i, float(feat.x), float(feat.y)) < 48.0:
				return Catalog.ICON_FIRE
	# Penned check is expensive (8 blocked probes); sample infrequently.
	sim.world_entities._ensure_agent_timers(i)
	if posmod(sim.frame_i + i, 45) == 0:
		sim.penned_flag[i] = 1 if _is_penned(i) else 0
	if sim.penned_flag[i] != 0:
		return Catalog.ICON_ROCK
	var tile = sim.collision._tile_at(sim.pos_x[i], sim.pos_y[i])
	if tile == Catalog.TILE_GOO:
		if _thought_known("mop"):
			return Catalog.ICON_MOP
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	# Hidden indoors: no thought bubble while a guest of a visit building.
	if sim.building_sim.indoors(i):
		return -1
	if sim.fed[i] < Catalog.NEED_HUNGRY and _thought_known("apple"):
		return Catalog.ICON_APPLE
	var in_tub = sim.link_tub[i] >= 0
	var on_ride = sim.link_ride[i] >= 0
	if sim.clean[i] < Catalog.NEED_SEEK and not in_tub:
		if _thought_known("bathtub"):
			return Catalog.ICON_TUB
		if _thought_known("sponge"):
			return Catalog.ICON_SPONGE
	if sim.amused[i] < Catalog.NEED_FUN and not on_ride:
		if _thought_known("roundabout"):
			return Catalog.ICON_ROUND
		if _thought_known("ball"):
			return Catalog.ICON_BALL
	if doing == sim.ACT_EAT and _thought_known("apple"):
		return Catalog.ICON_APPLE
	if doing == sim.ACT_BATH and _thought_known("bathtub") and not in_tub:
		return Catalog.ICON_TUB
	if doing == sim.ACT_WASH and _thought_known("sponge"):
		return Catalog.ICON_SPONGE
	if doing == sim.ACT_PLAY:
		if _thought_known("roundabout") and not on_ride:
			return Catalog.ICON_ROUND
		if _thought_known("ball"):
			return Catalog.ICON_BALL
	if doing == sim.ACT_WORK and (_thought_known("mine") or _thought_known("pickaxe")):
		return Catalog.ICON_ORE
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > sim.MITOSIS_CHARGE * 0.7:
		return Catalog.ICON_EGG
	if sim.fed[i] >= 85.0 and sim.amused[i] >= 85.0 and sim.clean[i] >= 85.0 and _thought_known("flower"):
		return Catalog.ICON_FLOWER
	return -1



## Whether an agent is boxed in by blockers (drives trapped thought icon).
func _is_penned(i: int) -> bool:
	var blocked_n = 0
	for d in [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1),
	]:
		if sim.collision._move_blocked(sim.pos_x[i] + d.x * 14.0, sim.pos_y[i] + d.y * 14.0):
			blocked_n += 1
	return blocked_n >= 6



## Rare world bark when urgent thought icons pass caps, cooldown, and visibility.
func _maybe_bark(i: int) -> void:
	if sim.barks.size() >= 2:
		sim.bark_cool[i] = Catalog.BARK_COOL
		return
	if sim.building_sim.indoors(i):
		sim.bark_cool[i] = Catalog.BARK_COOL
		return
	if sim.view_rect.size != Vector2.ZERO and not sim.view_rect.has_point(Vector2(sim.pos_x[i], sim.pos_y[i])):
		sim.bark_cool[i] = Catalog.BARK_COOL * 0.5
		return
	for bark in sim.barks:
		if int(bark.id) == i:
			sim.bark_cool[i] = Catalog.BARK_COOL
			return
	var icon = _thought_icon(i)
	if icon < 0:
		sim.bark_cool[i] = Catalog.BARK_COOL
		return
	sim.bark_cool[i] = Catalog.BARK_COOL
	var urgent = (
		icon == Catalog.ICON_FIRE
		or icon == Catalog.ICON_APPLE
		or icon == Catalog.ICON_MOP
		or icon == Catalog.ICON_ROCK
		or icon == Catalog.ICON_TUB
		or icon == Catalog.ICON_SPONGE
		or icon == Catalog.ICON_BALL
		or icon == Catalog.ICON_ROUND
		or icon == Catalog.ICON_ORE
		or icon == Catalog.ICON_DWELL
		or icon == Catalog.ICON_FANCY
		or icon == Catalog.ICON_THEATRE
	)
	if urgent:
		if randf() > 0.0015:
			return
	elif randf() > 0.0003:
		return
	var sing = ""
	var life = 1.2 if urgent else 1.4
	if bark_can_sing(i) and not ThrongClips.BARK_SING.is_empty():
		sing = str(ThrongClips.BARK_SING[randi() % ThrongClips.BARK_SING.size()])
		# Hold still for exactly one playthrough of the picked Sing clip @ 8fps.
		var frames_n = maxi(ThrongClips.frame_count(sing), 1)
		life = float(frames_n) / 8.0
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 0.0
		if i < sim.seek_t.size():
			sim.seek_t[i] = 0.0
	sim.barks.append({
		"id": i,
		"icon": icon,
		"t": life,
		"life": life,
		"x": sim.pos_x[i],
		"y": sim.pos_y[i],
		"sing": sing,
	})



## Active bark record for an agent id, if any.
func bark_of(i: int) -> Dictionary:
	for bark in sim.barks:
		if int(bark.get("id", -1)) == i:
			return bark
	return {}



## Sing clip name on an agent's bark bubble, when present.
func bark_sing_of(i: int) -> String:
	return str(bark_of(i).get("sing", ""))



## Whether agent state allows a singing bark (not bathing, carrying, etc.).
func bark_can_sing(i: int) -> bool:
	# Sing B–E only when free enough for a thought bubble (not bath/theatre/carry/…).
	if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
		return false
	if sim.held_kind == "thronglet" and sim.held_ref == i:
		return false
	if sim.mito_t[i] > 0.0 or sim.mito_charge[i] > 0.0:
		return false
	if sim.carry[i] != Catalog.CARRY_NONE:
		return false
	if sim.building_sim.indoors(i):
		return false
	if sim.world_entities.near_fire(i):
		return false
	if i < sim.penned_flag.size() and sim.penned_flag[i] != 0:
		return false
	if i < sim.cheer_t.size() and sim.cheer_t[i] > 0.0:
		return false
	if i < sim.peer_t.size() and sim.peer_t[i] > 0.0:
		return false
	if i < sim.drop_t.size() and sim.drop_t[i] > 0.0:
		return false
	match int(sim.act[i]):
		sim.ACT_EAT, sim.ACT_BATH, sim.ACT_WASH, sim.ACT_PLAY, sim.ACT_WORK:
			return false
	return true



## Periodic ambient voice SFX from sampled colony mood and movement.
func _tick_voice(delta: float) -> void:
	sim.voice_wait = maxf(0.0, sim.voice_wait - delta)
	if sim.voice_wait > 0.0 or sim.living <= 0 or sim.frozen:
		return
	var upset = -1
	var sing = -1
	var idle = -1
	var fast = 0
	var n = sim.living_ids.size()
	# Sample the living list — never scan slot_count (can be 120k).
	var step = maxi(1, n / 64)
	var start = posmod(sim.frame_i, step)
	for k in range(start, n, step):
		var i = int(sim.living_ids[k])
		if i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
			continue
		if sim.fed[i] < Catalog.NEED_HUNGRY or sim.clean[i] < 20.0:
			upset = i
		elif int(sim.act[i]) == sim.ACT_PLAY:
			sing = i
		elif absf(sim.dir_x[i]) + absf(sim.dir_y[i]) < 0.01:
			idle = i
		if absf(sim.dir_x[i]) + absf(sim.dir_y[i]) > 0.85:
			fast += 1
	sim.voice_wait = randf_range(12.0, 20.0)
	if upset >= 0:
		sim.sfx_queue.append("voice_upset")
	elif sing >= 0:
		sim.sfx_queue.append("voice_sing")
	elif idle >= 0 and randf() < 0.2:
		sim.sfx_queue.append("voice_prrr")
	if fast > 10 and randf() < 0.35:
		sim.sfx_queue.append("speed")



## Age bark bubbles and keep their world anchors on agents.
func _tick_barks(delta: float, age: bool = true) -> void:
	var kept: Array = []
	for bark in sim.barks:
		if age:
			bark.t = float(bark.t) - delta
		var i = int(bark.id)
		if float(bark.t) <= 0.0 or i < 0 or i >= sim.slot_count or sim.state[i] != Catalog.ST_LIVING:
			continue
		if sim.building_sim.indoors(i):
			continue
		bark.x = sim.pos_x[i]
		bark.y = sim.pos_y[i]
		kept.append(bark)
	sim.barks = kept



## Remove an agent's bark bubble from the live list.
func clear_bark(id: int) -> void:
	if sim.barks.is_empty():
		return
	var kept: Array = []
	for bark in sim.barks:
		if int(bark.get("id", -1)) != id:
			kept.append(bark)
	sim.barks = kept



## Current tutorial sign text row for the HUD.
func tutorial_line() -> String:
	var signs: Array[int] = [0, 1, 15]
	if sim.tutorial_i < 0 or sim.tutorial_i >= signs.size():
		return ""
	return LineBook.row("SYS.MESSAGES", signs[sim.tutorial_i])



## Advance tutorial signs; may unlock count thoughts and queue ethics talk.
func advance_tutorial() -> void:
	var signs: Array[int] = [0, 1, 15]
	if sim.tutorial_i < 0:
		return
	sim.tutorial_i += 1
	if sim.tutorial_i < signs.size():
		return
	sim.tutorial_i = -1
	_know_count()
	if sim.living > 0 and _ethics_choice("first_born") == -1:
		_queue_talk("first_born", {})



## Mark population count as known so UI thoughts can reference it.
func _know_count() -> void:
	sim.count_unknown = false



## Substitute player name tokens in dialogue and notification strings.
func address(text: String) -> String:
	if sim.player_name == "":
		return text
	return text.replace("[NAME]", sim.player_name).replace("{name}", sim.player_name)



## Open frozen modal prompting the player to enter a display name.
func _open_name_ask() -> void:
	var ask = LineBook.row("SYS.PLAYERINPUT", 0)
	sim.modal = {
		"event": "player_name",
		"step": "ask",
		"draft": "",
		"log": ["> " + ask],
		"seq": 1,
		"tree": "",
		"node": "",
	}
	_begin_gaze()



## Validate name entry and advance the name modal to confirm or error.
func submit_name(raw: String) -> void:
	if sim.modal.is_empty() or str(sim.modal.get("event", "")) != "player_name":
		return
	if str(sim.modal.get("step", "")) != "ask":
		return
	var called = raw.strip_edges()
	sim.modal["draft"] = called
	var notice = ""
	if called == "":
		notice = LineBook.row("SYS.NOTIFICATIONS", 54)
	elif not _name_chars_ok(called):
		notice = LineBook.row("SYS.MENUS", 27)
	elif _name_banned(called):
		notice = LineBook.row("SYS.MENUS", 23)
	if notice != "":
		sim.modal["log"] = ["> " + LineBook.row("SYS.PLAYERINPUT", 0), "> " + notice]
		sim.modal["seq"] = int(sim.modal.get("seq", 1)) + 1
		return
	var confirm = LineBook.row("SYS.PLAYERINPUT", 2).replace("[NAME]", called)
	sim.modal["step"] = "confirm"
	sim.modal["log"] = ["> " + confirm]
	sim.modal["seq"] = int(sim.modal.get("seq", 1)) + 1



## Handle name-modal menu indices across ask, confirm, and echo steps.
func _choose_name(index: int) -> void:
	var step = str(sim.modal.get("step", ""))
	if step == "ask":
		submit_name(str(sim.modal.get("draft", "")))
		return
	if step == "echo":
		sim.modal = {}
		sim.frozen = false
		_restore_gaze()
		_open_next_talk()
		return
	if step != "confirm":
		return
	if index != 0:
		sim.modal["step"] = "ask"
		sim.modal["draft"] = ""
		sim.modal["log"] = ["> " + LineBook.row("SYS.PLAYERINPUT", 0)]
		sim.modal["seq"] = int(sim.modal.get("seq", 1)) + 1
		return
	sim.player_name = str(sim.modal.get("draft", ""))
	var echo = LineBook.row("SYS.PLAYERINPUT", 5).replace("{0}", sim.player_name)
	if echo.begins_with("'") and echo.ends_with("'") and echo.length() >= 2:
		echo = echo.substr(1, echo.length() - 2)
	sim.modal["step"] = "echo"
	sim.modal["log"] = [echo]
	sim.modal["seq"] = int(sim.modal.get("seq", 1)) + 1



## Charset and length rules for an acceptable player display name.
func _name_chars_ok(called: String) -> bool:
	_ensure_name_rules()
	if sim._name_chars == "" or called.length() > 24:
		return false
	for i in called.length():
		if not sim._name_chars.contains(called[i]):
			return false
	return true



## Profanity filter using flattened name against banned substrings.
func _name_banned(called: String) -> bool:
	_ensure_name_rules()
	var flat = _flat_name(called)
	for ban in sim._name_bans:
		if ban.length() >= 3 and flat.contains(ban):
			return true
	return false



## Normalizes a player name for profanity checks by lowercasing and stripping separators.
func _flat_name(raw: String) -> String:
	var out = ""
	var lower = raw.to_lower()
	for i in lower.length():
		var ch = lower[i]
		if ch == " " or ch == "\t" or ch == "-" or ch == "_" or ch == ".":
			continue
		out += ch
	return out



## Lazy-loads allowed character set and banned substrings used during player naming dialogue.
func _ensure_name_rules() -> void:
	if sim._name_rules:
		return
	sim._name_rules = true
	var bans = FileAccess.open("res://data/dialogue/profanity.txt", FileAccess.READ)
	if bans != null:
		while not bans.eof_reached():
			var line = _flat_name(bans.get_line())
			if line.length() >= 3:
				sim._name_bans.append(line)
	var chars = FileAccess.open("res://data/dialogue/name_chars.txt", FileAccess.READ)
	if chars != null:
		sim._name_chars = chars.get_as_text()



## Handles gaze UI picks: player name flow, line advance, or branching DialogueBook ethics choices.
func choose(index: int) -> void:
	if sim.modal.is_empty():
		return
	if str(sim.modal.get("event", "")) == "player_name":
		_choose_name(index)
		return
	if sim.modal.has("lines"):
		_advance_lines()
		return
	var event = str(sim.modal.event)
	if not Catalog.GAZE.has(event):
		return
	var action: Dictionary = sim.modal.action if sim.modal.action is Dictionary else {}
	var gaze: Dictionary = Catalog.GAZE[event]
	if not sim.modal.has("node") or str(sim.modal.get("tree", "")) == "":
		var opened: Dictionary = DialogueBook.open_session(event)
		if opened.is_empty():
			sim.modal = {}
			sim.frozen = false
			_restore_gaze()
			_open_next_talk()
			return
		sim.modal["tree"] = opened.tree
		sim.modal["node"] = opened.node
		sim.modal["log"] = opened.log
		sim.modal["seq"] = opened.seq
	var session = {
		"tree": str(sim.modal.tree),
		"node": str(sim.modal.node),
		"log": sim.modal.log if sim.modal.log is Array else [],
		"seq": int(sim.modal.get("seq", 1)),
	}
	var choices: Array = DialogueBook.choices_of(session)
	if index < 0 or index >= choices.size():
		return
	var step: Dictionary = DialogueBook.advance(session, index)
	var edge: Dictionary = step.edge if step.edge is Dictionary else {}
	sim.modal["log"] = step.session.log
	sim.modal["node"] = step.session.node
	sim.modal["seq"] = step.session.seq
	sim.sfx_queue.append("ui")
	if not bool(step.done):
		return
	var label = str(edge.get("label", ""))
	_set_ethics(event, index, label)
	_apply_moral_edge(edge)
	sim.talked_trees[str(sim.modal.tree)] = true
	sim.modal = {}
	sim.frozen = false
	_restore_gaze()
	var allow: Array = gaze.get("allow", [])
	if allow.has(index) and not action.is_empty():
		sim.world_entities._apply_action(action)
	if event == "first_born" and sim.player_name == "":
		_open_name_ask()
		return
	_open_next_talk()



## Snapshot one agent slot for HUD debug: needs, combined mood, and living/dead status.
func inspect(id: int) -> Dictionary:
	if id < 0 or id >= sim.slot_count or sim.state[id] == Catalog.ST_VACANT:
		return {}
	var status = "VIVO"
	if sim.state[id] == Catalog.ST_DEAD:
		status = "MUERTO"
	return {
		"id": id,
		"fed": sim.fed[id],
		"amused": sim.amused[id],
		"clean": sim.clean[id],
		"happy": (sim.fed[id] + sim.amused[id] + sim.clean[id]) / 3.0,
		"status": status,
	}



## Player-facing ethics readout tying moral score to the latest colony judgment line.
func moral_line() -> String:
	if sim.ethics.is_empty():
		return "AUN NO TE JUZGAN."
	var mark = "CUIDADO" if sim.moral > 0 else "FRIO" if sim.moral < 0 else "NEUTRO"
	return "%s (%+d)  %s" % [mark, sim.moral, str(sim.ethics[sim.ethics.size() - 1].text)]



## Queues a floating feedback icon; can follow a living agent id until it expires or dies.
func _pop(x: float, y: float, icon: int, sprite_scale: float = 1.0, throng_id: int = -1, life: float = 0.55, kind: String = "") -> void:
	sim.pops.append({
		"x": x,
		"y": y,
		"t": life,
		"life": life,
		"icon": icon,
		"lift": 0.0,
		"scale": sprite_scale,
		"throng_id": throng_id,
		"kind": kind,
	})



## Advances pop lifetimes, lifts detached icons, and drops pops tied to dead agents.
func _tick_pops(dt: float, age: bool = true) -> void:
	var kept: Array = []
	for pop in sim.pops:
		var throng_id = int(pop.get("throng_id", -1))
		if age:
			pop.t = float(pop.t) - dt
			if throng_id < 0:
				pop.lift = float(pop.lift) + 22.0 * dt
		if float(pop.t) <= 0.0 or (throng_id >= 0 and (throng_id >= sim.slot_count or sim.state[throng_id] != Catalog.ST_LIVING)):
			continue
		if throng_id >= 0:
			pop.x = sim.pos_x[throng_id]
			pop.y = sim.pos_y[throng_id]
		kept.append(pop)
	sim.pops = kept



## Entry from _ready: resumes last save or starts a fresh campaign bootstrap.
func _boot_game() -> void:
	var last = sim.save_system.last_slot()
	if last >= 0 and sim.save_system.load_slot(last):
		return
	sim.world_entities._bootstrap_new()



## Locks the sim when the campaign loses its last living agent after having peaked.
func _enter_game_over() -> void:
	if sim.sandbox_mode or sim.game_over or sim.living > 0 or sim.peak <= 0:
		return
	sim.game_over = true
	sim.paused = true
	sim.frozen = false
	sim.modal = {}
	sim.talk_pending = {}
	sim.gaze_queue.clear()
	sim.player_tools.cancel_hold()
	sim.notes.append("EL ULTIMO MULTI HA MUERTO.")



## Ethics confirm path: sandbox runs tools immediately; campaign may open gaze dialogue first.
func _confirm(event: String, action: Dictionary) -> void:
	# Sandbox has no ethics dialogue; apply destructive tools immediately.
	if sim.sandbox_mode:
		if not action.is_empty():
			sim.world_entities._apply_action(action)
		return
	if not Catalog.GAZE.has(event):
		return
	var prev = _ethics_choice(event)
	var allow: Array = Catalog.GAZE[event].allow
	if prev != -1 and allow.has(prev):
		sim.world_entities._apply_action(action)
		sim.notes.append("EL THRONG LO HA NOTADO.")
		return
	_queue_talk(event, action)



## Queues a non-destructive ethics line when the player has not yet chosen on that event.
func _reflect(event: String) -> void:
	if _ethics_choice(event) != -1:
		return
	_queue_talk(event, {})



## Serializes gaze events into pending talk, avoiding duplicate modals for the same event.
func _queue_talk(event: String, action: Dictionary) -> void:
	if sim.sandbox_mode or sim.game_over or not Catalog.GAZE.has(event):
		return
	if _ethics_choice(event) != -1 and action.is_empty():
		return
	for pending in sim.gaze_queue:
		if str(pending.event) == event:
			return
	if not sim.modal.is_empty() and str(sim.modal.event) == event:
		return
	if not sim.talk_pending.is_empty() and str(sim.talk_pending.event) == event:
		return
	if sim.modal.is_empty() and sim.talk_pending.is_empty():
		_schedule_talk(event, action)
	else:
		sim.gaze_queue.append({"event": event, "action": action})



## Pops the gaze queue, skipping already-resolved ambient lines, and schedules the next modal.
func _open_next_talk() -> void:
	while not sim.gaze_queue.is_empty():
		var next: Dictionary = sim.gaze_queue.pop_front()
		var event = str(next.event)
		if _ethics_choice(event) != -1 and (next.action is Dictionary and next.action.is_empty()) and event != "ambient":
			continue
		var tree_id = str(next.get("tree", ""))
		if tree_id != "":
			_schedule_talk_tree(event, next.action if next.action is Dictionary else {}, tree_id)
		else:
			_schedule_talk(event, next.action if next.action is Dictionary else {})
		return



## Delays opening a talk modal by TALK_OPEN_DELAY unless testing skips the wait.
func _schedule_talk(event: String, action: Dictionary) -> void:
	var wait = 0.0 if sim.testing else sim.TALK_OPEN_DELAY
	if wait <= 0.0:
		_open_talk_modal(event, action)
		return
	sim.talk_pending = {"event": event, "action": action, "wait": wait}



## Counts down talk_pending and opens the modal when delay expires and UI is idle.
func _tick_talk_wait(delta: float) -> void:
	if sim.talk_pending.is_empty() or not sim.modal.is_empty() or sim.frozen or sim.game_over:
		return
	sim.talk_pending.wait = maxf(0.0, float(sim.talk_pending.wait) - delta)
	if float(sim.talk_pending.wait) > 0.0:
		return
	var event = str(sim.talk_pending.event)
	var action: Dictionary = sim.talk_pending.action if sim.talk_pending.action is Dictionary else {}
	var tree_id = str(sim.talk_pending.get("tree", ""))
	sim.talk_pending = {}
	_open_talk_modal(event, action, tree_id)



## Steps through non-branching LineBook gaze scripts and applies ethics on the final line.
func _advance_lines() -> void:
	var lines: Array = sim.modal.get("lines", [])
	var at = int(sim.modal.get("line", 0)) + 1
	sim.sfx_queue.append("ui")
	if at < lines.size():
		sim.modal["line"] = at
		sim.modal["seq"] = at + 1
		var log: Array = sim.modal.get("log", [])
		log.append("> " + str(lines[at]))
		sim.modal["log"] = log
		return
	var event = str(sim.modal.event)
	var action: Dictionary = sim.modal.action if sim.modal.action is Dictionary else {}
	var label = str(lines[0]) if not lines.is_empty() else ""
	_set_ethics(event, 0, label)
	sim.modal = {}
	sim.frozen = false
	_restore_gaze()
	var allow: Array = Catalog.GAZE[event].get("allow", [])
	if allow.has(0) and not action.is_empty():
		sim.world_entities._apply_action(action)
	_open_next_talk()



## Chooses dialogue tree, line script, or confirm tree for an event and enters gaze layout.
func _open_talk_modal(event: String, action: Dictionary, tree_override: String = "") -> void:
	var gaze: Dictionary = Catalog.GAZE.get(event, {})
	var confirm = str(gaze.get("kind", "")) == "confirm" or tree_override.begins_with("confirm")
	var opened: Dictionary = {}
	if tree_override != "":
		opened = DialogueBook.open_tree(tree_override)
	elif not confirm:
		opened = DialogueBook.open_session(event)
	if not opened.is_empty() and not DialogueBook.choices_of(opened).is_empty():
		_open_tree_modal(event, action, opened)
		return
	if not confirm:
		var lines: Array = LineBook.lines_for(event)
		if not lines.is_empty():
			sim.modal = {
				"event": event,
				"action": action,
				"lines": lines,
				"line": 0,
				"log": ["> " + str(lines[0])],
				"seq": 1,
				"tree": "",
				"node": "",
			}
			_begin_gaze()
			return
	if opened.is_empty():
		if tree_override != "":
			opened = DialogueBook.open_tree(tree_override)
		else:
			opened = DialogueBook.open_session(event)
	if opened.is_empty():
		return
	_open_tree_modal(event, action, opened)



## Binds an opened DialogueBook session into modal state and freezes colony motion for choices.
func _open_tree_modal(event: String, action: Dictionary, opened: Dictionary) -> void:
	sim.modal = {
		"event": event,
		"action": action,
		"tree": opened.tree,
		"node": opened.node,
		"log": opened.log,
		"seq": opened.seq,
	}
	_begin_gaze()



## Increments ambient talk counter when the world can accept background colony chatter.
func _queue_ambient_talk() -> void:
	# World bubbles are icon-only; ambient lines stay in the console / gaze path.
	if sim.game_over or sim.testing or sim.living <= 0 or not sim.modal.is_empty() or not sim.talk_pending.is_empty():
		return
	sim.ambient_n += 1



## Like _schedule_talk but forces a specific dialogue tree id after the standard delay.
func _schedule_talk_tree(event: String, action: Dictionary, tree_id: String) -> void:
	var wait = 0.0 if sim.testing else sim.TALK_OPEN_DELAY
	if wait <= 0.0:
		_open_talk_modal(event, action, tree_id)
		return
	sim.talk_pending = {"event": event, "action": action, "wait": wait, "tree": tree_id}



## Freezes simulation input, clears tool motion, stages thronglets, and plays talk sting.
func _begin_gaze() -> void:
	# Dialogue freeze only — do not force glitch_t (that drove POSSESSED on every talk).
	# Screen/body glitch stays for monolith / late package paths that set glitch_t themselves.
	sim.frozen = true
	_clear_action_motion()
	_line_up_gaze()
	sim.sfx_queue.append("talk")



## Staggers up to eight living agents into a readable formation facing the dialogue camera.
func _line_up_gaze() -> void:
	_restore_gaze()
	var focus = _gaze_clearing()
	var ids: Array = []
	for i in sim.slot_count:
		if sim.state[i] == Catalog.ST_LIVING:
			ids.append(i)
	ids.sort_custom(func(a, b):
		var da = Vector2(sim.pos_x[int(a)], sim.pos_y[int(a)]).distance_squared_to(focus)
		var db = Vector2(sim.pos_x[int(b)], sim.pos_y[int(b)]).distance_squared_to(focus)
		return da < db
	)
	var placed = 0
	for raw in ids:
		if placed >= 8:
			break
		var i = int(raw)
		var here_x = sim.pos_x[i]
		var here_y = sim.pos_y[i]
		var spot = _gaze_spot(focus, placed % 4, int(placed / 4))
		if is_inf(spot.x) or sim.collision._blocked(spot.x, spot.y):
			spot = _safe_gaze_spot(focus, here_x, here_y)
		if is_inf(spot.x) or sim.collision._blocked(spot.x, spot.y):
			continue
		sim.pos_x[i] = spot.x
		sim.pos_y[i] = spot.y
		sim.dir_x[i] = 0.0
		sim.dir_y[i] = 1.0
		sim.gaze_home[i] = Vector2(here_x, here_y)
		placed += 1
	_tick_barks(0.0, false)



## Searches near the view center for open ground that fits the gaze grid without canopy cover.
func _gaze_clearing() -> Vector2:
	var seed = sim.view_rect.get_center()
	if sim.view_rect.size == Vector2.ZERO:
		seed = Vector2(256, 256)
	var best = seed
	var best_score = -1
	for ring in 10:
		var rays = 1 if ring == 0 else 8
		for corner in rays:
			var ang = float(corner) * TAU / float(maxi(rays, 1))
			var at = seed + Vector2(cos(ang), sin(ang)) * float(ring) * 28.0
			if sim.collision._blocked(at.x, at.y):
				continue
			var score = 0
			for col in 4:
				for row in 2:
					var probe = at + Vector2((float(col) - 1.5) * 22.0, 36.0 + float(row) * 18.0)
					if sim.collision._blocked(probe.x, probe.y) or _gaze_covered(probe.x, probe.y):
						continue
					score += 1
			if score > best_score:
				best_score = score
				best = at
				if score >= 8:
					return best
	return best



## Grid slot position for gaze lineup, stepping outward until uncovered walkable space is found.
func _gaze_spot(focus: Vector2, col: int, row: int) -> Vector2:
	var base = focus + Vector2((float(col) - 1.5) * 22.0, 36.0 + float(row) * 18.0)
	var fallback = Vector2(INF, INF)
	for step in 24:
		for side in [-1, 0, 1]:
			var at = base + Vector2(float(side) * 14.0 + float(step) * 6.0, float(step) * 12.0)
			if sim.collision._blocked(at.x, at.y) or _gaze_taken(at.x, at.y):
				continue
			if is_inf(fallback.x):
				fallback = at
			if not _gaze_covered(at.x, at.y):
				return at
	return fallback



## Fallback placement spiral when the ideal gaze grid cell is blocked or taken.
func _safe_gaze_spot(focus: Vector2, here_x: float, here_y: float) -> Vector2:
	var seeds: Array[Vector2] = [focus, Vector2(here_x, here_y)]
	for seed in seeds:
		if not sim.collision._blocked(seed.x, seed.y) and not _gaze_taken(seed.x, seed.y):
			return seed
		for ring in 24:
			var rays = 8
			for corner in rays:
				var ang = float(corner) * TAU / float(rays)
				var at = seed + Vector2(cos(ang), sin(ang)) * float(ring + 1) * 12.0
				if sim.collision._blocked(at.x, at.y) or _gaze_taken(at.x, at.y):
					continue
				return at
	return Vector2(INF, INF)



## True if another gaze-staged agent already occupies this world point.
func _gaze_taken(x: float, y: float) -> bool:
	var at = Vector2(x, y)
	for key in sim.gaze_home.keys():
		var i = int(key)
		if i < 0 or i >= sim.slot_count:
			continue
		if Vector2(sim.pos_x[i], sim.pos_y[i]).distance_squared_to(at) < 144.0:
			return true
	return false



## Converts world feet to isometric screen space for canopy overlap tests during gaze.
func _iso_of(x: float, y: float) -> Vector2:
	var cell = Vector2(x, y) / float(Catalog.TILE) - Vector2(0.5, 0.5)
	return Vector2(16.0 * (1.0 + cell.x - cell.y), 8.0 * (1.0 + cell.x + cell.y))



## Whether tree canopies or tall buildings would hide a thronglet standing at world xy in gaze.
func _gaze_covered(x: float, y: float) -> bool:
	var me = _iso_of(x, y)
	var body = Rect2(me.x - 12.0, me.y - 22.0, 24.0, 22.0)
	var c0 = sim.spatial._cell_vec(x - 80.0, y - 48.0)
	var c1 = sim.spatial._cell_vec(x + 176.0, y + 176.0)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var feat = sim.feature_by_id.get(int(sim.feature_cell.get(Vector2i(cx, cy), -1)), {})
			if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
				continue
			if int(feat.kind) != Catalog.FEAT_TREE:
				continue
			if _canopy_hits(me, body, float(feat.x), float(feat.y), 32.0, 62.0):
				return true
	for b in sim.buildings:
		if b.dead or bool(b.get("lifted", false)):
			continue
		if _canopy_hits(me, body, float(b.x), float(b.y), 32.0, 62.0):
			return true
	return false



## Axis-aligned canopy rect intersection test in iso space for gaze and axe targeting.
func _canopy_hits(me: Vector2, body: Rect2, x: float, y: float, half_w: float, height: float) -> bool:
	var base = _iso_of(x, y)
	if base.y + 2.0 < me.y:
		return false
	var canopy = Rect2(base.x - half_w, base.y - height, half_w * 2.0, height)
	return canopy.intersects(body)



## Picks the highest tree or cosmetic feature whose canopy covers the iso point under the cursor.
func _canopy_feature_at(x: float, y: float) -> Dictionary:
	var tip = _iso_of(x, y)
	var body = Rect2(tip.x - 2.0, tip.y - 2.0, 4.0, 4.0)
	var best = {}
	var best_base_y = -1.0e9
	var c0 = sim.spatial._cell_vec(x - 64.0, y - 64.0)
	var c1 = sim.spatial._cell_vec(x + 96.0, y + 96.0)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var feat = sim.feature_by_id.get(int(sim.feature_cell.get(Vector2i(cx, cy), -1)), {})
			if feat.is_empty() or feat.dead or bool(feat.get("lifted", false)):
				continue
			var kind = int(feat.kind)
			if kind != Catalog.FEAT_TREE and kind != Catalog.FEAT_COSMETIC and kind != Catalog.FEAT_COSMETIC_BAD:
				continue
			if not _canopy_hits(tip, body, float(feat.x), float(feat.y), 32.0, 62.0):
				continue
			var base_y = _iso_of(float(feat.x), float(feat.y)).y
			if base_y >= best_base_y:
				best_base_y = base_y
				best = feat
	return best



## Teleports gaze-staged agents back to stored home positions and clears gaze_home map.
func _restore_gaze() -> void:
	for key in sim.gaze_home.keys():
		var i = int(key)
		if i < 0 or i >= sim.slot_count or sim.state[i] == Catalog.ST_VACANT:
			continue
		var home: Vector2 = sim.gaze_home[key]
		sim.pos_x[i] = home.x
		sim.pos_y[i] = home.y
	sim.gaze_home.clear()
	_tick_barks(0.0, false)



## Clears sponge/tool wash state together with per-agent action motion flags.
func _clear_wash_all() -> void:
	_clear_action_motion()



## Resets global tool handlers and action timers so dialogue freeze does not leave stuck anims.
func _clear_action_motion() -> void:
	sim.sponge_id = -1
	sim.sponge_hold = 0.0
	for i in sim.slot_count:
		sim.shake_t[i] = 0.0
		sim.act[i] = 0
		sim.act_t[i] = 0.0



## Looks up which dialogue choice index the player already committed to for an ethics event.
func _ethics_choice(event: String) -> int:
	var found = -1
	for entry in sim.ethics:
		if str(entry.event) == event:
			found = int(entry.choice)
	return found



## Records or updates one ethics journal entry after a gaze choice or line completion.
func _set_ethics(event: String, index: int, text: String) -> void:
	for entry in sim.ethics:
		if str(entry.event) == event:
			entry.choice = index
			entry.text = text
			return
	sim.ethics.append({"event": event, "choice": index, "text": text})



## Applies dialogue edge moral delta and unlocks narrative mutations with HUD notes.
func _apply_moral_edge(edge: Dictionary) -> void:
	if edge.has("moral"):
		sim.moral = clampi(sim.moral + int(edge.moral), -5, 5)
	var flag = str(edge.get("mutate", ""))
	if flag != "":
		sim.mutations[flag] = true
		if flag == "adapt":
			sim.notes.append("ALGUNOS NACEN CON TONO MORADO.")
		elif flag == "numb":
			sim.notes.append("SUS OJOS SE VUELVEN FRIOS.")
		elif flag == "hard":
			sim.notes.append("LA COLONIA SE ENDURECE.")
		elif flag == "fuel":
			sim.notes.append("APRENDEN A VER ENERGIA EN TODO.")
		elif flag == "care":
			sim.notes.append("RECUERDAN QUE LOS CUIDAS.")
		elif flag == "short_rest":
			sim.notes.append("PASAN MENOS TIEMPO EN LAS VIVIENDAS.")



## First-time unlock: sets flag, celebrates, may queue unlock talk or append a note.
func _grant(key: String, message: String = "", talk: bool = true) -> bool:
	if bool(sim.unlocks.get(key, false)):
		return false
	sim.unlocks[key] = true
	sim.unlock_serial += 1
	sim.celebrate_t = sim.CELEBRATE_DUR
	sim.sfx_queue.append("unlock_" + key)
	if talk and Catalog.UNLOCK_TALK.has(key):
		_queue_talk(str(Catalog.UNLOCK_TALK[key]), {})
	elif message != "":
		sim.notes.append(message)
	return true



## Re-evaluates progression unlocks and hooks when population peak or gems change.
func _refresh_pop_gates(announce: bool = true) -> void:
	ProgressionManager.evaluate_unlocks(sim, announce)
	if sim.sandbox_mode:
		return
	ProgressionManager.apply_progression_hooks(sim, announce)



## Static campaign ladder of population, gem, and part-two expansion thresholds.
func _milestone_defs() -> Array:
	return [
		{"kind": "pop", "n": 6},
		{"kind": "pop", "n": 12},
		{"kind": "expand", "n": 0},
		{"kind": "gem", "n": 20},
		{"kind": "pop", "n": 30},
		{"kind": "gem", "n": 20},
		{"kind": "pop", "n": 40},
		{"kind": "gem", "n": 500},
	]



## Returns the milestone requirement for current land_tier, extrapolating after the defined list.
func _milestone_at(tier: int) -> Dictionary:
	var defs = _milestone_defs()
	if tier < defs.size():
		return defs[tier]
	var n_base = tier - 7
	if (tier - 8) % 2 == 0:
		return {"kind": "pop", "n": 40 + n_base * 10}
	return {"kind": "gem", "n": 20 + n_base * 25}



## Tests whether peak population, gem peak, or part_two satisfies one milestone row.
func _milestone_met(step: Dictionary) -> bool:
	var kind = str(step.kind)
	if kind == "pop":
		return sim.peak >= int(step.n)
	if kind == "gem":
		return sim.gems_peak >= int(step.n)
	if kind == "expand":
		return sim.part_two
	return false



## Advances land tier when met, shapes island, spawns monoliths, and refreshes unlock hooks.
func _check_milestones(announce: bool = true) -> void:
	if sim.gems > sim.gems_peak:
		sim.gems_peak = sim.gems
	sim.total_gems_earned = maxi(sim.total_gems_earned, sim.gems_peak)
	if sim.sandbox_mode:
		return
	if sim.peak >= 25:
		var mono1 = false
		for feat in sim.features:
			if not feat.dead and int(feat.kind) == Catalog.FEAT_MONOLITH and int(feat.get("ore", 0)) == 1:
				mono1 = true
				break
		var bug = bool(sim.unlocks.get("bug", false))
		var spawned1 = bool(sim.monolith_tier_spawned.get(1, false))
		# Migración/reparación: bug huérfano de progresión antigua o monolito marcado sin entidad.
		if bug and not spawned1:
			sim.unlocks["bug"] = false
			bug = false
		if spawned1 and not bug and not mono1:
			sim.monolith_tier_spawned.erase(1)
		_ensure_monolith(1)
	var grew = false
	var guard = 0
	while _milestone_met(_milestone_at(sim.land_tier)) and guard < 64:
		sim.land_tier += 1
		grew = true
		guard += 1
	ProgressionManager.evaluate_unlocks(sim, announce)
	if not grew:
		return
	var added = sim.island_gen.shape_island()
	if announce and added > 0:
		sim.notes.append("LA ISLA CRECE.")



## Single HUD goal string for tutorial beats, milestones, or sandbox build checklist.
func goal_line() -> String:
	if sim.sandbox_mode:
		return "SANDBOX  ISLA %d" % sim.land_tier
	if sim.living <= 0 and sim.world_entities._has_egg():
		return "AYUDA AL HUEVO A ECLOSIONAR"
	if sim.peak < 2:
		return "CUIDA: COMIDA, LIMPIEZA Y JUEGO HASTA LA MITOSIS"
	if not bool(sim.unlocks.get("axe", false)):
		return "CRECE LA COLONIA  %d/6" % mini(sim.peak, 6)
	if sim.trees_chopped <= 0:
		return "TALA UN ARBOL CON EL HACHA"
	if sim.stumps_cleared <= 0:
		return "QUITA EL TOCON CON EL MARTILLO"
	if not sim.building_sim._has_building(Catalog.BLD_TUB):
		return _goal_build("CONSTRUYE UNA BANERA", int(Catalog.BUILD_INFO[Catalog.BLD_TUB].wood))
	if not sim.building_sim._has_building(Catalog.BLD_APPLE):
		return _goal_build("PLANTA UN MANZANO", int(Catalog.BUILD_INFO[Catalog.BLD_APPLE].wood))
	if not sim.building_sim._has_building(Catalog.BLD_ROUND):
		return _goal_build("COLOCA UN TIOVIVO", int(Catalog.BUILD_INFO[Catalog.BLD_ROUND].wood))
	if sim.peak < 12:
		return "CRECE LA COLONIA  %d/12" % mini(sim.peak, 12)
	if not sim.part_two:
		return "HAZ CRECER LA COLONIA PARA EXPANDIR LA ISLA"
	var sand = _sandbox_goal()
	if sand != "":
		return sand
	var step: Dictionary = _milestone_at(sim.land_tier)
	var kind = str(step.kind)
	var n = int(step.n)
	if kind == "pop":
		return "EXPANDE  %d/%d MULTIS" % [mini(sim.peak, n), n]
	if kind == "gem":
		if bool(sim.unlocks.get("mine", false)) and sim.world_entities.count_item(Catalog.ITEM_ORE) > 0:
			return "JUNTA ENERGIA  %d/%d  (MARTILLO EN EL MINERAL)" % [mini(sim.gems_peak, n), n]
		if n >= 100 and bool(sim.unlocks.get("mine", false)):
			return "JUNTA ENERGIA  %d/%d  (MINA EN NODO → MARTILLO EN MINERAL)" % [mini(sim.gems_peak, n), n]
		return "JUNTA ENERGIA  %d/%d  (MARTILLO: ROCA → MINERAL)" % [mini(sim.gems_peak, n), n]
	if kind == "expand":
		return "HAZ CRECER LA COLONIA PARA EXPANDIR LA ISLA"
	return "EXPANSION LIBRE  %d MULTIS · %d ENERGIA" % [sim.living, sim.gems]



## Post-market sandbox build order hints (market, factories, theatre) when milestones are done.
func _sandbox_goal() -> String:
	# Building goals only; land growth keeps using milestones forever.
	if not sim.building_sim._has_building(Catalog.BLD_MARKET):
		return _goal_build("COLOCA EL MERCADO", int(Catalog.BUILD_INFO[Catalog.BLD_MARKET].wood))
	if not sim.building_sim._has_factory():
		if not bool(sim.unlocks.get("factory", false)):
			var need = int(Catalog.MARKET.factory.cost)
			return "COMPRA LA FABRICA  %d/%d ENERGIA" % [mini(sim.gems, need), need]
		return _goal_place("CONSTRUYE UNA FABRICA", "factory")
	if not bool(sim.unlocks.get("theatre", false)):
		var need_t = int(Catalog.MARKET.theatre.cost)
		return "COMPRA EL TEATRO  %d/%d ENERGIA" % [mini(sim.gems, need_t), need_t]
	if not sim.building_sim._has_building(Catalog.BLD_THEATRE):
		return _goal_place("CONSTRUYE EL TEATRO", "theatre")
	if not bool(sim.unlocks.get("factory2", false)):
		var need_f2 = int(Catalog.MARKET.factory2.cost)
		return "COMPRA FABRICA II  %d/%d ENERGIA" % [mini(sim.gems, need_f2), need_f2]
	return ""



## Formats a wood-gathering sub-goal before a named construction step.
func _goal_build(label: String, cost: int) -> String:
	if cost <= 0:
		return label
	var have = sim.world_entities.count_item(Catalog.ITEM_WOOD)
	if have < cost:
		return "TALA MADERA  %d/%d  LUEGO %s" % [have, cost, label]
	return "%s  (%d MADERA)" % [label, cost]



## Formats gem or wood placement goals using ProgressionManager costs for an unlock id.
func _goal_place(label: String, unlock_id: String) -> String:
	var cost = ProgressionManager.placement_cost(sim, unlock_id)
	var resource = str(cost.get("resource", ""))
	var amount = int(cost.get("amount", 0))
	if amount <= 0 or resource == "":
		return label
	if resource == "gem":
		if sim.gems < amount:
			return "JUNTA ENERGIA  %d/%d  LUEGO %s" % [sim.gems, amount, label]
		return "%s  (%d ENERGIA)" % [label, amount]
	if resource == "wood":
		return _goal_build(label, amount)
	return label



## Resolves wood and gem price for placing a building kind in the current mode and unlock state.
func _building_costs(kind: int) -> Dictionary:
	var wood_cost = 0
	var gem_cost = 0
	if sim.sandbox_mode:
		return {"wood": 0, "gem": 0}
	if not Catalog.BUILD_INFO.has(kind):
		return {"wood": 0, "gem": 0}
	var info: Dictionary = Catalog.BUILD_INFO[kind]
	wood_cost = int(info.wood)
	var cost = ProgressionManager.placement_cost(sim, str(info.unlock))
	if str(cost.get("resource", "")) == "gem":
		gem_cost = int(cost.get("amount", 0))
	elif str(cost.get("resource", "")) == "wood":
		wood_cost = int(cost.get("amount", 0))
	return {"wood": wood_cost, "gem": gem_cost}



## Shop gate before placement: compares cached building costs to gems and wood stock.
func _can_afford_building(kind: int) -> bool:
	var costs = _building_costs(kind)
	if int(costs.gem) > 0 and sim.gems < int(costs.gem):
		return false
	if int(costs.wood) > 0 and sim.world_entities.count_item(Catalog.ITEM_WOOD) < int(costs.wood):
		return false
	return true



## Flips campaign to expansion phase, grants market-related unlocks, and seeds surface ore.
func _enter_part_two(reason: String, talk_market: bool = true) -> void:
	var first = not sim.part_two
	sim.part_two = true
	_grant("market", "", talk_market)
	_grant("flower", "", false)
	_grant("sculpture", "", false)
	if first:
		sim.world_entities._seed_early_ore(6)
		sim.notes.append("EL MERCADO ESTA LISTO. COMPRA EL PICO Y LO DEMAS ALLI.")
		if reason != "":
			sim.notes.append(reason)
	_check_milestones()



## Spawns tiered monolith features once progression allows, optionally opening reveal dialogue.
func _ensure_monolith(tier: int) -> void:
	if bool(sim.monolith_tier_spawned.get(tier, false)):
		return
	if tier == 1 and bool(sim.unlocks.get("bug", false)):
		return
	if tier == 2 and bool(sim.unlocks.get("nuke", false)):
		return
	var x = 168.0 + float(tier) * 78.0
	var y = 168.0
	if sim.collision._blocked(x, y):
		x = 256.0
		y = 150.0 + float(tier) * 20.0
	var feat = sim.world_entities._add_feature(Catalog.FEAT_MONOLITH, x, y, 4, tier)
	if feat.is_empty():
		return
	sim.monolith_tier_spawned[tier] = true
	feat.spawn_progress = 0.0
	feat.spawn_dur = 1.4
	feat.age = 0.0
	feat.triggered = false
	feat.particle_t = 0.0
	sim.notes.append("UN MONOLITO HA APARECIDO.")
	sim.sfx_queue.append("monolith_in")
	sim.sfx_queue.append("monolith_reveal")
	# Cinematic reveal so the player doesn't miss it.
	if not sim.testing and sim.modal.is_empty() and sim.talk_pending.is_empty() and bool(sim.unlocks.get("monolith_reveal_cinematic", true)):
		sim.unlocks["monolith_reveal_cinematic"] = false
		var lines: Array = LineBook.lines_for("monolith_appear")
		if lines.is_empty():
			lines = ["Un monolito emerge del suelo..."]
		sim.modal = {
			"event": "monolith_appear",
			"action": {},
			"lines": lines,
			"line": 0,
			"log": ["> " + str(lines[0])],
			"seq": 1,
			"tree": "",
			"node": "",
			"focus_x": x,
			"focus_y": y,
		}
		sim.frozen = true
		_begin_gaze()



## Agent contact grants bug or nuke tools, triggers glitch beat, and removes the monolith.
func _touch_monolith(feat: Dictionary) -> void:
	if feat.is_empty() or feat.get("dead", false):
		return
	sim.glitch_t = maxf(sim.glitch_t, 0.75)
	var tier = int(feat.ore)
	if tier == 1:
		_grant("bug", "EL MONOLITO ENTREGA EL BICHO. ABRE UN CUERPO Y DEJA HUESO.")
	elif tier == 2:
		_grant("nuke", "EL MONOLITO ENTREGA EL TERMAL. LIMPIA UN SECTOR. LA PARTIDA SIGUE.")
	sim.world_entities._kill_feature(feat)
	sim.sfx_queue.append("monolith")



## Marks every catalog and market unlock true for sandbox tooling and cheat starts.
func _unlock_all() -> void:
	_init_unlocks()
	for key in sim.unlocks.keys():
		sim.unlocks[key] = true
	for id in ProgressionCatalog.all_ids():
		sim.unlocks[str(id)] = true
	for key in Catalog.MARKET.keys():
		sim.unlocks[str(key)] = true
	sim.unlocks["camera"] = true
	sim.unlocks["flower"] = true
	sim.unlocks["sculpture"] = true
	sim.unlock_serial += 1



## Player click on egg advances hatch counter, shake feedback, and crack audio.
func _help_egg(it: Dictionary) -> void:
	if it.is_empty() or it.dead or int(it.kind) != Catalog.ITEM_EGG:
		return
	if float(it.get("air", 0.0)) > 0.0:
		return
	it.hatch = int(it.get("hatch", 0)) + 1
	it.shake = 0.35
	sim.sfx_queue.append("egg_crack")
	if int(it.hatch) >= int(it.get("need", sim.EGG_NEED)):
		_hatch_egg(it)
	elif int(it.hatch) == 1:
		sim.notes.append("SIGUE TOCANDALO. QUIERE NACER.")



## Finishes egg: removes item, spawns first thronglet if colony empty, opens first_born talk.
func _hatch_egg(it: Dictionary) -> void:
	if it.is_empty() or it.dead:
		return
	var x = float(it.x)
	var y = float(it.y)
	it.dead = true
	if sim.hand_id == int(it.id):
		sim.hand_id = -1
	if sim.peak > 0 or sim.living > 0:
		return
	var id = sim.world_entities._push_slot(x, y, 50.0, 50.0, 50.0, 4.0, 0)
	if id >= 0:
		sim.shake_t[id] = 0.45
	_know_count()
	sim.sfx_queue.append("egg_hatch")
	sim.sfx_queue.append("hatch")
	if sim.tutorial_i < 0:
		_queue_talk("first_born", {})



## Sets the default tool and building unlock table for a new colony.
func _init_unlocks() -> void:
	sim.unlocks = {
		"apple": true,
		"ball": true,
		"sponge": true,
		"camera": true,
		"bathtub": false,
		"apple_tree": false,
		"roundabout": false,
		"axe": false,
		"hammer": false,
		"bug": false,
		"market": false,
		"pickaxe": false,
		"mine": false,
		"dwelling": false,
		"factory": false,
		"chainsaw": false,
		"theatre": false,
		"factory2": false,
		"mine2": false,
		"fancy": false,
		"grabber": false,
		"swarm": false,
		"mop": false,
		"tnt": false,
		"nuke": false,
		"flower": false,
		"sculpture": false,
	}



