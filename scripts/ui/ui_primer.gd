extends Control

@onready var masterspace: RwmMasterspace = $"./Masterspace"

func _ready() -> void:
	print("ready!!")

	masterspace.hook_spawn(
		&"create_terminal",
		"res://scenes/ui/terminal.tscn",
		{
			"unique": true
		}
	)

	masterspace.hook_spawn(
		&"create_settings",
		"res://scenes/ui/settings/settings.tscn",
		{
			"unique": true
		}
	)

	masterspace.hook_spawn(
		&"create_map_select",
		"res://scenes/ui/map select/map_select.tscn",
		{
			"unique": true
		}
	)
