extends GutTest

const PATH := "user://issue7_test.json"

func after_each() -> void:
	get_tree().paused = false
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)
	RaceSetup.track_id = RaceSetup.DEFAULT_TRACK
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func _course(id: String) -> CanyonCourse:
	var course := CanyonCourse.new()
	course.track_id = id
	course.simulation_only = true
	add_child_autofree(course)
	return course

func _race(countdown := false, id := "sunny_sprint") -> Node3D:
	RaceSetup.track_id = id
	var race: Node3D = load("res://scenes/practice.tscn").instantiate()
	race.save_path = PATH
	race.countdown_enabled = countdown
	add_child_autofree(race)
	race.set_physics_process(false)
	return race

func _frame() -> Array:
	return [0, 255, 0, 0, 0, 0, 0, 0, 0, 0, -2]

func _short_run() -> Dictionary:
	var capture := GhostRun.new()
	capture.append(_frame())
	capture.append(_frame())
	capture.append(_frame())
	return capture.finish("sunny_sprint", 50)

func test_courses_keep_existing_access_and_rooftop_uses_two_distinct_medals() -> void:
	var save := SaveStore.default_save()
	for id in ["sunny_sprint", "canyon_climb", "neon_night", "goo_gauntlet", "the_monopoly"]:
		assert_true(RaceSetup.is_unlocked(save, id), id)
	assert_false(RaceSetup.is_unlocked(save, "missing"))
	assert_false(RaceSetup.is_unlocked(save, "rooftop_precision"))
	SaveStore.record_best(save, "sunny_sprint", 90000, "gold", 0)
	SaveStore.record_best(save, "sunny_sprint", 95000, "gold", 0)
	SaveStore.record_best(save, "unknown_imported_course", 1000, "gold", 0)
	assert_false(RaceSetup.is_unlocked(save, "rooftop_precision"))
	SaveStore.record_best(save, "neon_night", 200000, "bronze", 0)
	assert_true(RaceSetup.is_unlocked(save, "rooftop_precision"))
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.save_path = PATH
	menu.auto_launch = false
	add_child_autofree(menu)
	menu._open("track")
	menu._on_track_picked(5)
	assert_ne(RaceSetup.track_id, "rooftop_precision")
	menu.save = save
	menu._open("track")
	menu.cards[5].pressed.emit()
	assert_eq(RaceSetup.track_id, "rooftop_precision")

func test_rooftop_layout_and_neon_loop_are_distinct_and_checkpoint_backed() -> void:
	var roof := _course("rooftop_precision")
	var neon := _course("neon_night")
	assert_eq(RaceSetup.TRACKS.size(), 6)
	assert_eq(roof.gates.size(), 5)
	assert_eq(roof.loops, 0)
	assert_gt(roof.gaps.size(), 8)
	assert_gt(neon.loops, 5)
	assert_gt(neon.boosts.size(), roof.boosts.size())
	assert_eq(roof.forks.size(), 2)
	assert_true(RaceRules.valid_thresholds(roof.medals))
	assert_ne(roof.track.plan, neon.track.plan)
	for spot in roof.gates + [roof.start_spot, roof.finish]:
		assert_true(roof.sample(spot.sec, spot.s).pos.is_equal_approx(spot.pos))

func test_fork_input_selects_different_routes_with_shared_merge() -> void:
	var course := _course("rooftop_precision")
	var fork: Dictionary = course.forks[0]
	var junction: CanyonCourse.Section = course.sections[fork.junction]
	assert_ne(fork.choices[0], fork.choices[1])
	var selected: Array = []
	for high in [false, true]:
		var wheel := WheelRider.new()
		wheel.handling = WheelHandling.new()
		wheel.course = course
		add_child_autofree(wheel)
		wheel.set_physics_process(false)
		wheel.place_on(fork.junction, junction.length - 0.05)
		wheel.speed = 12.0
		var frame := _frame()
		frame[2] = 255 if high else 0
		wheel.step(frame)
		selected.append(wheel.section)
	assert_eq(selected, [junction.next, junction.fork])
	assert_eq(course.sections[fork.routes[0]].next, course.sections[fork.routes[1]].next)

func test_best_time_owns_ghost_and_slower_or_tied_run_cannot_replace_it() -> void:
	var save := SaveStore.default_save()
	var run := _short_run()
	assert_false(run.is_empty())
	SaveStore.record_best(save, "sunny_sprint", 50, "silver", 10, run)
	var original: Dictionary = save.records.sunny_sprint.ghost.duplicate(true)
	SaveStore.record_best(save, "sunny_sprint", 60, "gold", 20, {})
	SaveStore.record_best(save, "sunny_sprint", 50, "gold", 30, {})
	assert_eq(save.records.sunny_sprint.ghost, original)
	assert_eq(save.records.sunny_sprint.medal, "gold")
	assert_eq(save.total_score, 60)
	assert_true(SaveStore.save_to_path(save, PATH))
	var loaded := SaveStore.load_from_path(PATH)
	assert_true(loaded.ok)
	assert_eq(loaded.save, save)
	SaveStore.record_best(save, "sunny_sprint", 40, "bronze", 0, run)
	assert_false(save.records.sunny_sprint.has("ghost"), "faster time with invalid/absent inputs removes obsolete ghost")

func test_bad_optional_ghost_drops_without_losing_records_settings_or_import_fields() -> void:
	var save := SaveStore.default_save()
	SaveStore.record_best(save, "sunny_sprint", 50, "silver", 4, _short_run())
	save["bindings"] = {"jump": 32}
	var mutations: Array = [
		{"course": "neon_night"}, {"revision": 0}, {"hz": 30}, {"time_ms": 51},
		{"revision": "1"}, {"course": []}, {"hz": {}}, {"time_ms": true},
		{"checksum": "bad"}, {"frames": [[0]]}, {"frames": "bad"},
		{"frames": [[0, 256, 0, 0, 0, 0, 0, 0, 0, 0, -2]]},
		{"frames": [[0, 0, 0, 0, 0, 0, 0, 0, 0, 2, -2]]},
		{"frames": [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 999]]},
	]
	for mutation in mutations:
		var damaged := save.duplicate(true)
		damaged.records.sunny_sprint.ghost.merge(mutation, true)
		var loaded := SaveStore.from_json(SaveStore.to_json(damaged))
		assert_true(loaded.ok)
		assert_false(loaded.save.records.sunny_sprint.has("ghost"))
		assert_eq(loaded.save.records.sunny_sprint.best_ms, 50)
		assert_eq(loaded.save.total_score, 4)
		assert_eq(int(loaded.save.bindings.jump), int(save.bindings.jump))
	assert_false(GhostRun.valid(null, "sunny_sprint", 50))
	assert_false(SaveStore.from_json("{broken").ok)

func test_v1_v2_v3_migrate_without_relocking_old_courses_or_inventing_ghosts() -> void:
	for version in [1, 2, 3]:
		var raw := {"version": version, "total_score": 9}
		if version == 1:
			raw.times = [{"course": "neon_night", "best_ms": 200000, "medal": "bronze"}]
		else:
			raw.records = {"neon_night": {"best_ms": 200000, "medal": "bronze"}}
		var loaded := SaveStore.from_json(JSON.stringify(raw))
		assert_true(loaded.ok)
		assert_eq(loaded.save.records.neon_night.best_ms, 200000)
		assert_false(loaded.save.records.neon_night.has("ghost"))
		assert_true(RaceSetup.is_unlocked(loaded.save, "the_monopoly"))
		assert_false(RaceSetup.is_unlocked(loaded.save, "rooftop_precision"))
	var imported := SaveStore.default_save()
	SaveStore.record_best(imported, "rooftop_precision", 999999, "none", 0)
	assert_true(RaceSetup.is_unlocked(imported, "rooftop_precision"), "existing course record retains access")

func test_countdown_pause_resume_and_reset_inputs_do_not_leak_into_capture() -> void:
	var race := _race(true)
	race._physics_process(GhostRun.DT)
	assert_true(race.capture.frames.is_empty())
	race.racing = true
	race.rider.process_mode = Node.PROCESS_MODE_PAUSABLE
	race._set_paused(true)
	race._physics_process(GhostRun.DT)
	assert_true(race.capture.frames.is_empty())
	Input.action_press(&"jump")
	race._set_paused(false)
	race._physics_process(GhostRun.DT)
	assert_eq(race.capture.frames.size(), 1)
	assert_eq(race.capture.frames[0][9], 0, "resume jump is consumed before capture")
	assert_true(race.rider.grounded)
	race.rider.reset_at(race.course.bounds.end + Vector3(100, -1000, 0), Vector3.RIGHT)
	race._physics_process(GhostRun.DT)
	assert_eq(race.capture.frames[-1][10], -1)
	assert_eq(race.rules.resets, 1)
	assert_eq(race.rules.elapsed_ms, 3033)
	var packed: Dictionary = race.capture.finish("sunny_sprint", race.rules.elapsed_ms)
	assert_true(GhostRun.valid(packed, "sunny_sprint", 3033))

func test_full_best_run_saved_loaded_and_replayed_by_physics_in_live_race() -> void:
	var race := _race()
	var positions: Array[Vector3] = []
	var speeds: Array[float] = []
	for tick in 24000:
		_drive_tick(race, true)
		positions.append(race.rider.global_position)
		speeds.append(race.rider.speed)
		if race.rules.finished:
			break
	assert_true(race.rules.finished, "driver must complete a real course; checkpoint %d, section %d, distance %s, speed %s, grounded %s, resets %s, pos %s" % [race.rules.next_checkpoint, race.rider.section, race.rider.distance, race.rider.speed, race.rider.grounded, race.rules.resets, race.rider.global_position])
	if not race.rules.finished:
		return
	assert_gt(race.rules.resets, 0, "run includes an actual fall and checkpoint reset")
	var loaded := SaveStore.load_from_path(PATH)
	assert_true(loaded.ok)
	var record: Dictionary = loaded.save.records.sunny_sprint
	assert_true(record.has("ghost"))
	if not record.has("ghost"):
		return
	assert_eq(record.ghost.frames.size(), positions.size())
	assert_eq(record.best_ms, race.rules.elapsed_ms)
	var replay_race := _race()
	assert_not_null(replay_race.ghost, "best ghost is actually present in the live race")
	if replay_race.ghost == null:
		return
	assert_ne(replay_race.ghost.course, replay_race.course)
	assert_ne(replay_race.ghost.course.features[0], replay_race.course.features[0])
	var cursor: int = replay_race.ghost.cursor
	replay_race.racing = false
	replay_race._physics_process(GhostRun.DT)
	assert_eq(replay_race.ghost.cursor, cursor, "countdown freezes replay")
	replay_race.racing = true
	replay_race._set_paused(true)
	replay_race._physics_process(GhostRun.DT)
	assert_eq(replay_race.ghost.cursor, cursor, "pause freezes replay")
	replay_race._set_paused(false)
	var max_error := 0.0
	var speed_error := 0.0
	# Live controls deliberately differ: only the saved input drives the ghost.
	Input.action_release(&"move_right")
	Input.action_press(&"brake")
	for tick in positions.size():
		replay_race._physics_process(GhostRun.DT)
		max_error = maxf(max_error, replay_race.ghost.rider.global_position.distance_to(positions[tick]))
		# Finish turns on cruise for the player after the final physics tick.
		speed_error = maxf(speed_error, absf(replay_race.ghost.rider.speed - speeds[tick]))
	assert_almost_eq(max_error, 0.0, 0.00001)
	assert_almost_eq(speed_error, 0.0, 0.00001)
	assert_true(replay_race.ghost.completed)
	assert_false(replay_race.ghost.diverged)
	assert_eq(replay_race.ghost.cursor, positions.size())
	assert_false(replay_race.rules.finished, "ghost cannot finish the player's race")
	var before: Vector3 = replay_race.ghost.rider.global_position
	replay_race.ghost.advance()
	assert_eq(replay_race.ghost.rider.global_position, before, "input exhaustion is safe")

	var repeat := GhostReplay.new()
	add_child_autofree(repeat)
	repeat.setup(record.ghost)
	var repeat_error := 0.0
	for tick in positions.size():
		repeat.advance()
		repeat_error = maxf(repeat_error, repeat.rider.global_position.distance_to(positions[tick]))
	assert_almost_eq(repeat_error, 0.0, 0.00001, "the same saved run replays repeatedly")
	assert_true(repeat.completed)
	assert_false(repeat.diverged)
	print("Verified ghost: %d ticks, %d ms, %d resets; two replays, maximum position error %s" % [positions.size(), record.best_ms, race.rules.resets, maxf(max_error, repeat_error)])

func test_unreadable_save_cannot_be_overwritten_by_fallback_progress_or_settings() -> void:
	var original := "{broken original save"
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(original)
	file.close()
	assert_false(SaveStore.load_from_path(PATH).ok)
	var fallback := SaveStore.default_save()
	SaveStore.record_best(fallback, "sunny_sprint", 50, "gold", 3, _short_run())
	assert_false(SaveStore.save_to_path(fallback, PATH))
	assert_eq(FileAccess.get_file_as_string(PATH), original)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))

func test_capture_limit_and_invalid_numeric_reset_frames_are_rejected() -> void:
	var capture := GhostRun.new()
	capture.frames.resize(GhostRun.MAX_FRAMES)
	capture.append(_frame())
	assert_true(capture.overflow)
	assert_true(capture.finish("sunny_sprint", 1200000).is_empty())
	for value in [NAN, INF, 0.5, "0", null]:
		var run := _short_run()
		run.frames[0][0] = value
		assert_false(GhostRun.valid(run, "sunny_sprint", 50))
	var bad_time := _short_run()
	bad_time.frames[0][10] = -1
	bad_time.checksum = GhostRun.checksum(bad_time)
	assert_false(GhostRun.valid(bad_time, "sunny_sprint", 50), "reset penalty must match the best time")

func _drive_tick(race: Node3D, fall_once := false) -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"flip_back")
	Input.action_release(&"jump")
	Input.action_release(&"brake")
	# Manual stepping does not advance Godot input-edge frames. Supply
	# exactly one effective edge only when the driver requests a hop.
	race.rider._jump_input_consumed = true
	# A minimal driver pedals along the rail and lets auto-level handle air.
	if race.rider.grounded:
		var sample: Dictionary = race.course.sample(race.rider.section, race.rider.distance)
		var direction: int = sample.drive
		Input.action_press(&"move_left" if direction < 0 else &"move_right")
		var section: CanyonCourse.Section = race.course.sections[race.rider.section]
		if sample.kind == CanyonCourse.NORMAL and race.rider.speed > 20.0:
			Input.action_press(&"brake")
		if section.fork >= 0 and section.length - race.rider.distance < 3.0:
			Input.action_press(&"flip_back")
		if section.next < 0 and section.length - race.rider.distance < 4.0:
			Input.action_press(&"jump")
			race.rider._jump_input_consumed = false
	# Drive off the start once: replay must reproduce a real fall/reset.
	if fall_once and race.rules.resets == 0:
		Input.action_release(&"move_right")
		Input.action_release(&"brake")
		Input.action_release(&"jump")
		Input.action_press(&"move_left")
		race.rider._jump_input_consumed = true
	race._physics_process(GhostRun.DT)

func test_rooftop_can_be_completed_by_inputs_and_saves_a_replay() -> void:
	var race := _race(false, "rooftop_precision")
	for tick in 24000:
		_drive_tick(race)
		if race.rules.finished:
			break
	assert_true(race.rules.finished, "rooftop must be traversable: gate %s, section %s" % [race.rules.next_checkpoint, race.rider.section])
	if race.rules.finished:
		var loaded := SaveStore.load_from_path(PATH)
		assert_true(loaded.ok)
		assert_true(loaded.save.records.rooftop_precision.has("ghost"))

func test_analog_controls_quantize_and_physically_incomplete_replay_stops() -> void:
	var wheel := WheelRider.new()
	Input.action_press(&"move_right", 0.333)
	Input.action_press(&"tabletop")
	wheel._jump_input_consumed = true
	var frame := GhostRun.capture(wheel)
	assert_eq(frame[1], 85)
	assert_eq(frame[8], 255)
	assert_eq(frame[9], 0)
	wheel.free()
	var replay := GhostReplay.new()
	add_child_autofree(replay)
	replay.setup(_short_run())
	for i in 3:
		replay.advance()
	assert_true(replay.diverged, "matching checksum alone cannot make an unfinished run finish")
	assert_false(replay.completed)
	assert_false(replay.visible)
