# AudioManager.gd
# Singleton that synthesises simple SFX procedurally so we don't ship audio assets.
# Each effect is a one-shot AudioStreamPlayer fed by an AudioStreamGenerator.
extends Node

var _master_bus: int = 0
var _sfx_bus: int = 0
var _master_volume: float = 0.8
var _sfx_volume: float = 0.8
var _enabled: bool = true


func _ready() -> void:
	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus == -1:
		_master_bus = 0
	_sfx_bus = _master_bus  # We use Master as SFX bus (no extra bus in project)
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(_master_volume))


func set_master_volume(v: float) -> void:
	_master_volume = clamp(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(_master_bus, linear_to_db(_master_volume))


func get_master_volume() -> float:
	return _master_volume


func set_sfx_volume(v: float) -> void:
	_sfx_volume = clamp(v, 0.0, 1.0)


func get_sfx_volume() -> float:
	return _sfx_volume


func set_enabled(e: bool) -> void:
	_enabled = e
	AudioServer.set_bus_mute(_master_bus, not e)


func is_enabled() -> bool:
	return _enabled


# ---------- Procedural SFX ----------
# Plays a short tone with given frequency, duration, volume, and envelope.
func play_tone(freq: float, duration: float, vol: float = 0.5, shape: int = 0) -> void:
	if not _enabled:
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100
	stream.buffer_length = max(0.05, duration + 0.05)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(clamp(vol * _sfx_volume, 0.001, 1.0))
	add_child(player)
	player.play()
	_fill_buffer(player, freq, duration, shape)
	# Auto-free when finished
	await player.finished
	player.queue_free()


func _fill_buffer(player: AudioStreamPlayer, freq: float, duration: float, shape: int) -> void:
	var frames := int(player.stream.mix_rate * duration)
	var buf := PackedVector2Array()
	buf.resize(frames)
	var sr := float(player.stream.mix_rate)
	var inv_sr := 1.0 / sr
	for i in range(frames):
		var t: float = i * inv_sr
		var env: float = 1.0
		# Attack-decay envelope
		var atk := 0.01
		var rel := 0.1
		if t < atk:
			env = t / atk
		elif t > duration - rel:
			env = max(0.0, (duration - t) / rel)
		var s: float = 0.0
		var phase: float = t * freq * TAU
		match shape:
			0:  # sine
				s = sin(phase)
			1:  # square
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			2:  # saw
				s = 2.0 * (fmod(t * freq, 1.0)) - 1.0
			_:  # noise
				s = randf_range(-1.0, 1.0)
		var v: float = s * env * 0.4
		buf[i] = Vector2(v, v)
	player.get_stream_playback().push_buffer(buf)


# ---------- Named SFX shortcuts ----------
func sfx_pickup() -> void:
	play_tone(880.0, 0.10, 0.35, 0)
	await get_tree().create_timer(0.08).timeout
	play_tone(1320.0, 0.10, 0.30, 0)


func sfx_steal() -> void:
	play_tone(220.0, 0.05, 0.30, 1)
	await get_tree().create_timer(0.05).timeout
	play_tone(440.0, 0.15, 0.35, 0)


func sfx_alert() -> void:
	play_tone(660.0, 0.08, 0.40, 1)
	await get_tree().create_timer(0.10).timeout
	play_tone(880.0, 0.08, 0.40, 1)


func sfx_caught() -> void:
	play_tone(110.0, 0.40, 0.45, 2)
	await get_tree().create_timer(0.10).timeout
	play_tone(80.0, 0.30, 0.40, 3)


func sfx_deposit() -> void:
	play_tone(523.0, 0.08, 0.35, 0)
	await get_tree().create_timer(0.08).timeout
	play_tone(659.0, 0.08, 0.35, 0)
	await get_tree().create_timer(0.08).timeout
	play_tone(784.0, 0.12, 0.40, 0)


func sfx_hatch() -> void:
	for i in range(3):
		play_tone(440.0 * (1.0 + 0.25 * i), 0.10, 0.30, 0)
		await get_tree().create_timer(0.10).timeout


func sfx_upgrade() -> void:
	play_tone(659.0, 0.10, 0.35, 0)
	await get_tree().create_timer(0.08).timeout
	play_tone(988.0, 0.15, 0.40, 0)


func sfx_coin() -> void:
	play_tone(1318.0, 0.06, 0.25, 0)


func sfx_step() -> void:
	play_tone(80.0, 0.04, 0.15, 3)


func sfx_ui_click() -> void:
	play_tone(660.0, 0.04, 0.20, 0)


func sfx_error() -> void:
	play_tone(220.0, 0.10, 0.30, 1)
