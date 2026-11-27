extends GutTest
## Skeleton smoke tests: input contract, scene loading, toolchain pin.

const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"flip_back", &"roll_forward", &"jump", &"brake",
	&"zflip_left", &"zflip_right", &"tabletop", &"pause"
]


func test_input_actions_exist_with_keyboard_binding() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		var has_key := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				has_key = true
		assert_true(has_key, "%s needs a keyboard binding" % action)


func test_input_actions_exist_with_gamepad_binding() -> void:
	for action in ACTIONS:
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_pad, "%s needs a gamepad binding" % action)

func test_gameplay_bindings_accept_reconnected_controllers() -> void:
	for device in [0, 1, 3]:
		for action in ACTIONS:
			var checked := false
			for binding in InputMap.action_get_events(action):
				if binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
					var event := binding.duplicate() as InputEvent
					event.device = device
					if event is InputEventJoypadButton:
						event.pressed = true
					assert_true(event.is_action(action), "%s on controller %d" % [action, device])
					checked = true
			assert_true(checked)


func test_scenes_instantiate() -> void:
	for path in ["res://scenes/menu.tscn", "res://scenes/practice.tscn"]:
		var scene: PackedScene = load(path)
		assert_not_null(scene, "cannot load %s" % path)
		var node := scene.instantiate()
		assert_not_null(node, "cannot instantiate %s" % path)
		add_child_autofree(node)


func test_main_scene_is_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/menu.tscn")

func test_web_uses_sample_audio_for_single_threaded_export() -> void:
	assert_eq(ProjectSettings.get_setting("audio/general/default_playback_type.web"), 1)
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	assert_false(presets.get_value("preset.4.options", "variant/thread_support"))


func test_toolchain_pin_matches_running_editor() -> void:
	var f := FileAccess.open("res://docs/toolchain.json", FileAccess.READ)
	assert_not_null(f, "docs/toolchain.json missing")
	var pin: String = JSON.parse_string(f.get_as_text())["godot_version"]
	var info := Engine.get_version_info()
	var running := "%d.%d.%d-%s" % [info.major, info.minor, info.patch, info.status]
	assert_eq(running, pin, "running editor differs from docs/toolchain.json pin")


func test_app_identifier_prefix_in_presets() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_eq(text.count("com.infinityball.uniloop"), 3)


func test_generated_icon_is_wired_into_all_export_targets() -> void:
	var icon: Texture2D = load("res://AppStore/icon.png")
	assert_not_null(icon)
	assert_eq(icon.get_width(), 1024)
	assert_eq(icon.get_height(), 1024)
	assert_eq(ProjectSettings.get_setting("application/config/icon"), "res://AppStore/icon.png")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("application/modify_resources=true"))
	assert_true(FileAccess.file_exists("res://AppStore/icon.ico"))
	assert_eq(ProjectSettings.get_setting("application/config/windows_native_icon"), "res://AppStore/icon.ico")
	assert_true(presets.contains("application/icon=\"res://AppStore/icon.ico\""))
	for entry in ["launcher_icons/main_192", "icons/iphone_120x120", "icons/ipad_152x152"]:
		assert_true(presets.contains(entry + "=\"res://AppStore/icon.png\""), entry + " must use the generated icon")
