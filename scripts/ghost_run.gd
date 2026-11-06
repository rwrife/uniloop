class_name GhostRun
extends RefCounted
## Inputs, not transforms. Increment REVISION whenever course/handling simulation
## changes. Incompatible ghosts drop without discarding local times or medals.
const REVISION := 3
const HZ := 60
const DT := 1.0 / HZ
const MAX_FRAMES := HZ * 60 * 20
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"flip_back", &"roll_forward",
	&"jump", &"brake", &"zflip_left", &"zflip_right", &"tabletop"]
# Nine byte strengths, effective jump edge, reset checkpoint (-2 = no reset).
const FRAME_SIZE := 11
var frames: Array = []
var overflow := false

static func capture(rider: WheelRider) -> Array:
	var frame: Array = []
	for action in ACTIONS:
		frame.append(roundi(Input.get_action_strength(action) * 255.0))
	frame.append(1 if rider._jump_just_pressed() else 0)
	frame.append(-2)
	return frame

func append(frame: Array) -> void:
	if frames.size() >= MAX_FRAMES:
		overflow = true
		return
	frames.append(frame.duplicate())

func reset_at(gate: int) -> void:
	if not frames.is_empty() and not overflow:
		frames[-1][10] = gate

func finish(course_id: String, time_ms: int) -> Dictionary:
	if overflow or frames.is_empty():
		return {}
	var out := {"revision": REVISION, "course": course_id, "hz": HZ,
		"time_ms": time_ms, "frames": frames.duplicate(true)}
	out.checksum = checksum(out)
	return out if valid(out, course_id, time_ms) else {}

static func checksum(data: Dictionary) -> String:
	var canonical := normalized(data)
	return JSON.stringify([canonical.revision, canonical.course, canonical.hz,
		canonical.time_ms, canonical.frames]).sha256_text()

## JSON reads numbers as floats; canonical integers keep checksums and stored
## controls identical before and after a disk round trip.
static func normalized(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for key in ["revision", "hz", "time_ms"]:
		out[key] = int(out[key])
	for frame in out.frames:
		for i in frame.size():
			frame[i] = int(frame[i])
	return out

static func valid(raw: Variant, course_id: String, best_ms: int) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = raw
	for key in ["revision", "hz", "time_ms"]:
		var value: Variant = data.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or floorf(float(value)) != float(value):
			return false
	if typeof(data.get("course")) != TYPE_STRING:
		return false
	if data.revision != REVISION or data.course != course_id or data.hz != HZ or data.time_ms != best_ms:
		return false
	if not RaceSetup.TRACKS.any(func(t: Dictionary) -> bool: return t.id == course_id):
		return false
	if typeof(data.get("frames")) != TYPE_ARRAY or data.frames.is_empty() or data.frames.size() > MAX_FRAMES:
		return false
	var resets := 0
	var gates: int = RaceSetup.track(course_id).plan.size()
	for frame in data.frames:
		if typeof(frame) != TYPE_ARRAY or frame.size() != FRAME_SIZE:
			return false
		for i in FRAME_SIZE:
			if typeof(frame[i]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(frame[i])) or floorf(float(frame[i])) != float(frame[i]):
				return false
			if i < 9 and (frame[i] < 0 or frame[i] > 255):
				return false
		if int(frame[9]) not in [0, 1] or frame[10] < -2 or frame[10] >= gates:
			return false
		if frame[10] != -2:
			resets += 1
	var expected_ms := int(data.frames.size() * 1000.0 / HZ) + resets * RaceRules.RESET_PENALTY_MS
	return best_ms == expected_ms and typeof(data.get("checksum")) == TYPE_STRING and data.checksum == checksum(data)
