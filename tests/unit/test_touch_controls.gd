extends GutTest

func _practice() -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	if practice._touch_buttons.is_empty():
		practice._build_touch_overlay()
	practice._apply_safe_area()
	return practice

func _touch(practice: Node3D, finger: int, action: StringName, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = practice._touch_buttons[action].get_global_rect().get_center()
	event.pressed = pressed
	event.canceled = canceled
	practice._handle_touch(event)

func test_simultaneous_movement_and_jump() -> void:
	var practice := _practice()
	_touch(practice, 0, &"move_right", true)
	_touch(practice, 1, &"jump", true)
	assert_true(Input.is_action_pressed(&"move_right"))
	assert_true(Input.is_action_pressed(&"jump"))
	_touch(practice, 1, &"jump", false)
	assert_false(Input.is_action_pressed(&"jump"))
	assert_true(Input.is_action_pressed(&"move_right"))
	practice._release_touches()
	assert_false(Input.is_action_pressed(&"move_right"))

func test_canceled_touch_and_background_release_inputs() -> void:
	var practice := _practice()
	_touch(practice, 0, &"brake", true)
	_touch(practice, 0, &"brake", true, true)
	assert_false(Input.is_action_pressed(&"brake"))
	_touch(practice, 1, &"move_right", true)
	practice._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_false(Input.is_action_pressed(&"move_right"))
	assert_true(get_tree().paused)
	practice._set_paused(false)

func test_pause_releases_and_hides_controls() -> void:
	var practice := _practice()
	var overlay: Control = practice.get_node("Hud/Root/TouchOverlay")
	_touch(practice, 0, &"move_right", true)
	practice._set_paused(true)
	assert_false(Input.is_action_pressed(&"move_right"))
	assert_false(overlay.visible)
	assert_false(practice.rider.can_process())
	practice._set_paused(false)
	assert_true(overlay.visible)

func test_first_touch_creates_controls_when_touchscreen_was_not_detected() -> void:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	if not practice._touch_buttons.is_empty():
		practice.get_node("Hud/Root/TouchOverlay").free()
		practice._touch_buttons.clear()
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = Vector2(500, 300)
	practice._input(event)
	assert_eq(practice._touch_buttons.size(), practice.ACTIONS.size())
	assert_true(practice.get_node("Hud/Root/TouchOverlay").visible)
	_touch(practice, 1, &"move_right", true)
	_touch(practice, 2, &"jump", true)
	assert_true(Input.is_action_pressed(&"move_right"))
	assert_true(Input.is_action_pressed(&"jump"))
	practice._release_touches()

func test_first_touch_respects_disabled_overlay() -> void:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	if not practice._touch_buttons.is_empty():
		practice.get_node("Hud/Root/TouchOverlay").free()
		practice._touch_buttons.clear()
	SaveStore.set_settings(practice.save, {"touch_overlay": false})
	var event := InputEventScreenTouch.new()
	event.pressed = true
	practice._input(event)
	assert_true(practice._touch_buttons.is_empty())
	assert_null(practice.get_node_or_null("Hud/Root/TouchOverlay"))

func test_portrait_camera_keeps_rider_visible_at_full_forward_lead() -> void:
	var window := get_tree().root
	var original_size := window.size
	window.size = Vector2i(390, 844)
	await wait_process_frames(3)
	var practice := _practice()
	practice.rider.set_physics_process(false)
	practice._rider_vx = practice.rider.handling.max_speed
	practice._snap_camera()
	var camera: Camera3D = practice.get_node("Camera")
	var screen_point := camera.unproject_position(practice.rider.global_position)
	var width := practice.get_viewport().get_visible_rect().size.x
	assert_gt(screen_point.x, width * 0.15, "rider stays clear of the left edge in portrait")
	assert_lt(screen_point.x, width * 0.85)
	window.size = Vector2i(1280, 720)
	await wait_process_frames(3)
	assert_eq(camera.keep_aspect, Camera3D.KEEP_HEIGHT)
	assert_almost_eq(camera.fov, 45.0, 0.01, "landscape retains its original field of view")
	window.size = original_size
