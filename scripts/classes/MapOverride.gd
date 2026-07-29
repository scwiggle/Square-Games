extends Node
class_name MapOverride

var data_offset_msec: int = 0

static func get_from_id(id: StringName) -> MapOverride:
	var override: MapOverride = MapOverride.new()
	var expected_path: String = "user://mapoverrides/%s" % str(id)

	if not FileAccess.file_exists(expected_path):
		return override

	var config: ConfigFile = ConfigFile.new()
	config.load(expected_path)
	override.data_offset_msec = config.get_value(
		"Override",
		"DataOffsetMsec",
		override.data_offset_msec
	)

	return override

static func get_from_path(path: String) -> MapOverride:
	return MapOverride.get_from_id(StringName(path.get_basename()))
