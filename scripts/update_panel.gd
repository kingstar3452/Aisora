extends VBoxContainer
## Plain release notes; downloaded text is never rendered as executable content.
var client: AisoraUpdateClient
var version_label: Label
var status_label: Label
var notes: TextEdit
var check_button: Button
var download_button: Button
var restart_button: Button
var restore_button: Button
var confirm: ConfirmationDialog
var _rollback: bool=false
var _clock: float=0.

func _ready() -> void:
	var title: Label=Label.new();title.text="Aisora updates";title.add_theme_font_size_override("font_size",18);add_child(title)
	version_label=Label.new();version_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(version_label)
	for preference: String in ["automatic","previews"]:
		var toggle: CheckButton=CheckButton.new();toggle.text="Check for updates on launch" if preference=="automatic" else "Include preview releases";toggle.button_pressed=bool(client.get(preference))
		toggle.toggled.connect(func(on: bool):client.set(preference,on);client.save_preferences());add_child(toggle)
	check_button=_button("Check for Updates",client.check_for_updates)
	download_button=_button("Download & Install Update",client.download_update)
	restart_button=_button("Restart to Update",func():_confirm_restart(false))
	restore_button=_button("Restore Previous Version…",func():_confirm_restart(true))
	_button("Show downloaded update / update files",client.reveal_download)
	status_label=Label.new();status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.add_theme_font_size_override("font_size",12);add_child(status_label)
	notes=TextEdit.new();notes.editable=false;notes.custom_minimum_size=Vector2(0,130);notes.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;notes.add_theme_font_size_override("font_size",12);add_child(notes)
	var help: Label=Label.new();help.text="Download & Install stages and validates first. Restart is separate. Ad-hoc builds can be blocked by Gatekeeper; security checks are never disabled.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.add_theme_font_size_override("font_size",12);add_child(help)
	confirm=ConfirmationDialog.new();confirm.title="Restart Aisora";confirm.dialog_text="End ChatGPT Voice in the browser first.\nConfirm there is no active Voice session.\n\nThe helper will wait for Aisora to close, revalidate the staged app and preserve the previous version. Local settings and images remain untouched.";confirm.ok_button_text="Voice ended · restart";add_child(confirm)
	confirm.confirmed.connect(func():client.restart_update(_rollback))
	client.changed.connect(refresh);refresh()

func _button(title: String,action: Callable) -> Button:
	var button: Button=Button.new();button.text=title;button.add_theme_font_size_override("font_size",13);button.pressed.connect(action);add_child(button);return button
func _confirm_restart(rollback: bool) -> void:
	if client.voice_busy():return
	_rollback=rollback;confirm.title="Restore previous Aisora" if rollback else "Restart to Update";confirm.popup_centered(Vector2i(430,210))
func refresh() -> void:
	if version_label==null:return
	var phase: String=str(client.state.get("phase","idle"))
	version_label.text="Installed: %s\nLatest: %s"%[client.installed,str(client.state.get("latest","Not checked"))]
	status_label.text=str(client.state.get("message",""))
	if phase=="downloading":status_label.text+="\n%.1f / %.1f MB"%[float(client.state.get("received",0))/1000000.,float(client.state.get("total",0))/1000000.]
	var text: String=str(client.state.get("notes",""))
	if not text.is_empty():notes.text=text.left(16000)
	check_button.disabled=client.busy()
	download_button.disabled=client.busy() or client.voice_busy() or str(client.state.get("tag","")).is_empty() or phase=="ready"
	restart_button.disabled=client.busy() or client.voice_busy() or phase!="ready"
	restore_button.disabled=client.busy() or client.voice_busy() or not client.has_rollback()
func _process(delta: float) -> void:
	# Controls track Voice only while this settings panel is visible.
	if not is_visible_in_tree():return
	_clock+=delta
	if _clock>=.5:_clock=0.;refresh()
