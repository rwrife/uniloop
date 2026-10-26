extends GutTest

const MenuScene := preload("res://scenes/menu.tscn")


func test_title_zoom_runs_on_rendered_texture_without_resizing_control() -> void:
	var menu: Control = MenuScene.instantiate()
	add_child_autofree(menu)
	assert_eq(menu.background.scale, Vector2.ONE)
	assert_true(menu.background.material is ShaderMaterial)
	var code := (menu.background.material as ShaderMaterial).shader.code
	assert_true(code.contains("zoom = 1.04"))
	assert_true(code.contains("sin(TIME * (3.14159265359 / 6.0))"), "period is centered on 12 seconds")
	assert_eq(menu.background.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED)
