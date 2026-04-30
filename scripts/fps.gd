extends RichTextLabel

func _physics_process(_dt:float ) -> void:
	self.text = str(Engine.get_frames_per_second())

func teststuff(a:int=0,b:int=0,c:int=0,d:int=0) -> int:
	var e: int = a+b*c+d
	return e
func benchmark() -> void:
	#debug function for testing some stuff
	pass

	const num_trials: int = 1000
	const trial_iterations: int = 10000

	var t1s: Array[int] = []
	t1s.resize(num_trials)

	var t2s: Array[int] = []
	t2s.resize(num_trials)

	var a:int = randi()
	var b:int = randi()
	var c:int = randi()
	var d:int = randi()
	var testfunc: Callable = teststuff.bindv([randi(),randi(),randi(),randi()])

	for trial in range(num_trials):

		var t1: int = Time.get_ticks_usec()

		for i in range(trial_iterations):
			var _a: int = teststuff(a,b,c,d)


		t1s[trial]=(Time.get_ticks_usec()-t1)

		var t2: int = Time.get_ticks_usec()


		for i in range(trial_iterations):
			var _a: int = testfunc.call()

		t2s[trial]=(Time.get_ticks_usec()-t2)

	var t1a:float = 0
	var t2a:float = 0

	for t in t1s:
		t1a+=t
	t1a/=len(t1s)

	for t in t2s:
		t2a+=t
	t2a/=len(t2s)

	print("T1: {0}\nT2: {1}".format([t1a,t2a]))


func _ready() -> void:
	pass
	var arr: PackedByteArray = [0xff, 0xff]

	print(arr)

	ReplayParser.write_bits(arr, 0, 9, 0b100000001)

	print(arr)

	print(ReplayParser.read_bits(arr, 0, 9))
	print(0)

	#var st: int = Time.get_ticks_usec()
	#
	#for i in range(0, 100_000):
		#var a: Array = []
		#a.resize(1000)
		#
		#var i2: int = 0
		#var al: int = len(a)
		#while i2 < al:
			#i2 += 1
	#
	#var et: int = Time.get_ticks_usec()
	#
	#print((et - st) / 1_000.0)

	#var sspm: SSPMUtil.SSPM = SSPMUtil.load_from_path("user://rhythiamaps/stress.sspm")

	#var request: HTTPRequest = HTTPRequest.new()
	#self.add_child(request)
#
	#var data: PackedStringArray = []
#
	#var boundary: String = "--GODOT" + Crypto.new().generate_random_bytes(16).hex_encode()
#
	#data.append("--%s" % boundary)
	#data.append('Content-Disposition: form-data; name="time"')
	#data.append("")
	#data.append("1h")
#
	#data.append("--%s" % boundary)
	#data.append('Content-Disposition: form-data; name="fileNameLength"')
	#data.append("")
	#data.append("16")
#
	#data.append("--%s" % boundary)
	#data.append('Content-Disposition: form-data; name="reqtype"')
	#data.append("")
	#data.append("fileupload")
#
	#data.append("--%s" % boundary)
	#data.append('Content-Disposition: form-data; name="fileToUpload"; filename="test.txt"')
	#data.append('Content-Type: text/plain')
	#data.append("")
	#data.append("Hello, World!")
	#data.append("--%s--" % boundary)
#
	#request.request("https://litterbox.catbox.moe/resources/internals/api.php", ["Content-Type: multipart/form-data;boundary=%s" % boundary], HTTPClient.METHOD_POST, "\r\n".join(data))
#
	#request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
		#print(result)
		#print(response_code)
		##for v: String in headers:
			##print(v)
		#DisplayServer.clipboard_set(body.get_string_from_utf8())
		#print(body.get_string_from_utf8())
	#)
	#benchmark()
