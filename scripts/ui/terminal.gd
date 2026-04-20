extends Control

#this is some retarded bullshit but its ok

func _ready() -> void:
	if Terminal.get_parent() != null:
		Terminal.reparent(self)
	else:
		self.add_child(Terminal)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and Terminal.get_parent() == self:
		self.remove_child(Terminal)
