extends Node
class_name ReplayParser

static func write_bits(buffer: PackedByteArray, position: int, bits: int, value: int) -> void:
	var read_position: int = position / 8
	var bit_offset: int = position % 8

	var mask: int = ((2**bits)-1) << bit_offset
	value <<= bit_offset

	for i in range(ceili((bits + bit_offset) / 8.0)):
		var real_mask: int = (mask >> (8 * i)) & 0xff
		var read_value: int = buffer.decode_u8(read_position+i)

		print((value >> ((8 * i)) & 0xff) & real_mask)
		print((~real_mask & read_value))

		buffer.encode_u8(read_position+i, ((value >> ((8 * i)) & 0xff) & real_mask) | (~real_mask & read_value))

static func read_bits(buffer: PackedByteArray, position: int, bits: int) -> int:
	var read_position: int = position / 8
	var bit_offset: int = position % 8

	var mask: int = ((2**bits)-1) << bit_offset

	var value: int = 0

	for i in range(ceili((bits + bit_offset) / 8.0)):
		var real_mask: int = (mask >> (8 * i)) & 0xff
		var read_value: int = buffer.decode_u8(read_position+i)

		print((value >> ((8 * i)) & 0xff) & real_mask)
		print((~real_mask & read_value))

		value = (value << 8) | (real_mask & read_value)

	return value

static func create_replay(map: MapLoader.Map, replay_note_hit_data: PackedByteArray, replay_cursor_pos_data: PackedVector3Array, settings: SSCS.Settings, modifiers:SSCS.Modifiers, start_from: float) -> PackedByteArray:
	var data: PackedByteArray

	var delta_cursor_pos_data: PackedVector3Array = []
	delta_cursor_pos_data.resize(len(replay_cursor_pos_data))

	for i: int in range(len(replay_cursor_pos_data)):
		var v: Vector3 = replay_cursor_pos_data[i]

		var remapped: Vector3 = Vector3(
			int(round(remap(v.x, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 2 ** 20 - 1))),
			int(round(remap(v.y, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 2 ** 20 - 1))),
			v.z,
		)

		if i == 0:
			delta_cursor_pos_data[i] = remapped
		else:
			var previous: Vector3 = delta_cursor_pos_data[i - 1]

			delta_cursor_pos_data[i] = remapped - previous

	for i: int in range(len(replay_cursor_pos_data)):
		var v: Vector3 = delta_cursor_pos_data[i]

		var remapped: Vector3 = Vector3(
			int(round(remap(v.x, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 2 ** 20 - 1))),
			int(round(remap(v.y, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 2 ** 20 - 1))),
			v.z,
		)

		if i == 0:
			delta_cursor_pos_data[i] = remapped
		else:
			var previous: Vector3 = delta_cursor_pos_data[i - 1]

			delta_cursor_pos_data[i] = remapped - previous



	return data

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
