extends Node
class_name MapOverride

var data_offset_msec: int = 0

static func get_from_id(id: StringName) -> MapOverride:
	var override: MapOverride = MapOverride.new()
	var expected_path: String = "user://mapoverrides/%s.ini" % str(id)

	if not FileAccess.file_exists(expected_path):
		print("override at %s not present" % expected_path)
		return override

	print("loading override from %s" % expected_path)

	var config: ConfigFile = ConfigFile.new()
	config.load(expected_path)
	override.data_offset_msec = config.get_value(
		"Override",
		"DataOffsetMsec",
		override.data_offset_msec
	)

	return override

static func get_from_path(path: String) -> MapOverride:
	return MapOverride.get_from_id(StringName(path.get_file().get_basename()))
