extends Node
## AudioBus — Autoload singleton for WARBAND's audio system.
## Manages layered music tracks and one-shot SFX via manifest at data/audio.json.
## Crossfades music with a 1-second linear fade using two AudioStreamPlayer nodes.
## All asset paths are manifest-driven; missing files log a warning and skip silently.

const MANIFEST_PATH := "res://data/audio.json"
const FADE_DURATION := 1.0

const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer

var _sfx_pool: Dictionary = {}  # event_name -> AudioStreamPlayer

var _music_map: Dictionary = {}
var _sfx_map: Dictionary = {}

var _fade_tween: Tween


func _ready() -> void:
	_build_bus_layout()
	_create_players()
	_load_manifest()


func _build_bus_layout() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)


func _create_players() -> void:
	_player_a = AudioStreamPlayer.new()
	_player_a.bus = BUS_MUSIC
	_player_a.volume_db = 0.0
	add_child(_player_a)
	_player_b = AudioStreamPlayer.new()
	_player_b.bus = BUS_MUSIC
	_player_b.volume_db = -80.0
	add_child(_player_b)
	_active_player = _player_a


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		Console.warn("AudioBus: manifest not found at %s" % MANIFEST_PATH, "audio")
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		Console.warn("AudioBus: cannot open manifest", "audio")
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		Console.warn("AudioBus: manifest parse failed", "audio")
		return
	var parsed_dict: Dictionary = parsed
	var music_entries: Array = parsed_dict.get("music", [])
	for entry: Dictionary in music_entries:
		var n: String = String(entry.get("name", ""))
		var p: String = String(entry.get("path", ""))
		if n != "" and p != "":
			_music_map[n] = p
	var sfx_entries: Array = parsed_dict.get("sfx", [])
	for entry: Dictionary in sfx_entries:
		var n: String = String(entry.get("name", ""))
		var p: String = String(entry.get("path", ""))
		if n != "" and p != "":
			_sfx_map[n] = p
	Console.info("AudioBus: loaded %d music, %d sfx" % [_music_map.size(), _sfx_map.size()], "audio")


## Crossfades to a named music track. No-op if missing or same.
func play_music(track_name: String) -> void:
	if not _music_map.has(track_name):
		Console.warn("AudioBus: unknown music track '%s'" % track_name, "audio")
		return
	var path: String = _music_map[track_name]
	if not ResourceLoader.exists(path):
		# Silent miss — assets not shipped in this build. Don't spam warnings.
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var incoming: AudioStreamPlayer = _player_b if _active_player == _player_a else _player_a
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(_active_player, "volume_db", -80.0, FADE_DURATION)
	_fade_tween.tween_property(incoming, "volume_db", 0.0, FADE_DURATION)
	var outgoing: AudioStreamPlayer = _active_player
	_active_player = incoming
	_fade_tween.finished.connect(func() -> void:
		outgoing.stop()
		outgoing.volume_db = -80.0
	)


func stop_music() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_player_a.stop()
	_player_b.stop()


## Plays a one-shot SFX. Missing files silently skip.
func play_sfx(event: String) -> void:
	if not _sfx_map.has(event):
		return
	var path: String = _sfx_map[event]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if not _sfx_pool.has(event):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool[event] = p
	var player: AudioStreamPlayer = _sfx_pool[event]
	player.stream = stream
	player.play()


func set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), clampf(db, -80.0, 0.0))


func set_music_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), clampf(db, -80.0, 0.0))


func set_sfx_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), clampf(db, -80.0, 0.0))
