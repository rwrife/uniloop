extends Node
## Opt-in local developer benchmark; never enabled during normal play.
var race: Node3D
var frames: Array[float] = []
var started := 0
var previous := 0
var draws := 0.0
var primitives := 0.0
var active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_begin.call_deferred()

func _begin() -> void:
	RaceSetup.track_id = "canyon_climb"
	get_tree().change_scene_to_file("res://scenes/practice.tscn")
	await get_tree().scene_changed
	race = get_tree().current_scene
	# Keep the benchmark isolated from the player's records.
	race.save_path = "user://benchmark-save.json"
	race._set_paused(false)
	started = Time.get_ticks_usec() + 5000000
	previous = started
	active = true

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(race):
		return
	if get_tree().paused:
		race._set_paused(false)
	var now := Time.get_ticks_usec()
	if now < started:
		return
	frames.append((now - previous) / 1000.0)
	previous = now
	draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var right: bool = race.rider.drive_dir >= 0
	Input.action_release(&"move_left" if right else &"move_right")
	Input.action_press(&"move_right" if right else &"move_left")
	if now - started >= 15000000:
		active = false
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		var sorted := frames.duplicate()
		sorted.sort()
		var report := {
			"fps": frames.size() * 1000000.0 / (now - started),
			"frames": frames.size(), "duration_s": (now - started) / 1000000.0,
			"p50_ms": sorted[sorted.size() / 2],
			"p95_ms": sorted[int(sorted.size() * 0.95)],
			"draw_calls": draws / frames.size(),
			"primitives": primitives / frames.size(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"track": RaceSetup.track_id,
		}
		var file := FileAccess.open("user://performance_probe.json", FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "  "))
		print("PERFORMANCE_PROBE ", JSON.stringify(report))
		race._set_paused(true)
