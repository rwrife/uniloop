extends Node3D
## Canyon Ribbon race: same InputMap actions from keyboard, gamepad, touch.

const MENU_SCENE := "res://scenes/menu.tscn"
const HANDLING := preload("res://scripts/handling.gd")
const COURSE := preload("res://scripts/canyon.gd")
const RIDER := preload("res://scripts/wheel_rider.gd")
const ACTIONS: Array[StringName] = [&"lean_left", &"brake", &"accelerate", &"lean_right", &"jump"]
var course: CanyonCourse
var rider: WheelRider
var rules: RaceRules
var save: Dictionary
var save_path := "user://uniloop.json"
var _milliseconds := 0.0
var _last_gate := -1
var _message := "Ride through each gate in order"
@onready var status: Label = $Hud/Status

func _ready() -> void:
	course = COURSE.new()
	course.name = "CanyonRibbon"
	add_child(course)
	rider = RIDER.new()
	rider.name = "WheelRider"
	rider.handling = HANDLING.new()
	add_child(rider)
	rules = RaceRules.new(course.GATES.size())
	rider.reset_at(course.spawn_at(0, rider.handling.reset_offset), course.heading(0))
	for i in course.gate_areas.size():
		course.gate_areas[i].body_entered.connect(_on_checkpoint.bind(i))
	course.finish_area.body_entered.connect(_on_finish)
	var result := SaveStore.load_from_path(save_path)
	save = result.save if result.ok else SaveStore.default_save()
	if not result.ok:
		_message = "Save unreadable (%s); original left untouched" % result.error
	$Hud/Pause.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	if DisplayServer.is_touchscreen_available():
		_build_touch_overlay()

func _physics_process(delta: float) -> void:
	if rules.finished:
		return
	_milliseconds += delta * 1000.0
	var ms := int(_milliseconds)
	rules.tick(ms)
	_milliseconds -= ms
	if rider.last_landing == "landed":
		_message = "Landing: %s" % rules.land(rider.vertical_speed_before_landing, rider.bank_angle)
		rider.last_landing = ""
	if rider.global_position.y < rider.handling.fall_height or absf(rider.global_position.x) > 80.0 or rider.global_position.z < -200.0:
		_reset()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"pause"):
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	var camera: Camera3D = $Camera
	var behind := rider.global_basis.z * rider.handling.camera_distance
	var destination := rider.global_position + behind + Vector3.UP * rider.handling.camera_height
	camera.global_position = camera.global_position.lerp(destination, minf(1.0, delta * rider.handling.camera_follow))
	camera.look_at(rider.global_position + Vector3.UP, Vector3.UP)
	status.text = "CANYON RIBBON  %02d:%05.2f\nGate %d/%d  Speed %d  Score %d  Resets %d\n%s\nWASD/Arrows • Space jump/pump • Esc pause" % [
		rules.elapsed_ms / 60000, fmod(float(rules.elapsed_ms), 60000.0) / 1000.0,
		rules.next_checkpoint, course.GATES.size(), int(rider.speed), rules.score, rules.resets, _message]

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != rider or rider.speed < rider.handling.gate_min_speed or not rules.cross_checkpoint(index):
		return
	_last_gate = index
	_message = "Checkpoint %d/%d" % [index + 1, course.GATES.size()]

func _on_finish(body: Node3D) -> void:
	if body != rider or rider.speed < rider.handling.gate_min_speed or not rules.finish():
		return
	var medal := RaceRules.medal(rules.elapsed_ms, course.MEDALS)
	SaveStore.record_best(save, "canyon_ribbon", rules.elapsed_ms, medal, rules.score)
	_message = "FINISHED • %s • %0.2fs" % [medal.to_upper(), rules.elapsed_ms / 1000.0]
	if not SaveStore.save_to_path(save, save_path):
		_message += " • Could not save record"

func _reset() -> void:
	var index := 0 if _last_gate < 0 else course.GATES[_last_gate]
	rider.reset_at(course.spawn_at(index, rider.handling.reset_offset), course.heading(index))
	rules.reset_to_checkpoint()
	_message = "Reset at gate • +%ds" % (RaceRules.RESET_PENALTY_MS / 1000)

func _build_touch_overlay() -> void:
	var overlay := HBoxContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -110.0
	for action in ACTIONS:
		var button := Button.new()
		button.text = String(action).replace("lean_", "")
		button.custom_minimum_size = Vector2(65, 92)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_down.connect(Input.action_press.bind(action))
		button.button_up.connect(Input.action_release.bind(action))
		button.tree_exiting.connect(Input.action_release.bind(action))
		overlay.add_child(button)
	$Hud.add_child(overlay)
