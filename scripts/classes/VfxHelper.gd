extends Node3D
class_name VfxHelper

const LOOK_DAMP: float = 0.05
const VELOCITY_MULTIPLIER: float = 0.25

@onready var velocity_rotated: Node3D = $VelocityRotated

var game_handler: GameHandler
var cursor: Cursor
var cursor_velocity: Vector3

func _ready() -> void:
	game_handler = SSCS.game_handler # goyim_handler
	cursor = game_handler.cursor     # goyim_cursor
	velocity_rotated.position.z = -LOOK_DAMP

func _process(delta: float) -> void:
	cursor_velocity = (cursor.get_velocity_world() / delta) * VELOCITY_MULTIPLIER
	velocity_rotated.look_at(cursor_velocity)
