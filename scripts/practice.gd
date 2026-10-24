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
var current_device := "keyboard"
var _landing_shake := 0.0
@onready var status: Label = $Hud/Root/Status
@onready var pause_panel: PanelContainer = $Hud/Root/PausePanel
@onready var pause_button: Button = $Hud/Root/Pause
@onready var settings_panel: PanelContainer = $Hud/Root/SettingsPanel

func _input(event: InputEvent) -> void:
	current_device = UniloopUI.device_for(event)
	if event.is_action_pressed(&"pause"):
		if settings_panel.visible:
			_open_pause_from_settings()
		else:
			_set_paused(not pause_panel.visible)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		if settings_panel.visible:
			_open_pause_from_settings()
		elif pause_panel.visible:
			_set_paused(false)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_set_paused(not pause_panel.visible)

func _set_paused(enabled: bool) -> void:
	pause_panel.visible = enabled
	settings_panel.visible = false
	get_tree().paused = enabled
	if enabled:
		$Hud/Root/PausePanel/Box/Resume.grab_focus()
	else:
		pause_button.grab_focus()


func _open_pause_settings() -> void:
	pause_panel.visible = false
	settings_panel.visible = true
	var settings := SaveStore.get_settings(save)
	$Hud/Root/SettingsPanel/Box/HighContrast.button_pressed = settings.high_contrast
	$Hud/Root/SettingsPanel/Box/ReducedShake.button_pressed = settings.reduced_shake
	$Hud/Root/SettingsPanel/Box/TouchOverlay.button_pressed = settings.touch_overlay
	$Hud/Root/SettingsPanel/Box/HighContrast.grab_focus()


func _open_pause_from_settings() -> void:
	settings_panel.visible = false
	pause_panel.visible = true
	$Hud/Root/PausePanel/Box/Resume.grab_focus()


func _wire_pause_settings() -> void:
	$Hud/Root/PausePanel/Box/Settings.pressed.connect(_open_pause_settings)
	$Hud/Root/SettingsPanel/Box/Back.pressed.connect(_open_pause_from_settings)
	$Hud/Root/SettingsPanel/Box/HighContrast.toggled.connect(_on_pause_high_contrast)
	$Hud/Root/SettingsPanel/Box/ReducedShake.toggled.connect(_on_pause_reduced_shake)
	$Hud/Root/SettingsPanel/Box/TouchOverlay.toggled.connect(_on_pause_touch_overlay)


func _on_pause_high_contrast(enabled: bool) -> void:
	SaveStore.set_settings(save, {"high_contrast": enabled})
	SaveStore.save_to_path(save, save_path)
	$Hud/Root.theme = UniloopUI.create_theme(SaveStore.get_settings(save))


func _on_pause_reduced_shake(enabled: bool) -> void:
	SaveStore.set_settings(save, {"reduced_shake": enabled})
	SaveStore.save_to_path(save, save_path)


func _on_pause_touch_overlay(enabled: bool) -> void:
	SaveStore.set_settings(save, {"touch_overlay": enabled})
	SaveStore.save_to_path(save, save_path)
	var existing := $Hud/Root.get_node_or_null("TouchOverlay")
	if enabled and existing == null and DisplayServer.is_touchscreen_available():
		_build_touch_overlay()
		_apply_safe_area()
	elif not enabled and existing != null:
		existing.queue_free()

func _exit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _restart_course() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	$Hud/Root.theme = UniloopUI.create_theme(SaveStore.get_settings(save))
	pause_button.pressed.connect(_set_paused.bind(true))
	$Hud/Root/PausePanel/Box/Resume.pressed.connect(_set_paused.bind(false))
	$Hud/Root/PausePanel/Box/Restart.pressed.connect(_restart_course)
	$Hud/Root/PausePanel/Box/Menu.pressed.connect(_exit_to_menu)
	_wire_pause_settings()
	if DisplayServer.is_touchscreen_available() and SaveStore.get_settings(save).touch_overlay:
		_build_touch_overlay()
	_apply_safe_area()

func _physics_process(delta: float) -> void:
	if get_tree().paused or rules.finished:
		return
	_milliseconds += delta * 1000.0
	var ms := int(_milliseconds)
	rules.tick(ms)
	_milliseconds -= ms
	if rider.last_landing == "landed":
		_message = "Landing: %s" % rules.land(rider.vertical_speed_before_landing, rider.bank_angle)
		_landing_shake = 0.14 if not SaveStore.get_settings(save).reduced_shake else 0.0
		rider.last_landing = ""
	if rider.global_position.y < rider.handling.fall_height or absf(rider.global_position.x) > rider.handling.course_bound_x or rider.global_position.z < rider.handling.course_end_z:
		_reset()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var camera: Camera3D = $Camera
	# Camera follows rider; pause handled in _input.
	var behind := rider.global_basis.z * rider.handling.camera_distance
	var destination := rider.global_position + behind + Vector3.UP * rider.handling.camera_height
	if _landing_shake > 0.0:
		destination += Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.1), 0.0)
		_landing_shake = maxf(0.0, _landing_shake - delta)
	camera.global_position = camera.global_position.lerp(destination, minf(1.0, delta * rider.handling.camera_follow))
	camera.look_at(rider.global_position + Vector3.UP, Vector3.UP)
	var prompt_str := "Accel: %s • Brake: %s • Lean: %s/%s • Jump: %s" % [
		UniloopUI.prompt(&"accelerate", current_device),
		UniloopUI.prompt(&"brake", current_device),
		UniloopUI.prompt(&"lean_left", current_device),
		UniloopUI.prompt(&"lean_right", current_device),
		UniloopUI.prompt(&"jump", current_device),
	]
	status.text = "CANYON RIBBON  %02d:%05.2f\nGate %d/%d  Speed %d  Score %d  Resets %d\n%s\n%s" % [
		rules.elapsed_ms / 60000, fmod(float(rules.elapsed_ms), 60000.0) / 1000.0,
		rules.next_checkpoint, course.GATES.size(), int(rider.speed), rules.score, rules.resets, _message, prompt_str]

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

func _apply_safe_area() -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, get_viewport().get_visible_rect().size)
	var margins := UniloopUI.safe_margins(viewport_rect, DisplayServer.get_display_safe_area())
	status.position = Vector2(margins.x, margins.y)
	status.size = Vector2(maxf(200, viewport_rect.size.x - margins.x - margins.z - 128), 150)
	$Hud/Root/Pause.offset_top = margins.y
	$Hud/Root/Pause.offset_bottom = margins.y + 56
	var overlay := $Hud/Root.get_node_or_null("TouchOverlay")
	if overlay:
		overlay.offset_bottom = -margins.w
		overlay.offset_top = -(margins.w + 96)
		overlay.offset_left = margins.x
		overlay.offset_right = -margins.z


func _build_touch_overlay() -> void:
	var overlay := HBoxContainer.new()
	overlay.name = "TouchOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay.offset_top = -110.0
	for action in ACTIONS:
		var button := Button.new()
		button.text = UniloopUI.prompt(action, "touch")
		button.custom_minimum_size = Vector2(65, 92)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(Input.action_press.bind(action))
		button.button_up.connect(Input.action_release.bind(action))
		button.tree_exiting.connect(Input.action_release.bind(action))
		overlay.add_child(button)
	$Hud/Root.add_child(overlay)
