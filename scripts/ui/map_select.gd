extends Control

const map_scene: PackedScene = preload("res://scenes/ui/map select/map.tscn")

var last_selected: Button

var maps: Array[Array]

func create_map(map: MapLoader.Map) -> void:
	var new_map: Button = map_scene.instantiate()

	if map.cover and !map.cover.is_empty():
		new_map.get_node("Map/Cover").texture = ImageTexture.create_from_image(map.cover)

	if map.author_name != "":
		new_map.get_node("Map/Control/Map Name").text = "{0} - {1}".format([map.author_name, map.map_name])
	else:
		new_map.get_node("Map/Control/Map Name").text = map.map_name
	new_map.get_node("Map/Control/Charter Name").text = map.charter_name

	if map == SSCS.selected_map:
		new_map.button_pressed = true
		last_selected = new_map

	new_map.pressed.connect(func() -> void:
		if last_selected == new_map:
			new_map.button_pressed = true
			return

		last_selected.button_pressed = false
		last_selected = new_map

		SSCS.selected_map = map
	)

	maps.append([
		new_map,
		map.map_name
	])

	$"MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer".add_child(new_map)

func _ready() -> void:

	for map_id: String in SSCS.map_cache:
		var map: MapLoader.Map = SSCS.map_cache[map_id]

		if !map.loaded_successfully: continue

		create_map(map)

	SSCS.map_loaded.connect(func(map: MapLoader.Map) -> void:
		if !map.loaded_successfully: return

		create_map(map)
	)

	$"MarginContainer/VBoxContainer/LineEdit".text_changed.connect(func(text: String) -> void:
		if text == "":
			for map: Array in maps:
				map[0].visible = true
		else:
			for map: Array in maps:
				map[0].visible = map[1].to_lower().contains(text.to_lower())
	)
