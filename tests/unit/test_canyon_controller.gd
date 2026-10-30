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
	practice.countdown_enabled = false
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
	assert_gte(course.forks.size(), 4, "forking routes")
	assert_gte(course.goo_pits, 4, "goo pits")
	assert_gt(course.gaps.size(), 0)
	assert_gt(course.boosts.size(), 0)
	var leftward := 0
	for gate in course.gates:
		if gate.t.x < 0.0:
			leftward += 1
	assert_gt(leftward, 0, "course doubles back to the left")
	assert_gt(course.finish.pos.y, course.start_spot.pos.y + 50.0, "course climbs")
	for node in ["Rail", "Chevrons", "Goo", "GooDrips", "GooDroplets", "RibbonCollision", "Backdrop", "Finish"]:
		assert_not_null(course.get_node_or_null(node), node)
	var kinds := {}
	for sec in course.sections:
		for kind in sec.kinds:
			kinds[kind] = true
	for kind in [CanyonCourse.NORMAL, CanyonCourse.TURN, CanyonCourse.HAZARD, CanyonCourse.GOO]:
		assert_true(kinds.has(kind), "track kind %d is used" % kind)
	assert_false(kinds.has(CanyonCourse.SHORTCUT), "fork routes are not colour-coded")
	for child in course.get_children():
		if child is Label3D:
			assert_false("SHORTCUT" in child.text, "forks are not signposted")

func test_forks_offer_two_long_distinct_routes() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	var signatures := {}
	for fork in course.forks:
		assert_eq(fork.routes.size(), 2)
		assert_gte(absf(fork.merge.x - fork.split.x), 200.0, "routes are long")
		var split_sec: CanyonCourse.Section = course.sections[fork.junction]
		assert_gte(split_sec.fork, 0, "rail splits at a junction")
		var rest: int = course.sections[fork.routes[0]].next
		assert_eq(course.sections[fork.routes[1]].next, rest, "routes rejoin")
		var side_by_side := 0
		for x_off in [30.0, 60.0, 90.0, 120.0, 150.0, 180.0]:
			var x: float = fork.split.x + signf(fork.merge.x - fork.split.x) * x_off
			var ys: Array = []
			for sec: CanyonCourse.Section in course.sections:
				for k in sec.points.size() - 1:
					var a: Vector3 = sec.points[k]
					var b: Vector3 = sec.points[k + 1]
					if absf(a.z - fork.split.z) < 3.5 and absf(a.y - fork.split.y) < 15.0 and minf(a.x, b.x) <= x and x <= maxf(a.x, b.x):
						ys.append(a.y)
			if ys.size() >= 2:
				side_by_side += 1
		assert_gte(side_by_side, 4, "both routes run side by side (allowing for jump gaps)")
		for route in fork.routes:
			var sec: CanyonCourse.Section = course.sections[route]
			assert_almost_eq(sec.points[sec.points.size() - 1].distance_to(fork.merge), 0.0, 0.01, "route ends at the merge")
		var shape := ""
		for route in fork.routes:
			shape += "%d," % course.sections[route].points.size()
		signatures[shape] = true
	assert_eq(signatures.size(), course.forks.size(), "every fork is different")

func test_goo_is_forward_only() -> void:
	var practice := _practice()
	var course: CanyonCourse = practice.course
	var wheel: WheelRider = practice.rider
	var spot := {}
	for i in course.sections.size():
		var sec: CanyonCourse.Section = course.sections[i]
		for k in sec.kinds.size():
			if sec.kinds[k] == CanyonCourse.GOO and absf(sec.seg_tangents[k].y) < 0.05:
				spot = {"sec": i, "s": sec.cum[k] + 0.5}
				break
		if not spot.is_empty():
			break
	assert_false(spot.is_empty(), "flat goo exists")
	await get_tree().physics_frame
	wheel.place_on(spot.sec, spot.s)
	wheel.speed = 0.0
	var forward := -1.0 if course.sample(spot.sec, spot.s).drive > 0 else 1.0
	Input.action_press(&"move_left" if forward < 0.0 else &"move_right")
	Input.action_press(&"brake")
	var start: float = wheel.distance
	for tick in 20:
		await get_tree().physics_frame
		Input.action_press(&"jump")
	assert_true(wheel.grounded, "no hopping out of goo")
	assert_gt(wheel.distance, start + 0.5, "goo keeps crawling forward")
	assert_gt(wheel.speed, 0.0)
	assert_lte(wheel.speed, wheel.handling.goo_speed + 0.01)

func test_goo_sprays_only_while_wheel_rolls_through_slime() -> void:
	var practice := _practice()
	var course: CanyonCourse = practice.course
	var wheel: WheelRider = practice.rider
	var spray: CPUParticles3D = wheel.get_node("GooSplatter")
	assert_false(spray.emitting, "no slime at spawn")
	var spot := {}
	for i in course.sections.size():
		var sec: CanyonCourse.Section = course.sections[i]
		for k in sec.kinds.size():
			if sec.kinds[k] == CanyonCourse.GOO and absf(sec.seg_tangents[k].y) < 0.05:
				spot = {"sec": i, "s": sec.cum[k] + 0.5}
				break
		if not spot.is_empty():
			break
	assert_false(spot.is_empty(), "flat goo exists")
	wheel.place_on(spot.sec, spot.s)
	wheel.speed = 2.0
	for tick in 3:
		await get_tree().physics_frame
	assert_true(spray.emitting, "rolling wheel throws slime")
	assert_true(spray.position.distance_to(wheel.to_local(course.sample(wheel.section, wheel.distance).pos)) < 0.01, "spray starts at tire contact")
	wheel.place_on(course.start_spot.sec, course.start_spot.s)
	wheel.speed = 2.0
	for tick in 3:
		await get_tree().physics_frame
	assert_false(spray.emitting, "clean rail does not spray")
	wheel.place_on(spot.sec, spot.s)
	wheel.speed = 2.0
	for tick in 3:
		await get_tree().physics_frame
	assert_true(spray.emitting, "spray resumes in goo")
	wheel.reset_at(Vector3(0, 4, 0), Vector3.RIGHT)
	assert_false(spray.emitting, "reset clears spray immediately")
	await get_tree().physics_frame
	assert_false(spray.emitting, "airborne wheel cannot spray")

func test_released_twist_settles_and_lands() -> void:
	var practice := _practice()
	var report := await _drop_onto_start(practice, func(wheel: WheelRider) -> void:
		wheel.twist_air = deg_to_rad(125.0)
		wheel.twist = deg_to_rad(125.0))
	assert_false(report.is_empty(), "rider landed")
	assert_false(report.crash, "a twist released past halfway settles to 180")
	assert_true("TWIST 180" in report.tricks)

func test_canyon_medals_valid() -> void:
	for t in RaceSetup.TRACKS:
		assert_true(RaceRules.valid_thresholds(t.medals), t.id)
		assert_gte(t.medals.gold, 90000, "%s is a real race" % t.id)
		assert_lte(t.medals.silver, 300000, "%s fits in 5 minutes" % t.id)

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

func test_cartoon_rider_poses_respond_to_speed_tricks_and_landing() -> void:
	var rider: WheelRider = RIDER.new()
	rider.handling = HANDLING.new()
	add_child_autofree(rider)
	var frame: Node3D = rider.get_node("Pose/RiderPrimitive")
	var seat: Node3D = frame.get_node("SeatHead")
	assert_not_null(seat.get_node_or_null("EyeLeft"))
	assert_not_null(seat.get_node_or_null("EyeRight"))
	rider.grounded = true
	rider.speed = rider.handling.max_speed
	rider._update_pose(1.0)
	assert_lt(frame.rotation.z, -deg_to_rad(18.0), "speed leans cartoon body forward")
	assert_gte(frame.rotation.z, -deg_to_rad(20.0) - 0.01, "lean stays bounded")
	assert_gt(seat.rotation.z, 0.1, "head looks forward while rolling")
	rider.speed = -rider.handling.max_speed * 3.0
	rider._update_pose(1.0)
	assert_lte(frame.rotation.z, deg_to_rad(20.0) + 0.01, "reverse lean stays bounded")
	assert_gt(frame.rotation.z, deg_to_rad(17.0), "reverse leans backward")
	rider.grounded = false
	rider.speed = rider.handling.max_speed
	rider.flip_air = TAU
	rider._update_pose(1.0)
	assert_lt(seat.rotation.z, -0.1, "head follows tricks")
	rider.grounded = true
	rider.speed = 0.0
	rider.recover_time = 0.0
	rider._landing_squash = 1.0
	rider._update_pose(0.016)
	assert_lt(frame.scale.y, 0.9, "heavy landing compresses spring")
	rider.reset_at(Vector3.ZERO, Vector3.RIGHT)
	assert_almost_eq(frame.scale.y, 1.0, 0.001, "reset clears spring motion")

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

func test_hud_shows_only_timer_and_points() -> void:
	var practice := _practice()
	var hud: Control = practice.get_node("Hud/Root/Status")
	assert_eq(hud.get_child_count(), 2, "just the timer and points badges")
	assert_not_null(hud.get_node_or_null("TimeBadge"))
	assert_not_null(hud.get_node_or_null("ScoreBadge"))
	for label in practice.get_node("Hud/Root").find_children("*", "Label", true, false):
		assert_false(String(course_title(practice)) in label.text, "no level name on screen")
		assert_false("Hop" in label.text or "Tabletop" in label.text, "no control instructions")
	assert_eq(practice.get_node("Hud/Root/Pause").get_theme_font("font"), UniloopUI.CHUNKY_FONT, "pause matches menu buttons")

func course_title(practice: Node) -> String:
	return String(practice.course.track.title).to_upper()
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
	assert_eq(practice.save.records[practice.course.course_id].medal, "gold")
	assert_false(practice.popup.visible, "no small FINISH popup before stats")
	var start_x := wheel.global_position.x
	await get_tree().create_timer(0.4).timeout
	assert_false(practice.stats_panel.visible, "keep rider on screen for rollout")
	assert_gt(wheel.global_position.x, start_x, "rider continues past finish")
	for tick in 180:
		await get_tree().process_frame
		if practice.stats_panel.visible:
			break
	assert_true(practice.stats_panel.visible, "stats screen appears after the roll-out")
	assert_gte(practice._finish_timer, practice.STATS_DELAY, "hold rollout one full second")
	assert_lte(practice._finish_timer, practice.STATS_DELAY + 0.2, "do not wait for camera exit")
	await get_tree().process_frame # Let the stats entrance coroutine finish its first-frame setup.
	assert_true(practice.get_node("Hud/Root/StatsPanel/Box/Buttons/Again").has_focus())

func test_course_gaps_are_open() -> void:
	var practice := _practice()
	await get_tree().physics_frame
	var space := practice.get_world_3d().direct_space_state
	for gap in practice.course.gaps:
		var mid: Vector3 = (gap[0] + gap[1]) * 0.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mid + Vector3(0, 3, 0), mid + Vector3(0, -3, 0)))
		assert_false(hit.has("collider"), "gap at %s must be open" % mid)


func test_every_track_builds_with_its_rocket_bumps() -> void:
	for t in RaceSetup.TRACKS:
		var course: CanyonCourse = CANYON.new()
		course.track_id = t.id
		add_child_autofree(course)
		assert_eq(course.course_id, t.id)
		assert_eq(course.rocket_bumps, t.bumps.size(), "%s bumps" % t.id)
		assert_gt(course.gates.size(), 3, t.id)
		assert_eq(t.plan.back()[0], "FINAL", t.id)
		assert_eq(t.plan.size() % 2, 1, "%s finishes running right" % t.id)
func test_render_batches_preserve_instances_and_separate_distant_geometry() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	var mesh := BoxMesh.new()
	var items := [
		[Transform3D(Basis.IDENTITY, Vector3.ZERO), Color.RED],
		[Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), Color.GREEN],
		[Transform3D(Basis.IDENTITY, Vector3(100, 0, 0)), Color.BLUE],
	]
	var group := course._add_multimesh("BatchTest", mesh, items, false)
	assert_eq(group.get_child_count(), 2, "Distant geometry must be culled separately")
	var count := 0
	for node: MultiMeshInstance3D in group.get_children():
		var multi := node.multimesh
		count += multi.instance_count
		assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for item in items:
		var enclosed := false
		for node: MultiMeshInstance3D in group.get_children():
			if node.multimesh.custom_aabb.encloses(item[0] * mesh.get_aabb()):
				enclosed = true
		assert_true(enclosed, "Every original instance must lie inside a render batch")
	assert_eq(count, items.size(), "Every instance must be preserved")

func test_respawn_snaps_interpolated_rider_and_camera() -> void:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	assert_eq(practice.get_node("Camera").physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
	var where := Vector3(150, 80, -4)
	practice.rider.reset_at(where, Vector3.RIGHT)
	assert_true(practice.rider.get_global_transform_interpolated().origin.is_equal_approx(where))
	practice._snap_camera()
	assert_true(practice.get_node("Camera").global_position.is_equal_approx(practice._camera_target(false)))
