extends GutTest

const SAVE_PATH := "user://test_finish_crowd.json"

func _practice() -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = SAVE_PATH
	practice.countdown_enabled = false
	add_child_autofree(practice)
	practice.set_physics_process(false)
	practice.rider.set_physics_process(false)
	return practice

func _finish(practice: Node3D) -> void:
	for index in practice.course.gates.size():
		practice.rules.cross_checkpoint(index)
	practice.rider.speed = practice.rider.handling.gate_min_speed + 1.0
	practice._on_finish(practice.rider)

func after_each() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func test_supplied_cheer_is_loaded_as_nonlooping_scene_owned_effect() -> void:
	var practice := _practice()
	var crowd: AudioStreamPlayer = practice.audio.get_node("FinishCrowd")
	assert_true(crowd.stream is AudioStreamMP3)
	assert_eq(crowd.stream.resource_path, "res://assets/audio/sfx/finish_crowd.mp3")
	assert_gt(crowd.stream.get_length(), 0.0, "supplied MP3 decodes")
	assert_false(crowd.stream.loop, "play the supplied clip once, not endlessly")
	assert_eq(crowd.bus, &"SFX", "crowd respects Sound Effects and Master sliders")
	assert_false(crowd.playing, "no crowd during normal racing")
	print("Supplied finish crowd duration: %.3f seconds" % crowd.stream.get_length())

func test_valid_finish_fades_crowd_behind_existing_finish_cue_without_waiting() -> void:
	var practice := _practice()
	var audio: Node = practice.audio
	var crowd: AudioStreamPlayer = audio.get_node("FinishCrowd")
	practice.rider.speed = practice.rider.handling.gate_min_speed + 1.0
	practice._on_finish(practice.rider)
	assert_false(crowd.playing, "missing checkpoints cannot start cheers")
	assert_true(audio.get_node("Music").playing, "invalid finish leaves normal race music unchanged")
	_finish(practice)
	assert_true(crowd.playing)
	assert_false(audio.get_node("Music").playing, "race music cannot compete with finish audio")
	assert_true(audio.get_node("finish").playing, "original finish cue remains foreground")
	assert_lt(crowd.volume_db, -30.0, "crowd starts softly")
	assert_true(practice.rider.cruise, "finish rollout begins without waiting for the clip")
	assert_eq(practice._finish_timer, 0.0)
	assert_false(practice.finish_stats.is_empty())
	await wait_seconds(0.75)
	assert_almost_eq(crowd.volume_db, -14.0, 0.1, "crowd stays quieter than foreground effects")
	assert_lt(crowd.volume_db, audio.get_node("finish").volume_db)
	var before := crowd.get_playback_position()
	practice._on_finish(practice.rider)
	assert_gte(crowd.get_playback_position(), before - 0.02, "duplicate finish event cannot restart cheers")
	for signal_name in ["boosted", "took_off"]:
		practice.rider.emit_signal(signal_name)
	assert_false(audio.get_node("boost").playing)
	assert_false(audio.get_node("jump").playing)

func test_crowd_pauses_resumes_and_stops_with_scene_audio() -> void:
	var practice := _practice()
	var audio: Node = practice.audio
	var crowd: AudioStreamPlayer = audio.get_node("FinishCrowd")
	_finish(practice)
	audio.set_paused(true)
	assert_true(crowd.stream_paused)
	assert_false(audio._crowd_fade.is_running(), "fade pauses with playback")
	audio.set_paused(false)
	assert_false(crowd.stream_paused)
	assert_true(crowd.playing, "resume continues the same crowd clip")
	audio.stop_all()
	assert_false(crowd.playing, "restart/menu stop_all ends the crowd immediately")
	assert_null(audio._crowd_fade, "no fade continues after leaving finish")
	audio.play_finish()
	assert_true(crowd.playing)
	practice.remove_child(audio)
	assert_false(crowd.playing, "scene exit also stops the cheer")
	assert_null(audio._crowd_fade)
	audio.free()

func test_crowd_ends_naturally_without_restarting() -> void:
	var practice := _practice()
	var crowd: AudioStreamPlayer = practice.audio.get_node("FinishCrowd")
	crowd.pitch_scale = 4.0
	watch_signals(crowd)
	_finish(practice)
	await wait_seconds(crowd.stream.get_length() / 4.0 + 0.4)
	assert_false(crowd.playing)
	assert_signal_emit_count(crowd, "finished", 1, "single background playthrough")
	practice._on_finish(practice.rider)
	assert_false(crowd.playing, "finished race cannot trigger another crowd playthrough")
