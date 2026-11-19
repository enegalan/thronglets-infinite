extends Node
class_name MediaController

var host: Node2D

var sfx_bank := {}
var sfx_pool: Array = []
var music: AudioStreamPlayer
var amb: AudioStreamPlayer
var sting: AudioStreamPlayer
var music_mode := ""
var spot_mode := ""
var bird_wait := 8.0
var logo_video_playing := false

var video_played := {}
var video_player: VideoStreamPlayer
var video_from_title := false
var video_from_library := false

var captions_label: Label
var captions_layer: CanvasLayer
var captions_on := true
var captions_lines: Array = []
var captions_ends: Array = []
var captions_index := -1
var sfx_vol := 1.0
var music_vol := 1.0


func setup(p_host: Node2D) -> void:
	host = p_host


func build_audio() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	add_child(music)
	amb = AudioStreamPlayer.new()
	amb.bus = "Master"
	add_child(amb)
	sting = AudioStreamPlayer.new()
	sting.bus = "Master"
	add_child(sting)
	for i in 8:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_pool.append(player)
	_fill_bank()
	_apply_volumes()


func _fill_bank() -> void:
	sfx_bank["deflesh"] = _clips(PackedStringArray(["deflesh_a.wav"]))
	sfx_bank["crush"] = _clips(PackedStringArray(["thronglet_crush.wav"]))
	sfx_bank["fire_start"] = _clips(_seq("sfx_fire_start_", 1, 5))
	sfx_bank["fire_out"] = _clips(_seq("sfx_fire_extinguish_", 1, 5))
	sfx_bank["heal"] = _clips(_seq("sfx_healerHeart_activate_", 1, 6))
	sfx_bank["monolith_in"] = _clips(PackedStringArray(["sfx_monolith_appear.wav"]))
	sfx_bank["monolith"] = _clips(PackedStringArray(["sfx_monolith_interact.wav"]))
	sfx_bank["unlock"] = _clips(PackedStringArray(["sfx_general_unlock.wav"]))
	sfx_bank["unlock_axe"] = _clips(PackedStringArray(["sfx_axe_unlock.wav"]))
	sfx_bank["unlock_hammer"] = _clips(PackedStringArray(["sfx_hammer_unlock.wav"]))
	sfx_bank["unlock_pickaxe"] = _clips(PackedStringArray(["sfx_pickaxe_unlock.wav"]))
	sfx_bank["unlock_mop"] = _clips(PackedStringArray(["sfx_mop_unlock.wav"]))
	sfx_bank["unlock_chainsaw"] = _clips(PackedStringArray(["sfx_chainsaw_unlock.wav"]))
	sfx_bank["unlock_grabber"] = _clips(PackedStringArray(["sfx_grabber_unlock.wav"]))
	sfx_bank["unlock_nuke"] = _clips(PackedStringArray(["sfx_nuke_unlock.wav"]))
	sfx_bank["unlock_tnt"] = _clips(PackedStringArray(["sfx_dynamite_unlock.wav"]))
	sfx_bank["unlock_bathtub"] = _clips(PackedStringArray(["sfx_bathtub_unlock.wav"]))
	sfx_bank["unlock_roundabout"] = _clips(PackedStringArray(["sfx_roundabout_unlock.wav"]))
	sfx_bank["unlock_apple_tree"] = _clips(PackedStringArray(["sfx_tree_apple_unlock.wav"]))
	sfx_bank["unlock_fire"] = _clips(PackedStringArray(["sfx_fire_unlock.wav"]))
	sfx_bank["unlock_bug"] = _clips(PackedStringArray(["sfx_ladybug_unlock.wav"]))
	sfx_bank["ui"] = _clips(PackedStringArray(["ui_click_messy.wav"]))
	sfx_bank["locked"] = _clips(PackedStringArray(["ui_tool_unavailable.wav"]))
	sfx_bank["error"] = _clips(PackedStringArray(["ui_error.wav"]))
	sfx_bank["talk"] = _clips(PackedStringArray(["sfx_text_bubble_open.wav"]))
	sfx_bank["bird"] = _clips(_seq("ambScatter_act1n2_bird_", 1, 8))
	sfx_bank["voice_prrr"] = _clips(_seq("vo_thronglet_prrr_", 1, 13))
	sfx_bank["voice_sing"] = _clips(_seq("vo_thronglet_sing_", 1, 6))
	sfx_bank["voice_sing"].append_array(_clips(_seq("vo_throng_sing_group_small_", 1, 13)))
	sfx_bank["dialogue_in"] = _clips(_seq("ui_dialogue_frame_in_", 1, 7))
	sfx_bank["dialogue_out"] = _clips(_seq("ui_dialogue_frame_out_", 1, 8))
	sfx_bank["console"] = _clips(_seq("ui_console_new_line_", 1, 4))
	sfx_bank["console_select"] = _clips(PackedStringArray(["ui_console_select.wav", "ui_console_prompt.wav"]))
	sfx_bank["speed"] = _clips(_seq("sfx_thronglet_speed_run_", 1, 6))
	sfx_bank["superore"] = _clips(_seq("sfx_superOre_lift_", 1, 6))
	sfx_bank["superore"].append_array(_clips(_seq("sfx_superOre_drop_", 1, 4)))
	sfx_bank["splash"] = _clips(_seq("sfx_water_splash_", 1, 4))
	sfx_bank["uplink"] = _clips(_seq("sfx_uplink_add_negative_", 1, 3))
	sfx_bank["uplink"].append_array(_clips(_seq("sfx_uplink_add_positive_", 1, 3)))
	sfx_bank["uplink"].append_array(_clips(_seq("sfx_uplink_add_thronglet_single_", 1, 3)))
	sfx_bank["gameover"] = _clips(PackedStringArray([
		"sfx_data_overload_gameOver_1stPopUp_head.wav",
		"sfx_data_overload_gameOver_1stPopUp_lp.wav",
	]))
	sfx_bank["gameover"].append_array(_clips(_seq("sfx_data_overload_gameOver_popUp_other_", 1, 6)))
	sfx_bank["monolith_reveal"] = _clips(PackedStringArray(["monolith_reveal_nobeat_nobar.ogg"]))
	sfx_bank["nuked"] = _clips(PackedStringArray(["thronglets_nuked_nobpm_nobar.ogg"]))
	sfx_bank["artifact_finale"] = _clips(PackedStringArray(["artifact_finale_140bpm_44bar.ogg"]))
	sfx_bank["finale_outro"] = _clips(PackedStringArray(["finale_outro.ogg"]))
	sfx_bank["code_layer"] = _clips(PackedStringArray([
		"code_layer_in_a.ogg",
		"code_layer_loop_120bpm_23bar.ogg",
		"code_layer_out_a.ogg",
	]))
	# --- Ambiences ---
	sfx_bank["amb_spot_market_lp"] = _clips(PackedStringArray(["amb_spot_market_lp.ogg"]))
	sfx_bank["amb_spot_mine_lp"] = _clips(PackedStringArray(["amb_spot_mine_lp.wav"]))
	sfx_bank["amb_spot_mountainVoidOpening_lp"] = _clips(PackedStringArray(["amb_spot_mountainVoidOpening_lp.wav"]))
	sfx_bank["amb_spot_pollution"] = _clips(PackedStringArray(["amb_spot_pollution.ogg"]))
	sfx_bank["ambBed_act1n2_barrenWind"] = _clips(PackedStringArray(["ambBed_act1n2_barrenWind.ogg"]))
	sfx_bank["ambBed_act1n2_softWindBirds_lp"] = _clips(PackedStringArray(["ambBed_act1n2_softWindBirds_lp.ogg"]))
	sfx_bank["ambBed_act3_lp"] = _clips(PackedStringArray(["ambBed_act3_lp.ogg"]))
	sfx_bank["throngletville_amb_st"] = _clips(PackedStringArray(["throngletville_amb_st.ogg"]))
	sfx_bank["venice_three_84dot5bpm_58bar"] = _clips(PackedStringArray(["venice_three_84dot5bpm_58bar.ogg"]))

	# --- Music and stingers ---
	sfx_bank["music_title"] = _clips(PackedStringArray(["thronglets_title_theme_180bpm_24bar.ogg"]))
	sfx_bank["music_megafm_a"] = _clips(PackedStringArray(["thronglets_megafm_a_140bpm_72bar.ogg"]))
	sfx_bank["music_megafm_b"] = _clips(PackedStringArray(["thronglets_megafm_b_140bpm_88bar.ogg"]))
	sfx_bank["music_fieldwork"] = _clips(PackedStringArray(["fieldwork_140bpm_108bar.ogg"]))
	sfx_bank["music_wasteland_one"] = _clips(PackedStringArray(["wasteland_one_160bpm_134bar.ogg"]))
	sfx_bank["music_wasteland_two"] = _clips(PackedStringArray(["wasteland_part_two_160bpm_156bar.ogg"]))
	sfx_bank["music_toward_artifact"] = _clips(PackedStringArray(["toward_the_artifact_140bpm_208bar.ogg"]))
	sfx_bank["music_finale"] = _clips(PackedStringArray(["thronglets_finale_76bpm_74bar.ogg"]))
	sfx_bank["music_artifact_finale"] = _clips(PackedStringArray(["artifact_finale_140bpm_44bar.ogg"]))
	sfx_bank["music_actIII_millions_A"] = _clips(PackedStringArray(["actIII_millions_oneshot_A.ogg"]))
	sfx_bank["music_actIII_millions_B"] = _clips(PackedStringArray(["actIII_millions_oneshot_B.ogg"]))
	sfx_bank["music_actIII_millions_C"] = _clips(PackedStringArray(["actIII_millions_oneshot_C.ogg"]))
	sfx_bank["music_artifact_reveal"] = _clips(PackedStringArray(["artifact_reveal_140bpm_10bar.ogg"]))
	sfx_bank["music_artifact_hum"] = _clips(PackedStringArray(["artifact_hum_loop.ogg"]))
	sfx_bank["music_nuked"] = _clips(PackedStringArray(["thronglets_nuked_nobpm_nobar.ogg"]))
	sfx_bank["music_actii_intro"] = _clips(PackedStringArray(["act_ii_intro_welcome_progress_nobpm_nobar.ogg"]))
	sfx_bank["music_wasteland_intro"] = _clips(PackedStringArray(["wasteland_intro_oneshot.ogg"]))
	sfx_bank["music_code_layer_in"] = _clips(PackedStringArray(["code_layer_in_a.ogg"]))
	sfx_bank["music_code_layer_loop"] = _clips(PackedStringArray(["code_layer_loop_120bpm_23bar.ogg"]))
	sfx_bank["music_code_layer_out"] = _clips(PackedStringArray(["code_layer_out_a.ogg"]))
	sfx_bank["music_tnt_multmel"] = _clips(PackedStringArray(["tnt_multmel_108bbpm_88bar.ogg"]))
	sfx_bank["music_finale_outro"] = _clips(PackedStringArray(["finale_outro.ogg"]))

	# --- UI ---
	sfx_bank["ui_button_click"] = _clips(PackedStringArray(["code_layer_in_a.ogg"]))
	sfx_bank["ui_game_continue"] = _clips(PackedStringArray(["ui_game_continue.wav"]))
	sfx_bank["ui_game_continue_broken"] = _clips(PackedStringArray(["ui_game_continue_broken.wav"]))
	sfx_bank["ui_click_messy_0"] = _clips(PackedStringArray(["ui_click_messy_0.wav"]))
	sfx_bank["ui_click_messy"] = _clips(PackedStringArray(["ui_click_messy.wav"]))
	sfx_bank["ui_console_prompt"] = _clips(PackedStringArray(["ui_console_prompt.wav"]))
	sfx_bank["ui_dialogue_frame_in"] = _clips(_seq("ui_dialogue_frame_in_", 1, 7))
	sfx_bank["ui_dialogue_frame_out"] = _clips(_seq("ui_dialogue_frame_out_", 1, 8))
	sfx_bank["ui_droplet_up"] = _clips(PackedStringArray(["ui_droplet_up.wav"]))
	sfx_bank["ui_error"] = _clips(PackedStringArray(["ui_error.wav"]))
	sfx_bank["ui_fm_bump"] = _clips(PackedStringArray(["ui_fm_bump.wav"]))
	sfx_bank["ui_slide_a"] = _clips(PackedStringArray(["ui_slide_a.wav"]))
	sfx_bank["ui_tool_unavailable"] = _clips(PackedStringArray(["ui_tool_unavailable.wav"]))
	sfx_bank["ui_act2_tutorial_window_open"] = _clips(PackedStringArray(["ui_act2_tutorial_window_open.wav"]))
	sfx_bank["ui_act2_tutorial_window_close"] = _clips(PackedStringArray(["ui_act2_tutorial_window_close.wav"]))
	sfx_bank["ui_act2_tutorial_window_lp"] = _clips(PackedStringArray(["ui_act2_tutorial_window_lp.wav"]))

	_fill_tools_and_misc()
	_fill_loose_clips()
	sfx_bank["voice_upset"] = _clips(PackedStringArray([
		"vo_thronglet_upset_04.wav", "vo_thronglet_upset_06.wav", "vo_thronglet_upset_09.wav",
		"vo_thronglet_upset_11.wav", "vo_thronglet_upset_12.wav",
	]))


func _fill_tools_and_misc() -> void:
	# --- Tools and constructions ---
	sfx_bank["sfx_axe_unlock"] = _clips(PackedStringArray(["sfx_axe_unlock.wav"]))
	sfx_bank["sfx_bathtub_enter"] = _clips(_seq("sfx_bathtub_enter_", 1, 6))
	sfx_bank["sfx_bathtub_exit"] = _clips(_seq("sfx_bathtub_exit_", 1, 6))
	sfx_bank["sfx_bathtub_place"] = _clips(_seq("sfx_bathtub_place_", 1, 5))
	sfx_bank["sfx_bathtub_unlock"] = _clips(PackedStringArray(["sfx_bathtub_unlock.wav"]))
	sfx_bank["sfx_camera_move_lp"] = _clips(PackedStringArray(["sfx_camera_move_lp.wav"]))
	sfx_bank["sfx_chainsaw_cut"] = _clips(_seq("sfx_chainsaw_cut_", 1, 4))
	sfx_bank["sfx_chainsaw_unlock"] = _clips(PackedStringArray(["sfx_chainsaw_unlock.wav"]))
	sfx_bank["sfx_computer_loading_windows_appear_lp"] = _clips(PackedStringArray(["sfx_computer_loading_windows_appear_lp.wav"]))
	sfx_bank["sfx_computer_skipButton_click"] = _clips(PackedStringArray(["sfx_computer_skipButton_click.wav"]))
	sfx_bank["sfx_cutscene_nuke_result_lp_st"] = _clips(PackedStringArray(["sfx_cutscene_nuke_result_lp_st.wav"]))
	sfx_bank["sfx_dynamite_activate"] = _clips(PackedStringArray(["sfx_dynamite_activate.wav"]))
	sfx_bank["sfx_dynamite_explode_st"] = _clips(PackedStringArray(["sfx_dynamite_explode_st.wav"]))
	sfx_bank["sfx_dynamite_place"] = _clips(PackedStringArray(["sfx_dynamite_place.wav"]))
	sfx_bank["sfx_dynamite_select"] = _clips(PackedStringArray(["sfx_dynamite_select.wav"]))
	sfx_bank["sfx_dynamite_unlock"] = _clips(PackedStringArray(["sfx_dynamite_unlock.wav"]))
	sfx_bank["sfx_eden_artifact_presence_lp"] = _clips(PackedStringArray(["sfx_eden_artifact_presence_lp.wav"]))
	sfx_bank["sfx_eden_artifact_reach_st"] = _clips(PackedStringArray(["sfx_eden_artifact_reach_st.wav"]))
	sfx_bank["sfx_eden_artifact_thronglets_eyesGlow_st"] = _clips(PackedStringArray(["sfx_eden_artifact_thronglets_eyesGlow_st.wav"]))
	sfx_bank["sfx_eden_artifact_thronglets_glow_st"] = _clips(PackedStringArray(["sfx_eden_artifact_thronglets_glow_st.wav"]))
	sfx_bank["sfx_egg_fall_01"] = _clips(PackedStringArray(["sfx_egg_fall_01.wav"]))
	sfx_bank["sfx_egg_impact_grass_01"] = _clips(PackedStringArray(["sfx_egg_impact_grass_01.wav"]))
	sfx_bank["sfx_factory_place"] = _clips(_seq("sfx_factory_place_", 1, 3))
	sfx_bank["sfx_fire_extinguish"] = _clips(_seq("sfx_fire_extinguish_", 1, 5))
	sfx_bank["sfx_fire_lp_01"] = _clips(PackedStringArray(["sfx_fire_lp_01.wav"]))
	sfx_bank["sfx_fire_start"] = _clips(_seq("sfx_fire_start_", 1, 5))
	sfx_bank["sfx_fire_unlock"] = _clips(PackedStringArray(["sfx_fire_unlock.wav"]))
	sfx_bank["sfx_general_tool_grab"] = _clips(PackedStringArray(["sfx_general_tool_grab.wav"]))
	sfx_bank["sfx_general_tool_use"] = _clips(PackedStringArray(["sfx_general_tool_use.wav"]))
	sfx_bank["sfx_general_unlock"] = _clips(PackedStringArray(["sfx_general_unlock.wav"]))
	sfx_bank["sfx_glitch_special_dialUp"] = _clips(PackedStringArray(["sfx_glitch_special_dialUp.wav"]))
	sfx_bank["sfx_grabber_pickUp"] = _clips(PackedStringArray(["sfx_grabber_pickUp.wav"]))
	sfx_bank["sfx_grabber_release"] = _clips(PackedStringArray(["sfx_grabber_release.wav"]))
	sfx_bank["sfx_grabber_unlock"] = _clips(PackedStringArray(["sfx_grabber_unlock.wav"]))
	sfx_bank["sfx_hammer_hit"] = _clips(_seq("sfx_hammer_hit_", 1, 4))
	sfx_bank["sfx_hammer_unlock"] = _clips(PackedStringArray(["sfx_hammer_unlock.wav"]))
	sfx_bank["sfx_healerHeart_activate"] = _clips(_seq("sfx_healerHeart_activate_", 1, 6))
	sfx_bank["sfx_healerHeart_grab"] = _clips(PackedStringArray(["sfx_healerHeart_grab.wav"]))
	sfx_bank["sfx_healerHeart_place"] = _clips(PackedStringArray(["sfx_healerHeart_place.wav"]))
	sfx_bank["sfx_healerHeart_unlock"] = _clips(PackedStringArray(["sfx_healerHeart_unlock.wav"]))
	sfx_bank["sfx_house_place"] = _clips(_seq("sfx_house_place_", 1, 3))
	sfx_bank["sfx_intro_linear01_console_st"] = _clips(PackedStringArray(["sfx_intro_linear01_console_st.wav"]))
	sfx_bank["sfx_item_buy"] = _clips(PackedStringArray(["sfx_item_buy.wav"]))
	sfx_bank["sfx_item_unlock_glitch_layer"] = _clips(PackedStringArray(["sfx_item_unlock_glitch_layer.wav"]))
	sfx_bank["sfx_ladybug_grab"] = _clips(PackedStringArray(["sfx_ladybug_grab.wav"]))
	sfx_bank["sfx_ladybug_unlock"] = _clips(PackedStringArray(["sfx_ladybug_unlock.wav"]))
	sfx_bank["sfx_levelStart_eden_st"] = _clips(PackedStringArray(["sfx_levelStart_eden_st.wav"]))
	sfx_bank["sfx_mine_place"] = _clips(_seq("sfx_mine_place_", 1, 3))
	sfx_bank["sfx_monolith_appear"] = _clips(PackedStringArray(["sfx_monolith_appear.wav"]))
	sfx_bank["sfx_monolith_interact"] = _clips(PackedStringArray(["sfx_monolith_interact.wav"]))
	sfx_bank["sfx_mop_grab_01"] = _clips(PackedStringArray(["sfx_mop_grab_01.wav"]))
	sfx_bank["sfx_mop_unlock"] = _clips(PackedStringArray(["sfx_mop_unlock.wav"]))
	sfx_bank["sfx_mop_use"] = _clips(_seq("sfx_mop_use_", 1, 6))
	sfx_bank["sfx_mountain_explode_st"] = _clips(PackedStringArray(["sfx_mountain_explode_st.wav"]))
	sfx_bank["sfx_nuke_countdown_lp"] = _clips(PackedStringArray(["sfx_nuke_countdown_lp.wav"]))
	sfx_bank["sfx_nuke_explode"] = _clips(PackedStringArray(["sfx_nuke_explode.wav"]))
	sfx_bank["sfx_nuke_place"] = _clips(PackedStringArray(["sfx_nuke_place.wav"]))
	sfx_bank["sfx_nuke_select"] = _clips(PackedStringArray(["sfx_nuke_select.wav"]))
	sfx_bank["sfx_nuke_unlock"] = _clips(PackedStringArray(["sfx_nuke_unlock.wav"]))
	sfx_bank["sfx_pickaxe_hit"] = _clips(_seq("sfx_pickaxe_hit_", 1, 6))
	sfx_bank["sfx_pickaxe_unlock"] = _clips(PackedStringArray(["sfx_pickaxe_unlock.wav"]))
	sfx_bank["sfx_quietPopUp_musicGlitch"] = _clips(PackedStringArray(["sfx_quietPopUp_musicGlitch.wav"]))
	sfx_bank["sfx_rock_break"] = _clips(PackedStringArray([
		"sfx_rock_break_01.wav", "sfx_rock_break_02.wav", "sfx_rock_break_04.wav",
		"sfx_rock_break_05.wav", "sfx_rock_break_06.wav",
	]))
	sfx_bank["sfx_rock_crack"] = _clips(_seq("sfx_rock_crack_", 1, 6))
	sfx_bank["sfx_roundabout_place"] = _clips(_seq("sfx_roundabout_place_", 1, 3))
	sfx_bank["sfx_roundabout_start"] = _clips(_seq("sfx_roundabout_start_", 1, 4))
	sfx_bank["sfx_roundabout_unlock"] = _clips(PackedStringArray(["sfx_roundabout_unlock.wav"]))
	sfx_bank["sfx_sculpture_place"] = _clips(PackedStringArray(["sfx_sculpture_place.wav"]))
	sfx_bank["sfx_sculpture_select"] = _clips(PackedStringArray(["sfx_sculpture_select.wav"]))
	sfx_bank["sfx_superOre_drop"] = _clips(_seq("sfx_superOre_drop_", 1, 4))
	sfx_bank["sfx_superOre_lift"] = _clips(_seq("sfx_superOre_lift_", 1, 6))
	sfx_bank["sfx_teleport_appear"] = _clips(PackedStringArray(["sfx_teleport_appear.wav"]))
	sfx_bank["sfx_teleport_doorAppear"] = _clips(PackedStringArray(["sfx_teleport_doorAppear.wav"]))
	sfx_bank["sfx_teleport_doorClose"] = _clips(PackedStringArray(["sfx_teleport_doorClose.wav"]))
	sfx_bank["sfx_teleport_galaxy_presence_lp"] = _clips(PackedStringArray(["sfx_teleport_galaxy_presence_lp.wav"]))
	sfx_bank["sfx_teleport_lp"] = _clips(PackedStringArray(["sfx_teleport_lp.wav"]))
	sfx_bank["sfx_teleport_thronglet_disappear"] = _clips(PackedStringArray(["sfx_teleport_thronglet_disappear.wav"]))
	sfx_bank["sfx_text_bubble_close"] = _clips(PackedStringArray(["sfx_text_bubble_close.wav"]))
	sfx_bank["sfx_text_bubble_next"] = _clips(PackedStringArray(["sfx_text_bubble_next.wav"]))
	sfx_bank["sfx_text_bubble_open"] = _clips(PackedStringArray(["sfx_text_bubble_open.wav"]))
	sfx_bank["sfx_theatre_place"] = _clips(_seq("sfx_theatre_place_", 1, 3))
	sfx_bank["sfx_thonglePackage_close"] = _clips(PackedStringArray(["sfx_thonglePackage_close.wav"]))
	sfx_bank["sfx_thonglePackage_loading_lp"] = _clips(PackedStringArray(["sfx_thonglePackage_loading_lp.wav"]))
	sfx_bank["sfx_thonglePackage_open"] = _clips(PackedStringArray(["sfx_thonglePackage_open.wav"]))
	sfx_bank["sfx_thronglet_bones_drop"] = _clips(_seq("sfx_thronglet_bones_drop_", 1, 6))
	sfx_bank["sfx_thronglet_bones_grab"] = _clips(_seq("sfx_thronglet_bones_grab_", 1, 6))
	sfx_bank["sfx_thronglet_emoji_01"] = _clips(PackedStringArray(["sfx_thronglet_emoji_01.wav"]))
	sfx_bank["sfx_thronglet_eyeGlow"] = _clips(PackedStringArray(["sfx_thronglet_eyeGlow.wav"]))
	sfx_bank["sfx_thronglet_lumber_drop"] = _clips(_seq("sfx_thronglet_lumber_drop_", 1, 6))
	sfx_bank["sfx_thronglet_lumber_grab"] = _clips(_seq("sfx_thronglet_lumber_grab_", 1, 6))
	sfx_bank["sfx_thronglet_speed_run"] = _clips(_seq("sfx_thronglet_speed_run_", 1, 6))
	sfx_bank["sfx_tree_apple_plant"] = _clips(_seq("sfx_tree_apple_plant_", 1, 4))
	sfx_bank["sfx_tree_apple_unlock"] = _clips(PackedStringArray(["sfx_tree_apple_unlock.wav"]))
	sfx_bank["sfx_tree_stump_destroy"] = _clips(_seq("sfx_tree_stump_destroy_", 1, 4))
	sfx_bank["sfx_uplink_add_bomb"] = _clips(PackedStringArray(["sfx_uplink_add_bomb.wav"]))
	sfx_bank["sfx_uplink_add_negative"] = _clips(_seq("sfx_uplink_add_negative_", 1, 3))
	sfx_bank["sfx_uplink_add_positive"] = _clips(_seq("sfx_uplink_add_positive_", 1, 3))
	sfx_bank["sfx_uplink_add_thronglet_multiple_lp_noHearts"] = _clips(PackedStringArray(["sfx_uplink_add_thronglet_multiple_lp_noHearts.wav"]))
	sfx_bank["sfx_uplink_add_thronglet_single"] = _clips(_seq("sfx_uplink_add_thronglet_single_", 1, 3))
	sfx_bank["sfx_uplink_googlyEyes_appear"] = _clips(PackedStringArray(["sfx_uplink_googlyEyes_appear.wav"]))
	sfx_bank["sfx_uplink_grab"] = _clips(PackedStringArray(["sfx_uplink_grab.wav"]))
	sfx_bank["sfx_uplink_place"] = _clips(PackedStringArray(["sfx_uplink_place.wav"]))
	sfx_bank["sfx_uplink_unlock"] = _clips(PackedStringArray(["sfx_uplink_unlock.wav"]))
	sfx_bank["sfx_water_splash"] = _clips(_seq("sfx_water_splash_", 1, 4))

	# --- Thronglets (voices and sounds) ---
	sfx_bank["thronglet_crush"] = _clips(PackedStringArray(["thronglet_crush.wav"]))
	sfx_bank["thronglet_glitch_a"] = _clips(PackedStringArray(["thronglet_glitch_a.wav"]))
	sfx_bank["thronglet_glitch_b"] = _clips(PackedStringArray(["thronglet_glitch_b.wav"]))
	sfx_bank["thronglet_glitch_c"] = _clips(PackedStringArray(["thronglet_glitch_c.wav"]))
	sfx_bank["thronglet_glitch_d"] = _clips(PackedStringArray(["thronglet_glitch_d.wav"]))
	sfx_bank["thronglet_glitch_e"] = _clips(PackedStringArray(["thronglet_glitch_e.wav"]))
	sfx_bank["thronglet_jump_megafm"] = _clips(PackedStringArray(["thronglet_jump_megafm.wav"]))
	sfx_bank["thronglet_scrub_a"] = _clips(PackedStringArray(["thronglet_scrub_a.wav"]))
	sfx_bank["WaterSplashBeep"] = _clips(PackedStringArray(["WaterSplashBeep.wav"]))
	sfx_bank["artifact_hum_loop"] = _clips(PackedStringArray(["artifact_hum_loop.ogg"]))
	sfx_bank["hatch_success_stinger"] = _clips(PackedStringArray(["hatch_success_stinger.wav"]))
	sfx_bank["monolith_reveal_nobeat_nobar"] = _clips(PackedStringArray(["monolith_reveal_nobeat_nobar.ogg"]))

	# --- Thronglet voices ---
	sfx_bank["vo_throng_sing_group_small"] = _clips(_seq("vo_throng_sing_group_small_", 1, 13))
	sfx_bank["vo_thronglet_prrr"] = _clips(_seq("vo_thronglet_prrr_", 1, 13))
	sfx_bank["vo_thronglet_sing"] = _clips(_seq("vo_thronglet_sing_", 1, 6))
	sfx_bank["vo_thronglet_upset_04"] = _clips(PackedStringArray(["vo_thronglet_upset_04.wav"]))
	sfx_bank["vo_thronglet_upset_06"] = _clips(PackedStringArray(["vo_thronglet_upset_06.wav"]))
	sfx_bank["vo_thronglet_upset_09"] = _clips(PackedStringArray(["vo_thronglet_upset_09.wav"]))
	sfx_bank["vo_thronglet_upset_11"] = _clips(PackedStringArray(["vo_thronglet_upset_11.wav"]))
	sfx_bank["vo_thronglet_upset_12"] = _clips(PackedStringArray(["vo_thronglet_upset_12.wav"]))


func _seq(prefix: String, first: int, last: int) -> PackedStringArray:
	var names := PackedStringArray()
	for i in range(first, last + 1):
		names.append("%s%02d.wav" % [prefix, i])
	return names


func _fill_loose_clips() -> void:
	var packed := {}
	for key in sfx_bank.keys():
		for stream in sfx_bank[key]:
			packed[stream] = true
	var dir := DirAccess.open("res://resources/audio")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".wav") or file_name.ends_with(".ogg")):
			var stream := _load_stream(file_name)
			if stream != null and not packed.has(stream):
				sfx_bank[file_name.get_basename()] = [stream]
				packed[stream] = true
		file_name = dir.get_next()


func build_video() -> void:
	video_player = VideoStreamPlayer.new()
	video_player.visible = false
	video_player.z_index = 80
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.finished.connect(_on_video_finished)
	var layer := CanvasLayer.new()
	layer.layer = 1000
	add_child(layer)
	captions_layer = layer
	var plate := ColorRect.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.color = Color(0, 0, 0, 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.visible = false
	video_player.set_meta("plate", plate)
	layer.add_child(plate)
	layer.add_child(video_player)
	captions_label = _make_captions_label()
	layer.add_child(captions_label)


func _ui_font() -> FontFile:
	var font := FontFile.new()
	font.load_dynamic_font("res://resources/ui/VT323-Regular.ttf")
	return font


func _make_captions_label() -> Label:
	var label := Label.new()
	label.z_index = 90
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 80
	label.offset_right = -80
	label.offset_top = -160
	label.offset_bottom = -48
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _ui_font())
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	return label


func _ensure_captions_label() -> void:
	if captions_label != null and is_instance_valid(captions_label):
		return
	if captions_layer == null:
		var new_layer := CanvasLayer.new()
		new_layer.layer = 1000
		add_child(new_layer)
		captions_layer = new_layer
	captions_label = _make_captions_label()
	captions_layer.add_child(captions_label)


func _caption_table_for(base: String) -> String:
	if not base.begins_with("SEQ_"):
		return ""
	var seq_n := int(base.substr(4).get_slice(".", 0))
	if seq_n < 1:
		return ""
	return "SUB_SEQ_%d" % seq_n


func _caption_display_text(raw: String) -> String:
	return str(raw).strip_edges().replace("\\n", "\n")


func clear_captions() -> void:
	captions_lines.clear()
	captions_ends.clear()
	captions_index = -1
	if captions_label != null:
		captions_label.visible = false
		captions_label.text = ""


func _show_captions_for(base: String) -> void:
	_ensure_captions_label()
	clear_captions()
	if captions_label == null or not captions_on:
		return
	var table := _caption_table_for(base)
	if table == "":
		return
	var weights: Array = []
	var total_weight := 0.0
	var i := 0
	while true:
		var raw := LineBook.row(table, i)
		if raw == "":
			break
		var text := _caption_display_text(raw)
		i += 1
		if text == "":
			continue
		captions_lines.append(text)
		var weight := maxf(24.0, float(text.length()))
		weights.append(weight)
		total_weight += weight
	if captions_lines.is_empty() or total_weight <= 0.0:
		return
	var duration := 0.0
	if video_player != null:
		duration = video_player.get_stream_length()
	if duration <= 0.05:
		duration = total_weight * 0.08
	var cursor := 0.0
	for weight in weights:
		cursor += duration * (float(weight) / total_weight)
		captions_ends.append(cursor)
	_apply_caption_at(0.0)


func _apply_caption_at(pos: float) -> void:
	if captions_label == null or captions_lines.is_empty():
		return
	var idx := 0
	while idx < captions_ends.size() and pos >= float(captions_ends[idx]):
		idx += 1
	if idx >= captions_lines.size():
		idx = captions_lines.size() - 1
	if idx == captions_index:
		return
	captions_index = idx
	captions_label.text = str(captions_lines[idx])
	captions_label.visible = true
	captions_label.move_to_front()


func tick_captions() -> void:
	if not captions_on or captions_lines.is_empty():
		return
	if video_player == null or not video_player.visible or not video_player.is_playing():
		return
	_apply_caption_at(video_player.stream_position)


func play_video(base: String, from_title: bool, from_library: bool = false) -> bool:
	var path := "res://resources/video/" + base + ".ogv"
	if not ResourceLoader.exists(path):
		return false
	var stream: VideoStream = load(path)
	if stream == null:
		return false
	video_player.stream = stream
	video_player.visible = true
	var plate: ColorRect = video_player.get_meta("plate") as ColorRect
	if plate != null:
		plate.visible = false
	if music != null:
		var tween: Tween = create_tween()
		tween.tween_property(music, "volume_db", -80.0, 0.5)
	if sting != null:
		var tween2: Tween = create_tween()
		tween2.tween_property(sting, "volume_db", -80.0, 0.5)
	video_player.play()
	video_played[base] = true
	video_from_title = from_title
	video_from_library = from_library
	_show_captions_for(base)
	return true


func _on_video_finished() -> void:
	if video_player != null:
		video_player.visible = false
		var plate: ColorRect = video_player.get_meta("plate") as ColorRect
		if plate != null:
			plate.visible = false
	clear_captions()
	if host != null and str(host.get("boot")) == "logo" and not bool(host.get("logo_started")):
		return
	if host == null or str(host.get("boot")) != "logo":
		if music != null:
			var tween: Tween = create_tween()
			tween.tween_property(music, "volume_db", -6.0, 1.0)
		if sting != null:
			var tween2: Tween = create_tween()
			tween2.tween_property(sting, "volume_db", -4.0, 1.0)
	if host != null and str(host.get("boot")) == "logo":
		video_player.volume_db = 0.0
		host.call("_begin_dos")
		return
	if video_from_library:
		video_from_library = false
		if host != null:
			host.call("_show_title")
			host.call("_open_video_library")
		return
	if video_from_title:
		video_from_title = false
		if host != null:
			host.call("_show_title")


func maybe_play_sequence(mode: String) -> void:
	var clips := {
		"mountain": "SEQ_2.1",
		"glitch": "ConsoleText",
		"anomaly": "SEQ_7.3",
		"epilogue": "SEQ_8.3",
	}
	if not clips.has(mode) or video_played.has(mode):
		return
	if play_video(str(clips[mode]), false):
		video_played[mode] = true
		if mode == "glitch":
			play_file("code_layer_in_a.ogg", false)
		elif mode == "epilogue":
			play("artifact_finale")
			play("finale_outro")


func _clips(names: PackedStringArray) -> Array:
	var out: Array = []
	for clip_name in names:
		var stream := _load_stream(clip_name)
		if stream != null:
			out.append(stream)
	return out


func _load_stream(clip_name: String) -> AudioStream:
	var path := "res://resources/audio/" + clip_name
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream != null:
			return stream
	if clip_name.ends_with(".wav"):
		return _load_wav(path)
	return null


func _load_wav(path: String) -> AudioStream:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw := file.get_buffer(file.get_length())
	file.close()
	if raw.size() < 44:
		return null
	var data_offset := -1
	var data_size := 0
	var cursor := 12
	while cursor + 8 <= raw.size():
		var chunk_id := String(raw.slice(cursor, cursor + 4).get_string_from_ascii())
		var chunk_size := int(raw.decode_u32(cursor + 4))
		if chunk_id == "data":
			data_offset = cursor + 8
			data_size = chunk_size if chunk_size > 0 else raw.size() - data_offset
			break
		cursor += 8 + chunk_size + (chunk_size & 1)
	if data_offset < 0:
		return null
	var channels := int(raw.decode_u16(22))
	var mix_rate := int(raw.decode_u32(24))
	var bits := int(raw.decode_u16(34))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = mix_rate if mix_rate > 0 else 44100
	wav.stereo = channels > 1
	wav.data = raw.slice(data_offset, mini(data_offset + data_size, raw.size()))
	return wav


func play(name: String) -> void:
	if name.begins_with("unlock_") and not has_clip(name):
		name = "unlock"
	if not has_clip(name):
		return
	var clips: Array = sfx_bank[name]
	var stream: AudioStream = clips[randi() % clips.size()]
	var player := _free_sfx()
	player.stream = stream
	player.play()


func play_sfx_then(name: String, callback: Callable) -> void:
	if music != null:
		var music_tween := create_tween()
		music_tween.tween_property(music, "volume_db", -80.0, 0.5)

	var wait_time := 0.35
	if has_clip(name):
		play(name)
		var stream: AudioStream = sfx_bank[name][0]
		if stream != null:
			wait_time = maxf(stream.get_length(), 0.1)
	else:
		play("ui")

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_time
	add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		if callback.is_valid():
			callback.call()
	)
	timer.start()


func has_clip(name: String) -> bool:
	if not sfx_bank.has(name):
		return false
	var clips: Array = sfx_bank[name]
	return not clips.is_empty()


func _free_sfx() -> AudioStreamPlayer:
	for raw in sfx_pool:
		var player := raw as AudioStreamPlayer
		if player != null and not player.playing:
			return player
	return sfx_pool[0] as AudioStreamPlayer


func sync_music(in_title: bool, camera_biome: String) -> void:
	if logo_video_playing:
		return
	var mode := "title"
	if not in_title:
		mode = camera_biome
		if mode == "":
			mode = "meadow"
	if mode == music_mode:
		_sync_spot_amb(in_title)
		return
	var previous := music_mode
	music_mode = mode
	_play_biome_bed(mode)
	_play_biome_stinger(mode, previous)
	_sync_spot_amb(in_title)
	maybe_play_sequence(mode)


func _play_biome_bed(mode: String) -> void:
	if mode == "title":
		_loop_bed(music, "thronglets_title_theme_180bpm_24bar.ogg")
		amb.stop()
	elif mode == "mountain":
		_loop_bed(music, "thronglets_megafm_b_140bpm_88bar.ogg")
		_loop_bed(amb, "amb_spot_mountainVoidOpening_lp.wav")
	elif mode == "glitch":
		_loop_bed(music, "wasteland_one_160bpm_134bar.ogg")
		_loop_bed(amb, "ambBed_act3_lp.ogg")
	elif mode == "anomaly":
		_loop_bed(music, "wasteland_part_two_160bpm_156bar.ogg")
		_loop_bed(amb, "amb_spot_pollution.ogg")
	elif mode == "epilogue":
		_loop_bed(music, "toward_the_artifact_140bpm_208bar.ogg")
		_loop_bed(amb, "artifact_hum_loop.ogg")
	elif mode == "waste":
		_loop_bed(music, "wasteland_one_160bpm_134bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_barrenWind.ogg")
	else:
		_loop_bed(music, "fieldwork_140bpm_108bar.ogg")
		_loop_bed(amb, "ambBed_act1n2_softWindBirds_lp.ogg")


func _play_biome_stinger(mode: String, previous: String) -> void:
	if previous == "":
		return
	var once := {
		"mountain": "thronglets_megafm_a_140bpm_72bar.ogg",
		"glitch": "actIII_millions_oneshot_A.ogg",
		"anomaly": "artifact_reveal_140bpm_10bar.ogg",
		"epilogue": "thronglets_finale_76bpm_74bar.ogg",
	}
	if once.has(mode):
		play_file(str(once[mode]), false)


func _sync_spot_amb(in_title: bool) -> void:
	if in_title or music_mode == "mountain" or music_mode == "glitch" or music_mode == "anomaly" or music_mode == "epilogue":
		return
	var spot := ""
	if host != null and host.has_method("_near_spot"):
		spot = str(host.call("_near_spot"))
	if spot == spot_mode:
		return
	spot_mode = spot
	if spot == "mine":
		_loop_bed(amb, "amb_spot_mine_lp.wav")
	elif spot == "market":
		_loop_bed(amb, "amb_spot_market_lp.ogg")
	elif spot == "pollution":
		_loop_bed(amb, "amb_spot_pollution.ogg")
	elif music_mode == "waste":
		_loop_bed(amb, "ambBed_act1n2_barrenWind.ogg")
	else:
		_loop_bed(amb, "ambBed_act1n2_softWindBirds_lp.ogg")


func play_file(file_name: String, looped: bool) -> void:
	var loaded: AudioStream = load("res://resources/audio/" + file_name)
	if loaded == null:
		return
	var stream := loaded
	if loaded is AudioStreamOggVorbis:
		var ogg := loaded.duplicate() as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = looped
			stream = ogg
	if sting == null:
		return
	sting.stream = stream
	sting.play()


func _loop_bed(player: AudioStreamPlayer, file_name: String) -> void:
	var loaded: AudioStream = load("res://resources/audio/" + file_name)
	if loaded == null:
		return
	var stream := loaded
	if loaded is AudioStreamOggVorbis:
		var ogg := loaded.duplicate() as AudioStreamOggVorbis
		if ogg != null:
			ogg.loop = true
			stream = ogg
	player.stream = stream
	player.play()


func tick_birds(delta: float) -> void:
	if music_mode != "field":
		return
	bird_wait -= delta
	if bird_wait > 0.0:
		return
	bird_wait = randf_range(7.0, 14.0)
	play("bird")


func apply_volumes() -> void:
	_apply_volumes()


func _apply_volumes() -> void:
	var sdb := linear_to_db(sfx_vol) if sfx_vol > 0.0 else -80.0
	var mdb := linear_to_db(music_vol) if music_vol > 0.0 else -80.0
	for raw in sfx_pool:
		var player := raw as AudioStreamPlayer
		if player != null:
			player.volume_db = sdb
	if music != null:
		music.volume_db = mdb
	if amb != null:
		amb.volume_db = mdb
	if sting != null:
		sting.volume_db = sdb
	if video_player != null:
		video_player.volume_db = mdb
