extends SceneTree
## One-shot layout screenshot capture: real windowed render under Xvfb.
##   xvfb-run -s "-screen 0 1600x1200x24" godot --headless? no: windowed run:
##   godot -s tools/capture_layouts.gd  (run under Xvfb, gl compatibility)
## Writes docs/screenshots/ui/*.png at real resolutions.

const MENU := preload("res://scenes/menu.tscn")
const OUT_DIR := "res://docs/screenshots/ui"
const LAYOUTS := [
	{"name": "menu_desktop_1920x1080", "size": Vector2i(1920, 1080), "view": "menu"},
	{"name": "menu_tablet_1024x768", "size": Vector2i(1024, 768), "view": "menu"},
	{"name": "menu_phone_portrait_390x844", "size": Vector2i(390, 844), "view": "menu"},
	{"name": "settings_desktop_1920x1080", "size": Vector2i(1920, 1080), "view": "settings"},
	{"name": "settings_phone_portrait_390x844", "size": Vector2i(390, 844), "view": "settings"},
	{"name": "pause_phone_landscape_844x390", "size": Vector2i(844, 390), "view": "pause"},
]


func _initialize() -> void:
	var err := DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if err != OK:
		push_error("cannot create %s: %s" % [OUT_DIR, error_string(err)])
		quit(1)
		# quit() defers; continue so _process never runs with bad state
		return
	_frames = 0
	_index = -1  # _process starts the pipeline once the window exists


var _frames := 0
var _index := -1
var _current: Control = null


func _run_current() -> void:
	if _index >= LAYOUTS.size():
		print("CAPTURES DONE")
		quit(0)
		return
	var spec: Dictionary = LAYOUTS[_index]
	root.size = spec.size
	_frames = 0
	await process_frame
	var menu: Control = MENU.instantiate()
	root.add_child(menu)
	_current = menu
	if spec.view == "settings":
		menu._open_settings()
	elif spec.view == "pause":
		menu.queue_free()
		var practice: Node3D = load("res://scenes/practice.tscn").instantiate()
		root.add_child(practice)
		practice._set_paused(true)
	_frames = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _index < 0:
		_index = 0
		_run_current()
		return false
	if _frames < 12:
		return false
	var spec: Dictionary = LAYOUTS[_index]
	# Verify primary interactions fit viewport, not merely that PNG bytes exist.
	var margin: Control = root.get_node_or_null("MainMenu/SafeMargin")
	if margin != null:
		var active: Control = margin.get_node("SubPanel") if spec.view == "settings" else margin.get_node("MainCard")
		var viewport_size: Vector2i = spec.size
		if active.global_position.x < -1 or active.global_position.y < -1 or active.global_position.x + active.size.x > viewport_size.x + 1 or active.global_position.y + active.size.y > viewport_size.y + 1:
			push_error("layout overflow: %s at %s size %s versus %s" % [spec.name, active.global_position, active.size, viewport_size])
			quit(1)
			return false
	elif spec.view == "pause":
		var panel := root.get_node_or_null("Practice/Hud/Root/PausePanel")
		if panel != null and panel.size.x > spec.size.x:
			push_error("pause layout wider than viewport: %s versus %s" % [panel.size, spec.size])
			quit(1)
			return false
	var image := root.get_texture().get_image()
	var path: String = OUT_DIR + "/" + spec.name + ".png"
	var err := image.save_png(path)
	if err != OK:
		push_error("save failed %s: %s" % [path, error_string(err)])
		quit(1)
		return false
	print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null
	for child in root.get_children():
		if child is Node3D:
			child.queue_free()
	_index += 1
	_run_current()
	return false
