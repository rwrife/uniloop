extends Node3D
## Practice scene stub. Shows which input actions are currently held so the
## InputMap bindings (keyboard, gamepad, touch overlay) can be checked by hand.
## Riding mechanics arrive with the vehicle controller issue.

const MENU_SCENE := "res://scenes/menu.tscn"
const ACTIONS: Array[StringName] = [
	&"accelerate", &"brake", &"lean_left", &"lean_right", &"jump", &"pause"
]

@onready var status: Label = $Hud/Status


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	$Ground.mesh = plane
	if DisplayServer.is_touchscreen_available():
		_build_touch_overlay()


func _process(_delta: float) -> void:
	var held: PackedStringArray = []
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			held.append(String(action))
	status.text = "Practice stub - held: %s" % (", ".join(held) if held.size() > 0 else "none")
	if Input.is_action_just_pressed(&"pause"):
		get_tree().change_scene_to_file(MENU_SCENE)


## Touch controls drive the same InputMap actions as keyboard and gamepad.
func _build_touch_overlay() -> void:
	var overlay := HBoxContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -96.0
	for action in ACTIONS:
		var button := Button.new()
		button.text = String(action)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_down.connect(Input.action_press.bind(action))
		button.button_up.connect(Input.action_release.bind(action))
		overlay.add_child(button)
	$Hud.add_child(overlay)
