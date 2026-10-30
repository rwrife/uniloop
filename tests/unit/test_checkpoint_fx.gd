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
	var active: Array[Node] = []
	for burst: CPUParticles3D in practice.find_children("CheckpointConfetti*", "CPUParticles3D", false, false):
		if burst.emitting:
			active.append(burst)
	return active

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
	assert_true(boom.stream is AudioStreamWAV)
	assert_eq(boom.stream.resource_path, "res://assets/audio/sfx/checkpoint_boom.wav")
	assert_gt(boom.stream.get_length(), 0.0, "predecoded supplied boom is ready")
	assert_eq(boom.stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_eq(boom.bus, &"SFX")
	assert_eq(boom.max_polyphony, 1, "fast crossings cannot stack many loud booms")
	assert_almost_eq(boom.volume_db, -9.0, 0.001, "boom is audible but still 3 dB below other gameplay effects")
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
	assert_eq(burst.amount, 96)
	assert_eq(burst.mesh.size, Vector3(0.32, 0.08, 0.18))
	assert_eq(burst.direction, Vector3.UP)
	assert_almost_eq(burst.spread, 55.0, 0.001, "upward-biased cone retains a celebratory sideways spread")
	var rise := burst.initial_velocity_max * burst.lifetime + 0.5 * burst.gravity.y * pow(burst.lifetime, 2)
	assert_gte(rise, 15.0, "fastest upward pieces can climb high without extending the 1.5-second burst")
	assert_gte(burst.initial_velocity_min, 11.0)
	assert_almost_eq(burst.emission_sphere_radius, 0.65, 0.001)
	assert_eq(burst.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
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
	await wait_seconds(1.9)
	assert_false(is_instance_valid(burst), "finished one-shot frees its node")
	assert_eq(_bursts(practice).size(), 0)

func test_reduced_motion_uses_fewer_gentler_confetti_particles() -> void:
	var practice := _practice(true)
	practice._on_checkpoint(practice.rider, 0)
	var burst: CPUParticles3D = _bursts(practice)[0]
	assert_eq(burst.amount, 24)
	assert_lte(burst.initial_velocity_max, 5.0)
	assert_lte(burst.lifetime, 0.8)
	assert_true(practice.audio.get_node("checkpoint").playing, "reduced motion does not mute checkpoint feedback")

func test_checkpoint_audio_and_particles_are_ready_before_first_crossing() -> void:
	var practice := _practice()
	var boom: AudioStreamPlayer = practice.audio.get_node("checkpoint")
	var source: AudioStreamMP3 = load("res://assets/audio/sfx/checkpoint_boom.mp3")
	assert_same(boom.stream, practice.AUDIO.CHECKPOINT_BOOM)
	assert_eq(boom.stream.format, AudioStreamWAV.FORMAT_16_BITS, "no MP3/QOA decoding on first play")
	assert_gt(boom.stream.data.size(), 0, "PCM samples are already resident before crossing")
	assert_almost_eq(boom.stream.get_length(), source.get_length(), 1.0 / boom.stream.mix_rate)
	assert_false(boom.playing, "precaching is silent and does not play an early boom")
	assert_eq(practice._checkpoint_bursts.size(), practice.course.gates.size())
	var prepared: CPUParticles3D = practice._checkpoint_bursts[0]
	await wait_seconds(1.8)
	assert_true(is_instance_valid(prepared), "unused emitters survive beyond the burst lifetime until crossed")
	assert_false(prepared.emitting, "preparing confetti cannot celebrate an uncrossed gate")
	assert_same(prepared.mesh, practice._checkpoint_bursts[1].mesh, "mesh/material are shared and prepared once")
	practice.audio._streams.clear()
	var started := Time.get_ticks_usec()
	practice._on_checkpoint(practice.rider, 0)
	print("First checkpoint callback: %.3f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	assert_true(boom.playing)
	assert_same(_bursts(practice)[0], prepared, "crossing starts the existing emitter instead of allocating resources")
	assert_null(practice._checkpoint_bursts[0], "only unused emitters remain reserved")
	assert_true(practice.audio._streams.is_empty(), "first trigger does not request another resource load")
