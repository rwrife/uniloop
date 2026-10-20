extends GutTest
## Skeleton contract: project boots to a menu stub and declares every input
## action with keyboard plus gamepad bindings.

const MENU_SCENE := "res://scenes/menu.tscn"
const PRACTICE_SCENE := "res://scenes/practice.tscn"
const ACTIONS := ["accelerate", "brake", "lean_left", "lean_right", "jump", "pause"]


func test_main_scene_is_the_menu() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MENU_SCENE)


func test_stub_scenes_load() -> void:
	for path in [MENU_SCENE, PRACTICE_SCENE]:
		var scene: PackedScene = load(path)
		assert_not_null(scene, "scene missing: " + path)
		if scene != null:
			var inst: Node = scene.instantiate()
			assert_not_null(inst, "scene cannot instantiate: " + path)
			inst.free()


func test_all_gameplay_actions_exist() -> void:
	for action in ACTIONS:
		assert_true(InputMap.has_action(action), "missing action: " + action)


func test_actions_bind_keyboard_and_gamepad() -> void:
	for action in ACTIONS:
		var events := InputMap.action_get_events(action)
		var keyboard := false
		var gamepad := false
		for event in events:
			if event is InputEventKey:
				keyboard = true
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				gamepad = true
		assert_true(keyboard, action + " has no keyboard binding")
		assert_true(gamepad, action + " has no gamepad binding")


func test_toolchain_pin_matches_project() -> void:
	var file := FileAccess.open("res://docs/toolchain.json", FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_eq(parsed["godot_version"], "4.7.2-stable")
	assert_eq(parsed["engine"], "godot")


func test_zero_network_contract() -> void:
	var file := FileAccess.open("res://docs/toolchain.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_eq(parsed["network"]["cloud_sync"], false)
