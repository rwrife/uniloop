class_name CourseSignature
extends Node3D
## One authored mechanic on a flat, checkpoint-backed runway. Rider contacts
## use the same primitive dimensions as the query collider, with swept tests.

const TRAMPOLINE_SPEED := 28.0
const CORK_LENGTH := 72.0
const CORK_RADIUS := 2.0
const CORK_TURNS := 2.0
const CORK_MIN_SPEED := 12.0
const CORK_MAX_SPEED := 64.0
const CORK_PUMP := 26.0
const CORK_COAST_DRAG := 6.0
const BIND_SECONDS := 0.8

var kind := ""
var anchor: Dictionary
var spent := false
var volume := AABB()
var _solid: Node3D
var _collider: CollisionShape3D


func populate(course: CanyonCourse, spot: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	kind = course.track.signature.id
	anchor = spot
	position = anchor.pos
	_solid = Node3D.new()
	_solid.name = "Mechanism"
	add_child(_solid)
	match kind:
		"trampoline":
			volume = AABB(Vector3(-2.5, 0.0, -1.6), Vector3(5.0, 0.16, 3.2))
			_box(volume.size, volume.get_center(), Color("#ffba32"))
			for x in [-2.0, 2.0]:
				for z in [-1.2, 1.2]:
					var spring := TorusMesh.new()
					spring.inner_radius = 0.16
					spring.outer_radius = 0.24
					spring.rings = 8
					spring.ring_segments = 8
					for y in [-0.2, -0.4, -0.6]:
						_part(spring, Vector3(x, y, z), Color("#e4e9f2"))
		"corkscrew":
			_build_corkscrew()
		"flux_gate":
			volume = AABB(Vector3(-0.5, 0.0, -1.3), Vector3(1.0, 1.6, 2.6))
			_box(volume.size, volume.get_center(), Color("#ff24c8"), 0.7)
			for z in [-1.4, 1.4]:
				_box(Vector3(0.4, 2.0, 0.25), Vector3(0, 1, z), Color("#00efff"), 0.6)
		"binding_bubble":
			volume = AABB(Vector3(-0.85, 0.0, -0.85), Vector3(1.7, 1.7, 1.7))
			var bubble := SphereMesh.new()
			bubble.radius = 0.85
			bubble.height = 1.7
			bubble.radial_segments = 16
			bubble.rings = 8
			_part(bubble, volume.get_center(), Color("#75c51b"))
			for y in [0.5, 0.85, 1.2]:
				_box(Vector3(1.0, 0.08, 0.1), Vector3(0, y, 0.8), Color("#273b16"))
		"quota_crate":
			volume = AABB(Vector3(-1.0, 0.0, -1.2), Vector3(2.0, 1.6, 2.4))
			_box(volume.size, volume.get_center(), Color("#b88954"))
			for x in [-0.75, 0.75]:
				_box(Vector3(0.16, 1.7, 2.5), Vector3(x, 0.8, 0), Color("#ece7d9"))
			_box(Vector3(2.1, 0.16, 2.5), Vector3(0, 0.8, 0), Color("#ece7d9"))
		_:
			assert(false, "Unknown course signature: %s" % kind)
	if kind != "corkscrew":
		_add_collider()
	var sign := Label3D.new()
	sign.name = "SignatureSign"
	sign.text = "%s\n%s" % [course.track.signature.name, course.track.signature.hint]
	sign.position = Vector3(-9.0, 5.5, 0.0)
	sign.font_size = 48
	sign.pixel_size = 0.035
	sign.outline_size = 10
	sign.no_depth_test = false
	add_child(sign)


func _part(mesh: Mesh, at: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.25
	paint.roughness = 0.35
	if UniloopUI.uses_ios_compatibility():
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.emission_enabled = glow > 0.0
	paint.emission = color
	paint.emission_energy_multiplier = glow
	part.material_override = paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_solid.add_child(part)
	return part


func _box(size: Vector3, at: Vector3, color: Color, glow := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(mesh, at, color, glow)


func _add_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "SignatureCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	_collider = CollisionShape3D.new()
	_collider.position = volume.get_center()
	if kind == "binding_bubble":
		var sphere := SphereShape3D.new()
		sphere.radius = volume.size.x * 0.5
		_collider.shape = sphere
	else:
		var box := BoxShape3D.new()
		box.size = volume.size
		_collider.shape = box
	body.add_child(_collider)


func _build_corkscrew() -> void:
	var beam := CylinderMesh.new()
	beam.top_radius = 0.55
	beam.bottom_radius = 0.55
	beam.height = CORK_LENGTH
	beam.radial_segments = 12
	var core := _part(beam, Vector3(CORK_LENGTH * 0.5, -CORK_RADIUS, 0), Color("#656b77"))
	core.rotation.z = PI / 2.0
	var points := PackedVector3Array()
	for i in 97:
		var offset := CORK_LENGTH * i / 96.0
		points.append(cork_sample(offset, 0.0).pos - anchor.pos)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.18
	tube.bottom_radius = 0.18
	tube.height = 1.0
	tube.radial_segments = 8
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("#ffba32")
	paint.metallic = 0.35
	paint.roughness = 0.3
	if UniloopUI.uses_ios_compatibility():
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tube.material = paint
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = tube
	mesh.instance_count = points.size() - 1
	var faces := PackedVector3Array()
	for i in mesh.instance_count:
		var a := points[i]
		var b := points[i + 1]
		var t := (b - a).normalized()
		var x := t.cross(Vector3.UP).normalized()
		var z := x.cross(t).normalized()
		mesh.set_instance_transform(i, Transform3D(Basis(x, b - a, z), (a + b) * 0.5))
		# Query-only strip; attachment follows the analytic coil, never a mesh triangle.
		var side := x * 0.18
		faces.append_array([a - side, a + side, b + side, a - side, b + side, b - side])
	var coil := MultiMeshInstance3D.new()
	coil.name = "Coil"
	coil.multimesh = mesh
	coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_solid.add_child(coil)
	var body := StaticBody3D.new()
	body.name = "SignatureCollision"
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var core_shape := CylinderShape3D.new()
	core_shape.radius = 0.55
	core_shape.height = CORK_LENGTH
	var core_collider := CollisionShape3D.new()
	core_collider.shape = core_shape
	core_collider.position = core.position
	core_collider.rotation = core.rotation
	body.add_child(core_collider)
	_box(Vector3(1.0, 0.12, 2.0), Vector3.ZERO, Color("#ffba32"))
	_box(Vector3(1.0, 0.12, 2.0), Vector3(CORK_LENGTH, 0, 0), Color("#ffba32"))


func cork_ratio() -> float:
	return sqrt(1.0 + pow(TAU * CORK_TURNS * CORK_RADIUS / CORK_LENGTH, 2.0))


func cork_sample(offset: float, wheel_radius: float) -> Dictionary:
	offset = clampf(offset, 0.0, CORK_LENGTH)
	var angle := offset / CORK_LENGTH * TAU * CORK_TURNS
	var normal := Vector3(0, cos(angle), sin(angle))
	return {
		"pos": anchor.pos + Vector3(offset, -CORK_RADIUS, 0) + normal * (CORK_RADIUS + wheel_radius),
		"n": normal,
		"angle": angle,
	}


func enters(index: int, before: float, after: float) -> bool:
	return index == anchor.sec and before < anchor.s and after >= anchor.s


func clear_of_contact(where: Vector3, radius: float) -> bool:
	var local := to_local(where)
	if kind == "corkscrew":
		return local.x < -radius - 1.0 or local.x > CORK_LENGTH + radius + 1.0
	return absf(local.x) > volume.size.x * 0.5 + radius + 1.0 or absf(local.z) > volume.size.z * 0.5 + radius + 1.0


func sweep(from: Vector3, to: Vector3, radius: float) -> Dictionary:
	if spent or kind == "corkscrew":
		return {}
	var a := to_local(from)
	var b := to_local(to)
	var f := -1.0
	if kind == "trampoline":
		var top := volume.end.y + radius
		if b.y < a.y and a.y >= top and b.y <= top:
			f = _sphere_box_sweep(a, b, radius)
		elif absf(a.y - b.y) < 0.000001 and absf(a.y - radius) <= 0.2:
			f = _sphere_box_sweep(a, b, radius)
	elif kind == "binding_bubble":
		var center := volume.get_center()
		var d := b - a
		var start := a - center
		var r := volume.size.x * 0.5 + radius
		var c := start.length_squared() - r * r
		if c <= 0.0:
			f = 0.0
		elif d.length_squared() > 0.000001:
			var dot := start.dot(d)
			var discriminant := dot * dot - d.length_squared() * c
			if discriminant >= 0.0:
				f = (-dot - sqrt(discriminant)) / d.length_squared()
	else:
		f = _sphere_box_sweep(a, b, radius)
	if f < 0.0 or f > 1.0:
		return {}
	return {"f": f, "pos": from.lerp(to, f)}


func _sphere_box_sweep(a: Vector3, b: Vector3, radius: float) -> float:
	if _box_sweep(a, b, volume.grow(radius)) < 0.0:
		return -1.0
	# Distance to a box is quadratic between crossings of its face planes.
	# Solve each interval so rounded sphere/box corners do not create fake hits.
	var cuts: Array[float] = [0.0, 1.0]
	var travel := b - a
	for axis in 3:
		if absf(travel[axis]) > 0.000001:
			for plane in [volume.position[axis], volume.end[axis]]:
				var crossing: float = (plane - a[axis]) / travel[axis]
				if crossing > 0.0 and crossing < 1.0:
					cuts.append(crossing)
	cuts.sort()
	for i in cuts.size() - 1:
		var lo := cuts[i]
		var hi := cuts[i + 1]
		var midpoint := a.lerp(b, (lo + hi) * 0.5)
		var offset := Vector3.ZERO
		var motion := Vector3.ZERO
		for axis in 3:
			if midpoint[axis] < volume.position[axis]:
				offset[axis] = a[axis] - volume.position[axis]
				motion[axis] = travel[axis]
			elif midpoint[axis] > volume.end[axis]:
				offset[axis] = a[axis] - volume.end[axis]
				motion[axis] = travel[axis]
		if (offset + motion * lo).length_squared() <= radius * radius:
			return lo
		var aa := motion.length_squared()
		var bb := offset.dot(motion)
		var cc := offset.length_squared() - radius * radius
		var discriminant := bb * bb - aa * cc
		if aa > 0.000001 and discriminant >= 0.0:
			var root := (-bb - sqrt(discriminant)) / aa
			if root >= lo and root <= hi:
				return root
	return -1.0


func _box_sweep(a: Vector3, b: Vector3, box: AABB) -> float:
	var enter := 0.0
	var leave := 1.0
	for axis in 3:
		var d := b[axis] - a[axis]
		if absf(d) < 0.000001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return -1.0
		else:
			var t0 := (box.position[axis] - a[axis]) / d
			var t1 := (box.end[axis] - a[axis]) / d
			enter = maxf(enter, minf(t0, t1))
			leave = minf(leave, maxf(t0, t1))
			if enter > leave:
				return -1.0
	return enter


func spend(clear_visual := true) -> void:
	spent = true
	if clear_visual:
		clear()
	_collider.set_deferred("disabled", true)


func clear() -> void:
	_solid.hide()
