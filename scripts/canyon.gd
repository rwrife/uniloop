class_name CanyonCourse
extends Node3D
## Uni Racers-style 2.5D course. Rail legs zigzag upward while drifting right:
## right-bound legs run in front (z = 0), left-bound legs behind (z = BACK_Z),
## joined by 180° helix turns or vertical launches that shoot the rider up
## through the underside of the next leg. The track is a set of polyline
## sections the rider follows directly; landings are one-way (from above only).

enum { NORMAL, TURN, SHORTCUT, HAZARD, GOO }
## Stripe colour pairs per kind: blue/green normal, red/blue direction shift,
## yellow (reserved; fork routes are deliberately unmarked), red/yellow pitfall
## or goo hazard.
const KIND_COLORS := [
	[Color(0.1, 0.3, 0.92), Color(0.08, 0.72, 0.36)],
	[Color(0.86, 0.06, 0.12), Color(0.1, 0.16, 0.82)],
	[Color(1.0, 0.86, 0.1), Color(1.0, 0.6, 0.05)],
	[Color(0.9, 0.08, 0.1), Color(1.0, 0.85, 0.1)],
	[Color(0.9, 0.08, 0.1), Color(1.0, 0.85, 0.1)],
]
const NEON_KIND_COLORS := [
	[Color("#00efff"), Color("#83ff24")],
	[Color("#ff24c8"), Color("#9855ff")],
	[Color("#fff026"), Color("#ff9d16")],
	[Color("#ff3154"), Color("#fff026")],
	[Color("#ff3154"), Color("#fff026")],
]
const NEON_RAIL := preload("res://assets/shaders/neon_rail.gdshader")
const NEON_BACKDROP := preload("res://assets/shaders/neon_backdrop.gdshader")
const MONOPOLY_BACKDROP := preload("res://assets/shaders/monopoly_backdrop.gdshader")
const APPLES := preload("res://scripts/monopoly_apples.gd")
const MONOPOLY_KIND_COLORS := [
	[Color(0.72, 0.72, 0.72), Color(0.54, 0.54, 0.54)],
	[Color(0.82, 0.82, 0.82), Color(0.46, 0.46, 0.46)],
	[Color(0.76, 0.76, 0.76), Color(0.60, 0.60, 0.60)],
	[Color(0.92, 0.92, 0.92), Color(0.38, 0.38, 0.38)],
	[Color(0.92, 0.92, 0.92), Color(0.38, 0.38, 0.38)],
]
const MUD_COLOR := Color("#92582c")
const NEON_SPARK_COLOR := Color("#ff24c8")
const BACK_Z := -10.0
## Forks split at a Y-junction into two long, unmarked routes that rejoin
## BRANCH_LENGTH later: the upper branch climbs BRANCH_CLIMB while moving
## BRANCH_Z behind, the lower branch dips BRANCH_DROP, both over BRANCH_SPREAD.
const BRANCH_LENGTH := 240.0
const BRANCH_Z := 3.0
const BRANCH_SPREAD := 40.0
const BRANCH_CLIMB := 5.0
const BRANCH_DROP := 4.0
const EASE_LENGTH := 30.0
const UTURN_RADIUS := 5.0
const UTURN_RISE := 4.0
const LAUNCH_RADIUS := 6.0
const LAUNCH_RISE := 4.0
const LAUNCH_CLEARANCE := 6.0
const LAUNCH_OVERHANG := 12.0
const LOOP_SHIFT := 1.6
const RIGHT_LEG := 440.0
const LEFT_LEG := 250.0
const RAIL_RADIUS := 0.45
## Goo coats the rail only this much thicker than the bare rail.
const GOO_THICKNESS := 1.15
const STRIPE_LENGTH := 2.0
const CHEVRON_SPACING := 7.0
const COLLISION_HALF_DEPTH := 2.5
const LAND_Z_TOLERANCE := 2.5
const RENDER_CELL := 24.0
const CELL := 20.0
## Rocket bumps sit this far before a leg's end: far enough that the launch
## lands back on the same leg before the turn.
const BUMP_LEAD := 110.0
const BUMP_HEIGHT := 1.6
const BUMP_RUN := 3.0
const DRIP_SHADER := """
shader_type spatial;
uniform vec4 surface_color : source_color;
uniform vec4 glow_color : source_color;
uniform float glow_energy = 0.45;
// Goo drip hanging from the rail; the top (+y) stays glued, the tip stretches.
void vertex() {
	float phase = COLOR.r * 6.2832;
	float stretch = 0.75 + 0.3 * sin(TIME * 1.4 + phase) + 0.12 * sin(TIME * 3.1 + phase * 2.0);
	float down = 0.5 - VERTEX.y;
	VERTEX.y = 0.5 - down * stretch;
	float thinning = mix(1.0, inversesqrt(max(stretch, 1.0)), down);
	VERTEX.xz *= thinning;
	NORMAL = normalize(vec3(NORMAL.x / thinning, NORMAL.y / stretch, NORMAL.z / thinning));
}
void fragment() {
	ALBEDO = surface_color.rgb;
	EMISSION = glow_color.rgb * glow_energy;
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
	SPECULAR = 0.5;
}
"""
const BACKDROP_SHADER := """
shader_type spatial;
render_mode unshaded;
varying vec3 world_pos;
uniform vec3 sky_a = vec3(0.42, 0.32, 0.30);
uniform vec3 sky_b = vec3(0.50, 0.40, 0.37);
uniform vec3 sky_c = vec3(0.35, 0.26, 0.27);
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
	vec3 col = mix(sky_a, sky_b, tri);
	col = mix(col, sky_c, diamond);
	col *= 0.8 + 0.2 * clamp(world_pos.y / 200.0 + 0.3, 0.0, 1.0);
	ALBEDO = pow(col, vec3(2.2));
}
"""

class Section:
	var points := PackedVector3Array()
	var binormals := PackedVector3Array()
	## Per segment (points[k] -> points[k + 1]).
	var kinds := PackedByteArray()
	var drives := PackedInt32Array()
	var landable := PackedByteArray()
	var seg_tangents := PackedVector3Array()
	var seg_normals := PackedVector3Array()
	## Per point.
	var cum := PackedFloat32Array()
	var tangents := PackedVector3Array()
	var normals := PackedVector3Array()
	var curvature := PackedFloat32Array()
	var length := 0.0
	var next := -1
	## Alternate next section at a junction, taken by holding Up.
	var fork := -1
	var prev := -1

## Which RaceSetup track to build; set before adding the course to the tree.
var track_id := RaceSetup.DEFAULT_TRACK
var reduced_motion := false
var high_contrast := false
var track: Dictionary
var course_id := ""
var medals: Dictionary
var sections: Array = []
var gates: Array[Dictionary] = []
var start_spot: Dictionary
var finish: Dictionary
var boosts: Array[Dictionary] = []
var gaps: Array = []
## {"split", "merge", "routes", "junction"} per fork; routes = sections that end at merge.
var forks: Array[Dictionary] = []
var goo_pits := 0
var rocket_bumps := 0
var launches: Array[Vector3] = []
var uturns := 0
var loops := 0
var bounds := AABB()
var apples: MonopolyApples

var _sec: Section
var _sec_index := -1
var _sec_len := 0.0
var _pen := Vector3.ZERO
var _dir := 1
var _layer_z := 0.0
var _zt := 0.0
var _land_sec := PackedInt32Array()
var _land_k := PackedInt32Array()
var _cells := {}
var _neon_backdrop: ShaderMaterial
var _neon_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	track = RaceSetup.track(track_id)
	course_id = track.id
	medals = track.medals
	_layout()
	bounds = AABB(sections[0].points[0], Vector3.ZERO)
	for sec: Section in sections:
		_finalize(sec)
		for p in sec.points:
			bounds = bounds.expand(p)
	for spot in gates:
		_resolve(spot)
	_resolve(start_spot)
	_resolve(finish)
	for pad in boosts:
		_resolve(pad)
	_index_landing()
	_build_rail()
	_build_collision()
	_build_backdrop()
	for i in gates.size():
		var arrow := "▶" if gates[i].t.x > 0.0 else "◀"
		var text := ("%d %s" % [i + 1, arrow]) if arrow == "▶" else ("%s %d" % [arrow, i + 1])
		_add_gate(gates[i], "Checkpoint%d" % i, text, Color(0.1, 0.85, 0.75))
	_add_gate(finish, "Finish", "FINISH", Color(1.0, 0.8, 0.15))
	_add_gate(start_spot, "Start", "", Color(0.35, 0.65, 1.0))
	for pad in boosts:
		_add_boost_pad(pad)
	for fork in forks:
		_add_junction_marker(fork.split)
	if course_id == "the_monopoly":
		apples = APPLES.new()
		apples.name = "Apples"
		add_child(apples)
		apples.populate(self)
	set_process(course_id == "neon_night" and not reduced_motion)

func _process(delta: float) -> void:
	_neon_time += delta
	_neon_backdrop.set_shader_parameter("motion_time", _neon_time)

# --- Layout -----------------------------------------------------------------

func _layout() -> void:
	_dir = 1
	_layer_z = 0.0
	_zt = 0.0
	_begin(Vector3(-10, 0, 0))
	start_spot = _spot(7.0)
	var plan: Array = track.plan
	for leg_index in plan.size():
		var leg: Array = plan[leg_index]
		var start_x := _pen.x
		var kind: String = leg[0]
		match kind:
			"RA":
				_leg_ra()
			"RB":
				_leg_rb()
			"L":
				_leg_l()
			"S":
				_leg_s()
			"G":
				_leg_g()
			"FINAL":
				_leg_final()
				continue
		var length := RIGHT_LEG if kind in ["RA", "RB", "S"] else LEFT_LEG
		var bump: bool = leg_index in track.bumps
		length = maxf(length, (_pen.x - start_x) * _dir + (BUMP_LEAD + 10.0 if bump else 40.0))
		if bump:
			_line_to(start_x + _dir * (length - BUMP_LEAD))
			_rocket_bump()
		_line_to(start_x + _dir * (length - 30.0))
		if leg[1] == "uturn":
			# Climb before the helix so the helix itself is level: a rising helix
			# ends in a crest that throws the rider off at speed.
			_hill(30.0, UTURN_RISE, TURN)
			_uturn()
		else:
			_line_to(start_x + _dir * length, TURN)
			_launch()

func _leg_ra() -> void:
	_line(25.0)
	_gate()
	_loop_run(7.0)
	_hill(40.0, 6.0)
	_fork()
	_hill(40.0, 5.0)

func _leg_rb() -> void:
	_line(25.0)
	_gate()
	_hill(40.0, 4.0)
	_jump(16.0, 3.5, 22.0, -3.0)
	_loop_run(8.0)
	_fork()
	_hill(50.0, 8.0)

func _leg_l() -> void:
	_line(25.0)
	_gate()
	_hill(40.0, 5.0)
	_loop_run(6.0)
	_goo_pit()
	_jump(12.0, 2.0, 14.0, -1.0)
	_hill(40.0, 5.0)

## Speed leg: back-to-back boosted loops into a fork.
func _leg_s() -> void:
	_line(25.0)
	_gate()
	_loop_run(7.0)
	_loop_run(8.0)
	_fork()
	_boost()
	_hill(40.0, 6.0)

## Goo leg: a goo pit either side of a fork.
func _leg_g() -> void:
	_line(25.0)
	_gate()
	_goo_pit()
	_hill(40.0, 5.0)
	_fork()
	_goo_pit()
	_hill(30.0, 4.0)

func _leg_final() -> void:
	_line(25.0)
	_gate()
	_rollers()
	_loop_run(8.0)
	_hill(40.0, 3.0)
	_line(40.0)
	finish = _spot(0.0)
	_line(160.0)

# --- Builder primitives -----------------------------------------------------

func _begin(at: Vector3, prev := -1) -> int:
	var sec := Section.new()
	sec.prev = prev
	sec.points.append(at)
	sec.binormals.append(Vector3(0, 0, _dir))
	sections.append(sec)
	_sec = sec
	_sec_index = sections.size() - 1
	_sec_len = 0.0
	_pen = at
	return _sec_index

func _add(p: Vector3, binormal: Vector3, kind: int, drive: int, landable := true) -> void:
	_sec_len += _pen.distance_to(p)
	_sec.points.append(p)
	_sec.binormals.append(binormal)
	_sec.kinds.append(kind)
	_sec.drives.append(drive)
	_sec.landable.append(1 if landable else 0)
	_pen = p

func _spot(ahead: float) -> Dictionary:
	return {"sec": _sec_index, "s": _sec_len + ahead}

func _gate() -> void:
	gates.append(_spot(0.0))

func _boost() -> void:
	boosts.append(_spot(2.0))

func _profile(dx: float, steps: int, kind: int, shape: Callable) -> void:
	var start := _pen
	for i in range(1, steps + 1):
		var u := float(i) / steps
		_add(Vector3(start.x + _dir * dx * u, start.y + shape.call(u), lerpf(start.z, _zt, u)), Vector3(0, 0, _dir), kind, _dir)

func _line(dx: float, dy := 0.0, kind := NORMAL) -> void:
	_profile(dx, maxi(1, ceili(dx / 10.0)), kind, func(u: float) -> float: return dy * u)

func _line_to(x: float, kind := NORMAL) -> void:
	var dx := (x - _pen.x) * _dir
	if dx > 0.5:
		_line(dx, 0.0, kind)

func _hill(dx: float, dy: float, kind := NORMAL) -> void:
	_profile(dx, maxi(6, ceili(dx / 4.0)), kind, func(u: float) -> float: return dy * (1.0 - cos(PI * u)) * 0.5)

func _rollers() -> void:
	for k in 2:
		_hill(22.0, 2.0)
		_hill(22.0, -2.0)

func _loop_run(radius: float) -> void:
	_boost()
	_line(40.0)
	_loop(radius)
	_line(25.0)

func _loop(radius: float, steps := 40) -> void:
	loops += 1
	var start := _pen
	var center := start + Vector3(0, radius, 0)
	for i in range(1, steps + 1):
		var th := -PI / 2.0 + TAU * i / steps
		_add(Vector3(center.x + _dir * radius * cos(th), center.y + radius * sin(th), start.z + LOOP_SHIFT * i / steps), Vector3(0, 0, _dir), TURN, _dir)

func _jump(kick_dx: float, kick_dy: float, gap_dx: float, gap_dy: float) -> void:
	_line(12.0, 0.0, HAZARD)
	_profile(kick_dx, 6, HAZARD, func(u: float) -> float: return kick_dy * u * u)
	var lip := _pen
	var landing := lip + Vector3(_dir * gap_dx, gap_dy, 0.0)
	gaps.append([lip, landing])
	_begin(landing)
	_line(20.0)

## Splits into two unmarked routes of similar length with different obstacles.
## The rail visibly forks at a Y-junction: the upper branch climbs away behind,
## the lower branch dips in front. Hold Up at the junction for the upper
## branch; Down (or nothing) keeps you low. Both routes rejoin at the merge.
func _fork() -> void:
	var recipes := [["goo_rollers", "climb_gaps"], ["loop_jump", "rollers_jump"], ["rollers_jump", "climb_goo"], ["double_jump", "goo_boost"]]
	var index := forks.size()
	var recipe: Array = recipes[index % recipes.size()]
	var from := _sec_index
	var split := _pen
	var layer := _zt
	var merge := Vector3(split.x + _dir * BRANCH_LENGTH, split.y, layer)
	var routes: Array[int] = []
	var low := _begin(split, from)
	sections[from].next = low
	_hill(BRANCH_SPREAD, -BRANCH_DROP)
	_route(recipe[0])
	routes.append(_ease_to(merge))
	var high := _begin(split, from)
	sections[from].fork = high
	_zt = layer - BRANCH_Z
	_hill(BRANCH_SPREAD, BRANCH_CLIMB)
	_route(recipe[1])
	routes.append(_ease_to(merge))
	var rest := _begin(merge, routes[0])
	for route in routes:
		sections[route].next = rest
	forks.append({"split": split, "merge": merge, "routes": routes, "junction": from})
	_line(10.0)

func _route(id: String) -> void:
	match id:
		"goo_rollers":
			_goo_pit()
			_rollers()
		"climb_gaps":
			_hill(40.0, 8.0)
			_jump(12.0, 2.0, 18.0, -2.0)
			_boost()
			_line(15.0)
			_hill(30.0, -4.0)
		"loop_jump":
			_loop_run(7.0)
			_jump(12.0, 2.0, 16.0, -2.0)
		"rollers_jump":
			_rollers()
			_jump(14.0, 2.5, 20.0, -2.0)
		"climb_goo":
			_hill(40.0, 9.0)
			_goo_pit()
			_hill(20.0, -3.0)
		"double_jump":
			_jump(10.0, 2.0, 22.0, -1.0)
			_jump(10.0, 2.0, 22.0, -1.0)
		"goo_boost":
			_goo_pit()
			_boost()
			_line(30.0)
			_hill(30.0, -3.0)

## Ends the current route exactly at `target` with a smooth ease; returns the
## route's final section.
func _ease_to(target: Vector3) -> int:
	_zt = target.z
	_line_to(target.x - _dir * EASE_LENGTH)
	var dx := (target.x - _pen.x) * _dir
	assert(dx > 10.0, "fork route too long for BRANCH_LENGTH")
	_hill(dx, target.y - _pen.y)
	return _sec_index

## A kicker followed by a long sagging goo trough. Only a full-speed hop off
## the kicker clears it; anything less lands in the goo, which is forward-only.
func _goo_pit() -> void:
	goo_pits += 1
	_line(8.0, 0.0, HAZARD)
	_profile(14.0, 6, HAZARD, func(u: float) -> float: return 2.5 * u * u)
	_hill(8.0, -3.5, GOO)
	_line(24.0, 0.0, GOO)
	_hill(8.0, 3.5, GOO)
	_line(10.0)

## A short, steep curl at the end of a straight. Ride over it at speed and it
## fires you skyward; hop just before it to skim over.
func _rocket_bump() -> void:
	rocket_bumps += 1
	var start := _pen
	for i in range(1, 9):
		var u := i / 8.0
		_add(start + Vector3(_dir * BUMP_RUN * u, BUMP_HEIGHT * u * u * u, 0.0), Vector3(0, 0, _dir), NORMAL, _dir)
	var crest := _pen
	for i in range(1, 9):
		var u := i / 8.0
		_add(crest + Vector3(_dir * 2.5 * u, -BUMP_HEIGHT * (1.0 - cos(PI * u)) * 0.5, 0.0), Vector3(0, 0, _dir), NORMAL, _dir)
	_line(8.0)

func _other_layer() -> float:
	return 0.0 if is_equal_approx(_layer_z, BACK_Z) else BACK_Z

func _uturn(steps := 24) -> void:
	uturns += 1
	var start := _pen
	var target := _other_layer()
	var side := signf(target - start.z)
	for i in range(1, steps + 1):
		var th := PI * i / steps
		var p := Vector3(start.x + _dir * UTURN_RADIUS * sin(th), start.y, start.z + side * UTURN_RADIUS * (1.0 - cos(th)))
		var tangent := Vector3(_dir * cos(th), 0.0, side * sin(th))
		_add(p, tangent.cross(Vector3.UP).normalized(), TURN, 0)
	_dir = -_dir
	_layer_z = target
	_zt = target

func _launch(steps := 10) -> void:
	var start := _pen
	var target := _other_layer()
	for i in range(1, steps + 1):
		var ph := PI / 2.0 * i / steps
		var p := Vector3(start.x + _dir * LAUNCH_RADIUS * sin(ph), start.y + LAUNCH_RADIUS * (1.0 - cos(ph)), lerpf(start.z, target, float(i) / steps))
		_add(p, Vector3(0, 0, _dir), TURN, _dir)
	for i in 2:
		_add(_pen + Vector3(0, LAUNCH_RISE / 2.0, 0), Vector3(0, 0, _dir), TURN, _dir)
	var lip := _pen
	launches.append(lip)
	_begin(Vector3(lip.x + _dir * LAUNCH_OVERHANG, lip.y + LAUNCH_CLEARANCE, target))
	_dir = -_dir
	_layer_z = target
	_zt = target
	_sec.binormals[0] = Vector3(0, 0, _dir)

# --- Path queries -----------------------------------------------------------

func _finalize(sec: Section) -> void:
	var n := sec.points.size()
	sec.cum.resize(n)
	sec.tangents.resize(n)
	sec.normals.resize(n)
	sec.curvature.resize(n)
	sec.seg_tangents.resize(n - 1)
	sec.seg_normals.resize(n - 1)
	var lengths := PackedFloat32Array()
	lengths.resize(n - 1)
	sec.cum[0] = 0.0
	for k in n - 1:
		var d := sec.points[k + 1] - sec.points[k]
		lengths[k] = maxf(d.length(), 0.001)
		sec.seg_tangents[k] = d / lengths[k]
		var b := (sec.binormals[k] + sec.binormals[k + 1]).normalized()
		sec.seg_normals[k] = b.cross(sec.seg_tangents[k]).normalized()
		sec.cum[k + 1] = sec.cum[k] + lengths[k]
	sec.length = sec.cum[n - 1]
	for k in n:
		var t: Vector3
		if k == 0:
			t = sec.seg_tangents[0]
		elif k == n - 1:
			t = sec.seg_tangents[n - 2]
		else:
			t = (sec.seg_tangents[k - 1] + sec.seg_tangents[k]).normalized()
		sec.tangents[k] = t
		sec.normals[k] = sec.binormals[k].cross(t).normalized()
		sec.curvature[k] = 0.0
		if k > 0 and k < n - 1:
			sec.curvature[k] = (sec.seg_tangents[k] - sec.seg_tangents[k - 1]).dot(sec.normals[k]) / ((lengths[k - 1] + lengths[k]) * 0.5)

func _resolve(spot: Dictionary) -> void:
	var smp := sample(spot.sec, spot.s)
	spot.pos = smp.pos
	var flat := Vector3(smp.t.x, 0.0, smp.t.z)
	spot.t = flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	spot.n = smp.n

## Rail point, smoothed tangent/normal/binormal, curvature and segment data at
## arc length `s` along section `index`.
func sample(index: int, s: float) -> Dictionary:
	var sec: Section = sections[index]
	s = clampf(s, 0.0, sec.length)
	var k := clampi(sec.cum.bsearch(s) - 1, 0, sec.points.size() - 2)
	var span := sec.cum[k + 1] - sec.cum[k]
	var u := clampf((s - sec.cum[k]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return {
		"pos": sec.points[k].lerp(sec.points[k + 1], u),
		"t": sec.tangents[k].lerp(sec.tangents[k + 1], u).normalized(),
		"n": sec.normals[k].lerp(sec.normals[k + 1], u).normalized(),
		"b": sec.binormals[k].lerp(sec.binormals[k + 1], u).normalized(),
		"seg_t": sec.seg_tangents[k],
		"curv": lerpf(sec.curvature[k], sec.curvature[k + 1], u),
		"kind": sec.kinds[k],
		"drive": sec.drives[k],
		"landable": sec.landable[k] == 1,
	}

func spawn(gate_index: int) -> Dictionary:
	return start_spot if gate_index < 0 else gates[gate_index]

func boost_between(index: int, s0: float, s1: float) -> bool:
	for pad in boosts:
		if pad.sec == index and minf(s0, s1) < pad.s and pad.s <= maxf(s0, s1):
			return true
	return false

func crossed(spot: Dictionary, from: Vector3, to: Vector3) -> bool:
	var d0: float = (from - spot.pos).dot(spot.t)
	var d1: float = (to - spot.pos).dot(spot.t)
	return d0 < 0.0 and d1 >= 0.0 and ((to - spot.pos) - spot.t * d1).length() < 6.0

func out_of_bounds(where: Vector3) -> bool:
	return where.y < bounds.position.y - 25.0 or where.x < bounds.position.x - 40.0 or where.x > bounds.end.x + 40.0

func _index_landing() -> void:
	for i in sections.size():
		var sec: Section = sections[i]
		for k in sec.points.size() - 1:
			if sec.landable[k] == 0:
				continue
			var id := _land_sec.size()
			_land_sec.append(i)
			_land_k.append(k)
			var lo := floori(minf(sec.points[k].x, sec.points[k + 1].x) / CELL)
			var hi := floori(maxf(sec.points[k].x, sec.points[k + 1].x) / CELL)
			for c in range(lo, hi + 1):
				if not _cells.has(c):
					_cells[c] = PackedInt32Array()
				_cells[c].append(id)

## One-way landing test: the wheel (radius r) must cross a rail's offset line
## from above while moving into it. Rising through a rail from below is free.
## Rail on section `skip_sec` between arc lengths skip_lo..skip_hi is ignored
## (the stretch just behind a takeoff, e.g. the inside of a loop you exited).
func find_landing(from: Vector3, to: Vector3, velocity: Vector3, r: float, skip_sec := -1, skip_lo := 0.0, skip_hi := 0.0) -> Dictionary:
	var best := 2.0
	var hit := {}
	var lo_x := minf(from.x, to.x) - r - 0.5
	var hi_x := maxf(from.x, to.x) + r + 0.5
	var lo_y := minf(from.y, to.y) - r - 0.5
	var hi_y := maxf(from.y, to.y) + r + 0.5
	var seen := {}
	var p0 := Vector2(from.x, from.y)
	var p1 := Vector2(to.x, to.y)
	for c in range(floori(lo_x / CELL), floori(hi_x / CELL) + 1):
		for id in _cells.get(c, PackedInt32Array()):
			if seen.has(id):
				continue
			seen[id] = true
			var sec: Section = sections[_land_sec[id]]
			var k := _land_k[id]
			var a := sec.points[k]
			var b := sec.points[k + 1]
			if maxf(a.x, b.x) < lo_x or minf(a.x, b.x) > hi_x or maxf(a.y, b.y) < lo_y or minf(a.y, b.y) > hi_y:
				continue
			if absf((a.z + b.z) * 0.5 - to.z) > LAND_Z_TOLERANCE:
				continue
			var n3 := sec.seg_normals[k]
			# Only land on rail you can stand on (not loop walls or launch faces).
			if n3.y < 0.25:
				continue
			var n := Vector2(n3.x, n3.y)
			if n.length() < 0.5:
				continue
			n = n.normalized()
			if velocity.x * n.x + velocity.y * n.y >= 0.0:
				continue
			var a2 := Vector2(a.x, a.y) + n * r
			var b2 := Vector2(b.x, b.y) + n * r
			var d0 := (p0 - a2).dot(n)
			var d1 := (p1 - a2).dot(n)
			if d0 < -0.2 or d1 >= 0.0:
				continue
			var f := clampf(d0 / (d0 - d1), 0.0, 1.0) if d0 > 0.0 else 0.0
			var h := p0.lerp(p1, f)
			var seg := b2 - a2
			var u := (h - a2).dot(seg) / seg.length_squared()
			if u < -0.03 or u > 1.03 or f >= best:
				continue
			var s := sec.cum[k] + clampf(u, 0.0, 1.0) * (sec.cum[k + 1] - sec.cum[k])
			if _land_sec[id] == skip_sec and s > skip_lo and s < skip_hi:
				continue
			best = f
			hit = {"sec": _land_sec[id], "s": s, "f": f}
	return hit

# --- Visuals ----------------------------------------------------------------

func _paint(color: Color, emission := 0.0) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	if UniloopUI.uses_ios_compatibility():
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = color
	paint.metallic = 0.25
	paint.roughness = 0.3
	if emission > 0.0:
		paint.emission_enabled = true
		paint.emission = color
		paint.emission_energy_multiplier = emission
	return paint

func goo_color(slime_color: Color) -> Color:
	return Color(MUD_COLOR, slime_color.a) if course_id == "canyon_climb" else slime_color

func spark_color(base_color: Color) -> Color:
	return Color(NEON_SPARK_COLOR, base_color.a) if course_id == "neon_night" else base_color

func _build_rail() -> void:
	var paint := StandardMaterial3D.new()
	if UniloopUI.uses_ios_compatibility():
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.metallic = 0.3
	paint.roughness = 0.22
	var rail_paint: Material = paint
	var colors: Array = KIND_COLORS
	if course_id == "neon_night":
		var neon_paint := ShaderMaterial.new()
		neon_paint.shader = NEON_RAIL
		rail_paint = neon_paint
		colors = NEON_KIND_COLORS
	elif course_id == "the_monopoly":
		colors = MONOPOLY_KIND_COLORS
		paint.metallic = 0.0
		paint.roughness = 0.95
	var tube := CylinderMesh.new()
	tube.top_radius = RAIL_RADIUS
	tube.bottom_radius = RAIL_RADIUS
	tube.height = 1.0
	tube.radial_segments = 16
	tube.rings = 1
	tube.material = rail_paint
	var joint := SphereMesh.new()
	joint.radius = RAIL_RADIUS
	joint.height = RAIL_RADIUS * 2.0
	joint.radial_segments = 12
	joint.rings = 6
	joint.material = rail_paint
	var chevron := PrismMesh.new()
	chevron.size = Vector3.ONE
	chevron.material = _paint(Color(0.95, 0.97, 1.0), 0.6)
	var goo_paint := _paint(goo_color(Color(0.35, 1.0, 0.2)), 0.45)
	goo_paint.roughness = 0.05
	goo_paint.metallic = 0.1
	var goo_coat := CylinderMesh.new()
	goo_coat.top_radius = 1.0
	goo_coat.bottom_radius = 1.0
	goo_coat.height = 1.0
	goo_coat.radial_segments = 14
	goo_coat.rings = 1
	goo_coat.material = goo_paint
	var goo_lump := SphereMesh.new()
	goo_lump.radius = 0.5
	goo_lump.height = 1.0
	goo_lump.radial_segments = 10
	goo_lump.rings = 5
	goo_lump.material = goo_paint
	var drip := _drip_mesh()
	var drip_paint := ShaderMaterial.new()
	drip_paint.shader = Shader.new()
	drip_paint.shader.code = DRIP_SHADER.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;") if UniloopUI.uses_ios_compatibility() else DRIP_SHADER
	drip_paint.set_shader_parameter("surface_color", goo_paint.albedo_color)
	drip_paint.set_shader_parameter("glow_color", goo_paint.emission)
	drip_paint.set_shader_parameter("glow_energy", goo_paint.emission_energy_multiplier)
	drip.surface_set_material(0, drip_paint)
	var stripes: Array = []
	var joints: Array = []
	var arrows: Array = []
	var coats: Array = []
	var lumps: Array = []
	var drips: Array = []
	var drop_points := PackedVector3Array()
	for sec: Section in sections:
		var stripe_index := 0
		var last_color: Color = colors[sec.kinds[0]][0]
		joints.append([Transform3D(Basis.IDENTITY, sec.points[0] - sec.normals[0] * RAIL_RADIUS), last_color])
		var next_arrow := 3.0
		for k in sec.points.size() - 1:
			var a := sec.points[k]
			var b := sec.points[k + 1]
			var t := sec.seg_tangents[k]
			var n := sec.seg_normals[k]
			var length := sec.cum[k + 1] - sec.cum[k]
			var count := maxi(1, roundi(length / STRIPE_LENGTH))
			var kind := sec.kinds[k]
			var axis := Basis(n, t * (length / count), n.cross(t).normalized())
			for j in count:
				var u := (j + 0.5) / count
				last_color = colors[kind][stripe_index % 2]
				stripes.append([Transform3D(axis, a.lerp(b, u) - n * RAIL_RADIUS), last_color])
				stripe_index += 1
			joints.append([Transform3D(Basis.IDENTITY, b - sec.normals[k + 1] * RAIL_RADIUS), last_color])
			while next_arrow < sec.cum[k + 1]:
				var u := (next_arrow - sec.cum[k]) / length
				next_arrow += CHEVRON_SPACING
				var side := t.cross(Vector3.BACK)
				if side.length() < 0.3:
					continue
				side = side.normalized()
				var up := Vector3.BACK.cross(side)
				var face := a.lerp(b, u) - n * RAIL_RADIUS + Vector3.BACK * (RAIL_RADIUS + 0.03)
				arrows.append([Transform3D(Basis(side * 0.5, up * 0.42, Vector3.BACK * 0.04), face), Color.WHITE])
			if kind == GOO:
				var b3 := n.cross(t).normalized()
				var core := a.lerp(b, 0.5) - n * RAIL_RADIUS
				var coat_r := RAIL_RADIUS * GOO_THICKNESS
				coats.append([Transform3D(Basis(n * coat_r, t * length, b3 * coat_r), core), Color.WHITE])
				var ball := Basis.IDENTITY.scaled(Vector3.ONE * coat_r * 2.0)
				lumps.append([Transform3D(ball, b - sec.normals[k + 1] * RAIL_RADIUS), Color.WHITE])
				var starts := k == 0 or sec.kinds[k - 1] != GOO
				var ends := k == sec.kinds.size() - 1 or sec.kinds[k + 1] != GOO
				for edge in [[starts, a, sec.normals[k]], [ends, b, sec.normals[k + 1]]]:
					if not edge[0]:
						continue
					# Rounded, sagging blob where the slime drops off the rail.
					var tip: Vector3 = edge[1] - edge[2] * RAIL_RADIUS
					var sag := Basis(t * coat_r * 2.2, Vector3.UP * coat_r * 2.9, b3 * coat_r * 2.2)
					lumps.append([Transform3D(sag, tip + Vector3.DOWN * coat_r * 0.45), Color.WHITE])
					var width := _drip_width(tip)
					var root: Vector3 = tip - edge[2] * coat_r * 0.35
					drips.append([Transform3D(Basis(t * width, Vector3.UP * 2.6, b3 * width), root + Vector3.DOWN * 1.3), Color(_hash(tip), 0, 0)])
				var drip_count := maxi(1, roundi(length / 1.6))
				for j in drip_count:
					var u := (j + _hash(b + Vector3(j, 1, 0)) * 0.8 + 0.1) / drip_count
					var hang := 0.5 + 2.4 * pow(_hash(a + Vector3(j, 2, 0)), 1.8)
					var top := a.lerp(b, u) - n * (RAIL_RADIUS + coat_r * 0.35)
					var down := Vector3.DOWN if n.y > 0.3 else -n
					var side := t.cross(down).normalized()
					var width := _drip_width(top)
					drips.append([Transform3D(Basis(side * width, -down * hang, side.cross(-down) * width), top + down * hang * 0.5), Color(_hash(top), 0, 0)])
					if hang > 2.2:
						drop_points.append(top + down * hang)
	_add_multimesh("Rail", tube, stripes)
	_add_multimesh("RailJoints", joint, joints)
	_add_multimesh("Chevrons", chevron, arrows)
	_add_multimesh("Goo", goo_coat, coats)
	_add_multimesh("GooLumps", goo_lump, lumps)
	_add_multimesh("GooDrips", drip, drips, false)
	if not drop_points.is_empty():
		_add_goo_droplets(drop_points, goo_paint)

func _hash(p: Vector3) -> float:
	return fposmod(sin(p.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)

func _drip_width(at: Vector3) -> float:
	return 1.35 if _hash(at + Vector3(7, 11, 3)) > 0.65 else 0.65 + 0.25 * _hash(at)

func _drip_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [
		Vector2(0.5, 0.5), Vector2(0.45, 0.48), Vector2(0.35, 0.34),
		Vector2(0.25, 0.22), Vector2(0.1, 0.125), Vector2(-0.1, 0.09),
		Vector2(-0.25, 0.085), Vector2(-0.32, 0.13), Vector2(-0.38, 0.18),
		Vector2(-0.43, 0.17), Vector2(-0.47, 0.12), Vector2(-0.49, 0.065),
		Vector2(-0.5, 0.0),
	]
	var rounded: Array[Vector2] = []
	for i in profile.size() - 1:
		for half in 2:
			rounded.append(profile[i].cubic_interpolate(
				profile[i + 1], profile[maxi(0, i - 1)],
				profile[mini(profile.size() - 1, i + 2)], half * 0.5))
	rounded.append(profile.back())
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_smooth_group(0)
	for ring in rounded.size() - 1:
		for side in 12:
			var radial_a := Vector3(cos(side * TAU / 12.0), 0, sin(side * TAU / 12.0))
			var radial_b := Vector3(cos((side + 1) * TAU / 12.0), 0, sin((side + 1) * TAU / 12.0))
			var upper := rounded[ring]
			var lower := rounded[ring + 1]
			var a := radial_a * upper.y + Vector3.UP * upper.x
			var b := radial_b * upper.y + Vector3.UP * upper.x
			var c := radial_a * lower.y + Vector3.UP * lower.x
			var d := radial_b * lower.y + Vector3.UP * lower.x
			for point in [a, c, b]:
				builder.add_vertex(point)
			if lower.y > 0.0:
				for point in [b, c, d]:
					builder.add_vertex(point)
	builder.generate_normals()
	builder.index()
	return builder.commit()

func _add_goo_droplets(points: PackedVector3Array, paint: StandardMaterial3D) -> void:
	var drops := CPUParticles3D.new()
	drops.name = "GooDroplets"
	drops.amount = mini(400, points.size() * 2)
	drops.lifetime = 1.4
	drops.local_coords = false
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	drops.emission_points = points
	drops.direction = Vector3.DOWN
	drops.spread = 0.0
	drops.initial_velocity_min = 0.0
	drops.initial_velocity_max = 0.5
	drops.gravity = Vector3(0, -14.0, 0)
	drops.scale_amount_min = 0.7
	drops.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.34
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = paint
	drops.mesh = mesh
	drops.visibility_aabb = AABB(bounds.position - Vector3(10, 30, 10), bounds.size + Vector3(20, 40, 20))
	add_child(drops)

func _add_multimesh(node_name: String, mesh: Mesh, items: Array, shadows := true) -> Node3D:
	# Godot culls a MultiMesh as one object. Course-wide batches submitted every
	# rail segment even though the side camera can only see a few metres.
	var group := Node3D.new()
	group.name = node_name
	var cells: Dictionary = {}
	for item in items:
		var at: Vector3 = item[0].origin
		var key := Vector3i(floori(at.x / RENDER_CELL), floori(at.y / RENDER_CELL), floori(at.z / RENDER_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(item)
	for key: Vector3i in cells:
		var batch: Array = cells[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = batch.size()
		var box: AABB = batch[0][0] * mesh.get_aabb()
		for i in batch.size():
			multi.set_instance_transform(i, batch[i][0])
			multi.set_instance_color(i, (batch[i][1] as Color).srgb_to_linear())
			box = box.merge(batch[i][0] * mesh.get_aabb())
		# Include the animated goo tips beyond their undeformed mesh bounds.
		multi.custom_aabb = box.grow(3.0)
		var node := MultiMeshInstance3D.new()
		node.name = "Cell_%d_%d_%d" % [key.x, key.y, key.z]
		node.multimesh = multi
		if not shadows:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(node)
	add_child(group)
	return group

func _build_collision() -> void:
	var faces := PackedVector3Array()
	for sec: Section in sections:
		for k in sec.points.size() - 1:
			if sec.landable[k] == 0:
				continue
			var a := sec.points[k]
			var b := sec.points[k + 1]
			var side := sec.seg_normals[k].cross(sec.seg_tangents[k]).normalized() * COLLISION_HALF_DEPTH
			faces.append_array([a - side, a + side, b - side, a + side, b + side, b - side])
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
	var quad := QuadMesh.new()
	quad.size = Vector2(bounds.size.x + 400.0, bounds.size.y + 260.0)
	var material := ShaderMaterial.new()
	if course_id == "neon_night":
		material.shader = NEON_BACKDROP
		material.set_shader_parameter("effect_strength", 0.45 if high_contrast else 1.0)
		_neon_backdrop = material
	elif course_id == "the_monopoly":
		material.shader = MONOPOLY_BACKDROP
	else:
		material.shader = Shader.new()
		material.shader.code = BACKDROP_SHADER
		var sky: Array = track.sky
		material.set_shader_parameter("sky_a", sky[0])
		material.set_shader_parameter("sky_b", sky[1])
		material.set_shader_parameter("sky_c", sky[2])
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = quad
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.position = Vector3(bounds.get_center().x, bounds.get_center().y, BACK_Z - 35.0)
	add_child(backdrop)

func _add_gate(spot: Dictionary, node_name: String, text: String, color: Color) -> Node3D:
	var gate := Node3D.new()
	gate.name = node_name
	gate.position = spot.pos
	var paint := _paint(color, 0.35)
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

## A neutral up/down sign just before a junction: hold Up or Down to pick.
func _add_junction_marker(at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Junction"
	label.text = "▲\n▼"
	label.font_size = 72
	label.pixel_size = 0.012
	label.outline_size = 16
	label.line_spacing = -18.0
	label.modulate = Color(1, 1, 1, 0.92)
	add_child(label)
	label.global_position = at + Vector3(0, 3.2, 0.6)

func _add_boost_pad(pad: Dictionary) -> void:
	var smp := sample(pad.sec, pad.s)
	var t: Vector3 = smp.seg_t
	var n: Vector3 = smp.n
	var node := MeshInstance3D.new()
	node.name = "BoostPad"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 0.12, 1.6)
	node.mesh = mesh
	node.material_override = _paint(Color(1.0, 0.55, 0.05), 2.5)
	node.transform = Transform3D(Basis(t, n, t.cross(n).normalized()), smp.pos + n * 0.06)
	add_child(node)
	for k in 2:
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.9, 0.7, 0.05)
		arrow.mesh = prism
		arrow.material_override = _paint(Color(1.0, 0.95, 0.3), 3.0)
		var side := t.cross(n).normalized()
		arrow.transform = Transform3D(Basis(side, t, n), smp.pos + n * 0.14 + t * (k * 0.9 - 0.45))
		add_child(arrow)
