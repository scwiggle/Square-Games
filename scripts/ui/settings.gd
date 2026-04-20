extends Control

const settings_tab_scene: PackedScene = preload("res://scenes/ui/settings/settings_tab.tscn")

const setting_scenes: Dictionary[String, PackedScene] = {
	"bool" = preload("res://scenes/ui/settings/bool.tscn"),
	"string" = preload("res://scenes/ui/settings/string.tscn")
}

var tabs: Dictionary[String, ScrollContainer]

func add_tab(tab_name: String) -> void:
	var new_tab: ScrollContainer = settings_tab_scene.instantiate()
	new_tab.name = tab_name
	$"MarginContainer/TabContainer".add_child(new_tab)
	
	tabs[tab_name] = new_tab

func add_setting(tab_name: String, setting_name: String, setting_type: String, on_changed: Callable, default_value: Variant) -> void:
	var new_setting: HBoxContainer = setting_scenes[setting_type].instantiate()
	
	new_setting.get_node("RichTextLabel").text = setting_name
	
	#I sincerely apologize for any damages caused by the code following this comment.
	match setting_type:
		"bool":
			new_setting.get_node("CheckBox").button_pressed = default_value
			new_setting.get_node("CheckBox").toggled.connect(on_changed.bind(new_setting.get_node("CheckBox")))
		"string":
			new_setting.get_node("LineEdit").text = var_to_str(default_value)
			new_setting.get_node("LineEdit").text_submitted.connect(on_changed.bind(new_setting.get_node("LineEdit")))
	
	tabs[tab_name].get_node("MarginContainer/VBoxContainer").add_child(new_setting)

func default_bool_callback(value: bool, input: CheckBox, setting_name: String) -> void:
	SSCS.set_setting(setting_name, value, true)

func default_string_callback(value: String, input: LineEdit, setting_name: String) -> void:
	SSCS.set_setting(setting_name, var_to_str(value), true)
	input.text = var_to_str(SSCS.settings[setting_name])

var settings_metadata: Dictionary = {
	"Gameplay" = {
		"approach_rate" = {
			"name" = "Approach Rate",
			"type" = "string",
			"callback" = default_string_callback.bind("approach_rate")
		},
		"spawn_distance" = {
			"name" = "Spawn Distance",
			"type" = "string",
			"callback" = default_string_callback.bind("spawn_distance")
		},
		"grid_distance" = {
			"name" = "Grid Distance",
			"type" = "string",
			"callback" = default_string_callback.bind("grid_distance")
		},
		"vanish_distance" = {
			"name" = "Vanish Distance",
			"type" = "string",
			"callback" = default_string_callback.bind("vanish_distance")
		},
		"parallax" = {
			"name" = "Parallax",
			"type" = "string",
			"callback" = default_string_callback.bind("parallax")
		},
		"pixels_per_grid_unit" = {
			"name" = "Pixels Per Grid Unit",
			"type" = "string",
			"callback" = default_string_callback.bind("pixels_per_grid_unit")
		},
		"fov" = {
			"name" = "Field of View",
			"type" = "string",
			"callback" = default_string_callback.bind("fov")
		},
		"semi_spin" = {
			"name" = "Fake Spin",
			"type" = "bool",
			"callback" = default_bool_callback.bind("semi_spin")
		},
		"true_spin" = {
			"name" = "Spin",
			"type" = "bool",
			"callback" = default_bool_callback.bind("true_spin")
		},
		"sound_space_accurate_camera" = {
			"name" = "Sound Space Accurate Camera",
			"type" = "bool",
			"callback" = default_bool_callback.bind("sound_space_accurate_camera")
		},
		"disable_pausing" = {
			"name" = "Disable Pause",
			"type" = "bool",
			"callback" = default_bool_callback.bind("disable_pausing")
		},
		"record_replays" = {
			"name" = "Record Replays",
			"type" = "bool",
			"callback" = default_bool_callback.bind("record_replays")
		},
		"smooth_replays" = {
			"name" = "Smooth Replays",
			"type" = "bool",
			"callback" = default_bool_callback.bind("smooth_replays")
		},
		"use_replay_settings" = {
			"name" = "Use Replay Settings",
			"type" = "bool",
			"callback" = default_bool_callback.bind("use_replay_settings")
		},
	},
	"Visuals" = {
		"note_transparency" = {
			"name" = "Note Transparency",
			"type" = "string",
			"callback" = default_string_callback.bind("note_transparency")
		},
		"note_begin_transparency" = {
			"name" = "Note Fade In Transparency",
			"type" = "string",
			"callback" = default_string_callback.bind("note_begin_transparency")
		},
		"note_fade_in_begin" = {
			"name" = "Note Fade In Begin",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_in_begin")
		},
		"note_fade_in_end" = {
			"name" = "Note Fade In End",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_in_end")
		},
		
		"note_end_transparency" = {
			"name" = "Note Fade Out Transparency",
			"type" = "string",
			"callback" = default_string_callback.bind("note_end_transparency")
		},
		"note_fade_out_begin" = {
			"name" = "Note Fade Out Begin",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_out_begin")
		},
		"note_fade_out_end" = {
			"name" = "Note Fade Out End",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_out_end")
		},
		"hud_scale" = {
			"name" = "Hud Scale",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_out_end")
		},
		"cursor_scale" = {
			"name" = "Cursor Scale",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_out_end")
		},
		"note_scale" = {
			"name" = "Note Scale",
			"type" = "string",
			"callback" = default_string_callback.bind("note_fade_out_end")
		},
	},
	"Display" = {
		"fullscreen" = {
			"name" = "Fullscreen",
			"type" = "bool",
			"callback" = default_bool_callback.bind("fullscreen")
		},
	},
	"Audio" = {
		"map_volume" = {
			"name" = "Map Volume",
			"type" = "string",
			"callback" = default_string_callback.bind("map_volume")
		},
		"hit_sound_volume" = {
			"name" = "Hit Sound Volume",
			"type" = "string",
			"callback" = default_string_callback.bind("hit_sound_volume")
		},
		"miss_sound_volume" = {
			"name" = "Miss Sound Volume",
			"type" = "string",
			"callback" = default_string_callback.bind("miss_sound_volume")
		},
	}
}

func _ready() -> void:
	for tab: String in settings_metadata:
		add_tab(tab)
		var tab_data: Dictionary = settings_metadata[tab]
		for setting: String in tab_data:
			var setting_data: Dictionary = tab_data[setting]
			
			add_setting(tab, setting_data.name, setting_data.type, setting_data.callback, SSCS.settings[setting])
