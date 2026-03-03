extends Node
class_name AutoplayHandler

var map: MapLoader.Map

var processed_data: Array[Array] = []

const max_shift_multi: float = 0.25

var cursor: Cursor

var max_range: float = SSCS.modifiers.hitbox_size*max_shift_multi

var last_loaded_note: int = 0

static func _check_hit(note_pos: Variant, cursor_pos: Variant, size: float) -> bool:
	if typeof(note_pos) != TYPE_VECTOR2:
		note_pos = Vector2(note_pos[0], note_pos[1])
	if typeof(cursor_pos) != TYPE_VECTOR2:
		cursor_pos = Vector2(cursor_pos[0], cursor_pos[1])

	var diff: Vector2 = (note_pos - cursor_pos).abs()

	return max(diff.x, diff.y) < size

func _init(map_arg: MapLoader.Map, cursor_arg: Cursor) -> void:
	self.map = map_arg
	self.cursor = cursor_arg

	var i: int = 0

	var notes: Array[Array] = map.data.duplicate(true)
	var notes_len: int = len(notes)

	for note: Array in notes:
		note[2] /= SSCS.modifiers.speed

	var preprocessed_data: Array[Array] = []

	print("begin initial preprocessing")
	#initial preprocessing
	while i < notes_len:
		var v: Array = notes[i]
		i += 1

		var collected: Array[Array] = [v]

		while i < notes_len:
			var v2: Array = notes[i]
			if v2 and abs(v2[2] - v[2]) <= 5 and _check_hit(v, v2, SSCS.modifiers.hitbox_size * 0.9):
				collected.append(v2)
				i += 1
			else:
				break

		var avg_pos: Vector2 = Vector2()

		for note: Array in collected:
			avg_pos += Vector2(note[0], note[1])
		avg_pos /= len(collected)

		if i > 1:
			var prev_data: Array = preprocessed_data[-1]
			var prev_data_pos: Vector2 = Vector2(prev_data[0], prev_data[1])

			var time_elapsed: float = abs(prev_data[2] - v[2]) / 1000.0

			var speed: float = (prev_data_pos - avg_pos).length() / (time_elapsed * 100)
			avg_pos *= 0.8 + (sigmoid(speed * 5) - 0.5) * 2 * 0.2

			if i > 2 and len(preprocessed_data) >= 2:
				var prev_prev_data: Array = preprocessed_data[-2]
				var prev_prev_data_pos: Vector2 = Vector2(prev_prev_data[0], prev_prev_data[1])

				var dir_1: Vector2 = (prev_data_pos - prev_prev_data_pos).normalized()
				var dir_2: Vector2 = (avg_pos - prev_data_pos).normalized()

				avg_pos *= 1 + (max(-dir_1.dot(dir_2) - 0.5, 0) * (1 / (time_elapsed * 20 + 1)))

		var new_note_data: Array = [
			avg_pos.x,
			avg_pos.y,
			v[2]
		]

		var v_prev: Array = notes[i - 2]
		if v_prev != null and len(collected) == 1 and v[0] == v_prev[0] and v[1] == v_prev[1] and len(preprocessed_data) > 0:
			print("stack old avg")
			new_note_data[0] = preprocessed_data[-1][0]
			new_note_data[1] = preprocessed_data[-1][1]

		preprocessed_data.append(new_note_data)

	print("begin aggressive stack compressing")
	i = 2

	var preprocessed_data_len: int = len(preprocessed_data)

	var secondary_preprocessed_data: Array[Array] = []

	if preprocessed_data_len > 5 and true:

		secondary_preprocessed_data.append(preprocessed_data[0])
		secondary_preprocessed_data.append(preprocessed_data[1])

		var merged: bool = false
		while i + 3 < preprocessed_data_len:

			var stack_length: int = 1

			var top_note: Array = preprocessed_data[i]
			var top_note_i: int = i
			i += 1
			#secondary_preprocessed_data.append(top_note)

			while i + 2 < preprocessed_data_len:
				var next_note: Array = preprocessed_data[i]
				i += 1
				if _check_hit(next_note, top_note, 0.1):
					stack_length += 1
				else:
					break
			i -= 1

			if stack_length > 1:
				print("stack found ", top_note[2])
				print(stack_length)

				var end_note: Array = preprocessed_data[i-1]

				var valid: bool = false
				var valid_test: Array

				var tests: Array[Array] = []

				var test_width: float = SSCS.modifiers.hitbox_size * 0.5
				const test_width_fidelity: int = 3
				const test_count: int = 11
				for i2: int in range(0, test_count):
					tests.append([
						top_note[0],
						top_note[1],
						lerp(top_note[2], end_note[2], i2 / (test_count - 1.0)),
					])
					for x: int in range(-test_width_fidelity, test_width_fidelity+1):
						for y: int in range(-test_width_fidelity, test_width_fidelity+1):
							if y == 0 and x == 0: continue
							var offset: Vector2 = (Vector2(x,y) / float(test_width_fidelity)) * test_width
							tests.append([
								top_note[0] + offset.x,
								top_note[1] + offset.y,
								lerp(top_note[2], end_note[2], i2 / (test_count - 1.0)),
							])

				var notes_to_check: Array[Array] = preprocessed_data.slice(i - stack_length - 2, i + 2)

				var cursor_position_notes: Array[Array] = secondary_preprocessed_data.slice(-stack_length - 4)
				var cursor_position_notes_end: Array[Array] = preprocessed_data.slice(i, i + 5)


				for test: Array in tests:
					var current_valid: bool = true
					var test_validation_array: Array = cursor_position_notes + [test] + cursor_position_notes_end

					for note: Array in notes_to_check:
						if !_check_hit(note, _get_cursor_position_from_notes_and_elapsed(test_validation_array, note[2] + 5), SSCS.modifiers.hitbox_size * 0.8):
							current_valid = false
							break
					if current_valid:
						valid = true
						valid_test = test
						print("VALID STACK ATTEMPT WTF!?!?!")
						break

				if valid:
					secondary_preprocessed_data.append(valid_test)
				else:
					print("invalid stack attempt")
					secondary_preprocessed_data.append(top_note)
					var top_note_shifted: Array = top_note.duplicate()
					top_note_shifted[2] += 10
					secondary_preprocessed_data.append(top_note_shifted)

					var end_note_shifted: Array = end_note.duplicate()
					end_note_shifted[2] -= 10
					secondary_preprocessed_data.append(end_note_shifted)
					secondary_preprocessed_data.append(end_note)

			else:
				secondary_preprocessed_data.append(top_note)

		secondary_preprocessed_data.append(preprocessed_data[-3])
		secondary_preprocessed_data.append(preprocessed_data[-2])
		secondary_preprocessed_data.append(preprocessed_data[-1])
	else:
		secondary_preprocessed_data = preprocessed_data

	#shift preprocessing
	i = 0
	var secondary_preprocessed_data_len: int = len(secondary_preprocessed_data)
	print(secondary_preprocessed_data_len)

	print("begin shift preprocessing")

	while i+1<secondary_preprocessed_data_len:

		var note_0: Array = secondary_preprocessed_data[max(i-2,0)]
		var note_1: Array = secondary_preprocessed_data[max(i-1,0)]
		var note_2: Array = secondary_preprocessed_data[i]
		var note_3: Array = secondary_preprocessed_data[i+1]
		var note_4: Array = secondary_preprocessed_data[min(i+2,secondary_preprocessed_data_len-1)]

		var shift_vec: Vector2

		if (note_2[0] == note_3[0] and note_2[1] == note_3[1]):
			print("ignore")
			var desired: Vector2 = Vector2(
				((processed_data[-1] if len(processed_data) > 0 else note_1)[0] + note_2[0] * 0.5 + note_3[0]) / 2.5,
				((processed_data[-1] if len(processed_data) > 0 else note_1)[1] + note_2[1] * 0.5 + note_3[1]) / 2.5,
			)

			shift_vec = desired - Vector2(note_2[0], note_2[1])

			if shift_vec.x == 0 or shift_vec.y == 0:
				shift_vec = shift_vec.clampf(-SSCS.modifiers.hitbox_size * 0.75, SSCS.modifiers.hitbox_size * 0.75)
			else:
				shift_vec = shift_vec * clamp(shift_vec.x, -SSCS.modifiers.hitbox_size * 0.75, SSCS.modifiers.hitbox_size * 0.75)/shift_vec.x
				shift_vec = shift_vec * clamp(shift_vec.y, -SSCS.modifiers.hitbox_size * 0.75, SSCS.modifiers.hitbox_size * 0.75)/shift_vec.y
		else:
			var pos: Vector2 = SplineManager._get_position(note_0, note_1, note_3, note_4, note_2[2])

			shift_vec = pos - Vector2(note_2[0], note_2[1])

			if shift_vec.x == 0 or shift_vec.y == 0:
				shift_vec = shift_vec.clampf(-max_range, max_range)
			else:
				shift_vec = shift_vec * clamp(shift_vec.x, -max_range, max_range) / shift_vec.x
				shift_vec = shift_vec * clamp(shift_vec.y, -max_range, max_range) / shift_vec.y

		#var new_note: Array = [
			#note_2[0] + shift_vec.x,
			#note_2[1] + shift_vec.y,
			#note_2[2]
		#]

		#if _check_hit(SplineManager._get_position(note_1, new_note, note_3, note_4, new_note[2]), note_2, SSCS.modifiers.hitbox_size):
			#processed_data.append(new_note)
		#else:
			#processed_data.append(note_2)

		var valid: bool = false
		for i2: int in range(0,1):
			var shift_multi: float = (10 - i2) / 10.0
			var new_note: Array = [
				note_2[0] + shift_vec.x * shift_multi,
				note_2[1] + shift_vec.y * shift_multi,
				note_2[2]
			]
			var test_validation_array: Array = processed_data.slice(-3) + [new_note] + secondary_preprocessed_data.slice(i+1, i+4)
			var current_valid: bool = true
			for note: Array in map.data:
				if note[2] >= test_validation_array[2][2] and note[2] <= test_validation_array[-3][2]:
					if !(_check_hit(note, _get_cursor_position_from_notes_and_elapsed(test_validation_array, note[2]+1), SSCS.modifiers.hitbox_size * 0.9) or _check_hit(note, _get_cursor_position_from_notes_and_elapsed(test_validation_array, note[2]+5), SSCS.modifiers.hitbox_size * 0.9)):
						current_valid = false
						break
			if current_valid:
				valid = true
				processed_data.append(new_note)
				break
		if !valid:
			processed_data.append(note_2)
		i += 1

	processed_data.append(preprocessed_data[-1])

	#processed_data = secondary_preprocessed_data

	#map.data = processed_data

	#processed_data = secondary_preprocessed_data


func _get_cursor_position_from_notes_and_elapsed(note_data: Array, elapsed: int) -> Vector2:
	var temp_last_loaded_note: int = 0
	while temp_last_loaded_note + 1<len(note_data):
		var note: Array = note_data[temp_last_loaded_note+1]
		if note[2] > elapsed:
			break
		else:
			temp_last_loaded_note+=1

	var note_0: Array = note_data[max(temp_last_loaded_note - 1,0)]
	var note_1: Array = note_data[temp_last_loaded_note]
	var note_2: Array = note_data[min(temp_last_loaded_note + 1, len(note_data) - 1)]
	var note_3: Array = note_data[min(temp_last_loaded_note + 2, len(note_data) - 1)]

	var return_pos: Vector2 = SplineManager._get_position(note_0, note_1, note_2, note_3, elapsed).clampf(-cursor.GRID_MAX,cursor.GRID_MAX)

	return return_pos

func get_cursor_position() -> Vector2:
	var elapsed: int = int(AudioManager.elapsed * 1000.0 / SSCS.modifiers.speed)
	while last_loaded_note+1<len(processed_data):
		var note: Array = processed_data[last_loaded_note+1]
		if note[2] > elapsed:
			break
		else:
			last_loaded_note+=1

	var note_0: Array = processed_data[max(last_loaded_note - 1,0)]
	var note_1: Array = processed_data[last_loaded_note]
	var note_2: Array = processed_data[min(last_loaded_note + 1, len(processed_data) - 1)]
	var note_3: Array = processed_data[min(last_loaded_note + 2, len(processed_data) - 1)]

	#var offset_forward: int = 1
	#while _check_hit(note_2, note_3, SSCS.modifiers.hitbox_size * 0.5 + 0.01) and last_loaded_note + 2 + offset_forward < len(processed_data):
		##print('forward ', offset_forward)
		#note_3 = processed_data[min(last_loaded_note + 2 + offset_forward, len(processed_data) - 1)]
		#offset_forward += 1
#
	#var offset_backward: int = 1
	#while _check_hit(note_1, note_0, 0.5) and last_loaded_note - 1 - offset_backward >= 0:
		##print('backward')
		#note_0 = processed_data[max(last_loaded_note - 1 - offset_backward,0)]
		#offset_backward += 1

	var return_pos: Vector2 = SplineManager._get_position(note_0, note_1, note_2, note_3, elapsed).clampf(-cursor.GRID_MAX,cursor.GRID_MAX)

	return return_pos
