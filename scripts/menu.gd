extends Control
## Title screen over the splash art, then Quick Race -> Pick Your Uni ->
## Pick Track -> race (which opens with the 3-2-1 countdown). League lists
## per-track records; Options holds settings, remapping and How to Play.
## Every screen is keyboard, gamepad and touch navigable.

const PRACTICE_SCENE := "res://scenes/practice.tscn"
const SPLASH := preload("res://assets/ui/boot_splash.png")
const AUDIO := preload("res://scripts/audio.gd")
const DESKTOP_OS := ["Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "macOS"]
## Where Back goes from each sub-screen.
const PARENT := {"uni": "title", "track": "uni", "league": "title", "options": "title", "help": "options"}

var save: Dictionary
var save_path := "user://uniloop.json"
var remapping_action := &""
var current_device := "keyboard"
var screen := "title"
## Tests turn this off so picking a track doesn't change scene.
var auto_launch := true
var buttons: Dictionary = {}
var cards: Array[Button] = []

var background: TextureRect
var safe: MarginContainer
var title_menu: VBoxContainer
var panel: PanelContainer
var panel_title: Label
var panel_body: VBoxContainer
var back_btn: Button
var device_label: Label
var audio: AUDIO


func _ready() -> void:
	var loaded := SaveStore.load_from_path(save_path)
	save = loaded.save if loaded.ok else SaveStore.default_save()
	UniloopUI.restore_bindings(save)
	UniloopUI.apply_audio(SaveStore.get_settings(save))
	audio = AUDIO.new()
	audio.name = "Audio"
	add_child(audio)
	audio.play_music("title")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_theme()
	_build()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	_show_title()
	if OS.get_environment("UNILOOP_BENCHMARK") == "1":
		get_tree().root.add_child.call_deferred(load("res://scripts/performance_probe.gd").new())


func _input(event: InputEvent) -> void:
	var detected := UniloopUI.device_for(event)
	if detected != current_device and not (event is InputEventMouseMotion):
		current_device = detected
		_update_device_prompt()
	if remapping_action != &"" and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != Key.KEY_ESCAPE:
			UniloopUI.remap(save, remapping_action, event)
			SaveStore.save_to_path(save, save_path)
		remapping_action = &""
		_open("options")
		get_viewport().set_input_as_handled()
		return
	if remapping_action == &"" and UniloopUI.is_menu_submit(event):
		if UniloopUI.activate_focused_control(get_viewport()):
			return
	if screen != "title" and (event.is_action_pressed(&"pause") or UniloopUI.is_menu_cancel(event)):
		_go_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if is_node_ready():
		if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
			audio.set_paused(true)
		elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
			audio.set_paused(false)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen != "title":
			_go_back()
		else:
			get_tree().quit()


# --- Layout ---------------------------------------------------------------------

func _ui_scale() -> float:
	var vp := get_viewport_rect().size
	return clampf(minf(vp.x / 1280.0, vp.y / 720.0), 0.55, 1.6)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	background = TextureRect.new()
	background.name = "Splash"
	background.texture = SPLASH
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Cover the viewport with extra bleed throughout the breathing animation.
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var breathe_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	// Smooth sine zoom sampled directly in the fragment shader without moving or
	// resizing the Control rect on large screens or snapping to integer texels.
	float zoom = 1.04 + 0.02 * sin(TIME * (3.14159265359 / 6.0));
	vec2 centered = (UV - vec2(0.5, 0.5)) / zoom + vec2(0.5, 0.5);
	COLOR = texture(TEXTURE, centered);
}
"""
	breathe_mat.shader = shader
	background.material = breathe_mat
	add_child(background)

	safe = MarginContainer.new()
	safe.name = "SafeMargin"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)

	title_menu = VBoxContainer.new()
	title_menu.name = "TitleMenu"
	title_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_menu.size_flags_vertical = Control.SIZE_SHRINK_END
	safe.add_child(title_menu)
	var entries := [["quick_race", "QUICK RACE"], ["multiplayer", "MULTIPLAYER"],
		["league", "LEAGUE"], ["options", "OPTIONS"]]
	if OS.get_name() in DESKTOP_OS:
		entries.append(["quit", "QUIT"])
	for entry in entries:
		var b := UniloopUI.chunky_button(entry[1], 44)
		b.name = String(entry[0]).to_pascal_case()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_menu.add_child(b)
		buttons[entry[0]] = b
	var mp: Button = buttons.multiplayer
	mp.disabled = true
	mp.focus_mode = Control.FOCUS_NONE
	mp.tooltip_text = "Coming soon"
	var soon := UniloopUI.chunky_label("SOON!", 22, Color.WHITE)
	soon.name = "Soon"
	soon.rotation = deg_to_rad(-12)
	soon.add_theme_color_override("font_color", UniloopUI.POP_PINK)
	soon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	soon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(soon)
	buttons.quick_race.pressed.connect(_open.bind("uni"))
	buttons.league.pressed.connect(_open.bind("league"))
	buttons.options.pressed.connect(_open.bind("options"))
	if buttons.has("quit"):
		buttons.quit.pressed.connect(func() -> void: get_tree().quit())
	var ring: Array[Button] = []
	for key in buttons:
		if not buttons[key].disabled:
			ring.append(buttons[key])
	for i in ring.size():
		ring[i].focus_neighbor_bottom = ring[i].get_path_to(ring[(i + 1) % ring.size()])
		ring[i].focus_neighbor_top = ring[i].get_path_to(ring[(i - 1 + ring.size()) % ring.size()])
		ring[i].focus_next = ring[i].focus_neighbor_bottom
		ring[i].focus_previous = ring[i].focus_neighbor_top

	panel = PanelContainer.new()
	panel.name = "Panel"
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.1, 0.03, 0.19, 0.93)
	plate.border_color = UniloopUI.POP_YELLOW
	plate.set_border_width_all(6)
	plate.set_corner_radius_all(26)
	plate.set_content_margin_all(22)
	plate.shadow_color = Color(0, 0, 0, 0.5)
	plate.shadow_size = 12
	panel.add_theme_stylebox_override("panel", plate)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	safe.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	panel_title = UniloopUI.chunky_label("", 60)
	panel_title.name = "Title"
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(panel_title)
	var scroll := ScrollContainer.new()
	scroll.name = "Body"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	content.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.name = "Items"
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 10)
	scroll.add_child(panel_body)
	back_btn = UniloopUI.chunky_button("BACK", 32)
	back_btn.icon = preload("res://assets/ui/back_arrow.svg")
	back_btn.name = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.pressed.connect(_go_back)
	content.add_child(back_btn)

	device_label = Label.new()
	device_label.name = "DevicePrompt"
	device_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	device_label.size_flags_vertical = Control.SIZE_SHRINK_END
	device_label.add_theme_color_override("font_outline_color", UniloopUI.INK)
	device_label.add_theme_constant_override("outline_size", 6)
	device_label.add_theme_font_size_override("font_size", 16)
	safe.add_child(device_label)


func _apply_layout() -> void:
	# Bias the crop toward the upper artwork so the title clears wide phone edges.
	var viewport_size := get_viewport_rect().size
	var image_size := background.texture.get_size()
	var image_height := viewport_size.x * image_size.y / image_size.x
	background.offset_bottom = maxf(0.0, image_height - viewport_size.y) * 0.35
	background.pivot_offset = background.size * 0.5
	var touchscreen := DisplayServer.is_touchscreen_available()
	UniloopUI.apply_safe_area(safe, touchscreen)
	var s := _ui_scale()
	var pad := int(28 * s)
	for side in ["margin_left", "margin_bottom"]:
		safe.add_theme_constant_override(side, maxi(safe.get_theme_constant(side), pad))
	title_menu.add_theme_constant_override("separation", int(14 * s))
	for key in buttons:
		var b: Button = buttons[key]
		UniloopUI.style_chunky(b, int(44 * s))
		b.custom_minimum_size = Vector2(360 * s, 0)
	_update_device_prompt()
	if screen != "title" and is_inside_tree():
		_open(screen)


func _refresh_theme() -> void:
	theme = UniloopUI.create_theme(SaveStore.get_settings(save))


func _update_device_prompt() -> void:
	if device_label == null:
		return
	var mode := UniloopUI.mode_label(current_device)
	var vp := Vector2i(get_viewport_rect().size)
	if UniloopUI.mode(vp, DisplayServer.is_touchscreen_available()) == "desktop":
		device_label.text = "%s  •  Enter/Space/A: Select  •  Esc/B: Back" % mode
	else:
		device_label.text = "%s  •  Tap to select" % mode


# --- Navigation -----------------------------------------------------------------

func _show_title() -> void:
	screen = "title"
	panel.visible = false
	title_menu.visible = true
	var pop := title_menu.create_tween()
	title_menu.modulate.a = 0.0
	pop.tween_property(title_menu, "modulate:a", 1.0, 0.25)
	buttons.quick_race.grab_focus()


func _go_back() -> void:
	var from := screen
	var to: String = PARENT.get(screen, "title")
	if to == "title":
		_show_title()
		var key := "quick_race" if from in ["uni", "track"] else from
		if buttons.has(key):
			buttons[key].grab_focus()
	else:
		_open(to)


func _open(which: String) -> void:
	screen = which
	title_menu.visible = false
	panel.visible = true
	cards.clear()
	for child in panel_body.get_children():
		panel_body.remove_child(child)
		child.queue_free()
	var navigation := panel.get_node_or_null("Content/TrackNavigation")
	if navigation != null:
		navigation.get_parent().remove_child(navigation)
		navigation.queue_free()
	back_btn.focus_neighbor_top = NodePath()
	back_btn.text = "MENU" if PARENT.get(which, "title") == "title" else "BACK"
	UniloopUI.style_chunky(back_btn, int(30 * _ui_scale()))
	match which:
		"uni": _build_uni_picker()
		"track": _build_track_picker()
		"league": _build_league()
		"options": _build_options()
		"help": _build_help()
	_fit_panel()
	panel_title.add_theme_font_size_override("font_size", int(60 * _ui_scale()))
	panel_title.pivot_offset = Vector2(panel_title.size.x * 0.5, panel_title.size.y * 0.5)
	panel_title.scale = Vector2(1.25, 1.25)
	panel_title.create_tween().tween_property(panel_title, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cards.is_empty():
		var first := _first_focusable(panel_body)
		(first if first != null else back_btn).grab_focus()


## Centre the panel and cap its size so it never sprawls across big screens.
func _fit_panel() -> void:
	var s := _ui_scale()
	var widths := {"uni": 900.0, "track": 1220.0, "league": 860.0, "options": 820.0, "help": 860.0}
	var room := get_viewport_rect().size - Vector2(
		safe.get_theme_constant("margin_left") + safe.get_theme_constant("margin_right"),
		safe.get_theme_constant("margin_top") + safe.get_theme_constant("margin_bottom"))
	# Portrait uni picker has three rows; give it height before enabling scrolling.
	var height := 920.0 if screen == "uni" and room.x < room.y else float({"track": 660.0, "uni": 760.0}.get(screen, 860.0))
	if screen == "track" and room.x < room.y:
		height = 1700.0
	panel.custom_minimum_size = Vector2(
		minf(room.x, float(widths.get(screen, 860.0)) * s),
		minf(room.y, height * s))


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL and (child as Control).visible:
			return child
		var found := _first_focusable(child)
		if found != null:
			return found
	return null


func _card(minimum: Vector2) -> Button:
	var b := UniloopUI.chunky_button("", 20, minimum)
	b.clip_contents = true
	cards.append(b)
	return b


func _card_box(card: Button) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 14.0 * _ui_scale()
	box.offset_left = inset
	box.offset_top = inset
	box.offset_right = -inset
	box.offset_bottom = -inset
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	return box


# --- Pick your uni ---------------------------------------------------------------

func _build_uni_picker() -> void:
	panel_title.text = "PICK YOUR UNI"
	var s := _ui_scale()
	var grid := GridContainer.new()
	grid.columns = 2 if get_viewport_rect().size.x < get_viewport_rect().size.y else 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", int(12 * s))
	grid.add_theme_constant_override("v_separation", int(10 * s))
	panel_body.add_child(grid)
	for i in RaceSetup.UNIS.size():
		var info: Dictionary = RaceSetup.UNIS[i]
		var card := _card(Vector2(234, 207) * s)
		card.name = "Uni%d" % i
		var box := _card_box(card)
		var icon := UniIcon.new()
		icon.frame = info.frame
		icon.seat = info.seat
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var label := UniloopUI.chunky_label(String(info.name).to_upper(), int(28 * s))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		card.pressed.connect(_on_uni_picked.bind(i))
		card.focus_entered.connect(icon.spin)
		card.mouse_entered.connect(icon.spin)
		grid.add_child(card)
	cards[clampi(RaceSetup.uni_index, 0, cards.size() - 1)].grab_focus()


func _on_uni_picked(index: int) -> void:
	RaceSetup.uni_index = index
	_open("track")


# --- Pick track ------------------------------------------------------------------

func _build_track_picker() -> void:
	panel_title.text = "PICK YOUR TRACK"
	var s := _ui_scale()
	var viewport_size := get_viewport_rect().size
	if viewport_size.y > viewport_size.x:
		s = maxf(s, viewport_size.x / 390.0)
	var scroll := ScrollContainer.new()
	scroll.name = "TrackScroller"
	scroll.custom_minimum_size.y = 382 * s
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.scroll_deadzone = 10
	panel_body.add_child(scroll)
	var tracks := HBoxContainer.new()
	tracks.name = "Tracks"
	tracks.add_theme_constant_override("separation", int(18 * s))
	scroll.add_child(tracks)
	var selected := 0
	for i in RaceSetup.TRACKS.size():
		var t: Dictionary = RaceSetup.TRACKS[i]
		if t.id == RaceSetup.track_id:
			selected = i
		var card := _card(Vector2(270, 360) * s)
		card.name = "Track%d" % i
		var box := _card_box(card)
		box.add_theme_constant_override("separation", int(6 * s))
		var sky := TextureRect.new()
		var grad := Gradient.new()
		grad.set_color(0, t.sky[2].lightened(0.15))
		grad.set_color(1, t.sky[1].lightened(0.3))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 64
		tex.height = 16
		sky.texture = tex
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.stretch_mode = TextureRect.STRETCH_SCALE
		sky.custom_minimum_size = Vector2(0, 14 * s)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sky)
		var title := UniloopUI.chunky_label(String(t.title).to_upper(), int(34 * s))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size.y = 84 * s
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(title)
		for stat in [["LENGTH", "length"], ["SPEED", "speed"], ["DIFFICULTY", "difficulty"]]:
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var name_label := UniloopUI.chunky_label(stat[0], int(20 * s), Color.WHITE)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(name_label)
			var stars := StarBar.new()
			stars.value = int(t[stat[1]])
			stars.custom_minimum_size = Vector2(84, 24) * s
			stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(stars)
			box.add_child(row)
		var blurb := Label.new()
		blurb.text = t.blurb
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blurb.add_theme_font_size_override("font_size", int(17 * s))
		blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(blurb)
		var best := UniloopUI.chunky_label(_record_text(t.id), int(22 * s), Color("7df9ff"))
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(best)
		card.pressed.connect(_on_track_picked.bind(i))
		tracks.add_child(card)
	var navigation := HBoxContainer.new()
	navigation.name = "TrackNavigation"
	navigation.add_theme_constant_override("separation", int(12 * s))
	var content: VBoxContainer = panel.get_node("Content")
	content.add_child(navigation)
	content.move_child(navigation, 1)
	var previous := UniloopUI.chunky_button("<", int(30 * s), Vector2(56, 48) * s)
	previous.name = "Previous"
	previous.tooltip_text = "Previous tracks"
	navigation.add_child(previous)
	var hint := Label.new()
	hint.text = "SCROLL FOR MORE TRACKS"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", int(18 * s))
	navigation.add_child(hint)
	var next := UniloopUI.chunky_button(">", int(30 * s), Vector2(56, 48) * s)
	next.name = "Next"
	next.tooltip_text = "More tracks"
	navigation.add_child(next)
	var bar := scroll.get_h_scroll_bar()
	var update_arrows := func(_value := 0.0) -> void:
		previous.disabled = bar.value <= bar.min_value
		next.disabled = bar.value >= bar.max_value - bar.page - 1.0
	bar.value_changed.connect(update_arrows)
	bar.changed.connect(update_arrows)
	previous.pressed.connect(func() -> void: scroll.scroll_horizontal -= roundi(288 * s))
	next.pressed.connect(func() -> void: scroll.scroll_horizontal += roundi(288 * s))
	for i in cards.size():
		var card := cards[i]
		card.focus_neighbor_left = card.get_path_to(cards[maxi(0, i - 1)])
		card.focus_neighbor_right = card.get_path_to(cards[mini(cards.size() - 1, i + 1)])
		card.focus_neighbor_top = card.get_path()
		card.focus_neighbor_bottom = card.get_path_to(back_btn)
		card.focus_entered.connect(func() -> void: back_btn.focus_neighbor_top = back_btn.get_path_to(card))
	back_btn.focus_neighbor_top = back_btn.get_path_to(cards[selected])
	scroll.ensure_control_visible.call_deferred(cards[selected])
	cards[selected].grab_focus()


func _record_text(track_id: String) -> String:
	var record: Dictionary = save.records.get(track_id, {})
	if record.is_empty():
		return "NO TIME YET"
	return "BEST %s  %s" % [_format_time(int(record.best_ms)), String(record.get("medal", "none")).to_upper()]


func _format_time(ms: int) -> String:
	return "%d:%05.2f" % [ms / 60000, fmod(float(ms), 60000.0) / 1000.0]


func _on_track_picked(index: int) -> void:
	RaceSetup.track_id = RaceSetup.TRACKS[index].id
	if auto_launch:
		get_tree().change_scene_to_file(PRACTICE_SCENE)


# --- League ----------------------------------------------------------------------

func _build_league() -> void:
	panel_title.text = "LEAGUE"
	var s := _ui_scale()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", int(48 * s))
	grid.add_theme_constant_override("v_separation", int(10 * s))
	panel_body.add_child(grid)
	for head in ["TRACK", "BEST TIME", "MEDAL", "GOLD TIME"]:
		grid.add_child(UniloopUI.chunky_label(head, int(26 * s), UniloopUI.POP_PINK))
	var medal_colors := {"gold": Color("ffd60a"), "silver": Color("d9e2ec"), "bronze": Color("e08a4f"), "none": Color("8d7fa6")}
	var medals := 0
	for t in RaceSetup.TRACKS:
		var record: Dictionary = save.records.get(t.id, {})
		var medal := String(record.get("medal", "none"))
		if medal != "none":
			medals += 1
		grid.add_child(UniloopUI.chunky_label(String(t.title).to_upper(), int(30 * s)))
		grid.add_child(UniloopUI.chunky_label(_format_time(int(record.best_ms)) if record.has("best_ms") else "--", int(30 * s), Color.WHITE))
		grid.add_child(UniloopUI.chunky_label(medal.to_upper() if medal != "none" else "--", int(30 * s), medal_colors.get(medal, Color.WHITE)))
		grid.add_child(UniloopUI.chunky_label(_format_time(int(t.medals.gold)), int(30 * s), Color("7df9ff")))
	var total := UniloopUI.chunky_label("TOTAL SCORE  %d     MEDALS  %d / %d" % [int(save.get("total_score", 0)), medals, RaceSetup.TRACKS.size()], int(32 * s), Color.WHITE)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_body.add_child(total)


# --- Options and help ------------------------------------------------------------

func _build_options() -> void:
	panel_title.text = "OPTIONS"
	var settings := SaveStore.get_settings(save)
	var how := UniloopUI.chunky_button("HOW TO PLAY", int(30 * _ui_scale()))
	how.name = "HowToPlay"
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.pressed.connect(_open.bind("help"))
	panel_body.add_child(how)
	for spec in [["High Contrast Mode", settings.high_contrast, _on_high_contrast_toggled],
			["Reduced Camera Shake", settings.reduced_shake, _on_reduced_shake_toggled],
			["On-Screen Touch Buttons", settings.touch_overlay, _on_touch_overlay_toggled]]:
		var check := CheckButton.new()
		check.text = spec[0]
		check.button_pressed = spec[1]
		check.focus_mode = Control.FOCUS_ALL
		check.toggled.connect(spec[2])
		panel_body.add_child(check)

	var scale_label := Label.new()
	scale_label.text = "Text Scale:"
	panel_body.add_child(scale_label)
	var scale_box := HBoxContainer.new()
	for sc in SaveStore.TEXT_SCALES:
		var sbtn := UniloopUI.button(str(int(sc * 100)) + "%", 70)
		sbtn.pressed.connect(_on_text_scale_pressed.bind(sc))
		scale_box.add_child(sbtn)
	panel_body.add_child(scale_box)

	for spec in [["Master", "audio_master"], ["Music", "audio_music"], ["Sound Effects", "audio_sfx"]]:
		var vol_label := Label.new()
		vol_label.text = "%s Volume: %d%%" % [spec[0], int(settings[spec[1]])]
		panel_body.add_child(vol_label)
		var slider := HSlider.new()
		slider.name = spec[1]
		slider.min_value = 0
		slider.max_value = 100
		slider.value = float(settings[spec[1]])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(120, 32)
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(_on_volume_changed.bind(vol_label, spec[1], spec[0]))
		panel_body.add_child(slider)

	var rebind_hdr := Label.new()
	rebind_hdr.text = "Keyboard Remap (press a button, then any key):"
	rebind_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(rebind_hdr)
	var rebind_grid := GridContainer.new()
	rebind_grid.columns = 2
	for action in UniloopUI.ACTIONS:
		var lbl := Label.new()
		lbl.text = String(action).capitalize()
		rebind_grid.add_child(lbl)
		var b := UniloopUI.button(UniloopUI.prompt(action, "keyboard"))
		b.pressed.connect(_on_rebind_pressed.bind(action, b))
		rebind_grid.add_child(b)
	panel_body.add_child(rebind_grid)


func _on_high_contrast_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"high_contrast": enabled})
	SaveStore.save_to_path(save, save_path)
	_refresh_theme()


func _on_reduced_shake_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"reduced_shake": enabled})
	SaveStore.save_to_path(save, save_path)


func _on_touch_overlay_toggled(enabled: bool) -> void:
	SaveStore.set_settings(save, {"touch_overlay": enabled})
	SaveStore.save_to_path(save, save_path)


func _on_text_scale_pressed(scale: float) -> void:
	SaveStore.set_settings(save, {"text_scale": scale})
	SaveStore.save_to_path(save, save_path)
	_refresh_theme()


func _on_volume_changed(value: float, label: Label, key: String, caption: String) -> void:
	SaveStore.set_settings(save, {key: int(value)})
	SaveStore.save_to_path(save, save_path)
	label.text = "%s Volume: %d%%" % [caption, int(value)]
	UniloopUI.apply_audio(SaveStore.get_settings(save))


func _on_rebind_pressed(action: StringName, button: Button) -> void:
	button.text = "Press any key..."
	remapping_action = action


func _build_help() -> void:
	panel_title.text = "HOW TO PLAY"
	var lines: Array[String] = [
		"RACE GOAL: Ride the rail through every numbered gate in order. The course zig-zags upward: U-turn helixes and vertical launches flip your direction, so follow the arrows.",
		"TRACK COLORS: Blue/green = normal rail. Red/blue = loops, U-turns and launches ahead. Neon Night uses cyan/lime and pink/violet instead. Red/yellow = jumps, kickers, pitfalls and goo.",
		"FORKS: The rail splits at a junction into two long routes with different obstacles. Hold Up to take the upper rail, or stay low. Your call.",
		"MUD / GOO: Brown mud in Canyon Ribbon and green slime on other tracks are forward-only - no brakes, no reverse, no hops, just a slow crawl. Hit the kicker before it at full speed and hop to sail over.",
		"ROCKET BUMPS: Watch for a short steep curl at the end of a straight. Hit it at speed and it fires you sky-high - hop just before it to skim over.",
		"ONE-WAY RAILS: You can launch up through the underside of a rail and land on top of it. Fall off and you drop to the rail below - ride back up to where you were.",
		"STUNTS (in the air): Flip = backward 360, Roll = forward 360, Twist = 180 spin, Z-Flip = seat to the ground, Tabletop = hold the stunt button. Land clean for +500 per trick and a speed boost.",
		"WIPEOUTS: Land tilted, mid-twist, mid-z-flip or still in a tabletop and you crash: -250 points and a short stop while you recover.",
		"BOOST PADS: Orange pads give a burst of speed - you need it for loops and launches.",
		"SUNNY SIGNATURE - TRAMPOLINE: Ride onto the golden spring pad for a high trick arc. Finish your spins and land level. It cannot bounce again until you leave its footprint.",
		"CANYON SIGNATURE - BEAM CORKSCREW: Optional! Hold %s (touch: Flip) to enter. Hold %s or %s (touch: Flip/Roll) to build speed around the beam. A pumped run beats the straight rail; without pumping you slow and may fall. Hop on top to exit early, or finish two turns for an automatic top exit. Hopping at the side or underneath drops you to your last checkpoint." % [UniloopUI.prompt(&"flip_back", current_device), UniloopUI.prompt(&"flip_back", current_device), UniloopUI.prompt(&"roll_forward", current_device)],
		"NEON SIGNATURE - FLUX GATE: Hold %s (touch: Brake) through the glowing block to turn its charge into a speed burst. An unbraked hit drains 75%% of speed and clears your boost. Hop over to avoid it." % UniloopUI.prompt(&"brake", current_device),
		"GOO SIGNATURE - BINDING BUBBLE: Hop over the striped slime sphere, or it holds you still for 0.8 seconds before popping and releasing you at goo crawl speed.",
		"MONOPOLY SIGNATURE - QUOTA CRATE: Smash the strapped crate at a cost of 45% speed, or hop over to keep momentum. Red apples remain separate, once-per-race 100-point bonuses.",
		"SIGNATURE RECOVERY: The gate, bubble and crate clear after one hit per race, even across checkpoint resets. Springs and corkscrews can be retried. Pause freezes every mechanic; restart rebuilds the course.",
		"CONTROLS:",
		"  Ride left / right:  %s / %s (in the air: twist)" % [UniloopUI.prompt(&"move_left", current_device), UniloopUI.prompt(&"move_right", current_device)],
		"  Flip / Roll:        %s / %s" % [UniloopUI.prompt(&"flip_back", current_device), UniloopUI.prompt(&"roll_forward", current_device)],
		"  Hop / Pump:         %s" % UniloopUI.prompt(&"jump", current_device),
		"  Brake:              %s" % UniloopUI.prompt(&"brake", current_device),
		"  Z-Flip:             %s / %s" % [UniloopUI.prompt(&"zflip_left", current_device), UniloopUI.prompt(&"zflip_right", current_device)],
		"  Tabletop:           %s" % UniloopUI.prompt(&"tabletop", current_device),
		"  Pause/Menu:         %s" % UniloopUI.prompt(&"pause", current_device),
		"ACCESSIBILITY: High-contrast mode, text scaling up to 150%, reduced motion, and full remapping are in Options. Reduced Camera Shake also freezes Neon Night's background lights.",
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel_body.add_child(lbl)


# --- Drawn widgets ----------------------------------------------------------------

## A cartoon unicycle in the picked colours; spins its wheel when focused.
class UniIcon extends Control:
	var frame := Color.YELLOW
	var seat := Color.BLACK
	var wheel_angle := 0.0

	func spin() -> void:
		var t := create_tween()
		t.tween_property(self, "wheel_angle", wheel_angle + TAU, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := minf(size.x * 0.5, size.y) * 0.36
		var hub := Vector2(size.x * 0.5, size.y - r - 4.0)
		var ink := UniloopUI.INK
		var seat_at := hub + Vector2(r * 0.45, -r * 2.25)
		var w := maxf(4.0, r * 0.2)
		draw_circle(hub, r + 3.0, ink)
		draw_circle(hub, r, Color(0.12, 0.12, 0.14))
		draw_circle(hub, r * 0.74, Color(0.82, 0.84, 0.9))
		draw_circle(hub, r * 0.64, Color(0.2, 0.12, 0.3))
		for k in 8:
			var a := wheel_angle + k * TAU / 8.0
			draw_line(hub, hub + Vector2(cos(a), sin(a)) * r * 0.64, Color(0.85, 0.87, 0.92), maxf(1.5, r * 0.04))
		var crank := Vector2(cos(wheel_angle), sin(wheel_angle)) * r * 0.42
		draw_line(hub - crank, hub + crank, ink, w * 0.7)
		draw_line(hub, seat_at, ink, w + 6.0)
		draw_line(hub, seat_at, frame, w)
		draw_circle(hub, w * 0.8, ink)
		draw_circle(hub, w * 0.55, frame.lightened(0.3))
		var seat_poly := PackedVector2Array()
		for k in 16:
			var a := PI + k * PI / 15.0
			seat_poly.append(seat_at + Vector2(cos(a) * r * 0.62, sin(a) * r * 0.28 - r * 0.05))
		var outline := PackedVector2Array()
		for p in seat_poly:
			outline.append(seat_at + (p - seat_at) * 1.18)
		draw_colored_polygon(outline, ink)
		draw_colored_polygon(seat_poly, seat)
		draw_line(seat_at + Vector2(-r * 0.4, -r * 0.18), seat_at + Vector2(r * 0.2, -r * 0.24), seat.lightened(0.45), maxf(2.0, r * 0.06))


## Three cartoon stars, `value` of them filled.
class StarBar extends Control:
	var value := 1

	func _draw() -> void:
		var r := minf(size.y * 0.5, size.x / 6.0)
		for i in 3:
			var c := Vector2(r + i * r * 2.0, size.y * 0.5)
			var pts := PackedVector2Array()
			var outer := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				var rr := r * (0.95 if k % 2 == 0 else 0.42)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
				outer.append(c + Vector2(cos(a), sin(a)) * (rr + 2.5))
			draw_colored_polygon(outer, UniloopUI.INK)
			draw_colored_polygon(pts, UniloopUI.POP_YELLOW if i < value else Color(0.3, 0.22, 0.4))
