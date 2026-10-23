class_name AisoraBridgeClient
extends Node
## Loopback only. The pairing key is unrelated to ChatGPT authentication.
signal status_changed

var state: Dictionary = {"connected": false, "voice": "unknown", "capturing": false, "rms": 0.0, "pending": false, "error": "Start the local bridge and pair the extension."}
var request: HTTPRequest
var command_request: HTTPRequest
var elapsed: float = 0.0
var age: float = 99.0
var busy: bool = false
var command_busy: bool = false
var key: String = ""
var pairing_path: String = ""
var command_cooldown: float = 0.0
var session_may_be_active: bool = false
var port: int = 8765

func _ready() -> void:
	request = HTTPRequest.new()
	# Network progress must not depend on the render-frame cap (5 FPS when minimized).
	request.use_threads = true
	request.timeout = 0.8
	add_child(request)
	request.request_completed.connect(_received)
	command_request = HTTPRequest.new()
	command_request.use_threads = true
	command_request.timeout = 1.0
	add_child(command_request)
	command_request.request_completed.connect(_command_received)
	_load_pairing()

func _pairing_data(path: String) -> Dictionary:
	var file: FileAccess=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2048:return {}
	var decoder: JSON=JSON.new()
	if decoder.parse(file.get_as_text())!=OK:return {}
	var data: Variant=decoder.data
	if not data is Dictionary:return {}
	var candidate: Variant=data.get("key","")
	var candidate_port: Variant=data.get("port",0)
	if not candidate is String or not candidate_port is float:return {}
	var pattern: RegEx=RegEx.create_from_string("^[a-f0-9]{64}$")
	if pattern.search(candidate)==null or candidate_port!=int(candidate_port) or candidate_port<1024 or candidate_port>65535:return {}
	return {"key":candidate,"port":int(candidate_port)}

func _load_pairing() -> void:
	var path: String=pairing_path
	if path.is_empty():path=OS.get_environment("AISORA_BRIDGE_CONFIG")
	if path.is_empty():path="res://.local/bridge.json"
	var data: Dictionary=_pairing_data(path)
	if not data.is_empty():key=data.key;port=data.port

func choose_pairing_file(path: String) -> bool:
	var data: Dictionary=_pairing_data(path)
	if data.is_empty():
		state.error="Invalid pairing file. Choose the small bridge.json created by the local bridge."
		status_changed.emit();return false
	pairing_path=path;key=data.key;port=data.port
	request.cancel_request();busy=false;age=99.0;elapsed=1.0
	state.error="Pairing file selected. Waiting for bridge authentication…";status_changed.emit()
	return true

func _process(delta: float) -> void:
	command_cooldown=maxf(0.0,command_cooldown-delta)
	elapsed += delta
	age += delta
	if age > 0.5:
		state.rms = 0.0
		state.capturing = false
	if busy or elapsed < (0.1 if age < 1.0 else 1.0):
		return
	elapsed = 0.0
	if age > 1.0:
		_load_pairing()
	if key.is_empty():
		return
	busy = true
	var result: Error = request.request(_url("/v1/state"), _headers())
	if result != OK:
		busy = false
		_offline()

func _url(path: String) -> String:
	return "http://127.0.0.1:%d%s" % [port, path]

func _headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "X-Aisora-Key: " + key])

func _received(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var data: Variant = null
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and not body.is_empty():
		var decoder: JSON = JSON.new()
		if decoder.parse(body.get_string_from_utf8()) == OK:
			data = decoder.data
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and data is Dictionary and data.get("voice", "") in ["unknown", "active", "inactive"]:
		if data.voice=="active":session_may_be_active=true
		elif data.voice=="inactive" and data.get("connected",false):session_may_be_active=false
		state = data
		age = 0.0
		status_changed.emit()
	else:
		_offline("Pairing rejected. Choose the current bridge.json in Settings." if code==401 else "")

func _offline(message: String="") -> void:
	state = {"connected": false, "voice": "unknown", "capturing": false, "rms": 0.0, "pending": false, "error": "Bridge unavailable. Start tools/start_bridge.command; manual Voice still works."}
	if not message.is_empty():state.error=message
	status_changed.emit()

func command_pending() -> bool:
	return command_busy or command_cooldown>0.0 or bool(state.get("pending",false))

func clear_session_guard() -> void:
	session_may_be_active=false

func toggle_voice() -> void:_send_voice("toggle")
func start_voice() -> void:_send_voice("start")
func end_voice() -> void:_send_voice("end")

func _send_voice(action: String) -> void:
	if key.is_empty() or command_pending():return
	if action=="start" or (action=="toggle" and state.get("voice","")!="active"):session_may_be_active=true
	command_busy=true;command_cooldown=0.8;state.pending=true
	var result: Error=command_request.request(_url("/v1/command"),_headers(),HTTPClient.METHOD_POST,JSON.stringify({"action":action}))
	if result!=OK:command_busy=false;_offline()

func _command_received(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	command_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_offline()
	elif code == 200:
		state.pending=true
		status_changed.emit()
	elif code != 200:
		state.pending=false
		var decoder: JSON = JSON.new()
		var data: Variant = decoder.data if decoder.parse(body.get_string_from_utf8()) == OK else null
		state.error = str(data.get("error", "Voice command failed. Use the browser manually.")) if data is Dictionary else "Voice command failed."
		status_changed.emit()
