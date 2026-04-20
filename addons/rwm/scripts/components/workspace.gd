class_name RwmWorkspace
extends Control

var id: int: # starts at 1
	set(_new):
		pass
	get:
		return masterspace.workspaces.find(self) + 1

var windows: Array[RwmWindow]
var window_arranger: RwmWindowArranger
var masterspace: RwmMasterspace
var focused_window: RwmWindow
var cursor_focused_window: RwmWindow

var dim_rect: ColorRect = ColorRect.new()
var dim_tween: Tween
var dim_tween_style: int
var dim_tween_ease: int
var dim_tween_duration: float
var dim_amount: float

signal focused_window_changed(new_window: RwmWindow)
signal occupation_changed(is_occupied: bool)

func _init(masterspace: RwmMasterspace) -> void:
	self.masterspace = masterspace
	masterspace.add_child(self)
	window_arranger = RwmWindowArranger.new(self)

	masterspace.resized.connect(func() -> void:
		update_focus()
	)

func _ready() -> void:
	dim_rect.color = Color(0.0, 0.0, 0.0)
	# dim_rect.z_as_relative = true
	# dim_rect.z_index = -1

	var config: ConfigFile = masterspace.config
	var dim_mode: StringName = StringName(config.get_value("styling", "wallpaper-dim-mode"))
	dim_amount = config.get_value("styling", "wallpaper-dim-amount")
	dim_tween_style = RwmConfigParser.get_tween_style(config.get_value("animations", "wallpaper-dim-style"))
	dim_tween_ease = RwmConfigParser.get_tween_ease(config.get_value("animations", "wallpaper-dim-direction"))
	dim_tween_duration = config.get_value("animations", "wallpaper-dim-duration-seconds")

	match dim_mode:
		&"always":
			dim_rect.modulate.a = dim_amount
		&"never":
			dim_rect.hide()
		&"occupied":
			dim_rect.modulate.a = 0.0
			occupation_changed.connect(update_dim_state)

	add_child(dim_rect)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)

	masterspace.focused_workspace_changed.connect(func(new_workspace: RwmWorkspace) -> void:
		focused_window = null
		cursor_focused_window = null
		update_focus()
		if focused_window == null:
			focused_window_changed.emit(null)
	)


func update_dim_state(should_dim: bool) -> void:
	if dim_tween: dim_tween.kill()
	dim_tween = create_tween()
	dim_tween.set_trans(dim_tween_style)
	dim_tween.set_ease(dim_tween_ease)
	dim_tween.tween_property(
		dim_rect,
		^"modulate:a",
		dim_amount * float(should_dim),
		dim_tween_duration
	)

func add_window(scene_path: String, title: String = "") -> void:
	var window: RwmWindow = RwmWindow.new(self, scene_path, title)
	if window_arranger.add_window_at_position(window, get_global_mouse_position() / get_viewport_rect().size):
		if window_arranger.captured_window:
			window_arranger.uncapture()
		windows.append(window)
		window.can_render.emit()
		update_focus()
		if len(windows) == 1:
			occupation_changed.emit(true)
	else:
		window.queue_free()

func remove_window(window: RwmWindow) -> void:
	if window in windows:
		windows.erase(window)
		window.queue_free()
		window_arranger.remove_window(window)
		update_focus()
		if len(windows) == 0:
			occupation_changed.emit(false)
		return

	if window == null:
		push_warning("attempted to close a null window")
	else:
		push_warning("attempted to close window '{title}' ({id}) but it didn't exist".format({
			"title": window.title,
			"id": window.id
		}))

func update_focus() -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	var found: bool = false
	var new_window: RwmWindow = null

	if window_arranger.captured_window != null:
		if window_arranger.captured_window.get_rect().has_point(mouse_position):
			new_window = window_arranger.captured_window
			found = true
	else:
		for window: RwmWindow in windows:
			if not window.get_rect().has_point(mouse_position):
				continue

			new_window = window
			found = true
			break

	if new_window != cursor_focused_window:
		cursor_focused_window = new_window
		focused_window = new_window
		focused_window_changed.emit(new_window)

func _input(event: InputEvent) -> void:
	if not masterspace.focused_workspace == self:
		return

	if event.is_action_pressed(&"rwm-close") and not focused_window == null:
		if window_arranger.captured_window:
			window_arranger.uncapture()
		var focused_position: Vector2 = focused_window.position / masterspace.size
		remove_window(focused_window)

		if len(windows) != 0:
			var path_to_new_window: PackedByteArray = window_arranger.get_binary_path_to_window_at_position(focused_position + Vector2(0.01, 0.01))
			var end_window_direction: int = path_to_new_window[-1]
			path_to_new_window.resize(len(path_to_new_window) - 1)

			var new_end_branch: Array = window_arranger.windows
			for direction: int in path_to_new_window:
				new_end_branch = new_end_branch[direction]

			focused_window = new_end_branch[end_window_direction]
			focused_window_changed.emit(focused_window)

	if event.is_action_pressed(&"rwm-move-down") or event.is_action_pressed(&"rwm-move-up") or event.is_action_pressed(&"rwm-move-left") or event.is_action_pressed(&"rwm-move-right"):
		if !focused_window or len(windows) <= 1: return

		var offset: Vector2
		if event.is_action_pressed(&"rwm-move-down"):
			offset = Vector2(0.01, 0.01) + (focused_window.position + Vector2(0, 1) * focused_window.size) / masterspace.size
		elif event.is_action_pressed(&"rwm-move-right"):
			offset = Vector2(0.01, 0.01) + (focused_window.position + Vector2(1, 0) * focused_window.size) / masterspace.size
		elif event.is_action_pressed(&"rwm-move-up"):
			offset = Vector2(0.01, -0.01) + (focused_window.position) / masterspace.size
		elif event.is_action_pressed(&"rwm-move-left"):
			offset = Vector2(-0.01, 0.01) + (focused_window.position) / masterspace.size

		var path_to_window: PackedByteArray = window_arranger.get_binary_path_to_window_at_position(focused_window.position / masterspace.size + Vector2(0.01, 0.01))
		var window_direction: int = path_to_window[-1]
		path_to_window.resize(len(path_to_window) - 1)

		var end_branch: Array = window_arranger.windows
		for direction: int in path_to_window:
			end_branch = end_branch[direction]

		var path_to_new_window: PackedByteArray = window_arranger.get_binary_path_to_window_at_position(offset)
		var new_window_direction: int = path_to_new_window[-1]
		path_to_new_window.resize(len(path_to_new_window) - 1)

		var new_end_branch: Array = window_arranger.windows
		for direction: int in path_to_new_window:
			new_end_branch = new_end_branch[direction]

		var current_window: RwmWindow = end_branch[window_direction]
		var new_window: RwmWindow = new_end_branch[new_window_direction]

		if current_window != new_window:
			if window_arranger.captured_window:
				window_arranger.uncapture()
			end_branch[window_direction] = new_window
			new_end_branch[new_window_direction] = current_window

			window_arranger.update_window_positions()
			#have to pulse the focused window changed event to make the border update
			focused_window_changed.emit(null)
			focused_window_changed.emit(current_window)

			if masterspace.config.get_value("behavior", "window-operation-warp-cursor"):
				Input.warp_mouse(masterspace.position + focused_window.position + focused_window.size / 2.0)
	elif event.is_action_pressed(&"rwm-focus-down") or event.is_action_pressed(&"rwm-focus-up") or event.is_action_pressed(&"rwm-focus-left") or event.is_action_pressed(&"rwm-focus-right"):
		if !focused_window or len(windows) <= 1: return

		var offset: Vector2
		if event.is_action_pressed(&"rwm-focus-down"):
			offset = Vector2(0.01, 0.01) + (focused_window.position + Vector2(0, 1) * focused_window.size) / masterspace.size
		elif event.is_action_pressed(&"rwm-focus-right"):
			offset = Vector2(0.01, 0.01) + (focused_window.position + Vector2(1, 0) * focused_window.size) / masterspace.size
		elif event.is_action_pressed(&"rwm-focus-up"):
			offset = Vector2(0.01, -0.01) + (focused_window.position) / masterspace.size
		elif event.is_action_pressed(&"rwm-focus-left"):
			offset = Vector2(-0.01, 0.01) + (focused_window.position) / masterspace.size

		var path_to_new_window: PackedByteArray = window_arranger.get_binary_path_to_window_at_position(offset)
		var end_window_direction: int = path_to_new_window[-1]
		path_to_new_window.resize(len(path_to_new_window) - 1)

		var new_end_branch: Array = window_arranger.windows
		for direction: int in path_to_new_window:
			new_end_branch = new_end_branch[direction]

		if focused_window != new_end_branch[end_window_direction]:
			if window_arranger.captured_window:
				window_arranger.uncapture()
			focused_window = new_end_branch[end_window_direction]
			focused_window_changed.emit(focused_window)

			if masterspace.config.get_value("behavior", "window-operation-warp-cursor"):
				Input.warp_mouse(masterspace.position + focused_window.position + focused_window.size / 2.0)

	if Input.is_action_pressed("rwm-workspace-move-modifier") and !event.is_echo() and event.is_pressed():
		var target_workspace: int = -1

		var event_text: StringName = event.as_text()
		event_text = event_text.get_slice("+", event_text.count("+"))

		if event_text.is_valid_int():
			target_workspace = int(event_text)

		if target_workspace == -1: return

		target_workspace = clampi(target_workspace, 1, 9)

		var target_workspace_node: RwmWorkspace = masterspace.workspaces[target_workspace - 1]

		var target_window: RwmWindow = focused_window

		if target_workspace_node == null:
			target_workspace_node = RwmWorkspace.new(masterspace)
			masterspace.workspaces[target_workspace - 1] = target_workspace_node
			masterspace.arrange_workspaces()

		if target_window != null and target_workspace_node != self:
			print(focused_window.position / masterspace.size)

			if target_workspace_node.window_arranger.add_window_at_position(focused_window, focused_window.position / masterspace.size):
				if window_arranger.captured_window:
					window_arranger.uncapture()
				windows.erase(target_window)
				window_arranger.remove_window(target_window)
				update_focus()
				if len(windows) == 0:
					occupation_changed.emit(false)

				target_window.workspace = target_workspace_node
				remove_child(target_window)
				target_workspace_node.add_child(target_window)
				target_workspace_node.windows.append(target_window)
				target_workspace_node.window_arranger.update_window_positions()


				if masterspace.config.get_value("behavior", "workspace-follow-window-movement"):
					masterspace.go_to_workspace(target_workspace)

	if event.is_action_pressed(&"rwm-window-maximize") or event.is_action_pressed(&"rwm-window-fullscreen"):
		print("do")
		var fullscreen: bool = event.is_action_pressed(&"rwm-window-fullscreen")
		if window_arranger.captured_window == null and focused_window != null:
			print("capture")
			window_arranger.capture(focused_window, fullscreen)
		elif window_arranger.is_captured_window_fullscreen == fullscreen:
			print("uncapture")
			window_arranger.uncapture()
		elif focused_window != null:
			print("capture")
			window_arranger.capture(focused_window, fullscreen)

		update_focus()
		masterspace.focus_border.refresh_signals(null)
		masterspace.focus_border.refresh_signals(focused_window)

	## cursor stuff
	if not event is InputEventMouseMotion:
		return

	update_focus()
