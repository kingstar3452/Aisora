extends Node3D
## Presentation only: ChatGPT owns the conversation and personality.
const Character = preload("res://scripts/character_controller.gd")
const Envelope = preload("res://scripts/audio_envelope.gd")
const Bridge = preload("res://scripts/bridge_client.gd")
const Park = preload("res://scripts/sakura_park.gd")
const PerformancePolicy = preload("res://scripts/performance_policy.gd")
const ActionCatalog = preload("res://scripts/action_catalog.gd")
const IllustratedPark = preload("res://scripts/illustrated_park.gd")
const FrameDiagnostics = preload("res://scripts/frame_diagnostics.gd")

var character: AisoraCharacter
var envelope: AisoraAudioEnvelope = Envelope.new()
var bridge: AisoraBridgeClient
var camera: Camera3D
var light: DirectionalLight3D
var settings: ConfigFile = ConfigFile.new()
var settings_path: String = "user://settings.cfg"
var state_label: Label
var connection_label: Label
var detail_label: Label
var audio_label: Label
var settings_panel: PanelContainer
var state_select: OptionButton
var voice_button: Button
var manual_state: int = -1
var demo: bool = false
var elapsed: float = 0.0
var ui_elapsed: float = 0.0
var fps_limit: int = 30
var zoom: float = 3.2
var framing: float = 0.86
var light_energy: float = 1.0
var voice_key: Key = KEY_F8
var ui_layer: CanvasLayer
var quality: int = 0
var park: AisoraSakuraPark
var illustrated: AisoraIllustratedPark
var stage_environment: Environment
var stage_mode: int = 0
var character_scale: float = 1.0
var character_anchor: Vector2 = Vector2(0.5,0.94)
var environment_intensity: float = 0.65
var parallax_enabled: bool = false
var image_dialog: FileDialog
var image_status: Label
var _choose_overlay: bool = false
var scheduler_enabled: bool = true
var idle_interval_min: float = 8.0
var idle_interval_max: float = 15.0
var action_weights: Dictionary = ActionCatalog.WEIGHTS.duplicate()
var interval_min_slider: HSlider
var interval_max_slider: HSlider
var pairing_dialog: FileDialog
var explicit_voice_buttons: Array[Button] = []
var action_status: Label
var performance: AisoraPerformancePolicy = PerformancePolicy.new()
var animation_intensity: float = 1.0
var petal_density: float = 0.45
var performance_label: Label
var diagnostics: AisoraFrameDiagnostics = FrameDiagnostics.new()
var diagnostics_visible: bool = false
var diagnostics_label: Label
var diagnostics_toggle: CheckButton
var _diagnostic_clock: float = 0.0

func _ready() -> void:
	settings.load(settings_path)
	fps_limit = clampi(int(settings.get_value("display", "fps", 30)), 15, 60)
	zoom = clampf(float(settings.get_value("display", "distance", 3.2)), 1.6, 4.0)
	framing = clampf(float(settings.get_value("display", "height", 0.86)), 0.7, 1.5)
	light_energy = clampf(float(settings.get_value("display", "light", 1.0)), 0.25, 2.0)
	envelope.gain = clampf(float(settings.get_value("audio", "gain", 5.0)), 1.0, 15.0)
	envelope.noise_gate = clampf(float(settings.get_value("audio", "gate", 0.012)), 0.001, 0.08)
	voice_key = KEY_F8 if int(settings.get_value("controls", "voice_key", KEY_F8)) != KEY_F9 else KEY_F9
	# Preserve old preferences: old Standard (1) maps to High (2), old lightweight to Low.
	quality = clampi(int(settings.get_value("display", "preset", 2 if int(settings.get_value("display", "quality", 0)) == 1 else 0)),0,2)
	diagnostics_visible = bool(settings.get_value("performance", "diagnostics",false))
	animation_intensity = clampf(float(settings.get_value("animation", "intensity", 1.0)), 0.0, 1.6)
	petal_density = clampf(float(settings.get_value("environment", "petal_density", 0.45)), 0.0, 1.0)
	performance.low_power = bool(settings.get_value("performance", "low_power", false))
	scheduler_enabled = bool(settings.get_value("animation","random_actions",true))
	idle_interval_min = clampf(float(settings.get_value("animation","interval_min",8.0)),5.0,120.0)
	idle_interval_max = clampf(maxf(idle_interval_min,float(settings.get_value("animation","interval_max",15.0))),5.0,180.0)
	var saved_weights: Variant=settings.get_value("animation","weights",{})
	if saved_weights is Dictionary:
		for name: String in ActionCatalog.IDS:
			var weight: Variant=saved_weights.get(name,action_weights[name])
			if (weight is float or weight is int) and is_finite(float(weight)):action_weights[name]=clampf(float(weight),0.0,5.0)
	stage_mode = clampi(int(settings.get_value("environment","mode",0)),0,1)
	character_scale = clampf(float(settings.get_value("environment","character_scale",1.0)),0.5,1.3)
	character_anchor = Vector2(clampf(float(settings.get_value("environment","character_x",0.5)),0.1,0.9),clampf(float(settings.get_value("environment","character_y",0.94)),0.4,0.98))
	environment_intensity = clampf(float(settings.get_value("environment","intensity",0.65)),0.0,1.0)
	parallax_enabled = bool(settings.get_value("environment","parallax",false))
	_apply_quality()
	_build_stage()
	character = Character.new()
	add_child(character)
	_apply_performance_settings()
	bridge = Bridge.new()
	bridge.pairing_path=str(settings.get_value("bridge","pairing_path",""))
	add_child(bridge)
	_build_ui()
	_update_camera()
	_apply_stage_mode()
	get_viewport().size_changed.connect(_place_character)

func _build_stage() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var sky: Environment = Environment.new()
	stage_environment = sky
	sky.background_mode = Environment.BG_SKY
	var backdrop: Sky = Sky.new()
	var backdrop_material: ShaderMaterial = ShaderMaterial.new()
	backdrop_material.shader = load("res://assets/backdrop.gdshader")
	backdrop.sky_material = backdrop_material
	backdrop.radiance_size = Sky.RADIANCE_SIZE_32
	sky.sky = backdrop
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("fff0d9")
	sky.ambient_light_energy = 0.46
	sky.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = sky
	add_child(environment)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	light.light_color = Color("fff0e3")
	light.light_energy = light_energy
	light.shadow_enabled = false
	add_child(light)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
	fill.light_color = Color("f4dfe7")
	fill.light_energy = 0.14
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.05
	camera.far = 75.0
	add_child(camera)
	camera.current = true
	park = Park.new()
	park.build_on_ready=stage_mode==1
	park.name = "SakuraPark"
	add_child(park)
	illustrated = IllustratedPark.new()
	illustrated.background_path = str(settings.get_value("environment","background_path",""))
	illustrated.foreground_path = str(settings.get_value("environment","foreground_path",""))
	add_child(illustrated)

func _update_camera() -> void:
	camera.position = Vector3(0.0, framing + 0.10, zoom)
	camera.look_at(Vector3(0.0, framing, 0.0))
	_place_character()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	var theme: Theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("d9e4f1"))
	root.theme = theme
	var top: MarginContainer = MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 32)
	top.add_theme_constant_override("margin_right", 32)
	top.add_theme_constant_override("margin_top", 24)
	root.add_child(top)
	var row: HBoxContainer = HBoxContainer.new()
	top.add_child(row)
	var brand: VBoxContainer = VBoxContainer.new()
	row.add_child(brand)
	var title: Label = _label("A I S O R A", 28, Color("234a48"))
	brand.add_child(title)
	brand.add_child(_label("A LITTLE MOMENT UNDER THE BLOSSOMS", 11, Color("365c58")))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var controls: VBoxContainer = VBoxContainer.new()
	row.add_child(controls)
	state_label = _label("IDLE", 18, Color("285950"))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(state_label)
	var settings_button: Button = Button.new()
	settings_button.text = "Settings  ·  Tab"
	settings_button.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)
	controls.add_child(settings_button)
	var bottom: MarginContainer = MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_top = -170
	bottom.offset_right = 525
	bottom.offset_bottom = -8
	bottom.add_theme_constant_override("margin_left", 20)
	bottom.add_theme_constant_override("margin_right", 0)
	bottom.add_theme_constant_override("margin_bottom", 12)
	root.add_child(bottom)
	var footer_panel: PanelContainer = PanelContainer.new()
	var footer_style: StyleBoxFlat = StyleBoxFlat.new()
	footer_style.bg_color = Color(0.04, 0.11, 0.12, 0.90)
	footer_style.set_corner_radius_all(10)
	footer_style.content_margin_left = 12
	footer_style.content_margin_right = 12
	footer_style.content_margin_top = 10
	footer_style.content_margin_bottom = 10
	footer_panel.add_theme_stylebox_override("panel", footer_style)
	bottom.add_child(footer_panel)
	var bottom_box: VBoxContainer = VBoxContainer.new()
	footer_panel.add_child(bottom_box)
	connection_label = _label("Manual Voice available", 15)
	bottom_box.add_child(connection_label)
	detail_label = _label("", 13, Color("8aa2bc"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_box.add_child(detail_label)
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	bottom_box.add_child(action_row)
	voice_button = Button.new()
	voice_button.text = "Toggle Voice · F8"
	voice_button.pressed.connect(bridge.toggle_voice)
	action_row.add_child(voice_button)
	var automatic: Button = Button.new()
	automatic.text = "Auto state · 0"
	automatic.pressed.connect(func(): _select_state(0))
	action_row.add_child(automatic)
	audio_label = _label("Output audio: off", 13)
	action_row.add_child(audio_label)
	diagnostics_label = _label("Warming up…",13,Color("e6f4eb"))
	diagnostics_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	diagnostics_label.offset_left = -350
	diagnostics_label.offset_top = -100
	diagnostics_label.offset_right = -20
	diagnostics_label.offset_bottom = -20
	diagnostics_label.add_theme_color_override("font_shadow_color",Color("173f3b"))
	diagnostics_label.add_theme_constant_override("shadow_outline_size",5)
	diagnostics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	diagnostics_label.visible = diagnostics_visible
	root.add_child(diagnostics_label)
	_build_settings(root)

func _label(text: String, size: int, color: Color = Color("d9e4f1")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_settings(root: Control) -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	settings_panel.offset_left = -370
	settings_panel.offset_right = -24
	settings_panel.offset_top = -300
	settings_panel.offset_bottom = 300
	settings_panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.13, 0.97)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	settings_panel.add_theme_stylebox_override("panel", style)
	root.add_child(settings_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	settings_panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(box)
	box.add_child(_label("Performance & presentation", 18))
	state_select = OptionButton.new()
	for item in ["Auto · 0", "Idle · 1", "Listening · 2", "Thinking · 3", "Talking · 4", "Sleeping · 5"]:
		state_select.add_item(item)
	state_select.item_selected.connect(_select_state)
	box.add_child(state_select)
	var quality_select: OptionButton = OptionButton.new()
	quality_select.add_item("Low · efficient materials, fewer petals")
	quality_select.add_item("Balanced · sharper scenery & detail")
	quality_select.add_item("High · original MToon, 2× AA")
	quality_select.select(quality)
	quality_select.item_selected.connect(func(index: int): quality = index; _apply_quality(); _apply_performance_settings(); _save())
	box.add_child(quality_select)
	var low_power_toggle: CheckButton = CheckButton.new()
	low_power_toggle.text = "Low-power mode · 15 FPS"
	low_power_toggle.button_pressed = performance.low_power
	low_power_toggle.toggled.connect(func(on: bool): performance.low_power = on; _apply_quality(); _apply_performance_settings(); _save())
	box.add_child(low_power_toggle)
	_slider(box, "Animation intensity", 0.0, 1.6, 0.05, animation_intensity, func(value: float): animation_intensity = value; _apply_performance_settings(); _save())
	_slider(box, "Petal density", 0.0, 1.0, 0.05, petal_density, func(value: float): petal_density = value; _apply_performance_settings(); _save())
	_slider(box, "Foreground FPS limit", 15, 60, 5, fps_limit, func(value: float): fps_limit = int(value); _save())
	performance_label = _label("30 FPS cap · foreground", 12, Color("9fdbc9"))
	box.add_child(performance_label)
	diagnostics_toggle = CheckButton.new()
	diagnostics_toggle.text = "FPS / frame-time overlay · F3"
	diagnostics_toggle.button_pressed = diagnostics_visible
	diagnostics_toggle.toggled.connect(func(on: bool): diagnostics_visible = on; diagnostics_label.visible = on; _save())
	box.add_child(diagnostics_toggle)
	box.add_child(_label("Standing actions",18))
	var random_toggle: CheckButton=CheckButton.new();random_toggle.text="Weighted random idle actions";random_toggle.button_pressed=scheduler_enabled
	random_toggle.toggled.connect(func(on: bool): scheduler_enabled=on; _apply_performance_settings(); _save())
	box.add_child(random_toggle)
	interval_min_slider=_slider(box,"Minimum idle interval (seconds)",5,120,1,idle_interval_min,func(value: float): idle_interval_min=value; interval_max_slider.value=maxf(value,interval_max_slider.value); _apply_performance_settings(); _save())
	interval_max_slider=_slider(box,"Maximum idle interval (seconds)",5,180,1,idle_interval_max,func(value: float): idle_interval_max=value; interval_min_slider.value=minf(value,interval_min_slider.value); _apply_performance_settings(); _save())
	var gesture_select: OptionButton=OptionButton.new()
	for index in ActionCatalog.IDS.size():gesture_select.add_item("%02d · %s"%[ActionCatalog.REQUEST_NUMBERS[index],ActionCatalog.LABELS[index]])
	box.add_child(gesture_select)
	var gesture_button: Button=Button.new();gesture_button.text="Preview selected action"
	gesture_button.pressed.connect(func(): _preview_action(ActionCatalog.IDS[gesture_select.selected]))
	box.add_child(gesture_button)
	box.add_child(_label("Random weight for this action (0 = off)",12))
	var weight_control: SpinBox=SpinBox.new();weight_control.min_value=0;weight_control.max_value=5;weight_control.step=0.1;weight_control.value=action_weights[ActionCatalog.IDS[0]]
	gesture_select.item_selected.connect(func(index: int): weight_control.set_value_no_signal(float(action_weights[ActionCatalog.IDS[index]])))
	weight_control.value_changed.connect(func(value: float): action_weights[ActionCatalog.IDS[gesture_select.selected]]=value; _apply_performance_settings(); _save())
	box.add_child(weight_control)
	action_status=_label("15 standing actions + standing sleep/wake.
Walking, full turns, sitting, lying and rising from the floor are unavailable.",12,Color("b9c8d9"))
	action_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(action_status)
	_build_scenery_settings(box,root)
	_slider(box, "Camera distance", 1.6, 4.0, 0.05, zoom, func(value: float): zoom = value; _update_camera(); _save())
	_slider(box, "Camera height", 0.7, 1.5, 0.02, framing, func(value: float): framing = value; _update_camera(); _save())
	_slider(box, "Lighting", 0.25, 2.0, 0.05, light_energy, func(value: float): light_energy = value; light.light_energy = value; character.set_lighting(value); _save())
	box.add_child(_label("Voice connection",18))
	var pair_button: Button=Button.new();pair_button.text="Choose bridge pairing file…"
	pair_button.pressed.connect(func():pairing_dialog.popup_centered_ratio(0.7));box.add_child(pair_button)
	pairing_dialog=FileDialog.new();pairing_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;pairing_dialog.access=FileDialog.ACCESS_FILESYSTEM;pairing_dialog.filters=PackedStringArray(["*.json ; Local bridge pairing"]);pairing_dialog.use_native_dialog=true
	pairing_dialog.file_selected.connect(func(path: String):
		if bridge.choose_pairing_file(path):_save()
	)
	root.add_child(pairing_dialog)
	for action: String in ["start","end"]:
		var button: Button=Button.new();button.text="Start Voice" if action=="start" else "End Voice"
		button.pressed.connect(bridge.start_voice if action=="start" else bridge.end_voice)
		box.add_child(button);explicit_voice_buttons.append(button)
	var release_guard: Button=Button.new();release_guard.text="Voice ended manually · resume idle actions";release_guard.add_theme_font_size_override("font_size",12);release_guard.pressed.connect(bridge.clear_session_guard);box.add_child(release_guard)
	var voice_help: Label=_label("If browser automation fails, use ChatGPT’s own Voice button. Allow microphone permissions there; do not share account credentials.",12)
	voice_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(voice_help)
	_slider(box, "Mouth sensitivity", 1.0, 15.0, 0.25, envelope.gain, func(value: float): envelope.gain = value; _save())
	_slider(box, "Silence threshold", 0.001, 0.08, 0.001, envelope.noise_gate, func(value: float): envelope.noise_gate = value; _save())
	var key_select: OptionButton = OptionButton.new()
	key_select.add_item("Voice shortcut: F8")
	key_select.add_item("Voice shortcut: F9")
	key_select.select(0 if voice_key == KEY_F8 else 1)
	key_select.item_selected.connect(func(index: int): voice_key = KEY_F8 if index == 0 else KEY_F9; _save())
	box.add_child(key_select)
	var demo_toggle: CheckButton = CheckButton.new()
	demo_toggle.text = "Test mouth (synthetic amplitude)"
	demo_toggle.toggled.connect(func(on: bool): demo = on)
	box.add_child(demo_toggle)
	var fullscreen: Button = Button.new()
	fullscreen.text = "Full-screen / windowed · F11"
	fullscreen.pressed.connect(_toggle_fullscreen)
	box.add_child(fullscreen)
	box.add_child(_label("Tab: settings   H: hide interface\n1–5: test states   0: automatic\nEsc: leave full-screen", 12, Color("8aa2bc")))

func _slider(box: VBoxContainer, title: String, minimum: float, maximum: float, step: float, value: float, changed: Callable) -> HSlider:
	var caption: Label = _label("%s · %.2f" % [title, value], 13)
	box.add_child(caption)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(next_value: float): caption.text = "%s · %.2f" % [title, next_value])
	slider.value_changed.connect(changed)
	box.add_child(slider)
	return slider

func _save() -> void:
	settings.set_value("bridge","pairing_path",bridge.pairing_path)
	settings.set_value("animation","random_actions",scheduler_enabled)
	settings.set_value("animation","interval_min",idle_interval_min)
	settings.set_value("animation","interval_max",idle_interval_max)
	settings.set_value("animation","weights",action_weights)
	settings.set_value("environment","mode",stage_mode)
	settings.set_value("environment","character_scale",character_scale)
	settings.set_value("environment","character_x",character_anchor.x)
	settings.set_value("environment","character_y",character_anchor.y)
	settings.set_value("environment","intensity",environment_intensity)
	settings.set_value("environment","parallax",parallax_enabled)
	settings.set_value("environment","background_path",illustrated.background_path)
	settings.set_value("environment","foreground_path",illustrated.foreground_path)
	settings.set_value("display", "fps", fps_limit)
	settings.set_value("display", "distance", zoom)
	settings.set_value("display", "height", framing)
	settings.set_value("display", "light", light_energy)
	settings.set_value("display", "quality", 1 if quality == 2 else 0)
	settings.set_value("display", "preset",quality)
	settings.set_value("performance", "diagnostics",diagnostics_visible)
	settings.set_value("animation", "intensity", animation_intensity)
	settings.set_value("environment", "petal_density", petal_density)
	settings.set_value("performance", "low_power", performance.low_power)
	settings.set_value("audio", "gain", envelope.gain)
	settings.set_value("audio", "gate", envelope.noise_gate)
	settings.set_value("controls", "voice_key", voice_key)
	settings.save(settings_path)

func _select_state(index: int) -> void:
	manual_state = index - 1
	state_select.select(index)

func _process(delta: float) -> void:
	if character == null or bridge == null:
		return
	elapsed += delta
	diagnostics.record(delta)
	_diagnostic_clock += delta
	if diagnostics_visible and _diagnostic_clock >= 0.5:
		_diagnostic_clock = 0.0
		var stats: Dictionary = diagnostics.snapshot()
		diagnostics_label.text = "%.1f FPS · %.1f ms / frame\nP95 %.1f ms · Engine process %.2f ms\n%d draw calls · cap %d · %s" % [stats.fps,stats.mean_ms,stats.p95_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Engine.max_fps,["Low","Balanced","High"][quality]]
	var voice_active: bool = bridge.state.get("voice", "unknown") == "active"
	var audio_fresh: bool = bool(bridge.state.get("capturing", false)) and (voice_active or manual_state == Character.State.TALKING)
	var rms: float = float(bridge.state.get("rms", 0.0))
	if demo:
		audio_fresh = true
		rms = (sin(elapsed * 9.0) * 0.5 + 0.5) * 0.15
	character.mouth = envelope.update(rms, audio_fresh, delta)
	character.motion.conversation_active=voice_active or bridge.session_may_be_active or bridge.command_pending() or envelope.speaking
	var next: int = manual_state
	if next < 0:
		next = Character.State.TALKING if envelope.speaking else ((Character.State.THINKING if bridge.state.get("activity","")=="thinking" else Character.State.LISTENING) if voice_active else Character.State.IDLE)
	character.set_state(next as Character.State)
	performance.fps_limit = fps_limit
	Engine.max_fps = performance.frame_cap(character.motion.is_resting())
	var hidden: bool = not performance.focused or performance.minimized
	park.suspended = hidden or stage_mode==0
	illustrated.suspended = hidden
	character.backgrounded = hidden
	var resting: bool = character.motion.is_resting()
	if park.resting != resting:
		park.resting = resting
		park.apply_performance()
	ui_elapsed += delta
	if ui_elapsed < 0.2:
		return
	ui_elapsed = 0.0
	if DisplayServer.get_name() != "headless":
		performance.minimized = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
	var activity: String = "minimized" if performance.minimized else ("inactive" if not performance.focused else "foreground")
	performance_label.text = "%d FPS cap · %s" % [Engine.max_fps, activity]
	state_label.text = Character.STATE_NAMES[character.state] + ("  ·  TEST" if manual_state >= 0 or demo else "")
	var connected: bool = bool(bridge.state.get("connected", false))
	connection_label.text=("Bridge online" if bridge.age<1.5 else "Bridge offline")+(" · Browser connected" if connected else " · Browser disconnected")+" · Voice "+str(bridge.state.get("voice","unknown"))
	detail_label.text = str(bridge.state.get("error", ""))
	voice_button.text = "Waiting for browser…" if bridge.state.get("pending", false) else "Toggle Voice · " + ("F8" if voice_key == KEY_F8 else "F9")
	voice_button.disabled = not connected or bridge.command_pending()
	for button: Button in explicit_voice_buttons:button.disabled=voice_button.disabled
	audio_label.text = "TEST AMPLITUDE" if demo else ("Tab output: %.0f%%" % [envelope.mouth * 100.0] if audio_fresh else "Tab output: off / silent")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == voice_key:
		bridge.toggle_voice()
	elif event.keycode >= KEY_0 and event.keycode <= KEY_5:
		_select_state(event.keycode - KEY_0)
	elif event.keycode == KEY_TAB:
		settings_panel.visible = not settings_panel.visible
	elif event.keycode == KEY_F3:
		diagnostics_visible = not diagnostics_visible
		diagnostics_label.visible = diagnostics_visible
		diagnostics_toggle.set_pressed_no_signal(diagnostics_visible)
		_save()
	elif event.keycode == KEY_H:
		ui_layer.visible = not ui_layer.visible
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()
	elif event.keycode == KEY_ESCAPE:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		return
	get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_quality() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X if quality == 2 and not performance.low_power else Viewport.MSAA_DISABLED
	if character != null:
		character.set_visual_quality(0 if performance.low_power else quality)
		character.set_lighting(light_energy)

func _apply_performance_settings() -> void:
	if character != null:
		character.motion.configure_scheduler(idle_interval_min,idle_interval_max,scheduler_enabled,action_weights)
		character.animation_intensity = animation_intensity
		character.low_power = performance.low_power
		character.set_visual_quality(0 if performance.low_power else quality)
		character.set_lighting(light_energy)
	if illustrated != null:
		illustrated.quality=quality;illustrated.low_power=performance.low_power
		illustrated.intensity=environment_intensity;illustrated.density=petal_density;illustrated.parallax=parallax_enabled
		illustrated.apply_performance()
	if park != null:
		park.quality = quality
		park.petal_density = petal_density
		park.low_power = performance.low_power
		park.apply_performance()

func _notification(what: int) -> void:
	if performance == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		performance.focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		performance.focused = true
		performance.minimized = false

func _apply_stage_mode() -> void:
	if park==null or illustrated==null:return
	if stage_mode==1:park.ensure_built()
	park.visible=stage_mode==1
	park.suspended=stage_mode==0 or not performance.focused or performance.minimized
	stage_environment.background_mode=Environment.BG_CANVAS if stage_mode==0 else Environment.BG_SKY
	stage_environment.background_canvas_max_layer=-1
	illustrated.enabled=stage_mode==0
	illustrated.apply_performance()
	_place_character()

func _place_character() -> void:
	if character==null or camera==null or illustrated==null:return
	character.scale=Vector3.ONE*(character_scale if stage_mode==0 else 1.0)
	character.position=Vector3.ZERO
	if stage_mode==0:
		var pixel: Vector2=get_viewport().get_visible_rect().size*character_anchor
		var origin: Vector3=camera.project_ray_origin(pixel)
		var direction: Vector3=camera.project_ray_normal(pixel)
		if absf(direction.z)>0.001:character.position=origin-direction*(origin.z/direction.z)
	illustrated.character_anchor=character_anchor;illustrated.character_scale=character_scale;illustrated.resize()

func _image_selected(path: String) -> void:
	if illustrated.load_local(path,_choose_overlay):
		stage_mode=0;_apply_stage_mode();_save()
	image_status.text=illustrated.message

func _build_scenery_settings(box: VBoxContainer, root: Control) -> void:
	box.add_child(_label("Illustrated scenery",18))
	var scenery_select: OptionButton = OptionButton.new()
	scenery_select.add_item("Illustrated background + 3D Aisora")
	scenery_select.add_item("Original 3D park fallback")
	scenery_select.select(stage_mode)
	scenery_select.item_selected.connect(func(index: int): stage_mode=index; _apply_stage_mode(); _save())
	box.add_child(scenery_select)
	image_status = _label(illustrated.message,12,Color("a8d4c5"))
	image_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(image_status)
	for overlay: bool in [false,true]:
		var choose: Button=Button.new()
		choose.text="Choose transparent foreground…" if overlay else "Choose local park image…"
		choose.pressed.connect(func(): _choose_overlay=overlay; image_dialog.popup_centered_ratio(0.7))
		box.add_child(choose)
	image_dialog=FileDialog.new();image_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;image_dialog.access=FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; Images"])
	image_dialog.use_native_dialog=true
	image_dialog.file_selected.connect(_image_selected)
	root.add_child(image_dialog)
	_slider(box,"Character scale",0.5,1.3,0.05,character_scale,func(value: float): character_scale=value; _place_character(); _save())
	_slider(box,"Character horizontal position",0.1,0.9,0.02,character_anchor.x,func(value: float): character_anchor.x=value; _place_character(); _save())
	_slider(box,"Character ground position",0.4,0.98,0.02,character_anchor.y,func(value: float): character_anchor.y=value; _place_character(); _save())
	_slider(box,"Scenery animation (0 = off)",0.0,1.0,0.05,environment_intensity,func(value: float): environment_intensity=value; _apply_performance_settings(); _save())
	var parallax_toggle: CheckButton=CheckButton.new();parallax_toggle.text="Slow background parallax";parallax_toggle.button_pressed=parallax_enabled
	parallax_toggle.toggled.connect(func(on: bool): parallax_enabled=on; _apply_performance_settings(); _save())
	box.add_child(parallax_toggle)

func _preview_action(name: String) -> bool:
	if bridge.state.get("voice","")=="active" or bridge.session_may_be_active or bridge.command_pending() or envelope.speaking:
		action_status.text="Action preview paused during Voice. Your conversation keeps control."
		return false
	_select_state(1);character.set_state(Character.State.IDLE)
	var ok: bool=character.play_gesture(name)
	action_status.text="Preview: "+name.replace("_"," ") if ok else "This action is unavailable."
	return ok
