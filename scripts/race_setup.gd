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
		"blurb": "Gentle forks and goo pits. A golden trampoline launches you high for tricks.",
		"signature": {"id": "trampoline", "name": "TRAMPOLINE", "hint": "Ride on to launch high. Land level!"},
		"length": 1, "speed": 2, "difficulty": 1,
		"plan": [["RA", "uturn"], ["L", "launch"], ["RA", "uturn"], ["L", "launch"], ["FINAL", ""]],
		"bumps": [2],
		"medals": {"gold": 95000, "silver": 115000, "bronze": 150000},
		"sky": [Color(0.45, 0.62, 0.82), Color(0.55, 0.72, 0.9), Color(0.36, 0.52, 0.72)],
	},
	{
		"id": "canyon_climb", "title": "Canyon Ribbon",
		"blurb": "Loops, launches and mud. Optional beam corkscrew: Up enters, Up/Down pumps; hop off on top.",
		"signature": {"id": "corkscrew", "name": "BEAM CORKSCREW", "hint": "Up enters; Up/Down pumps.\nHop on top; side/underside exits fall."},
		"length": 2, "speed": 2, "difficulty": 2,
		"plan": [["RA", "uturn"], ["L", "launch"], ["RB", "launch"], ["L", "uturn"],
			["RA", "launch"], ["L", "uturn"], ["RB", "launch"], ["L", "uturn"], ["FINAL", ""]],
		"bumps": [2, 5],
		"medals": {"gold": 180000, "silver": 220000, "bronze": 290000},
		"sky": [Color(0.42, 0.32, 0.30), Color(0.50, 0.40, 0.37), Color(0.35, 0.26, 0.27)],
	},
	{
		"id": "neon_night", "title": "Neon Night",
		"blurb": "Boosts and loops. Brake through the flux gate for a charge; unbraked hits drain speed.",
		"signature": {"id": "flux_gate", "name": "FLUX GATE", "hint": "Brake through for BOOST.\nOtherwise lose speed; hop to avoid."},
		"length": 2, "speed": 3, "difficulty": 2,
		"plan": [["S", "uturn"], ["L", "launch"], ["S", "launch"], ["L", "uturn"], ["S", "uturn"], ["L", "launch"], ["FINAL", ""]],
		"bumps": [0, 4],
		"medals": {"gold": 140000, "silver": 170000, "bronze": 225000},
		"sky": [Color(0.12, 0.08, 0.22), Color(0.17, 0.1, 0.3), Color(0.35, 0.08, 0.4)],
	},
	{
		"id": "goo_gauntlet", "title": "Goo Gauntlet",
		"blurb": "Goo, forks and rocket bumps. Hop over the binding bubble or get stuck until it pops.",
		"signature": {"id": "binding_bubble", "name": "BINDING BUBBLE", "hint": "Hop over, or get stuck for 0.8s.\nIt pops after one hit."},
		"length": 3, "speed": 1, "difficulty": 3,
		"plan": [["RA", "uturn"], ["G", "launch"], ["RB", "launch"], ["L", "uturn"], ["RA", "launch"],
			["G", "uturn"], ["RB", "launch"], ["G", "uturn"], ["RA", "launch"], ["L", "uturn"], ["FINAL", ""]],
		"bumps": [1, 4, 8],
		"medals": {"gold": 255000, "silver": 300000, "bronze": 400000},
		"sky": [Color(0.3, 0.36, 0.2), Color(0.38, 0.44, 0.24), Color(0.22, 0.3, 0.14)],
	},
	{
		"id": "the_monopoly", "title": "The Monopoly",
		"blurb": "Corporate gray. Smash the quota crate at a speed cost; squash red apples for 100 points.",
		"signature": {"id": "quota_crate", "name": "QUOTA CRATE", "hint": "Smash through: lose 45% speed.\nHop over to keep your momentum."},
		"length": 2, "speed": 2, "difficulty": 2,
		"plan": [["RA", "uturn"], ["L", "launch"], ["RB", "launch"], ["L", "uturn"],
			["RA", "uturn"], ["L", "launch"], ["FINAL", ""]],
		"bumps": [2, 4],
		"medals": {"gold": 145000, "silver": 180000, "bronze": 240000},
		"sky": [Color(0.32, 0.32, 0.32), Color(0.40, 0.40, 0.40), Color(0.24, 0.24, 0.24)],
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
