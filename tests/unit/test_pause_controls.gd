extends GutTest

func _practice() -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = "user://pause_controls_test_record.json"
	practice.countdown_enabled = false
	add_child_autofree(practice)
	return practice

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func after_each() -> void:
	get_tree().paused = false
	for code in [KEY_SPACE, KEY_ESCAPE]:
		_key(code, false)
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)

func test_space_after_focus_loss_resume_jumps_without_reopening_pause() -> void:
	var practice := _practice()
	await get_tree().process_frame
	practice._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused, "losing focus still pauses")
	assert_true(practice.get_node("Hud/Root/PausePanel/Box/Resume").has_focus(), "pause menu supports keyboard navigation")
	practice._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert_false(practice.pause_panel.visible, "Space activates Resume")
	assert_false(get_tree().paused)
	assert_null(get_viewport().gui_get_focus_owner(), "gameplay does not focus a UI button")
	await get_tree().physics_frame
	_key(KEY_SPACE, true)
	assert_true(Input.is_action_pressed(&"jump"), "Space retains its jump binding")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_SPACE, false)
	assert_false(practice.pause_panel.visible, "jump does not activate the Pause button")
	assert_false(get_tree().paused)
	assert_false(practice.rider.grounded, "Space actually makes the rider jump")

func test_escape_can_pause_resume_and_leave_space_for_jumping() -> void:
	var practice := _practice()
	await get_tree().process_frame
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	assert_true(practice.pause_panel.visible)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	assert_false(practice.pause_panel.visible)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	assert_false(practice.pause_panel.visible, "explicit resume also releases menu focus")
	assert_false(get_tree().paused)

func test_resume_releases_pause_button_focus_but_pointer_pause_still_works() -> void:
	var practice := _practice()
	practice.pause_button.grab_focus()
	practice.pause_button.pressed.emit()
	assert_true(practice.pause_panel.visible)
	practice.get_node("Hud/Root/PausePanel/Box/Resume").pressed.emit()
	assert_false(practice.pause_panel.visible)
	assert_null(get_viewport().gui_get_focus_owner())
	practice.pause_button.pressed.emit()
	assert_true(practice.pause_panel.visible, "Pause button remains usable")
	practice._set_paused(false)
