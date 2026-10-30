class_name WheelRider
extends CharacterBody3D
## Side-scrolling unicycle that follows the course path directly. Grounded it
## rolls along the rail (including loops, helix turns and vertical launches);
## airborne it flies ballistically and performs stunts:
##   ▲/▼ flip (backward) / roll (forward), ◀/▶ twist, L/R z-flip, X tabletop.
## Clean landings turn tricks into a speed burst; bad landings crash.

signal landed(report: Dictionary)
signal boosted
signal took_off

@export var handling: WheelHandling
@export var frame_color := Color(0.98, 0.85, 0.1)
@export var seat_color := Color(0.06, 0.06, 0.07)
var course: CanyonCourse
var speed := 0.0
var grounded := false
var section := -1
var distance := 0.0
## +1 drive right, -1 drive left, 0 any direction (helix turns).
var drive_dir := 1
var yaw := 0.0
var pitch := 0.0
var twist := 0.0
var zflip := 0.0
var tabletop := 0.0
var flip_air := 0.0
var twist_air := 0.0
var zflip_air := 0.0
var tabletop_time := 0.0
var air_time := 0.0
var boost_time := 0.0
var recover_time := 0.0
var pump_queued := false
var cruise := false
var vertical_speed_before_landing := 0.0
## Landing tilt relative to the rail, in degrees.
var bank_angle := 0.0
var top_speed := 0.0
var _wheel_spin := 0.0
var _landing_squash := 0.0
var _lean_motion := Vector3.ZERO
var _pose: Node3D
var _trail: CPUParticles3D
var _goo_splatter: CPUParticles3D
var _skip_sec := -1
var _skip_lo := 0.0
var _skip_hi := 0.0

func _ready() -> void:
	assert(handling != null)
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = handling.wheel_radius
	shape.shape = sphere
	add_child(shape)
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	_pose.add_child(_build_wheel())
	_pose.add_child(_build_frame())
	_trail = _build_trail()
	add_child(_trail)
	_goo_splatter = _build_goo_splatter()
	add_child(_goo_splatter)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	if UniloopUI.uses_ios_compatibility():
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	var yellow := _material(frame_color, 0.4, 0.25)
	var steel := _material(Color(0.9, 0.92, 0.95), 0.8, 0.2)
	var fork := BoxMesh.new()
	fork.size = Vector3(0.09, 0.95, 0.09)
	for side in [-0.12, 0.12]:
		frame.add_child(_part(fork, yellow, Vector3(0, 0.45, side)))
	var crown := BoxMesh.new()
	crown.size = Vector3(0.14, 0.09, 0.36)
	frame.add_child(_part(crown, yellow, Vector3(0, 0.94, 0)))
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.045
	post.height = 0.6
	frame.add_child(_part(post, steel, Vector3(0, 1.25, 0)))
	var shock := CylinderMesh.new()
	shock.top_radius = 0.065
	shock.bottom_radius = 0.065
	shock.height = 0.2
	frame.add_child(_part(shock, yellow, Vector3(0, 1.15, 0)))
	var seat_head := Node3D.new()
	seat_head.name = "SeatHead"
	seat_head.position = Vector3(0.04, 1.6, 0)
	var seat := CapsuleMesh.new()
	seat.radius = 0.14
	seat.height = 0.82
	seat_head.add_child(_part(seat, _material(seat_color, 0.1, 0.4), Vector3.ZERO, Vector3(0, 0, PI / 2.0 - 0.12)))
	var sclera := _material(Color(1.0, 1.0, 1.0), 0.0, 0.2)
	var pupil_mat := _material(Color(0.05, 0.05, 0.08), 0.0, 0.1)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.055
	eye_mesh.height = 0.11
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.026
	pupil_mesh.height = 0.052
	for eye_spec in [["EyeLeft", 0.11], ["EyeRight", -0.11]]:
		var eye := Node3D.new()
		eye.name = eye_spec[0]
		eye.position = Vector3(0.32, 0.02, eye_spec[1])
		eye.add_child(_part(eye_mesh, sclera, Vector3.ZERO))
		eye.add_child(_part(pupil_mesh, pupil_mat, Vector3(0.035, 0.0, 0.0)))
		seat_head.add_child(eye)
	frame.add_child(seat_head)
	return frame

func _build_trail() -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.name = "SpeedTrail"
	trail.emitting = false
	trail.amount = 48
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.5
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.35
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = paint
	trail.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.4, 0.9))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	trail.color_ramp = ramp
	return trail

## Small translucent droplets leave the contact patch in world space; no texture asset needed.
func _build_goo_splatter() -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.name = "GooSplatter"
	spray.position.y = -handling.wheel_radius
	spray.emitting = false
	spray.amount = 32
	spray.lifetime = 0.55
	spray.local_coords = false
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.12
	spray.direction = Vector3.UP
	spray.spread = 65.0
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 4.0
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.3
	var droplet := SphereMesh.new()
	droplet.radius = 0.075
	droplet.height = 0.15
	droplet.radial_segments = 6
	droplet.rings = 3
	var paint := _material(Color(0.13, 0.9, 0.06, 0.85), 0.0, 0.2)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet.material = paint
	spray.mesh = droplet
	return spray

func _active() -> bool:
	return not cruise and recover_time <= 0.0

func _physics_process(delta: float) -> void:
	recover_time = maxf(0.0, recover_time - delta)
	boost_time = maxf(0.0, boost_time - delta)
	if grounded and course != null:
		_ground_step(delta)
	else:
		_air_step(delta)
	top_speed = maxf(top_speed, absf(speed))
	_update_pose(delta)

func _ground_step(delta: float) -> void:
	var h := handling
	var smp := course.sample(section, distance)
	var t: Vector3 = smp.seg_t
	drive_dir = smp.drive
	var in_goo: bool = smp.kind == CanyonCourse.GOO
	if recover_time > 0.0:
		speed = 0.0
	elif in_goo and not cruise:
		# Goo is forward-only: no brake, no reverse, no hop; it drags you to a crawl.
		var rate := h.goo_drag if speed > h.goo_speed else h.acceleration
		speed = move_toward(speed, h.goo_speed, rate * delta)
	else:
		speed -= h.gravity * h.slope_gravity * t.y * delta
		var throttle := 1.0
		if not cruise:
			var axis := Input.get_axis(&"move_left", &"move_right")
			throttle = absf(axis) if drive_dir == 0 else axis * drive_dir
		if not cruise and Input.is_action_pressed(&"brake"):
			speed = move_toward(speed, 0.0, h.brake * delta)
		elif throttle > 0.0:
			# Only brake a real backward roll; from a standstill on a slope, pedal forward.
			if speed < -1.0:
				speed = move_toward(speed, 0.0, h.brake * delta)
			else:
				var target := h.cruise_speed if cruise else h.max_speed
				speed = move_toward(speed, maxf(speed, target), h.acceleration * throttle * delta)
		elif throttle < 0.0:
			if speed > 1.0:
				speed = move_toward(speed, 0.0, h.brake * 0.6 * delta)
			else:
				speed = move_toward(speed, -h.reverse_speed, h.acceleration * 0.5 * delta)
		else:
			speed = move_toward(speed, 0.0, h.drag * delta)
		if smp.kind == CanyonCourse.GOO and speed > h.goo_speed:
			speed = move_toward(speed, h.goo_speed, h.goo_drag * delta)
		if speed > h.max_speed:
			speed = move_toward(speed, h.max_speed, h.boost_decay * delta)
		speed = clampf(speed, -h.max_speed, h.max_speed * h.boost_cap)
	var before := distance
	distance += speed * delta
	if course.boost_between(section, before, distance) and speed >= 0.0:
		speed = minf(maxf(speed, h.max_speed) + h.boost_speed, h.max_speed * h.boost_cap)
		boost_time = 1.0
		boosted.emit()
	for guard in 4:
		var sec: CanyonCourse.Section = course.sections[section]
		if distance > sec.length:
			var next := sec.next
			if sec.fork >= 0 and not cruise and Input.is_action_pressed(&"flip_back"):
				next = sec.fork
			if next < 0:
				var lip := course.sample(section, sec.length)
				_place(lip, delta)
				_leave_ground(lip.seg_t * speed)
				return
			distance -= sec.length
			section = next
		elif distance < 0.0:
			if sec.prev < 0:
				var edge := course.sample(section, 0.0)
				_place(edge, delta)
				_leave_ground(edge.seg_t * speed)
				return
			section = sec.prev
			distance += course.sections[section].length
		else:
			break
	smp = course.sample(section, distance)
	_place(smp, delta)
	var grip: float = speed * speed * smp.curv + h.gravity * smp.n.y
	if grip < 0.0 and absf(speed) > 1.0:
		_leave_ground(smp.seg_t * speed)
	elif _active() and smp.drive != 0 and smp.kind != CanyonCourse.GOO and smp.kind != CanyonCourse.TURN and Input.is_action_just_pressed(&"jump"):
		_leave_ground(smp.seg_t * speed + smp.n * h.jump_speed)

func _place(smp: Dictionary, delta: float) -> void:
	global_position = smp.pos + smp.n * handling.wheel_radius
	yaw = atan2(smp.b.x, smp.b.z)
	pitch = lerp_angle(pitch, _surface_pitch(smp.t), minf(1.0, handling.align_rate * delta))

func _surface_pitch(tangent: Vector3) -> float:
	var local := tangent.rotated(Vector3.UP, -yaw)
	return atan2(local.y, local.x)

func _leave_ground(launch: Vector3) -> void:
	grounded = false
	# Don't let a jump drop back onto the rail it just left behind (loop insides).
	_skip_sec = section
	if speed >= 0.0:
		_skip_lo = distance - 70.0
		_skip_hi = distance - 3.0
	else:
		_skip_lo = distance + 3.0
		_skip_hi = distance + 70.0
	velocity = Vector3(launch.x, launch.y, 0.0)
	air_time = 0.0
	flip_air = 0.0
	twist_air = 0.0
	zflip_air = 0.0
	tabletop_time = 0.0
	pump_queued = false
	took_off.emit()

func _air_step(delta: float) -> void:
	var h := handling
	air_time += delta
	velocity.y -= h.gravity * delta
	velocity.z = 0.0
	speed = Vector2(velocity.x, velocity.y).length() * signf(speed if speed != 0.0 else 1.0)
	if _active():
		var flip := Input.get_axis(&"roll_forward", &"flip_back")
		var turn := Input.get_axis(&"move_left", &"move_right")
		var roll := Input.get_axis(&"zflip_left", &"zflip_right")
		pitch += flip * h.spin_rate * delta
		flip_air += flip * h.spin_rate * delta
		twist += turn * h.twist_rate * delta
		twist_air += turn * h.twist_rate * delta
		zflip += roll * h.zflip_rate * delta
		zflip_air += roll * h.zflip_rate * delta
		if Input.is_action_pressed(&"tabletop"):
			tabletop = move_toward(tabletop, 1.0, 6.0 * delta)
			if tabletop > 0.9:
				tabletop_time += delta
		else:
			tabletop = move_toward(tabletop, 0.0, 6.0 * delta)
		if Input.is_action_just_pressed(&"jump"):
			pump_queued = true
		if flip == 0.0:
			var upright := wrapf(pitch, -PI, PI)
			pitch += move_toward(upright, 0.0, h.auto_level * delta) - upright
		# Released twists and z-flips settle onto the nearest landable angle.
		if turn == 0.0:
			var settle := move_toward(twist, snappedf(twist, PI), h.twist_snap * delta) - twist
			twist += settle
			twist_air += settle
		if roll == 0.0:
			var settle := move_toward(zflip, snappedf(zflip, TAU), h.zflip_snap * delta) - zflip
			zflip += settle
			zflip_air += settle
	var from := global_position
	global_position += velocity * delta
	if course != null and air_time > 0.05:
		var hit := course.find_landing(from, global_position, velocity, h.wheel_radius, _skip_sec, _skip_lo, _skip_hi)
		if not hit.is_empty():
			_land(hit)

func _land(hit: Dictionary) -> void:
	var h := handling
	var smp := course.sample(hit.sec, hit.s)
	section = hit.sec
	distance = hit.s
	var new_yaw := atan2(smp.b.x, smp.b.z)
	if absf(wrapf(new_yaw - yaw, -PI, PI)) > PI / 2.0:
		pitch = -pitch
	yaw = new_yaw
	var surface := _surface_pitch(smp.t)
	bank_angle = rad_to_deg(absf(wrapf(pitch - surface, -PI, PI)))
	vertical_speed_before_landing = velocity.dot(smp.n)
	_landing_squash = clampf(absf(vertical_speed_before_landing) / h.hard_landing, 0.0, 1.0)
	speed = velocity.dot(smp.t)
	var tricks: Array[String] = []
	var count := 0
	var flips := int((absf(flip_air) + TAU * 0.2) / TAU)
	if flips > 0:
		tricks.append(("FLIP" if flip_air > 0.0 else "ROLL") + (" x%d" % flips if flips > 1 else ""))
		count += flips
	var halves := int((absf(twist_air) + PI * 0.25) / PI)
	if halves > 0:
		tricks.append("TWIST %d" % (halves * 180))
		count += halves
	var zflips := int((absf(zflip_air) + TAU * 0.2) / TAU)
	if zflips > 0:
		tricks.append("Z-FLIP" + (" x%d" % zflips if zflips > 1 else ""))
		count += zflips
	if tabletop_time >= 0.25:
		tricks.append("TABLETOP")
		count += 1
	var reason := ""
	if absf(vertical_speed_before_landing) > h.hard_landing:
		reason = "Hard landing"
	elif bank_angle > h.crash_angle:
		reason = "Land level with the rail"
	elif absf(wrapf(twist, -PI / 2.0, PI / 2.0)) > deg_to_rad(h.twist_tolerance):
		reason = "Finish the twist"
	elif absf(wrapf(zflip, -PI, PI)) > deg_to_rad(h.zflip_tolerance):
		reason = "Finish the z-flip"
	elif tabletop > 0.4:
		reason = "Release the tabletop"
	if reason != "":
		speed = 0.0
		recover_time = h.recover_time
		tricks.clear()
		count = 0
	else:
		if count > 0:
			speed += h.trick_boost * count
			boost_time = 1.5
		if pump_queued:
			speed += h.pump_boost
		speed = minf(speed, h.max_speed * h.boost_cap)
	pitch = surface
	twist = wrapf(snappedf(twist, PI), 0.0, TAU)
	zflip = 0.0
	tabletop = 0.0
	pump_queued = false
	grounded = true
	velocity = Vector3.ZERO
	global_position = smp.pos + smp.n * h.wheel_radius
	landed.emit({
		"impact": vertical_speed_before_landing,
		"tilt": bank_angle,
		"tricks": tricks,
		"count": count,
		"crash": reason != "",
		"reason": reason,
		"air_time": air_time,
	})

func _update_pose(delta: float) -> void:
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)
	var fallen := 0.0
	if recover_time > 0.0:
		fallen = 1.45 * clampf(recover_time / handling.recover_time * 1.8, 0.0, 1.0)
	_pose.basis = Basis(Vector3.RIGHT, zflip + tabletop * 1.35 + fallen) * Basis(Vector3.UP, twist)
	var frame: Node3D = _pose.get_node("RiderPrimitive")
	var lean_frac := clampf(absf(speed) / handling.max_speed, 0.0, 1.0)
	var travel := basis.x * speed if grounded else velocity
	var lean_target := travel.limit_length(handling.max_speed) / handling.max_speed
	if not grounded:
		lean_target *= 0.3
	# Smooth world-space travel before projecting into the current trick pose.
	_lean_motion = _lean_motion.lerp(lean_target, 1.0 - exp(-3.0 * delta))
	var lean_angle := -deg_to_rad(20.0) * clampf(_lean_motion.dot(basis * _pose.basis.x), -1.0, 1.0)
	var head_shake := 0.0
	if recover_time > 0.0:
		head_shake = sin(recover_time * 28.0) * deg_to_rad(24.0)
	frame.rotation.z = lean_angle
	frame.rotation.y = head_shake
	var seat: Node3D = frame.get_node("SeatHead")
	var head_look := 0.0
	var head_tilt := 0.0
	if not grounded:
		head_look = clampf(-flip_air * 0.45, -deg_to_rad(45.0), deg_to_rad(45.0))
		head_tilt = clampf(twist_air * 0.35, -deg_to_rad(30.0), deg_to_rad(30.0))
	elif absf(speed) > 1.0:
		head_look = deg_to_rad(12.0) * lean_frac
	head_look += head_shake * 0.6
	seat.rotation.z = head_look
	seat.rotation.y = head_tilt
	if delta > 0.0:
		_landing_squash = maxf(0.0, _landing_squash - delta * 4.0)
	var spring := _landing_squash * 0.35 * cos((1.0 - _landing_squash) * TAU * 1.25)
	frame.scale = Vector3(1.0 + spring * 0.25, 1.0 - spring, 1.0 + spring * 0.25)
	_wheel_spin -= speed / handling.wheel_radius * delta
	_pose.get_node("WheelPrimitive").rotation.z = _wheel_spin
	_trail.emitting = boost_time > 0.0 or absf(speed) > handling.max_speed * 0.92
	if _goo_splatter != null:
		var in_goo: bool = grounded and course != null and course.sample(section, distance).kind == CanyonCourse.GOO
		_goo_splatter.emitting = in_goo and absf(speed) > 0.1 and recover_time <= 0.0
		if _goo_splatter.emitting:
			var contact: Dictionary = course.sample(section, distance)
			_goo_splatter.position = to_local(contact.pos)
			_goo_splatter.direction = (basis.inverse() * (contact.n * 0.8 - contact.seg_t * signf(speed))).normalized()

func place_on(index: int, s: float) -> void:
	section = index
	distance = s
	grounded = true
	speed = 0.0
	velocity = Vector3.ZERO
	_clear_state()
	var smp := course.sample(index, s)
	_place(smp, 1.0)
	pitch = _surface_pitch(smp.t)
	drive_dir = smp.drive
	_reset_visual_motion()

func reset_at(where: Vector3, heading: Vector3) -> void:
	global_position = where
	grounded = false
	velocity = Vector3.ZERO
	speed = 0.0
	yaw = 0.0 if heading.x >= 0.0 else PI
	pitch = 0.0
	_clear_state()
	_reset_visual_motion()

func _reset_visual_motion() -> void:
	if not is_node_ready():
		return
	_update_pose(0.0)
	# Prime the camera interpolation pump, then snap every visual on teleports.
	get_global_transform_interpolated()
	reset_physics_interpolation()

func _clear_state() -> void:
	if _goo_splatter != null:
		_goo_splatter.emitting = false
	_skip_sec = -1
	_landing_squash = 0.0
	_lean_motion = Vector3.ZERO
	twist = 0.0
	zflip = 0.0
	tabletop = 0.0
	flip_air = 0.0
	twist_air = 0.0
	zflip_air = 0.0
	tabletop_time = 0.0
	air_time = 0.0
	boost_time = 0.0
	recover_time = 0.0
	pump_queued = false
	cruise = false
