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
var key: String = ""
var port: int = 8765

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 0.8
	add_child(request)
	request.request_completed.connect(_received)
	command_request = HTTPRequest.new()
	command_request.timeout = 1.0
	add_child(command_request)
	command_request.request_completed.connect(_command_received)
	_load_pairing()

func _load_pairing() -> void:
	var path: String = OS.get_environment("AISORA_BRIDGE_CONFIG")
	if path.is_empty():
		path = "res://.local/bridge.json"
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("key", "") is String and data.get("port", 0) is float:
		var candidate_port: int = int(data.port)
		if str(data.key).length() == 64 and candidate_port >= 1024 and candidate_port <= 65535:
			key = data.key
			port = candidate_port

func _process(delta: float) -> void:
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
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and data is Dictionary and data.get("voice", "") in ["unknown", "active", "inactive"]:
		state = data
		age = 0.0
		status_changed.emit()
	else:
		_offline()

func _offline() -> void:
	state = {"connected": false, "voice": "unknown", "capturing": false, "rms": 0.0, "pending": false, "error": "Bridge unavailable. Start tools/start_bridge.command; manual Voice still works."}
	status_changed.emit()

func toggle_voice() -> void:
	if key.is_empty() or command_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var result: Error = command_request.request(_url("/v1/command"), _headers(), HTTPClient.METHOD_POST, JSON.stringify({"action": "toggle"}))
	if result != OK:
		_offline()

func _command_received(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_offline()
	elif code != 200:
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		state.error = str(data.get("error", "Voice command failed. Use the browser manually.")) if data is Dictionary else "Voice command failed."
		status_changed.emit()
