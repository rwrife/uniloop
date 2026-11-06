extends GutTest

const DT := 1.0 / 60.0
const SAVE_PATH := "user://feature_test.json"
const KINDS := ["bounce", "spiral", "updraft"]


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


func _first(course: CanyonCourse, kind: String) -> CourseFeature:
	for feature in course.features:
		if feature.kind == kind:
			return feature
	return null


## Rolls toward `feature` at full speed, holding the leg's forward direction.
func _approach(wheel: WheelRider, feature: CourseFeature, ahead := 8.0) -> void:
	wheel.place_on(feature.anchor.sec, feature.anchor.s - ahead)
	wheel.speed = wheel.handling.max_speed
	Input.action_press(&"move_right" if feature.dir > 0 else &"move_left")


func _ride(wheel: WheelRider, seconds: float, crashes: Array) -> float:
	var peak := -INF
	for tick in int(seconds / DT):
		wheel._physics_process(DT)
		peak = maxf(peak, wheel.global_position.y)
		if wheel.recover_time > 0.0:
			crashes.append(wheel.global_position)
			break
		if wheel.course.out_of_bounds(wheel.global_position):
			crashes.append("out of bounds")
			break
	return peak


func test_every_course_scatters_a_feature_after_every_checkpoint() -> void:
	for track in RaceSetup.TRACKS:
		var course := _course(track.id)
		assert_eq(course.features.size(), course.gates.size(), track.id)
		assert_gte(course.features.size(), 5, track.id + " has plenty of features")
		var kinds := {}
		for index in course.features.size():
			var feature := course.features[index]
			assert_has(KINDS, feature.kind, track.id)
			assert_eq(feature.kind, track.features[index % track.features.size()], track.id)
			assert_eq(feature.anchor.sec, course.gates[index].sec, track.id)
			assert_gt(feature.anchor.s, course.gates[index].s + 10.0, track.id)
			assert_almost_eq(course.sample(feature.anchor.sec, feature.anchor.s).n.y, 1.0, 0.001, track.id)
			var end := course.sample(feature.anchor.sec, feature.anchor.s + feature.length)
			assert_almost_eq(end.pos.y, feature.anchor.pos.y, 0.001, track.id + " feature runs on flat rail")
			assert_eq(course.feature_at(feature.anchor.sec, feature.anchor.s + 1.0), feature)
			kinds[feature.kind] = true
		assert_gte(kinds.size(), 2, track.id + " mixes feature kinds")
		assert_false(track.has("signature"), "old one-off signatures are gone")
	for track in RaceSetup.TRACKS.slice(0, 5):
		var course := _course(track.id)
		assert_gt(course.goo_pits, 0, "existing goo remains")
		assert_gt(course.loops, 0, "existing loops remain")
		assert_gt(course.forks.size(), 0, "existing forks remain")
	var sunny := _course("sunny_sprint")
	var bounces := 0
	for feature in sunny.features:
		bounces += 1 if feature.kind == "bounce" else 0
	assert_gte(bounces, 3, "Sunny Sprint is the bounce-floor course")


func test_all_courses_keep_gate_labels_without_instruction_signs() -> void:
	for track in RaceSetup.TRACKS:
		var course := _course(track.id)
		assert_null(course.get_node_or_null("Junction"), track.id)
		var labels := course.find_children("*", "Label3D", true, false)
		assert_eq(labels.size(), course.gates.size() + 1, track.id)
		for label in labels:
			var gate := label.get_parent()
			assert_true(gate.name == &"Finish" or String(gate.name).begins_with("Checkpoint"), track.id)
		assert_eq(course.get_node("Finish").get_child(2).text, "FINISH", track.id)


func test_feature_and_apple_positions_are_deterministic() -> void:
	for track in RaceSetup.TRACKS:
		var first := _course(track.id)
		var second := _course(track.id)
		assert_eq(first.features.size(), second.features.size(), track.id)
		for index in first.features.size():
			assert_eq(first.features[index].anchor, second.features[index].anchor, track.id)
		assert_eq(first.gates, second.gates, track.id)
		if first.apples != null:
			assert_eq(first.apples.remaining.size(), second.apples.remaining.size())
			for index in first.apples.remaining.size():
				assert_eq(first.apples.remaining[index].position, second.apples.remaining[index].position)


func test_bounce_floor_is_a_colored_stretch_that_bends_under_the_wheel() -> void:
	var course := _course("sunny_sprint")
	var floor := _first(course, "bounce")
	assert_not_null(floor.get_node("Visual/BounceFloor"))
	assert_eq(course.sample(floor.anchor.sec, floor.anchor.s + 4.0).kind, CanyonCourse.BOUNCE)
	var wheel := _wheel(course)
	wheel.place_on(floor.anchor.sec, floor.anchor.s + 8.0)
	wheel.speed = 4.0
	Input.action_press(&"move_right" if floor.dir > 0 else &"move_left")
	wheel._physics_process(DT)
	assert_true(wheel.grounded, "riding over the floor never launches")
	var rail: Vector3 = course.sample(wheel.section, wheel.distance).pos
	assert_almost_eq(rail.y + wheel.handling.wheel_radius - wheel.global_position.y, CourseFeature.BOUNCE_SAG, 0.01, "wheel sinks into the floor")
	floor._process(0.05)
	floor._process(0.05)
	var bent := floor._pad_y[roundi((wheel.distance - floor.anchor.s) / CourseFeature.BOUNCE_SEGMENT)]
	assert_lt(bent, -0.05, "floor visibly bends under the wheel")
	for tick in 120:
		floor._process(DT)
	wheel.place_on(course.start_spot.sec, course.start_spot.s)
	for tick in 240:
		floor._process(DT)
	assert_almost_eq(floor._pad_y[0] + floor._pad_y[20], 0.0, 0.02, "floor springs back flat")


func test_hopping_onto_a_bounce_floor_springs_far_higher_than_a_hop() -> void:
	var course := _course("sunny_sprint")
	var floor := _first(course, "bounce")
	var plain := _wheel(course)
	plain.place_on(course.start_spot.sec, course.start_spot.s)
	var base := plain.global_position.y
	plain._leave_ground(Vector3(0, plain.handling.jump_speed, 0))
	var hop_peak := _ride(plain, 1.5, [])
	var wheel := _wheel(course)
	wheel.place_on(floor.anchor.sec, floor.anchor.s + 4.0)
	wheel.global_position.y += 2.0
	wheel.grounded = false
	wheel.velocity = Vector3(0, -wheel.handling.jump_speed, 0)
	wheel.air_time = 1.0
	wheel.speed = 0.0
	var took_off := [0]
	wheel.took_off.connect(func() -> void: took_off[0] += 1)
	for tick in 20:
		wheel._physics_process(DT)
		if took_off[0] > 0:
			break
	assert_eq(took_off[0], 1, "landing on the floor bounces")
	assert_false(wheel.grounded)
	assert_between(wheel.velocity.y, CourseFeature.BOUNCE_MIN, CourseFeature.BOUNCE_MAX)
	var crashes := []
	var peak := _ride(wheel, 0.5, crashes)
	assert_gt(peak - floor.anchor.pos.y, (hop_peak - base) * 2.0, "bounce beats a plain hop")
	assert_true(crashes.is_empty())


func test_bounce_heights_grow_with_drop_and_cap() -> void:
	var floor := _first(_course("sunny_sprint"), "bounce")
	assert_eq(floor.bounce_speed(-2.0), CourseFeature.BOUNCE_MIN)
	assert_gt(floor.bounce_speed(-14.0), floor.bounce_speed(-11.0))
	assert_eq(floor.bounce_speed(-40.0), CourseFeature.BOUNCE_MAX)
	var wheel := _wheel(_course("sunny_sprint"))
	floor = _first(wheel.course, "bounce")
	wheel.place_on(floor.anchor.sec, floor.anchor.s + 6.0)
	wheel.speed = 10.0
	Input.action_press(&"jump")
	wheel._physics_process(DT)
	assert_false(wheel.grounded)
	assert_almost_eq(wheel.velocity.y, CourseFeature.BOUNCE_HOP, 0.5, "hopping off the floor springs high")


func test_spiral_grabs_rider_automatically_and_exits_on_top_with_boost() -> void:
	var course := _course("canyon_climb")
	var spiral := _first(course, "spiral")
	assert_not_null(spiral.get_node("Visual/Coil"))
	var wheel := _wheel(course)
	_approach(wheel, spiral)
	var boosted := [0]
	wheel.boosted.connect(func() -> void: boosted[0] += 1)
	var entered := false
	var lowest := INF
	for tick in 600:
		wheel._physics_process(DT)
		entered = entered or wheel.corkscrewing
		lowest = minf(lowest, wheel.global_position.y)
		if entered and not wheel.corkscrewing:
			break
	assert_true(entered, "no input needed to get on the spiral")
	assert_false(wheel.corkscrewing)
	assert_true(wheel.grounded, "exit lands back on top of the rail")
	assert_lt(lowest, spiral.anchor.pos.y - CourseFeature.CORK_RADIUS * 1.5, "rides under the coil")
	assert_eq(boosted[0], 1)
	assert_gt(wheel.speed, wheel.handling.max_speed)
	assert_almost_eq(wheel.distance, spiral.anchor.s + CourseFeature.CORK_LENGTH, 0.001)


func test_spiral_never_stalls_and_pumping_is_faster() -> void:
	var times := []
	for pump in [false, true]:
		var wheel := _wheel(_course("canyon_climb"))
		var spiral := _first(wheel.course, "spiral")
		wheel.place_on(spiral.anchor.sec, spiral.anchor.s + 0.1)
		wheel.speed = 1.0
		wheel._physics_process(DT)
		assert_true(wheel.corkscrewing, "even a crawl gets grabbed")
		assert_gte(wheel.speed, CourseFeature.CORK_MIN_SPEED)
		if pump:
			Input.action_press(&"flip_back")
		var time := 0.0
		while wheel.corkscrewing and time < 10.0:
			wheel._physics_process(DT)
			time += DT
			assert_gte(wheel.speed, CourseFeature.CORK_MIN_SPEED)
			assert_lte(wheel.speed, CourseFeature.CORK_MAX_SPEED)
		assert_false(wheel.corkscrewing)
		Input.action_release(&"flip_back")
		times.append(time)
	assert_lt(times[1], times[0] - 0.5, "pumping beats coasting")


func test_jumping_onto_a_spiral_still_catches_the_rider() -> void:
	var wheel := _wheel(_course("canyon_climb"))
	var spiral := _first(wheel.course, "spiral")
	_approach(wheel, spiral, 3.0)
	Input.action_press(&"jump")
	var entered := false
	for tick in 240:
		wheel._physics_process(DT)
		if wheel.corkscrewing:
			entered = true
			break
	assert_true(entered)


func test_updraft_lifts_a_rider_well_above_a_hop() -> void:
	var course := _course("neon_night")
	var fan := _first(course, "updraft")
	assert_null(fan.get_node_or_null("Visual/Column"), "no big wind tube")
	var housing: MeshInstance3D = fan.get_node("Visual/Housing")
	assert_lt(housing.position.y, -2.0, "fan hangs below the rail")
	assert_lte((housing.mesh as TorusMesh).outer_radius, 1.5, "fan is small")
	assert_gte(fan._streaks.size(), 10, "wind streaks show the updraft")
	var wheel := _wheel(course)
	_approach(wheel, fan)
	var crashes := []
	var peak := _ride(wheel, 3.0, crashes)
	assert_gt(peak - fan.anchor.pos.y, 4.0, "fan launches the rider")
	assert_true(fan.lifts(fan.anchor.pos + Vector3(fan.dir * 6.0, 3.0, 0)))
	assert_false(fan.lifts(fan.anchor.pos + Vector3(-fan.dir * 2.0, 3.0, 0)))
	assert_false(fan.lifts(fan.anchor.pos + Vector3(fan.dir * 6.0, CourseFeature.UPDRAFT_HEIGHT + 1.0, 0)))
	assert_true(crashes.is_empty())
	assert_true(wheel.grounded)


func test_every_feature_can_be_ridden_safely_at_speed() -> void:
	for track in RaceSetup.TRACKS:
		var course := _course(track.id)
		for index in course.features.size():
			var feature := course.features[index]
			for hop in [false, true]:
				var wheel := _wheel(course)
				_approach(wheel, feature, 5.0)
				if hop:
					Input.action_press(&"jump")
				var crashes := []
				var cleared := false
				var forward := &"move_right" if feature.dir > 0 else &"move_left"
				for tick in 300:
					if wheel.grounded or wheel.corkscrewing:
						Input.action_press(forward)
					else:
						Input.action_release(forward)
					wheel._physics_process(DT)
					if wheel.recover_time > 0.0 or wheel.course.out_of_bounds(wheel.global_position):
						crashes.append([tick, wheel.section, wheel.distance, wheel.global_position])
						break
					if wheel.grounded and not wheel.corkscrewing and wheel.section == feature.anchor.sec \
							and wheel.distance > feature.anchor.s + feature.length + 4.0:
						cleared = true
						break
				assert_true(cleared, "%s feature %d (%s) hop=%s rides through: %s" % [track.id, index, feature.kind, hop, [wheel.section, wheel.distance]])
				assert_true(crashes.is_empty(), "%s feature %d (%s) hop=%s: %s" % [track.id, index, feature.kind, hop, crashes])
				for action in UniloopUI.ACTIONS:
					Input.action_release(action)
				wheel.free()
				await wait_physics_frames(1)


func test_pause_zero_delta_and_reset_are_safe_on_a_spiral() -> void:
	var wheel := _wheel(_course("canyon_climb"))
	var spiral := _first(wheel.course, "spiral")
	wheel.place_on(spiral.anchor.sec, spiral.anchor.s - 0.5)
	wheel.speed = 20.0
	for tick in 30:
		wheel._physics_process(DT)
	assert_true(wheel.corkscrewing)
	var where := wheel.global_position
	var speed := wheel.speed
	wheel._physics_process(0.0)
	assert_eq(wheel.global_position, where)
	get_tree().paused = true
	wheel._physics_process(1.0)
	assert_eq(wheel.global_position, where)
	assert_eq(wheel.speed, speed)
	assert_false(spiral.can_process())
	get_tree().paused = false
	wheel.place_on(wheel.course.start_spot.sec, wheel.course.start_spot.s)
	assert_false(wheel.corkscrewing)
	assert_null(wheel.spiral)
	assert_eq(wheel.velocity, Vector3.ZERO)


func test_touch_pumps_the_spiral_and_pause_releases_fingers() -> void:
	RaceSetup.track_id = "canyon_climb"
	var race: Node3D = load("res://scenes/practice.tscn").instantiate()
	race.save_path = SAVE_PATH
	race.countdown_enabled = false
	add_child_autofree(race)
	race.set_physics_process(false)
	race.rider.set_physics_process(false)
	if race._touch_buttons.is_empty():
		race._build_touch_overlay()
	race._apply_safe_area()
	var spiral := _first(race.course, "spiral")
	race.rider.place_on(spiral.anchor.sec, spiral.anchor.s + 0.1)
	race.rider.speed = 20.0
	race.rider._physics_process(DT)
	assert_true(race.rider.corkscrewing)
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = race._touch_buttons[&"roll_forward"].get_global_rect().get_center()
	event.pressed = true
	race._handle_touch(event)
	var before: float = race.rider.speed
	for tick in 10:
		race.rider._physics_process(DT)
	assert_gt(race.rider.speed, before)
	var where: Vector3 = race.rider.global_position
	race._set_paused(true)
	assert_false(Input.is_action_pressed(&"roll_forward"))
	race.rider._physics_process(1.0)
	assert_eq(race.rider.global_position, where)
	race._set_paused(false)
	assert_true(race.rider.corkscrewing, "resume keeps riding the spiral")
	race._release_touches()


func test_help_explains_every_feature_with_adaptive_input_prompts() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.auto_launch = false
	add_child_autofree(menu)
	menu.current_device = "touch"
	menu._open("help")
	var text := ""
	for child in menu.panel_body.get_children():
		if child is Label:
			text += child.text + "\n"
	for name in ["BOUNCE FLOORS", "SPIRALS", "UPDRAFT FANS"]:
		assert_true(name in text, name)
	for track in RaceSetup.TRACKS:
		assert_false(track.blurb.is_empty())
	assert_true("Flip/Roll" in text)
	assert_true("checkpoint" in text)
	for old in ["TRAMPOLINE", "FLUX GATE", "BINDING BUBBLE", "QUOTA CRATE"]:
		assert_false(old in text, old)