class_name AisoraUpdateClient
extends Node
## Only the bundled native helper handles releases, downloads and installation.
## No remote code is interpreted here. Preferences live outside the app bundle.
signal changed
signal quit_for_update

var storage: String="user://updates"
var automatic: bool=false
var previews: bool=false
var installed: String=str(ProjectSettings.get_setting("application/config/version","6.0.0"))
var state: Dictionary={"phase":"idle","message":"Updates are checked only when you ask, unless launch checks are enabled."}
var voice_guard: Callable
var bridge_path: Callable
var health_guard: Callable
var helper_path: String=""
var _pid: int=-1
var _mode: String=""
var _clock: float=0.
var _auto_delay: float=5.
var _health_time: float=0.
var _health_token: String=""
var _launch_armed: bool=false
var _last_state: String=""

func _ready() -> void:
	var prefs: ConfigFile=ConfigFile.new()
	if prefs.load(storage.path_join("preferences.cfg"))==OK:
		automatic=bool(prefs.get_value("updates","check_on_launch",false))
		previews=bool(prefs.get_value("updates","prereleases",false))
	var executable: String=OS.get_executable_path()
	if OS.get_name()=="macOS" and executable.ends_with("/Aisora.app/Contents/MacOS/Aisora"):
		helper_path=executable.get_base_dir().get_base_dir().path_join("Helpers/AisoraUpdater")
		if not FileAccess.file_exists(helper_path):helper_path=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aisora-update-token="):
			var token: String=arg.trim_prefix("--aisora-update-token=")
			if token.length()==64 and RegEx.create_from_string("^[a-f0-9]{64}$").search(token)!=null:_health_token=token
	var previous: Dictionary=_read("status.json")
	if not previous.is_empty():
		state=previous
		if str(state.get("phase","")) in ["starting","downloading","validating","waiting","restarting"]:
			state={"phase":"interrupted","message":"The previous update task was interrupted. Check for updates again, or restore the retained previous version if available."}
	_refresh_processing()

func _read(name_value: String) -> Dictionary:
	var f: FileAccess=FileAccess.open(storage.path_join(name_value),FileAccess.READ)
	if f==null or f.get_length()>1024*1024:return {}
	var data: Variant=JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

func save_preferences() -> void:
	DirAccess.make_dir_recursive_absolute(storage)
	var prefs: ConfigFile=ConfigFile.new()
	prefs.set_value("updates","check_on_launch",automatic);prefs.set_value("updates","prereleases",previews)
	if prefs.save(storage.path_join("preferences.cfg"))!=OK:_message("error","Could not save update preferences. Existing Aisora settings are unchanged.")
	_refresh_processing()

func busy() -> bool:return _pid>0
func voice_busy() -> bool:return voice_guard.is_valid() and bool(voice_guard.call())
func supported() -> bool:return not helper_path.is_empty()
func has_rollback() -> bool:
	var transaction: Dictionary=_read("transaction.json")
	return str(transaction.get("phase","")) in ["prepared","awaiting_health","unconfirmed","complete"] and DirAccess.dir_exists_absolute(str(transaction.get("candidate","")))

func check_for_updates() -> bool:
	return _start("check")

func download_update() -> bool:
	if voice_busy():_message("blocked","End the active Voice session before downloading an update.");return false
	var tag: String=str(state.get("tag",""))
	if tag.is_empty():_message("error","Check for updates first.");return false
	return _start("stage",tag)

func restart_update(rollback: bool=false) -> bool:
	if voice_busy():_message("blocked","Voice has priority. End it in the browser before restarting.");return false
	if not rollback and (str(state.get("phase",""))!="ready" or _read("plan.json").is_empty()):
		_message("error","A fully validated, macOS-accepted update must be staged first.");return false
	if rollback and not has_rollback():_message("error","No retained previous application is available.");return false
	_launch_armed=true
	var result: bool=_start("rollback" if rollback else "install")
	if not result:_launch_armed=false
	return result

func reveal_download() -> void:
	var path: String=str(state.get("path",""))
	if not path.is_empty() and DirAccess.dir_exists_absolute(path):OS.shell_show_in_file_manager(path)
	else:
		DirAccess.make_dir_recursive_absolute(storage)
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(storage))

func _start(mode: String,tag: String="") -> bool:
	if busy():return false
	if not supported():_message("unsupported","Install the updater-enabled Intel Mac build once. Update installation is unavailable in the editor or Linux test player.");return false
	if mode!="check" and voice_busy():_message("blocked","Voice is active; no update task started.");return false
	if DirAccess.make_dir_recursive_absolute(storage)!=OK:_message("error","Cannot write the private update staging directory.");return false
	var arguments: PackedStringArray=["-mode",mode,"-data",ProjectSettings.globalize_path(storage)]
	if previews:arguments.append("-preview")
	if not tag.is_empty():arguments.append_array(["-tag",tag])
	if mode!="check":
		var pairing: String=str(bridge_path.call()) if bridge_path.is_valid() else ""
		if not pairing.is_empty():arguments.append_array(["-bridge",pairing])
	if mode in ["install","rollback"]:arguments.append_array(["-parent",str(OS.get_process_id()),"-confirmed-no-voice"])
	DirAccess.remove_absolute(storage.path_join("status.json"))
	_pid=OS.create_process(helper_path,arguments)
	if _pid<=0:_message("error","The bundled updater could not start. macOS may require approval, or this folder may not permit execution.");return false
	_mode=mode;_last_state="";_clock=0.
	_message("starting","Starting update task…");_refresh_processing();return true

func _message(phase: String,message: String) -> void:
	state=state.duplicate();state.phase=phase;state.message=message;changed.emit()

func _refresh_processing() -> void:set_process(busy() or (automatic and _auto_delay>=0.) or not _health_token.is_empty())

func _process(delta: float) -> void:
	# No frame-by-frame disk access: helper status is polled at 1 Hz only while busy.
	if not _health_token.is_empty():
		_health_time+=delta
		if _health_time>=30. and (not health_guard.is_valid() or bool(health_guard.call())):_ack_health()
	if automatic and not busy() and _auto_delay>=0. and _health_token.is_empty():
		_auto_delay-=delta
		if _auto_delay<=0.:
			if voice_busy():_auto_delay=5.
			else:_auto_delay=-1.;check_for_updates()
	if not busy():_refresh_processing();return
	_clock+=delta
	if _clock<1.:return
	_clock=0.
	if _mode!="check" and voice_busy() and not _launch_armed:
		OS.kill(_pid);_pid=-1;_message("blocked","Update staging stopped because Voice became active. The installed application is unchanged. Retry after Voice ends.");_refresh_processing();return
	var current: Dictionary=_read("status.json")
	if not current.is_empty():
		var serialized: String=JSON.stringify(current)
		if serialized!=_last_state:state=current;_last_state=serialized;changed.emit()
	if _launch_armed and str(state.get("phase",""))=="waiting":
		if voice_busy():
			OS.kill(_pid);_pid=-1;_launch_armed=false;_message("blocked","Voice became active; restart cancelled.");_refresh_processing();return
		quit_for_update.emit();return
	if not OS.is_process_running(_pid):
		_pid=-1;_launch_armed=false
		if str(state.get("phase","")) in ["starting","downloading","validating"]:_message("error","Updater stopped before completing the task. The installed application was not replaced. Retry the check.")
		_refresh_processing();changed.emit()

func _ack_health() -> void:
	var transaction: Dictionary=_read("transaction.json")
	if transaction.get("token","")!=_health_token or installed not in [str(transaction.get("version","")),str(transaction.get("previous_version",""))]:_health_token="";return
	var temporary: String=storage.path_join("healthy.json.tmp")
	var f: FileAccess=FileAccess.open(temporary,FileAccess.WRITE)
	if f==null:return
	f.store_string(JSON.stringify({"token":_health_token,"version":installed}));f.flush();f.close()
	if DirAccess.rename_absolute(temporary,storage.path_join("healthy.json"))==OK:_health_token=""
