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
var _hud_score := 0
var _shown_score := 0.0
var _landing_shake := 0.0
var _last_pos := Vector3.ZERO
var _rider_vx := 0.0
var _finish_timer := -1.0
var _prior_best := -1
var _touch: Dictionary = {}
var _touch_buttons: Dictionary = {}
## The 3-2-1-RACE! intro; the rider and clock are frozen until it ends.
var countdown_enabled := true
var racing := true
var countdown_label: Label
var _flash: ColorRect
@onready var status: HBoxContainer = $Hud/Root/Status
var time_label: Label
var score_label: Label
@onready var pause_panel: PanelContainer = $Hud/Root/PausePanel
@onready var pause_button: Button = $Hud/Root/Pause
var _pause_dim: ColorRect
var popup: Label
var stats_panel: PanelContainer
var finish_fx: FinishFX

func _input(event: InputEvent) -> void:
	current_device = UniloopUI.device_for(event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
	if event.is_action_pressed(&"pause") and (stats_panel == null or not stats_panel.visible):
		_set_paused(not pause_panel.visible)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and pause_panel.visible:
		_set_paused(false)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_set_paused(not pause_panel.visible)

func _set_paused(enabled: bool) -> void:
	pause_panel.visible = enabled
	_pause_dim.visible = enabled
	get_tree().paused = enabled
	if enabled:
		$Hud/Root/PausePanel/Box/Resume.grab_focus()
		pause_panel.pivot_offset = pause_panel.size * 0.5
		pause_panel.scale = Vector2(0.6, 0.6)
		pause_panel.create_tween().tween_property(pause_panel, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		pause_button.grab_focus()

## Arcade pause card: dimmed backdrop, wobbling PAUSED title and chunky buttons.
func _style_pause_panel() -> void:
	_pause_dim = ColorRect.new()
	_pause_dim.name = "PauseDim"
	_pause_dim.color = Color(0.07, 0.01, 0.15, 0.6)
	_pause_dim.visible = false
	_pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Hud/Root.add_child(_pause_dim)
	$Hud/Root.move_child(_pause_dim, pause_panel.get_index())
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.17, 0.05, 0.31, 0.96)
	card.border_color = UniloopUI.POP_YELLOW
	card.set_border_width_all(7)
	card.set_corner_radius_all(30)
	card.set_content_margin_all(30)
	card.content_margin_top = 10
	card.shadow_color = Color(0, 0, 0, 0.6)
	card.shadow_size = 14
	card.shadow_offset = Vector2(0, 10)
	pause_panel.add_theme_stylebox_override("panel", card)
	for side in ["offset_left", "offset_right", "offset_top", "offset_bottom"]:
		pause_panel.set(side, 0.0)
	var box: VBoxContainer = pause_panel.get_node("Box")
	box.add_theme_constant_override("separation", 16)
	var title: Label = box.get_node("Title")
	var looks := UniloopUI.chunky_label("PAUSED", 84)
	for prop in ["theme_override_fonts/font", "theme_override_font_sizes/font_size",
		"theme_override_colors/font_color", "theme_override_colors/font_outline_color",
		"theme_override_constants/outline_size", "theme_override_colors/font_shadow_color",
		"theme_override_constants/shadow_offset_x", "theme_override_constants/shadow_offset_y"]:
		title.set(prop, looks.get(prop))
	looks.free()
	var buttons: Array[Button] = []
	for key in ["Resume", "Restart", "Menu"]:
		var b: Button = box.get_node(key)
		UniloopUI.style_chunky(b, 40)
		b.custom_minimum_size = Vector2(380, 0)
		buttons.append(b)
	for i in buttons.size():
		var b := buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
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
	course.track_id = RaceSetup.track_id
	add_child(course)
	rider = RIDER.new()
	rider.name = "WheelRider"
	rider.handling = HANDLING.new()
	rider.frame_color = RaceSetup.uni().frame
	rider.seat_color = RaceSetup.uni().seat
	rider.course = course
	rider.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rider)
	($Environment as WorldEnvironment).environment.background_color = course.track.sky[0]
	rider.landed.connect(_on_landed)
	rider.boosted.connect(_on_boosted)
	rules = RaceRules.new(course.gates.size())
	var spot := course.spawn(-1)
	rider.place_on(spot.sec, spot.s)
	_last_pos = rider.global_position
	_snap_camera()
	var result := SaveStore.load_from_path(save_path)
	save = result.save if result.ok else SaveStore.default_save()
	$Hud/Root.theme = UniloopUI.create_theme(SaveStore.get_settings(save))
	pause_button.pressed.connect(_set_paused.bind(true))
	$Hud/Root/PausePanel/Box/Resume.pressed.connect(_set_paused.bind(false))
	$Hud/Root/PausePanel/Box/Restart.pressed.connect(_restart_course)
	$Hud/Root/PausePanel/Box/Menu.pressed.connect(_exit_to_menu)
	_style_pause_panel()
	_build_popup()
	_build_hud()
	if not result.ok:
		push_warning("Save unreadable (%s); original left untouched" % result.error)
		_show_popup("SAVE UNREADABLE", Color(1.0, 0.3, 0.25), 2.0)
	_build_stats_panel()
	if DisplayServer.is_touchscreen_available() and SaveStore.get_settings(save).touch_overlay:
		_build_touch_overlay()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	if countdown_enabled:
		_start_countdown()

func _start_countdown() -> void:
	racing = false
	rider.process_mode = Node.PROCESS_MODE_DISABLED
	_flash = ColorRect.new()
	_flash.name = "CountdownFlash"
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	$Hud/Root.add_child(_flash)
	countdown_label = UniloopUI.chunky_label("", 240)
	countdown_label.name = "Countdown"
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Hud/Root.add_child(countdown_label)
	var beats := [["3", Color("ff3b30")], ["2", Color("ff9f1c")], ["1", Color("ffd60a")], ["RACE!", Color("39ff6a")]]
	var tween := countdown_label.create_tween()
	tween.tween_interval(0.45)
	for i in beats.size():
		tween.tween_callback(_countdown_beat.bind(beats[i][0], beats[i][1], i == beats.size() - 1))
		if i < beats.size() - 1:
			tween.tween_interval(0.9)

func _countdown_beat(text: String, color: Color, go: bool) -> void:
	countdown_label.text = text
	countdown_label.add_theme_color_override("font_color", color)
	countdown_label.add_theme_font_size_override("font_size", 300 if go else 240)
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.modulate.a = 1.0
	countdown_label.scale = Vector2(3.2, 3.2)
	countdown_label.rotation = randf_range(-0.35, 0.35)
	var pop := countdown_label.create_tween().set_parallel()
	pop.tween_property(countdown_label, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(countdown_label, "rotation", randf_range(-0.08, 0.08), 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_flash.color = Color(color, 0.45 if go else 0.25)
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_shake(0.35 if go else 0.15)
	_sparks(color, 60 if go else 20)
	if go:
		racing = true
		rider.process_mode = Node.PROCESS_MODE_PAUSABLE
		pop.chain().tween_interval(0.35)
		pop.chain().tween_property(countdown_label, "scale", Vector2(2.4, 2.4), 0.3)
		pop.parallel().tween_property(countdown_label, "modulate:a", 0.0, 0.3)
	else:
		var beat := countdown_label.create_tween()
		beat.tween_interval(0.4)
		beat.tween_property(countdown_label, "scale", Vector2(0.85, 0.85), 0.45).set_trans(Tween.TRANS_SINE)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var here := rider.global_position
	_rider_vx = lerpf(_rider_vx, (here.x - _last_pos.x) / maxf(delta, 0.0001), minf(1.0, delta * 6.0))
	if rules.finished or not racing:
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

## Chunky TIME and POINTS badges plus an arcade-style PAUSE button.
func _build_hud() -> void:
	status.add_theme_constant_override("separation", 14)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label = _hud_badge("TimeBadge", "TIME", 200, UniloopUI.WHITE)
	score_label = _hud_badge("ScoreBadge", "POINTS", 180, UniloopUI.POP_YELLOW)
	pause_button.text = "PAUSE"
	UniloopUI.style_chunky(pause_button, 30)
	pause_button.custom_minimum_size = Vector2.ZERO

func _hud_badge(badge_name: String, caption: String, width: float, color: Color) -> Label:
	var plate := PanelContainer.new()
	plate.name = badge_name
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size.x = width
	var look := StyleBoxFlat.new()
	look.bg_color = Color(0.17, 0.05, 0.31, 0.9)
	look.border_color = UniloopUI.POP_YELLOW
	look.set_border_width_all(5)
	look.set_corner_radius_all(20)
	look.content_margin_left = 16
	look.content_margin_right = 16
	look.content_margin_top = 7
	look.content_margin_bottom = 4
	look.shadow_color = Color(0, 0, 0, 0.45)
	look.shadow_size = 2
	look.shadow_offset = Vector2(0, 5)
	plate.add_theme_stylebox_override("panel", look)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -8)
	plate.add_child(stack)
	var cap := UniloopUI.chunky_label(caption, 20, UniloopUI.CYAN)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(cap)
	var value := UniloopUI.chunky_label("0", 46, color)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(value)
	status.add_child(plate)
	return value

func _update_status() -> void:
	time_label.text = _format_time(rules.elapsed_ms)
	if rules.score != _hud_score:
		var gained := rules.score > _hud_score
		_hud_score = rules.score
		score_label.pivot_offset = score_label.size * 0.5
		score_label.scale = Vector2(1.4, 1.4) if gained else Vector2(0.8, 0.8)
		score_label.add_theme_color_override("font_color", Color("fff3a0") if gained else Color(1.0, 0.3, 0.25))
		var pop := score_label.create_tween().set_parallel()
		pop.tween_property(score_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(score_label, "theme_override_colors/font_color", UniloopUI.POP_YELLOW, 0.5)
	# Roll the shown points toward the real score like an arcade counter.
	_shown_score = move_toward(_shown_score, float(rules.score), maxf(40.0, absf(rules.score - _shown_score) * 6.0) * get_process_delta_time())
	score_label.text = str(roundi(_shown_score))

func _format_time(ms: int) -> String:
	return "%02d:%05.2f" % [ms / 60000, fmod(float(ms), 60000.0) / 1000.0]

func _on_landed(report: Dictionary) -> void:
	if rules.finished:
		return
	if report.crash:
		crashes += 1
		rules.score = maxi(0, rules.score - CRASH_PENALTY)
		rules.streak = 0
		_show_popup("WIPEOUT!  -%d\n%s" % [CRASH_PENALTY, report.reason], Color(1.0, 0.3, 0.25))
		_shake(0.3)
		_sparks(Color(1.0, 0.45, 0.2), 40)
		return
	# Plain hops don't feed the landing streak, so hop-spamming can't farm points.
	var quality := rules.land(report.impact, report.tilt) if report.air_time >= 0.9 or report.count > 0 else "hop"
	var tricks: Array = report.tricks
	if report.count > 0:
		var points: int = TRICK_SCORE * report.count * tricks.size()
		rules.score += points
		tricks_landed += report.count
		best_combo = maxi(best_combo, report.count)
		_show_popup("%s\n+%d  BOOST!" % [" + ".join(tricks), points], Color(1.0, 0.86, 0.2))
		_sparks(Color(1.0, 0.9, 0.3), 28)
		_shake(0.12)
	elif report.air_time > 0.5 and quality != "hop":
		_shake(0.1)

func _on_boosted() -> void:
	if not rules.finished:
		_show_popup("BOOST!", Color(1.0, 0.6, 0.15), 0.6)

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != rider or absf(rider.speed) < rider.handling.gate_min_speed or not rules.cross_checkpoint(index):
		return
	_last_gate = index
	_show_popup("CHECKPOINT %d/%d" % [index + 1, course.gates.size()], UniloopUI.CYAN, 0.6)

func _on_finish(body: Node3D) -> void:
	if body != rider or absf(rider.speed) < rider.handling.gate_min_speed or not rules.finish():
		return
	var medal := RaceRules.medal(rules.elapsed_ms, course.medals)
	var prior: Dictionary = save.records.get(course.course_id, {})
	_prior_best = int(prior.get("best_ms", -1))
	SaveStore.record_best(save, course.course_id, rules.elapsed_ms, medal, rules.score)
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
	_show_popup("FELL!  +%dS" % (RaceRules.RESET_PENALTY_MS / 1000), Color(1.0, 0.3, 0.25))

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
	popup.add_theme_font_override("font", UniloopUI.CHUNKY_FONT)
	popup.add_theme_font_size_override("font_size", 54)
	popup.add_theme_constant_override("outline_size", 14)
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
	finish_fx = FinishFX.new()
	finish_fx.visible = false
	$Hud/Root.add_child(finish_fx)
	stats_panel = PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.visible = false
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stats_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stats_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	stats_panel.custom_minimum_size = Vector2(640, 0)
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.17, 0.05, 0.31, 0.95)
	card.border_color = UniloopUI.POP_YELLOW
	card.set_border_width_all(7)
	card.set_corner_radius_all(30)
	card.set_content_margin_all(26)
	card.content_margin_top = 8
	card.shadow_color = Color(0, 0, 0, 0.6)
	card.shadow_size = 14
	card.shadow_offset = Vector2(0, 10)
	stats_panel.add_theme_stylebox_override("panel", card)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 6)
	stats_panel.add_child(box)
	var title := UniloopUI.chunky_label("FINISH!", 92)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var track := UniloopUI.chunky_label("", 30, UniloopUI.CYAN)
	track.name = "Track"
	track.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(track)
	var badges := HBoxContainer.new()
	badges.name = "Badges"
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 18)
	box.add_child(badges)
	var medal := PanelContainer.new()
	medal.name = "Medal"
	badges.add_child(medal)
	var medal_text := UniloopUI.chunky_label("", 40, UniloopUI.INK)
	medal_text.name = "Text"
	medal_text.remove_theme_constant_override("outline_size")
	medal_text.add_theme_constant_override("shadow_offset_y", 0)
	medal.add_child(medal_text)
	var time := UniloopUI.chunky_label("", 52, UniloopUI.WHITE)
	time.name = "Time"
	badges.add_child(time)
	var record := UniloopUI.chunky_label("NEW RECORD!", 34, UniloopUI.POP_PINK)
	record.name = "Record"
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 0)
	box.add_child(grid)
	var hint := UniloopUI.chunky_label("", 24, Color("c9b8ff"))
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	box.add_child(buttons)
	var again := UniloopUI.chunky_button("RIDE AGAIN!", 36, Vector2(250, 0))
	again.name = "Again"
	again.pressed.connect(_restart_course)
	buttons.add_child(again)
	var menu := UniloopUI.chunky_button("MAIN MENU", 36, Vector2(250, 0))
	menu.name = "Menu"
	menu.pressed.connect(_exit_to_menu)
	buttons.add_child(menu)
	again.focus_neighbor_right = again.get_path_to(menu)
	menu.focus_neighbor_left = menu.get_path_to(again)
	$Hud/Root.add_child(stats_panel)

func _show_stats() -> void:
	var s := finish_stats
	var record: bool = _prior_best < 0 or s.time_ms < _prior_best
	var box := stats_panel.get_node("Box")
	box.get_node("Track").text = String(course.track.title).to_upper()
	box.get_node("Badges/Time").text = _format_time(s.time_ms)
	var looks := {
		"gold": ["GOLD!", Color("ffd60a")],
		"silver": ["SILVER!", Color("dfe7f2")],
		"bronze": ["BRONZE!", Color("e08a4a")],
		"none": ["NO MEDAL", Color("8d7fa6")],
	}
	var look: Array = looks.get(String(s.medal), looks.none)
	var medal: PanelContainer = box.get_node("Badges/Medal")
	medal.get_node("Text").text = "★ %s" % look[0] if s.medal != "none" else look[0]
	var plate := StyleBoxFlat.new()
	plate.bg_color = look[1]
	plate.border_color = UniloopUI.INK
	plate.set_border_width_all(5)
	plate.set_corner_radius_all(40)
	plate.content_margin_left = 22
	plate.content_margin_right = 22
	plate.content_margin_top = 0
	plate.content_margin_bottom = 0
	medal.add_theme_stylebox_override("panel", plate)
	var rec_label: Label = box.get_node("Record")
	rec_label.text = "NEW RECORD!" if record else "BEST  %s" % _format_time(_prior_best)
	rec_label.add_theme_color_override("font_color", UniloopUI.POP_PINK if record else Color("c9b8ff"))
	var next_tier: String = {"none": "bronze", "bronze": "silver", "silver": "gold"}.get(String(s.medal), "")
	var hint := "%s under %s - go again!" % [next_tier.to_upper(), _format_time(course.medals[next_tier])] if next_tier != "" else ""
	if not s.saved:
		hint = "Could not save record"
	box.get_node("Hint").text = hint
	box.get_node("Hint").visible = hint != ""
	var rows := [
		["SCORE", "0"],
		["STUNTS", str(s.tricks)],
		["BEST COMBO", "x%d" % s.best_combo],
		["TOP SPEED", "%d km/h" % int(s.top_speed * 3.6)],
		["WIPEOUTS", str(s.crashes)],
		["FALLS", str(s.resets)],
	]
	var grid: GridContainer = box.get_node("Grid")
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var cells: Array[Label] = []
	for row in rows:
		var key := UniloopUI.chunky_label(row[0], 28, UniloopUI.WHITE)
		var value := UniloopUI.chunky_label(row[1], 32)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.custom_minimum_size.x = 110
		grid.add_child(key)
		grid.add_child(value)
		cells.append_array([key, value])
	finish_fx.start()
	stats_panel.visible = true
	pause_button.visible = false
	status.visible = false
	popup.visible = false
	rider.process_mode = Node.PROCESS_MODE_DISABLED
	rider.visible = false
	box.get_node("Buttons/Again").grab_focus()
	# Animate: card slams in, title wobbles, medal pops, rows cascade, score counts up.
	await get_tree().process_frame
	stats_panel.pivot_offset = stats_panel.size * 0.5
	stats_panel.scale = Vector2(0.2, 0.2)
	stats_panel.rotation = -0.2
	var t := stats_panel.create_tween().set_parallel()
	t.tween_property(stats_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(stats_panel, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var title: Label = box.get_node("Title")
	title.pivot_offset = title.size * 0.5
	var wobble := title.create_tween().set_loops()
	wobble.tween_property(title, "rotation", 0.05, 0.5).set_trans(Tween.TRANS_SINE)
	wobble.parallel().tween_property(title, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(title, "rotation", -0.05, 0.5).set_trans(Tween.TRANS_SINE)
	wobble.parallel().tween_property(title, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	medal.pivot_offset = medal.size * 0.5
	medal.scale = Vector2.ZERO
	var pop := medal.create_tween()
	pop.tween_interval(0.45)
	pop.tween_property(medal, "scale", Vector2(1.25, 1.25), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(medal, "scale", Vector2.ONE, 0.18)
	rec_label.pivot_offset = rec_label.size * 0.5
	if record:
		var pulse := rec_label.create_tween().set_loops()
		pulse.tween_property(rec_label, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(rec_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	for i in cells.size():
		var cell := cells[i]
		cell.modulate.a = 0.0
		var slide := cell.create_tween()
		slide.tween_interval(0.6 + 0.07 * (i / 2))
		slide.tween_property(cell, "modulate:a", 1.0, 0.2)
	var score_cell := cells[1]
	var count := score_cell.create_tween()
	count.tween_interval(0.7)
	count.tween_method(func(v: int) -> void: score_cell.text = str(v), 0, int(s.score), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
# --- Touch --------------------------------------------------------------------

func _apply_safe_area() -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, get_viewport().get_visible_rect().size)
	var margins := UniloopUI.safe_margins(viewport_rect, DisplayServer.get_display_safe_area())
	status.position = Vector2(margins.x, margins.y)
	status.size = Vector2.ZERO
	$Hud/Root/Pause.offset_top = margins.y
	$Hud/Root/Pause.offset_bottom = margins.y + 60
	$Hud/Root/Pause.offset_right = -margins.z
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
