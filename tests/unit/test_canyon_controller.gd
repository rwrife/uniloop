extends GutTest
## GUT suite for vehicle controller handling, canyon course geometry, and gates.

const HANDLING := preload("res://scripts/handling.gd")
const CANYON := preload("res://scripts/canyon.gd")
const RIDER := preload("res://scripts/wheel_rider.gd")

func test_handling_resource_has_valid_ranges() -> void:
	var h: WheelHandling = HANDLING.new()
	assert_gt(h.acceleration, 0.0)
	assert_gt(h.max_speed, h.reverse_speed)
	assert_gt(h.grip, 0.0)
	assert_gt(h.bank_grip_bonus, 0.0)
	assert_gt(h.jump_speed, 0.0)
	assert_gt(h.pump_boost, 0.0)
	assert_gt(h.wheel_radius, 0.0)
	assert_lt(h.fall_height, 0.0)
	assert_gt(h.camera_distance, 0.0)
	assert_gt(h.camera_height, 0.0)

func test_canyon_course_construction() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	assert_gt(course.POINTS.size(), 5)
	assert_eq(course.gate_areas.size(), course.GATES.size())
	assert_not_null(course.finish_area)
	assert_not_null(course.get_node_or_null("RibbonCollision"))
	var spawn := course.spawn_at(0, 3.0)
	assert_gt(spawn.y, course.POINTS[0].y)
	var head := course.heading(0)
	assert_almost_eq(head.length(), 1.0, 0.01)

func test_canyon_medals_valid() -> void:
	var course: CanyonCourse = CANYON.new()
	add_child_autofree(course)
	assert_true(RaceRules.valid_thresholds(course.MEDALS))
	assert_eq(RaceRules.medal(course.MEDALS.gold - 100, course.MEDALS), "gold")
	assert_eq(RaceRules.medal(course.MEDALS.gold + 100, course.MEDALS), "silver")

func test_rider_instantiation_and_nodes() -> void:
	var rider: WheelRider = RIDER.new()
	rider.handling = HANDLING.new()
	add_child_autofree(rider)
	assert_not_null(rider.get_node_or_null("WheelPrimitive"))
	assert_not_null(rider.get_node_or_null("RiderPrimitive"))
	assert_eq(rider.speed, 0.0)

func test_rider_reset_behavior() -> void:
	var rider: WheelRider = RIDER.new()
	rider.handling = HANDLING.new()
	add_child_autofree(rider)
	rider.speed = 20.0
	rider.velocity = Vector3(10, 5, -10)
	var target_pos := Vector3(0, 2, -10)
	var target_head := Vector3(0, 0, -1)
	rider.reset_at(target_pos, target_head)
	assert_eq(rider.speed, 0.0)
	assert_eq(rider.velocity, Vector3.ZERO)
	assert_eq(rider.global_position, target_pos)

func test_practice_scene_loads_and_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/practice.tscn")
	assert_not_null(scene)
	var node: Node = scene.instantiate()
	assert_not_null(node)
	add_child_autofree(node)
	assert_not_null(node.get_node_or_null("Hud/Status"))

func test_rider_moves_over_real_collision_and_crosses_first_gate() -> void:
	var scene: PackedScene = load("res://scenes/practice.tscn")
	var practice: Node3D = scene.instantiate()
	add_child_autofree(practice)
	var wheel: WheelRider = practice.rider
	await get_tree().physics_frame
	Input.action_press(&"accelerate")
	for tick in 240:
		await get_tree().physics_frame
		if practice.rules.next_checkpoint > 0:
			break
	Input.action_release(&"accelerate")
	var first_checkpoint_position: Vector3 = practice.course.POINTS[practice.course.GATES[0]]
	assert_eq(practice.rules.next_checkpoint, 1, "wheel should ride ribbon into checkpoint zero")
	assert_eq(practice.rules.resets, 0, "no fall while riding straight")
	assert_lt(wheel.global_position.distance_to(first_checkpoint_position), 8.0)

func test_track_collision_shape_is_registered() -> void:
	var scene: PackedScene = load("res://scenes/practice.tscn")
	var practice: Node3D = scene.instantiate()
	add_child_autofree(practice)
	await get_tree().physics_frame
	var hit: Dictionary = practice.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(0, 5, 2), Vector3(0, -5, 2)))
	assert_true(hit.has("collider"), "ribbon collision must be queryable")
	assert_gt((hit["normal"] as Vector3).y, 0.9)

func test_finish_requires_every_gate_and_records_medal() -> void:
	var scene: PackedScene = load("res://scenes/practice.tscn")
	var practice: Node3D = scene.instantiate()
	add_child_autofree(practice)
	var wheel: WheelRider = practice.rider
	practice.save_path = "user://canyon_test_record.json"
	wheel.speed = 10.0
	practice._on_finish(wheel)
	assert_false(practice.rules.finished)
	for i in practice.course.GATES.size():
		practice._on_checkpoint(wheel, i)
	practice._on_finish(wheel)
	assert_true(practice.rules.finished)
	assert_eq(practice.save.records["canyon_ribbon"].medal, "gold")
	assert_eq(practice.rules.next_checkpoint, practice.course.GATES.size())
