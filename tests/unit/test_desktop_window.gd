extends GutTest

const WINDOW := preload("res://scripts/desktop_window.gd")


func test_startup_sizing_is_registered_once_as_an_autoload() -> void:
	assert_eq(ProjectSettings.get_setting("autoload/DesktopWindow"), "*res://scripts/desktop_window.gd")


func test_only_windowed_windows_and_macos_are_resized() -> void:
	for platform in ["Windows", "macOS"]:
		assert_true(WINDOW.should_resize(platform, "native", Window.MODE_WINDOWED))
		assert_false(WINDOW.should_resize(platform, "headless", Window.MODE_WINDOWED))
		for mode in [Window.MODE_MINIMIZED, Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			assert_false(WINDOW.should_resize(platform, "native", mode))
	for platform in ["Linux", "Android", "iOS", "Web"]:
		assert_false(WINDOW.should_resize(platform, "native", Window.MODE_WINDOWED))


func test_initial_size_fits_three_quarters_and_preserves_exact_16_by_9() -> void:
	for usable in [
		Vector2i(1920, 1080), Vector2i(1920, 1040), Vector2i(2560, 1600),
		Vector2i(3440, 1440), Vector2i(1080, 1920), Vector2i(1366, 728),
		Vector2i(3840, 2160), Vector2i(800, 600)
	]:
		var size := WINDOW.initial_size(usable)
		assert_gt(size.x, 0)
		assert_gt(size.y, 0)
		assert_eq(size.x * 9, size.y * 16, "exact 16:9 for %s" % usable)
		assert_lte(float(size.x), usable.x * 0.75)
		assert_lte(float(size.y), usable.y * 0.75)
		assert_true(
			size.x + 16 > usable.x * 0.75 or size.y + 9 > usable.y * 0.75,
			"largest integer 16:9 size inside the 75%% bounds for %s" % usable
		)
	assert_eq(WINDOW.initial_size(Vector2i(1920, 1080)), Vector2i(1440, 810))
	assert_eq(WINDOW.initial_size(Vector2i(2560, 1600)), Vector2i(1920, 1080))


func test_centering_respects_taskbars_and_offset_monitors() -> void:
	for usable in [
		Rect2i(0, 40, 1920, 1040), Rect2i(-1920, 0, 1920, 1080),
		Rect2i(1920, -200, 2560, 1600), Rect2i(0, 0, 1365, 767)
	]:
		var size := WINDOW.initial_size(usable.size)
		var position := WINDOW.centered_position(usable, size)
		var leading: Vector2i = position - usable.position
		var trailing: Vector2i = usable.end - (position + size)
		assert_lte(absi(leading.x - trailing.x), 1)
		assert_lte(absi(leading.y - trailing.y), 1)
		assert_true(usable.encloses(Rect2i(position, size)))
