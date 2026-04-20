class_name RwmConfigParser
extends Node

const ALLOW_OVERRIDE: bool = true # allows user:// overrides
const POSSIBLE_CONFIG_PATHS: PackedStringArray = [
	"user://rwm.cfg", # user-defined config first
	"res://addons/rwm/rwm.cfg"
]

static func find_config() -> String:
	var possible_paths_cleaned: PackedStringArray = POSSIBLE_CONFIG_PATHS
	if not ALLOW_OVERRIDE: possible_paths_cleaned.erase("user://rwm.cfg")

	for possible_path: String in possible_paths_cleaned:
		if FileAccess.file_exists(possible_path):
			return possible_path

	return possible_paths_cleaned[0] # last resort

static func load_config(path: String) -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	config.load(path)
	return config

static func load_config_auto() -> ConfigFile:
	var path: String = find_config()
	return load_config(path)

## helpers
static func get_tween_style(input: String = "linear") -> int:
	return Tween["TRANS_%s" % input.to_upper().replace("-", "_")]

static func get_tween_ease(input: String = "in-out") -> int:
	return Tween["EASE_%s" % input.to_upper().replace("-", "_")]
