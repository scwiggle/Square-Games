extends Node

var player: AudioStreamPlayer
var stream: AudioStream

var playing: bool = false
var elapsed: float = 0.0
var playback_speed: float = 1
var compensation: float = 0
var audio_began: bool = false

var last_update: int 

signal ended

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = &"Music"
	player.pitch_scale = playback_speed
	player.volume_linear = SSCS.settings.map_volume * 0.15
	player.finished.connect(func() -> void:
		print("audio ended")
		playing = false
		audio_began = false
		ended.emit()
	)
	self.add_child(player)

	compensation = AudioServer.get_output_latency()

func set_stream(new_stream: AudioStream) -> void:
	stream = new_stream
	player.stream = stream

func set_playback_speed(speed: float) -> void:
	playback_speed = speed
	player.pitch_scale = speed

func play(from: float) -> void:
	playing = true
	if from >= 0:
		player.play(from)
		audio_began = true
	elapsed = from
	last_update = Time.get_ticks_usec()

func stop() -> void:
	playing = false
	player.stop()

func full_stop() -> void:
	audio_began = false
	playing = false
	player.stop()

func resume() -> void:
	play(elapsed)

func _process(_dt: float) -> void:
	if not playing: return
	var current_update: int = Time.get_ticks_usec()
	
	if audio_began:
		elapsed = player.get_playback_position() + AudioServer.get_time_since_last_mix() - compensation
	else:
		elapsed += (float(current_update - last_update) / 1_000_000.0) * playback_speed
	
	last_update = current_update
	
	if !audio_began and elapsed >= 0:
		play(elapsed)
	RenderingServer.global_shader_parameter_set("elapsed_time",elapsed)
