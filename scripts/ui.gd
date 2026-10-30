class_name UniloopUI
extends RefCounted
## Shared branded Controls, safe-area layout and device-aware prompts.

const BG := Color("0b1324")
const PANEL := Color("172740")
const CYAN := Color("51e1eb")
const WHITE := Color("f4faff")
const YELLOW := Color("ffec57")
const XBOX_ICON := {"A": "🅰", "B": "🅱", "X": "🆇", "Y": "🆈", "Menu": "☰"}
const ACTIONS := [&"move_left", &"move_right", &"flip_back", &"roll_forward", &"jump",
	&"brake", &"zflip_left", &"zflip_right", &"tabletop", &"pause"]


static func mode(size: Vector2i, touchscreen: bool) -> String:
	if not touchscreen:
		return "desktop"
	if size.x < size.y:
		return "phone_portrait" if size.x < 900 else "tablet"
	return "phone_landscape" if size.y < 700 else "tablet"


static func safe_margins(viewport_rect: Rect2i, safe_rect: Rect2i) -> Vector4i:
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4i(16, 16, 16, 16)
	return Vector4i(
		maxi(16, safe_rect.position.x - viewport_rect.position.x + 16),
		maxi(16, safe_rect.position.y - viewport_rect.position.y + 16),
		maxi(16, viewport_rect.end.x - safe_rect.end.x + 16),
		maxi(16, viewport_rect.end.y - safe_rect.end.y + 16))


static func uses_ios_compatibility() -> bool:
	# Godot's iOS simulator template uses Apple's software OpenGL renderer.
	return OS.has_feature("ios") and RenderingServer.get_current_rendering_method() == "gl_compatibility"


static func viewport_safe_rect(viewport: Viewport) -> Rect2i:
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2i()
	return Rect2i(viewport.get_screen_transform().affine_inverse() * Rect2(safe))


static func apply_safe_area(margin: MarginContainer, touchscreen: bool) -> void:
	var rect := Rect2i(Vector2i.ZERO, margin.get_viewport_rect().size)
	var safe := viewport_safe_rect(margin.get_viewport()) if touchscreen else rect
	var sides := safe_margins(rect, safe)
	for pair in [["margin_left", sides.x], ["margin_top", sides.y],
		["margin_right", sides.z], ["margin_bottom", sides.w]]:
		margin.add_theme_constant_override(pair[0], pair[1])


static func create_theme(settings: Dictionary) -> Theme:
	var t := Theme.new()
	var contrast := bool(settings.get("high_contrast", false))
	var scale := float(settings.get("text_scale", 1.0))
	var ink := WHITE
	var accent := YELLOW if contrast else CYAN
	var surface := Color.BLACK if contrast else PANEL
	for type in ["Button", "Label", "CheckButton", "OptionButton", "HSlider"]:
		t.set_color("font_color", type, ink)
		t.set_font_size("font_size", type, maxi(16, int(22 * scale)))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = surface if state != "pressed" else accent.darkened(0.55)
		box.border_color = accent if contrast or state == "hover" else Color("345875")
		box.set_border_width_all(3 if contrast else 2)
		box.set_corner_radius_all(12)
		box.set_content_margin_all(14)
		t.set_stylebox(state, "Button", box)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = accent
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(14)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_hover_color", "Button", accent)
	t.set_color("font_focus_color", "Button", accent)
	return t


const CHUNKY_FONT := preload("res://assets/fonts/Bangers-Regular.ttf")
const POP_YELLOW := Color("ffd60a")
const POP_PINK := Color("ff3fa4")
const POP_PURPLE := Color("2a0b4a")
const INK := Color("0d0418")


## Big outlined cartoon text (Bangers) for titles and the race countdown.
static func chunky_label(text: String, size: int, color := POP_YELLOW) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CHUNKY_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 12))
	return l


## Chunky arcade button: yellow outlined Bangers text on a bordered purple
## plate; hot-pink border when hovered or focused.
static func chunky_button(text: String, size: int, minimum := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = minimum
	style_chunky(b, size)
	return b


static func style_chunky(b: Control, size: int) -> void:
	if b is Button:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", CHUNKY_FONT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", POP_YELLOW)
	b.add_theme_color_override("font_hover_color", Color("fff3a0"))
	b.add_theme_color_override("font_focus_color", Color("fff3a0"))
	b.add_theme_color_override("font_pressed_color", Color("ff9f1c"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ff9f1c"))
	b.add_theme_color_override("font_disabled_color", Color("8d7fa6"))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", maxi(6, size / 4))
	var edge := maxi(4, size / 9)
	var looks := {
		"normal": [Color(0.17, 0.05, 0.31, 0.88), INK],
		"hover": [Color(0.27, 0.08, 0.46, 0.94), POP_PINK],
		"pressed": [Color(0.45, 0.12, 0.38, 0.96), POP_YELLOW],
		"disabled": [Color(0.14, 0.11, 0.2, 0.7), Color("3b3050")],
	}
	for state in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = looks[state][0]
		box.border_color = looks[state][1]
		box.set_border_width_all(edge)
		box.set_corner_radius_all(edge * 4)
		box.content_margin_left = size * 0.6
		box.content_margin_right = size * 0.6
		box.content_margin_top = size * 0.12
		box.content_margin_bottom = size * 0.12
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 2
		box.shadow_offset = Vector2(0, edge)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = POP_PINK
	focus.set_border_width_all(edge + 2)
	focus.set_corner_radius_all(edge * 4 + 4)
	focus.set_expand_margin_all(edge)
	b.add_theme_stylebox_override("focus", focus)


static func button(label: String, minimum_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(minimum_width, 56)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


static func prompt(action: StringName, device: String) -> String:
	var index := ACTIONS.find(action)
	if index < 0:
		return ""
	var pad := ["D-pad ←", "D-pad →", "D-pad ↑", "D-pad ↓"]
	var glyphs := {
		"keyboard": ["A / ←", "D / →", "W / ↑", "S / ↓", "Space", "Shift", "Q", "E", "X", "Esc"],
		"xbox": pad + ["A", "X", "LB", "RB", "Y", "Menu"],
		"playstation": pad + ["✕", "□", "L1", "R1", "△", "Options"],
		"nintendo": pad + ["B", "Y", "L", "R", "X", "+"],
		"touch": ["◀", "▶", "▲", "▼", "JUMP", "BRAKE", "L", "R", "STUNT", "PAUSE"],
	}
	if device == "keyboard":
		var keys: Array[String] = []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keys.append(OS.get_keycode_string(ev.physical_keycode))
		if keys.size() == 1:
			return keys[0]
	return glyphs.get(device, glyphs.keyboard)[index]


static func prompt_for_hint(action: StringName, device: String) -> String:
	var base := prompt(action, device)
	if device == "xbox":
		return XBOX_ICON.get(base, base)
	return base


static func controls_hint_lines(device: String) -> PackedStringArray:
	return PackedStringArray([
		"%s / %s  steer" % [prompt_for_hint(&"move_left", device), prompt_for_hint(&"move_right", device)],
		"%s  jump   %s  brake" % [prompt_for_hint(&"jump", device), prompt_for_hint(&"brake", device)],
		"%s / %s  z-flip   %s  stunt" % [prompt_for_hint(&"zflip_left", device), prompt_for_hint(&"zflip_right", device), prompt_for_hint(&"tabletop", device)],
		"%s  pause" % prompt_for_hint(&"pause", device),
	])


static func controls_hint_text(device: String) -> String:
	return "%s\n%s" % [mode_label(device), "\n".join(controls_hint_lines(device))]


static func mode_label(device: String) -> String:
	if is_gamepad_device(device):
		return "GAMEPAD"
	return "KEYBOARD" if device == "keyboard" else device.to_upper()


static func is_gamepad_device(device: String) -> bool:
	return device == "xbox" or device == "playstation" or device == "nintendo"


static func gamepad_type_from_name(name: String) -> String:
	var lowered := name.to_lower()
	if "playstation" in lowered or "dualshock" in lowered or "dualsense" in lowered:
		return "playstation"
	if "nintendo" in lowered or "switch" in lowered:
		return "nintendo"
	return "xbox"


static func connected_gamepad_type(preferred_device := -1) -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "keyboard"
	if preferred_device >= 0 and pads.has(preferred_device):
		return gamepad_type_from_name(Input.get_joy_name(preferred_device))
	return gamepad_type_from_name(Input.get_joy_name(int(pads[0])))


static func device_for(event: InputEvent) -> String:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return gamepad_type_from_name(Input.get_joy_name(event.device))
	return "keyboard"


static func apply_audio(settings: Dictionary) -> void:
	for name in ["Master", "Music", "SFX"]:
		var bus := AudioServer.get_bus_index(name)
		if bus < 0:
			continue
		var key: String = "audio_" + name.to_lower()
		var volume := float(settings.get(key, SaveStore.DEFAULT_SETTINGS[key])) / 100.0
		AudioServer.set_bus_volume_linear(bus, volume)
		AudioServer.set_bus_mute(bus, volume == 0.0)


static func is_menu_submit(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"jump"):
		return true
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A


static func is_menu_cancel(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(&"ui_cancel"):
		return true
	return event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B


static func activate_focused_control(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner()
	if not focused is BaseButton or not focused.is_visible_in_tree() or focused.disabled:
		return false
	var button := focused as BaseButton
	# Consume before callbacks: selecting a track can remove the current scene.
	viewport.set_input_as_handled()
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	button.pressed.emit()
	return true


static func restore_bindings(save: Dictionary) -> void:
	var bindings: Variant = save.get("bindings", {})
	if typeof(bindings) != TYPE_DICTIONARY:
		return
	for action in ACTIONS:
		var code: Variant = bindings.get(String(action))
		if typeof(code) == TYPE_INT and code >= 32 and code <= 4194400:
			# Keep default gamepad and at least one keyboard binding.
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey:
					InputMap.action_erase_event(action, ev)
			var key := InputEventKey.new()
			key.physical_keycode = code
			InputMap.action_add_event(action, key)


static func remap(save: Dictionary, action: StringName, event: InputEventKey) -> void:
	if action not in ACTIONS or event.physical_keycode == 0:
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var copy := InputEventKey.new()
	copy.physical_keycode = event.physical_keycode
	InputMap.action_add_event(action, copy)
	var bindings: Dictionary = save.get("bindings", {})
	bindings[String(action)] = event.physical_keycode
	save.bindings = bindings
