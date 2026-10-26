extends SceneTree
## Capture real desktop scenes on macOS at an App Store accepted resolution.
const OUT := "res://AppStore/screenshots/macos/"

func _initialize() -> void:
	call_deferred("capture")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func shot(filename: String) -> void:
	await frames(20)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.get_size() == Vector2i(2560, 1600), "Unexpected screenshot size")
	image.convert(Image.FORMAT_RGB8)
	assert(image.save_png(OUT + filename + ".png") == OK)
	print("CAPTURE ", filename, " ", image.get_size())

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(2560, 1600)
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await frames(30)
	await shot("07-title-screen")
	menu._open("uni")
	await shot("05-choose-your-wheel")
	menu._open("track")
	await shot("06-four-original-tracks")
	menu.queue_free()
	await frames(2)
	var names := ["01-canyon-ribbon", "02-neon-night", "03-sunny-sprint", "04-goo-gauntlet"]
	var tracks := ["canyon_climb", "neon_night", "sunny_sprint", "goo_gauntlet"]
	for index in tracks.size():
		RaceSetup.track_id = tracks[index]
		RaceSetup.uni_index = [0, 4, 2, 3][index]
		var race = load("res://scenes/practice.tscn").instantiate()
		race.countdown_enabled = false
		race.save_path = "user://macos_appstore_capture.json"
		root.add_child(race)
		race._set_paused(false)
		await frames(3)
		var section := 0
		var distance: float = [75.0, 93.0, 125.0, 80.0][index]
		if index == 3:
			for si in race.course.sections.size():
				var sec = race.course.sections[si]
				var found := false
				for ki in sec.kinds.size():
					if sec.kinds[ki] == CanyonCourse.GOO:
						section = si
						distance = sec.cum[ki] + 3.0
						found = true
						break
				if found:
					break
		race.rider.place_on(section, distance)
		race.rider.process_mode = Node.PROCESS_MODE_DISABLED
		race._snap_camera()
		await shot(names[index])
		race.queue_free()
		await frames(2)
	quit()
