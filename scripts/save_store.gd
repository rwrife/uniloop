class_name SaveStore
extends RefCounted
## Versioned, scene-free save schema: validation, migration, atomic write.

const SCHEMA_VERSION := 3
const MEDALS := ["none", "bronze", "silver", "gold"]
const TEXT_SCALES := [1.0, 1.25, 1.5]
const DEFAULT_SETTINGS := {
	"text_scale": 1.0,
	"high_contrast": false,
	"reduced_shake": false,
	"touch_overlay": true,
	"audio_master": 80,
	"audio_music": 80,
	"audio_sfx": 50,
}


static func default_save() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"records": {},
		"total_score": 0,
		"settings": DEFAULT_SETTINGS.duplicate(true),
	}


## Coerce any settings blob to a valid settings dict. Unknown keys drop,
## invalid values fall back to defaults. Never fails (settings are UX, not records).
static func sanitize_settings(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var data: Dictionary = raw
	if data.get("text_scale") in TEXT_SCALES:
		out.text_scale = float(data["text_scale"])
	for flag in ["high_contrast", "reduced_shake", "touch_overlay"]:
		if typeof(data.get(flag)) == TYPE_BOOL:
			out[flag] = data[flag]
	for key in ["audio_master", "audio_music", "audio_sfx"]:
		var volume := _as_int(data.get(key, -1))
		if volume >= 0 and volume <= 100:
			out[key] = volume
	return out


static func get_settings(save: Dictionary) -> Dictionary:
	return sanitize_settings(save.get("settings"))


## Merge updates into the save's settings and sanitize. Returns the new settings.
static func set_settings(save: Dictionary, updates: Dictionary) -> Dictionary:
	var merged: Dictionary = get_settings(save)
	for key in updates:
		merged[key] = updates[key]
	var clean := sanitize_settings(merged)
	save.settings = clean
	return clean


## Returns {ok: bool, error: String, save: Dictionary}.
static func from_json(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _fail("malformed JSON")
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("not a JSON object")
	var raw: Dictionary = parsed
	if not raw.has("version"):
		return _fail("missing version")
	var version := _as_int(raw["version"])
	if version < 1:
		return _fail("version must be a positive int")
	if version > SCHEMA_VERSION:
		return _fail("save from a newer version (%d)" % version)
	var save: Dictionary = raw.duplicate(true)
	if version == 1:
		var legacy := _validate_v1(save)
		if not legacy.ok:
			return legacy
		save = _migrate_v1_to_v2(save)
	var validated := _validate(save)
	if not validated.ok:
		return validated
	# ponytail: v1/v2 carry no settings; v3 always stores sanitized settings.
	save.settings = sanitize_settings(save.get("settings"))
	save.version = SCHEMA_VERSION
	return {"ok": true, "error": "", "save": save}


static func to_json(save: Dictionary) -> String:
	var out := save.duplicate(true)
	out.version = SCHEMA_VERSION
	return JSON.stringify(out, "\t")


static func record_best(save: Dictionary, course_id: String, time_ms: int, medal: String, score: int) -> void:
	assert(course_id != "" and time_ms >= 0 and score >= 0 and medal in MEDALS)
	var records: Dictionary = save.records
	var prior: Dictionary = records.get(course_id, {})
	var best_medal := _better_medal(str(prior.get("medal", "none")), medal)
	if prior.is_empty() or time_ms < int(prior.best_ms):
		records[course_id] = {"best_ms": time_ms, "medal": best_medal}
	else:
		prior.medal = best_medal
		records[course_id] = prior
	save.total_score = int(save.get("total_score", 0)) + score


static func save_to_path(save: Dictionary, path: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_json(save))
	f.flush()
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK


static func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "error": "", "save": default_save()}
	return from_json(FileAccess.get_file_as_string(path))


## v1 shape: {"version":1,"times":[{"course":id,"best_ms":int,"medal":str}],"total_score":int}
static func _validate_v1(save: Dictionary) -> Dictionary:
	if typeof(save.get("times")) != TYPE_ARRAY:
		return _fail("v1 times must be an array")
	if _as_int(save.get("total_score", 0)) < 0:
		return _fail("v1 total_score must be a non-negative int")
	for entry in save.times:
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail("v1 time entry must be an object")
		if str(entry.get("course", "")) == "":
			return _fail("v1 time entry missing course")
		if _as_int(entry.get("best_ms", -1)) < 0:
			return _fail("v1 best_ms must be a non-negative int")
		if entry.get("medal", "none") not in MEDALS:
			return _fail("v1 has an unknown medal")
	return {"ok": true, "error": "", "save": save}


static func _migrate_v1_to_v2(save: Dictionary) -> Dictionary:
	var out := default_save()
	for entry in save.times:
		var course_id := str(entry["course"])
		var best_ms := _as_int(entry["best_ms"])
		var medal := str(entry.get("medal", "none"))
		var prior: Dictionary = out.records.get(course_id, {})
		var best_medal := _better_medal(str(prior.get("medal", "none")), medal)
		if prior.is_empty() or best_ms < int(prior.best_ms):
			out.records[course_id] = {"best_ms": best_ms, "medal": best_medal}
		else:
			prior.medal = best_medal
			out.records[course_id] = prior
	out.total_score = _as_int(save.get("total_score", 0))
	return out


static func _validate(save: Dictionary) -> Dictionary:
	for key in ["records", "total_score"]:
		if not save.has(key):
			return _fail("missing field %s" % key)
	if typeof(save.records) != TYPE_DICTIONARY:
		return _fail("records must be an object")
	var score := _as_int(save.total_score)
	if score < 0:
		return _fail("total_score must be a non-negative int")
	save.total_score = score
	for course_id in save.records:
		if typeof(course_id) != TYPE_STRING or course_id == "":
			return _fail("record key must be a non-empty string")
		var rec: Variant = save.records[course_id]
		if typeof(rec) != TYPE_DICTIONARY:
			return _fail("%s record must be an object" % course_id)
		var best_ms := _as_int(rec.get("best_ms", -1))
		if best_ms < 0:
			return _fail("%s best_ms must be a non-negative int" % course_id)
		rec.best_ms = best_ms
		if rec.get("medal") not in MEDALS:
			return _fail("%s has an unknown medal" % course_id)
	return {"ok": true, "error": "", "save": save}


static func _as_int(val: Variant) -> int:
	if typeof(val) == TYPE_INT:
		return val
	if typeof(val) == TYPE_FLOAT and is_finite(val) and floorf(val) == val:
		return int(val)
	return -1


static func _better_medal(a: String, b: String) -> String:
	return a if MEDALS.find(a) >= MEDALS.find(b) else b


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "save": {}}
