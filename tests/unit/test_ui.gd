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
	assert_eq(UI.prompt(&"jump", "playstation"), "□")
	assert_eq(UI.prompt(&"jump", "touch"), "JUMP")
	assert_eq(UI.prompt(&"pause", "nintendo"), "+")
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
	var play: Button = menu.get_node("SafeMargin/MainCard/Actions/Play")
	assert_true(play.has_focus())
	assert_true(play.focus_neighbor_bottom != NodePath())
	menu._open_settings()
	assert_true(menu.get_node("SafeMargin/SubPanel").visible)
	assert_true(menu.get_node("SafeMargin/SubPanel/Content/Back").has_focus())
	menu._close_subpanel()
	assert_true(play.visible)
	var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
	add_child_autofree(practice)
	practice._set_paused(true)
	assert_true(get_tree().paused)
	assert_true(practice.pause_panel.visible)
	practice._open_pause_settings()
	assert_false(practice.pause_panel.visible)
	assert_true(practice.settings_panel.visible)
	practice._open_pause_from_settings()
	assert_true(practice.pause_panel.visible)
	assert_false(practice.settings_panel.visible)
	practice._set_paused(false)
	assert_false(get_tree().paused)
	assert_false(practice.pause_panel.visible)
