extends Node3D
class_name Hud

@onready var viewport_right: SubViewport = %InfoRightViewport
@onready var text_right: RichTextLabel = %InfoRightText

@onready var spectated_user: RichTextLabel = %SpectatedUser

@onready var viewport_bottom: SubViewport = %InfoBottomViewport
@onready var health_bar: ProgressBar = %HealthBar

var info_right_base: String

func _ready() -> void:
	info_right_base = text_right.text

	self.position=Vector3(0,0,SSCS.settings.grid_distance)
	self.scale = Vector3(1, 1, 1) * SSCS.settings.hud_scale

	update_info_right(0, 0)

func update_info_right(hits: int, misses: int) -> void:
	text_right.text = info_right_base.format([hits,misses])
	#viewport_right.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	#viewport_right.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_info_bottom(health: float) -> void:
	health_bar.value = health
	#viewport_bottom.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	#viewport_bottom.render_target_update_mode = SubViewport.UPDATE_ONCE

func update_info_top(spectated: String) -> void:
	spectated_user.text = "[center]%s[/center]" % spectated
