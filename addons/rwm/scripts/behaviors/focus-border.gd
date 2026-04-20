extends Control

@export var masterspace: RwmMasterspace

@onready var border: Panel = $Border

var config: ConfigFile

enum FadeDirection {
	IN,
	OUT
}

var true_visibility: bool = visible

## tween-specific stuff
var tween_transform: Tween
var tween_opacity: Tween # shares attributes with transform tween
var tween_style_transform: int
var tween_ease_transform: int
var tween_duration_transform: float

var target_window: RwmWindow

func fade(direction: FadeDirection) -> void:
	var out: bool = bool(direction)

	if not true_visibility == out:
		return

	true_visibility = not out

	if tween_opacity: tween_opacity.kill()
	tween_opacity = create_tween()
	tween_opacity.set_trans(tween_style_transform)
	tween_opacity.set_ease(tween_ease_transform)
	tween_opacity.tween_property(
		self,
		^"modulate:a",
		float(true_visibility),
		tween_duration_transform * 2.0
	)

func do_tween_transform() -> void:
	if tween_transform: tween_transform.kill()
	tween_transform = create_tween()
	tween_transform.set_trans(tween_style_transform)
	tween_transform.set_ease(tween_ease_transform)
	tween_transform.tween_property(
		self,
		^"position",
		target_window.position,
		tween_duration_transform
	)
	tween_transform.parallel().tween_property(
		self,
		^"size",
		target_window.size,
		tween_duration_transform
	)

func refresh_signals(new_window: RwmWindow) -> void:
	if new_window == null:
		target_window = null
		fade(FadeDirection.OUT)
		return
	elif new_window == target_window:
		return
	target_window = new_window
	modulate.a = 0
	true_visibility = false
	new_window.visual.viewport_container.grab_focus()
	do_tween_transform()
	fade(FadeDirection.IN)

func refresh_signals_full() -> void:
	# clear existing
	for workspace: RwmWorkspace in masterspace.workspaces:
		if workspace == null or not workspace.focused_window_changed.is_connected(refresh_signals): continue
		workspace.focused_window_changed.disconnect(refresh_signals)

	masterspace.focused_workspace.focused_window_changed.connect(refresh_signals)

func _ready() -> void:
	config = masterspace.config

	var style: StyleBoxFlat = border.get(&"theme_override_styles/panel")
	var border_color: Color = Color(config.get_value("colors", "border-focused"))
	var border_width: int = config.get_value("styling", "border-focused-width-pixels")
	var corner_radius: int = config.get_value("styling", "window-corner-radius-pixels")

	modulate.a = 0
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)

	## prepare tweens
	tween_style_transform = RwmConfigParser.get_tween_style(config.get_value("animations", "border-focused-style"))
	tween_ease_transform = RwmConfigParser.get_tween_ease(config.get_value("animations", "border-focused-direction"))
	tween_duration_transform = config.get_value("animations", "border-focused-duration-seconds")

	## finalize
	masterspace.focused_workspace_changed.connect(
		func(_new_workspace: RwmWorkspace) -> void:
			refresh_signals_full()
	)
