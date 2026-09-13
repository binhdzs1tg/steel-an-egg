extends Node
## AudioManager
## Singleton that generates procedural SFX and ambient music in code.
## No external audio files needed — all synthesized via AudioStreamGenerator.

signal sfx_played(name: String)
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_generator: AudioStreamGenerator
var _music_playback: AudioStreamGeneratorPlayback
var _music_phase: float = 0.0
var _music_target_volume: float = 0.4
var _sfx_volume_db: float = 0.0
var _music_volume_db: float = -6.0
var _is_playing_music: bool = false
const SAMPLE_RATE: int = 44100
const FRAMES_PER_FILL: int = 1024


func _ready() -> void:
	# Load saved settings
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	_music_volume_db = linear_to_db(float(settings.get("music_volume", 0.7)))
	_sfx_volume_db = linear_to_db(float(settings.get("sfx_volume", 0.8)))
	if settings.get("music_volume", 0.7) <= 0.01:
		_music_volume_db = -80.0
	if settings.get("sfx_volume", 0.8) <= 0.01:
		_sfx_volume_db = -80.0

	# SFX player (one-shot)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.volume_db = _sfx_volume_db
	add_child(_sfx_player)

	# Music player (continuous generator)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = _music_volume_db
	add_child(_music_player)
	_music_generator = AudioStreamGenerator.new()
	_music_generator.mix_rate = SAMPLE_RATE
	_music_generator.buffer_length = 0.5
	_music_player.stream = _music_generator
	_music_player.play()
	_is_playing_music = true
	_music_playback = _music_player.get_stream_playback()
	_fill_music_buffer()  # initial fill


func _process(_delta: float) -> void:
	if _is_playing_music:
		_fill_music_buffer()


# ---------- Music ----------
func _fill_music_buffer() -> void:
	if _music_playback == null:
		return
	var frames_to_fill := _music_playback.get_frames_available()
	for i in range(frames_to_fill):
		var sample := _generate_music_sample(_music_phase)
		_music_playback.push_frame(sample)
		_music_phase += 1.0 / float(SAMPLE_RATE)
		if _music_phase > 1000.0:
			_music_phase -= 1000.0


func _generate_music_sample(phase: float) -> Vector2:
	# Simple ambient pad: low drone + slow LFO + soft arpeggio
	var drone := sin(phase * TAU * 110.0) * 0.15  # A2
	var drone2 := sin(phase * TAU * 165.0) * 0.10  # E3
	var arp_freq := 220.0 * pow(2.0, (fmod(floor(phase * 0.5), 8.0)) / 12.0)
	var arp := sin(phase * TAU * arp_freq) * 0.06 * (0.5 + 0.5 * sin(phase * TAU * 0.5))
	var pad := sin(phase * TAU * 55.0) * 0.10  # A1
	var mixed := drone + drone2 + arp + pad
	# Soft low-pass via averaging (cheap)
	mixed = clampf(mixed * 0.8, -0.6, 0.6)
	return Vector2(mixed, mixed)


func set_music_volume(volume_0_to_1: float) -> void:
	volume_0_to_1 = clampf(volume_0_to_1, 0.0, 1.0)
	_music_volume_db = linear_to_db(volume_0_to_1) if volume_0_to_1 > 0.01 else -80.0
	_music_player.volume_db = _music_volume_db
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	settings["music_volume"] = volume_0_to_1
	data["settings"] = settings
	SaveSystem.mark_dirty()
	music_volume_changed.emit(volume_0_to_1)


func set_sfx_volume(volume_0_to_1: float) -> void:
	volume_0_to_1 = clampf(volume_0_to_1, 0.0, 1.0)
	_sfx_volume_db = linear_to_db(volume_0_to_1) if volume_0_to_1 > 0.01 else -80.0
	_sfx_player.volume_db = _sfx_volume_db
	var data: Dictionary = SaveSystem.get_data()
	var settings: Dictionary = data.get("settings", {})
	settings["sfx_volume"] = volume_0_to_1
	data["settings"] = settings
	SaveSystem.mark_dirty()
	sfx_volume_changed.emit(volume_0_to_1)


# ---------- SFX ----------
# Each SFX is synthesized on demand and played as a one-shot AudioStream.
func play_sfx(name: String) -> void:
	var stream: AudioStream = _generate_sfx(name)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()
	sfx_played.emit(name)


# Generates a short AudioStreamWAV (procedural) for the given event.
func _generate_sfx(name: String) -> AudioStream:
	var samples: PackedByteArray = PackedByteArray()
	var duration: float = 0.3
	var freq: float = 440.0
	var decay: float = 6.0
	var noise_amount: float = 0.0
	var sweep: float = 0.0  # pitch sweep

	match name:
		"egg_collect":
			duration = 0.25; freq = 600.0; decay = 8.0; sweep = 0.5
		"egg_pickup_fail":
			duration = 0.2; freq = 200.0; decay = 8.0
		"hatch_start":
			duration = 0.5; freq = 300.0; decay = 3.0; sweep = 1.0
		"hatch_crack":
			duration = 0.4; freq = 150.0; decay = 4.0; noise_amount = 0.6
		"pet_appear_common":
			duration = 0.5; freq = 500.0; decay = 4.0; sweep = 0.8
		"pet_appear_rare":
			duration = 0.8; freq = 700.0; decay = 3.0; sweep = 1.5
		"pet_appear_legendary":
			duration = 1.2; freq = 800.0; decay = 2.0; sweep = 2.0
		"pet_appear_secret":
			duration = 1.8; freq = 1000.0; decay = 1.5; sweep = 2.5; noise_amount = 0.3
		"money_tick":
			duration = 0.08; freq = 880.0; decay = 20.0
		"upgrade_buy":
			duration = 0.35; freq = 660.0; decay = 5.0; sweep = 1.0
		"speed_level_up":
			duration = 0.6; freq = 550.0; decay = 3.0; sweep = 2.0
		"quest_complete":
			duration = 0.7; freq = 770.0; decay = 3.0; sweep = 1.5
		"achievement":
			duration = 1.0; freq = 880.0; decay = 2.5; sweep = 2.0
		"unlock_biome":
			duration = 1.2; freq = 440.0; decay = 2.0; sweep = 2.5
		"damage":
			duration = 0.25; freq = 180.0; decay = 8.0; noise_amount = 0.4
		"ui_click":
			duration = 0.05; freq = 800.0; decay = 30.0
		"ui_hover":
			duration = 0.03; freq = 1000.0; decay = 40.0
		_:
			duration = 0.1; freq = 440.0; decay = 10.0

	var num_samples: int = int(duration * SAMPLE_RATE)
	samples.resize(num_samples * 2)  # 16-bit stereo
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-decay * t)
		var current_freq: float = freq * (1.0 + sweep * t)
		var wave: float = sin(t * TAU * current_freq)
		if noise_amount > 0.0:
			wave = wave * (1.0 - noise_amount) + (randf() * 2.0 - 1.0) * noise_amount
		var v: int = int(clampf(wave * env, -1.0, 1.0) * 32767)
		# Stereo (same both channels)
		samples.encode_s16(i * 4, v)
		samples.encode_s16(i * 4 + 2, v)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	stream.data = samples
	return stream


# Plays a SFX at a specific 3D position (for spatial audio)
# For simplicity we just play 2D; could be extended to AudioStreamPlayer3D.
func play_sfx_3d(name: String, _position: Vector3) -> void:
	play_sfx(name)
