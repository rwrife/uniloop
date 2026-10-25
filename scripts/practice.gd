extends Node3D
## Canyon Ribbon race: same InputMap actions from keyboard, gamepad and touch.
## Handles gates, stunt scoring, crashes, falls, the finish roll-out and stats.

const MENU_SCENE := "res://scenes/menu.tscn"
const HANDLING := preload("res://scripts/handling.gd")
const COURSE := preload("res://scripts/canyon.gd")
const RIDER := preload("res://scripts/wheel_rider.gd")
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"flip_back", &"roll_forward",
	&"jump", &"brake", &"zflip_left", &"zflip_right", &"tabletop"]
const TRICK_SCORE := 500
const CRASH_PENALTY := 250
const CAMERA_TRACK_X := 12.0
const STATS_DELAY := 3.0
var course: CanyonCourse
var rider: WheelRider
var rules: RaceRules
var save: Dictionary
var save_path := "user://uniloop.json"
var current_device := "keyboard"
var tricks_landed := 0
var best_combo := 0
var crashes := 0
var finish_stats: Dictionary = {}
var _milliseconds := 0.0
var _last_gate := -1
var _message := "Ride right ▶ through each gate"
var _landing_shake := 0.0
var _last_pos := Vector3.ZERO
var _rider_vx := 0.0
var _finish_timer := -1.0
var _prior_best := -1
var _touch: Dictionary = {}
var _touch_buttons: Dictionary = {}
@onready var status: Label = $Hud/Root/Status
@onready var pause_panel: PanelContainer = $Hud/Root/PausePanel
@onready var pause_button: Button = $Hud/Root/Pause
@onready var settings_panel: PanelContainer = $Hud/Root/SettingsPanel
var popup: Label
var stats_panel: PanelContainer

func _input(event: InputEvent) -> void:
	current_device = UniloopUI.device_for(event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
	if event.is_action_pressed(&"pause") and (stats_panel == null or not stats_panel.visible):
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
		_release_touches()
		existing.queue_free()
		_touch_buttons.clear()

func _exit_to_menu() -> void:
	_release_touches()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func _restart_course() -> void:
	_release_touches()
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
	rider.course = course
	rider.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rider)
	rider.landed.connect(_on_landed)
	rider.boosted.connect(_on_boosted)
	rules = RaceRules.new(course.gates.size())
	var spot := course.spawn(-1)
	rider.place_on(spot.sec, spot.s)
	_last_pos = rider.global_position
	_snap_camera()
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
	_build_popup()
	_build_stats_panel()
	status.add_theme_constant_override("outline_size", 8)
	status.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1))
	if DisplayServer.is_touchscreen_available() and SaveStore.get_settings(save).touch_overlay:
		_build_touch_overlay()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var here := rider.global_position
	_rider_vx = lerpf(_rider_vx, (here.x - _last_pos.x) / maxf(delta, 0.0001), minf(1.0, delta * 6.0))
	if rules.finished:
		_last_pos = here
		return
	_milliseconds += delta * 1000.0
	var ms := int(_milliseconds)
	rules.tick(ms)
	_milliseconds -= ms
	var next := rules.next_checkpoint
	if next < course.gates.size():
		if course.crossed(course.gates[next], _last_pos, here):
			_on_checkpoint(rider, next)
	elif course.crossed(course.finish, _last_pos, here):
		_on_finish(rider)
	_last_pos = here
	if course.out_of_bounds(here) or (not rider.grounded and rider.air_time > rider.handling.air_timeout):
		_reset()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var camera: Camera3D = $Camera
	if rules.finished:
		if _finish_timer >= 0.0 and not stats_panel.visible:
			_finish_timer += delta
			if _finish_timer > STATS_DELAY or not camera.is_position_in_frustum(rider.global_position):
				_show_stats()
	else:
		var destination := _camera_target()
		var cam_pos := camera.global_position
		cam_pos.x = lerpf(cam_pos.x, destination.x, minf(1.0, delta * CAMERA_TRACK_X))
		cam_pos.y = lerpf(cam_pos.y, destination.y, minf(1.0, delta * rider.handling.camera_follow))
		cam_pos.z = lerpf(cam_pos.z, destination.z, minf(1.0, delta * 3.0))
		if _landing_shake > 0.0:
			cam_pos += Vector3(randf_range(-0.2, 0.2), randf_range(-0.14, 0.14), 0.0)
			_landing_shake = maxf(0.0, _landing_shake - delta)
		camera.global_position = cam_pos
	camera.rotation = Vector3.ZERO
	_update_status()

func _update_status() -> void:
	var arrow := "▶" if rider.drive_dir > 0 else ("◀" if rider.drive_dir < 0 else "◀▶")
	var d := current_device
	var prompts := "Ride %s/%s • Hop %s • Brake %s • Air: Flip %s Roll %s Twist %s/%s Z-Flip %s/%s Tabletop %s" % [
		UniloopUI.prompt(&"move_left", d), UniloopUI.prompt(&"move_right", d),
		UniloopUI.prompt(&"jump", d), UniloopUI.prompt(&"brake", d),
		UniloopUI.prompt(&"flip_back", d), UniloopUI.prompt(&"roll_forward", d),
		UniloopUI.prompt(&"move_left", d), UniloopUI.prompt(&"move_right", d),
		UniloopUI.prompt(&"zflip_left", d), UniloopUI.prompt(&"zflip_right", d),
		UniloopUI.prompt(&"tabletop", d)]
	status.text = "CANYON RIBBON  %s   Ride %s\nGate %d/%d  Speed %d  Score %d  Resets %d\n%s\n%s" % [
		_format_time(rules.elapsed_ms), arrow, rules.next_checkpoint, course.gates.size(),
		int(absf(rider.speed) * 3.6), rules.score, rules.resets, _message, prompts]

func _format_time(ms: int) -> String:
	return "%02d:%05.2f" % [ms / 60000, fmod(float(ms), 60000.0) / 1000.0]

func _on_landed(report: Dictionary) -> void:
	if rules.finished:
		return
	if report.crash:
		crashes += 1
		rules.score = maxi(0, rules.score - CRASH_PENALTY)
		rules.streak = 0
		_message = "WIPEOUT! %s" % report.reason
		_show_popup("WIPEOUT!  -%d\n%s" % [CRASH_PENALTY, report.reason], Color(1.0, 0.3, 0.25))
		_shake(0.3)
		_sparks(Color(1.0, 0.45, 0.2), 40)
		return
	var quality := rules.land(report.impact, report.tilt)
	var tricks: Array = report.tricks
	if report.count > 0:
		var points: int = TRICK_SCORE * report.count * tricks.size()
		rules.score += points
		tricks_landed += report.count
		best_combo = maxi(best_combo, report.count)
		_message = "%s +%d • speed boost!" % [" + ".join(tricks), points]
		_show_popup("%s\n+%d  BOOST!" % [" + ".join(tricks), points], Color(1.0, 0.86, 0.2))
		_sparks(Color(1.0, 0.9, 0.3), 28)
		_shake(0.12)
	elif report.air_time > 0.5:
		_message = "Landing: %s" % quality
		_shake(0.1)

func _on_boosted() -> void:
	if not rules.finished:
		_show_popup("BOOST!", Color(1.0, 0.6, 0.15), 0.6)

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != rider or absf(rider.speed) < rider.handling.gate_min_speed or not rules.cross_checkpoint(index):
		return
	_last_gate = index
	var heading := "▶" if course.gates[index].t.x > 0.0 else "◀"
	_message = "Checkpoint %d/%d %s" % [index + 1, course.gates.size(), heading]

func _on_finish(body: Node3D) -> void:
	if body != rider or absf(rider.speed) < rider.handling.gate_min_speed or not rules.finish():
		return
	var medal := RaceRules.medal(rules.elapsed_ms, course.MEDALS)
	var prior: Dictionary = save.records.get(CanyonCourse.COURSE_ID, {})
	_prior_best = int(prior.get("best_ms", -1))
	SaveStore.record_best(save, CanyonCourse.COURSE_ID, rules.elapsed_ms, medal, rules.score)
	finish_stats = {
		"time_ms": rules.elapsed_ms,
		"medal": medal,
		"score": rules.score,
		"tricks": tricks_landed,
		"best_combo": best_combo,
		"top_speed": rider.top_speed,
		"crashes": crashes,
		"resets": rules.resets,
		"saved": SaveStore.save_to_path(save, save_path),
	}
	_message = "FINISHED • %s • %s" % [medal.to_upper(), _format_time(rules.elapsed_ms)]
	rider.cruise = true
	rider.recover_time = 0.0
	_finish_timer = 0.0
	_show_popup("FINISH!", Color(1.0, 0.86, 0.2), 1.2)

func _reset() -> void:
	var spot := course.spawn(_last_gate)
	rider.place_on(spot.sec, spot.s)
	_last_pos = rider.global_position
	rules.reset_to_checkpoint()
	_snap_camera()
	_message = "Fell off • back to gate • +%ds" % (RaceRules.RESET_PENALTY_MS / 1000)

func _camera_target() -> Vector3:
	var h := rider.handling
	var lead := h.camera_lead * clampf(_rider_vx / h.max_speed, -1.0, 1.0)
	var p := rider.global_position
	return Vector3(p.x + lead, p.y + h.camera_height, p.z + h.camera_distance)

func _snap_camera() -> void:
	$Camera.global_position = _camera_target()
	$Camera.rotation = Vector3.ZERO

func _shake(amount: float) -> void:
	if not SaveStore.get_settings(save).reduced_shake:
		_landing_shake = maxf(_landing_shake, amount)

# --- Effects and panels -------------------------------------------------------

func _build_popup() -> void:
	popup = Label.new()
	popup.name = "TrickPopup"
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	popup.offset_left = -360.0
	popup.offset_right = 360.0
	popup.offset_top = 150.0
	popup.offset_bottom = 260.0
	popup.add_theme_font_size_override("font_size", 40)
	popup.add_theme_constant_override("outline_size", 10)
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.modulate.a = 0.0
	$Hud/Root.add_child(popup)

func _show_popup(text: String, color: Color, hold := 0.9) -> void:
	popup.text = text
	popup.add_theme_color_override("font_color", color)
	popup.modulate.a = 1.0
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(1.3, 1.3)
	var tween := popup.create_tween()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.15)
	tween.tween_interval(hold)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35)

func _sparks(color: Color, amount: int) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = amount
	burst.lifetime = 0.6
	burst.explosiveness = 0.95
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 9.0
	burst.gravity = Vector3(0, -18, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.12)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	mesh.material = paint
	burst.mesh = mesh
	add_child(burst)
	burst.global_position = rider.global_position
	burst.emitting = true
	burst.finished.connect(burst.queue_free)

func _build_stats_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.visible = false
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stats_panel.offset_left = -280.0
	stats_panel.offset_right = 280.0
	stats_panel.offset_top = -280.0
	stats_panel.offset_bottom = 260.0
	stats_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stats_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.05, 0.08, 0.15, 0.96)
	card.border_color = UniloopUI.YELLOW
	card.set_border_width_all(3)
	card.set_corner_radius_all(16)
	card.set_content_margin_all(24)
	stats_panel.add_theme_stylebox_override("panel", card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 10)
	stats_panel.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = "COURSE COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UniloopUI.YELLOW)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	var again := UniloopUI.button("Ride Again")
	again.name = "Again"
	again.pressed.connect(_restart_course)
	box.add_child(again)
	var menu := UniloopUI.button("Main Menu")
	menu.name = "Menu"
	menu.pressed.connect(_exit_to_menu)
	box.add_child(menu)
	$Hud/Root.add_child(stats_panel)

func _show_stats() -> void:
	var s := finish_stats
	var best := "NEW RECORD!" if _prior_best < 0 or s.time_ms < _prior_best else _format_time(_prior_best)
	var rows := [
		["Time", _format_time(s.time_ms)],
		["Medal", String(s.medal).to_upper()],
		["Score", str(s.score)],
		["Stunts landed", str(s.tricks)],
		["Best combo", "%d trick%s" % [s.best_combo, "" if s.best_combo == 1 else "s"]],
		["Top speed", "%d km/h" % int(s.top_speed * 3.6)],
		["Wipeouts", str(s.crashes)],
		["Falls / resets", str(s.resets)],
		["Personal best", best],
	]
	if not s.saved:
		rows.append(["Save", "Could not save record"])
	var grid: GridContainer = stats_panel.get_node("Box/Grid")
	for child in grid.get_children():
		child.queue_free()
	for row in rows:
		for k in 2:
			var cell := Label.new()
			cell.text = row[k]
			if k == 1:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)
	stats_panel.visible = true
	pause_button.visible = false
	status.visible = false
	popup.visible = false
	rider.process_mode = Node.PROCESS_MODE_DISABLED
	rider.visible = false
	stats_panel.get_node("Box/Again").grab_focus()

# --- Touch --------------------------------------------------------------------

func _apply_safe_area() -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, get_viewport().get_visible_rect().size)
	var margins := UniloopUI.safe_margins(viewport_rect, DisplayServer.get_display_safe_area())
	status.position = Vector2(margins.x, margins.y)
	status.size = Vector2(maxf(200, viewport_rect.size.x - margins.x - margins.z - 128), 150)
	$Hud/Root/Pause.offset_top = margins.y
	$Hud/Root/Pause.offset_bottom = margins.y + 56
	if _touch_buttons.is_empty():
		return
	var size := Vector2(viewport_rect.size)
	var unit := clampf(minf(size.x, size.y) * 0.13, 64.0, 120.0)
	var gap := unit * 0.12
	var left := Vector2(margins.x, size.y - margins.w)
	var right := Vector2(size.x - margins.z, size.y - margins.w)
	var layout := {
		&"move_left": Rect2(left + Vector2(0, -unit * 2.0 - gap), Vector2(unit, unit)),
		&"move_right": Rect2(left + Vector2((unit + gap) * 2.0, -unit * 2.0 - gap), Vector2(unit, unit)),
		&"flip_back": Rect2(left + Vector2(unit + gap, -unit * 3.0 - gap * 2.0), Vector2(unit, unit)),
		&"roll_forward": Rect2(left + Vector2(unit + gap, -unit), Vector2(unit, unit)),
		&"zflip_left": Rect2(left + Vector2(0, -unit * 4.0 - gap * 4.0), Vector2(unit * 1.4, unit * 0.7)),
		&"jump": Rect2(right + Vector2(-unit * 1.6, -unit * 1.6), Vector2(unit * 1.6, unit * 1.6)),
		&"brake": Rect2(right + Vector2(-unit * 2.8 - gap, -unit), Vector2(unit * 1.2, unit)),
		&"tabletop": Rect2(right + Vector2(-unit * 1.6, -unit * 2.8 - gap), Vector2(unit * 1.6, unit * 1.1)),
		&"zflip_right": Rect2(right + Vector2(-unit * 1.4, -unit * 4.0 - gap * 4.0), Vector2(unit * 1.4, unit * 0.7)),
	}
	for action: StringName in layout:
		var button: Panel = _touch_buttons[action]
		button.position = layout[action].position
		button.size = layout[action].size

func _build_touch_overlay() -> void:
	var overlay := Control.new()
	overlay.name = "TouchOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.15, 0.25, 0.45)
	style.border_color = Color(0.32, 0.88, 0.92, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	for action in ACTIONS:
		var button := Panel.new()
		button.name = String(action)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = UniloopUI.prompt(action, "touch")
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		overlay.add_child(button)
		_touch_buttons[action] = button
	$Hud/Root.add_child(overlay)

func _touch_action(at: Vector2) -> StringName:
	for action: StringName in _touch_buttons:
		var button: Panel = _touch_buttons[action]
		if button.is_visible_in_tree() and button.get_global_rect().grow(8.0).has_point(at):
			return action
	return &""

func _handle_touch(event: InputEvent) -> void:
	if _touch_buttons.is_empty() or get_tree().paused:
		return
	var held: StringName = _touch.get(event.index, &"")
	var target := &""
	if event is InputEventScreenDrag or event.pressed:
		target = _touch_action(event.position)
	if target == held:
		return
	_touch.erase(event.index)
	if held != &"" and not _touch.values().has(held):
		Input.action_release(held)
		_touch_buttons[held].modulate = Color.WHITE
	if target != &"":
		_touch[event.index] = target
		Input.action_press(target)
		_touch_buttons[target].modulate = Color(1.6, 1.6, 1.6)

func _release_touches() -> void:
	for action in _touch.values():
		Input.action_release(action)
	_touch.clear()

func _exit_tree() -> void:
	_release_touches()
