extends Control
## Full-featured, adaptive, strategy B custom menu for Uniloop.
## All controls keyboard and gamepad navigateable. No OS styling.

const PRACTICE_SCENE := "res://scenes/practice.tscn"
const SAVE_PATH := "user://uniloop.json"
const COURSES := [
	{"id": "canyon_climb", "title": "Canyon Ribbon", "desc": "Zig-zag climb: loops, U-turn helixes, vertical launches, shortcuts and goo"},
	{"id": "neon_night", "title": "Neon Night Loop", "desc": "High-speed banked loops (coming soon)"},
	{"id": "rooftop_line", "title": "Rooftop Line", "desc": "Precision gap riding (coming soon)"},
]

var save: Dictionary
var selected_course := 0
var remapping_action := &""
var current_device := "keyboard"
var _return_focus_node: Control = null

@onready var root_margin: MarginContainer = $SafeMargin
@onready var main_card: VBoxContainer = $SafeMargin/MainCard
@onready var play_btn: Button = $SafeMargin/MainCard/Actions/Play
@onready var courses_btn: Button = $SafeMargin/MainCard/Actions/Courses
@onready var settings_btn: Button = $SafeMargin/MainCard/Actions/Settings
@onready var help_btn: Button = $SafeMargin/MainCard/Actions/Help
@onready var quit_btn: Button = $SafeMargin/MainCard/Actions/Quit
@onready var records_label: Label = $SafeMargin/MainCard/Records
@onready var device_label: Label = $SafeMargin/MainCard/DevicePrompt
@onready var subpanel: PanelContainer = $SafeMargin/SubPanel
@onready var subpanel_title: Label = $SafeMargin/SubPanel/Content/Title
@onready var subpanel_body: VBoxContainer = $SafeMargin/SubPanel/Content/Body/Items
@onready var subpanel_back: Button = $SafeMargin/SubPanel/Content/Back


func _ready() -> void:
	var loaded := SaveStore.load_from_path(SAVE_PATH)
	save = loaded.save if loaded.ok else SaveStore.default_save()
	UniloopUI.restore_bindings(save)
	UniloopUI.apply_audio(SaveStore.get_settings(save))
	_refresh_theme()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	_wire_buttons()
	_update_summary()
	subpanel.visible = false
	play_btn.grab_focus()


func _input(event: InputEvent) -> void:
	var detected := UniloopUI.device_for(event)
	if detected != current_device:
		current_device = detected
		_update_device_prompt()
	if remapping_action != &"" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != Key.KEY_ESCAPE:
			UniloopUI.remap(save, remapping_action, event)
			SaveStore.save_to_path(save, SAVE_PATH)
		remapping_action = &""
		_open_settings()
		get_viewport().set_input_as_handled()
		return
	if subpanel.visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		_close_subpanel()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if subpanel.visible:
			_close_subpanel()
		else:
			get_tree().quit()


func _apply_layout() -> void:
	var touchscreen := DisplayServer.is_touchscreen_available()
	UniloopUI.apply_safe_area(root_margin, touchscreen)
	quit_btn.visible = OS.get_name() in ["Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "macOS"]
	_update_device_prompt()


func _refresh_theme() -> void:
	theme = UniloopUI.create_theme(SaveStore.get_settings(save))


func _update_device_prompt() -> void:
	var viewport_rect := Rect2i(Vector2i.ZERO, get_viewport_rect().size)
	var mode := UniloopUI.mode(viewport_rect.size, DisplayServer.is_touchscreen_available())
	if mode == "desktop":
		device_label.text = "Control: %s  •  Enter/Space/A: Select  •  Esc/B: Back" % current_device.to_upper()
	else:
		device_label.text = "Control: %s  •  Tap a button  •  Back closes panels" % current_device.to_upper()


func _wire_buttons() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	courses_btn.pressed.connect(_open_courses)
	settings_btn.pressed.connect(_open_settings)
	help_btn.pressed.connect(_open_help)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	subpanel_back.pressed.connect(_close_subpanel)


func _update_summary() -> void:
	var record: Dictionary = save.records.get(CanyonCourse.COURSE_ID, {})
	var best := str(record.get("best_ms", "none"))
	var medal := str(record.get("medal", "none"))
	var time_str := "%d:%05.2f" % [int(best) / 60000, fmod(float(best), 60000.0) / 1000.0] if best != "none" else "--"
	records_label.text = "CANYON RIBBON BEST: %s (%s)  •  TOTAL SCORE: %d" % [
		time_str, medal.to_upper(), int(save.get("total_score", 0))
	]


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(PRACTICE_SCENE)


func _open_courses() -> void:
	_prepare_subpanel("COURSE SELECT")
	for i in COURSES.size():
		var info: Dictionary = COURSES[i]
		var btn := UniloopUI.button("%s  [%s]" % [info["title"], "READY" if i == 0 else "LOCKED"])
		btn.disabled = (i != 0)
		btn.pressed.connect(_on_course_selected.bind(i))
		subpanel_body.add_child(btn)
		var desc := Label.new()
		desc.text = "   " + info["desc"]
		desc.modulate = Color(0.7, 0.8, 0.9)
		subpanel_body.add_child(desc)
	_show_subpanel(courses_btn)


func _on_course_selected(index: int) -> void:
	selected_course = index
	_close_subpanel()
	_on_play_pressed()


func _open_settings() -> void:
	_prepare_subpanel("SETTINGS & ACCESSIBILITY")
	var settings := SaveStore.get_settings(save)
	# High Contrast Toggle
	var hc := CheckButton.new()
	hc.text = "High Contrast Mode"
	hc.button_pressed = settings.high_contrast
	hc.focus_mode = Control.FOCUS_ALL
	hc.toggled.connect(_on_high_contrast_toggled)
	subpanel_body.add_child(hc)

	# Reduced Motion / Shake
	var rm := CheckButton.new()
	rm.text = "Reduced Camera Shake"
	rm.button_pressed = settings.reduced_shake
	rm.focus_mode = Control.FOCUS_ALL
	rm.toggled.connect(_on_reduced_shake_toggled)
	subpanel_body.add_child(rm)

	# Touch overlay
	var to := CheckButton.new()
	to.text = "On-Screen Touch Buttons"
	to.button_pressed = settings.touch_overlay
	to.focus_mode = Control.FOCUS_ALL
	to.toggled.connect(_on_touch_overlay_toggled)
	subpanel_body.add_child(to)

	# Text Scale
	var scale_label := Label.new()
	scale_label.text = "Text Scale:"
	subpanel_body.add_child(scale_label)
	var scale_box := HBoxContainer.new()
	for sc in SaveStore.TEXT_SCALES:
		var sbtn := UniloopUI.button(str(int(sc * 100)) + "%", 70)
		sbtn.pressed.connect(_on_text_scale_pressed.bind(sc))
		scale_box.add_child(sbtn)
	subpanel_body.add_child(scale_box)

	# Master volume slider
	var vol_box := VBoxContainer.new()
	var vol_label := Label.new()
	vol_label.text = "Master Volume: %d%%" % int(settings.audio_master)
	vol_box.add_child(vol_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = float(settings.audio_master)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 32)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_volume_changed.bind(vol_label))
	vol_box.add_child(slider)
	subpanel_body.add_child(vol_box)

	# Key rebind row
	var rebind_hdr := Label.new()
	rebind_hdr.text = "Keyboard Remap (Press button, then any key):"
	rebind_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rebind_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subpanel_body.add_child(rebind_hdr)
	var rebind_grid := GridContainer.new()
	rebind_grid.columns = 2
	for action in UniloopUI.ACTIONS:
		var lbl := Label.new()
		lbl.text = String(action).capitalize()
		rebind_grid.add_child(lbl)
		var b := UniloopUI.button(UniloopUI.prompt(action, "keyboard"))
		b.pressed.connect(_on_rebind_pressed.bind(action, b))
		rebind_grid.add_child(b)
	subpanel_body.add_child(rebind_grid)

	_show_subpanel(settings_btn)


func _on_high_contrast_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"high_contrast": enabled})
	SaveStore.save_to_path(save, SAVE_PATH)
	_refresh_theme()


func _on_reduced_shake_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"reduced_shake": enabled})
	SaveStore.save_to_path(save, SAVE_PATH)


func _on_touch_overlay_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"touch_overlay": enabled})
	SaveStore.save_to_path(save, SAVE_PATH)


func _on_text_scale_pressed(scale: float) -> void:
	SaveStore.set_settings(save, {"text_scale": scale})
	SaveStore.save_to_path(save, SAVE_PATH)
	_refresh_theme()


func _on_volume_changed(value: float, label: Label) -> void:
	SaveStore.set_settings(save, {"audio_master": int(value)})
	SaveStore.save_to_path(save, SAVE_PATH)
	label.text = "Master Volume: %d%% " % int(value)
	UniloopUI.apply_audio(SaveStore.get_settings(save))


func _on_rebind_pressed(action: StringName, button: Button) -> void:
	button.text = "Press any key..."
	remapping_action = action


func _open_help() -> void:
	_prepare_subpanel("HOW TO PLAY & ACCESSIBILITY")
	var lines: Array[String] = [
		"RACE GOAL: Ride the rail through every numbered gate in order. The course zig-zags upward: U-turn helixes and vertical launches flip your direction, so follow the arrows.",
		"TRACK COLORS: Blue/green = normal rail. Red/blue = loops, U-turns and launches ahead. Yellow = shortcut (hold Up at a ▲ fork). Red/yellow = jumps, pitfalls and green goo that slows you down.",
		"ONE-WAY RAILS: You can launch up through the underside of a rail and land on top of it. Fall off and you drop to the rail below - ride back up to where you were.",
		"STUNTS (in the air): Flip = backward 360, Roll = forward 360, Twist = 180 spin, Z-Flip = seat to the ground, Tabletop = hold the stunt button. Land clean for +500 per trick and a speed boost.",
		"WIPEOUTS: Land tilted, mid-twist, mid-z-flip or still in a tabletop and you crash: -250 points and a short stop while you recover.",
		"BOOST PADS: Orange pads give a burst of speed - you need it for loops and launches.",
		"DEVICE GLYPHS:",
		"  Ride left / right:  %s / %s (in the air: twist)" % [UniloopUI.prompt(&"move_left", current_device), UniloopUI.prompt(&"move_right", current_device)],
		"  Flip / Roll:        %s / %s (on the ground: hold Up to take shortcuts)" % [UniloopUI.prompt(&"flip_back", current_device), UniloopUI.prompt(&"roll_forward", current_device)],
		"  Hop / Pump:         %s" % UniloopUI.prompt(&"jump", current_device),
		"  Brake:              %s" % UniloopUI.prompt(&"brake", current_device),
		"  Z-Flip:             %s / %s" % [UniloopUI.prompt(&"zflip_left", current_device), UniloopUI.prompt(&"zflip_right", current_device)],
		"  Tabletop:           %s" % UniloopUI.prompt(&"tabletop", current_device),
		"  Pause/Menu:         %s" % UniloopUI.prompt(&"pause", current_device),
		"ACCESSIBILITY: High-contrast mode, text scaling up to 150%, reduced motion, and full remapping available in Settings.",
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subpanel_body.add_child(lbl)
	_show_subpanel(help_btn)


func _prepare_subpanel(title_text: String) -> void:
	subpanel_title.text = title_text
	for child in subpanel_body.get_children():
		child.queue_free()


func _show_subpanel(return_to: Control) -> void:
	_return_focus_node = return_to
	main_card.visible = false
	subpanel.visible = true
	subpanel_back.grab_focus()


func _close_subpanel() -> void:
	subpanel.visible = false
	main_card.visible = true
	if _return_focus_node != null and is_instance_valid(_return_focus_node):
		_return_focus_node.grab_focus()
	else:
		play_btn.grab_focus()
