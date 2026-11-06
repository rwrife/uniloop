class_name CourseFeature
extends Node3D
## A stunt stretch built into the rail: a springy bounce floor, an auto-ride
## spiral, an updraft fan, a slime catapult or a springboard over a gap. Each
## course owns one kind (Rooftop mixes them all) and repeats it after every
## checkpoint.

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
const FAN_RADIUS := 1.3
const FAN_DROP := 2.6
const CATAPULT_LENGTH := 24.0
const CATAPULT_FIRE := 14.0
const CATAPULT_SINK := 0.55
const CATAPULT_CRAWL := 3.0
const CATAPULT_GRIP := 110.0
const CATAPULT_SPEED := 50.0
const CATAPULT_KICK := 10.0
const SPRING_LENGTH := 14.0
const SPRING_DIP := 0.6
const SPRING_SWEET := 3.0
const SPRING_POP := 22.0
const SPRING_GAP := 16.0
const SPRING_DROP := 2.0
const LENGTHS := {"bounce": BOUNCE_LENGTH, "spiral": CORK_LENGTH, "updraft": UPDRAFT_SPAN, "catapult": CATAPULT_LENGTH, "springboard": SPRING_LENGTH}

var kind := ""
var anchor: Dictionary
var dir := 1
var length := 0.0
var _visual: Node3D
var _pad: MultiMesh
var _pad_y := PackedFloat32Array()
var _pad_v := PackedFloat32Array()
var _pad_basis := Basis.IDENTITY
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
		"catapult":
			_build_catapult()
		"springboard":
			_build_springboard()
	set_process(true)


func covers(sec: int, s: float) -> bool:
	return sec == anchor.sec and s >= anchor.s and s < anchor.s + length


## Depth the floor sinks under a wheel at `offset`; tapers to zero at the ends.
## Slime gets deeper and deeper until the catapult fires.
func sag(offset: float) -> float:
	if kind == "catapult":
		return CATAPULT_SINK * smoothstep(0.0, CATAPULT_FIRE, offset) if offset < CATAPULT_FIRE else 0.0
	if kind == "springboard":
		return SPRING_DIP * pow(clampf(offset / length, 0.0, 1.0), 3.0)
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


## The slime erupts: blobs fly up and a burst of droplets sprays out.
func fling(offset: float) -> void:
	if _pad == null:
		return
	for i in _pad_v.size():
		var d := (i + 0.5) * BOUNCE_SEGMENT - offset
		_pad_v[i] += 9.0 * exp(-d * d / 6.0)
	var burst := CPUParticles3D.new()
	burst.name = "SlimeBurst"
	burst.one_shot = true
	burst.amount = 14 if not _animate else 40
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.direction = Vector3(dir * 0.5, 1, 0)
	burst.spread = 50.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 9.0
	burst.gravity = Vector3(0, -18, 0)
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.4
	var drop := SphereMesh.new()
	drop.radius = 0.12
	drop.height = 0.24
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = _paint(Color("#7dff3a"), 0.6)
	burst.mesh = drop
	burst.position = Vector3(dir * offset, 0.2, 0)
	_visual.add_child(burst)
	burst.finished.connect(burst.queue_free)
	burst.emitting = true


## A springboard jump inside the last few metres of the plank pops way up.
func sweet_spot(offset: float) -> bool:
	return kind == "springboard" and offset >= length - SPRING_SWEET


## Board deflection at `x` with the wheel pressing at `at` (a cantilever bend).
func _bend(x: float, at: float) -> float:
	var shape := x * x * (3.0 * at - x) if x <= at else at * at * (3.0 * x - at)
	return -SPRING_DIP * shape / (2.0 * pow(length, 3.0))


## The plank whips up after launching a rider.
func flick() -> void:
	for i in _pad_v.size():
		var x := (i + 0.5) * BOUNCE_SEGMENT
		_pad_v[i] += 10.0 * x / length


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
				if kind == "springboard":
					target = _bend(x, _press_at)
				else:
					var d := x - _press_at
					target = -sag(x) * exp(-d * d / 2.5)
			_pad_v[i] += ((target - _pad_y[i]) * 160.0 - _pad_v[i] * 7.0) * delta
			_pad_y[i] += _pad_v[i] * delta
			var y := _pad_y[i] - 0.2
			if kind == "catapult" and _animate:
				y += sin(_clock * 3.0 + i * 0.7) * 0.04
			_pad.set_instance_transform(i, Transform3D(_pad_basis, Vector3(dir * x, y, 0)))
	if _blades != null and _animate:
		_blades.rotation.y = _clock * 14.0
		_place_streaks()


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
	var metal := _paint(Color("#3b4250"))
	var hanger := BoxMesh.new()
	hanger.size = Vector3(0.14, FAN_DROP - 0.5, 0.14)
	for side in [-1.0, 1.0]:
		_part(hanger, center + Vector3(side * FAN_RADIUS * 0.8, -0.5 - (FAN_DROP - 0.5) * 0.5, 0), metal)
	var ring := TorusMesh.new()
	ring.inner_radius = FAN_RADIUS - 0.12
	ring.outer_radius = FAN_RADIUS + 0.06
	ring.rings = 24
	ring.ring_segments = 8
	_part(ring, center + Vector3(0, -FAN_DROP, 0), metal).name = "Housing"
	var hub := SphereMesh.new()
	hub.radius = 0.25
	hub.height = 0.4
	_part(hub, center + Vector3(0, -FAN_DROP, 0), metal)
	_blades = Node3D.new()
	_blades.name = "Blades"
	_blades.position = center + Vector3(0, -FAN_DROP, 0)
	_visual.add_child(_blades)
	var blade := BoxMesh.new()
	blade.size = Vector3(FAN_RADIUS * 0.9, 0.05, 0.42)
	var steel := _paint(Color("#cfd8e3"))
	for i in 4:
		var part := MeshInstance3D.new()
		part.mesh = blade
		part.material_override = steel
		part.position = Vector3(cos(TAU * i / 4.0), 0, -sin(TAU * i / 4.0)) * FAN_RADIUS * 0.48
		part.rotation = Vector3(0.35, TAU * i / 4.0, 0)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blades.add_child(part)
	var streak := BoxMesh.new()
	streak.size = Vector3(0.07, 1.6, 0.07)
	var wind := _paint(Color("#e9fdff"), 1.2, 0.55)
	for i in 14:
		var holder := Node3D.new()
		holder.name = "Wind%d" % i
		holder.set_meta("spread", (i % 7 - 3.0) / 3.0)
		holder.set_meta("z", ((i * 5) % 3 - 1.0) * 0.5)
		holder.set_meta("phase", i * 1.37)
		var piece := MeshInstance3D.new()
		piece.mesh = streak
		piece.material_override = wind
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(piece)
		_visual.add_child(holder)
		_streaks.append(holder)
	_place_streaks()


## Wind streaks rise from the fan and fan out across the lift zone.
func _place_streaks() -> void:
	var center := Vector3(dir * length * 0.5, 0, 0)
	var rise_span := UPDRAFT_HEIGHT + FAN_DROP
	for holder in _streaks:
		var rise := fposmod(_clock * 9.0 + float(holder.get_meta("phase")) * 2.1, rise_span)
		var t := rise / rise_span
		var spread: float = holder.get_meta("spread")
		var sway := sin(_clock * 3.0 + float(holder.get_meta("phase"))) * 0.25 * t
		holder.position = center + Vector3(
				spread * (FAN_RADIUS * 0.7 + (length * 0.5 - FAN_RADIUS * 0.7) * t) + sway,
				rise - FAN_DROP, float(holder.get_meta("z")) * (1.0 + t))
		holder.scale = Vector3.ONE * (1.0 - t * 0.6)
		holder.visible = t < 0.95


func _build_catapult() -> void:
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 0.7
	blob.radial_segments = 12
	blob.rings = 6
	var paint := _paint(Color.WHITE, 0.45)
	paint.vertex_color_use_as_albedo = true
	paint.roughness = 0.1
	blob.material = paint
	_pad_basis = Basis.from_scale(Vector3(1.0, 0.8, 1.6))
	_pad = MultiMesh.new()
	_pad.transform_format = MultiMesh.TRANSFORM_3D
	_pad.use_colors = true
	_pad.mesh = blob
	var count := roundi(length / BOUNCE_SEGMENT)
	_pad.instance_count = count
	_pad_y.resize(count)
	_pad_v.resize(count)
	for i in count:
		var shade := 0.85 + 0.15 * sin(i * 1.7)
		_pad.set_instance_color(i, Color("#5ee62a").lerp(Color("#b6ff5c"), shade - 0.7))
		_pad.set_instance_transform(i, Transform3D(_pad_basis, Vector3(dir * (i + 0.5) * BOUNCE_SEGMENT, -0.2, 0)))
	var pool := MultiMeshInstance3D.new()
	pool.name = "SlimePool"
	pool.multimesh = _pad
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(pool)
	var tub := BoxMesh.new()
	tub.size = Vector3(length, 0.5, 1.9)
	_part(tub, Vector3(dir * length * 0.5, -0.65, 0), _paint(Color("#2f5d1c")))
	var rim := BoxMesh.new()
	rim.size = Vector3(0.35, 0.8, 2.0)
	var dark := _paint(Color("#1f3d12"))
	for x in [0.0, length]:
		_part(rim, Vector3(dir * x, -0.35, 0), dark)
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.9, 0.7, 0.1)
	var marker := _part(arrow, Vector3(dir * CATAPULT_FIRE, -0.1, 1.05), _paint(Color("#d9ff4a"), 1.0))
	marker.rotation.z = -PI / 2.0 * dir

func _build_springboard() -> void:
	var plank := BoxMesh.new()
	plank.size = Vector3(BOUNCE_SEGMENT * 1.04, 0.22, 1.2)
	var paint := _paint(Color.WHITE, 0.3)
	paint.vertex_color_use_as_albedo = true
	plank.material = paint
	_pad = MultiMesh.new()
	_pad.transform_format = MultiMesh.TRANSFORM_3D
	_pad.use_colors = true
	_pad.mesh = plank
	var count := roundi(length / BOUNCE_SEGMENT)
	_pad.instance_count = count
	_pad_y.resize(count)
	_pad_v.resize(count)
	for i in count:
		var tip := (i + 0.5) * BOUNCE_SEGMENT >= length - SPRING_SWEET
		_pad.set_instance_color(i, Color("#ffd23f") if tip else (Color("#3fa9ff") if (i / 3) % 2 == 0 else Color("#8fd0ff")))
		_pad.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(dir * (i + 0.5) * BOUNCE_SEGMENT, -0.2, 0)))
	var board := MultiMeshInstance3D.new()
	board.name = "Springboard"
	board.multimesh = _pad
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(board)
	var base := BoxMesh.new()
	base.size = Vector3(2.0, 2.4, 1.6)
	_part(base, Vector3(dir * 1.0, -1.5, 0), _paint(Color("#24324a")))
	var coil := TorusMesh.new()
	coil.inner_radius = 0.16
	coil.outer_radius = 0.3
	coil.rings = 8
	coil.ring_segments = 8
	var steel := _paint(Color("#e4e9f2"))
	for y in [-0.5, -0.75, -1.0, -1.25]:
		_part(coil, Vector3(dir * length * 0.45, y, 0), steel)