extends Control

@export var window: RwmWindow

@onready var visual: Control = $Visual
@onready var viewport_container: SubViewportContainer = $Visual/ViewportContainer
@onready var viewport: SubViewport = $Visual/ViewportContainer/Viewport
@onready var backdrop: Panel = $Visual/Backdrop
@onready var border: Panel = $Visual/Backdrop/Border
@onready var blur_layer: ColorRect = $Visual/Backdrop/BlurLayer

var config: ConfigFile
var scene: Variant

## layout stuff
var gaps_inner: int

## tween-specific stuff
var tween_transform: Tween
var tween_style_transform: int
var tween_ease_transform: int
var tween_duration_transform: float

func do_tween_transform() -> void:
	## updates
	position = window.global_position + Vector2(1, 1) * gaps_inner / 2.0
	size = window.size - Vector2(2, 2) * gaps_inner / 2.0

	## tweens
	if tween_transform: tween_transform.kill()
	tween_transform = create_tween()
	tween_transform.set_trans(tween_style_transform)
	tween_transform.set_ease(tween_ease_transform)
	tween_transform.tween_property(
		visual,
		^"position",
		position,
		tween_duration_transform
	)
	tween_transform.parallel().tween_property(
		visual,
		^"size",
		size,
		tween_duration_transform
	)
	tween_transform.parallel().tween_property(
		visual,
		^"modulate:a",
		1.0,
		tween_duration_transform
	)

func set_blur(radius: float, variance: float) -> void:
	blur_layer.material.set(
		&"shader_parameter/blur_scale",
		radius
	)
	blur_layer.material.set(
		&"shader_parameter/blur_variance",
		variance
	)

func _ready() -> void:
	## instantiate
	scene = load(window.scene_path).instantiate()
	viewport.own_world_3d = true
	viewport.add_child(scene)

	config = window.workspace.masterspace.config

	var backdrop_style: StyleBoxFlat = backdrop.get(&"theme_override_styles/panel")
	var border_style: StyleBoxFlat = border.get(&"theme_override_styles/panel")
	var corner_radius: float = config.get_value("styling", "window-corner-radius-pixels")

	backdrop_style.bg_color = Color(config.get_value("colors", "window-backdrop"))
	backdrop_style.set_corner_radius_all(corner_radius)

	border_style.border_color = Color(config.get_value("colors", "border-regular"))
	border_style.set_corner_radius_all(corner_radius)

	if config.get_value("styling", "blur-layer-enabled"):
		set_blur(0.0, 0.0)
	else:
		set_blur(
			float(config.get_value("styling", "blur-radius-pixels")),
			config.get_value("styling", "blur-variance")
		)

	## declare layout vars
	gaps_inner = config.get_value("layout", "gaps-inner-pixels")

	## prepare tweens
	tween_style_transform = RwmConfigParser.get_tween_style(config.get_value("animations", "window-transform-style"))
	tween_ease_transform = RwmConfigParser.get_tween_ease(config.get_value("animations", "window-transform-direction"))
	tween_duration_transform = config.get_value("animations", "window-transform-duration-seconds")

	## finalize
	window.updated.connect(do_tween_transform)

	## open tween
	await window.can_render
	visual.size = Vector2(0, 0)
	visual.global_position = window.global_position + (window.size / 2.0) + ((Vector2(1.0, 1.0) * gaps_inner) / 2.0)
	visual.modulate.a = 0.0
	show()
