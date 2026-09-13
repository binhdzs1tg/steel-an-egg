extends Node
## AudioManager
## Singleton that generates procedural SFX and ambient music in code.
## No external audio files needed — everything is synthesized once and cached.
##
## PERF NOTE (important):
##   The old implementation used AudioStreamGenerator and re-filled the buffer
##   EVERY frame in GDScript (~20k+ samples per frame) which caused massive lag.
##   Now the ambient music is generated ONCE at boot as a seamless looping
##   AudioStreamWAV, and SFX streams are generated lazily once and cached.

signal sfx_played(name: String)
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

const SAMPLE_RATE: int = 22050
const MUSIC_LOOP_SECONDS: float = 8.0

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _sfx_cache: Dictionary = {}
var _music_volume_db: float = -6.0
var _sfx_volume_db: float = 0.0


func _ready() -> void:
        # Keep audio running while the game is paused.
        process_mode = Node.PROCESS_MODE_ALWAYS

        # Load saved settings
        var data: Dictionary = SaveSystem.get_data()
        var settings: Dictionary = data.get("settings", {})
        var music_vol := float(settings.get("music_volume", 0.7))
        var sfx_vol := float(settings.get("sfx_volume", 0.8))
        _music_volume_db = linear_to_db(music_vol) if music_vol > 0.01 else -80.0
        _sfx_volume_db = linear_to_db(sfx_vol) if sfx_vol > 0.01 else -80.0

        # SFX player (one-shot)
        _sfx_player = AudioStreamPlayer.new()
        _sfx_player.name = "SFXPlayer"
        _sfx_player.volume_db = _sfx_volume_db
        add_child(_sfx_player)

        # Music player (pre-generated seamless loop — zero per-frame CPU cost)
        _music_player = AudioStreamPlayer.new()
        _music_player.name = "MusicPlayer"
        _music_player.volume_db = _music_volume_db
        _music_player.stream = _generate_music_loop()
        add_child(_music_player)
        _music_player.play()


# ---------- Music ----------
func _generate_music_loop() -> AudioStreamWAV:
        # Ambient pad: low drone + fifth + sub + soft shimmer, all frequencies are
        # integer multiples of 1/loop_length so the loop is perfectly seamless.
        var frames: int = int(SAMPLE_RATE * MUSIC_LOOP_SECONDS)
        var samples := PackedByteArray()
        samples.resize(frames * 4)  # 16-bit stereo
        var loop_len := float(MUSIC_LOOP_SECONDS)
        # Frequencies chosen so that freq * loop_len is an integer (loop-safe).
        var f_sub := 55.0      # A1  (440 cycles)
        var f_drone := 110.0   # A2  (880 cycles)
        var f_fifth := 165.0   # E3  (1320 cycles)
        var f_shimmer := 440.0 # A4  (3520 cycles)
        var lfo := 1.0 / loop_len          # 1 slow amplitude LFO cycle per loop
        for i in range(frames):
                var t := float(i) / float(SAMPLE_RATE)
                var swell := 0.75 + 0.25 * sin(t * TAU * lfo)  # gentle breathing
                var sub := sin(t * TAU * f_sub) * 0.10
                var drone := sin(t * TAU * f_drone) * 0.13
                var fifth := sin(t * TAU * f_fifth) * 0.08
                var shimmer := sin(t * TAU * f_shimmer) * 0.03 * (0.5 + 0.5 * sin(t * TAU * lfo * 8.0))
                var mixed := (sub + drone + fifth + shimmer) * swell
                mixed = clampf(mixed, -0.85, 0.85)
                var v := int(mixed * 32767.0)
                samples.encode_s16(i * 4, v)
                samples.encode_s16(i * 4 + 2, v)
        var stream := AudioStreamWAV.new()
        stream.format = AudioStreamWAV.FORMAT_16_BITS
        stream.mix_rate = SAMPLE_RATE
        stream.stereo = true
        stream.data = samples
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = frames
        return stream


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
# Each SFX is synthesized on demand ONCE, then cached and reused.
func play_sfx(name: String) -> void:
        var stream: AudioStream = _get_sfx_stream(name)
        if stream == null:
                return
        # Restart from the beginning even if the same stream is playing.
        _sfx_player.stream = stream
        _sfx_player.play()
        sfx_played.emit(name)


func _get_sfx_stream(name: String) -> AudioStream:
        if _sfx_cache.has(name):
                return _sfx_cache[name]
        var stream := _generate_sfx(name)
        _sfx_cache[name] = stream
        return stream


# Generates a short AudioStreamWAV (procedural) for the given event.
func _generate_sfx(name: String) -> AudioStreamWAV:
        var samples := PackedByteArray()
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
        # 16-bit stereo = 4 bytes per sample frame. The old buffer was sized with
        # num_samples * 2, so every encode_s16() past the halfway point failed with
        # "p_offset > size - 2" and SFX came out cut in half.
        samples.resize(num_samples * 4)
        for i in range(num_samples):
                var t := float(i) / float(SAMPLE_RATE)
                var env := exp(-decay * t)
                var current_freq := freq * (1.0 + sweep * t)
                var wave := sin(t * TAU * current_freq)
                if noise_amount > 0.0:
                        wave = wave * (1.0 - noise_amount) + (randf() * 2.0 - 1.0) * noise_amount
                var v := int(clampf(wave * env, -1.0, 1.0) * 32767.0)
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
