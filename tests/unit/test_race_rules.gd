extends GutTest

const Rules = preload("res://scripts/race_rules.gd")
const Store = preload("res://scripts/save_store.gd")


func test_checkpoints_timer_finish_and_reset_penalty() -> void:
	var run := Rules.new(3)
	assert_false(run.cross_checkpoint(1))
	assert_eq(run.next_checkpoint, 0)
	run.tick(1000)
	assert_true(run.cross_checkpoint(0))
	assert_false(run.cross_checkpoint(0))
	assert_false(run.finish())
	assert_eq(run.reset_to_checkpoint(), 0)
	assert_eq(run.elapsed_ms, 4000)
	assert_eq(run.resets, 1)
	assert_true(run.cross_checkpoint(1))
	assert_eq(run.reset_to_checkpoint(), 1)
	assert_true(run.cross_checkpoint(2))
	assert_true(run.finish())
	assert_false(run.finish())
	run.tick(1000)
	assert_eq(run.elapsed_ms, 7000)


func test_landing_bands_streak_and_reset() -> void:
	var run := Rules.new(1)
	assert_eq(run.land(6.0, 12.0), "perfect")
	assert_eq(run.land(12.0, 25.0), "clean")
	assert_eq(run.score, 400)
	assert_eq(run.land(12.01, 0.0), "rough")
	assert_eq(run.streak, 0)
	assert_eq(run.score, 425)
	assert_eq(run.land(0.0, 0.0), "perfect")
	run.reset_to_checkpoint()
	assert_eq(run.streak, 0)


func test_medal_boundaries_and_unlocks() -> void:
	var limits := {"gold": 60000, "silver": 75000, "bronze": 90000}
	assert_eq(Rules.medal(60000, limits), "gold")
	assert_eq(Rules.medal(60001, limits), "silver")
	assert_eq(Rules.medal(75000, limits), "silver")
	assert_eq(Rules.medal(75001, limits), "bronze")
	assert_eq(Rules.medal(90001, limits), "none")
	assert_eq(Rules.medal(-1, limits), "none")
	assert_eq(Rules.medal(1, {"gold": 60}), "none")
	assert_true(Rules.unlocked(0, []))
	assert_false(Rules.unlocked(1, ["none"]))
	assert_true(Rules.unlocked(1, ["bronze"]))
	assert_false(Rules.unlocked(2, ["gold", "none"]))
	assert_false(Rules.unlocked(3, ["gold"]))


func test_save_migration_best_record_and_round_trip() -> void:
	var old := '{"version":1,"times":[{"course":"canyon","best_ms":70000,"medal":"silver"}],"total_score":50}'
	var result: Dictionary = Store.from_json(old)
	assert_true(result.ok)
	assert_eq(result.save.version, 2)
	assert_eq(result.save.records.canyon.best_ms, 70000)
	Store.record_best(result.save, "canyon", 80000, "gold", 20)
	assert_eq(result.save.records.canyon.best_ms, 70000)
	assert_eq(result.save.records.canyon.medal, "gold")
	Store.record_best(result.save, "canyon", 65000, "silver", 10)
	assert_eq(result.save.records.canyon.best_ms, 65000)
	assert_eq(result.save.records.canyon.medal, "gold")
	assert_eq(result.save.total_score, 80)
	assert_eq(Store.from_json(Store.to_json(result.save)).save, result.save)
	var duplicates := '{"version":1,"times":[{"course":"canyon","best_ms":70000,"medal":"gold"},{"course":"canyon","best_ms":60000,"medal":"bronze"}]}'
	var migrated: Dictionary = Store.from_json(duplicates)
	assert_true(migrated.ok)
	assert_eq(migrated.save.records.canyon.best_ms, 60000)
	assert_eq(migrated.save.records.canyon.medal, "gold")


func test_corrupt_saves_rejected_without_wiping_file() -> void:
	for text in ["bad JSON", "[]", "{}", '{"version":99,"records":{},"total_score":0}',
		'{"version":2,"records":{"canyon":{"best_ms":-1,"medal":"gold"}},"total_score":0}',
		'{"version":2,"records":{},"total_score":"bad"}',
		'{"version":1,"times":[{"course":"canyon","best_ms":"oops"}]}']:
		assert_false(Store.from_json(text).ok, "expected reject: %s" % text)
	var path := "user://test_race_rules_corrupt.json"
	var original := "broken save"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(original)
	f.close()
	assert_false(Store.load_from_path(path).ok)
	assert_eq(FileAccess.get_file_as_string(path), original)
	DirAccess.remove_absolute(path)


func test_atomic_save_round_trip() -> void:
	var path := "user://test_race_rules_save.json"
	var save: Dictionary = Store.default_save()
	Store.record_best(save, "canyon", 55000, "gold", 200)
	assert_true(Store.save_to_path(save, path))
	assert_true(Store.load_from_path(path).ok)
	assert_eq(Store.load_from_path(path).save, save)
	DirAccess.remove_absolute(path)
