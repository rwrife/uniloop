extends GutTest

func _practice() -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = "user://test_resume_jump.json"
	practice.countdown_enabled = false
	add_child_autofree(practice)
	practice.set_physics_process(false)
	practice.rider.set_physics_process(false)
	return practice

func _confirm(controller: bool, pressed: bool) -> void:
	if controller:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		_key(KEY_SPACE, pressed)
	Input.flush_buffered_events()

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func after_each() -> void:
	get_tree().paused = false
	_confirm(true, false)
	for code in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
		_key(code, false)
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)
	await wait_seconds(0.15)

func _check_held_resume(controller: bool) -> void:
	var practice := _practice()
	practice._set_paused(true)
	_confirm(controller, true)
	assert_false(get_tree().paused, "confirmation still resumes immediately")
	assert_false(practice.pause_panel.visible)
	practice.rider._physics_process(1.0 / 60.0)
	assert_true(practice.rider.grounded, "Resume confirmation cannot jump")
	assert_false(practice.rider.pump_queued, "Resume cannot queue an air pump")
	practice.rider._physics_process(1.0 / 60.0)
	assert_true(practice.rider.grounded, "holding Resume cannot trigger a delayed jump")
	_confirm(controller, false)
	_confirm(controller, true)
	practice.rider._physics_process(1.0 / 60.0)
	assert_false(practice.rider.grounded, "a fresh press after release still jumps")

func test_space_resume_does_not_jump_but_next_press_does() -> void:
	_check_held_resume(false)

func test_controller_A_resume_does_not_jump_but_next_press_does() -> void:
	_check_held_resume(true)

func test_quick_tap_resume_is_consumed_even_if_released_before_physics() -> void:
	for controller in [false, true]:
		var practice := _practice()
		practice._set_paused(true)
		_confirm(controller, true)
		_confirm(controller, false)
		practice.rider._physics_process(1.0 / 60.0)
		assert_true(practice.rider.grounded, "a quick Resume tap cannot leak a just-pressed jump")
		await get_tree().process_frame
		_confirm(controller, true)
		practice.rider._physics_process(1.0 / 60.0)
		assert_false(practice.rider.grounded, "next intentional press jumps")
		_confirm(controller, false)
		practice.queue_free()
		await get_tree().process_frame

func test_airborne_resume_does_not_queue_a_pump() -> void:
	for controller in [false, true]:
		var practice := _practice()
		practice.rider.reset_at(Vector3(0, 100, 0), Vector3.RIGHT)
		practice.rider.course = null
		practice._set_paused(true)
		_confirm(controller, true)
		practice.rider._physics_process(1.0 / 60.0)
		assert_false(practice.rider.pump_queued, "Resume does not count as an air-pump request")
		_confirm(controller, false)
		practice.rider._physics_process(1.0 / 60.0)
		_confirm(controller, true)
		practice.rider._physics_process(1.0 / 60.0)
		assert_true(practice.rider.pump_queued, "a fresh airborne jump press still queues a pump")
		_confirm(controller, false)
		practice.queue_free()
		await get_tree().process_frame

func test_enter_or_escape_resume_does_not_block_an_independent_jump() -> void:
	for code in [KEY_ENTER, KEY_ESCAPE]:
		var practice := _practice()
		practice._set_paused(true)
		_key(code, true)
		_key(code, false)
		assert_false(get_tree().paused)
		_confirm(false, true)
		practice.rider._physics_process(1.0 / 60.0)
		assert_false(practice.rider.grounded, "non-jump Resume input leaves a fresh Space press available")
		_confirm(false, false)
		practice.queue_free()
		await get_tree().process_frame
