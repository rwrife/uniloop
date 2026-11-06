class_name CourseFeature
extends Node3D
## A stunt stretch built into the rail: a springy bounce floor, an auto-ride
## spiral or an updraft fan. Courses scatter several of these along their legs.

const BOUNCE_LENGTH := 24.0
const BOUNCE_SAG := 0.35
const BOUNCE_MIN := 15.0
const BOUNCE_MAX := 22.0
const BOUNCE_GAIN := 5.0
const BOUNCE_HOP := 16.0
const BOUNCE_SEGMENT := 0.5
const CORK_LENGTH := 72.0
const CORK_RADIUS := 2.0
const CORK_TURNS := 2.0
const CORK_TUBE := 0.4
const CORK_MIN_SPEED := 16.0
const CORK_MAX_SPEED := 56.0
const CORK_PUMP := 22.0
const CORK_COAST := 3.0
const UPDRAFT_SPAN := 12.0
const UPDRAFT_HEIGHT := 10.0
const UPDRAFT_LIFT := 70.0
const UPDRAFT_MAX := 15.0
const UPDRAFT_KICK := 6.0
const LENGTHS := {"bounce": BOUNCE_LENGTH, "spiral": CORK_LENGTH, "updraft": UPDRAFT_SPAN}

var kind := ""
var anchor: Dictionary
var dir := 1
var length := 0.0
var _visual: Node3D
var _pad: MultiMesh
var _pad_y := PackedFloat32Array()
var _pad_v := PackedFloat32Array()
var _press_at := 0.0
var _press_time := 0.0
var _blades: Node3D
var _streaks: Array[Node3D] = []
var _clock := 0.0
var _animate := true


func populate(spot: Dictionary, feature_kind: String, heading: int, visual := true, animate := true) -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	kind = feature_kind
	anchor = spot
	dir = heading
	length = LENGTHS[kind]
	position = anchor.pos
	_animate = animate
	set_process(false)
	if not visual:
		return
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	match kind:
		"bounce":
			_build_bounce()
		"spiral":
			_build_spiral()
		"updraft":
			_build_updraft()
	set_process(true)


func covers(sec: int, s: float) -> bool:
	return sec == anchor.sec and s >= anchor.s and s < anchor.s + length


## Depth the floor sinks under a wheel at `offset`; tapers to zero at the ends.
func sag(offset: float) -> float:
	return BOUNCE_SAG * smoothstep(0.0, 2.0, offset) * smoothstep(0.0, 2.0, length - offset)


func bounce_speed(impact: float) -> float:
	return clampf(absf(impact) + BOUNCE_GAIN, BOUNCE_MIN, BOUNCE_MAX)


func press(offset: float) -> void:
	_press_at = offset
	_press_time = 0.1


func kick(offset: float) -> void:
	if _pad == null:
		return
	for i in _pad_v.size():
		var d := (i + 0.5) * BOUNCE_SEGMENT - offset
		_pad_v[i] -= 7.0 * exp(-d * d / 4.0)


func cork_ratio() -> float:
	return sqrt(1.0 + pow(TAU * CORK_TURNS * CORK_RADIUS / CORK_LENGTH, 2.0))


func cork_sample(offset: float, wheel_radius: float) -> Dictionary:
	offset = clampf(offset, 0.0, CORK_LENGTH)
	var angle := offset / CORK_LENGTH * TAU * CORK_TURNS
	var normal := Vector3(0, cos(angle), sin(angle))
	return {
		"pos": anchor.pos + Vector3(dir * offset, -CORK_RADIUS, 0) + normal * (CORK_RADIUS + wheel_radius),
		"n": normal,
		"angle": angle,
	}


func lifts(where: Vector3) -> bool:
	if kind != "updraft":
		return false
	var local: Vector3 = where - anchor.pos
	var along := local.x * dir
	return along >= 0.0 and along <= length and local.y >= -1.0 and local.y <= UPDRAFT_HEIGHT and absf(local.z) < 3.0


func _process(delta: float) -> void:
	_clock += delta
	if _pad != null:
		_press_time = maxf(0.0, _press_time - delta)
		for i in _pad_y.size():
			var x := (i + 0.5) * BOUNCE_SEGMENT
			var target := 0.0
			if _press_time > 0.0:
				var d := x - _press_at
				target = -sag(x) * exp(-d * d / 2.5)
			_pad_v[i] += ((target - _pad_y[i]) * 160.0 - _pad_v[i] * 7.0) * delta
			_pad_y[i] += _pad_v[i] * delta
			_pad.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(dir * x, _pad_y[i] - 0.2, 0)))
	if _blades != null and _animate:
		_blades.rotation.y = _clock * 14.0
		for i in _streaks.size():
			var rise := fposmod(_clock * 7.0 + i * 2.3, UPDRAFT_HEIGHT)
			_streaks[i].position.y = rise
			_streaks[i].scale = Vector3.ONE * (1.0 - rise / UPDRAFT_HEIGHT * 0.7)


func _paint(color: Color, glow := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(color, alpha)
	paint.metallic = 0.2
	paint.roughness = 0.35
	if UniloopUI.uses_ios_compatibility() or alpha < 1.0:
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.emission_enabled = glow > 0.0
	paint.emission = color
	paint.emission_energy_multiplier = glow
	return paint


func _part(mesh: Mesh, at: Vector3, paint: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = paint
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(part)
	return part


func _build_bounce() -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(BOUNCE_SEGMENT * 1.04, 0.4, 1.3)
	var paint := _paint(Color.WHITE, 0.35)
	paint.vertex_color_use_as_albedo = true
	slab.material = paint
	_pad = MultiMesh.new()
	_pad.transform_format = MultiMesh.TRANSFORM_3D
	_pad.use_colors = true
	_pad.mesh = slab
	var count := roundi(length / BOUNCE_SEGMENT)
	_pad.instance_count = count
	_pad_y.resize(count)
	_pad_v.resize(count)
	for i in count:
		_pad.set_instance_color(i, Color("#ff3fa4") if (i / 4) % 2 == 0 else Color("#ff9ad6"))
		_pad.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(dir * (i + 0.5) * BOUNCE_SEGMENT, -0.2, 0)))
	var floor_mesh := MultiMeshInstance3D.new()
	floor_mesh.name = "BounceFloor"
	floor_mesh.multimesh = _pad
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(floor_mesh)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.4, 0.9, 1.6)
	var dark := _paint(Color("#4a1440"))
	for x in [0.0, length]:
		_part(frame, Vector3(dir * x, -0.35, 0), dark)
	var spring := TorusMesh.new()
	spring.inner_radius = 0.14
	spring.outer_radius = 0.24
	spring.rings = 8
	spring.ring_segments = 8
	var steel := _paint(Color("#e4e9f2"))
	for x in range(2, int(length), 4):
		for y in [-0.55, -0.75, -0.95]:
			_part(spring, Vector3(dir * x, y, 0), steel)


func _build_spiral() -> void:
	var beam := CylinderMesh.new()
	beam.top_radius = 0.5
	beam.bottom_radius = 0.5
	beam.height = CORK_LENGTH
	beam.radial_segments = 12
	var core := _part(beam, Vector3(dir * CORK_LENGTH * 0.5, -CORK_RADIUS, 0), _paint(Color("#656b77")))
	core.rotation.z = PI / 2.0
	var points := PackedVector3Array()
	for i in 145:
		var offset := CORK_LENGTH * i / 144.0
		var angle := offset / CORK_LENGTH * TAU * CORK_TURNS
		points.append(Vector3(dir * offset, -CORK_RADIUS, 0) + Vector3(0, cos(angle), sin(angle)) * (CORK_RADIUS - CORK_TUBE))
	var tube := CylinderMesh.new()
	tube.top_radius = CORK_TUBE
	tube.bottom_radius = CORK_TUBE
	tube.height = 1.0
	tube.radial_segments = 10
	tube.material = _paint(Color("#ffba32"), 0.3)
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = tube
	mesh.instance_count = points.size() - 1
	for i in mesh.instance_count:
		var a := points[i]
		var b := points[i + 1]
		var t := (b - a).normalized()
		var x := t.cross(Vector3.UP).normalized()
		var z := x.cross(t).normalized()
		mesh.set_instance_transform(i, Transform3D(Basis(x, b - a, z), (a + b) * 0.5))
	var coil := MultiMeshInstance3D.new()
	coil.name = "Coil"
	coil.multimesh = mesh
	coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(coil)
	var ring := TorusMesh.new()
	ring.inner_radius = CORK_RADIUS - 0.15
	ring.outer_radius = CORK_RADIUS + 0.15
	ring.rings = 16
	ring.ring_segments = 8
	var trim := _paint(Color("#ff5a1f"), 0.6)
	for x in [0.0, CORK_LENGTH]:
		var hoop := _part(ring, Vector3(dir * x, -CORK_RADIUS, 0), trim)
		hoop.rotation.z = PI / 2.0


func _build_updraft() -> void:
	var center := Vector3(dir * length * 0.5, 0, 0)
	var housing := CylinderMesh.new()
	housing.top_radius = 2.2
	housing.bottom_radius = 2.4
	housing.height = 0.8
	housing.radial_segments = 20
	_part(housing, center + Vector3(0, -1.4, 0), _paint(Color("#3b4250")))
	_blades = Node3D.new()
	_blades.name = "Blades"
	_blades.position = center + Vector3(0, -0.95, 0)
	_visual.add_child(_blades)
	var blade := BoxMesh.new()
	blade.size = Vector3(4.0, 0.08, 0.6)
	var steel := _paint(Color("#cfd8e3"))
	for i in 3:
		var part := MeshInstance3D.new()
		part.mesh = blade
		part.material_override = steel
		part.rotation.y = PI * i / 3.0
		_blades.add_child(part)
	var column := CylinderMesh.new()
	column.top_radius = length * 0.5
	column.bottom_radius = length * 0.4
	column.height = UPDRAFT_HEIGHT
	column.radial_segments = 24
	column.cap_top = false
	column.cap_bottom = false
	_part(column, center + Vector3(0, UPDRAFT_HEIGHT * 0.5 - 1.0, 0), _paint(Color("#9ff3ff"), 0.4, 0.14)).name = "Column"
	var streak := BoxMesh.new()
	streak.size = Vector3(0.12, 1.4, 0.12)
	var wind := _paint(Color("#e9fdff"), 1.0, 0.6)
	for i in 6:
		var holder := Node3D.new()
		holder.position = center + Vector3((i - 2.5) * 1.6, i * 1.6, (i % 2) * 1.2 - 0.6)
		var piece := MeshInstance3D.new()
		piece.mesh = streak
		piece.material_override = wind
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(piece)
		_visual.add_child(holder)
		_streaks.append(holder)
