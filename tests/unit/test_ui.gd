extends GutTest

const UI = preload("res://scripts/ui.gd")
const Store = preload("res://scripts/save_store.gd")


func test_safe_margins_and_screen_modes() -> void:
	assert_eq(UI.mode(Vector2i(390, 844), true), "phone_portrait")
	assert_eq(UI.mode(Vector2i(844, 390), true), "phone_landscape")
	assert_eq(UI.mode(Vector2i(1024, 768), true), "tablet")
	assert_eq(UI.mode(Vector2i(1920, 1080), false), "desktop")
	assert_eq(UI.safe_margins(Rect2i(0, 0, 390, 844), Rect2i(0, 47, 390, 763)), Vector4i(16, 63, 16, 50))
	assert_eq(UI.safe_margins(Rect2i(0, 0, 1920, 1080), Rect2i()), Vector4i(16, 16, 16, 16))


func test_palette_contrast_and_text_size() -> void:
	var normal := UI.create_theme(Store.DEFAULT_SETTINGS)
	var contrast := UI.create_theme({"high_contrast": true, "text_scale": 1.5})
	assert_eq(normal.get_color("font_color", "Label"), UI.WHITE)
	assert_eq(contrast.get_stylebox("normal", "Button").bg_color, Color.BLACK)
	assert_eq(contrast.get_stylebox("focus", "Button").border_color, UI.YELLOW)
	assert_true(contrast.get_font_size("font_size", "Button") > normal.get_font_size("font_size", "Button"))
	assert_eq(UI.button("Play").focus_mode, Control.FOCUS_ALL)


func test_settings_migrate_validate_and_persist() -> void:
	var old := '{"version":2,"records":{"canyon_ribbon":{"best_ms":70000,"medal":"gold"}},"total_score":150}'
	var result: Dictionary = Store.from_json(old)
	assert_true(result.ok)
	assert_eq(result.save.version, 3)
	assert_eq(result.save.records.canyon_ribbon.best_ms, 70000)
	assert_eq(result.save.settings.text_scale, 1.0)
	var save: Dictionary = result.save
	Store.set_settings(save, {"text_scale": 1.5, "high_contrast": true, "audio_master": 27})
	var path := "user://test_ui_settings.json"
	assert_true(Store.save_to_path(save, path))
	var loaded: Dictionary = Store.load_from_path(path)
	assert_true(loaded.ok)
	assert_eq(loaded.save.settings.text_scale, 1.5)
	assert_true(loaded.save.settings.high_contrast)
	assert_eq(loaded.save.settings.audio_master, 27)
	assert_eq(loaded.save.records.canyon_ribbon.best_ms, 70000)
	DirAccess.remove_absolute(path)
	var bad: Dictionary = Store.from_json('{"version":3,"records":{},"total_score":0,"settings":{"text_scale":900,"high_contrast":"true","audio_master":200}}')
	assert_true(bad.ok)
	assert_eq(bad.save.settings.text_scale, 1.0)
	assert_false(bad.save.settings.high_contrast)
	assert_eq(bad.save.settings.audio_master, 80)


func test_device_prompts() -> void:
	assert_eq(UI.prompt(&"jump", "keyboard"), "Space")
	assert_eq(UI.prompt(&"jump", "playstation"), "✕")
	assert_eq(UI.prompt(&"tabletop", "nintendo"), "X")
	assert_eq(UI.prompt(&"zflip_left", "xbox"), "LB")
	assert_eq(UI.prompt(&"jump", "touch"), "JUMP")
	assert_eq(UI.prompt(&"pause", "nintendo"), "+")
	assert_eq(UI.prompt_for_hint(&"jump", "xbox"), "🅰")
	assert_eq(UI.gamepad_type_from_name("Xbox Wireless Controller"), "xbox")
	assert_eq(UI.gamepad_type_from_name("DualSense Wireless Controller"), "playstation")
	assert_eq(UI.gamepad_type_from_name("Nintendo Switch Pro Controller"), "nintendo")
	assert_true(UI.controls_hint_text("keyboard").contains("Space"))
	assert_eq(UI.device_for(InputEventKey.new()), "keyboard")
	assert_eq(UI.device_for(InputEventScreenTouch.new()), "touch")


func test_rebind_keeps_gamepad_and_persists() -> void:
	var save := Store.default_save()
	var original := InputMap.action_get_events(&"jump").duplicate()
	var key := InputEventKey.new()
	key.physical_keycode = Key.KEY_J
	UI.remap(save, &"jump", key)
	assert_eq(save.bindings.jump, Key.KEY_J)
	var has_key := false
	var has_pad := false
	for ev in InputMap.action_get_events(&"jump"):
		if ev is InputEventKey and ev.physical_keycode == Key.KEY_J:
			has_key = true
		if ev is InputEventJoypadButton:
			has_pad = true
	assert_true(has_key)
	assert_true(has_pad)
	InputMap.action_erase_events(&"jump")
	for ev in original:
		InputMap.action_add_event(&"jump", ev)


func test_menu_controls_and_pause_flow() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	var play: Button = menu.buttons.quick_race
	assert_true(play.has_focus())
	assert_true(play.focus_neighbor_bottom != NodePath())
	assert_true(menu.buttons.multiplayer.disabled, "multiplayer is coming soon")
	assert_eq(menu.background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	menu._open("options")
	assert_true(menu.panel.visible)
	assert_false(menu.title_menu.visible)
	menu._go_back()
	assert_true(play.visible)
	assert_false(menu.panel.visible)
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	practice._set_paused(true)
	assert_true(get_tree().paused)
	assert_true(practice.pause_panel.visible)
	assert_null(practice.get_node_or_null("Hud/Root/SettingsPanel"), "no settings in the pause menu")
	var labels: Array[String] = []
	for b in practice.pause_panel.get_node("Box").get_children():
		if b is Button:
			labels.append(b.text)
			assert_eq(b.get_theme_font("font"), UniloopUI.CHUNKY_FONT, "pause buttons match the menu")
	assert_eq(labels, ["RESUME", "RESTART RACE", "QUIT RACE"] as Array[String])
	assert_true(practice.get_node("Hud/Root/PausePanel/Box/Resume").has_focus())
	practice._set_paused(false)
	assert_false(get_tree().paused)
	assert_false(practice.pause_panel.visible)

func test_menu_gamepad_confirm_activates_focused_button() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.auto_launch = false
	add_child_autofree(menu)
	assert_eq(menu.screen, "title")
	assert_true(menu.buttons.quick_race.has_focus())
	var confirm := InputEventAction.new()
	confirm.action = &"jump"
	confirm.pressed = true
	menu._input(confirm)
	assert_eq(menu.screen, "uni")

func test_practice_control_hints_follow_active_device() -> void:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.countdown_enabled = false
	add_child_autofree(practice)
	var hints: PanelContainer = practice.get_node("Hud/Root/ControlHints")
	var label: Label = hints.get_node("Text")
	assert_true(label.text.contains("Space"))
	practice._set_current_device("xbox")
	assert_true(label.text.contains(UI.prompt_for_hint(&"jump", "xbox")))
	practice._set_current_device("touch")
	assert_false(hints.visible)


func test_quick_race_flow_picks_uni_then_track() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.auto_launch = false
	add_child_autofree(menu)
	menu.buttons.quick_race.pressed.emit()
	assert_eq(menu.screen, "uni")
	assert_eq(menu.cards.size(), RaceSetup.UNIS.size())
	assert_between(RaceSetup.UNIS.size(), 5, 8, "about six unicycle colours")
	menu.cards[3].pressed.emit()
	assert_eq(RaceSetup.uni_index, 3)
	assert_eq(menu.screen, "track")
	assert_eq(menu.cards.size(), RaceSetup.TRACKS.size())
	menu.cards[2].pressed.emit()
	assert_eq(RaceSetup.track_id, RaceSetup.TRACKS[2].id)
	menu._go_back()
	assert_eq(menu.screen, "uni")
	menu._go_back()
	assert_eq(menu.screen, "title")
	RaceSetup.uni_index = 0
	RaceSetup.track_id = RaceSetup.DEFAULT_TRACK


func test_uni_picker_fits_portrait_without_scroll() -> void:
	var window := get_tree().root
	var original_size := window.size
	window.size = Vector2i(390, 844)
	await wait_process_frames(3)
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	menu._open("uni")
	await wait_process_frames(3)
	var grid: GridContainer = menu.panel_body.get_child(0)
	var scroll: ScrollContainer = menu.panel_body.get_parent()
	assert_eq(grid.columns, 2)
	assert_eq(menu.cards.size(), RaceSetup.UNIS.size())
	assert_false(scroll.get_v_scroll_bar().visible, "all six unis fit without scrolling")
	assert_false(scroll.get_h_scroll_bar().visible)
	window.size = original_size

func test_league_lists_every_track() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child_autofree(menu)
	menu._open("league")
	var text := ""
	for node in menu.panel.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	for t in RaceSetup.TRACKS:
		assert_true(String(t.title).to_upper() in text, t.id)


func test_countdown_freezes_rider_until_race() -> void:
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	practice.save_path = "user://countdown_test.json"
	add_child_autofree(practice)
	assert_false(practice.racing)
	assert_eq(practice.rider.process_mode, Node.PROCESS_MODE_DISABLED)
	await wait_seconds(1.0)
	assert_eq(practice.rules.elapsed_ms, 0, "clock waits for the countdown")
	await wait_seconds(3.0)
	assert_true(practice.racing)
	assert_eq(practice.countdown_label.text, "RACE!")
	assert_eq(practice.rider.process_mode, Node.PROCESS_MODE_PAUSABLE)