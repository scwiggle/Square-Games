extends Node3D
class_name VfxManager

@export var vfx_helper: VfxHelper

var game_handler: GameHandler
var cursor: Cursor

const PACKED_NOTE_SPARKS: PackedScene = preload("res://scenes/prefabs/vfx/note_sparks.tscn")

func _on_note_hit(note: Note) -> void:
	var note_sparks: Node3D = PACKED_NOTE_SPARKS.instantiate()
	var particles: GPUParticles3D = note_sparks.get_node(^"Particles")
	particles.process_material = particles.process_material.duplicate(true)

	var process_mat: ParticleProcessMaterial = particles.process_material
	# process_mat.initial_velocity_max = vfx_helper.cursor_velocity.length() * vfx_helper.VELOCITY_MULTIPLIER
	# process_mat.initial_velocity_min = process_mat.initial_velocity_max
	process_mat.color = note.color

	add_child(note_sparks)

	note_sparks.global_position = cursor.global_position
	note_sparks.rotation = vfx_helper.velocity_rotated.rotation
	particles.emitting = true
	particles.finished.connect(func() -> void: particles.queue_free())

func _ready() -> void:
	game_handler = SSCS.game_handler
	cursor = game_handler.cursor

	game_handler.note_hit.connect(_on_note_hit)
