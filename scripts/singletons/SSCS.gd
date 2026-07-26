extends Node

## any setting which is related to track position is on a scale of 0-1 where 0 is hitting the grid and 1 is freshly spawned

enum VfxDetailLevel {
	VFX_DETAIL_LEVEL_NONE,
	VFX_DETAIL_LEVEL_MINIMAL,
	VFX_DETAIL_LEVEL_MAX
}

const SPACES_PATH = "res://scenes/spaces"

class Settings:
	var approach_rate: float = 50.0
	var spawn_distance: float = 25.0
	var color_set: Array = [
		Color.from_string("#ffffff", Color.WHITE),
		Color.from_string("#66ffff", Color.WHITE),
	]
	var grid_distance: float = 3.5
	var vanish_distance: float = 0.2

	var pixels_per_grid_unit: float = 100.0

	var parallax: float = 0.1

	var note_transparency: float = 0.3
	var note_begin_transparency: float = 1
	var note_end_transparency: float = 0.9

	var note_fade_in_begin: float = 1
	var note_fade_in_end: float = 0.8

	var note_fade_out_begin: float = 0.4
	var note_fade_out_end: float = 0

	var fov: float = 75

	var absolute_input: bool = false

	var auto_spectate: bool = true

	var vfx_detail_level: VfxDetailLevel = VfxDetailLevel.VFX_DETAIL_LEVEL_MAX
	var space_id: StringName = &"stars"

	var glow_enabled: bool = false
	var glow_strength: float = 2
	var glow_bloom: float = 0.2

	var semi_spin: bool = false
	var true_spin: bool = false

	var fullscreen: bool = true:
		set(x):
			fullscreen = x
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	var map_volume: float = 1:
		set(x):
			map_volume = x
			if AudioManager.player != null:
				AudioManager.player.volume_linear = map_volume * 0.15

	var hit_sound_volume: float = 1
	var miss_sound_volume: float = 1

	var disable_pausing: bool = false

	var hud_scale: float = 1

	var record_replays: bool = true
	var smooth_replays: bool = true
	var use_replay_settings: bool = true

	var cursor_scale: float = 1
	var note_scale: float = 1

	var sound_space_accurate_camera: bool = false



class Modifiers:
	var hit_time: float = 45.0
	var hitbox_size: float = (0.875 + 0.2625)/2
	var speed: float = 1
	var no_fail: bool = false
	var autoplay: bool = false

	var horizontal_flip: bool = false
	var vertical_flip: bool = false

signal setting_updated(setting: String, old_value: Variant, new_value: Variant)
signal modifier_updated(modifier: String, old_value: Variant, new_value: Variant)

var settings: Settings = Settings.new()
var modifiers: Modifiers = Modifiers.new()

var true_settings: Settings = settings
var true_modifiers: Modifiers = modifiers

var game_handler: GameHandler
var map_cache: Dictionary[String, MapLoader.Map] = {}
var url_cache: Dictionary[String, Dictionary] = {}

var maps_to_load: PackedStringArray

var selected_map: MapLoader.Map

signal map_loaded(map: MapLoader.Map)

var host_lobby: HostLobby
var client_lobby: ClientLobby

var user_interface: UserInterface

var setting_parse_overrides: Dictionary[String,Callable] = {
	color_set = func(value: String) -> Array:
		var new_value: Array[Color] = []
		for color: String in value.split(","):
			new_value.append(Color.from_string(color,Color.WHITE))
		return [new_value,true]
}

var modifier_parse_overrides: Dictionary[String,Callable] = {
	color_set = func(value: String) -> Array[Color]:
		var colorset: Array[Color] = []
		for color: String in value.split(","):
			colorset.append(Color.from_string(color, Color.WHITE))
		return colorset
}

func set_setting(setting: String, value: Variant, generic: bool = false) -> bool:
	var cur_value: Variant = settings.get(setting)
	if cur_value == null: return false

	if generic and value is String:
		var new_value: Variant = str_to_var(value)

		if typeof(new_value) != typeof(cur_value):
			if typeof(cur_value) == TYPE_INT:
				new_value = int(new_value)
			elif typeof(cur_value) == TYPE_FLOAT:
				new_value = float(new_value)

			if typeof(new_value) != typeof(cur_value):
				return false

		if cur_value is Array and cur_value.is_typed():
			new_value = Array(new_value, cur_value.get_typed_builtin(), cur_value.get_typed_class_name(), cur_value.get_typed_script())

		settings.set(setting, new_value)
		setting_updated.emit(setting, cur_value, new_value)
	else:
		if typeof(cur_value) != typeof(value):
			return false
		settings.set(setting, value)
		setting_updated.emit(setting, cur_value, value)

	return true

func set_modifier(modifier: String, value: Variant, generic: bool = false) -> bool:
	var cur_value: Variant = modifiers.get(modifier)
	if cur_value == null: return false

	if generic and value is String:
		var new_value: Variant = str_to_var(value)

		if typeof(new_value) != typeof(cur_value):
			if typeof(cur_value) == TYPE_INT:
				new_value = int(new_value)
			elif typeof(cur_value) == TYPE_FLOAT:
				new_value = float(new_value)

			if typeof(new_value) != typeof(cur_value):
				return false

		if cur_value is Array and cur_value.is_typed():
			new_value = Array(new_value, cur_value.get_typed_builtin(), cur_value.get_typed_class_name(), cur_value.get_typed_script())

		modifiers.set(modifier, new_value)
		modifier_updated.emit(modifier, cur_value, new_value)
	else:
		if typeof(cur_value) != typeof(value):
			return false
		modifiers.set(modifier, value)
		modifier_updated.emit(modifier, cur_value, value)

	return true

const blacklisted_properties: Array[String] = ["RefCounted","script","Built-in script"]
func encode_class(obj: Variant) -> Dictionary:
	var encoded: Dictionary = {}

	for p: Dictionary in obj.get_property_list():
		if p.name not in blacklisted_properties:
			encoded[p.name]=obj.get(p.name)

	return encoded

func wait(time: float) -> void:
	await get_tree().create_timer(time).timeout

func get_map_file_path_from_name(map_name: String) -> String:
	var map: String
	var is_sspm: bool = FileAccess.file_exists("user://rhythiamaps/%s.sspm" % map_name)
	var is_phxm: bool = FileAccess.file_exists("user://phoenyxmaps/%s.phxm" % map_name)
	if is_sspm:
		map = "user://rhythiamaps/%s.sspm" % map_name
	elif is_phxm:
		map = "user://phoenyxmaps/%s.phxm" % map_name
	else:
		map = "user://maps/%s" % map_name

	return map

func get_full_map_name_from_partial_name(partial_map_name: String) -> String:

	for v: String in DirAccess.get_files_at("user://maps"):
		if v.get_basename().contains(partial_map_name):
			return v.get_basename()

	for v: String in DirAccess.get_files_at("user://rhythiamaps"):
		if v.get_basename().contains(partial_map_name):
			return v.get_basename()

	for v: String in DirAccess.get_files_at("user://phoenyxmaps"):
		if v.get_basename().contains(partial_map_name):
			return v.get_basename()

	return ""

signal temporary_map_link_received
func get_temporary_map_download_link(map: MapLoader.Map) -> String:
	if url_cache.has(map.map_name):
		if Time.get_unix_time_from_system() - url_cache[map.map_name].time < (60*60) - 30:
			return url_cache[map.map_name].url
		else:
			url_cache.erase(map.map_name)

	var request: HTTPRequest = HTTPRequest.new()
	self.add_child(request)

	var data: PackedStringArray = []

	var boundary: String = "--GODOT" + Crypto.new().generate_random_bytes(16).hex_encode()

	var upload_data: PackedByteArray = var_to_bytes_with_objects({
		data=map.raw_data,
		audio=map.audio
	})

	print(len(upload_data))

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="time"')
	data.append("")
	data.append("1h")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="fileNameLength"')
	data.append("")
	data.append("16")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="reqtype"')
	data.append("")
	data.append("fileupload")

	data.append("--%s" % boundary)
	data.append('Content-Disposition: form-data; name="fileToUpload"; filename="map.txt"')
	data.append('Content-Type: text/plain')
	data.append("")
	data.append(Marshalls.raw_to_base64(upload_data))
	data.append("--%s--" % boundary)


	request.request("https://litterbox.catbox.moe/resources/internals/api.php", ["Content-Type: multipart/form-data;boundary=%s" % boundary], HTTPClient.METHOD_POST, "\r\n".join(data))

	request.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var local_url: String = body.get_string_from_utf8()
		print("got map link")
		print("_result")
		print("_response_code")
		temporary_map_link_received.emit(local_url)
	)

	var url: String = await temporary_map_link_received
	request.queue_free()

	print("get url")
	print(url)

	if url.begins_with("http"):
		url_cache[map.map_name] = {
			time = Time.get_unix_time_from_system(),
			url = url
		}
		return url
	else:
		return ""

signal temporary_map_data_received
func get_map_from_url(url: String) -> MapLoader.Map:
	var request: HTTPRequest = HTTPRequest.new()
	self.add_child(request)

	print("requesting url: %s" % url)
	request.request(url)

	request.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		var local_data: PackedByteArray = Marshalls.base64_to_raw(body.get_string_from_ascii())
		print("got map data")
		print(_result)
		print(_response_code)
		print(len(local_data))
		temporary_map_data_received.emit(local_data)
	)

	var raw_data: PackedByteArray = await temporary_map_data_received

	print(len(raw_data))

	var data: Dictionary = bytes_to_var_with_objects(raw_data)


	var map: MapLoader.Map = MapLoader.Map.new()

	map.audio = data.audio
	map.raw_data = data.data
	map.data = MapLoader._parse_data(data.data, false)

	print("map url debug")
	print(len(data.data))
	print(len(map.data))
	print(map.audio.get_length())

	request.queue_free()

	return map

func get_arbitrary_exension(path: String, whitelist: PackedStringArray) -> String:
	var base_dir: String = path.get_base_dir()
	for file: String in DirAccess.get_files_at(base_dir):
		if path.get_file().get_basename() == file.get_basename() and file.get_extension() in whitelist:
			return base_dir + file
	return ""

func load_image(path: String) -> Image:
	var new_image: Image = Image.new()
	new_image.load(ProjectSettings.globalize_path(path))
	return new_image

func load_audio(path: String) -> AudioStream:
	var new_audio_stream: AudioStream
	match path.get_extension():
		"wav":
			new_audio_stream = AudioStreamWAV.load_from_file(path)
		"mp3":
			new_audio_stream = AudioStreamMP3.load_from_file(path)
		"ogg":
			new_audio_stream = AudioStreamOggVorbis.load_from_file(path)
	return new_audio_stream

func get_map_hash(map_name: String) -> PackedByteArray:
	var map_path: String = get_map_file_path_from_name(map_name)

	if len(map_path) == 0 or not FileAccess.file_exists(map_path):
		return []
	var hashing_context: HashingContext = HashingContext.new()
	hashing_context.start(HashingContext.HashType.HASH_SHA256)

	var file: FileAccess = FileAccess.open(map_path,FileAccess.READ)

	while file.get_position() < file.get_length():
		var chunk_size: int = file.get_length() - file.get_position()
		hashing_context.update(file.get_buffer(min(chunk_size, 1024)))

	var hash_data: PackedByteArray = hashing_context.finish()

	return hash_data

func load_map_from_name(map_name: String, ignore_cache: bool = false) -> MapLoader.Map:
	if !ignore_cache and map_cache.has(map_name) and map_cache[map_name].loaded_successfully:
		return map_cache[map_name]

	var map: MapLoader.Map
	var is_sspm: bool = FileAccess.file_exists("user://rhythiamaps/%s.sspm" % map_name)
	var is_phxm: bool = FileAccess.file_exists("user://phoenyxmaps/%s.phxm" % map_name)
	if is_sspm:
		map = MapLoader.from_path_sspm("user://rhythiamaps/%s.sspm" % map_name)
	elif is_phxm:
		map = MapLoader.from_path_phxm("user://phoenyxmaps/%s.phxm" % map_name)
	else:
		return MapLoader.Map.new()
		#map = MapLoader.from_path_native("user://maps/%s" % map_name)
	map.raw_map_name = map_name

	map_cache[map_name] = map
	map_loaded.emit(map)


	return map

func load_unloaded_maps() -> void:
	var mutex: Mutex = Mutex.new()

	var to_load: PackedStringArray = []

	for map_name: String in DirAccess.get_files_at("user://rhythiamaps"):
		to_load.append(map_name.get_basename())
	for map_name: String in DirAccess.get_files_at("user://phoenyxmaps"):
		to_load.append(map_name.get_basename())

	var task_id: int = WorkerThreadPool.add_group_task(func(index: int) -> void:
		var map_name: String = to_load[index]
		if map_cache.has(map_name): return
		var map: MapLoader.Map
		var is_sspm: bool = FileAccess.file_exists("user://rhythiamaps/%s.sspm" % map_name)
		var is_phxm: bool = FileAccess.file_exists("user://phoenyxmaps/%s.phxm" % map_name)
		if is_sspm:
			map = MapLoader.from_path_sspm("user://rhythiamaps/%s.sspm" % map_name)
		elif is_phxm:
			map = MapLoader.from_path_phxm("user://phoenyxmaps/%s.phxm" % map_name)
		else:
			map = MapLoader.Map.new()
			#map = MapLoader.from_path_native("user://maps/%s" % map_name)
		map.raw_map_name = map_name

		mutex.lock()
		map_cache[map_name] = map
		mutex.unlock()
	, len(to_load), -1, true)

	WorkerThreadPool.wait_for_group_task_completion(task_id)

static func seconds_to_timestamp(seconds: float) -> String:
	return "{0}:{1}".format([floor(seconds / 60.0), floor(fmod(seconds, 60.0))])

func _ready() -> void:
	#make sure directories exist
	DirAccess.make_dir_absolute("user://maps")
	DirAccess.make_dir_absolute("user://rhythiamaps")
	DirAccess.make_dir_absolute("user://phoenyxmaps")
	DirAccess.make_dir_absolute("user://replays")

	var settings_file: FileAccess = FileAccess.open("user://settings.txt", FileAccess.READ)

	if settings_file != null and settings_file.get_length() >= 4:
		print("decode")

		var raw_settings_data: PackedByteArray = settings_file.get_buffer(settings_file.get_length())

		var settings_data: Dictionary = bytes_to_var(raw_settings_data)

		for setting: String in settings_data:
			var value: Variant = settings_data[setting]
			settings.set(setting, value)

	setting_updated.connect(func(setting: String, _old: Variant, new: Variant) -> void:
		match setting:
			"fov":
				get_viewport().get_camera_3d().fov = new #idk why but you cant do this in a setter
	)

	load_unloaded_maps()

	SSCS.selected_map = map_cache[map_cache.keys()[0]]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("close")
		var settings_file: FileAccess = FileAccess.open("user://settings.txt",FileAccess.ModeFlags.WRITE_READ)
		print(settings_file.store_buffer(var_to_bytes(encode_class(settings))))
		settings_file.flush()
		settings_file.close()

		await get_tree().process_frame
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		settings.fullscreen = !settings.fullscreen
