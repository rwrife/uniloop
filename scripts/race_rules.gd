class_name RaceRules
extends RefCounted
## Scene-free race state. Caller supplies elapsed milliseconds and landing measurements.

const RESET_PENALTY_MS := 3000
const QUALITY_PERFECT := 200
const QUALITY_CLEAN := 100
const QUALITY_ROUGH := 25

var checkpoint_count: int
var next_checkpoint := 0
var elapsed_ms := 0
var score := 0
var streak := 0
var resets := 0
var finished := false


func _init(count: int) -> void:
	assert(count > 0)
	checkpoint_count = count


func tick(delta_ms: int) -> void:
	assert(delta_ms >= 0)
	if not finished:
		elapsed_ms += delta_ms


func cross_checkpoint(index: int) -> bool:
	if finished or index != next_checkpoint:
		return false
	next_checkpoint += 1
	return true


func finish() -> bool:
	if finished or next_checkpoint != checkpoint_count:
		return false
	finished = true
	return true


func reset_to_checkpoint() -> int:
	if finished:
		return max(0, next_checkpoint - 1)
	resets += 1
	streak = 0
	elapsed_ms += RESET_PENALTY_MS
	return max(0, next_checkpoint - 1)


func land(vertical_speed: float, tilt_degrees: float) -> String:
	assert(is_finite(vertical_speed) and is_finite(tilt_degrees))
	if finished:
		return "none"
	var impact := absf(vertical_speed)
	var tilt := absf(tilt_degrees)
	if impact <= 6.0 and tilt <= 12.0:
		streak += 1
		score += QUALITY_PERFECT * streak
		return "perfect"
	if impact <= 12.0 and tilt <= 25.0:
		streak += 1
		score += QUALITY_CLEAN * streak
		return "clean"
	streak = 0
	score += QUALITY_ROUGH
	return "rough"


static func medal(time_ms: int, thresholds: Dictionary) -> String:
	# All three course thresholds are inclusive, increasing, and measured in ms.
	if time_ms < 0 or not valid_thresholds(thresholds):
		return "none"
	for tier in ["gold", "silver", "bronze"]:
		if time_ms <= thresholds[tier]:
			return tier
	return "none"


static func valid_thresholds(thresholds: Dictionary) -> bool:
	for tier in ["gold", "silver", "bronze"]:
		if not thresholds.has(tier) or typeof(thresholds[tier]) != TYPE_INT or thresholds[tier] <= 0:
			return false
	return thresholds.gold < thresholds.silver and thresholds.silver < thresholds.bronze


static func unlocked(course_index: int, previous_medals: Array) -> bool:
	if course_index < 0 or course_index > previous_medals.size():
		return false
	if course_index == 0:
		return true
	return previous_medals[course_index - 1] in ["bronze", "silver", "gold"]
