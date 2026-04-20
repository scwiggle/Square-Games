class_name RwmMasterspace
extends Control

var config: ConfigFile
var workspaces: Array[RwmWorkspace]
var focused_workspace: RwmWorkspace
var custom_binds: Dictionary[StringName, Dictionary] = {}

var focus_border: Control = load("res://addons/rwm/prefabs/focus-border.tscn").instantiate()

signal focused_workspace_changed(new_workspace: RwmWorkspace)

func _init() -> void:
	config = RwmConfigParser.load_config_auto()
	workspaces.resize(9)

	focus_border.masterspace = self
	add_child(focus_border)

func _ready() -> void:
	go_to_workspace(0)

func _input(event: InputEvent) -> void:
	for bind in custom_binds.keys(): if event.is_action_pressed(bind):
		var bind_values: Dictionary = custom_binds.get(bind)
		var scene_path: String = bind_values.get(&"scene-path")
		var is_unique: bool = bind_values.has(&"unique") and bind_values.get(&"unique")
		var workspace_window_scene_paths: Array = workspaces.filter(func(workspace: Variant) -> bool: return not workspace == null).map(get_window_scene_paths)
		var workspace_window_scene_paths_flat: Array[String]
		for path_array: Array in workspace_window_scene_paths:
			workspace_window_scene_paths_flat.append_array(path_array)
		print(bind_values)
		print(scene_path)
		print(is_unique)
		print(workspace_window_scene_paths_flat)
		print()
		if is_unique and scene_path in workspace_window_scene_paths_flat:
			continue
		focused_workspace.add_window(scene_path)

	if Input.is_action_pressed(&"rwm-workspace-change-modifier") and !event.is_echo() and event.is_pressed():
		var target_workspace: int = -1
		var workspace_layout: String = config.get_value("styling", "workspace-layout-direction")

		var event_text: StringName = event.as_text()
		event_text = event_text.get_slice("+", event_text.count("+"))

		if event_text.is_valid_int():
			target_workspace = int(event_text)
		match event_text:
			&"Left": target_workspace = focused_workspace.id - 1
			&"Up": target_workspace = focused_workspace.id - 1
			&"Right": target_workspace = focused_workspace.id + 1
			&"Down": target_workspace = focused_workspace.id + 1
			&"Mouse Wheel Up": target_workspace = (focused_workspace.id - 1) if workspace_layout == &"vertical" else (focused_workspace.id - 1)
			&"Mouse Wheel Down": target_workspace = (focused_workspace.id + 1) if workspace_layout == &"vertical" else (focused_workspace.id + 1)

		if target_workspace == -1: return

		target_workspace = clampi(target_workspace, 1, 9)

		go_to_workspace(target_workspace)

func get_window_scene_path(window: RwmWindow) -> String:
	return window.scene_path

func get_window_scene_paths(workspace: RwmWorkspace) -> Array:
	return workspace.windows.map(get_window_scene_path)

func arrange_workspaces() -> void:
	var sorted_workspaces: Array[RwmWorkspace]
	for workspace: RwmWorkspace in workspaces:
		if workspace != null:
			sorted_workspaces.append(workspace)

	var focused_index = sorted_workspaces.find(focused_workspace)

	var workspace_sort_direction: Vector2

	match config.get_value("styling", "workspace-layout-direction"):
		&"vertical": workspace_sort_direction = Vector2(0, 1)
		&"horizontal": workspace_sort_direction = Vector2(1, 0)

	var i: int = 0
	for workspace: RwmWorkspace in sorted_workspaces:
		workspace.position = workspace.size * (i - focused_index) * workspace_sort_direction
		i += 1
		for window: RwmWindow in workspace.windows:
			window.updated.emit()

func hook_spawn(action: StringName, scene_path: String, attrs: Dictionary[StringName, Variant] = {}) -> void:
	custom_binds[action] = {
		&"scene-path": scene_path
	}
	for attr: StringName in attrs:
		custom_binds.get(action)[attr] = attrs.get(attr)

func go_to_workspace(id: int) -> void:
	var id_clamped: int = clampi(id, 1, 9) - 1

	if workspaces[id_clamped] == null:
		workspaces[id_clamped] = RwmWorkspace.new(self)

	var old_workspace: RwmWorkspace = focused_workspace
	focused_workspace = workspaces[id_clamped]

	if old_workspace != focused_workspace:
		focused_workspace_changed.emit(focused_workspace)

	purge_empty_workspaces()
	arrange_workspaces()

func purge_empty_workspaces() -> void:
	var i: int = 0
	while i < len(workspaces):
		var workspace = workspaces[i]
		if workspace != null and workspace != focused_workspace and workspace.windows.is_empty():
			workspaces[i] = null
			workspace.queue_free()
		i += 1
