class_name UserInterface #this shit is literally just so that gdscript can pick up on the methods and properties elsewhere
extends Control

func _init() -> void:
	SSCS.user_interface = self

func _input(event: InputEvent) -> void:
	if !self.visible:
		accept_event()
