class_name UniloopUI
extends RefCounted
## Shared branded Controls, safe-area layout and device-aware prompts.

const BG := Color("0b1324")
const PANEL := Color("172740")
const CYAN := Color("51e1eb")
const WHITE := Color("f4faff")
const YELLOW := Color("ffec57")
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


static func apply_safe_area(margin: MarginContainer, touchscreen: bool) -> void:
	var rect := Rect2i(Vector2i.ZERO, margin.get_viewport_rect().size)
	var safe := DisplayServer.get_display_safe_area() if touchscreen else rect
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


static func button(label: String, minimum_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = label
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


static func device_for(event: InputEvent) -> String:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var name := Input.get_joy_name(event.device).to_lower()
		if "playstation" in name or "dualshock" in name or "dualsense" in name:
			return "playstation"
		if "nintendo" in name or "switch" in name:
			return "nintendo"
		return "xbox"
	return "keyboard"


static func apply_audio(settings: Dictionary) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_linear(bus, float(settings.get("audio_master", 80)) / 100.0)


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
