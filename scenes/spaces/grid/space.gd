extends Node3D

@onready var environment: Environment = $Environment.environment
@onready var tiles: MeshInstance3D = $Floor/Tiles
@onready var layer: MeshInstance3D = $Floor/Layer

const TRANSITION_DURATION_SEC: float = 0.5

var game_handler: GameHandler
var transition_tween: Tween
var target_color: Color

func _transition_to_color(new_color: Color) -> void:
	if transition_tween: transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.tween_property(
		self,
		^"target_color",
		new_color,
		TRANSITION_DURATION_SEC
	)

func _update_colors() -> void:
	environment.sky.sky_material.sky_horizon_color = target_color
	environment.sky.sky_material.ground_horizon_color = target_color
	tiles.mesh.material.albedo_color = target_color
	layer.mesh.material.albedo_color = target_color

func _on_note_hit(note: Note) -> void:
	_transition_to_color(note.color)

func _ready() -> void:
	game_handler = SSCS.game_handler
	game_handler.note_hit.connect(_on_note_hit)

	target_color = SSCS.settings.color_set[-1]
	_update_colors()

func _process(_delta: float) -> void:
	if not transition_tween or not transition_tween.is_running():
		return

	_update_colors()
