@tool

extends Control
class_name OffsetContainer

@export_group("Transform Offsets")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var size_offset: Vector2:
	set(value):
		size_offset = value
		_queue_update()
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var position_offset: Vector2:
	set(value):
		position_offset = value
		_queue_update()
@export_custom(PROPERTY_HINT_NONE, "suffix:°") var rotation_offset_degrees: float:
	set(value):
		rotation_offset_degrees = value
		_queue_update()
@export var scale_offset: Vector2:
	set(value):
		scale_offset = value
		_queue_update()
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var pivot_offset_offset: Vector2:
	set(value):
		pivot_offset_offset = value
		if not _syncing_pivot:
			_syncing_pivot = true
			var base_size: Vector2 = self.size
			if base_size.x != 0.0 and base_size.y != 0.0:
				pivot_offset_percentage = (self.pivot_offset + pivot_offset_offset) / base_size
			_syncing_pivot = false
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "0,1,0.001,or_greater,or_less") var pivot_offset_percentage: Vector2:
	set(value):
		pivot_offset_percentage = value
		if not _syncing_pivot:
			_syncing_pivot = true
			pivot_offset_offset = (self.size * pivot_offset_percentage) - self.pivot_offset
			_syncing_pivot = false
		_queue_update()

var target_child: Control
var _proxy: Node2D
var _update_queued: bool = false
var _reconcile_queued: bool = false
var _syncing_pivot: bool = false

func _is_proxy(node: Node) -> bool:
	return node is Node2D and node.has_meta("_is_offset_proxy")

func clear_offsets() -> void:
	size_offset = Vector2.ZERO
	position_offset = Vector2.ZERO
	rotation_offset_degrees = 0.0
	scale_offset = Vector2.ZERO
	pivot_offset_offset = Vector2.ZERO

func _ready() -> void:
	set_notify_transform(true)
	_queue_reconcile()

	self.child_entered_tree.connect(func(_node: Node) -> void: _queue_reconcile())
	self.child_exiting_tree.connect(func(_node: Node) -> void: _queue_reconcile())

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resync_pivot_from_percentage()
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_RESIZED:
		_queue_update()

func _resync_pivot_from_percentage() -> void:
	if _syncing_pivot: return
	_syncing_pivot = true
	pivot_offset_offset = (self.size * pivot_offset_percentage) - self.pivot_offset
	_syncing_pivot = false

func _queue_reconcile() -> void:
	if _reconcile_queued: return
	_reconcile_queued = true
	call_deferred("_reconcile")

func _reconcile() -> void:
	_reconcile_queued = false

	if not (is_instance_valid(_proxy) and _proxy.is_inside_tree()):
		_proxy = null

	var raw_child: Node = null
	for c in self.get_children():
		if not _is_proxy(c):
			raw_child = c
			break

	if raw_child == null:
		if is_instance_valid(_proxy) and _proxy.get_child_count() > 0:
			target_child = _proxy.get_child(0)
		else:
			target_child = null
		_update_render()
		return

	if not is_instance_valid(_proxy):
		_proxy = Node2D.new()
		_proxy.name = "_OffsetProxy"
		_proxy.set_meta("_is_offset_proxy", true)
		self.add_child(_proxy)
		_try_set_owner(_proxy)

	if raw_child.get_parent() != _proxy:
		raw_child.get_parent().remove_child(raw_child)
		_proxy.add_child(raw_child)
		_try_set_owner(raw_child)

	target_child = raw_child
	_update_render()

func _try_set_owner(node: Node) -> void:
	if not Engine.is_editor_hint(): return
	if not node.is_inside_tree(): return

	var root: Node = get_tree().edited_scene_root
	if root == null: return
	if not root.is_ancestor_of(node): return

	node.owner = root

func _queue_update() -> void:
	if _update_queued: return
	_update_queued = true
	call_deferred("_update_render")

func _update_render() -> void:
	_update_queued = false
	if not target_child or not is_instance_valid(_proxy): return

	var new_size: Vector2 = self.size + size_offset
	var new_pivot: Vector2 = self.pivot_offset + pivot_offset_offset
	var new_scale: Vector2 = self.scale + scale_offset
	var new_rotation_degrees: float = self.rotation_degrees + rotation_offset_degrees
	var new_pos: Vector2 = self.global_position + position_offset

	target_child.position = -new_pivot
	target_child.size = new_size

	_proxy.global_position = new_pos + new_pivot
	_proxy.rotation_degrees = new_rotation_degrees
	_proxy.scale = new_scale
