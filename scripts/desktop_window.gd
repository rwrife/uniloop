extends Node

const SCREEN_FRACTION := 0.75
const ASPECT := Vector2i(16, 9)


func _ready() -> void:
	var window := get_tree().root
	if not should_resize(OS.get_name(), DisplayServer.get_name(), window.mode):
		return
	if Engine.is_editor_hint() or Engine.is_embedded_in_editor():
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		push_error("Cannot size the desktop window: screen usable area is empty.")
		return
	window.size = initial_size(usable.size)
	window.position = centered_position(usable, window.size)


static func should_resize(platform: String, display: String, mode: Window.Mode) -> bool:
	return platform in ["Windows", "macOS"] and display != "headless" and mode == Window.MODE_WINDOWED


static func initial_size(usable_size: Vector2i) -> Vector2i:
	var units := int(floor(minf(
		usable_size.x * SCREEN_FRACTION / ASPECT.x,
		usable_size.y * SCREEN_FRACTION / ASPECT.y
	)))
	return ASPECT * units


static func centered_position(usable: Rect2i, window_size: Vector2i) -> Vector2i:
	return usable.position + (usable.size - window_size) / 2
