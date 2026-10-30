extends Node
## Scene-owned playback: optional assets stay silent, scene exit stops everything.

const CHECKPOINT_BOOM := preload("res://assets/audio/sfx/checkpoint_boom.wav")
const MUSIC := {
	"title": "res://assets/audio/music/title.ogg",
	"race": "res://assets/audio/music/race_theme.ogg",
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
	"checkpoint": "res://assets/audio/sfx/checkpoint_boom.wav",
}
const UI_SFX := {
	"ui_tick": "res://assets/audio/sfx/ui_tick.wav",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
}
const FINISH_CROWD := "res://assets/audio/sfx/finish_crowd.mp3"

var current_music := ""
var _streams: Dictionary = {}
var _paused := false
var _music: AudioStreamPlayer
var _effects: Dictionary = {}
var _crowd: AudioStreamPlayer
var _crowd_fade: Tween
var _ui_root: Node
var _ui_viewport: Viewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = &"Music"
	add_child(_music)
	_crowd = AudioStreamPlayer.new()
	_crowd.name = "FinishCrowd"
	_crowd.bus = &"SFX"
	_crowd.stream = _load_stream(FINISH_CROWD)
	if _crowd.stream is AudioStreamMP3:
		_crowd.stream.loop = false
	add_child(_crowd)
	for cue in SFX:
		var player := AudioStreamPlayer.new()
		player.name = cue
		player.bus = &"SFX"
		player.volume_db = -6.0
		player.max_polyphony = 4
		if cue == "checkpoint":
			player.volume_db = -9.0
			player.max_polyphony = 1
		player.stream = CHECKPOINT_BOOM if cue == "checkpoint" else _load_stream(SFX[cue])
		add_child(player)
		_effects[cue] = player
	_ui_root = get_parent()
	_ui_viewport = get_viewport()
	for cue in UI_SFX:
		_load_stream(UI_SFX[cue])
	_ui_viewport.gui_focus_changed.connect(_on_ui_focus_changed)
	get_tree().node_added.connect(_watch_ui_node)
	for node in _ui_root.find_children("*", "BaseButton", true, false):
		_watch_ui_node(node)


func _watch_ui_node(node: Node) -> void:
	if node is BaseButton and _ui_root.is_ancestor_of(node):
		var callback := play_ui.bind("ui_confirm")
		if not node.pressed.is_connected(callback):
			node.pressed.connect(callback)


func _on_ui_focus_changed(control: Control) -> void:
	if _ui_root.is_ancestor_of(control):
		play_ui("ui_tick")


func play_ui(cue: String) -> void:
	var stream := _load_stream(UI_SFX[cue])
	if stream == null:
		return
	# Tiny UI cues survive scene changes and keep working on the paused menu.
	var player := AudioStreamPlayer.new()
	player.name = "MenuCue"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = &"SFX"
	player.volume_db = -12.0 if cue == "ui_tick" else -8.0
	player.stream = stream
	_ui_viewport.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


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
		stream.loop = cue != "race"
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED if cue == "race" else AudioStreamWAV.LOOP_FORWARD
	_music.stream = stream
	if stream != null:
		_music.play()


func play_sfx(cue: String) -> void:
	if _paused:
		return
	var player: AudioStreamPlayer = _effects[cue]
	if player.stream != null:
		player.play()


func play_finish() -> void:
	if _paused:
		return
	stop_all()
	play_sfx("finish")
	if _crowd.stream != null:
		_crowd.volume_db = -36.0
		_crowd.play()
		_crowd_fade = create_tween()
		_crowd_fade.tween_property(_crowd, "volume_db", -14.0, 0.6)


func set_paused(enabled: bool) -> void:
	_paused = enabled
	_music.stream_paused = enabled
	_crowd.stream_paused = enabled
	if _crowd_fade != null and _crowd_fade.is_valid():
		if enabled:
			_crowd_fade.pause()
		else:
			_crowd_fade.play()
	if enabled:
		for player: AudioStreamPlayer in _effects.values():
			player.stop()


func stop_all() -> void:
	current_music = ""
	_music.stop()
	_crowd.stop()
	if _crowd_fade != null:
		_crowd_fade.kill()
		_crowd_fade = null
	for player: AudioStreamPlayer in _effects.values():
		player.stop()


func _exit_tree() -> void:
	if _ui_viewport != null and _ui_viewport.gui_focus_changed.is_connected(_on_ui_focus_changed):
		_ui_viewport.gui_focus_changed.disconnect(_on_ui_focus_changed)
	if get_tree().node_added.is_connected(_watch_ui_node):
		get_tree().node_added.disconnect(_watch_ui_node)
	stop_all()
