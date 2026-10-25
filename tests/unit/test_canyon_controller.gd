extends GutTest
## GUT suite for the path-following rider, the zig-zag canyon course, stunts,
## crashes, one-way rails, gates and the finish roll-out / stats screen.

const HANDLING := preload("res://scripts/handling.gd")
const CANYON := preload("res://scripts/canyon.gd")
const RIDER := preload("res://scripts/wheel_rider.gd")
const PRACTICE := preload("res://scenes/practice.tscn")

func _practice() -> Node3D:
	var practice: Node3D = PRACTICE.instantiate()
	practice.save_path = "user://canyon_test_record.json"
	add_child_autofree(practice)
	return practice

func after_each() -> void:
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)

func test_handling_resource_has_valid_ranges() -> void:
	var h: WheelHandling = HANDLING.new()
	assert_gt(h.acceleration, 0.0)
	assert_gt(h.max_speed, h.reverse_speed)
	assert_gt(h.boost_cap, 1.0)
	assert_gt(h.spin_rate, 0.0)
	assert_gt(h.twist_rate, 0.0)
	assert_gt(h.zflip_rate, 0.0)
	assert_gt(h.jump_speed, 0.0)
	assert_gt(h.trick_boost, 0.0)
	assert_gt(h.recover_time, 0.0)
	assert_lt(h.goo_speed, h.max_speed)
	assert_gt(h.camera_distance, 0.0)

func test_canyon_course_has_zigzag_features() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	assert_gte(course.gates.size(), 6)
	assert_gte(course.loops, 4, "full 360 loops")
	assert_gte(course.uturns, 2, "helix U-turns")
	assert_gte(course.launches.size(), 2, "vertical launches")
	assert_gte(course.forks.size(), 2, "shortcut forks")
	assert_gt(course.gaps.size(), 0)
	assert_gt(course.boosts.size(), 0)
	var leftward := 0
	for gate in course.gates:
		if gate.t.x < 0.0:
			leftward += 1
	assert_gt(leftward, 0, "course doubles back to the left")
	assert_gt(course.finish.pos.y, course.start_spot.pos.y + 50.0, "course climbs")
	for node in ["Rail", "Chevrons", "Goo", "RibbonCollision", "Backdrop", "Finish"]:
		assert_not_null(course.get_node_or_null(node), node)
	var kinds := {}
	for sec in course.sections:
		for kind in sec.kinds:
			kinds[kind] = true
	for kind in [CanyonCourse.NORMAL, CanyonCourse.TURN, CanyonCourse.SHORTCUT, CanyonCourse.HAZARD, CanyonCourse.GOO]:
		assert_true(kinds.has(kind), "track kind %d is used" % kind)

func test_canyon_medals_valid() -> void:
	assert_true(RaceRules.valid_thresholds(CanyonCourse.MEDALS))
	assert_gte(CanyonCourse.MEDALS.gold, 120000, "level takes at least 2 minutes")
	assert_lte(CanyonCourse.MEDALS.bronze, 300000, "level fits in 5 minutes")

func test_rails_are_one_way() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	var gate: Dictionary = course.gates[0]
	var n: Vector3 = gate.n
	var r := 0.65
	var up := course.find_landing(gate.pos - n * 2.0, gate.pos + n * 3.0, n * 15.0, r)
	assert_true(up.is_empty(), "rising through the underside does not collide")
	var down := course.find_landing(gate.pos + n * 2.0, gate.pos + n * 0.3, -n * 15.0, r)
	assert_false(down.is_empty(), "falling onto the top lands")

func test_rider_instantiation_and_nodes() -> void:
	var rider: WheelRider = RIDER.new()
	rider.handling = HANDLING.new()
	add_child_autofree(rider)
	assert_not_null(rider.get_node_or_null("Pose/WheelPrimitive"))
	assert_not_null(rider.get_node_or_null("Pose/RiderPrimitive"))
	assert_eq(rider.speed, 0.0)

func test_rider_reset_behavior() -> void:
	var rider: WheelRider = RIDER.new()
	rider.handling = HANDLING.new()
	add_child_autofree(rider)
	rider.speed = 20.0
	rider.velocity = Vector3(10, 5, 0)
	rider.reset_at(Vector3(0, 2, 0), Vector3.LEFT)
	assert_eq(rider.speed, 0.0)
	assert_eq(rider.velocity, Vector3.ZERO)
	assert_eq(rider.global_position, Vector3(0, 2, 0))
	assert_false(rider.grounded)

func test_practice_scene_loads_and_instantiates() -> void:
	var practice := _practice()
	assert_not_null(practice.get_node_or_null("Hud/Root/Status"))
	assert_not_null(practice.get_node_or_null("Hud/Root/PausePanel/Box/Resume"))
	assert_not_null(practice.get_node_or_null("Hud/Root/StatsPanel"))
	assert_not_null(practice.get_node_or_null("Hud/Root/TrickPopup"))
	assert_true(practice.rider.grounded)

func test_ride_right_crosses_first_gate_side_on() -> void:
	var practice := _practice()
	var wheel: WheelRider = practice.rider
	await get_tree().physics_frame
	Input.action_press(&"move_right")
	for tick in 240:
		await get_tree().physics_frame
		if practice.rules.next_checkpoint > 0:
			break
	Input.action_release(&"move_right")
	await get_tree().process_frame
	var camera: Camera3D = practice.get_node("Camera")
	assert_eq(practice.rules.next_checkpoint, 1, "riding right reaches the first gate")
	assert_eq(practice.rules.resets, 0)
	assert_true(wheel.grounded)
	assert_almost_eq(wheel.global_position.z, 0.0, 0.01, "front layer")
	assert_almost_eq((-camera.global_basis.z).dot(Vector3.FORWARD), 1.0, 0.001, "camera looks side-on")
	assert_almost_eq(camera.global_position.x, wheel.global_position.x, 10.0, "camera tracks rider")

func test_rider_sticks_through_loop_top() -> void:
	var practice := _practice()
	var course: CanyonCourse = practice.course
	var wheel: WheelRider = practice.rider
	var found := false
	for i in course.sections.size():
		var sec: CanyonCourse.Section = course.sections[i]
		for k in sec.points.size():
			if sec.normals[k].y < -0.95 and sec.landable[k] == 1:
				wheel.place_on(i, sec.cum[k])
				found = true
				break
		if found:
			break
	assert_true(found, "a loop top exists")
	wheel.speed = 22.0
	var start: float = wheel.distance
	for tick in 15:
		await get_tree().physics_frame
	assert_true(wheel.grounded, "centripetal grip holds the rider upside down")
	assert_gt(wheel.distance, start + 3.0)

func _drop_onto_start(practice: Node3D, setup: Callable) -> Dictionary:
	var wheel: WheelRider = practice.rider
	var reports: Array = []
	wheel.landed.connect(func(report: Dictionary) -> void: reports.append(report))
	await get_tree().physics_frame
	var spot: Dictionary = practice.course.start_spot
	wheel.reset_at(spot.pos + Vector3(0, 3.5, 0), Vector3.RIGHT)
	setup.call(wheel)
	for tick in 90:
		await get_tree().physics_frame
		if not reports.is_empty():
			break
	return reports[0] if not reports.is_empty() else {}

func test_roll_lands_clean_and_scores() -> void:
	var practice := _practice()
	var report := await _drop_onto_start(practice, func(wheel: WheelRider) -> void:
		wheel.flip_air = -TAU
		wheel.pitch = -TAU)
	assert_false(report.is_empty(), "rider landed")
	assert_false(report.crash)
	assert_true("ROLL" in report.tricks, "forward 360 is a roll")
	assert_gte(practice.rules.score, 500)
	assert_eq(practice.tricks_landed, 1)

func test_twist_and_zflip_count() -> void:
	var practice := _practice()
	var report := await _drop_onto_start(practice, func(wheel: WheelRider) -> void:
		wheel.twist_air = PI
		wheel.twist = PI
		wheel.zflip_air = TAU
		wheel.zflip = TAU)
	assert_false(report.crash)
	assert_true("TWIST 180" in report.tricks)
	assert_true("Z-FLIP" in report.tricks)
	assert_eq(report.count, 2)

func test_bad_landing_crashes_and_costs_points() -> void:
	var practice := _practice()
	practice.rules.score = 1000
	var report := await _drop_onto_start(practice, func(wheel: WheelRider) -> void:
		wheel.flip_air = 2.7
		wheel.pitch = 2.7)
	assert_true(report.crash, "landing on the seat is a wipeout")
	assert_eq(practice.rules.score, 1000 - practice.CRASH_PENALTY)
	assert_eq(practice.crashes, 1)
	assert_eq(practice.rider.speed, 0.0)
	assert_gt(practice.rider.recover_time, 0.0, "rider stops to recover")

func test_finish_rolls_off_right_and_shows_stats() -> void:
	var practice := _practice()
	var wheel: WheelRider = practice.rider
	await get_tree().physics_frame
	wheel.speed = 10.0
	practice._on_finish(wheel)
	assert_false(practice.rules.finished, "finish needs every gate")
	for i in practice.course.gates.size():
		practice._on_checkpoint(wheel, i)
	practice._on_finish(wheel)
	assert_true(practice.rules.finished)
	assert_true(wheel.cruise)
	assert_eq(practice.save.records[CanyonCourse.COURSE_ID].medal, "gold")
	var start_x := wheel.global_position.x
	for tick in 300:
		await get_tree().process_frame
		if practice.stats_panel.visible:
			break
	assert_true(practice.stats_panel.visible, "stats screen appears after the roll-out")
	assert_gt(wheel.global_position.x, start_x + 5.0, "rider rolls forward off screen, not backward")
	assert_true(practice.get_node("Hud/Root/StatsPanel/Box/Again").has_focus())

func test_course_gaps_are_open() -> void:
	var practice := _practice()
	await get_tree().physics_frame
	var space := practice.get_world_3d().direct_space_state
	for gap in practice.course.gaps:
		var mid: Vector3 = (gap[0] + gap[1]) * 0.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3(0, 3, 0), mid + Vector3(0, -3, 0)))
		assert_false(hit.has("collider"), "gap at %s must be open" % mid)
