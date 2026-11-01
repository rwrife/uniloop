class_name GhostReplay
extends Node3D
## A visible rival with private mutable signature state. No player signals,
## pickups, collision or records. The race advances it once per active tick.
var rider: WheelRider
var course: CanyonCourse
var data: Dictionary
var cursor := 0
var checkpoint := 0
var completed := false
var diverged := false

func setup(run: Dictionary) -> void:
	data = run.duplicate(true)
	course = CanyonCourse.new()
	course.track_id = data.course
	course.reduced_motion = true
	course.simulation_only = true
	add_child(course)
	course.hide()
	course.set_process(false)
	rider = WheelRider.new()
	rider.handling = WheelHandling.new()
	rider.course = course
	rider.frame_color = Color("#7df9ff")
	rider.seat_color = Color("#c8faff")
	add_child(rider)
	rider.set_physics_process(false)
	rider.set_process_input(false)
	rider.collision_layer = 0
	var start := course.spawn(-1)
	rider.place_on(start.sec, start.s)
	for part in rider.find_children("*", "MeshInstance3D", true, false):
		part.transparency = 0.55
	var label := Label3D.new()
	label.text = "BEST GHOST"
	label.position.y = 3.5
	label.font_size = 32
	label.modulate = Color("#7df9ff")
	rider.add_child(label)

func advance() -> void:
	if completed or diverged or cursor >= data.frames.size():
		return
	var frame: Array = data.frames[cursor]
	var before := rider.global_position
	rider.step(frame)
	var here := rider.global_position
	if absf(rider.speed) >= rider.handling.gate_min_speed:
		if checkpoint < course.gates.size():
			if course.crossed(course.gates[checkpoint], before, here):
				checkpoint += 1
		elif course.crossed(course.finish, before, here):
			completed = true
	var fell := course.out_of_bounds(here) or (not rider.grounded and rider.air_time > rider.handling.air_timeout)
	if fell != (frame[10] != -2) or (fell and int(frame[10]) != checkpoint - 1):
		diverged = true
	if frame[10] != -2:
		var spot := course.spawn(int(frame[10]))
		rider.place_on(spot.sec, spot.s)
	cursor += 1
	if completed != (cursor == data.frames.size()):
		# Early finish or input exhaustion before the finish means stale physics.
		diverged = true
	if diverged or completed:
		hide()
