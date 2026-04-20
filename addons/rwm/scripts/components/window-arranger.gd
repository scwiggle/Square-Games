class_name RwmWindowArranger
extends Control

var workspace: RwmWorkspace
var masterspace: RwmMasterspace

var windows: Array = [] # binary tree where the leaves are RwmWindow
var captured_window: RwmWindow
var is_captured_window_fullscreen: bool = false

var config: ConfigFile

func _ready() -> void:
	masterspace.resized.connect(
		func() -> void:
			if captured_window != null and is_captured_window_fullscreen:
				print("resize")
				captured_window.size = masterspace.size + Vector2(1.0, 1.0) * config.get_value("layout", "gaps-inner-pixels")
				captured_window.updated.emit()
			else:
				update_window_positions(windows)
	)

func get_binary_path_to_window_at_position(position: Vector2) -> PackedByteArray:
	if len(windows) == 1:
		return [0]

	var path: PackedByteArray
	var current_branch: Array = windows
	var current_split: Vector2 = Vector2(0.5, 0.5)
	var split_vertical: bool = true
	var split_scale: Vector2 = Vector2(0.25, 0.25)

	while true:
		if split_vertical:
			if position.x < current_split.x:
				current_split.x -= split_scale.x
				path.append(0)
			else:
				current_split.x += split_scale.x
				path.append(1)
			split_scale.x /= 2
		else:
			if position.y < current_split.y:
				current_split.y -= split_scale.y
				path.append(0)
			else:
				current_split.y += split_scale.y
				path.append(1)
			split_scale.y /= 2
		split_vertical = !split_vertical

		if typeof(current_branch[path[-1]]) != TYPE_ARRAY: break

		current_branch = current_branch[path[-1]]

	return path

func capture(window: RwmWindow, fullscreen: bool) -> void:
	captured_window = window
	is_captured_window_fullscreen = fullscreen

	for other_window: RwmWindow in workspace.windows:
		if other_window != window:
			other_window.visual.visible = false

	if fullscreen:
		window.position = ceil(-Vector2(1.0, 1.0) * config.get_value("layout", "gaps-inner-pixels") / 2.0)
		window.size = masterspace.size + Vector2(1.0, 1.0) * config.get_value("layout", "gaps-inner-pixels")

		var visual: Control = window.visual

		visual.backdrop.get(&"theme_override_styles/panel").set_corner_radius_all(0)
		visual.border.get(&"theme_override_styles/panel").set_corner_radius_all(0)
		visual.border.get(&"theme_override_styles/panel").set_border_width_all(0)

		window.updated.emit()
	else:
		update_window_positions([window])

func uncapture() -> void:
	captured_window = null

	for other_window: RwmWindow in workspace.windows:
		other_window.visual.visible = true

		var visual: Control = other_window.visual
		var corner_radius: float = config.get_value("styling", "window-corner-radius-pixels")

		visual.backdrop.get(&"theme_override_styles/panel").set_corner_radius_all(corner_radius)
		visual.border.get(&"theme_override_styles/panel").set_corner_radius_all(corner_radius)
		visual.border.get(&"theme_override_styles/panel").set_border_width_all(1)

	update_window_positions()


func add_window_at_position(window: RwmWindow, position: Vector2) -> bool: #returns if the addition was successful
	if len(windows) == 0:
		windows.append(window)
		update_window_positions(windows)
		return true
	if len(windows) == 1:
		if position.x < 0.5:
			windows.push_front(window)
		else:
			windows.append(window)
		update_window_positions(windows)
		return true

	var current_branch: Array = windows
	var current_split: Vector2 = Vector2(0.5, 0.5)
	var split_vertical: bool = true
	var split_scale: Vector2 = Vector2(0.25, 0.25)
	var direction: int
	var depth: int = 0

	while true:
		if split_vertical:
			if position.x < current_split.x:
				current_split.x -= split_scale.x
				direction = 0
			else:
				current_split.x += split_scale.x
				direction = 1
			split_scale.x /= 2
		else:
			if position.y < current_split.y:
				current_split.y -= split_scale.y
				direction = 0
			else:
				current_split.y += split_scale.y
				direction = 1
			split_scale.y /= 2
		split_vertical = !split_vertical

		if typeof(current_branch[direction]) != TYPE_ARRAY: break
		current_branch = current_branch[direction]
		depth += 1

	if depth >= config.get_value("behavior", "max-split-depth") - 1:
		return false

	var final_direction: int
	if split_vertical:
		if position.x < current_split.x:
			final_direction = 0
		else:
			final_direction = 1
	else:
		if position.y < current_split.y:
			final_direction = 0
		else:
			final_direction = 1

	var original_window: RwmWindow = current_branch[direction]

	var new_branch: Array = []
	new_branch.resize(2)
	new_branch[final_direction] = window
	new_branch[final_direction - 1] = original_window
	current_branch[direction] = new_branch

	update_window_positions(windows)
	# print(windows)

	return true

##does NOT return anything meant to be used externally, the return value is used internally by the function as it is recursive
func remove_window(window: RwmWindow, current_branch: Array = windows) -> int:
	var i: int = 0
	for leaf: Variant in current_branch:
		if typeof(leaf) != TYPE_ARRAY and leaf == window:
			current_branch.erase(leaf)
			if current_branch == windows and len(current_branch) > 0:
				var remaining_leaf: Variant = current_branch[0]
				if typeof(remaining_leaf) == TYPE_ARRAY:
					# print("remove window tier")
					windows = remaining_leaf
				update_window_positions()
				return -2
			return i
		elif typeof(leaf) == TYPE_ARRAY:
			var result: int = remove_window(window, leaf)
			if result == -2:
				return -2
			elif result > -1:
				current_branch[i] = leaf[0]
				update_window_positions()
				return -2
		i += 1
	return -1

func update_window_positions(current_branch: Array = windows, current_position: Vector2 = Vector2(), current_size: Vector2 = Vector2(1, 1), split_vertical: bool = true) -> void:
	var gap_offset: float = (config.get_value("layout", "gaps-outer-pixels") - config.get_value("layout", "gaps-inner-pixels") / 2.0)
	var offset_masterspace_size: Vector2 = masterspace.size - Vector2(2, 2) * gap_offset
	if len(current_branch) == 1:
		current_branch[0].scaled_position = current_position
		current_branch[0].scaled_size = current_size
		current_branch[0].position = current_position * offset_masterspace_size + Vector2(1, 1) * gap_offset
		current_branch[0].size = current_size * offset_masterspace_size
		current_branch[0].updated.emit()
		return

	var direction_vector: Vector2 = Vector2(
		1 if split_vertical else 0,
		0 if split_vertical else 1,
	)

	var i: int = 0
	for leaf: Variant in current_branch:
		var shifted_size: Vector2 = current_size - current_size * direction_vector * 0.5
		var shifted_position: Vector2 = current_position + shifted_size * direction_vector * i

		if typeof(leaf) == TYPE_ARRAY:
			update_window_positions(leaf, shifted_position, shifted_size, !split_vertical)
		else:
			leaf.scaled_position = shifted_position
			leaf.scaled_size = shifted_size
			leaf.position = shifted_position * offset_masterspace_size + Vector2(1, 1) * gap_offset
			leaf.size = shifted_size * offset_masterspace_size
			leaf.updated.emit()
		i += 1

func _init(workspace: RwmWorkspace) -> void:
	self.workspace = workspace
	self.masterspace = workspace.masterspace
	config = masterspace.config
	workspace.add_child(self)
