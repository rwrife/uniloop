class_name MonopolyApples
extends Node3D

signal squashed

const POINTS := 100
const RADIUS := 0.65
const RED := Color("#ff1826")
const LEAF_GREEN := Color("#4fae24")
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
	var fruit := _apple_mesh()
	var leaf_mesh := _leaf_mesh()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.045
	stem.bottom_radius = 0.065
	stem.height = 0.30
	stem.radial_segments = 6
	stem.material = _paint(Color("#61402d"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 150015
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
				if sample.pos.distance_to(course.signature.anchor.pos) < 12.0:
					clear = false
				if clear:
					var apple := Node3D.new()
					apple.name = "Apple%d" % remaining.size()
					apple.position = sample.pos + sample.n * 0.50
					var body := MeshInstance3D.new()
					body.name = "Fruit"
					body.mesh = fruit
					apple.add_child(body)
					var stalk := MeshInstance3D.new()
					stalk.name = "Stem"
					stalk.mesh = stem
					stalk.position = Vector3(0.0, 0.61, 0.0)
					stalk.rotation.z = -0.25
					apple.add_child(stalk)
					var leaf := MeshInstance3D.new()
					leaf.name = "Leaf"
					leaf.mesh = leaf_mesh
					leaf.position = Vector3(0.02, 0.66, 0.06)
					apple.add_child(leaf)
					add_child(apple)
					remaining.append(apple)
			distance += rng.randf_range(32.0, 62.0)


func _apple_mesh() -> ArrayMesh:
	# Radius/height profile: dimpled crown, full shoulders, and a slender tapered base.
	var profile: Array[Vector2] = [
		Vector2(0.0, 0.43), Vector2(0.18, 0.59), Vector2(0.35, 0.51),
		Vector2(0.43, 0.29), Vector2(0.42, 0.02), Vector2(0.35, -0.26),
		Vector2(0.23, -0.46), Vector2(0.08, -0.53), Vector2(0.0, -0.50),
	]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_smooth_group(0)
	for ring in profile.size() - 1:
		for side in 20:
			var angle_a := side * TAU / 20.0
			var angle_b := (side + 1) * TAU / 20.0
			var radial_a := Vector3(cos(angle_a), 0, sin(angle_a)) * (1.0 + 0.035 * cos(angle_a * 5.0))
			var radial_b := Vector3(cos(angle_b), 0, sin(angle_b)) * (1.0 + 0.035 * cos(angle_b * 5.0))
			var upper := profile[ring]
			var lower := profile[ring + 1]
			var a := radial_a * upper.x + Vector3.UP * upper.y
			var b := radial_b * upper.x + Vector3.UP * upper.y
			var c := radial_a * lower.x + Vector3.UP * lower.y
			var d := radial_b * lower.x + Vector3.UP * lower.y
			var vertices: Array[Vector3] = []
			if upper.x > 0.0:
				vertices.append_array([a, c, b])
			if lower.x > 0.0:
				vertices.append_array([b, c, d])
			for vertex in vertices:
				var radial := Vector3(vertex.x, 0, vertex.z).normalized()
				var shade := 0.72 + 0.28 * maxf(0.0, radial.dot(Vector3(-0.6, 0, 0.8)))
				builder.set_color(Color(shade, shade, shade))
				builder.add_vertex(vertex)
	builder.generate_normals()
	builder.index()
	var mesh := builder.commit()
	var material := _paint(RED)
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	return mesh


func _leaf_mesh() -> ArrayMesh:
	var outline: Array[Vector3] = [
		Vector3.ZERO, Vector3(0.16, 0.17, 0), Vector3(0.38, 0.22, 0),
		Vector3(0.60, 0.17, 0), Vector3(0.47, -0.02, 0), Vector3(0.22, -0.07, 0),
	]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		for vertex in [Vector3(0.29, 0.08, 0.05), outline[i], outline[(i + 1) % outline.size()]]:
			var shade := 1.0 if vertex.y >= 0.08 else 0.7
			builder.set_color(Color(shade, shade, shade))
			builder.add_vertex(vertex)
	builder.generate_normals()
	var mesh := builder.commit()
	var material := _paint(LEAF_GREEN)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	return mesh


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
