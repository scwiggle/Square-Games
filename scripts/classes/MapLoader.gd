extends Node
class_name MapLoader

enum MapType {
	Native,
	SSPM,
	PHXM
}

class Map:
	var map_type: MapType
	var path: String
	var raw_data: String
	var data: Array[Array]
	var audio: AudioStream
	var loaded_successfully: bool
	var raw_map_name: String
	var map_name: String
	var author_name: String
	var charter_name: String
	var cover: Image

#DEPRECATED because arrays are better in basically every way
#class NoteDataMinimal:
	#var x: float
	#var y: float
	#var t: int

	#func _init(x_arg: float, y_arg: float, t_arg: int) -> void:
		#x = x_arg
		#y = y_arg
		#t = t_arg

static func _parse_data(data: String, offset: bool = true) -> Array[Array]:
	var output_data: Array[Array] = []

	if offset:
		for v: String in data.split(","):
			var split: PackedStringArray = v.split("|")
			if len(split) == 3:
				var new_note_data: Array = [
					1.0 - split[0].to_float(),
					1.0 - split[1].to_float(),
					split[2].to_int()
				]

				output_data.append(new_note_data)
	else:
		for v: String in data.split(","):
			var split: PackedStringArray = v.split("|")
			if len(split) == 3:
				var new_note_data: Array = [
					split[0].to_float(),
					split[1].to_float(),
					split[2].to_int()
				]

				output_data.append(new_note_data)

	return output_data

static func from_path_native(path: String) -> Map: #path to a folder with a data.txt file and audio.mp3 file
	var new_map: Map = Map.new()

	if !FileAccess.file_exists(path): print("no map file"); return new_map

	var audio: AudioStreamMP3 = AudioStreamMP3.new()
	audio.data = FileAccess.get_file_as_bytes("%s/audio.mp3" % path)

	var raw_data: String = FileAccess.get_file_as_string("%s/data.txt" % path)
	var data: Array =  _parse_data(raw_data)

	new_map.map_type = MapType.Native
	new_map.path = path
	new_map.audio = audio
	new_map.raw_data = raw_data
	new_map.data = data
	new_map.loaded_successfully = len(data) > 0

	return new_map

static func from_path_sspm(path: String) -> Map: #path to a .sspm file
	var new_map: Map = Map.new()

	var sspm_parsed: SSPMUtil.SSPM = SSPMUtil.load_from_path(path)
	var data: Array =  sspm_parsed.data_parsed

	new_map.map_type = MapType.SSPM
	new_map.path = path
	new_map.audio = sspm_parsed.audio
	new_map.raw_data = sspm_parsed.data_csv
	new_map.data = data
	new_map.loaded_successfully = len(data) > 0
	new_map.cover = sspm_parsed.cover
	new_map.map_name = sspm_parsed.name
	new_map.charter_name = sspm_parsed.mapper

	return new_map

static func from_path_phxm(path: String) -> Map: #path to a .phxm file
	var new_map: Map = Map.new()

	var phxm_parsed: PHXMParser.PHXM = PHXMParser.load_from_path(path)
	var data: Array =  phxm_parsed.data_parsed

	new_map.map_type = MapType.PHXM
	new_map.path = path
	new_map.audio = phxm_parsed.audio
	new_map.raw_data = phxm_parsed.data_csv
	new_map.data = data
	new_map.loaded_successfully = len(data) > 0
	new_map.cover = phxm_parsed.cover
	new_map.map_name = phxm_parsed.metadata.Title
	new_map.author_name = phxm_parsed.metadata.Artist
	new_map.charter_name = ", ".join(phxm_parsed.metadata.Mappers)

	return new_map
