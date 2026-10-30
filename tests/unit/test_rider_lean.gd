extends GutTest

func _rider() -> WheelRider:
	var rider := WheelRider.new()
	rider.handling = WheelHandling.new()
	add_child_autofree(rider)
	rider.set_physics_process(false)
	return rider

func _frame(rider: WheelRider) -> Node3D:
	return rider.get_node("Pose/RiderPrimitive")

func _lean_displacement(rider: WheelRider) -> Vector3:
	var pose: Node3D = rider.get_node("Pose")
	return _frame(rider).global_basis.y - pose.global_basis.y

func test_ground_lean_follows_travel_after_half_twists_and_course_turns() -> void:
	for heading in [0.0, PI]:
		for turn in [0.0, PI, TAU]:
			for direction in [-1.0, 1.0]:
				var rider := _rider()
				rider.grounded = true
				rider.yaw = heading
				rider.twist = turn
				rider.speed = rider.handling.max_speed * direction
				rider._update_pose(3.0)
				var travel: Vector3 = rider.basis.x * direction
				assert_gt(_lean_displacement(rider).dot(travel), 0.1,
					"lean follows travel at yaw %s, twist %s, direction %s" % [heading, turn, direction])

func test_air_lean_follows_velocity_through_flips_twists_and_zflips() -> void:
	for flip in [0.0, PI, TAU]:
		for turn in [0.0, PI]:
			for roll in [0.0, PI]:
				for direction in [-1.0, 1.0]:
					var rider := _rider()
					rider.pitch = flip
					rider.twist = turn
					rider.zflip = roll
					rider.speed = rider.handling.max_speed
					rider.velocity = Vector3.RIGHT * rider.handling.max_speed * direction
					rider._update_pose(3.0)
					assert_gt(_lean_displacement(rider).dot(Vector3.RIGHT * direction), 0.05,
						"air lean follows velocity at pitch %s, twist %s, zflip %s, direction %s" % [flip, turn, roll, direction])
					assert_almost_eq(rider.pitch, flip, 0.0001, "cosmetic lean preserves flip")
					assert_almost_eq(rider.twist, turn, 0.0001, "cosmetic lean preserves twist")
					assert_almost_eq(rider.zflip, roll, 0.0001, "cosmetic lean preserves zflip")

func test_falling_without_horizontal_motion_does_not_create_forward_lean() -> void:
	var rider := _rider()
	rider.speed = rider.handling.max_speed
	rider.velocity = Vector3.DOWN * rider.handling.max_speed
	rider._update_pose(3.0)
	assert_almost_eq(_frame(rider).rotation.z, 0.0, 0.0001)

func test_lean_is_subtle_capped_and_eases_in() -> void:
	var rider := _rider()
	rider.grounded = true
	rider.speed = rider.handling.max_speed * 3.0
	rider._update_pose(1.0 / 60.0)
	assert_between(absf(_frame(rider).rotation.z), 0.001, deg_to_rad(1.1), "no instant lean on acceleration")
	rider._update_pose(0.3)
	assert_between(absf(_frame(rider).rotation.z), deg_to_rad(10.0), deg_to_rad(15.0), "lean eases in over several tenths of a second")
	rider._update_pose(3.0)
	assert_between(absf(_frame(rider).rotation.z), deg_to_rad(19.0), deg_to_rad(20.0) + 0.0001, "boosts cannot exceed 20 degrees")

func test_reversing_and_takeoff_transition_smoothly() -> void:
	var rider := _rider()
	rider.grounded = true
	rider.speed = rider.handling.max_speed
	rider._update_pose(3.0)
	var before := _frame(rider).rotation.z
	rider.speed = -rider.handling.max_speed
	rider._update_pose(1.0 / 60.0)
	assert_lt(_frame(rider).rotation.z, 0.0, "reverse crosses neutral instead of snapping")
	assert_lt(absf(_frame(rider).rotation.z - before), deg_to_rad(2.0))
	rider._update_pose(3.0)
	assert_gt(_frame(rider).rotation.z, deg_to_rad(19.0), "reverse eventually leans with travel")
	before = _frame(rider).rotation.z
	rider.grounded = false
	rider.velocity = Vector3.LEFT * rider.handling.max_speed
	rider._update_pose(1.0 / 60.0)
	assert_lt(absf(_frame(rider).rotation.z - before), deg_to_rad(1.0), "takeoff does not snap to airborne lean")
	rider._update_pose(3.0)
	assert_between(_frame(rider).rotation.z, deg_to_rad(5.9), deg_to_rad(6.1), "airborne lean remains subtle")

func test_lean_smoothing_is_frame_rate_independent() -> void:
	var slow := _rider()
	var fast := _rider()
	for rider in [slow, fast]:
		rider.grounded = true
		rider.speed = rider.handling.max_speed
	for tick in 15:
		slow._update_pose(1.0 / 30.0)
	for tick in 60:
		fast._update_pose(1.0 / 120.0)
	assert_almost_eq(_frame(slow).rotation.z, _frame(fast).rotation.z, 0.0001)

func test_reset_clears_lean_even_with_zero_delta() -> void:
	var rider := _rider()
	rider.grounded = true
	rider.speed = rider.handling.max_speed
	rider._update_pose(3.0)
	rider.reset_at(Vector3.ZERO, Vector3.RIGHT)
	assert_almost_eq(_frame(rider).rotation.z, 0.0, 0.0001)
