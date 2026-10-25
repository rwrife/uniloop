class_name CanyonCourse
extends Node3D
## Side-scrolling 2.5D course: an authored X/Y rail profile rendered as a
## striped 3D tube, with top-surface collision, jump gaps and sequential gates.

const POINTS: Array[Vector3] = [
	Vector3(-10, 0, 0), Vector3(40, 0, 0), Vector3(58, 3, 0), Vector3(64, 4, 0),
	Vector3(78, 2.5, 0), Vector3(100, 0, 0), Vector3(130, 0, 0), Vector3(148, 5, 0),
	Vector3(162, 6, 0), Vector3(180, 1, 0), Vector3(205, -2, 0), Vector3(228, 2, 0),
	Vector3(244, 6, 0), Vector3(258, 4.8, 0), Vector3(284, 0, 0), Vector3(310, 0, 0),
	Vector3(326, 4, 0), Vector3(340, 1, 0), Vector3(356, 5, 0), Vector3(372, 2, 0),
	Vector3(395, 0, 0), Vector3(420, -3, 0), Vector3(450, -3, 0), Vector3(470, 1, 0),
	Vector3(486, 0, 0), Vector3(515, -2, 0), Vector3(545, -2, 0), Vector3(610, -2, 0),
]
## Segment i (POINTS[i] -> POINTS[i + 1]) is left open as a jump gap.
const GAPS: Array[int] = [3, 12, 23]
const GATES: Array[int] = [1, 6, 14, 20]
const FINISH_INDEX := 26
const MEDALS := {"gold": 24000, "silver": 33000, "bronze": 46000}
const RAIL_RADIUS := 0.45
const STRIPE_LENGTH := 2.0
const COLLISION_HALF_DEPTH := 2.5
const STRIPE_COLORS: Array[Color] = [Color(0.86, 0.06, 0.12), Color(0.1, 0.16, 0.82)]
const BACKDROP_SHADER := """
shader_type spatial;
render_mode unshaded;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xy / 9.0;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	float h2 = hash(cell + 17.0);
	float tri = h > 0.5 ? step(f.x, f.y) : step(1.0 - f.x, f.y);
	float diamond = step(abs(f.x - 0.5) + abs(f.y - 0.5), 0.2 + 0.15 * h2) * step(0.45, h2);
	vec3 col = mix(vec3(0.42, 0.32, 0.30), vec3(0.50, 0.40, 0.37), tri);
	col = mix(col, vec3(0.35, 0.26, 0.27), diamond);
	col *= 0.85 + 0.15 * clamp(world_pos.y / 40.0 + 0.5, 0.0, 1.0);
	ALBEDO = pow(col, vec3(2.2));
}
"""

var gate_areas: Array[Area3D] = []
var finish_area: Area3D

func _ready() -> void:
	_build_rail()
	_build_collision()
	_build_backdrop()
	for i in GATES.size():
		gate_areas.append(_add_gate(GATES[i], "Checkpoint%d" % i, "%d" % (i + 1), Color(0.1, 0.85, 0.75)))
	finish_area = _add_gate(FINISH_INDEX, "Finish", "FINISH", Color(1.0, 0.8, 0.15))
	_add_gate(0, "Start", "", Color(0.35, 0.65, 1.0)).monitoring = false

func _built_segments() -> Array[int]:
	var segments: Array[int] = []
	for i in range(POINTS.size() - 1):
		if not GAPS.has(i):
			segments.append(i)
	return segments

func _build_rail() -> void:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.metallic = 0.3
	paint.roughness = 0.22
	var tube := CylinderMesh.new()
	tube.top_radius = RAIL_RADIUS
	tube.bottom_radius = RAIL_RADIUS
	tube.height = 1.0
	tube.radial_segments = 20
	tube.rings = 1
	tube.material = paint
	var joint := SphereMesh.new()
	joint.radius = RAIL_RADIUS
	joint.height = RAIL_RADIUS * 2.0
	joint.material = paint
	var stripes: Array[Transform3D] = []
	var joints := {}
	var drop := Vector3.DOWN * RAIL_RADIUS
	for i in _built_segments():
		var a := POINTS[i] + drop
		var b := POINTS[i + 1] + drop
		var length := a.distance_to(b)
		var count := maxi(1, roundi(length / STRIPE_LENGTH))
		var dir := (b - a) / length
		var axis := Basis(dir.cross(Vector3.BACK).normalized(), dir * (length / count), Vector3.BACK)
		for k in count:
			stripes.append(Transform3D(axis, a + dir * (length * (k + 0.5) / count)))
		joints[a] = true
		joints[b] = true
	var rail := MultiMeshInstance3D.new()
	rail.name = "Rail"
	rail.multimesh = _multimesh(tube, stripes, true)
	add_child(rail)
	var joint_transforms: Array[Transform3D] = []
	for point: Vector3 in joints:
		joint_transforms.append(Transform3D(Basis.IDENTITY, point))
	var caps := MultiMeshInstance3D.new()
	caps.name = "RailJoints"
	caps.multimesh = _multimesh(joint, joint_transforms, false)
	add_child(caps)

func _multimesh(mesh: Mesh, transforms: Array[Transform3D], striped: bool) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		multi.set_instance_color(i, (STRIPE_COLORS[i % 2] if striped else STRIPE_COLORS[1]).srgb_to_linear())
	return multi

func _build_collision() -> void:
	var faces := PackedVector3Array()
	var front := Vector3.BACK * COLLISION_HALF_DEPTH
	for i in _built_segments():
		var a := POINTS[i]
		var b := POINTS[i + 1]
		faces.append_array([a - front, a + front, b - front, a + front, b + front, b - front])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.name = "TrackCollider"
	collider.shape = shape
	var ground := StaticBody3D.new()
	ground.name = "RibbonCollision"
	ground.add_child(collider)
	add_child(ground)

func _build_backdrop() -> void:
	var start_x := POINTS[0].x
	var end_x := POINTS[POINTS.size() - 1].x
	var quad := QuadMesh.new()
	quad.size = Vector2(end_x - start_x + 400.0, 260.0)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = BACKDROP_SHADER
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = quad
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.position = Vector3((start_x + end_x) * 0.5, 20.0, -30.0)
	add_child(backdrop)

func _add_gate(index: int, node_name: String, text: String, color: Color) -> Area3D:
	var gate := Area3D.new()
	gate.name = node_name
	gate.position = POINTS[index]
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 7.0, 4.0)
	collision.shape = box
	collision.position.y = 2.5
	gate.add_child(collision)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.emission_enabled = true
	paint.emission = color * 0.35
	paint.metallic = 0.25
	paint.roughness = 0.35
	for part in [[Vector3(0.3, 6.4, 0.3), Vector3(0, 2.8, -1.6)], [Vector3(0.3, 0.3, 3.5), Vector3(0, 5.9, 0)]]:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		piece.mesh = mesh
		piece.position = part[1]
		piece.material_override = paint
		gate.add_child(piece)
	if text != "":
		var label := Label3D.new()
		label.text = text
		label.font_size = 96
		label.pixel_size = 0.012
		label.outline_size = 18
		label.modulate = color
		label.position = Vector3(0, 6.8, 0)
		gate.add_child(label)
	add_child(gate)
	return gate

func heading(index: int) -> Vector3:
	return (POINTS[min(index + 1, POINTS.size() - 1)] - POINTS[index]).normalized()

func spawn_at(index: int, offset: float) -> Vector3:
	return POINTS[index] + heading(index) * offset + Vector3.UP * 1.0

func out_of_bounds(where: Vector3) -> bool:
	return where.x < POINTS[0].x - 5.0 or where.x > POINTS[POINTS.size() - 1].x + 5.0
