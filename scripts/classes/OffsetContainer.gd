@tool

extends Control
class_name OffsetContainer

@export_group("Transform Offsets")
@export var size_offset: Vector2:
	set(value):
		size_offset = value
		_update_render()
@export var position_offset: Vector2:
	set(value):
		position_offset = value
		_update_render()
@export var rotation_offset: float:
	set(value):
		rotation_offset = value
		_update_render()
@export var scale_offset: Vector2:
	set(value):
		scale_offset = value
		_update_render()
@export var pivot_offset_offset: Vector2: # lmao
	set(value):
		pivot_offset_offset = value
		_update_render()

var target_child: Control

func _update_target() -> bool:
	if not self.get_child_count() > 0:
		target_child = null
		return false

	target_child           = self.get_child(0)
	target_child.top_level = true
	_update_render()

	return true

func clear_offsets() -> void:
	size_offset = Vector2.ZERO
	position_offset = Vector2.ZERO
	rotation_offset = 0.0
	scale_offset = Vector2.ZERO
	pivot_offset_offset = Vector2.ZERO

func _ready() -> void:
	_update_target()

	self.child_entered_tree.connect(func(_node: Node) -> void: _update_target())
	self.child_exiting_tree.connect(func(_node: Node) -> void: _update_target())

func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAW: return
	_update_render()

func _update_render() -> void:
	print("dateup rdner")
	if not target_child: return
	
	print("update reder")

	target_child.global_position = self.global_position + position_offset
	target_child.size = self.size + size_offset
	target_child.rotation = self.rotation + rotation_offset
	target_child.scale = self.scale + scale_offset
	target_child.pivot_offset = self.pivot_offset + pivot_offset_offset
