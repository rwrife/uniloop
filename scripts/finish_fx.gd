class_name FinishFX
extends Control
## Full-screen finish celebration drawn behind the stats card: a spinning
## sunburst, two waving checkered flags and a confetti shower.

const COLS := 9
const ROWS := 6
const CONFETTI := 160
const COLORS := [Color("ffd60a"), Color("ff3fa4"), Color("51e1eb"), Color("7cff6b"), Color("ff9f1c"), Color("f4faff")]

var time := 0.0
var _bits: Array[Dictionary] = []


func _init() -> void:
	name = "FinishFX"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func start() -> void:
	time = 0.0
	_bits.clear()
	var area := size if size.x > 0.0 else get_viewport_rect().size
	for i in CONFETTI:
		var left := i % 2 == 0
		_bits.append({
			"p": Vector2(area.x * (0.12 if left else 0.88), area.y * 0.3),
			"v": Vector2(randf_range(80, 620) * (1 if left else -1), randf_range(-900, -250)),
			"r": randf() * TAU,
			"spin": randf_range(-9, 9),
			"c": COLORS[i % COLORS.size()],
			"s": randf_range(7, 14),
			"phase": randf() * TAU,
		})
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	for bit in _bits:
		bit.v.y = minf(bit.v.y + 900.0 * delta, 240.0)
		bit.v.x *= 1.0 - minf(1.0, 1.6 * delta)
		bit.p += (bit.v + Vector2(sin(time * 3.0 + bit.phase) * 60.0, 0.0)) * delta
		bit.r += bit.spin * delta
		if bit.p.y > size.y + 20.0:
			bit.p = Vector2(randf() * size.x, -20.0)
			bit.v = Vector2(randf_range(-40, 40), randf_range(60, 200))
	queue_redraw()


func _draw() -> void:
	var c := size * Vector2(0.5, 0.45)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.01, 0.15, 0.72))
	var reach := size.length()
	var rays := 18
	for i in rays:
		var a := time * 0.25 + TAU * i / rays
		var w := TAU / rays * 0.5
		var tint := Color(1.0, 0.84, 0.04, 0.16) if i % 2 == 0 else Color(1.0, 0.25, 0.64, 0.12)
		draw_colored_polygon(PackedVector2Array([c,
			c + Vector2.from_angle(a - w * 0.5) * reach,
			c + Vector2.from_angle(a + w * 0.5) * reach]), tint)
	var flag := Vector2(minf(size.x * 0.24, 330.0), minf(size.y * 0.22, 220.0))
	_draw_flag(Vector2(size.x * 0.06, size.y * 0.12), flag, 1.0)
	_draw_flag(Vector2(size.x * 0.94, size.y * 0.12), flag, -1.0)
	for bit in _bits:
		var flutter := absf(cos(time * 7.0 + bit.phase))
		draw_set_transform(bit.p, bit.r, Vector2(1.0, maxf(0.15, flutter)))
		draw_rect(Rect2(Vector2(-bit.s, -bit.s * 0.5), Vector2(bit.s * 2.0, bit.s)), bit.c)
	draw_set_transform(Vector2.ZERO)


## A pole at `top` with a cloth of `cloth` size waving out in `dir` (+1 right, -1 left).
func _draw_flag(top: Vector2, cloth: Vector2, dir: float) -> void:
	var pole_h := cloth.y * 2.6
	var pole_w := maxf(8.0, cloth.y * 0.06)
	draw_rect(Rect2(top + Vector2(-pole_w * 0.5 + 3, 4), Vector2(pole_w, pole_h)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(top + Vector2(-pole_w * 0.5, 0), Vector2(pole_w, pole_h)), Color("0d0418"))
	draw_rect(Rect2(top + Vector2(-pole_w * 0.5 + 2, 2), Vector2(pole_w - 4, pole_h - 4)), Color("c9d4e6"))
	draw_circle(top, pole_w * 1.1, Color("0d0418"))
	draw_circle(top, pole_w * 0.85, Color("ffd60a"))
	var grid: Array[PackedVector2Array] = []
	for i in COLS + 1:
		var row := PackedVector2Array()
		var u := float(i) / COLS
		for j in ROWS + 1:
			var v := float(j) / ROWS
			var wave := sin(u * 5.5 - time * 7.0 + v * 0.8) * cloth.y * 0.13 * u
			var tug := cos(u * 5.5 - time * 7.0) * cloth.x * 0.025 * u
			row.append(top + Vector2(dir * (u * cloth.x - tug), pole_w + v * cloth.y + wave))
		grid.append(row)
	var outline := PackedVector2Array()
	for i in COLS + 1:
		outline.append(grid[i][0])
	for j in ROWS + 1:
		outline.append(grid[COLS][j])
	for i in range(COLS, -1, -1):
		outline.append(grid[i][ROWS])
	for j in range(ROWS, -1, -1):
		outline.append(grid[0][j])
	draw_polyline(outline, Color("0d0418"), maxf(5.0, pole_w * 0.7), true)
	for i in COLS:
		var u := float(i) / COLS
		var shade := 0.78 + 0.22 * cos(u * 5.5 - time * 7.0)
		for j in ROWS:
			var base := Color.WHITE if (i + j) % 2 == 0 else Color("16161c")
			var col := base * shade
			col.a = 1.0
			draw_colored_polygon(PackedVector2Array([grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]), col)
