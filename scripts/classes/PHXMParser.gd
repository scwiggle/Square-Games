extends Object
class_name PHXMParser

class PHXM:
	var data_csv: String
	var audio: AudioStream
	var data_parsed: Array[Array]
	var metadata: Dictionary
	var cover: Image
	var override: MapOverride

static func get_note_count(path: String) -> int:
	var zip_reader: ZIPReader = ZIPReader.new()
	var error: Error = zip_reader.open(path)
	if error != Error.OK:
		print(error)
		return 999999

	var object_data: PackedByteArray = zip_reader.read_file("objects.phxmo")

	return object_data.decode_u32(4)

static func load_from_path(path: String) -> PHXM:
	var zip_reader: ZIPReader = ZIPReader.new()
	zip_reader.open(path)

	var new_map: PHXM = PHXM.new()

	var metadata: Dictionary = JSON.parse_string(zip_reader.read_file("metadata.json").get_string_from_utf8())
	new_map.metadata = metadata
	new_map.override = MapOverride.get_from_path(path)

	if metadata.HasAudio:
		var audio_extension: String = metadata.AudioExt
		var audio_buffer: PackedByteArray = zip_reader.read_file("audio.%s" % audio_extension)

		match audio_extension:
			"mp3":
				new_map.audio = AudioStreamMP3.load_from_buffer(audio_buffer)
			"wav":
				new_map.audio = AudioStreamWAV.load_from_buffer(audio_buffer)
			"ogg":
				new_map.audio = AudioStreamOggVorbis.load_from_buffer(audio_buffer)

	if metadata.HasCover:
		var cover: Image = Image.new()

		cover.load_png_from_buffer(zip_reader.read_file("cover.png"))

		new_map.cover = cover

	var object_data: PackedByteArray = zip_reader.read_file("objects.phxmo")

	var cursor: int = 0

	var _type_count: int = object_data.decode_u32(cursor); cursor += 4
	var note_count: int = object_data.decode_u32(cursor); cursor += 4

	var note_data: Array[Array]

	for i: int in range(0, note_count):
		var ms: int = object_data.decode_u32(cursor); cursor += 4
		var final_ms: int = ms if new_map.override.data_offset_msec == 0 else ms + (SSCS.modifiers.speed / new_map.override.data_offset_msec)

		var quantum: bool = object_data.decode_u8(cursor) > 0; cursor += 1

		if quantum:
			var x: float = -object_data.decode_float(cursor); cursor += 4
			var y: float = object_data.decode_float(cursor); cursor += 4
			note_data.append([x, y, final_ms])
		else:
			var x: float = 1 - object_data.decode_u8(cursor); cursor += 1
			var y: float = object_data.decode_u8(cursor) - 1; cursor += 1
			note_data.append([x, y, final_ms])

	note_data.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[2] < b[2]
	)

	var data_csv: PackedStringArray = []
	data_csv.resize(note_count)

	var i: int = 0
	for note: Array in note_data:
		data_csv[i] = "|".join(note)
		i += 1

	new_map.data_csv = ",".join(data_csv)
	new_map.data_parsed = note_data

	return new_map
