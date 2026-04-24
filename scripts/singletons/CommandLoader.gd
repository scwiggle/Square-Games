extends Node

class Command:
	var function:Callable
	var names:Array[String]
	var argument_count:int
	var echoes: bool

	func _init(function_arg:Callable,names_arg:Array[String], argument_count_arg: int = -1, _variadic_arg: bool = false, echoes_arg: bool = true) -> void:
		function=function_arg
		names=names_arg
		argument_count = function.get_argument_count() if argument_count_arg == -1 else argument_count_arg
		echoes = echoes_arg

var commands:Array[Command]=[]

const command_help:Dictionary = {
	clear = {
		aliases = ["clr"],
		arguments = [],
		use = "Clears the output terminal."
	},
	listsongs = {
		aliases = ["listmaps", "lsm"],
		arguments = [],
		use = "Lists all maps in your maps folder."
	},
	listsettings = {
		aliases = ["lss"],
		arguments = [],
		use = "Lists all settings alongside their values."
	},
	setsetting = {
		aliases = ["set", "sets"],
		arguments = ["Setting", "Value"],
		use = "Sets the setting Setting to Value."
	},
	setmodifier = {
		aliases = ["setm"],
		arguments = ["Modifier", "Value"],
		use = "Sets the modifier Modifier to Value."
	},
	play = {
		aliases = ["playmap"],
		arguments = ["Map Name", "Start Position"],
		use = "Plays the map with the name Map Name"
	},
	replay = {
		aliases = ["rp"],
		arguments = ["Replay file id"],
		use = "Plays the given replay. Replay file id must be the start of a replay file in your replays folder."
	}
}

func register_command(command:Command) -> void:
	commands.append(command)

func _ready() -> void:
	if not Terminal.is_node_ready():
		await Terminal.ready
	Terminal.line_entered.connect(func(line:String)->void:
		var split:PackedStringArray = line.split(" ")
		var cmd:String = split[0]
		var args:PackedStringArray = split.slice(1)
		var argc:int = len(args)

		var ran:bool = false

		for command:Command in commands:
			if command.names.has(cmd):
				if command.echoes:
					Terminal.print_console("> %s\n" % line)

				if argc>=command.argument_count:
					ran=true
					command.function.callv(args)
				else:
					Terminal.print_console("Too few arguments (Expected at least {0} arguments, got {1}).\n".format([command.function.get_argument_count(),argc]))
				break

		if not ran:
			Terminal.print_console("Could not find command named \"{0}\".\n".format([cmd]))

	)
	#register commands

	register_command(Command.new(func() -> void:
		Terminal.console_text=""
		Terminal.update_console()
	,["clr","clear"]))

	register_command(Command.new(func() -> void:
		for v:String in DirAccess.get_files_at("user://maps"):
			Terminal.print_console(v.get_basename()+"\n")
		for v:String in DirAccess.get_files_at("user://rhythiamaps"):
			Terminal.print_console(v.get_basename()+"\n")
		for v:String in DirAccess.get_files_at("user://phoenyxmaps"):
			Terminal.print_console(v.get_basename()+"\n")
	,["lsc","listsongs","listmaps","listcharts"]))

	register_command(Command.new(func() -> void:
		for i:String in SSCS.encode_class(SSCS.settings):
			var v:Variant = SSCS.settings[i]
			Terminal.print_console("{0}: {1}\n".format([i,var_to_str(v)]))
	,["lss","listsettings"]))

	register_command(Command.new(func(setting_name: String, ...setting_value: Array) -> void:
		if SSCS.set_setting(setting_name, " ".join(setting_value), true):
			Terminal.print_console("Successfully set setting.\n")
		else:
			Terminal.print_console("Failed to set setting.\n")
	,["set","sets","setsetting"]))

	register_command(Command.new(func(modifier_name: String, ...modifier_value: Array) -> void:
		if SSCS.set_modifier(modifier_name, " ".join(modifier_value), true):
			Terminal.print_console("Successfully set modifier.\n")
		else:
			Terminal.print_console("Failed to set modifier.\n")
	,["setm","setmodifier"]))

	register_command(Command.new(func(map_name: String = "", start_from: String = "0") -> void:
		print("play ran")
		print("load map %s" % map_name)
		
		var map:MapLoader.Map
		if map_name == "":
			print("map no name.")
			map = SSCS.selected_map
			print(map)
		else:
			map = SSCS.load_map_from_name(map_name)

			if !map.loaded_successfully:
				map_name = SSCS.get_full_map_name_from_partial_name(map_name)
				map = SSCS.load_map_from_name(map_name)

			if !map.loaded_successfully:
				Terminal.print_console('Map "%s" does not exist.\n' % map_name)
				return

		var start_from_time: float = 0

		if start_from.is_valid_float():
			start_from_time = start_from.to_float()
		elif ["start", "s", "beggining", "b"].has(start_from):
			start_from_time = map.data[0][2]/1000.0

		print("num notes: ", str(len(map.data)))
		
		var game_handler: GameHandler = GameHandler.new(map)
		SSCS.game_handler=game_handler


		var game_scene:Node = $"/root/Game"

		game_scene.add_child(game_handler)

		game_handler.play(start_from_time)

		SSCS.user_interface.visible = false

		await game_handler.ended
		
		SSCS.user_interface.visible = true
		print("map ended")

		game_handler.queue_free()

	,["play","playmap"], 0))

	register_command(Command.new(func(command: String = "") -> void:
		print("we playing")
		if command == "":
			for command_name: String in command_help:
				var command_info: Dictionary = command_help[command_name]
				Terminal.print_console("{0}, {1}\n".format([command_name,", ".join(command_info.aliases)]))
			Terminal.print_console("Type the name of a command after \"help\" to get more info.\n")
			return

		var real_command: String = ""

		if command_help.has(command):
			real_command = command
		else:
			for command_name: String in command_help:
				var command_info: Dictionary = command_help[command_name]
				if command in command_info.aliases:
					real_command=command_name
					break

		if real_command == "":
			Terminal.print_console("No command with name \"%s\" exists." % command)
			return

		var command_info: Dictionary = command_help[real_command]
		Terminal.print_console("Command Name: {0}\nAliases: {1}\nArguments: {2}\n\n{3}\n".format([real_command,", ".join(command_info.aliases),", ".join(command_info.arguments),command_info.use]))
	,["help"],0))

	register_command(Command.new(func() -> void:
		for i:String in SSCS.encode_class(SSCS.modifiers):
			var v:Variant = SSCS.modifiers[i]
			Terminal.print_console("{0}: {1}\n".format([i,var_to_str(v)]))
	,["lsm","listmodifiers"]))

	register_command(Command.new(func(replay_id: String) -> void:
		for replay:String in DirAccess.get_files_at("user://replays"):
			if replay.begins_with(replay_id):
				var replay_data: Dictionary = ReplayParser.get_data_from_replay(FileAccess.get_file_as_bytes("user://replays/%s" % replay))

				if SSCS.settings.use_replay_settings:
					SSCS.settings = replay_data.settings
				SSCS.modifiers = replay_data.modifiers

				var game_handler: GameHandler = GameHandler.new(replay_data.map, true, replay_data.replay_note_hit_data, replay_data.replay_cursor_pos_data, true)

				SSCS.game_handler = game_handler
				$"/root/Game".add_child(game_handler)

				SSCS.user_interface.visible = false
				game_handler.play(replay_data.start_from)

				await game_handler.ended

				print("done")

				SSCS.user_interface.visible = true

				game_handler.queue_free()
				SSCS.settings = SSCS.true_settings
				SSCS.modifiers = SSCS.true_modifiers

				break

	,["rp","replay"]))

	register_command(Command.new(func() -> void:
		var new_lobby: HostLobby = HostLobby.new(Steam.LobbyType.LOBBY_TYPE_PUBLIC)
		$"/root/Game".add_child(new_lobby)
		SSCS.host_lobby = new_lobby
	,["ncl"]))

	register_command(Command.new(func(id: String) -> void:
		var new_lobby: ClientLobby = ClientLobby.new(id.to_int())
		$"/root/Game".add_child(new_lobby)
		SSCS.client_lobby = new_lobby
	,["njl"]))

	register_command(Command.new(func(...msg: Array) -> void:
		if SSCS.host_lobby != null:
			SSCS.host_lobby.send_chat_message(" ".join(msg))
		elif SSCS.client_lobby != null:
			SSCS.client_lobby.send_chat_message(" ".join(msg))
	,["nmsg"], -1, true, false))

	register_command(Command.new(func() -> void:
		NewSteamHandler.leave_lobby()
		await SSCS.wait(1)
		print(SSCS.host_lobby)
	,["nll"]))

	register_command(Command.new(func() -> void:
		SSCS.host_lobby.start_lobby(0)
	,["nsl"]))

	register_command(Command.new(func(...song_name: Array) -> void:
		SSCS.host_lobby.change_map(SSCS.load_map_from_name(" ".join(song_name)))
	,["nsls"]))

	register_command(Command.new(func(...user_name: Array) -> void:
		var user_id: int = NewSteamHandler.get_user_id_from_name(" ".join(user_name))

		print("try spec")
		print(user_id)
		if user_id != -1:
			if SSCS.host_lobby != null:
				SSCS.host_lobby.spectate_user(user_id)
	,["nsp"]))

	register_command(Command.new(func() -> void:
		print(ProjectSettings.globalize_path("%appdata%/SoundSpacePlus/settings.json"))

		var settings_path: String
		match OS.get_name().to_lower():
			"linux": settings_path = "/home/%s/.local/share/SoundSpacePlus/settings.json" % OS.get_environment("USER")
			"windows": settings_path = "%s/SoundSpacePlus/settings.json" % OS.get_environment("appdata").replace("\\","/")

		var settings_file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)

		var settings_data: Dictionary = JSON.parse_string(settings_file.get_as_text())

		SSCS.set_setting("fov", settings_data.fov)
		SSCS.set_setting("grid_distance", 3.5)
		SSCS.set_setting("vanish_distance", 0.1 if settings_data.do_note_pushback else INF)
		SSCS.set_setting("parallax", settings_data.parallax / 40.0)
		SSCS.set_setting("pixels_per_grid_unit", (1 / ((settings_data.sensitivity / settings_data.render_scale) * 0.018)) * (settings_data.absolute_scale if settings_data.absolute_mode else 1))
		SSCS.set_setting("approach_rate", settings_data.approach_rate)
		SSCS.set_setting("spawn_distance", settings_data.spawn_distance)
		if settings_data.half_ghost:
			SSCS.set_setting("note_fade_out_begin", ((12.0 / 50.0) * settings_data.approach_rate) / settings_data.spawn_distance)
			SSCS.set_setting("note_fade_out_end", ((3.0 / 50.0) * settings_data.approach_rate) / settings_data.spawn_distance)
			SSCS.set_setting("note_end_transparency", (1 - settings_data.note_opacity * 0.8))
		else:
			SSCS.set_setting("note_fade_out_begin", 0)
			SSCS.set_setting("note_fade_out_end", 0)
			SSCS.set_setting("note_end_transparency", (1 - settings_data.note_opacity))
		SSCS.set_setting("map_volume", (db_to_linear(settings_data.music_volume) * db_to_linear(settings_data.master_volume)) / 0.15)
		SSCS.set_setting("hit_sound_volume", (db_to_linear(settings_data.hit_volume) * db_to_linear(settings_data.master_volume)) / 0.15)
		SSCS.set_setting("miss_sound_volume", (db_to_linear(settings_data.miss_volume) * db_to_linear(settings_data.master_volume)) / 0.15)
		if settings_data.glow > 0 or settings_data.bloom > 0:
			SSCS.set_setting("glow_enabled", true)
			SSCS.set_setting("glow_bloom", settings_data.bloom)
			SSCS.set_setting("glow_strength", settings_data.glow)
		else:
			SSCS.set_setting("glow_enabled", false)
		SSCS.set_setting("cursor_scale", settings_data.cursor_scale)
		SSCS.set_setting("note_scale", settings_data.note_size)
		SSCS.set_setting("absolute_input", settings_data.absolute_mode)
		SSCS.set_setting("note_transparency", 1 - settings_data.note_opacity)
		SSCS.set_setting("note_fade_in_begin", 1)
		SSCS.set_setting("note_fade_in_end", 1 - settings_data.fade_length)
		SSCS.set_setting("semi_spin", false)
		SSCS.set_setting("cam_unlock", settings_data.cam_unlock)

	,["importsettings"]))

	register_command(Command.new(func() -> void:
		Steam.addRequestLobbyListDistanceFilter(Steam.LobbyDistanceFilter.LOBBY_DISTANCE_FILTER_WORLDWIDE)
		Steam.addRequestLobbyListStringFilter("identifier", "SSCS", Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
		Steam.requestLobbyList()

		var data: Array = await Steam.lobby_match_list

		for lobby_id: int in data:
			var lobby_name: String = Steam.getLobbyData(lobby_id, "name")
			Terminal.print_console("{0} ({1})\n".format([lobby_name, lobby_id]))
	,["ngl"]))

	register_command(Command.new(func(...user_name: Array) -> void:
		var user_id: int = NewSteamHandler.get_user_id_from_name(" ".join(user_name))
		if user_id != -1 and user_id != NewSteamHandler.local_steam_id:
			Steam.setLobbyOwner(NewSteamHandler.current_lobby_id, user_id)
	,["nso"]))
