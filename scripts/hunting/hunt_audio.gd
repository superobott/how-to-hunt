extends Node
## Tiny original synthesized cues; no imported audio or third-party assets.

var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _next_voice := 0


func _ready() -> void:
	# Servers and accelerated headless tests have no audible output or real-time mixer.
	if DisplayServer.get_name() == "headless":
		return
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -15.0
		add_child(voice)
		_players.append(voice)
	_sounds["shoot"] = _tone(240.0, 80.0, 0.13)
	_sounds["collect"] = _tone(620.0, 1100.0, 0.16)
	_sounds["sell"] = _tone(700.0, 1400.0, 0.25)
	_sounds["hit"] = _tone(180.0, 60.0, 0.12)
	_sounds["upgrade"] = _tone(440.0, 1320.0, 0.40)


func _exit_tree() -> void:
	for voice in _players:
		voice.stop()
		voice.stream = null
	_players.clear()
	_sounds.clear()


func play_cue(cue: String) -> void:
	if not _sounds.has(cue) or _players.is_empty():
		return
	var voice := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	voice.stream = _sounds[cue]
	voice.play()


static func _tone(start_hz: float, end_hz: float, seconds: float) -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var samples := int(seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var phase := 0.0
	for index in samples:
		var progress := float(index) / samples
		phase += TAU * lerpf(start_hz, end_hz, progress) / SAMPLE_RATE
		var envelope := sin(PI * progress) * (1.0 - progress)
		bytes.encode_s16(index * 2, int(sin(phase) * envelope * 16000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.data = bytes
	return sound
