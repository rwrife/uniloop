class_name RaceSetup
extends RefCounted
## Unicycle colours, track catalogue and the current race selection, shared
## between the title menu, the pick screens and the race scene.

const UNIS: Array[Dictionary] = [
	{"id": "solar", "name": "Solar Yellow", "frame": Color(0.98, 0.85, 0.1), "seat": Color(0.06, 0.06, 0.07)},
	{"id": "blaze", "name": "Blaze Red", "frame": Color(0.95, 0.16, 0.12), "seat": Color(0.1, 0.06, 0.05)},
	{"id": "surf", "name": "Surf Blue", "frame": Color(0.12, 0.55, 1.0), "seat": Color(0.95, 0.95, 0.98)},
	{"id": "slime", "name": "Slime Green", "frame": Color(0.25, 0.92, 0.2), "seat": Color(0.08, 0.1, 0.06)},
	{"id": "grape", "name": "Grape Purple", "frame": Color(0.62, 0.25, 0.95), "seat": Color(1.0, 0.85, 0.1)},
	{"id": "chrome", "name": "Hot Chrome", "frame": Color(0.88, 0.9, 0.95), "seat": Color(0.95, 0.2, 0.6)},
]

## Legs: R* run right in front, L/G run left behind; each ends in a U-turn or
## a vertical launch. `bumps` lists the (rare) legs ending in a rocket bump.
## Stars (1-3) describe length, speed and difficulty on the pick screen.
const TRACKS: Array[Dictionary] = [
	{
		"id": "sunny_sprint", "title": "Sunny Sprint",
		"blurb": "A quick warm-up climb with gentle forks and a couple of goo pits.",
		"length": 1, "speed": 2, "difficulty": 1,
		"plan": [["RA", "uturn"], ["L", "launch"], ["RA", "uturn"], ["L", "launch"], ["FINAL", ""]],
		"bumps": [2],
		"medals": {"gold": 95000, "silver": 115000, "bronze": 150000},
		"sky": [Color(0.45, 0.62, 0.82), Color(0.55, 0.72, 0.9), Color(0.36, 0.52, 0.72)],
	},
	{
		"id": "canyon_climb", "title": "Canyon Ribbon",
		"blurb": "The classic zig-zag climb: loops, helixes, launches, forks and mud.",
		"length": 2, "speed": 2, "difficulty": 2,
		"plan": [["RA", "uturn"], ["L", "launch"], ["RB", "launch"], ["L", "uturn"],
			["RA", "launch"], ["L", "uturn"], ["RB", "launch"], ["L", "uturn"], ["FINAL", ""]],
		"bumps": [2, 5],
		"medals": {"gold": 180000, "silver": 220000, "bronze": 290000},
		"sky": [Color(0.42, 0.32, 0.30), Color(0.50, 0.40, 0.37), Color(0.35, 0.26, 0.27)],
	},
	{
		"id": "neon_night", "title": "Neon Night",
		"blurb": "Boost pads and back-to-back loops. Flat out, all night.",
		"length": 2, "speed": 3, "difficulty": 2,
		"plan": [["S", "uturn"], ["L", "launch"], ["S", "launch"], ["L", "uturn"], ["S", "uturn"], ["L", "launch"], ["FINAL", ""]],
		"bumps": [0, 4],
		"medals": {"gold": 140000, "silver": 170000, "bronze": 225000},
		"sky": [Color(0.12, 0.08, 0.22), Color(0.17, 0.1, 0.3), Color(0.35, 0.08, 0.4)],
	},
	{
		"id": "goo_gauntlet", "title": "Goo Gauntlet",
		"blurb": "The long one. Goo everywhere, extra forks, rocket bumps. Experts only.",
		"length": 3, "speed": 1, "difficulty": 3,
		"plan": [["RA", "uturn"], ["G", "launch"], ["RB", "launch"], ["L", "uturn"], ["RA", "launch"],
			["G", "uturn"], ["RB", "launch"], ["G", "uturn"], ["RA", "launch"], ["L", "uturn"], ["FINAL", ""]],
		"bumps": [1, 4, 8],
		"medals": {"gold": 255000, "silver": 300000, "bronze": 400000},
		"sky": [Color(0.3, 0.36, 0.2), Color(0.38, 0.44, 0.24), Color(0.22, 0.3, 0.14)],
	},
]
const DEFAULT_TRACK := "canyon_climb"

static var uni_index := 0
static var track_id := DEFAULT_TRACK


static func track(id: String = "") -> Dictionary:
	var want := track_id if id == "" else id
	for t in TRACKS:
		if t.id == want:
			return t
	return TRACKS[1]


static func uni() -> Dictionary:
	return UNIS[clampi(uni_index, 0, UNIS.size() - 1)]
