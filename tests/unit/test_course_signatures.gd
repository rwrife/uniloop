extends GutTest

const DT := 1.0 / 60.0
const SAVE_PATH := "user://signature_test.json"


func after_each() -> void:
	get_tree().paused = false
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)
	RaceSetup.track_id = RaceSetup.DEFAULT_TRACK
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	await wait_process_frames(2)


func _course(id: String) -> CanyonCourse:
	var course := CanyonCourse.new()
	course.track_id = id
	course.reduced_motion = true
	add_child_autofree(course)
	course.set_process(false)
	return course


func _wheel(course: CanyonCourse) -> WheelRider:
	var wheel := WheelRider.new()
	wheel.handling = WheelHandling.new()
	wheel.course = course
	wheel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child_autofree(wheel)
	wheel.set_physics_process(false)
	return wheel


func _approach(wheel: WheelRider, ahead := 6.0) -> void:
	var spot := wheel.course.signature.anchor
	wheel.place_on(spot.sec, spot.s - ahead)
	wheel.speed = wheel.handling.max_speed
	Input.action_press(&"move_right")


func _hit(wheel: WheelRider) -> void:
	for tick in 120:
		wheel._physics_process(DT)
		if wheel.course.signature.spent or not wheel.grounded or wheel.corkscrewing:
			return
	fail_test("Signature was not reached in two seconds")


func _on_coil(wheel: WheelRider, offset: float, speed := 32.0) -> void:
	var spot := wheel.course.signature.anchor
	wheel.place_on(spot.sec, spot.s + offset)
	wheel.speed = speed
	wheel.corkscrewing = true
	wheel._signature_latched = true
	wheel._place_corkscrew()


func _race(id: String) -> Node3D:
	RaceSetup.track_id = id
	var race: Node3D = load("res://scenes/practice.tscn").instantiate()
	race.save_path = SAVE_PATH
	race.countdown_enabled = false
	add_child_autofree(race)
	race.set_physics_process(false)
	race.rider.set_physics_process(false)
	return race


func _control(controller: bool, key: Key, button: JoyButton, pressed: bool) -> void:
	if controller:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()


func _touch(race: Node3D, finger: int, action: StringName, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = race._touch_buttons[action].get_global_rect().get_center()
	event.pressed = pressed
	race._handle_touch(event)


func test_all_five_courses_have_one_exclusive_supported_signature() -> void:
	var expected := {
		"sunny_sprint": "trampoline", "canyon_climb": "corkscrew",
		"neon_night": "flux_gate", "goo_gauntlet": "binding_bubble",
		"the_monopoly": "quota_crate",
	}
	var unique := {}
	for track in RaceSetup.TRACKS:
		var course := _course(track.id)
		var signature := course.signature
		assert_false(signature.spent, "new race restores the signature")
		assert_eq(signature.kind, expected[track.id])
		var count := 0
		for child in course.get_children():
			if child is CourseSignature:
				count += 1
		assert_eq(count, 1)
		unique[signature.kind] = true
		assert_eq(signature.anchor.sec, course.gates[0].sec)
		assert_gt(signature.anchor.s, course.gates[0].s + 10.0)
		assert_eq(course.sample(signature.anchor.sec, signature.anchor.s).kind, CanyonCourse.NORMAL)
		assert_almost_eq(course.sample(signature.anchor.sec, signature.anchor.s).n.y, 1.0, 0.001)
		assert_not_null(signature.get_node("SignatureCollision").get_child(0).shape)
		assert_true(track.signature.name in signature.get_node("SignatureSign").text)
		assert_gt(course.goo_pits, 0, "existing goo remains")
		assert_gt(course.loops, 0, "existing loops remain")
		assert_gt(course.forks.size(), 0, "existing forks remain")
		assert_gt(course.gaps.size(), 0, "existing jumps remain")
	assert_eq(unique.size(), 5)


func test_signature_and_apple_positions_are_deterministic() -> void:
	for track in RaceSetup.TRACKS:
		var first := _course(track.id)
		var second := _course(track.id)
		assert_eq(first.signature.anchor, second.signature.anchor, track.id)
		assert_eq(first.gates, second.gates, track.id)
		if first.apples != null:
			assert_eq(first.apples.remaining.size(), second.apples.remaining.size())
			for index in first.apples.remaining.size():
				assert_eq(first.apples.remaining[index].position, second.apples.remaining[index].position)


func test_trampoline_launches_high_and_two_flips_land_cleanly() -> void:
	var wheel := _wheel(_course("sunny_sprint"))
	_approach(wheel)
	_hit(wheel)
	assert_false(wheel.grounded)
	assert_almost_eq(wheel.velocity.y, CourseSignature.TRAMPOLINE_SPEED, 0.001)
	assert_gt(wheel.velocity.y, wheel.handling.jump_speed * 2.0)
	Input.action_release(&"move_right")
	var reports: Array[Dictionary] = []
	wheel.landed.connect(func(report: Dictionary) -> void: reports.append(report))
	Input.action_press(&"flip_back")
	var peak := wheel.global_position.y
	for tick in 80:
		wheel._physics_process(DT)
		peak = maxf(peak, wheel.global_position.y)
	Input.action_release(&"flip_back")
	for tick in 100:
		if wheel.grounded:
			break
		wheel._physics_process(DT)
	assert_gt(peak - wheel.course.signature.anchor.pos.y, 14.0)
	assert_eq(reports.size(), 1)
	if reports.size() == 1:
		assert_false(reports[0].crash)
		assert_eq(reports[0].count, 2)
		assert_gt(reports[0].air_time, 2.0)


func test_trampoline_landing_precedes_rail_and_rearms_only_after_leaving() -> void:
	var course := _course("sunny_sprint")
	var wheel := _wheel(course)
	var at: Vector3 = course.signature.anchor.pos
	var contacts := [0]
	wheel.took_off.connect(func() -> void: contacts[0] += 1)
	wheel.reset_at(at + Vector3.UP * 1.1, Vector3.RIGHT)
	wheel.velocity = Vector3(0, -28, 0)
	wheel.air_time = 0.1
	wheel._physics_process(DT)
	assert_almost_eq(wheel.velocity.y, 28.0, 0.001, "pad catches before the underlying rail")
	for tick in 180:
		wheel._physics_process(DT)
	assert_eq(contacts[0], 1, "standing on a spring cannot repeatedly trigger or farm bounces")
	assert_true(wheel.grounded)
	assert_true(wheel._signature_latched)
	_approach(wheel)
	_hit(wheel)
	assert_eq(contacts[0], 2, "a new approach can bounce again")


func test_trampoline_boost_cap_arc_lands_before_existing_obstacles() -> void:
	var course := _course("sunny_sprint")
	var wheel := _wheel(course)
	_approach(wheel)
	wheel.speed = wheel.handling.max_speed * wheel.handling.boost_cap
	_hit(wheel)
	Input.action_release(&"move_right")
	for tick in 180:
		if wheel.grounded:
			break
		wheel._physics_process(DT)
	assert_true(wheel.grounded)
	assert_eq(wheel.recover_time, 0.0, "launch stays below the hard-landing limit")
	assert_lt(wheel.distance, course.signature.anchor.s + 150.0, "full boosted arc fits on its flat runway")


func test_flux_gate_charges_only_braked_ground_contacts() -> void:
	var charged := _wheel(_course("neon_night"))
	_approach(charged, 1.3)
	Input.action_press(&"brake")
	_hit(charged)
	assert_true(charged.course.signature.spent)
	assert_almost_eq(charged.speed, 48.0, 0.001)
	assert_gt(charged.boost_time, 0.0)
	Input.action_release(&"brake")
	var drained := _wheel(_course("neon_night"))
	_approach(drained, 1.3)
	drained.boost_time = 2.0
	_hit(drained)
	assert_almost_eq(drained.speed, 8.0, 0.001)
	assert_eq(drained.boost_time, 0.0)
	_approach(drained, 1.3)
	drained._physics_process(DT)
	assert_almost_eq(drained.speed, 32.0, 0.001, "a drained gate cannot trigger again after reset")
	var airborne := _wheel(_course("neon_night"))
	var at: Vector3 = airborne.course.signature.anchor.pos
	airborne.reset_at(at + Vector3(-3, 1, 0), Vector3.RIGHT)
	airborne.velocity = Vector3(32, 0, 0)
	Input.action_press(&"brake")
	for tick in 8:
		airborne._physics_process(DT)
	assert_true(airborne.course.signature.spent)
	assert_lte(airborne.velocity.x, 8.0, "air braking cannot manufacture a charged ground contact")


func test_quota_crate_costs_momentum_not_score_and_stays_broken() -> void:
	var course := _course("the_monopoly")
	var wheel := _wheel(course)
	_approach(wheel, 1.8)
	_hit(wheel)
	assert_true(course.signature.spent)
	assert_almost_eq(wheel.speed, 32.0 * 0.55, 0.001)
	assert_false(course.signature.get_node("Mechanism").visible)
	var fruit_count := course.apples.remaining.size()
	_approach(wheel, 1.8)
	wheel._physics_process(DT)
	assert_almost_eq(wheel.speed, 32.0, 0.001, "checkpoint retry does not penalize twice")
	assert_eq(course.apples.remaining.size(), fruit_count, "apples remain separate pickups")


func test_bubble_binds_ignores_inputs_and_releases_at_crawl_speed() -> void:
	var wheel := _wheel(_course("goo_gauntlet"))
	_approach(wheel)
	_hit(wheel)
	assert_almost_eq(wheel.bind_time, CourseSignature.BIND_SECONDS, 0.001)
	assert_true(wheel.course.signature.get_node("Mechanism").visible, "bubble stays visible while binding")
	var where := wheel.global_position
	Input.action_press(&"brake")
	Input.action_press(&"jump")
	Input.action_press(&"move_left")
	for tick in 47:
		wheel._physics_process(DT)
	assert_eq(wheel.global_position, where)
	assert_true(wheel.grounded)
	assert_eq(wheel.speed, 0.0)
	wheel._physics_process(0.02)
	assert_eq(wheel.bind_time, 0.0)
	assert_eq(wheel.speed, wheel.handling.goo_speed)
	assert_false(wheel.course.signature.get_node("Mechanism").visible, "bubble pops on release")
	Input.action_release(&"jump")
	Input.action_release(&"brake")
	Input.action_release(&"move_left")
	await wait_process_frames(2)
	wheel._physics_process(DT)
	assert_gt(wheel.global_position.x, where.x)
	assert_true(wheel.course.signature.spent)
	_approach(wheel)
	for tick in 20:
		wheel._physics_process(DT)
	assert_eq(wheel.bind_time, 0.0, "bubble cannot bind again after a reset")


func test_ordinary_well_timed_hops_clear_all_three_blockers() -> void:
	for id in ["neon_night", "goo_gauntlet", "the_monopoly"]:
		var wheel := _wheel(_course(id))
		_approach(wheel, 12.0)
		var sample := wheel.course.sample(wheel.section, wheel.distance)
		wheel._leave_ground(sample.seg_t * wheel.speed + sample.n * wheel.handling.jump_speed)
		Input.action_release(&"move_right")
		for tick in 52:
			wheel._physics_process(DT)
		assert_false(wheel.course.signature.spent, id + ": ordinary jump avoids contact")
		assert_true(wheel.grounded, id + ": returns to the runway")
		assert_eq(wheel.recover_time, 0.0, id + ": no landing crash")


func test_sweeps_do_not_tunnel_and_respect_depth_height_and_boundaries() -> void:
	for id in ["sunny_sprint", "neon_night", "goo_gauntlet", "the_monopoly"]:
		var signature := _course(id).signature
		var origin: Vector3 = signature.anchor.pos
		var center := origin + Vector3.UP * 0.65
		assert_false(signature.sweep(center - Vector3.RIGHT * 20, center + Vector3.RIGHT * 20, 0.65).is_empty(), id)
		for offset in [Vector3(0, 0, 4), Vector3(0, 5, 0)]:
			assert_true(signature.sweep(center + offset - Vector3.RIGHT * 20, center + offset + Vector3.RIGHT * 20, 0.65).is_empty(), id)
		assert_true(signature.sweep(center - Vector3.RIGHT * 20, center - Vector3.RIGHT * 20, 0.65).is_empty())
	var pad := _course("sunny_sprint").signature
	var at: Vector3 = pad.anchor.pos
	assert_true(pad.sweep(at - Vector3.UP * 3, at + Vector3.UP * 3, 0.65).is_empty(), "underside is one-way")
	var box := _course("the_monopoly").signature
	at = box.anchor.pos + Vector3(0, 0.65, box.volume.size.z * 0.5 + 0.65)
	assert_false(box.sweep(at - Vector3.RIGHT * 5, at + Vector3.RIGHT * 5, 0.65).is_empty(), "exact box boundary contacts")
	at.z += 0.001
	assert_true(box.sweep(at - Vector3.RIGHT * 5, at + Vector3.RIGHT * 5, 0.65).is_empty())
	at = box.anchor.pos + box.volume.end + Vector3(0.585, 0.585, -1.2)
	assert_true(box.sweep(at, at, 0.65).is_empty(), "rounded box corner does not hit just because broadphase overlaps")
	var bubble := _course("goo_gauntlet").signature
	at = bubble.anchor.pos + bubble.volume.get_center() + Vector3(0, 0, 1.5)
	assert_false(bubble.sweep(at - Vector3.RIGHT * 5, at + Vector3.RIGHT * 5, 0.65).is_empty(), "sphere tangent contacts")
	at.z += 0.001
	assert_true(bubble.sweep(at - Vector3.RIGHT * 5, at + Vector3.RIGHT * 5, 0.65).is_empty())


func test_pause_zero_delta_and_reset_are_safe_for_every_mechanic() -> void:
	for track in RaceSetup.TRACKS:
		var wheel := _wheel(_course(track.id))
		_approach(wheel)
		if track.id == "canyon_climb":
			_on_coil(wheel, 18.0)
		else:
			_hit(wheel)
		var where := wheel.global_position
		var speed := wheel.speed
		var binding := wheel.bind_time
		wheel._physics_process(0.0)
		assert_eq(wheel.global_position, where)
		get_tree().paused = true
		wheel._physics_process(1.0)
		assert_eq(wheel.global_position, where, track.id)
		assert_eq(wheel.speed, speed)
		assert_eq(wheel.bind_time, binding)
		assert_false(wheel.course.signature.can_process())
		get_tree().paused = false
		wheel.place_on(wheel.course.start_spot.sec, wheel.course.start_spot.s)
		assert_false(wheel.corkscrewing)
		assert_false(wheel.signature_falling)
		assert_false(wheel._signature_latched)
		assert_eq(wheel.bind_time, 0.0)
		assert_eq(wheel.velocity, Vector3.ZERO)


func test_corkscrew_is_optional_and_both_up_and_down_pump() -> void:
	var straight := _wheel(_course("canyon_climb"))
	_approach(straight, 1.0)
	for tick in 5:
		straight._physics_process(DT)
	assert_false(straight.corkscrewing)
	assert_almost_eq(straight.global_position.z, straight.course.signature.anchor.pos.z, 0.001)
	for action in [&"flip_back", &"roll_forward"]:
		var wheel := _wheel(_course("canyon_climb"))
		_approach(wheel, 0.1)
		Input.action_press(&"flip_back")
		wheel._physics_process(DT)
		assert_true(wheel.corkscrewing)
		Input.action_release(&"flip_back")
		Input.action_press(action)
		var before := wheel.speed
		for tick in 10:
			wheel._physics_process(DT)
		assert_gt(wheel.speed, before, str(action))
		assert_eq(wheel.flip_air, 0.0, "pumping is not an airborne trick")
		assert_lte(wheel.speed, CourseSignature.CORK_MAX_SPEED)
		Input.action_release(action)


func test_pumped_corkscrew_beats_straight_route_and_coasting_does_not() -> void:
	var course := _course("canyon_climb")
	var wheel := _wheel(course)
	var times: Array[float] = []
	for pump in [false, true]:
		_on_coil(wheel, 0.0)
		if pump:
			Input.action_press(&"roll_forward")
		else:
			Input.action_release(&"roll_forward")
		var time := 0.0
		while wheel.corkscrewing and time < 6.0:
			wheel._physics_process(DT)
			time += DT
		assert_lt(time, 6.0, "coil cannot trap the rider forever")
		times.append(time)
		if pump:
			assert_true(wheel.grounded)
			assert_false(wheel.signature_falling)
			assert_almost_eq(wheel.distance, course.signature.anchor.s + CourseSignature.CORK_LENGTH, 0.001)
			assert_almost_eq(wheel.global_position.z, course.signature.anchor.pos.z, 0.001)
		else:
			assert_false(wheel.grounded, "unpowered run loses grip before the end")
			assert_lt(wheel.distance, course.signature.anchor.s + CourseSignature.CORK_LENGTH)
	Input.action_release(&"roll_forward")
	wheel.place_on(course.signature.anchor.sec, course.signature.anchor.s)
	wheel.speed = wheel.handling.max_speed
	Input.action_press(&"move_right")
	var straight_time := 0.0
	while wheel.distance < course.signature.anchor.s + CourseSignature.CORK_LENGTH and straight_time < 6.0:
		wheel._physics_process(DT)
		straight_time += DT
	assert_lt(times[1], straight_time - 0.25, "shortcut must measurably beat the straight rail")
	assert_gt(times[0], straight_time, "coasting does not give a free shortcut")


func test_top_exit_lands_but_side_and_upside_down_exits_must_fall() -> void:
	var course := _course("canyon_climb")
	for offset in [0.0, 36.0, 72.0]:
		var wheel := _wheel(course)
		_on_coil(wheel, offset)
		wheel._exit_corkscrew()
		assert_false(wheel.signature_falling, "top exit at " + str(offset))
		assert_gt(wheel.velocity.y, 0.0)
		Input.action_release(&"move_right")
		for tick in 90:
			if wheel.grounded:
				break
			wheel._physics_process(DT)
		assert_true(wheel.grounded)
		assert_eq(wheel.recover_time, 0.0)
	for offset in [9.0, 18.0, 27.0, 54.0]:
		var wheel := _wheel(course)
		_on_coil(wheel, offset)
		wheel._exit_corkscrew()
		assert_true(wheel.signature_falling, "unsafe exit at " + str(offset))
		assert_lt(wheel.velocity.y, 0.0)
		for tick in 60:
			wheel._physics_process(DT)
		assert_false(wheel.grounded, "underside exit cannot become a one-way rail catch")


func test_early_top_shortcut_beats_the_straight_rail_without_a_landing_crash() -> void:
	var course := _course("canyon_climb")
	var wheel := _wheel(course)
	_on_coil(wheel, 0.0)
	Input.action_press(&"roll_forward")
	var elapsed := 0.0
	while wheel.distance < course.signature.anchor.s + 36.0 and elapsed < 3.0:
		wheel._physics_process(DT)
		elapsed += DT
	Input.action_release(&"roll_forward")
	wheel._exit_corkscrew()
	assert_false(wheel.signature_falling)
	while not wheel.grounded and elapsed < 4.0:
		wheel._physics_process(DT)
		elapsed += DT
	assert_true(wheel.grounded)
	assert_eq(wheel.recover_time, 0.0)
	assert_gte(wheel.distance, course.signature.anchor.s + CourseSignature.CORK_LENGTH)
	assert_lt(elapsed, CourseSignature.CORK_LENGTH / wheel.handling.max_speed - 0.2)


func test_coil_exit_threshold_stall_and_entry_boundaries() -> void:
	var course := _course("canyon_climb")
	var signature := course.signature
	assert_false(signature.enters(signature.anchor.sec, signature.anchor.s, signature.anchor.s + 1.0), "starting at entry does not retrigger")
	assert_false(signature.enters(signature.anchor.sec + 1, signature.anchor.s - 1.0, signature.anchor.s + 1.0), "another section cannot enter")
	assert_false(signature.enters(signature.anchor.sec, signature.anchor.s + 1.0, signature.anchor.s - 1.0), "reverse crossing does not enter")
	var boundary := acos(0.85) * CourseSignature.CORK_LENGTH / (TAU * CourseSignature.CORK_TURNS)
	for offset in [boundary - 0.001, boundary + 0.001]:
		var wheel := _wheel(course)
		_on_coil(wheel, offset)
		wheel._exit_corkscrew()
		assert_eq(wheel.signature_falling, offset > boundary)
	var stalled := _wheel(course)
	_on_coil(stalled, 18.0, CourseSignature.CORK_MIN_SPEED)
	stalled._physics_process(DT)
	assert_false(stalled.corkscrewing)
	assert_true(stalled.signature_falling)
	var sample := signature.cork_sample(-1.0, 0.65)
	assert_almost_eq(sample.n.y, 1.0, 0.001)
	sample = signature.cork_sample(CourseSignature.CORK_LENGTH + 1.0, 0.65)
	assert_almost_eq(sample.n.y, 1.0, 0.001)


func test_underside_fall_recovers_at_last_checkpoint_without_skipping_gates() -> void:
	var race := _race("canyon_climb")
	race.rider.speed = 32.0
	race._on_checkpoint(race.rider, 0)
	assert_eq(race.rules.next_checkpoint, 1)
	_on_coil(race.rider, 18.0)
	race.rider._exit_corkscrew()
	race._last_pos = race.rider.global_position
	for tick in 240:
		race.rider._physics_process(DT)
		race._physics_process(DT)
		if race.rules.resets > 0:
			break
	assert_eq(race.rules.resets, 1)
	assert_eq(race.rules.next_checkpoint, 1, "fall does not skip or erase checkpoints")
	assert_false(race.rules.finished)
	assert_true(race.rider.grounded)
	assert_false(race.rider.signature_falling)
	assert_false(race.rider.corkscrewing)
	assert_eq(race.rider.section, race.course.gates[0].sec)
	assert_eq(race.rider.distance, race.course.gates[0].s)
	assert_true("FELL!" in race.popup.text)


func test_crate_contact_does_not_change_race_points() -> void:
	var race := _race("the_monopoly")
	race.rules.score = 700
	_approach(race.rider, 1.8)
	race._last_pos = race.rider.global_position
	_hit(race.rider)
	race._physics_process(DT)
	assert_eq(race.rules.score, 700)
	assert_true(race.course.signature.spent)


func test_keyboard_and_gamepad_enter_pump_and_jump_off_the_coil() -> void:
	for controller in [false, true]:
		var wheel := _wheel(_course("canyon_climb"))
		_approach(wheel, 0.1)
		_control(controller, KEY_UP, JOY_BUTTON_DPAD_UP, true)
		wheel._physics_process(DT)
		assert_true(wheel.corkscrewing, "real input enters")
		_control(controller, KEY_UP, JOY_BUTTON_DPAD_UP, false)
		_control(controller, KEY_DOWN, JOY_BUTTON_DPAD_DOWN, true)
		var before := wheel.speed
		for tick in 10:
			wheel._physics_process(DT)
		assert_gt(wheel.speed, before, "real Down input pumps")
		_control(controller, KEY_DOWN, JOY_BUTTON_DPAD_DOWN, false)
		wheel.distance = wheel.course.signature.anchor.s + 36.0
		wheel._place_corkscrew()
		_control(controller, KEY_SPACE, JOY_BUTTON_A, true)
		wheel._physics_process(DT)
		assert_false(wheel.corkscrewing, "fresh Jump exits")
		assert_false(wheel.grounded)
		assert_false(wheel.signature_falling, "top exit is safe")
		_control(controller, KEY_SPACE, JOY_BUTTON_A, false)
		Input.action_release(&"move_right")
		await wait_process_frames(2)


func test_touch_enters_and_pumps_and_pause_releases_fingers_without_advancing() -> void:
	var race := _race("canyon_climb")
	if race._touch_buttons.is_empty():
		race._build_touch_overlay()
	race._apply_safe_area()
	_approach(race.rider, 0.1)
	Input.action_release(&"move_right")
	_touch(race, 0, &"move_right", true)
	_touch(race, 1, &"flip_back", true)
	race.rider._physics_process(DT)
	assert_true(race.rider.corkscrewing)
	_touch(race, 1, &"flip_back", false)
	_touch(race, 2, &"roll_forward", true)
	var before: float = race.rider.speed
	for tick in 10:
		race.rider._physics_process(DT)
	assert_gt(race.rider.speed, before)
	var where: Vector3 = race.rider.global_position
	race._set_paused(true)
	assert_false(Input.is_action_pressed(&"roll_forward"))
	assert_false(Input.is_action_pressed(&"move_right"))
	race.rider._physics_process(1.0)
	assert_eq(race.rider.global_position, where)
	race._set_paused(false)
	assert_true(race.rider.corkscrewing, "resume preserves attachment")
	race.rider.distance = race.course.signature.anchor.s + 36.0
	race.rider._place_corkscrew()
	_touch(race, 3, &"jump", true)
	race.rider._physics_process(DT)
	assert_false(race.rider.corkscrewing)
	assert_false(race.rider.signature_falling)
	race._release_touches()


func test_signature_actions_keep_keyboard_gamepad_and_touch_bindings() -> void:
	for action in [&"flip_back", &"roll_forward", &"jump", &"brake"]:
		var keyboard := false
		var controller := false
		for event in InputMap.action_get_events(action):
			keyboard = keyboard or event is InputEventKey
			controller = controller or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(keyboard, str(action))
		assert_true(controller, str(action))
		assert_false(UniloopUI.prompt(action, "touch").is_empty())


func test_help_discovers_every_signature_with_adaptive_input_prompts() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.auto_launch = false
	add_child_autofree(menu)
	menu.current_device = "touch"
	menu._open("help")
	var text := ""
	for child in menu.panel_body.get_children():
		if child is Label:
			text += child.text + "\n"
	for track in RaceSetup.TRACKS:
		assert_true(track.signature.name in text)
		assert_false(track.blurb.is_empty())
	assert_true("Flip/Roll" in text)
	assert_true("checkpoint" in text)
