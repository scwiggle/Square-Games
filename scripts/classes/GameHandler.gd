extends MultiMeshInstance3D
class_name GameHandler

const cursor_base: PackedScene = preload("res://scenes/prefabs/cursor.tscn")
const note_mesh: ArrayMesh = preload("res://assets/meshes/Rounded.obj")
const note_material: ShaderMaterial = preload("res://assets/materials/note_shader_material.tres")
const hud_base: PackedScene = preload("res://scenes/prefabs/hud.tscn")
const default_hit_sound: AudioStreamWAV = preload("res://assets/audio/hitsound.wav")
const default_miss_sound: AudioStreamMP3 = preload("res://assets/audio/misssound.mp3")

const nan_transform: Transform3D = Transform3D(Basis(),Vector3(-2^52,-2^52,-2^52))

@onready var camera: Camera3D = $"/root/Game/Camera"

var map: MapLoader.Map

var map_data: Array[Array]

var notes: Array[Note] = []
var note_scores: Array[int] = []
var allocated_notes: PackedByteArray = []
var cursor: Cursor
var hud: Hud

var note_stockpile: Array[Note] = []

var max_loaded_notes: int = 0

var last_top_note_id: int = 0

var note_added: int = -1
var note_removed: int = -1

var misses: int = 0
var hits: int = 0
var score: int = 0

var last_loaded_note_id: int=0

var ran: bool = false
var stopped: bool = false

var playing: bool = false

var speed_multiplier: float = SSCS.modifiers.speed

var hit_time: float = (SSCS.modifiers.hit_time/1000) * speed_multiplier
var hitbox_size: float = SSCS.modifiers.hitbox_size

var approach_time: float = (SSCS.settings.spawn_distance/SSCS.settings.approach_rate) * speed_multiplier

var no_fail: bool = SSCS.modifiers.no_fail or SSCS.modifiers.autoplay

var autoplay:bool = SSCS.modifiers.autoplay

var health: float = 5
var reset_timer: int = -1

var autoplay_handler: AutoplayHandler

var is_replay: bool = false
var replay_note_hit_data: PackedByteArray
var replay_cursor_pos_data: PackedVector3Array

var use_hit_sound: bool = SSCS.settings.hit_sound_volume > 0
var use_miss_sound: bool = SSCS.settings.miss_sound_volume > 0

var record_replays: bool = SSCS.settings.record_replays
var smooth_replays: bool = SSCS.settings.smooth_replays

var recorded_replay_note_hit_data: PackedByteArray
var recorded_replay_cursor_pos_data: PackedVector3Array

var last_replay_cursor_pos_index: int = 0

var hit_sound_player: AudioStreamPlayer
var miss_sound_player: AudioStreamPlayer

var horizontal_flip: bool = SSCS.modifiers.horizontal_flip
var vertical_flip: bool = SSCS.modifiers.vertical_flip

var end_replay_on_end_of_data: bool = false

signal ended
signal note_hit(note_id: int)
signal note_missed(note_id: int)

@warning_ignore("shadowed_variable")
func _init(map_arg: MapLoader.Map, is_replay: bool = false, replay_note_hit_data: PackedByteArray = [], replay_cursor_pos_data: PackedVector3Array = [], end_replay_on_end_of_data: bool = false) -> void:
	map = map_arg
	map_data = map.data
	
	var benchmark_start_1: int = Time.get_ticks_usec()

	var max_t: int = ceil(((SSCS.settings.spawn_distance+0.1)/SSCS.settings.approach_rate)*1000) + SSCS.modifiers.hit_time
	var note_counter: int = 0
	var current_note: int = 0

	for note: Array in map.data:
		var ct: float = note[2] / speed_multiplier

		while true:
			var closest_note: Array = map.data[note_counter]

			if ct - (closest_note[2] / speed_multiplier) > max_t:
				note_counter += 1
			else:
				break

		current_note += 1

		if current_note - note_counter > max_loaded_notes:
			max_loaded_notes = current_note - note_counter

	max_loaded_notes += 1
	if max_loaded_notes > 10000: #holy shit visual map
		max_loaded_notes *= 2

	var benchmark_end_1: int = Time.get_ticks_usec()
	print((benchmark_end_1 - benchmark_start_1)/1000.0)

	if horizontal_flip or vertical_flip:
		for note_data: Array in map.data:
			note_data[0] = (-1 if horizontal_flip else 1) * note_data[0]
			note_data[1] = (-1 if vertical_flip else 1) * note_data[1]

	print(max_loaded_notes)

	allocated_notes.resize(max_loaded_notes)
	allocated_notes.fill(0)

	note_scores.resize(len(map.data))
	for i: int in range(len(map.data)):
		note_scores[i] = 50

	if is_replay:
		print("we are replay")
		self.is_replay = true
		self.replay_cursor_pos_data = replay_cursor_pos_data
		self.replay_note_hit_data = replay_note_hit_data
		self.end_replay_on_end_of_data = end_replay_on_end_of_data

func _notification(what: int) -> void: #have to have this since horizontal/vertical flip mutates map data and we have to undo it
	if what == NOTIFICATION_PREDELETE:
		if horizontal_flip or vertical_flip:
			for note_data: Array in map.data:
				note_data[0] = (-1 if horizontal_flip else 1) * note_data[0]
				note_data[1] = (-1 if vertical_flip else 1) * note_data[1]

func _ready() -> void:
	RenderingServer.global_shader_parameter_set("approach_time",approach_time)
	RenderingServer.global_shader_parameter_set("spawn_distance",SSCS.settings.spawn_distance)
	RenderingServer.global_shader_parameter_set("vanish_distance",-SSCS.settings.vanish_distance)

	RenderingServer.global_shader_parameter_set("note_begin_transparency",SSCS.settings.note_begin_transparency)
	RenderingServer.global_shader_parameter_set("note_transparency",SSCS.settings.note_transparency)
	RenderingServer.global_shader_parameter_set("note_end_transparency",SSCS.settings.note_end_transparency)

	RenderingServer.global_shader_parameter_set("note_fade_in_begin",SSCS.settings.note_fade_in_begin)
	RenderingServer.global_shader_parameter_set("note_fade_in_end",SSCS.settings.note_fade_in_end)

	RenderingServer.global_shader_parameter_set("note_fade_out_begin",SSCS.settings.note_fade_out_begin)
	RenderingServer.global_shader_parameter_set("note_fade_out_end",SSCS.settings.note_fade_out_end)

	camera.environment.glow_enabled = SSCS.settings.glow_enabled
	camera.environment.glow_strength = SSCS.settings.glow_strength
	camera.environment.glow_bloom = SSCS.settings.glow_bloom

	cursor = cursor_base.instantiate()
	if is_replay or autoplay:
		cursor.accepts_input = false
	self.add_child(cursor)

	hud = hud_base.instantiate()
	self.add_child(hud)

	if autoplay:
		autoplay_handler = AutoplayHandler.new(map,cursor)

	self.multimesh = MultiMesh.new()

	update_note_mesh(note_mesh)
	self.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	self.multimesh.use_custom_data=true

	self.multimesh.instance_count = max_loaded_notes
	self.multimesh.visible_instance_count = 1

	note_stockpile.resize(max_loaded_notes)
	var i: int = 0
	while i < max_loaded_notes:
		note_stockpile[i] = Note.new(0, Vector2(), 0.0, multimesh, 1)
		i += 1
	
	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.max_polyphony = 50
	hit_sound_player.volume_linear = SSCS.settings.hit_sound_volume * 0.15
	hit_sound_player.bus = &"Sounds"

	var custom_hit_sound_resource: String = SSCS.get_arbitrary_exension("user://hitsound", ["mp3","wav"])
	if !custom_hit_sound_resource.is_empty():
		hit_sound_player.stream = SSCS.load_audio(custom_hit_sound_resource)
	else:
		hit_sound_player.stream = default_hit_sound

	self.add_child(hit_sound_player)


	miss_sound_player = AudioStreamPlayer.new()
	miss_sound_player.max_polyphony = 50
	miss_sound_player.volume_linear = SSCS.settings.miss_sound_volume * 0.15
	miss_sound_player.bus = &"Sounds"

	var custom_miss_sound_resource: String = SSCS.get_arbitrary_exension("user://misssound", ["mp3","wav"])
	if !custom_miss_sound_resource.is_empty():
		miss_sound_player.stream = SSCS.load_audio(custom_miss_sound_resource)
	else:
		miss_sound_player.stream = default_miss_sound

	self.add_child(miss_sound_player)




#region note creation and deletion

var lowest_hole: int = 0 #not actually guarunteed to be lowest hole, instead guarunteed to be lower than lowest hole

func spawn_note(note_id: int, pos: Vector2, t: float) -> Note:

	var new_index: int = allocated_notes.find(0, lowest_hole)

	lowest_hole = new_index
	
	note_added = maxi(note_added, new_index)
	#if new_index > note_added:
		#note_added = new_index

	#if new_index<0 or new_index>=multimesh.instance_count:
		#print("WOOAAHHH")
		#print(new_index)

	allocated_notes[new_index] = 1
	var new_note: Note = note_stockpile.pop_back() #Note.new(note_id, pos, t, multimesh, new_index)

	#if new_note == null:
		#new_note = Note.new(note_id, pos, t, multimesh, new_index)
		#note_stockpile.append(new_note)
		#print("new one")
	#else:
	new_note.reinitialize(note_id, pos, t, new_index)
 
	return new_note

func remove_note(note: Note) -> void:
	var index:int = note.multimesh_index
	
	note_removed = maxi(note_removed, index)
	#if index > note_removed:
		#note_removed = index
	
	lowest_hole = mini(lowest_hole, index)
	#if index < lowest_hole:
		#lowest_hole = index

	allocated_notes[index]=0

	multimesh.set_instance_transform(index,nan_transform)

	note_stockpile.append(note)


func update_note_mesh(mesh: Mesh) -> void:
	var new_note_mesh: Mesh = mesh.duplicate()

	new_note_mesh.surface_set_material(0, note_material)
	self.multimesh.mesh=new_note_mesh

#endregion
#region time control

func play(from: float) -> void:
	assert(not ran, "Tried to run game manager more than once")
	ran = true

	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if SSCS.settings.absolute_input else Input.MOUSE_MODE_CAPTURED
	cursor.pos = Vector2()
	cursor.update_position()
	playing = true
	AudioManager.set_stream(map.audio)
	AudioManager.set_playback_speed(speed_multiplier)
	AudioManager.play(from - 1 * speed_multiplier)

	if record_replays and !is_replay and !autoplay:
		note_hit.connect(func(note_id: int) -> void:
			recorded_replay_note_hit_data.resize(max(len(recorded_replay_note_hit_data), note_id + 1))
			recorded_replay_note_hit_data[note_id] = 1
		)

		note_missed.connect(func(note_id: int) -> void:
			recorded_replay_note_hit_data.resize(max(len(recorded_replay_note_hit_data), note_id + 1))
			recorded_replay_note_hit_data[note_id] = 0
		)

		ended.connect(func() -> void:
			var new_replay: FileAccess = FileAccess.open("user://replays/" + "{0} {1} {2}.sscr".format([len(DirAccess.get_files_at("user://replays")), map.map_name, Time.get_datetime_string_from_system(false, true)]).replace(" ","_").replace(":","_"), FileAccess.WRITE)
			print(new_replay)
			new_replay.store_buffer(ReplayParser.create_replay_without_map(map, recorded_replay_note_hit_data, recorded_replay_cursor_pos_data, SSCS.settings, SSCS.modifiers, from))
		)

	var threshold: int = ceil( (AudioManager.elapsed + approach_time) * 1000)
	var map_data_len: int = len(map.data)
	while last_loaded_note_id < map_data_len:
		var note_data: Array = map.data[last_loaded_note_id]
		if note_data[2] <= threshold:
			if is_replay:
				if replay_note_hit_data[last_loaded_note_id] == 1:
					hits += 1
				else:
					misses += 1
			last_loaded_note_id += 1
		else:
			break

func stop() -> void:
	assert(not stopped, "Tried to stop game manager more than once")
	stopped = true

	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	ended.emit()
	playing = false
	AudioManager.full_stop()

func pause() -> void:
	playing = false
	AudioManager.stop()
	#Input.warp_mouse(get_viewport().get_camera_3d().unproject_position(cursor.position))

func unpause() -> void:
	playing = true
	AudioManager.resume()

#endregion
#region note functionality

func _check_death() -> void:
	if (health == 0 and !no_fail and !is_replay) or (AudioManager.elapsed > (map.data[-1][2] / 1000.0) + 1.0):
		stop()

func _load_notes() -> void:
	var threshold: int = ceil( (AudioManager.elapsed + approach_time) * 1000)
	var map_data_len: int = len(map_data)
	
	while last_loaded_note_id < map_data_len:
		var note_data: Array = map_data[last_loaded_note_id]
		var note_t: int = note_data[2]
		#if note_t > threshold: break
		if note_t <= threshold:
		
			#var new_note: Note = spawn_note(last_loaded_note_id, Vector2(note_data[0], note_data[1]), note_t / 1000.0)
			var new_index: int = allocated_notes.find(0, lowest_hole)

			lowest_hole = new_index
			
			note_added = maxi(note_added, new_index)

			allocated_notes[new_index] = 1
			
			var new_note: Note = note_stockpile.pop_back()

			new_note.reinitialize(last_loaded_note_id, Vector2(note_data[0], note_data[1]), note_t / 1000.0, new_index)

			notes.append(new_note)

			last_loaded_note_id += 1
		else:
			break

var new_notes: Array[Note] #held externally for the sake of memory allocation efficiency(?) no clue if it works
	
func remove_notes(to_remove: PackedInt32Array) -> void:
	var to_remove_len: int = len(to_remove)
	if to_remove[-1] == to_remove_len - 1:
		for i: int in range(0, to_remove_len):
			#remove_note(notes[i])
			var note: Note = notes[i]
			var index: int = note.multimesh_index

			note_removed = maxi(note_removed, index)
			lowest_hole = mini(lowest_hole, index)

			allocated_notes[index]=0

			multimesh.set_instance_transform(index,nan_transform)
		note_stockpile.append_array(notes.slice(0, to_remove[-1] + 1))
		notes = notes.slice(to_remove[-1] + 1)
		return
	#var notes_len: int = len(notes)
	#print("slow one")

	new_notes.resize(to_remove[-1] - to_remove_len + 1)

	var shift: int = 0
	var i: int = 0
	var next_check: int = to_remove[0]
	
	var note_stockpile_len: int = len(note_stockpile)
	note_stockpile.resize(note_stockpile_len + to_remove_len)

	for note: Note in notes:
		if i == next_check:
			
			var index: int = note.multimesh_index

			note_removed = maxi(note_removed, index)
			lowest_hole = mini(lowest_hole, index)

			allocated_notes[index]=0

			multimesh.set_instance_transform(index,nan_transform)
			
			note_stockpile[note_stockpile_len + shift] = note
			shift += 1
			if shift < to_remove_len:
				next_check = to_remove[shift]
			else:
				break
		else:
			new_notes[i - shift] = note
		i += 1
	
	
	new_notes.append_array(notes.slice(to_remove[-1] + 1))

	#while i < notes_len:
		#new_notes[i - shift] = notes[i]
		#i += 1

	var notes_temp: Array[Note] = notes
	
	notes = new_notes
	new_notes = notes_temp

func _check_hitreg() -> void:
	var elapsed: float = AudioManager.elapsed

	var boundary: float = elapsed - hit_time

	var to_remove: PackedInt32Array = []
	var i: int = -1
	
	var cursor_pos: Vector2 = cursor.pos

	if is_replay:
		for note: Note in notes:
			i+=1
			var note_t: float = note.t
			if note_t < elapsed:
				if note_t < boundary:
					if note.note_id >= len(replay_note_hit_data): break

					if replay_note_hit_data[note.note_id] == 0:
						misses += 1
						health = health - 1
						if use_miss_sound: miss_sound_player.play(0)
						note_missed.emit(note.note_id)

						to_remove.append(i)
					else:
						hits += 1
						health = health + 0.5
						if use_hit_sound: hit_sound_player.play(0)
						note_hit.emit(note.note_id)

						to_remove.append(i)
			else:
				break
	else:
		for note: Note in notes:
			i += 1
			var note_t: float = note.t
			if note_t < elapsed:
				if note_t < boundary:
					misses += 1
					health -= 1.0
					if use_miss_sound: miss_sound_player.play(0)
					note_missed.emit(note.note_id)

					to_remove.append(i)
				else:
					var diff: Vector2 = (note.pos - cursor_pos).abs()
					
					if maxf(diff.x, diff.y) < hitbox_size:
						hits += 1
						health += 0.5
						if use_hit_sound: hit_sound_player.play(0)
						note_hit.emit(note.note_id)

						to_remove.append(i)
			else:
				break
	
	health = clampf(health, 0.0, 5.0)

	if len(to_remove) > 0:
		remove_notes(to_remove)
	#var shift: int = 0
	#for v: int in to_remove:
		#var note: Note = notes.pop_at(v-shift)
		#remove_note(note)
#
		#shift+=1

func _process(_dt: float) -> void:
	if Input.is_action_pressed(&"reset"):
		if reset_timer == -1:
			reset_timer=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-reset_timer > 500:
			stop()
	elif reset_timer != -1:
		reset_timer = -1

	if not playing or stopped: return
	if autoplay:
		cursor.pos = autoplay_handler.get_cursor_position()
		cursor.update_position()

	if is_replay:
		var cursor_pos_data: Vector3 = replay_cursor_pos_data[last_replay_cursor_pos_index]
		while cursor_pos_data.z < AudioManager.elapsed and last_replay_cursor_pos_index + 1 < len(replay_cursor_pos_data):
			last_replay_cursor_pos_index += 1
			cursor_pos_data = replay_cursor_pos_data[last_replay_cursor_pos_index]

		if last_replay_cursor_pos_index + 1 >= len(replay_cursor_pos_data):
			if end_replay_on_end_of_data:
				print("we done")
				stop()
			else:
				print("you a foreteller bro")
				pause()
				await get_tree().create_timer(0.75).timeout
				unpause()

		if smooth_replays:
			var previous_cursor_pos_data: Vector3 = replay_cursor_pos_data[max(last_replay_cursor_pos_index - 1, 0)]

			var progress: float = AudioManager.elapsed - previous_cursor_pos_data.z
			var time_distance: float = cursor_pos_data.z - previous_cursor_pos_data.z

			cursor.pos = Vector2(previous_cursor_pos_data.x, previous_cursor_pos_data.y).lerp(Vector2(cursor_pos_data.x, cursor_pos_data.y), progress/time_distance)
		else:
			cursor.pos = Vector2(cursor_pos_data.x, cursor_pos_data.y)
		cursor.update_position()

	_check_hitreg()
	_load_notes()
	_check_death()

	if note_removed == last_top_note_id:
		var top_note_id: int = allocated_notes.rfind(1)
		last_top_note_id = top_note_id
		self.multimesh.visible_instance_count=top_note_id+1
		hud.update_info_right(hits,misses)
		hud.update_info_bottom(health)
	elif note_added>last_top_note_id:
		last_top_note_id = note_added
		self.multimesh.visible_instance_count=note_added+1

#endregion

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and !SSCS.settings.disable_pausing:
		if playing:
			pause()
		else:
			unpause()

func _physics_process(_delta: float) -> void:
	if record_replays and playing and !is_replay and !autoplay:
		var cursor_pos: Vector2 = cursor.pos
		var cursor_pos_time: Vector3 = Vector3(cursor_pos.x,cursor_pos.y,AudioManager.elapsed)

		recorded_replay_cursor_pos_data.append(cursor_pos_time)
