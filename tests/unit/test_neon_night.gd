extends GutTest

class CapturedCourse extends CanyonCourse:
	var first_rail_color: Color

	func _add_multimesh(node_name: String, mesh: Mesh, items: Array, shadows := true) -> Node3D:
		if node_name == "Rail":
			# The headless dummy renderer cannot read back MultiMesh colors.
			first_rail_color = items[0][1]
		return super._add_multimesh(node_name, mesh, items, shadows)

func _course(id: String, reduced := false, contrast := false) -> CapturedCourse:
	var course := CapturedCourse.new()
	course.track_id = id
	course.reduced_motion = reduced
	course.high_contrast = contrast
	add_child_autofree(course)
	return course

func after_each() -> void:
	get_tree().paused = false
	RaceSetup.track_id = RaceSetup.DEFAULT_TRACK

func test_neon_rail_has_emissive_texture_and_distinct_hazards() -> void:
	var course := _course("neon_night")
	var rail: MultiMeshInstance3D = course.get_node("Rail").get_child(0)
	assert_eq(rail.multimesh.mesh.material.shader, CanyonCourse.NEON_RAIL)
	assert_eq(course.first_rail_color, CanyonCourse.NEON_KIND_COLORS[CanyonCourse.NORMAL][0])
	assert_ne(CanyonCourse.NEON_KIND_COLORS[CanyonCourse.NORMAL], CanyonCourse.NEON_KIND_COLORS[CanyonCourse.TURN])
	assert_gt(CanyonCourse.NEON_KIND_COLORS[CanyonCourse.HAZARD][0].r, 0.9)
	assert_gt(CanyonCourse.NEON_KIND_COLORS[CanyonCourse.HAZARD][1].g, 0.9)
	assert_true(course.get_node("RibbonCollision/TrackCollider").shape is ConcavePolygonShape3D)

func test_other_tracks_keep_their_original_material_and_palette() -> void:
	for id in ["sunny_sprint", "canyon_climb", "goo_gauntlet"]:
		var course := _course(id)
		var rail: MultiMeshInstance3D = course.get_node("Rail").get_child(0)
		assert_true(rail.multimesh.mesh.material is StandardMaterial3D, id)
		assert_eq(course.first_rail_color, CanyonCourse.KIND_COLORS[CanyonCourse.NORMAL][0], id)
		assert_ne(course.get_node("Backdrop").material_override.shader, CanyonCourse.NEON_BACKDROP, id)
		assert_false(course.is_processing(), id)

func test_neon_animation_uses_pausable_clock_not_shader_time() -> void:
	var course := _course("neon_night")
	var material: ShaderMaterial = course.get_node("Backdrop").material_override
	assert_eq(material.shader, CanyonCourse.NEON_BACKDROP)
	assert_lt(course.get_node("Backdrop").position.z, CanyonCourse.BACK_Z)
	assert_eq(course.process_mode, Node.PROCESS_MODE_PAUSABLE)
	assert_true(course.is_processing())
	course._process(0.5)
	assert_almost_eq(float(material.get_shader_parameter("motion_time")), 0.5, 0.001)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(float(material.get_shader_parameter("motion_time")), 0.5, "background animates during gameplay")
	get_tree().paused = true
	assert_false(course.can_process(), "background stops even under an always-processing race parent")
	var paused_time: float = material.get_shader_parameter("motion_time")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(float(material.get_shader_parameter("motion_time")), paused_time, "pause freezes rendered animation time")
	assert_false(material.shader.code.contains("TIME"), "shader cannot animate independently of the course")

func test_reduced_motion_freezes_background_and_contrast_dims_it() -> void:
	var course := _course("neon_night", true, true)
	var material: ShaderMaterial = course.get_node("Backdrop").material_override
	assert_false(course.is_processing())
	assert_eq(material.get_shader_parameter("motion_time"), null, "shader keeps its static default")
	assert_almost_eq(float(material.get_shader_parameter("effect_strength")), 0.45, 0.001)

func test_race_passes_saved_accessibility_settings_to_neon_course() -> void:
	var path := "user://neon_accessibility_test.json"
	var save := SaveStore.default_save()
	SaveStore.set_settings(save, {"reduced_shake": true, "high_contrast": true})
	assert_true(SaveStore.save_to_path(save, path))
	RaceSetup.track_id = "neon_night"
	var race: Node3D = load("res://scenes/practice.tscn").instantiate()
	race.save_path = path
	race.countdown_enabled = false
	add_child_autofree(race)
	assert_true(race.course.reduced_motion)
	assert_true(race.course.high_contrast)
	assert_false(race.course.is_processing())
	DirAccess.remove_absolute(path)
