extends GutTest

const SAVE_PATH := "user://test_menu_controller_audio.json"
const TICK := preload("res://assets/audio/sfx/ui_tick.wav")
const BEEP := preload("res://assets/audio/sfx/ui_confirm.wav")

func _menu() -> Control:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.save_path = SAVE_PATH
	menu.auto_launch = false
	add_child_autofree(menu)
	return menu

func _practice() -> Node3D:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = SAVE_PATH
	practice.countdown_enabled = false
	add_child_autofree(practice)
	return practice

func _pad(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(button: JoyButton) -> void:
	_pad(button)
	_pad(button, false)

func _cues(stream: AudioStream) -> Array[AudioStreamPlayer]:
	var found: Array[AudioStreamPlayer] = []
	for child in get_viewport().get_children():
		if child is AudioStreamPlayer and child.stream == stream:
			found.append(child)
	return found

func after_each() -> void:
	get_tree().paused = false
	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
		_pad(button, false)
	for action in UniloopUI.ACTIONS:
		Input.action_release(action)
	await wait_seconds(0.2)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func test_title_navigation_and_controller_confirm_have_distinct_cues() -> void:
	var menu := _menu()
	await wait_process_frames(2)
	_tap(JOY_BUTTON_DPAD_DOWN)
	assert_true(menu.buttons.league.has_focus(), "D-pad skips disabled Multiplayer")
	assert_gt(_cues(TICK).size(), 0, "selection focus plays tick")
	_tap(JOY_BUTTON_DPAD_DOWN)
	assert_true(menu.buttons.options.has_focus())
	_tap(JOY_BUTTON_A)
	assert_eq(menu.screen, "options", "A opens focused Options")
	assert_gt(_cues(BEEP).size(), 0, "A activation plays beep")
	for player in _cues(TICK) + _cues(BEEP):
		assert_eq(player.bus, &"SFX", "UI cues respect effects and master sliders")
		assert_lt(player.volume_db, -6.0, "UI cues stay subtle")
	_tap(JOY_BUTTON_B)
	assert_eq(menu.screen, "title", "B returns to title")

func test_controller_can_toggle_options_and_adjust_separate_volume_sliders() -> void:
	var menu := _menu()
	menu._open("options")
	await wait_process_frames(2)
	_tap(JOY_BUTTON_DPAD_DOWN)
	var check: CheckButton = get_viewport().gui_get_focus_owner()
	assert_not_null(check)
	assert_eq(check.text, "High Contrast Mode")
	_tap(JOY_BUTTON_A)
	assert_true(check.button_pressed, "A toggles a CheckButton, not just its pressed signal")
	assert_true(SaveStore.load_from_path(SAVE_PATH).save.settings.high_contrast)
	_tap(JOY_BUTTON_A)
	assert_false(check.button_pressed)
	var music: HSlider = menu.panel_body.get_node("audio_music")
	var effects: HSlider = menu.panel_body.get_node("audio_sfx")
	music.grab_focus()
	var before := music.value
	_tap(JOY_BUTTON_DPAD_RIGHT)
	assert_gt(music.value, before, "D-pad adjusts focused music slider")
	effects.grab_focus()
	effects.value = 25
	var loaded := SaveStore.load_from_path(SAVE_PATH)
	assert_eq(loaded.save.settings.audio_sfx, 25)
	assert_eq(loaded.save.settings.audio_music, int(music.value))
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), 0.25, 0.001)
	assert_gt(_cues(TICK).size(), 0, "sliders participate in focus feedback")

func test_pause_navigation_and_A_resume_work_while_tree_is_paused() -> void:
	var practice := _practice()
	practice._set_paused(true)
	await wait_process_frames(2)
	var resume: Button = practice.get_node("Hud/Root/PausePanel/Box/Resume")
	var restart: Button = practice.get_node("Hud/Root/PausePanel/Box/Restart")
	assert_true(resume.has_focus())
	_tap(JOY_BUTTON_DPAD_DOWN)
	assert_true(restart.has_focus(), "controller moves within paused menu")
	_tap(JOY_BUTTON_DPAD_UP)
	assert_true(resume.has_focus())
	_tap(JOY_BUTTON_A)
	assert_false(practice.pause_panel.visible, "A resumes rather than being ignored")
	assert_false(get_tree().paused)
	assert_null(get_viewport().gui_get_focus_owner(), "resume leaves focus off Pause")
	assert_gt(_cues(BEEP).size(), 0, "paused menu confirm remains audible")
	_tap(JOY_BUTTON_A)
	assert_false(practice.pause_panel.visible, "A during gameplay does not reopen pause")
	practice._set_paused(true)
	_tap(JOY_BUTTON_B)
	assert_false(practice.pause_panel.visible, "B also backs out of Pause")

func test_left_stick_navigates_title_menu() -> void:
	var menu := _menu()
	await wait_process_frames(2)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	assert_true(menu.buttons.league.has_focus(), "left stick navigates alongside D-pad")
	stick = stick.duplicate()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	Input.flush_buffered_events()

func test_keyboard_and_mouse_still_select_and_play_feedback() -> void:
	var menu := _menu()
	await wait_process_frames(2)
	menu.buttons.options.grab_focus()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ENTER
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	assert_eq(menu.screen, "options", "Enter retains confirm behavior")
	await wait_seconds(0.3)
	var help: Button = menu.panel_body.get_node("HowToPlay")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = help.get_global_rect().get_center()
	click.pressed = true
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	click.button_mask = 0
	get_viewport().push_input(click, true)
	assert_eq(menu.screen, "help", "mouse retains selection behavior")
	assert_gt(_cues(BEEP).size(), 0, "pointer selection also beeps")

func test_shared_confirm_handles_results_buttons_once() -> void:
	var practice := _practice()
	practice.stats_panel.visible = true
	var again: Button = practice.stats_panel.get_node("Box/Buttons/Again")
	for connection in again.pressed.get_connections():
		again.pressed.disconnect(connection.callable)
	var activations := [0]
	again.pressed.connect(func() -> void: activations[0] += 1)
	again.grab_focus()
	_tap(JOY_BUTTON_A)
	assert_eq(activations[0], 1, "results use same A-confirm without duplicate native activation")

func test_ui_cues_continue_while_paused_and_free_after_playback() -> void:
	var practice := _practice()
	await wait_seconds(0.2)
	practice._set_paused(true)
	practice.audio.play_ui("ui_confirm")
	assert_gt(_cues(BEEP).size(), 0)
	for player in _cues(BEEP):
		assert_eq(player.process_mode, Node.PROCESS_MODE_ALWAYS)
		assert_true(player.playing)
	await get_tree().create_timer(0.3, true).timeout
	assert_eq(_cues(BEEP).size(), 0, "short scene-independent UI cue cleans itself up")
	practice._set_paused(false)

func test_confirmation_can_remove_scene_without_null_viewport_or_losing_beep() -> void:
	var menu := _menu()
	var leave := Button.new()
	leave.text = "Leave"
	leave.pressed.connect(func() -> void: menu.get_parent().remove_child(menu))
	menu.add_child(leave)
	leave.grab_focus()
	assert_true(UniloopUI.activate_focused_control(get_viewport()))
	assert_false(menu.is_inside_tree(), "activation can immediately remove the scene")
	assert_gt(_cues(BEEP).size(), 0, "selection cue survives scene exit")
	menu.free()

func test_quieter_effect_defaults_preserve_saved_mix_and_music() -> void:
	var defaults := SaveStore.get_settings(SaveStore.default_save())
	assert_eq(defaults.audio_music, 80)
	assert_eq(defaults.audio_sfx, 50)
	var saved := SaveStore.sanitize_settings({"audio_music": 65, "audio_sfx": 80})
	assert_eq(saved.audio_music, 65)
	assert_eq(saved.audio_sfx, 80, "explicit existing choices are not overwritten")
	UniloopUI.apply_audio({})
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), 0.8, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), 0.5, 0.001)
	var menu := _menu()
	assert_almost_eq(menu.audio.get_node("jump").volume_db, -6.0, 0.001, "gameplay effects quieter even for existing settings")
	assert_almost_eq(menu.audio.get_node("Music").volume_db, 0.0, 0.001, "music gain unchanged")

func test_controller_confirm_and_disabled_buttons_do_not_break_keyboard_remapping() -> void:
	var menu := _menu()
	menu._open("options")
	var original := InputMap.action_get_events(&"jump").duplicate()
	var button := menu.panel_body.find_children("*", "Button", true, false).back() as Button
	menu._on_rebind_pressed(&"jump", button)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	menu._input(key)
	assert_eq(menu.remapping_action, &"")
	assert_eq(menu.save.bindings.jump, KEY_SPACE, "Space is captured for remapping before submit")
	InputMap.action_erase_events(&"jump")
	for event in original:
		InputMap.action_add_event(&"jump", event)
	var disabled := Button.new()
	disabled.disabled = true
	menu.add_child(disabled)
	disabled.grab_focus()
	assert_false(UniloopUI.activate_focused_control(get_viewport()))
