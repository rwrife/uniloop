class_name CanyonCourse
extends Node3D
## Authored centerline, baked ribbon collision, and sequential gate triggers.

const POINTS: Array[Vector3] = [
	Vector3(0, 0, 5), Vector3(0, 0, -13), Vector3(3, 1, -31),
	Vector3(11, 2, -49), Vector3(14, 2, -65), Vector3(9, 1, -82),
	Vector3(0, 0, -101), Vector3(-9, 0, -119), Vector3(-12, 1, -138),
	Vector3(-5, 2, -156), Vector3(0, 1, -176),
]
const WIDTH := 7.0
const GATES: Array[int] = [2, 4, 6, 8]
const FINISH_INDEX := 10
const MEDALS := {"gold": 24000, "silver": 33000, "bronze": 46000}
const RIBBON_STEPS := 12

var gate_areas: Array[Area3D] = []
var finish_area: Area3D

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(POINTS.size() - 1):
		for step in range(RIBBON_STEPS):
			var a := float(step) / RIBBON_STEPS
			var b := float(step + 1) / RIBBON_STEPS
			_emit_quad(surface, i, a, b)
	surface.generate_normals()
	var ribbon := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.26, 0.19)
	material.roughness = 0.92
	ribbon.surface_set_material(0, material)
	var ground := StaticBody3D.new()
	ground.name = "RibbonCollision"
	var display := MeshInstance3D.new()
	display.name = "Ribbon"
	display.mesh = ribbon
	ground.add_child(display)
	var shape := CollisionShape3D.new()
	shape.shape = ribbon.create_trimesh_shape()
	# ponytail: two-sided collision prevents thin ribbon winding from dropping wheel;
	# replace with a thick authored track mesh when art passes review.
	shape.shape.backface_collision = true
	shape.name = "TrackCollider"
	ground.add_child(shape)
	add_child(ground)
	for i in GATES.size():
		gate_areas.append(_add_gate(GATES[i], "Checkpoint%d" % i, Color(0.1, 0.85, 0.75)))
	finish_area = _add_gate(FINISH_INDEX, "Finish", Color(1.0, 0.75, 0.15))
	_add_gate(0, "Start", Color(0.35, 0.65, 1.0)).monitoring = false

func _emit_quad(surface: SurfaceTool, segment: int, a: float, b: float) -> void:
	var p0 := _edge(segment, a, -1.0)
	var p1 := _edge(segment, a, 1.0)
	var p2 := _edge(segment, b, -1.0)
	var p3 := _edge(segment, b, 1.0)
	for point in [p0, p1, p2, p1, p3, p2]:
		surface.add_vertex(point)

func _edge(segment: int, t: float, side: float) -> Vector3:
	# Shared vertex edges avoid holes where straight ribbon segments bend.
	return _vertex_edge(segment, side).lerp(_vertex_edge(segment + 1, side), t)

func _vertex_edge(index: int, side: float) -> Vector3:
	var before := POINTS[max(0, index - 1)]
	var after := POINTS[min(POINTS.size() - 1, index + 1)]
	var right := (after - before).normalized().cross(Vector3.UP).normalized()
	var bank := sin(float(index) * 0.8) * 0.18
	return POINTS[index] + right * side * WIDTH * 0.5 + Vector3.UP * (side * bank)

func _add_gate(index: int, label: String, color: Color) -> Area3D:
	var gate := Area3D.new()
	gate.name = label
	gate.position = POINTS[index]
	gate.rotation.y = atan2(POINTS[min(index + 1, POINTS.size() - 1)].x - POINTS[index - 1 if index > 0 else 0].x,
		-(POINTS[min(index + 1, POINTS.size() - 1)].z - POINTS[index - 1 if index > 0 else 0].z))
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH - 0.4, 3.0, 1.0)
	collision.shape = box
	collision.position.y = 1.2
	gate.add_child(collision)
	var arch := MeshInstance3D.new()
	arch.position.y = 3.0
	var beam := BoxMesh.new()
	beam.size = Vector3(WIDTH, 0.3, 0.35)
	arch.mesh = beam
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.25
	paint.roughness = 0.35
	arch.material_override = paint
	gate.add_child(arch)
	add_child(gate)
	return gate

func heading(index: int) -> Vector3:
	return (POINTS[min(index + 1, POINTS.size() - 1)] - POINTS[index]).normalized()

func spawn_at(index: int, offset: float) -> Vector3:
	return POINTS[index] + heading(index) * offset + Vector3.UP * 1.8
