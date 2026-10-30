extends Node
## Scene-owned playback: optional assets stay silent, scene exit stops everything.

const MUSIC := {
	"title": "res://assets/audio/music/title.ogg",
	"race": "res://assets/audio/music/race_loop.ogg",
}
const SFX := {
	"countdown_tick": "res://assets/audio/sfx/countdown_tick.wav",
	"countdown_go": "res://assets/audio/sfx/countdown_go.wav",
	"finish": "res://assets/audio/sfx/finish.wav",
	"crash": "res://assets/audio/sfx/crash.wav",
	"jump": "res://assets/audio/sfx/jump.wav",
	"land_clean": "res://assets/audio/sfx/land_clean.wav",
	"slime_land": "res://assets/audio/sfx/slime_land.wav",
	"boost": "res://assets/audio/sfx/boost.wav",
}

var current_music := ""
var _streams: Dictionary = {}
var _paused := false
var _music: AudioStreamPlayer
var _effects: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = &"Music"
	add_child(_music)
	for cue in SFX:
		var player := AudioStreamPlayer.new()
		player.name = cue
		player.bus = &"SFX"
		player.max_polyphony = 4
		player.stream = _load_stream(SFX[cue])
		add_child(player)
		_effects[cue] = player


func _load_stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


func play_music(cue: String) -> void:
	if _paused:
		return
	current_music = cue
	_music.stop()
	var stream := _load_stream(MUSIC[cue])
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music.stream = stream
	if stream != null:
		_music.play()


func play_sfx(cue: String) -> void:
	if _paused:
		return
	var player: AudioStreamPlayer = _effects[cue]
	if player.stream != null:
		player.play()


func set_paused(enabled: bool) -> void:
	_paused = enabled
	_music.stream_paused = enabled
	if enabled:
		for player: AudioStreamPlayer in _effects.values():
			player.stop()


func stop_all() -> void:
	current_music = ""
	_music.stop()
	for player: AudioStreamPlayer in _effects.values():
		player.stop()


func _exit_tree() -> void:
	stop_all()
