extends GutTest

const AUDIO_SCRIPT := "res://scripts/audio.gd"
const SAVE_PATH := "user://test_audio_settings.json"
const MUSIC := {
	"title": "res://assets/audio/music/title.ogg",
	"race": "res://assets/audio/music/race_theme.ogg",
}
const SFX := {
	"countdown_tick": "res://assets/audio/sfx/countdown_tick.wav",
	"countdown_go": "res://assets/audio/sfx/countdown_go.wav",
	"finish": "res://assets/audio/sfx/finish.wav",
	"crash": "res://assets/audio/sfx/crash.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"land_clean": "res://assets/audio/sfx/land_clean.wav",
	"slime_land": "res://assets/audio/sfx/slime_land.wav",
	"boost": "res://assets/audio/sfx/boost.wav",
}

var _bus_volumes: Dictionary
var _bus_mutes: Dictionary


func before_each() -> void:
	_bus_volumes = {}
	_bus_mutes = {}
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		_bus_volumes[bus] = AudioServer.get_bus_volume_db(i)
		_bus_mutes[bus] = AudioServer.is_bus_mute(i)


func after_each() -> void:
	get_tree().paused = false
	Input.action_release(&"jump")
	for bus in _bus_volumes:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(index, _bus_volumes[bus])
		AudioServer.set_bus_mute(index, _bus_mutes[bus])
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(80000)
	stream.data = data
	return stream


func _audio(scene: Node) -> Node:
	var audio := scene.get_node_or_null("Audio")
	assert_not_null(audio, "scene owns its audio so exit cannot leak playback")
	return audio


func _standalone_audio() -> Node:
	assert_true(ResourceLoader.exists(AUDIO_SCRIPT), "audio integration script exists")
	if not ResourceLoader.exists(AUDIO_SCRIPT):
		return null
	var audio: Node = load(AUDIO_SCRIPT).new()
	add_child_autofree(audio)
	return audio


func _seed(audio: Node) -> void:
	for key in MUSIC:
		audio._streams[MUSIC[key]] = _tone()
	for key in SFX:
		audio.get_node(key).stream = _tone()


func _practice(countdown := false) -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = SAVE_PATH
	practice.countdown_enabled = countdown
	add_child_autofree(practice)
	practice.set_physics_process(false)
	practice.rider.set_physics_process(false)
	return practice


func _report(crash := false, count := 0, goo := false) -> Dictionary:
	return {
		"impact": -2.0, "tilt": 0.0, "tricks": ["FLIP"] if count > 0 else [],
		"count": count, "crash": crash, "reason": "Hard landing" if crash else "",
		"air_time": 1.0, "goo": goo,
	}


func test_asset_contract_missing_files_are_silent_and_players_use_buses() -> void:
	var audio := _standalone_audio()
	if audio == null:
		return
	assert_eq(audio.MUSIC, MUSIC)
	assert_eq(audio.SFX, SFX)
	assert_eq(audio.get_node("Music").bus, &"Music")
	for key in MUSIC:
		audio.play_music(key)
		if not ResourceLoader.exists(MUSIC[key]):
			assert_false(audio.get_node("Music").playing, "missing music stays silent")
	for key in SFX:
		assert_eq(audio.get_node(key).bus, &"SFX")
		audio.play_sfx(key)
		if not ResourceLoader.exists(SFX[key]):
			assert_false(audio.get_node(key).playing, "missing effect stays silent")
	audio.stop_all()


func test_race_theme_is_five_minutes_and_plays_once() -> void:
	var track := load(MUSIC["race"]) as AudioStreamOggVorbis
	assert_not_null(track)
	if track == null:
		return
	assert_almost_eq(track.get_length(), 300.0, 0.05)
	var audio := _standalone_audio()
	audio.play_music("race")
	assert_false(track.loop, "five-minute race theme plays through, without restarting intro")
	assert_true(audio.get_node("Music").playing)


func test_music_loops_effects_overlap_and_pause_discards_effects() -> void:
	var audio := _standalone_audio()
	if audio == null:
		return
	_seed(audio)
	audio.play_music("title")
	var title_music: AudioStreamPlayer = audio.get_node("Music")
	assert_true(title_music.playing)
	assert_eq(title_music.stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "title loops")
	audio.play_music("race")
	var music: AudioStreamPlayer = audio.get_node("Music")
	assert_true(music.playing)
	assert_eq(music.stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "race theme plays through once")
	audio.play_sfx("land_clean")
	audio.play_sfx("boost")
	assert_true(audio.get_node("land_clean").playing)
	assert_true(audio.get_node("boost").playing, "boost does not cut off landing")
	audio.set_paused(true)
	assert_true(music.stream_paused, "music is silent while paused")
	assert_false(audio.get_node("boost").playing)
	audio.play_sfx("jump")
	assert_false(audio.get_node("jump").playing, "paused cues are discarded")
	audio.set_paused(false)
	assert_false(music.stream_paused)
	assert_true(music.playing)
	assert_false(audio.get_node("boost").playing, "stale effects do not resume")
	audio.stop_all()
	assert_false(music.playing)


func test_music_and_sfx_settings_migrate_sanitize_and_persist() -> void:
	var legacy := SaveStore.from_json('{"version":3,"records":{},"total_score":0,"settings":{"audio_master":27}}')
	assert_true(legacy.ok)
	assert_eq(legacy.save.settings.get("audio_music"), 80)
	assert_eq(legacy.save.settings.get("audio_sfx"), 80)
	SaveStore.set_settings(legacy.save, {"audio_music": 35, "audio_sfx": 0})
	assert_true(SaveStore.save_to_path(legacy.save, SAVE_PATH))
	var loaded := SaveStore.load_from_path(SAVE_PATH)
	assert_eq(loaded.save.settings.get("audio_master"), 27)
	assert_eq(loaded.save.settings.get("audio_music"), 35)
	assert_eq(loaded.save.settings.get("audio_sfx"), 0)
	var invalid := SaveStore.sanitize_settings({"audio_music": -1, "audio_sfx": 101})
	assert_eq(invalid.get("audio_music"), 80)
	assert_eq(invalid.get("audio_sfx"), 80)


func test_audio_settings_configure_routing_volume_and_true_mute() -> void:
	UniloopUI.apply_audio({"audio_master": 50, "audio_music": 25, "audio_sfx": 0})
	for bus in ["Music", "SFX"]:
		assert_gte(AudioServer.get_bus_index(bus), 0, bus + " bus exists")
		if AudioServer.get_bus_index(bus) < 0:
			return
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"Master")
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.5, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.25, 0.001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero is true mute")
	UniloopUI.apply_audio({"audio_master": 0, "audio_music": 100, "audio_sfx": 65})
	assert_true(AudioServer.is_bus_mute(0))
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))


func test_menu_owns_title_music_and_exposes_existing_persistent_settings() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	var audio := _audio(menu)
	if audio == null:
		return
	assert_eq(audio.current_music, "title")
	menu._open("options")
	var sliders: Array[Node] = menu.panel_body.find_children("*", "HSlider", true, false)
	assert_eq(sliders.size(), 3, "Master, Music and SFX volume")
	_seed(audio)
	audio.play_music("title")
	menu._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(audio.get_node("Music").stream_paused)
	menu._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(audio.get_node("Music").stream_paused)
	menu.remove_child(audio)
	assert_false(audio.get_node("Music").playing, "leaving the scene stops title music")
	audio.free()


func test_menu_volume_controls_apply_and_persist_each_channel() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	assert_not_null(menu.get("save_path"), "menu settings support an isolated save like practice")
	if menu.get("save_path") == null:
		menu.free()
		return
	menu.save_path = SAVE_PATH
	add_child_autofree(menu)
	menu._open("options")
	var sliders: Array[Node] = menu.panel_body.find_children("*", "HSlider", true, false)
	assert_eq(sliders.size(), 3)
	var values := [40, 30, 0]
	var keys := ["audio_master", "audio_music", "audio_sfx"]
	for i in sliders.size():
		sliders[i].value = values[i]
		assert_eq(SaveStore.load_from_path(SAVE_PATH).save.settings[keys[i]], values[i])
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.4, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.3, 0.001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	menu._open("options")
	sliders = menu.panel_body.find_children("*", "HSlider", true, false)
	for i in sliders.size():
		assert_eq(int(sliders[i].value), values[i], "reopened options keep channel volume")


func test_practice_countdown_ticks_then_go_starts_race_music() -> void:
	var practice := _practice(true)
	var audio := _audio(practice)
	if audio == null:
		return
	_seed(audio)
	assert_false(audio.get_node("Music").playing, "no race loop during countdown")
	for text in ["3", "2", "1"]:
		audio.stop_all()
		practice._countdown_beat(text, Color.WHITE, false)
		assert_true(audio.get_node("countdown_tick").playing, text)
	practice._countdown_beat("RACE!", Color.WHITE, true)
	assert_true(audio.get_node("countdown_go").playing)
	assert_true(audio.get_node("Music").playing)
	assert_eq(audio.current_music, "race")


func test_practice_applies_saved_volume_and_starts_music_without_countdown() -> void:
	var save := SaveStore.default_save()
	SaveStore.set_settings(save, {"audio_master": 45, "audio_music": 20, "audio_sfx": 70})
	assert_true(SaveStore.save_to_path(save, SAVE_PATH))
	var practice := _practice()
	var audio := _audio(practice)
	if audio == null:
		return
	assert_eq(audio.current_music, "race")
	assert_almost_eq(AudioServer.get_bus_volume_linear(0), 0.45, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.2, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), 0.7, 0.001)


func test_existing_rider_signals_play_jump_clean_slime_crash_and_boost() -> void:
	var practice := _practice()
	var audio := _audio(practice)
	if audio == null:
		return
	_seed(audio)
	practice.rider.took_off.emit()
	assert_true(audio.get_node("jump").playing)
	practice.rider.landed.emit(_report())
	assert_true(audio.get_node("land_clean").playing)
	audio.stop_all()
	practice.rider.landed.emit(_report(false, 0, true))
	assert_true(audio.get_node("slime_land").playing)
	assert_false(audio.get_node("land_clean").playing)
	audio.stop_all()
	practice.rider.landed.emit(_report(true, 0, true))
	assert_true(audio.get_node("crash").playing)
	assert_false(audio.get_node("slime_land").playing, "crash wins over clean/slime cues")
	audio.stop_all()
	practice.rider.boosted.emit()
	assert_true(audio.get_node("boost").playing)
	audio.stop_all()
	practice.rider.landed.emit(_report(false, 1))
	assert_true(audio.get_node("land_clean").playing)
	assert_true(audio.get_node("boost").playing, "trick boost uses landing report semantics")
	audio.stop_all()
	practice._reset()
	assert_true(audio.get_node("crash").playing, "falls have the crash cue")


func test_wheel_landing_report_identifies_goo_from_actual_surface() -> void:
	var practice := _practice()
	var rider: WheelRider = practice.rider
	var found := false
	for sec_index in practice.course.sections.size():
		var sec: CanyonCourse.Section = practice.course.sections[sec_index]
		for i in sec.kinds.size():
			if sec.kinds[i] != CanyonCourse.GOO:
				continue
			var distance := sec.cum[i] + 0.5
			var sample: Dictionary = practice.course.sample(sec_index, distance)
			rider.yaw = atan2(sample.b.x, sample.b.z)
			rider.pitch = rider._surface_pitch(sample.t)
			rider.velocity = sample.t * 5.0 - sample.n * 2.0
			watch_signals(rider)
			rider._land({"sec": sec_index, "s": distance})
			var report: Dictionary = get_signal_parameters(rider, "landed")[0]
			assert_true(report.get("goo", false), "actual goo landing is identified")
			found = true
			break
		if found:
			break
	assert_true(found, "course has a goo landing surface")


func test_finish_stops_race_music_plays_once_and_ignores_rollout_sounds() -> void:
	var practice := _practice()
	var audio := _audio(practice)
	if audio == null:
		return
	_seed(audio)
	audio.play_music("race")
	practice._on_finish(practice.rider)
	assert_true(audio.get_node("Music").playing, "invalid finish does not stop race audio")
	for i in practice.course.gates.size():
		practice.rules.cross_checkpoint(i)
	practice.rider.speed = practice.rider.handling.gate_min_speed + 1.0
	practice._on_finish(practice.rider)
	assert_false(audio.get_node("Music").playing)
	assert_true(audio.get_node("finish").playing)
	audio.get_node("finish").stop()
	practice._on_finish(practice.rider)
	practice.rider.landed.emit(_report(true))
	practice.rider.boosted.emit()
	practice.rider.took_off.emit()
	assert_false(audio.get_node("finish").playing, "finish does not repeat")
	for key in ["crash", "boost", "jump"]:
		assert_false(audio.get_node(key).playing, "no rollout cue: " + key)


func test_practice_pause_and_exit_silence_audio_without_stale_effects() -> void:
	var practice := _practice()
	var audio := _audio(practice)
	if audio == null:
		return
	_seed(audio)
	audio.play_music("race")
	practice.rider.boosted.emit()
	practice._set_paused(true)
	assert_true(audio.get_node("Music").stream_paused)
	assert_false(audio.get_node("boost").playing)
	practice._set_paused(false)
	assert_false(audio.get_node("Music").stream_paused)
	assert_true(audio.get_node("Music").playing)
	assert_false(audio.get_node("boost").playing)
	practice.remove_child(audio)
	assert_false(audio.get_node("Music").playing)
	audio.free()


func test_freeing_unreadied_scenes_does_not_orphan_audio_nodes() -> void:
	for path in ["res://scenes/menu.tscn", "res://scenes/practice.tscn"]:
		var scene: Node = load(path).instantiate()
		scene.free()
	assert_no_new_orphans("audio must be owned even when a scene never enters the tree")
