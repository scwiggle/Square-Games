class_name RwmWindow
extends Control

const PACKED_VISUAL_WINDOW: PackedScene = preload("res://addons/rwm/prefabs/window-visual.tscn")

var id: int: # starts at 1
	set(_new):
		pass
	get:
		return workspace.windows.find(self) + 1

var title: String
var scene_path: String # will be embedded embedded in this window
var workspace: RwmWorkspace
var binary_path: PackedByteArray
var visual: Control

var scaled_position: Vector2
var scaled_size: Vector2

signal updated
signal can_render

func _init(workspace: RwmWorkspace, scene_path: String, title: String = "") -> void:
	self.scene_path = scene_path
	self.workspace = workspace

	if title == "":
		title = scene_path.get_file().split(".")[0]

	self.title = title

	workspace.add_child(self)

func _ready() -> void:
	visual = PACKED_VISUAL_WINDOW.instantiate()
	visual.window = self
	visual.hide()
	add_child(visual)
