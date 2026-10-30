extends GutTest

const SAVE_PATH := "user://test_checkpoint_fx.json"

func _practice(reduced := false) -> Node3D:
	var save := SaveStore.default_save()
	SaveStore.set_settings(save, {"reduced_shake": reduced})
	assert_true(SaveStore.save_to_path(save, SAVE_PATH))
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = SAVE_PATH
	practice.countdown_enabled = false
	add_child_autofree(practice)
	practice.set_physics_process(false)
	practice.rider.set_physics_process(false)
	practice.rider.speed = practice.rider.handling.gate_min_speed + 1.0
	return practice

func _bursts(practice: Node3D) -> Array[Node]:
	return practice.find_children("CheckpointConfetti*", "CPUParticles3D", false, false)

func after_each() -> void:
	get_tree().paused = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func test_only_accepted_checkpoint_crossings_trigger_boom_and_confetti() -> void:
	var practice := _practice()
	var boom: AudioStreamPlayer = practice.audio.get_node("checkpoint")
	var stranger := Node3D.new()
	add_child_autofree(stranger)
	practice._on_checkpoint(stranger, 0)
	practice._on_checkpoint(practice.rider, 1)
	practice.rider.speed = 0.0
	practice._on_checkpoint(practice.rider, 0)
	assert_false(boom.playing, "wrong rider, wrong order and low speed do not celebrate")
	assert_eq(_bursts(practice).size(), 0)
	assert_eq(practice.rules.next_checkpoint, 0)
	practice.rider.speed = practice.rider.handling.gate_min_speed + 1.0
	practice.rules.tick(1234)
	practice._on_checkpoint(practice.rider, 0)
	assert_true(boom.playing)
	assert_eq(_bursts(practice).size(), 1)
	assert_eq(practice.rules.next_checkpoint, 1)
	assert_eq(practice.rules.elapsed_ms, 1234, "celebration does not alter timing")
	assert_eq(practice._last_gate, 0)
	assert_eq(practice.rules.score, 0)
	boom.stop()
	practice._on_checkpoint(practice.rider, 0)
	assert_false(boom.playing, "duplicate crossing cannot replay the boom")
	assert_eq(_bursts(practice).size(), 1)
	practice._on_checkpoint(practice.rider, 1)
	assert_true(boom.playing, "the next checkpoint has its own celebration")
	assert_eq(_bursts(practice).size(), 2)
	assert_eq(practice.rules.next_checkpoint, 2)
	for index in range(2, practice.course.gates.size()):
		practice.rules.cross_checkpoint(index)
	practice.rules.finish()
	boom.stop()
	practice._on_checkpoint(practice.rider, 0)
	assert_false(boom.playing, "no checkpoint celebrations after finishing")
	assert_eq(_bursts(practice).size(), 2)

func test_supplied_boom_is_quiet_nonlooping_and_preserves_race_mix() -> void:
	var practice := _practice()
	var boom: AudioStreamPlayer = practice.audio.get_node("checkpoint")
	assert_true(boom.stream is AudioStreamMP3)
	assert_eq(boom.stream.resource_path, "res://assets/audio/sfx/checkpoint_boom.mp3")
	assert_gt(boom.stream.get_length(), 0.0, "supplied MP3 decodes")
	assert_false(boom.stream.loop)
	assert_eq(boom.bus, &"SFX")
	assert_eq(boom.max_polyphony, 1, "fast crossings cannot stack many loud booms")
	assert_almost_eq(boom.volume_db, -18.0, 0.001, "boom is 12 dB below other gameplay effects")
	practice.audio.play_sfx("boost")
	practice._on_checkpoint(practice.rider, 0)
	assert_true(practice.audio.get_node("Music").playing, "race music continues uninterrupted")
	assert_true(practice.audio.get_node("boost").playing, "other race effects are not cut off")
	practice._set_paused(true)
	assert_false(boom.playing, "pause discards transient checkpoint audio")
	practice._set_paused(false)
	assert_false(boom.playing, "resume does not replay a stale boom")
	practice.audio.play_sfx("checkpoint")
	practice.audio.stop_all()
	assert_false(boom.playing, "restart/exit stops the cue")
	print("Supplied checkpoint boom duration: %.3f seconds" % boom.stream.get_length())

func test_confetti_is_multicolored_at_gate_and_cleans_up_after_pause() -> void:
	var practice := _practice()
	practice._on_checkpoint(practice.rider, 0)
	var burst: CPUParticles3D = _bursts(practice)[0]
	assert_true(burst.one_shot)
	assert_eq(burst.amount, 48)
	assert_eq(burst.explosiveness, 1.0)
	assert_true(burst.emitting)
	assert_false(burst.local_coords, "particles stay at the checkpoint, not attached to the rider")
	assert_eq(burst.global_position, practice.course.to_global(practice.course.gates[0].pos + Vector3.UP * 1.5))
	assert_ne(burst.global_position, practice.rider.global_position)
	assert_eq(burst.color_initial_ramp.get_point_count(), FinishFX.COLORS.size())
	for index in FinishFX.COLORS.size():
		assert_eq(burst.color_initial_ramp.get_color(index), FinishFX.COLORS[index])
	assert_true(burst.mesh.material.vertex_color_use_as_albedo, "particle palette reaches rendered rectangles")
	assert_eq(burst.process_mode, Node.PROCESS_MODE_PAUSABLE)
	practice._set_paused(true)
	assert_false(burst.can_process())
	await get_tree().create_timer(1.5, true).timeout
	assert_true(is_instance_valid(burst), "paused confetti is not prematurely freed")
	practice._set_paused(false)
	await wait_seconds(1.6)
	assert_false(is_instance_valid(burst), "finished one-shot frees its node")
	assert_eq(_bursts(practice).size(), 0)

func test_reduced_motion_uses_fewer_gentler_confetti_particles() -> void:
	var practice := _practice(true)
	practice._on_checkpoint(practice.rider, 0)
	var burst: CPUParticles3D = _bursts(practice)[0]
	assert_eq(burst.amount, 12)
	assert_lte(burst.initial_velocity_max, 3.0)
	assert_lte(burst.lifetime, 0.65)
	assert_true(practice.audio.get_node("checkpoint").playing, "reduced motion does not mute checkpoint feedback")
