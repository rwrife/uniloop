class_name WheelRider
extends CharacterBody3D
## Side-scrolling unicycle: rolls along the rail in the X/Y plane, keeps
## momentum over crests and spins freely in the air for flips.

@export var handling: WheelHandling
var speed := 0.0
var vertical_speed_before_landing := 0.0
## Landing tilt relative to the rail, in degrees.
var bank_angle := 0.0
var last_landing := ""
var last_flips := 0
var pump_queued := false
var auto_brake := false
var air_spin := 0.0
var _contact := false
var _wheel_spin := 0.0

func _ready() -> void:
	assert(handling != null)
	floor_snap_length = handling.floor_snap
	floor_max_angle = deg_to_rad(60.0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = handling.wheel_radius
	shape.shape = sphere
	add_child(shape)
	add_child(_build_wheel())
	add_child(_build_frame())

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = roughness
	return paint

func _part(mesh: Mesh, paint: Material, where: Vector3, angles := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = paint
	part.position = where
	part.rotation = angles
	return part

func _build_wheel() -> Node3D:
	var r := handling.wheel_radius
	var wheel := Node3D.new()
	wheel.name = "WheelPrimitive"
	var tire := TorusMesh.new()
	tire.inner_radius = r - 0.16
	tire.outer_radius = r
	wheel.add_child(_part(tire, _material(Color(0.05, 0.05, 0.06), 0.0, 0.8), Vector3.ZERO, Vector3(PI / 2.0, 0, 0)))
	var rim := CylinderMesh.new()
	rim.top_radius = r - 0.14
	rim.bottom_radius = r - 0.14
	rim.height = 0.05
	var rim_paint := _material(Color(0.85, 0.87, 0.9, 0.35), 0.8, 0.2)
	rim_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wheel.add_child(_part(rim, rim_paint, Vector3.ZERO, Vector3(PI / 2.0, 0, 0)))
	var spoke := BoxMesh.new()
	spoke.size = Vector3((r - 0.14) * 2.0, 0.05, 0.06)
	var steel := _material(Color(0.92, 0.92, 0.95), 0.9, 0.15)
	for k in 4:
		wheel.add_child(_part(spoke, steel, Vector3.ZERO, Vector3(0, 0, k * PI / 4.0)))
	var hub := SphereMesh.new()
	hub.radius = 0.11
	hub.height = 0.22
	wheel.add_child(_part(hub, steel, Vector3.ZERO))
	return wheel

func _build_frame() -> Node3D:
	var frame := Node3D.new()
	frame.name = "RiderPrimitive"
	var yellow := _material(Color(0.98, 0.85, 0.1), 0.5, 0.3)
	var fork := BoxMesh.new()
	fork.size = Vector3(0.08, 0.95, 0.08)
	for side in [-0.12, 0.12]:
		frame.add_child(_part(fork, yellow, Vector3(0, 0.45, side)))
	var crown := BoxMesh.new()
	crown.size = Vector3(0.12, 0.08, 0.34)
	frame.add_child(_part(crown, yellow, Vector3(0, 0.94, 0)))
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.045
	post.height = 0.6
	frame.add_child(_part(post, yellow, Vector3(0, 1.25, 0)))
	var seat := CapsuleMesh.new()
	seat.radius = 0.13
	seat.height = 0.8
	frame.add_child(_part(seat, _material(Color(0.06, 0.06, 0.07), 0.1, 0.5), Vector3(0.04, 1.6, 0), Vector3(0, 0, PI / 2.0 - 0.12)))
	return frame

func _physics_process(delta: float) -> void:
	var throttle := 0.0 if auto_brake else Input.get_action_strength(&"accelerate")
	var braking := auto_brake or Input.is_action_pressed(&"brake")
	var was_contact := _contact
	if _contact:
		var normal := get_floor_normal()
		var tangent := Vector3(normal.y, -normal.x, 0.0).normalized()
		speed -= handling.gravity * handling.slope_gravity * tangent.y * delta
		if throttle > 0.0:
			speed = move_toward(speed, maxf(speed, handling.max_speed), handling.acceleration * throttle * delta)
		elif braking:
			speed = move_toward(speed, -handling.reverse_speed, handling.brake * delta)
		else:
			speed = move_toward(speed, 0.0, handling.drag * delta)
		speed = clampf(speed, -handling.reverse_speed, handling.max_speed * handling.overspeed)
		velocity = tangent * speed
		rotation.z = lerp_angle(rotation.z, atan2(tangent.y, tangent.x), minf(1.0, delta * handling.align_rate))
		if Input.is_action_just_pressed(&"jump"):
			velocity += normal * handling.jump_speed
			_contact = false
	else:
		velocity.y -= handling.gravity * delta
		if throttle > 0.0:
			velocity.x = move_toward(velocity.x, maxf(velocity.x, handling.max_speed), handling.air_control * delta)
		elif braking:
			velocity.x = move_toward(velocity.x, 0.0, handling.air_control * delta)
		var spin := -Input.get_axis(&"lean_left", &"lean_right") * handling.spin_rate * delta
		rotation.z += spin
		air_spin += spin
		speed = velocity.x
		if Input.is_action_just_pressed(&"jump"):
			pump_queued = true
	velocity.z = 0.0
	var before_move := velocity
	move_and_slide()
	global_position.z = 0.0
	_contact = is_on_floor()
	if _contact and not was_contact:
		_land(before_move)
	elif was_contact and not _contact:
		air_spin = 0.0
	_wheel_spin -= speed / handling.wheel_radius * delta
	$WheelPrimitive.rotation.z = _wheel_spin

func _land(impact_velocity: Vector3) -> void:
	var normal := get_floor_normal()
	var tangent := Vector3(normal.y, -normal.x, 0.0).normalized()
	var slope := atan2(tangent.y, tangent.x)
	bank_angle = rad_to_deg(absf(wrapf(rotation.z - slope, -PI, PI)))
	vertical_speed_before_landing = impact_velocity.dot(normal)
	last_flips = int(absf(air_spin) / (TAU * 0.85))
	speed = impact_velocity.dot(tangent)
	if bank_angle > handling.crash_angle:
		speed *= handling.crash_speed_keep
		last_flips = 0
	elif pump_queued:
		speed += handling.pump_boost
	rotation.z = slope
	pump_queued = false
	air_spin = 0.0
	last_landing = "landed"

func reset_at(where: Vector3, heading: Vector3) -> void:
	global_position = where
	rotation = Vector3(0.0, 0.0, atan2(heading.y, heading.x))
	velocity = Vector3.ZERO
	speed = 0.0
	pump_queued = false
	auto_brake = false
	air_spin = 0.0
	_contact = false
	last_landing = ""
