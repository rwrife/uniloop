class_name WheelRider
extends CharacterBody3D
## Contact-driven arcade wheel: throttle works airborne (pump), grip pulls
## velocity toward facing only as much as contact and banking allow.

@export var handling: WheelHandling
var speed := 0.0
var vertical_speed_before_landing := 0.0
var bank_angle := 0.0
var last_landing := ""
var pump_queued := false
var _contact := false
var _jumped := false

func _ready() -> void:
	assert(handling != null)
	floor_snap_length = handling.wheel_radius * 0.8
	floor_max_angle = deg_to_rad(55.0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = handling.wheel_radius
	shape.shape = sphere
	add_child(shape)
	var wheel := MeshInstance3D.new()
	wheel.name = "WheelPrimitive"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = handling.wheel_radius
	cylinder.bottom_radius = handling.wheel_radius
	cylinder.height = 0.25
	wheel.mesh = cylinder
	wheel.rotation.z = PI / 2.0
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.09, 0.13)
	rubber.metallic = 0.15
	rubber.roughness = 0.7
	wheel.material_override = rubber
	add_child(wheel)
	var rider := MeshInstance3D.new()
	rider.name = "RiderPrimitive"
	rider.position.y = 0.95
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	rider.mesh = capsule
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.9, 0.32, 0.08)
	paint.metallic = 0.4
	paint.roughness = 0.3
	rider.material_override = paint
	add_child(rider)

func _physics_process(delta: float) -> void:
	var airborne := not _contact
	var lean := Input.get_axis(&"lean_left", &"lean_right")
	var bank_bonus := 1.0 + absf(get_floor_normal().x) * handling.bank_grip_bonus if _contact else 0.35
	rotate_y(-lean * handling.turn_rate * bank_bonus * delta)
	bank_angle = lerpf(bank_angle, lean * 16.0, minf(1.0, delta * handling.grip))
	$RiderPrimitive.rotation.z = deg_to_rad(-bank_angle)

	# Throttle applies on the ground and in the air (pump); only grip differs.
	if Input.is_action_pressed(&"accelerate"):
		speed = move_toward(speed, handling.max_speed, handling.acceleration * delta)
	elif Input.is_action_pressed(&"brake"):
		speed = move_toward(speed, -handling.reverse_speed, handling.brake * delta)
	else:
		speed = move_toward(speed, 0.0, handling.drag * delta)
	if Input.is_action_just_pressed(&"jump"):
		if _contact:
			velocity.y = handling.jump_speed
			_contact = false
			_jumped = true
		else:
			pump_queued = true

	var desired := -global_basis.z * speed
	var grip_factor := handling.grip * bank_bonus if _contact else handling.grip * 0.12
	var step := grip_factor * delta * maxf(1.0, absf(speed))
	velocity.x = move_toward(velocity.x, desired.x, step)
	velocity.z = move_toward(velocity.z, desired.z, step)
	if airborne and not _jumped:
		velocity.y -= handling.gravity * delta
	vertical_speed_before_landing = velocity.y
	_jumped = false
	move_and_slide()
	var landed_now := is_on_floor() and _contact != true and vertical_speed_before_landing < 0.0
	_contact = is_on_floor()
	if landed_now:
		last_landing = "landed"
		if pump_queued:
			speed = minf(handling.max_speed, speed + handling.pump_boost)
			pump_queued = false

func reset_at(where: Vector3, heading: Vector3) -> void:
	global_position = where
	rotation.y = atan2(-heading.x, -heading.z)
	velocity = Vector3.ZERO
	speed = 0.0
	pump_queued = false
	_contact = false
	_jumped = false
	last_landing = ""
