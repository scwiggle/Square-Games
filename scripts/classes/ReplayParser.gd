extends Node
class_name ReplayParser

static func create_replay_without_map(map: MapLoader.Map, replay_note_hit_data: PackedByteArray, replay_cursor_pos_data: PackedVector3Array, settings: SSCS.Settings, modifiers:SSCS.Modifiers, start_from: float) -> PackedByteArray:
	return var_to_bytes_with_objects({
		has_attached_map = false,

		map_name = map.raw_map_name,
		map_hash = SSCS.get_map_hash(map.raw_map_name),

		replay_note_hit_data = replay_note_hit_data,
		replay_cursor_pos_data = replay_cursor_pos_data,

		settings = SSCS.encode_class(settings),
		modifiers = SSCS.encode_class(modifiers),
		start_from = start_from
	})

static func get_data_from_replay(raw_data: PackedByteArray) -> Dictionary:
	var data: Dictionary = bytes_to_var_with_objects(raw_data)

	var map: MapLoader.Map

	if !data.has_attached_map:
		print("get map shit")
		if data.map_hash != SSCS.get_map_hash(data.map_name):
			return {}
		map = SSCS.load_map_from_name(data.map_name) 
		print(map.loaded_successfully)
		print(data.map_name)

	var replay_settings: SSCS.Settings = SSCS.Settings.new()
	for i: String in data.settings:
		if replay_settings.get(i) != null:
			replay_settings[i] = data.settings[i]

	var replay_modifiers: SSCS.Modifiers = SSCS.Modifiers.new()
	for i: String in data.modifiers:
		if replay_modifiers.get(i) != null:
			replay_modifiers[i] = data.modifiers[i]

	SSCS.settings = replay_settings
	SSCS.modifiers = replay_modifiers

	return {
		map = map,
		settings = replay_settings,
		modifiers = replay_modifiers,
		replay_cursor_pos_data = data.replay_cursor_pos_data,
		replay_note_hit_data = data.replay_note_hit_data,
		start_from = data.start_from
	}
