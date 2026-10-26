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
