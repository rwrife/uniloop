extends SceneTree
## One-shot dev helper: regenerates [input] in project.godot with keyboard,
## arrow-key, and gamepad bindings for every gameplay action. Run:
##   godot --headless --path . -s tools/gen_input_map.gd
## Touch devices reuse the same actions via the in-scene overlay (practice.gd).

# Godot 4 JoyButton indices: X=2, BACK=4, START=6, L3=7, dpad L=13/R=14.
const BUTTONS := {
	"SQUARE": 2,
	"START": 6,
	"SELECT": 4,
	"L3": 7,
	"DPAD_LEFT": 13,
	"DPAD_RIGHT": 14,
}

const KEYS := {
	"W": Key.KEY_W,
	"S": Key.KEY_S,
	"A": Key.KEY_A,
	"D": Key.KEY_D,
	"UP": Key.KEY_UP,
	"DOWN": Key.KEY_DOWN,
	"LEFT": Key.KEY_LEFT,
	"RIGHT": Key.KEY_RIGHT,
	"SPACE": Key.KEY_SPACE,
	"ESCAPE": Key.KEY_ESCAPE,
}

const ACTIONS := {
	"accelerate": {
		"keys": ["W", "UP"],
		"pad_buttons": [],
		"pad_axes": [[1, -1.0]],
	},
	"brake": {
		"keys": ["S", "DOWN"],
		"pad_buttons": [],
		"pad_axes": [[1, 1.0]],
	},
	"lean_left": {
		"keys": ["A", "LEFT"],
		"pad_buttons": ["DPAD_LEFT"],
		"pad_axes": [[0, -1.0]],
	},
	"lean_right": {
		"keys": ["D", "RIGHT"],
		"pad_buttons": ["DPAD_RIGHT"],
		"pad_axes": [[0, 1.0]],
	},
	"jump": {
		"keys": ["SPACE"],
		"pad_buttons": ["SQUARE", "L3"],
		"pad_axes": [],
	},
	"pause": {
		"keys": ["ESCAPE"],
		"pad_buttons": ["START", "SELECT"],
		"pad_axes": [],
	},
}


func _initialize() -> void:
	var lines := PackedStringArray()
	for action: String in ACTIONS:
		var spec: Dictionary = ACTIONS[action]
		var events := PackedStringArray()
		for key_name: String in spec["keys"]:
			var key := InputEventKey.new()
			key.physical_keycode = KEYS[key_name]
			events.append(_serialize(key))
		for button_name: String in spec["pad_buttons"]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = BUTTONS[button_name]
			events.append(_serialize(pad))
		for axis: Array in spec["pad_axes"]:
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis[0]
			motion.axis_value = axis[1]
			events.append(_serialize(motion))
		lines.append("%s={" % action)
		lines.append('"deadzone": 0.2,')
		lines.append('"events": [%s]' % ", ".join(events))
		lines.append("}")
	var text := "[input]\n\n" + "\n".join(lines) + "\n"
	var cfg := ConfigFile.new()
	var err := cfg.load("res://project.godot")
	if err != OK:
		push_error("cannot load project.godot: %s" % error_string(err))
		quit(1)
		return
	if not cfg.has_section("input"):
		cfg.add_section("input")
	for action: String in cfg.get_section_keys("input"):
		cfg.erase_section_key("input", action)
	var parsed := ConfigFile.new()
	var perr: int = parsed.parse(text)
	if perr != OK:
		push_error("generated input block does not parse: %s" % error_string(perr))
		quit(1)
		return
	for action: String in parsed.get_section_keys("input"):
		cfg.set_value("input", action, parsed.get_value("input", action))
	err = cfg.save("res://project.godot")
	if err != OK:
		push_error("cannot save project.godot: %s" % error_string(err))
		quit(1)
		return
	print("input map regenerated for %d actions" % ACTIONS.size())
	quit(0)


func _serialize(event: InputEvent) -> String:
	return var_to_str(event).strip_edges()
