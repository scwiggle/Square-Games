extends Node3D
class_name Hud

@onready var viewport_right: SubViewport = %InfoRightViewport
@onready var text_right: RichTextLabel = %InfoRightText

@onready var spectated_user: RichTextLabel = %SpectatedUser

@onready var viewport_bottom: SubViewport = %InfoBottomViewport
@onready var health_bar: ProgressBar = %HealthBar

const HEALTH_BAR_TWEEN_DURATION_SEC: float = 0.5

var info_right_base: String
var health_bar_tween: Tween

func _ready() -> void:
	info_right_base = text_right.text

	self.position=Vector3(0,0,SSCS.settings.grid_distance)
	self.scale = Vector3(1, 1, 1) * SSCS.settings.hud_scale

	update_info_right(0, 0)

func update_info_right(hits: int, misses: int) -> void:
	text_right.text = info_right_base.format([hits,misses])

func update_info_bottom(health: float) -> void:
	if health_bar_tween: health_bar_tween.kill()
	health_bar_tween = health_bar.create_tween()
	health_bar_tween.set_ease(Tween.EASE_OUT)
	health_bar_tween.set_trans(Tween.TRANS_EXPO)
	health_bar_tween.tween_property(
		health_bar,
		^"value",
		health,
		HEALTH_BAR_TWEEN_DURATION_SEC
	)

func update_info_top(spectated: String) -> void:
	spectated_user.text = "[center]%s[/center]" % spectated
