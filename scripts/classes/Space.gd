extends Node3D
class_name Space

class SpaceMeta:
	var name: String = "Unnamed Space"
	var author: String = "Unknown"
	var blurb: String = "No blurb provided"

var meta: SpaceMeta = SpaceMeta.new()
var scene_path: String
var environment: Environment

func _init(directory: String) -> void:
	var meta_file: ConfigFile = ConfigFile.new()
	var directory_stripped: String = directory.trim_suffix("/")
	
	meta_file.load("%s/meta.ini" % directory_stripped)

	meta.name = meta_file.get_value("Space", "Name")
	meta.author = meta_file.get_value("Space", "Author")
	meta.blurb = meta_file.get_value("Space", "Blurb")

	scene_path = "%s/space.tscn" % directory_stripped

func _ready() -> void:
	var space_scene: PackedScene = load(scene_path)
	var instantiated_space: Node3D = space_scene.instantiate()
	environment = instantiated_space.get_node(^"Environment").environment
	add_child(instantiated_space)
