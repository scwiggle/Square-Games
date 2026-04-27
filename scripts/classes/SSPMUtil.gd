extends Node
class_name SSPMUtil

class SSPM:
	var data_csv: String:
		get():
			if data_csv != "":
				return data_csv
			else:
				var csv_data: PackedStringArray = []
				csv_data.resize(len(data_csv))

				for i: int in range(len(data_csv)):
					var v: Array = data_parsed[i]
					csv_data[i] = "|".join(v) #("{0}|{1}|{2}".format([v.x,v.y,v.t]))

				data_csv=",".join(csv_data)
				return data_csv
	var audio: AudioStream
	var audiobuffer: PackedByteArray
	var cover: Image
	var name: String
	var mapper: String
	var difficulty: String
	var data_parsed: Array[Array]

static var total_load: float = 0

static func get_note_count(path: String) -> int:
	var file:FileAccess = FileAccess.open(path,FileAccess.READ)

	if file==null:
		return 99999999
	
	file.seek(0x70) #just to make sure
	var _markersOffset:int = file.get_64()
	var markersLength:int = file.get_64()
	
	return markersLength
	
static func load_from_path(path: String) -> SSPM:
	var load_start: int = Time.get_ticks_usec()
	var newdata:SSPM = SSPM.new()

	var file:FileAccess = FileAccess.open(path,FileAccess.READ)

	if file==null:
		return newdata

	file.get_32() #skip header
	var version:int = file.get_16()
	file.get_32() #skip Literally Nothing

	if version!=2:
		return newdata

	file.get_buffer(20) #skip hash
	var _lastMarkerMs:int = file.get_32()
	var noteCount:int = file.get_32()
	var _markerCount:int = file.get_32()
	var mapDifficulty:int = file.get_8()
	var _mapRating:int = file.get_16() #what the fuck is this
	var hasAudio:bool = file.get_8()
	var hasCover:bool = file.get_8()
	var _requiresModifier:bool = file.get_8() #what does this even mean

	match mapDifficulty:
		0: newdata.difficulty="None"
		1: newdata.difficulty="Easy"
		2: newdata.difficulty="Medium"
		3: newdata.difficulty="Hard"
		4: newdata.difficulty="Logic"
		5: newdata.difficulty="Tasukete"


	var _customDataOffset:int = file.get_64()
	var _customDataLength:int = file.get_64()

	var audioOffset:int = file.get_64()
	var audioLength:int = file.get_64()

	var coverOffset:int = file.get_64()
	var coverLength:int = file.get_64()

	var _markerDefinitionsOffset:int = file.get_64()
	var _markerDefinitionsLength:int = file.get_64()

	file.seek(0x70) #just to make sure
	var markersOffset:int = file.get_64()
	var _markersLength:int = file.get_64()


	var _mapId:String = file.get_buffer(file.get_16()).get_string_from_utf8()
	var mapname:String = file.get_buffer(file.get_16()).get_string_from_utf8()
	var _songname:String = file.get_buffer(file.get_16()).get_string_from_utf8()

	var mapperCount:int = file.get_16()

	var mappers:Array = []

	for i in range(mapperCount):
		mappers.append(file.get_buffer(file.get_16()).get_string_from_utf8())

	newdata.mapper=" & ".join(mappers)
	#if songname.replace("_"," ")!="Artist Name - Song Name":
		#newdata.name=songname
	#else:
	newdata.name=mapname

	var benchmarking_start_3: int = Time.get_ticks_usec()

	if hasAudio:
		file.seek(audioOffset)
		var audioData:PackedByteArray = file.get_buffer(audioLength)
		if !audioData.is_empty():
			var audioStream:AudioStream
			if audioData[0]==0x4F && audioData[1]==0x67 && audioData[2]==0x67 && audioData[3]==0x53:
				audioStream = AudioStreamOggVorbis.load_from_buffer(audioData)
			else:
				audioStream = AudioStreamMP3.load_from_buffer(audioData)
			newdata.audio=audioStream
			newdata.audiobuffer=audioData

	if hasCover:
		file.seek(coverOffset)
		var coverData:PackedByteArray = file.get_buffer(coverLength)

		var cover:Image = Image.new()

		var imgtype:String = ""
		var i:int=0
		for v:int in [0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]:
			if coverData[i]!=v:
				break
			i+=1
		if i==8:
			imgtype="png"

		if imgtype=="png":
			cover.load_png_from_buffer(coverData)
		elif imgtype=="jpg":
			cover.load_jpg_from_buffer(coverData)
		else:
			for v:int in coverData.slice(1,10):
				print(char(v))

		newdata.cover=cover
	
	var benchmarking_end_3: int = Time.get_ticks_usec()
	#only reason we go to marker definitions is for ssp_note

	file.seek(markersOffset)

	var benchmarking_start_1: int = Time.get_ticks_usec()

	var note_data: Array[Array]
	note_data.resize(noteCount)

	for i: int in range(noteCount):
		var ms:int = file.get_32()

		#var mtype:int = file.get_8() #skip marker type, only marker type thats ever used is ssp_note

		var isQuantum: int = file.get_16()

		if isQuantum==0:
			#var new_note_data: Array = [
				#1.0 - file.get_8(),
				#1.0 - file.get_8(),
				#ms
			#]

			note_data[i] = [
				1.0 - file.get_8(),
				1.0 - file.get_8(),
				ms
			]
		else:
			#var new_note_data: Array = [
				#1.0 - file.get_float(),
				#1.0 - file.get_float(),
				#ms
			#]

			note_data[i] = [
				1.0 - file.get_float(),
				1.0 - file.get_float(),
				ms
			]

	var benchmarking_end_1: int = Time.get_ticks_usec()
	var benchmarking_start_2: int = Time.get_ticks_usec()
	
	var sorting_dict: Dictionary[int, Array]
	var note_mses: PackedInt64Array
	
	for note: Array in note_data:
		var note_t: int = note[2]
		if sorting_dict.has(note_t):
			sorting_dict[note_t].append(note)
		else:
			note_mses.append(note[2])
			sorting_dict[note_t]=[note]
	
	note_mses.sort()
	
	var i: int = 0
	for ms: int in note_mses:
		for note: Array in sorting_dict[ms]:
			note_data[i] = note
			i += 1

	var benchmarking_end_2: int = Time.get_ticks_usec()

	newdata.data_parsed=note_data
	
	var load_end: int = Time.get_ticks_usec()
	
	total_load += (load_end - load_start)/1000.0
	
	#if len(note_data) > 10000:
	#print("Took {0} ms to load notes and {1} ms to sort and {2} ms to make cover and audio with {3} notes, total time spent loading of {4}".format([
		#(benchmarking_end_1-benchmarking_start_1)/1000.0,
		#(benchmarking_end_2-benchmarking_start_2)/1000.0,
		#(benchmarking_end_3-benchmarking_start_3)/1000.0,
		#len(note_data),
		#total_load])
	#)

	return newdata
