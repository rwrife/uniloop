class_name MonopolyApples
extends Node3D

signal squashed

const POINTS := 100
const RADIUS := 0.65
const RED := Color("#ff1826")
const SAUCE_COLORS := [Color("#ed1825"), Color("#ff5242"), Color("#ffc183")]

var remaining: Array[Node3D] = []
var reduced_motion := false
var _confetti_mesh: BoxMesh


func populate(course: CanyonCourse) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reduced_motion = course.reduced_motion
	_confetti_mesh = BoxMesh.new()
	_confetti_mesh.size = Vector3(0.16, 0.06, 0.12)
	var confetti_paint := _paint(Color.WHITE)
	confetti_paint.vertex_color_use_as_albedo = true
	_confetti_mesh.material = confetti_paint
	var fruit := SphereMesh.new()
	fruit.radius = 0.48
	fruit.height = 0.96
	fruit.radial_segments = 12
	fruit.rings = 6
	fruit.material = _paint(RED)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.045
	stem.bottom_radius = 0.065
	stem.height = 0.30
	stem.radial_segments = 6
	stem.material = _paint(Color("#61402d"))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in course.sections.size():
		var section: CanyonCourse.Section = course.sections[index]
		var distance := rng.randf_range(24.0, 48.0)
		while distance < section.length - 12.0:
			var sample := course.sample(index, distance)
			if sample.kind == CanyonCourse.NORMAL and sample.landable and sample.n.y > 0.85 and absf(sample.t.y) < 0.3:
				var clear := true
				for gate in course.gates + [course.start_spot, course.finish]:
					if sample.pos.distance_to(gate.pos) < 10.0:
						clear = false
						break
				if clear:
					var apple := Node3D.new()
					apple.name = "Apple%d" % remaining.size()
					apple.position = sample.pos + sample.n * 0.50
					for side in [-1.0, 1.0]:
						var lobe := MeshInstance3D.new()
						lobe.mesh = fruit
						lobe.position.x = side * 0.19
						lobe.scale = Vector3(1.0, 0.95, 0.95)
						apple.add_child(lobe)
					var stalk := MeshInstance3D.new()
					stalk.mesh = stem
					stalk.position = Vector3(0.0, 0.51, 0.0)
					stalk.rotation.z = -0.25
					apple.add_child(stalk)
					add_child(apple)
					remaining.append(apple)
			distance += rng.randf_range(32.0, 62.0)


func squash_between(from: Vector3, to: Vector3, wheel_radius: float) -> void:
	# Sweep the wheel, not just its end position, so boosted riders cannot skip fruit.
	var hit_radius := wheel_radius + RADIUS
	for i in range(remaining.size() - 1, -1, -1):
		var apple := remaining[i]
		var nearest := Geometry3D.get_closest_point_to_segment(apple.global_position, from, to)
		if nearest.distance_squared_to(apple.global_position) > hit_radius * hit_radius:
			continue
		remaining.remove_at(i)
		_burst(apple.global_position)
		apple.hide()
		apple.queue_free()
		squashed.emit()


func _burst(at: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.name = "ApplesauceConfetti"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 12 if reduced_motion else 40
	burst.lifetime = 0.6 if reduced_motion else 1.0
	burst.explosiveness = 1.0
	burst.local_coords = false
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 1.5 if reduced_motion else 3.0
	burst.initial_velocity_max = 3.0 if reduced_motion else 7.0
	burst.gravity = Vector3(0, -12, 0)
	burst.angular_velocity_min = -240.0
	burst.angular_velocity_max = 240.0
	var palette := Gradient.new()
	palette.set_color(0, SAUCE_COLORS[0])
	palette.set_color(1, SAUCE_COLORS[2])
	palette.add_point(0.5, SAUCE_COLORS[1])
	burst.color_initial_ramp = palette
	burst.mesh = _confetti_mesh
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(burst)
	burst.global_position = at
	burst.finished.connect(burst.queue_free)
	burst.emitting = true


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
