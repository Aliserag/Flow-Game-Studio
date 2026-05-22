extends Node

# AudioDirector autoload. Listens to EventBus signals and plays SFX/music cues.
# Asset-blocked: ships with silent placeholders; replace `_sample_*` with real
# AudioStream resources when audio assets land.
#
# Bus layout (configured via Audio Settings panel; mirrors project audio bus):
#   Master → Music
#         → SFX
# Settings persist via SettingsService (M4.7).

# Signal events we listen to and respond with audio cues.
# Replace these with real AudioStream resources when assets arrive.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var sfx_player_pool: Array = []  # AudioStreamPlayer pool
var music_player: AudioStreamPlayer = null
var muted_sfx: bool = false
var muted_music: bool = false

# Procedural placeholder beep generator. Returns a short AudioStreamWAV with a
# synthesized tone. Lets the audio pipeline run end-to-end even without assets.
var _placeholder_streams: Dictionary = {}

# Real CC0 audio assets (Kenney) loaded once at _ready and reused per cue.
# Licenses live under assets/audio/licenses/.
const SFX_PATHS: Dictionary = {
	"click": "res://assets/audio/sfx/click.wav",
	"combat_hit": "res://assets/audio/sfx/combat_hit.wav",
	"swarm_warning": "res://assets/audio/sfx/swarm_warning.wav",
	"megahorde_arrived": "res://assets/audio/sfx/megahorde_arrived.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
	"build_complete": "res://assets/audio/sfx/build_complete.wav",
	"move": "res://assets/audio/sfx/move.wav",
	"scavenge": "res://assets/audio/sfx/scavenge.wav",
	"recruit": "res://assets/audio/sfx/recruit.wav",
}
var _sfx_streams: Dictionary = {}

func _ready() -> void:
	_ensure_buses()
	_create_pool()
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)
	# Preload SFX streams so first-play is jank-free.
	for cue in SFX_PATHS.keys():
		var path: String = SFX_PATHS[cue]
		if ResourceLoader.exists(path):
			_sfx_streams[cue] = load(path)
	# Wire signal cues. Real CC0 audio plays now; procedural fallback if a cue is missing.
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.swarm_warning.connect(_on_swarm_warning)
	EventBus.megahorde_arrived.connect(_on_megahorde_arrived)
	EventBus.game_over.connect(_on_game_over)
	EventBus.enhancement_built.connect(_on_enhancement_built)
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.party_changed.connect(_on_party_changed)
	# Start ambient music. Real track if assets/audio/music/ambient.* exists,
	# else a procedural low-drone loop so the game isn't silent.
	_start_ambient_music()

func _start_ambient_music() -> void:
	# Prefer a real file if one is dropped in.
	for ext in [".ogg", ".wav", ".mp3"]:
		var path: String = "res://assets/audio/music/ambient" + ext
		if ResourceLoader.exists(path):
			music_player.stream = load(path)
			if music_player.stream is AudioStream:
				music_player.stream.loop = true if music_player.stream.has_method("set_loop") else true
			music_player.play()
			return
	# Procedural fallback — a low drone with subtle modulation.
	music_player.stream = _build_ambient_drone()
	music_player.play()
	# Workaround for AudioStreamWAV looping in newer Godot: replay on finished.
	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if not muted_music and music_player.stream != null:
		music_player.play()

func _build_ambient_drone() -> AudioStream:
	# Generates a ~6-second low-frequency drone with a slow LFO and thin noise
	# layer. Designed to loop seamlessly when restarted on `finished`.
	var sw := AudioStreamWAV.new()
	sw.format = AudioStreamWAV.FORMAT_16_BITS
	sw.mix_rate = 22050
	sw.stereo = false
	var duration_s: float = 6.0
	var sample_count: int = int(sw.mix_rate * duration_s)
	# Two detuned low oscillators + subtle high-frequency wash.
	var f1: float = 65.0   # low C-ish drone
	var f2: float = 97.5   # detuned partial
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var lfo_speed: float = 0.18  # Hz
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x434F4C44  # "COLD"
	for i in sample_count:
		var t: float = float(i) / sw.mix_rate
		# Sine pair.
		var s1: float = sin(TAU * f1 * t)
		var s2: float = sin(TAU * f2 * t)
		# Slow LFO modulation on amplitude.
		var lfo: float = 0.5 + 0.5 * sin(TAU * lfo_speed * t)
		# Thin pink-ish noise wash.
		var noise: float = (rng.randf() - 0.5) * 0.06
		var v: float = (s1 * 0.35 + s2 * 0.22) * (0.5 + lfo * 0.5) + noise
		v *= 0.4  # overall headroom; should be quiet
		var s_int: int = clampi(int(v * 32767.0), -32768, 32767)
		samples[i * 2] = s_int & 0xff
		samples[i * 2 + 1] = (s_int >> 8) & 0xff
	sw.data = samples
	return sw

func _ensure_buses() -> void:
	# Buses created at runtime so this works even without a project.audio_bus_layout.
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

func _create_pool() -> void:
	for _i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		sfx_player_pool.append(p)

func play_sfx(cue: String) -> void:
	if muted_sfx:
		return
	var stream: AudioStream = _sfx_streams.get(cue, null)
	if stream == null:
		stream = _placeholder_for(cue)
	if stream == null:
		return
	var p: AudioStreamPlayer = _free_sfx_player()
	if p == null:
		return
	p.stream = stream
	p.play()

func _free_sfx_player() -> AudioStreamPlayer:
	for p in sfx_player_pool:
		if not p.playing:
			return p
	return null

func play_music(track: String) -> void:
	if muted_music:
		return
	var stream: AudioStream = _placeholder_for("music_" + track)
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()

func set_master_volume(linear: float) -> void:
	var db: float = linear_to_db(clamp(linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), db)

func set_music_volume(linear: float) -> void:
	var db: float = linear_to_db(clamp(linear, 0.001, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), db)

func set_sfx_volume(linear: float) -> void:
	var db: float = linear_to_db(clamp(linear, 0.001, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), db)

func mute_sfx(value: bool) -> void:
	muted_sfx = value

func mute_music(value: bool) -> void:
	muted_music = value
	if value and music_player and music_player.playing:
		music_player.stop()

func _placeholder_for(cue: String) -> AudioStream:
	# Procedural placeholder: a very short, very quiet square-wave tone.
	# Replace this whole function when assets arrive.
	if _placeholder_streams.has(cue):
		return _placeholder_streams[cue]
	var sw := AudioStreamWAV.new()
	sw.format = AudioStreamWAV.FORMAT_16_BITS
	sw.mix_rate = 22050
	sw.stereo = false
	var sample_count: int = 1100  # ~50ms
	var freq: float = _cue_frequency(cue)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / sw.mix_rate
		var v: float = sin(TAU * freq * t) * 0.05
		var s: int = clampi(int(v * 32767.0), -32768, 32767)
		samples[i * 2] = s & 0xff
		samples[i * 2 + 1] = (s >> 8) & 0xff
	sw.data = samples
	_placeholder_streams[cue] = sw
	return sw

func _cue_frequency(cue: String) -> float:
	# Distinct frequency per cue so testers can identify what fired.
	match cue:
		"click": return 880.0
		"combat_hit": return 220.0
		"swarm_warning": return 110.0
		"megahorde_arrived": return 55.0
		"victory": return 660.0
		"defeat": return 165.0
		"build_complete": return 440.0
		_: return 440.0

# Signal listeners — each calls play_sfx with a distinct cue.

func _on_combat_resolved(_attacker, _defender, _result: Dictionary) -> void:
	play_sfx("combat_hit")

func _on_swarm_warning(_days: int, _kind: String) -> void:
	play_sfx("swarm_warning")

func _on_megahorde_arrived() -> void:
	play_sfx("megahorde_arrived")

func _on_game_over(victory: bool, _summary: String) -> void:
	play_sfx("victory" if victory else "defeat")

func _on_enhancement_built(_id: String) -> void:
	play_sfx("build_complete")

func _on_player_moved(_from: Vector2i, _to: Vector2i) -> void:
	play_sfx("move")

# Track party-size changes so we only fire on growth (recruits), not shrinkage.
var _last_party_size: int = -1

func _on_party_changed() -> void:
	var sz: int = GameState.party.size() if GameState else 0
	if _last_party_size >= 0 and sz > _last_party_size:
		play_sfx("recruit")
	_last_party_size = sz
