extends Node
class_name HostLobby

var discoverability: Steam.LobbyType

var user_data: Dictionary[int, Dictionary]

var selected_map: MapLoader.Map

var local_note_hit_data: Dictionary
var local_cursor_pos_data: PackedByteArray

var lobby_start: int
var last_replication_flush: int
var last_cursor_update: int

var cursor: Cursor

var spectated_user: int = -1

enum HOST_PACKET {
	CHAT_MESSAGE,
	CHANGE_SELECTED_MAP,
	REPLICATION_DATA_UPDATE,
	PLAYER_READY,
	PLAYER_DIED
}

func send_chat_message(message: String) -> void:
	Terminal.print_console("{0}{1}{2}: {3}\n".format([
		"[color=yellow]",
		NewSteamHandler.get_user_display_name(NewSteamHandler.local_steam_id),
		"[/color]",
		message,
	]))

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.CHAT_MESSAGE, var_to_bytes([NewSteamHandler.local_steam_id, message]))

func change_map(new_map: MapLoader.Map) -> void:
	if selected_map == new_map or !new_map.loaded_successfully: return

	selected_map = new_map

	for user_id: int in user_data:
		user_data[user_id].ready = false

	var url: String = await SSCS.get_temporary_map_download_link(new_map)

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.SELECTED_MAP_CHANGED, var_to_bytes({
		name = new_map.map_name,
		hash = SSCS.get_map_hash(new_map.map_name),
		url = url,
		url_end = SSCS.url_cache[new_map.map_name].time
	}))

func start_lobby(from: float = 0) -> void:
	var all_ready: bool = true
	for user_id: int in user_data:
		if !user_data[user_id].ready:
			all_ready = false
			break
	while !all_ready:
		await SSCS.wait(0.1)
		all_ready = true
		for user_id: int in user_data:
			if !user_data[user_id].ready:
				all_ready = false
				break

	var start_from_encoded: PackedByteArray
	start_from_encoded.resize(8)
	start_from_encoded.encode_double(0, from)

	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.MAP_START, start_from_encoded)

	var game_handler: GameHandler = GameHandler.new(selected_map)

	game_handler.note_hit.connect(func(note: Note) -> void:
		local_note_hit_data[note.note_id] = true
	)

	game_handler.note_missed.connect(func(note: Note) -> void:
		local_note_hit_data[note.note_id] = false
	)

	lobby_start = Time.get_ticks_msec()
	last_replication_flush = 0
	last_cursor_update = 0

	local_cursor_pos_data.clear()
	local_note_hit_data.clear()

	for user_id_2: int in user_data:
		user_data[user_id_2].alive = true
		user_data[user_id_2].cursor_replication_data.clear()
		user_data[user_id_2].note_hit_data.clear()

	SSCS.game_handler = game_handler

	$"/root/Game".add_child(game_handler)

	cursor = game_handler.cursor

	SSCS.user_interface.visible = false

	game_handler.play(from)

	await game_handler.ended

	var died_packet: PackedByteArray = [0,0,0,0,0,0,0,0,0,0,0,0]
	died_packet.encode_u64(0, NewSteamHandler.local_steam_id)
	died_packet.encode_float(8, (Time.get_ticks_msec() - lobby_start) / 1000.0)
	NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.PLAYER_DIED, died_packet)

	game_handler.queue_free()
	SSCS.user_interface.visible = true

func spectate_user(user_id: int) -> void:
	if !user_data.has(user_id) or spectated_user != -1 or !user_data[user_id].alive: print("bad"); return

	print("start spectate")
	print(user_id)
	print(user_data[user_id])
	spectated_user = user_id

	var game_handler: GameHandler = GameHandler.new(selected_map, true, user_data[user_id].note_hit_data, user_data[user_id].cursor_replication_data, false)

	SSCS.game_handler = game_handler

	$"/root/Game".add_child(game_handler)

	cursor = game_handler.cursor

	game_handler.hud.update_info_top(NewSteamHandler.get_user_display_name(user_id))

	SSCS.user_interface.visible = false

	game_handler.play(((Time.get_ticks_msec() - lobby_start) / 1000.0) - 0.5)

	await game_handler.ended

	print("dieded")

	spectated_user = -1
	game_handler.queue_free()
	SSCS.user_interface.visible = true

func _init(lobby_discoverability: int) -> void:
	lobby_discoverability = discoverability

	if NewSteamHandler.current_lobby_id == 0:
		NewSteamHandler.create_lobby(lobby_discoverability)
	elif lobby_discoverability != -1:
		Steam.setLobbyType(NewSteamHandler.current_lobby_id, lobby_discoverability)
		Steam.setLobbyData(NewSteamHandler.current_lobby_id, "name", Steam.getPersonaName())


	NewSteamHandler.player_joined.connect(func(user_id: int) -> void:
		user_data[user_id] = {
			alive = false,

			cursor_replication_data = PackedVector3Array(),
			note_hit_data = PackedByteArray(),

			ready = false
		}

		while not NewSteamHandler.lobby_users[user_id].has("connection"): await SSCS.wait(0.15)

		if selected_map != null:
			var url: String = await SSCS.get_temporary_map_download_link(selected_map)

			NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.SELECTED_MAP_CHANGED, var_to_bytes({
				name = selected_map.map_name,
				hash = SSCS.get_map_hash(selected_map.map_name),
				url = url,
				url_end = SSCS.url_cache[selected_map.map_name].time
			}))
		NewSteamHandler.send_message(user_id, ClientLobby.CLIENT_PACKET.SELECTED_MODIFIERS_CHANGED, var_to_bytes(SSCS.encode_class(SSCS.modifiers)))
	)

	NewSteamHandler.player_left.connect(func(user_id: int) -> void:
		if user_id == NewSteamHandler.local_steam_id:
			self.queue_free()
			if SSCS.host_lobby:
				SSCS.host_lobby = null
		else:
			user_data.erase(user_id)
	)

	NewSteamHandler.user_data_updated.connect(func(user_id: int) -> void:
		if user_data.has(user_id):
			user_data[user_id].settings = str_to_var(Steam.getLobbyMemberData(NewSteamHandler.current_lobby_id, user_id, "settings"))
	)

	NewSteamHandler.packet_received.connect(func(user_id: int, packet_type: int, packet_data: PackedByteArray, _raw_packet: Dictionary) -> void:
		match packet_type:
			HOST_PACKET.REPLICATION_DATA_UPDATE:
				print("got replication data")
				var data: Array = bytes_to_var(packet_data)

				var cursor_replication_data: PackedByteArray = data[0]
				var note_hit_data: Dictionary = data[1]

				var user_cursor_replication_data: PackedVector3Array = user_data[user_id].cursor_replication_data
				print("data")
				for offset: int in range(0, len(cursor_replication_data) / 8):
					var real_offset: int = offset * 8

					var x: float = remap(cursor_replication_data.decode_u16(real_offset + 0), 0, 0xffff, -Cursor.GRID_MAX, Cursor.GRID_MAX)
					var y: float = remap(cursor_replication_data.decode_u16(real_offset + 2), 0, 0xffff, -Cursor.GRID_MAX, Cursor.GRID_MAX)
					var t: int = cursor_replication_data.decode_s32(real_offset + 4)

					print(x)
					print(y)
					print(t)

					user_cursor_replication_data.append(Vector3(x, y, t / 1000.0))

				var user_note_hit_data: PackedByteArray = user_data[user_id].note_hit_data
				for note_id: int in note_hit_data:
					if note_id >= len(user_note_hit_data):
						user_note_hit_data.resize(note_id + 1)
					user_note_hit_data[note_id] = 1 if note_hit_data[note_id] else 0

				NewSteamHandler.send_message_to_users([user_id], ClientLobby.CLIENT_PACKET.REPLICATION_DATA_UPDATE, var_to_bytes([user_id, cursor_replication_data, note_hit_data]))
			HOST_PACKET.CHAT_MESSAGE:
				Terminal.print_console("{0}: {1}\n".format([
					NewSteamHandler.get_user_display_name(user_id),
					packet_data.get_string_from_utf8()
				]))

				NewSteamHandler.send_message_to_users([user_id], ClientLobby.CLIENT_PACKET.CHAT_MESSAGE, var_to_bytes([user_id, packet_data.get_string_from_utf8()]))
			HOST_PACKET.CHANGE_SELECTED_MAP:
				var data: Array = bytes_to_var(packet_data)

				Terminal.print_console("{0} would like to change the map to {1}. Type \"y\" to accept or type anything else to ignore.".format([NewSteamHandler.get_user_display_name(user_id), data[0]]))

				var answer: String = await Terminal.line_entered

				if answer.to_lower() == "y":
					Terminal.print_console("Downloading map...")

					var temp_selected_map: MapLoader.Map = selected_map
					selected_map = null
					var new_map: MapLoader.Map = await SSCS.get_map_from_url(data[1])
					new_map.map_name = data[0]

					if !new_map.loaded_successfully:
						selected_map = temp_selected_map
						return

					selected_map = new_map
			HOST_PACKET.PLAYER_READY:
				user_data[user_id].ready = true
			HOST_PACKET.PLAYER_DIED:
				var died_at: float = packet_data.decode_float(0)

				packet_data.resize(12)
				packet_data.encode_u64(0, user_id)
				packet_data.encode_float(8, died_at)

				NewSteamHandler.send_message_to_users([user_id], ClientLobby.CLIENT_PACKET.PLAYER_DIED, packet_data)

				await SSCS.wait(died_at - AudioManager.elapsed)

				if !user_data.has(user_id):
					print("man.")
					return

				user_data[user_id].alive = false

				if spectated_user == user_id:
					SSCS.game_handler.stop()
			_:
				print("unknown packet type ", packet_type)
	)

	NewSteamHandler.host_changed.connect(func(user_id: int) -> void:
		if user_id != NewSteamHandler.local_steam_id:
			print("turning into client")
			var new_lobby: ClientLobby = ClientLobby.new(NewSteamHandler.current_lobby_id)

			if selected_map != null:
				new_lobby.selected_map = selected_map

			for user_id_2: int in user_data:
				NewSteamHandler.player_joined.emit(user_id_2)

			$"/root/Game".add_child(new_lobby)

			SSCS.host_lobby = null
			SSCS.client_lobby = new_lobby
			self.queue_free()
	)

	SSCS.modifier_updated.connect(func() -> void:
		NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.SELECTED_MODIFIERS_CHANGED, var_to_bytes(SSCS.encode_class(SSCS.modifiers)))
	)

func _physics_process(_delta: float) -> void:
	if SSCS.game_handler != null and cursor != null:
		var current_tick: int = floori(AudioManager.elapsed * 1000)

		var cursor_data: PackedByteArray
		cursor_data.resize(2 + 2 + 4)

		cursor_data.encode_u16(0, roundi(remap(cursor.pos.x, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 0xffff)))
		cursor_data.encode_u16(2, roundi(remap(cursor.pos.y, -Cursor.GRID_MAX, Cursor.GRID_MAX, 0, 0xffff)))
		cursor_data.encode_s32(4, current_tick)

		last_cursor_update = current_tick

		local_cursor_pos_data.append_array(cursor_data)

		if current_tick - last_replication_flush > 500:
			print("flush data")
			last_replication_flush = current_tick

			NewSteamHandler.send_message_to_users([], ClientLobby.CLIENT_PACKET.REPLICATION_DATA_UPDATE, var_to_bytes([NewSteamHandler.local_steam_id, local_cursor_pos_data, local_note_hit_data]))

			local_cursor_pos_data.clear()
			local_note_hit_data.clear()
