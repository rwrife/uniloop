extends GutTest

const SAVE_PATH := "user://monopoly_test.json"

class CapturedCourse extends CanyonCourse:
	var rail_colors: Array[Color] = []

	func _add_multimesh(node_name: String, mesh: Mesh, items: Array, shadows := true) -> Node3D:
		if node_name in ["Rail", "RailJoints"]:
			for item in items:
				rail_colors.append(item[1])
		return super._add_multimesh(node_name, mesh, items, shadows)


func after_each() -> void:
	get_tree().paused = false
	RaceSetup.track_id = RaceSetup.DEFAULT_TRACK
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _course(reduced := false) -> CapturedCourse:
	var course := CapturedCourse.new()
	course.track_id = "the_monopoly"
	course.reduced_motion = reduced
	add_child_autofree(course)
	return course


func _race(reduced := false) -> Node3D:
	var save := SaveStore.default_save()
	SaveStore.set_settings(save, {"reduced_shake": reduced})
	assert_true(SaveStore.save_to_path(save, SAVE_PATH))
	RaceSetup.track_id = "the_monopoly"
	var race: Node3D = load("res://scenes/practice.tscn").instantiate()
	race.save_path = SAVE_PATH
	race.countdown_enabled = false
	add_child_autofree(race)
	race.set_physics_process(false)
	race.rider.set_physics_process(false)
	return race


func test_monopoly_is_a_complete_catalogued_course() -> void:
	var course := _course()
	assert_eq(course.track.title, "The Monopoly")
	assert_gt(course.loops, 0)
	assert_gt(course.goo_pits, 0)
	assert_gt(course.forks.size(), 0)
	assert_gt(course.gates.size(), 0)
	assert_gt(course.medals.bronze, course.medals.silver)
	assert_gt(course.medals.silver, course.medals.gold)
	assert_gt(course.finish.pos.y, course.start_spot.pos.y)
	assert_true(course.get_node("RibbonCollision/TrackCollider").shape is ConcavePolygonShape3D)


func test_only_rails_and_backdrop_are_grayscale() -> void:
	var course := _course()
	assert_gt(course.rail_colors.size(), 0)
	var darkest := 1.0
	for color in course.rail_colors:
		darkest = minf(darkest, color.r)
		if not is_equal_approx(color.r, color.g) or not is_equal_approx(color.g, color.b):
			fail_test("A rail or joint has a non-gray color")
			return
	assert_almost_eq(darkest, 0.38, 0.001, "even dark rail stripes stand out against the dark plaid")
	assert_almost_eq(course.rail_colors[0].r, 0.72, 0.001, "normal rails use the lighter gray")
	assert_eq(course.get_node("Backdrop").material_override.shader, CanyonCourse.MONOPOLY_BACKDROP)
	assert_false(course.is_processing(), "plaid is static")
	var rail: MultiMeshInstance3D = course.get_node("Rail").get_child(0)
	assert_almost_eq(rail.multimesh.mesh.material.roughness, 0.95, 0.001)
	var green := Color(0.35, 1.0, 0.2)
	assert_eq(course.goo_color(green), green, "slime stays green")
	var gate: StandardMaterial3D = course.get_node("Checkpoint0").get_child(0).material_override
	assert_eq(gate.albedo_color, Color(0.1, 0.85, 0.75), "flags retain original colors")
	var apple: MeshInstance3D = course.apples.remaining[0].get_child(0)
	assert_eq(apple.mesh.surface_get_material(0).albedo_color, MonopolyApples.RED)


func test_apples_have_slender_tapered_fruit_and_a_visible_green_leaf() -> void:
	var apples := _course().apples
	var apple := apples.remaining[0]
	var fruit: MeshInstance3D = apple.get_node("Fruit")
	var leaf: MeshInstance3D = apple.get_node("Leaf")
	var stem: MeshInstance3D = apple.get_node("Stem")
	var bounds := fruit.mesh.get_aabb()
	assert_gt(bounds.size.y, bounds.size.x * 1.15, "fruit is taller than it is wide")
	assert_lt(bounds.size.x, 1.0, "not the old wide, tomato-like paired spheres")
	assert_eq(leaf.mesh.surface_get_material(0).albedo_color, MonopolyApples.LEAF_GREEN)
	assert_gt(MonopolyApples.LEAF_GREEN.g, MonopolyApples.LEAF_GREEN.r)
	assert_gt(leaf.mesh.get_aabb().size.x, 0.5, "leaf reads clearly at gameplay scale")
	assert_gt(leaf.position.y, bounds.end.y, "leaf sits beside the crown's stem")
	assert_gt(stem.position.y, 0.5)
	assert_eq(leaf.mesh.surface_get_material(0).cull_mode, BaseMaterial3D.CULL_DISABLED)
	assert_same(apples.remaining[1].get_node("Fruit").mesh, fruit.mesh, "fruit mesh is shared")
	assert_same(apples.remaining[1].get_node("Leaf").mesh, leaf.mesh, "leaf mesh is shared")


func test_apples_are_scattered_on_rideable_rail_and_clear_of_gates() -> void:
	var course := _course()
	assert_gt(course.apples.remaining.size(), 10, "fruit throughout the course")
	for apple in course.apples.remaining:
		var supported := false
		for i in course.sections.size():
			var section: CanyonCourse.Section = course.sections[i]
			for k in section.points.size() - 1:
				var closest := Geometry3D.get_closest_point_to_segment(apple.position, section.points[k], section.points[k + 1])
				if closest.distance_to(apple.position) < 0.55:
					supported = true
					assert_eq(section.kinds[k], CanyonCourse.NORMAL)
					assert_eq(section.landable[k], 1)
					break
			if supported:
				break
		assert_true(supported, "apple sits just above a rail")
		for gate in course.gates + [course.start_spot, course.finish]:
			assert_gt(apple.position.distance_to(gate.pos), 9.0)


func test_swept_hit_awards_exactly_100_and_cannot_repeat_after_reset() -> void:
	var race := _race()
	var apples: MonopolyApples = race.course.apples
	var count := apples.remaining.size()
	var at := apples.remaining[0].global_position
	race._last_pos = at - Vector3(5, 0, 0)
	race.rider.global_position = at + Vector3(5, 0, 0)
	race._physics_process(1.0 / 60.0)
	assert_eq(race.rules.score, 100, "crossing an apple at speed awards exact bonus")
	assert_eq(apples.remaining.size(), count - 1)
	assert_eq(race.popup.text, "CORPORATE GREED SQUASHED!\n+100")
	assert_true(race.audio._effects.slime_land.playing, "squash follows existing SFX bus")
	var burst: CPUParticles3D = apples.get_node("ApplesauceConfetti")
	assert_true(burst.emitting)
	assert_eq(burst.amount, 40)
	assert_eq(burst.color_initial_ramp.get_color(0), MonopolyApples.SAUCE_COLORS[0])
	race._reset()
	apples.squash_between(at - Vector3(5, 0, 0), at + Vector3(5, 0, 0), 0.65)
	assert_eq(race.rules.score, 100, "reset does not respawn collected apples")


func test_jumping_over_and_passing_on_another_depth_do_not_squash() -> void:
	var apples := _course().apples
	var count := apples.remaining.size()
	var at := apples.remaining[0].global_position
	for offset in [Vector3(0, 4, 0), Vector3(0, 0, 4)]:
		apples.squash_between(at + offset - Vector3(4, 0, 0), at + offset + Vector3(4, 0, 0), 0.65)
	assert_eq(apples.remaining.size(), count)
	assert_null(apples.get_node_or_null("ApplesauceConfetti"))


func test_apple_points_reach_results_and_saved_league_total() -> void:
	var race := _race()
	var at: Vector3 = race.course.apples.remaining[0].global_position
	race.course.apples.squash_between(at, at, race.rider.handling.wheel_radius)
	race.rules.tick(160000)
	for index in race.course.gates.size():
		assert_true(race.rules.cross_checkpoint(index))
	race.rider.speed = race.rider.handling.gate_min_speed + 1.0
	race._on_finish(race.rider)
	assert_true(race.rules.finished)
	assert_eq(race.finish_stats.score, 100)
	assert_true(race.finish_stats.saved)
	var loaded := SaveStore.load_from_path(SAVE_PATH)
	assert_true(loaded.ok)
	assert_eq(loaded.save.total_score, 100)
	assert_eq(loaded.save.records.the_monopoly.best_ms, 160000)
	assert_eq(loaded.save.records.the_monopoly.medal, "silver")


func test_countdown_pause_and_finish_do_not_award_apple_points() -> void:
	var race := _race()
	var at: Vector3 = race.course.apples.remaining[0].global_position
	race._last_pos = at - Vector3(4, 0, 0)
	race.rider.global_position = at + Vector3(4, 0, 0)
	race.racing = false
	race._physics_process(0.016)
	assert_eq(race.rules.score, 0)
	race.racing = true
	race._last_pos = at - Vector3(4, 0, 0)
	get_tree().paused = true
	race._physics_process(0.016)
	assert_eq(race.rules.score, 0)
	get_tree().paused = false
	race.rules.finished = true
	race._physics_process(0.016)
	assert_eq(race.rules.score, 0)


func test_reduced_confetti_pauses_and_frees_after_emission() -> void:
	var apples := _course(true).apples
	var at := apples.remaining[0].global_position
	apples.squash_between(at, at, 0.65)
	var burst: CPUParticles3D = apples.get_node("ApplesauceConfetti")
	assert_eq(burst.amount, 12)
	assert_almost_eq(burst.lifetime, 0.6, 0.001)
	get_tree().paused = true
	assert_false(burst.can_process())
	get_tree().paused = false
	burst.finished.emit()
	await wait_process_frames(2)
	assert_false(is_instance_valid(burst))


func test_other_courses_do_not_spawn_apples() -> void:
	for id in ["sunny_sprint", "canyon_climb", "neon_night", "goo_gauntlet"]:
		var course := CanyonCourse.new()
		course.track_id = id
		add_child_autofree(course)
		assert_null(course.apples, id)


func test_picker_scrolls_horizontally_with_arrows_and_focus_at_all_sizes() -> void:
	var window := get_tree().root
	var original_size := window.size
	for size in [Vector2i(1920, 1080), Vector2i(1152, 648), Vector2i(390, 844), Vector2i(844, 390)]:
		window.size = size
		RaceSetup.track_id = "sunny_sprint"
		await wait_process_frames(3)
		var menu: Control = load("res://scenes/menu.tscn").instantiate()
		menu.auto_launch = false
		add_child_autofree(menu)
		menu._open("track")
		await wait_process_frames(5)
		var scroll: ScrollContainer = menu.panel_body.get_node("TrackScroller")
		var navigation: HBoxContainer = menu.panel.get_node("Content/TrackNavigation")
		assert_eq(scroll.get_child(0).get_child_count(), RaceSetup.TRACKS.size())
		assert_true(scroll.get_child(0) is HBoxContainer)
		assert_true(scroll.follow_focus)
		assert_true(scroll.get_h_scroll_bar().visible, str(size))
		assert_false(scroll.get_v_scroll_bar().visible)
		assert_gte(navigation.global_position.y, menu.panel.global_position.y)
		assert_lte(navigation.get_global_rect().end.y, menu.panel.get_global_rect().end.y)
		assert_true(navigation.get_node("Previous").disabled)
		assert_false(navigation.get_node("Next").disabled)
		navigation.get_node("Next").pressed.emit()
		await wait_process_frames(2)
		assert_gt(scroll.scroll_horizontal, 0)
		menu.cards[-1].grab_focus()
		await wait_process_frames(5)
		var rect: Rect2 = menu.cards[-1].get_global_rect()
		assert_gte(rect.position.x, scroll.global_position.x - 1.0)
		assert_lte(rect.end.x, scroll.get_global_rect().end.x + 1.0)
		assert_true(navigation.get_node("Next").disabled)
		assert_false(navigation.get_node("Previous").disabled)
		assert_eq(menu.cards[-1].find_valid_focus_neighbor(SIDE_LEFT), menu.cards[-2])
		assert_eq(menu.cards[-2].find_valid_focus_neighbor(SIDE_RIGHT), menu.cards[-1])
		assert_eq(menu.back_btn.find_valid_focus_neighbor(SIDE_TOP), menu.cards[-1])
		menu.cards[-1].pressed.emit()
		assert_eq(RaceSetup.track_id, "the_monopoly")
		assert_lte(menu.panel.get_global_rect().end.x, menu.get_viewport_rect().end.x + 1.0)
		menu.queue_free()
		await wait_process_frames(2)
	window.size = original_size


func test_reopening_picker_reveals_selected_monopoly_card() -> void:
	RaceSetup.track_id = "the_monopoly"
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	menu.auto_launch = false
	add_child_autofree(menu)
	menu._open("track")
	await wait_process_frames(6)
	var scroll: ScrollContainer = menu.panel_body.get_node("TrackScroller")
	assert_true(menu.cards[-1].has_focus())
	assert_gt(scroll.scroll_horizontal, 0)
	assert_lte(menu.cards[-1].get_global_rect().end.x, scroll.get_global_rect().end.x + 1.0)
	menu._open("uni")
	assert_null(menu.panel.get_node_or_null("Content/TrackNavigation"), "arrows only appear on track picker")
	assert_eq(menu.back_btn.focus_neighbor_top, NodePath(), "no stale neighbor into removed track cards")
	await wait_process_frames(2)
