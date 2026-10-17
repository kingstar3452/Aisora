extends Node3D
## Presentation only: ChatGPT owns the conversation and personality.
const Character = preload("res://scripts/character_controller.gd")
const Envelope = preload("res://scripts/audio_envelope.gd")
const Bridge = preload("res://scripts/bridge_client.gd")
const Park = preload("res://scripts/sakura_park.gd")
const PerformancePolicy = preload("res://scripts/performance_policy.gd")

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
var performance: AisoraPerformancePolicy = PerformancePolicy.new()
var animation_intensity: float = 1.0
var petal_density: float = 0.45
var performance_label: Label

func _ready() -> void:
	settings.load(settings_path)
	fps_limit = clampi(int(settings.get_value("display", "fps", 30)), 15, 60)
	zoom = clampf(float(settings.get_value("display", "distance", 3.2)), 1.6, 4.0)
	framing = clampf(float(settings.get_value("display", "height", 0.86)), 0.7, 1.5)
	light_energy = clampf(float(settings.get_value("display", "light", 1.0)), 0.25, 2.0)
	envelope.gain = clampf(float(settings.get_value("audio", "gain", 5.0)), 1.0, 15.0)
	envelope.noise_gate = clampf(float(settings.get_value("audio", "gate", 0.012)), 0.001, 0.08)
	voice_key = KEY_F8 if int(settings.get_value("controls", "voice_key", KEY_F8)) != KEY_F9 else KEY_F9
	quality = clampi(int(settings.get_value("display", "quality", 0)), 0, 1)
	animation_intensity = clampf(float(settings.get_value("animation", "intensity", 1.0)), 0.0, 1.6)
	petal_density = clampf(float(settings.get_value("environment", "petal_density", 0.45)), 0.0, 1.0)
	performance.low_power = bool(settings.get_value("performance", "low_power", false))
	_apply_quality()
	_build_stage()
	character = Character.new()
	add_child(character)
	_apply_performance_settings()
	bridge = Bridge.new()
	add_child(bridge)
	_build_ui()
	_update_camera()

func _build_stage() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var sky: Environment = Environment.new()
	sky.background_mode = Environment.BG_SKY
	var backdrop: Sky = Sky.new()
	var backdrop_material: ShaderMaterial = ShaderMaterial.new()
	backdrop_material.shader = load("res://assets/backdrop.gdshader")
	backdrop.sky_material = backdrop_material
	backdrop.radiance_size = Sky.RADIANCE_SIZE_32
	sky.sky = backdrop
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("fff0d9")
	sky.ambient_light_energy = 0.68
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
	fill.light_energy = 0.22
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.05
	camera.far = 75.0
	add_child(camera)
	camera.current = true
	park = Park.new()
	park.name = "SakuraPark"
	add_child(park)

func _update_camera() -> void:
	camera.position = Vector3(0.0, framing + 0.10, zoom)
	camera.look_at(Vector3(0.0, framing, 0.0))

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
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
	scroll.add_child(box)
	box.add_child(_label("Performance & presentation", 18))
	state_select = OptionButton.new()
	for item in ["Auto · 0", "Idle · 1", "Listening · 2", "Thinking · 3", "Talking · 4", "Sleeping · 5"]:
		state_select.add_item(item)
	state_select.item_selected.connect(_select_state)
	box.add_child(state_select)
	var quality_select: OptionButton = OptionButton.new()
	quality_select.add_item("Graphics: lightweight · no AA")
	quality_select.add_item("Graphics: standard · 2× AA")
	quality_select.select(quality)
	quality_select.item_selected.connect(func(index: int): quality = index; _apply_quality(); _save())
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
	var gesture_select: OptionButton = OptionButton.new()
	for item in ["Wave", "Stretch", "Look around", "Adjust posture"]:
		gesture_select.add_item(item)
	box.add_child(gesture_select)
	var gesture_button: Button = Button.new()
	gesture_button.text = "Preview idle gesture"
	gesture_button.pressed.connect(func():
		_select_state(1)
		character.set_state(Character.State.IDLE)
		character.play_gesture(["wave", "stretch", "inspect", "settle"][gesture_select.selected])
	)
	box.add_child(gesture_button)
	_slider(box, "Camera distance", 1.6, 4.0, 0.05, zoom, func(value: float): zoom = value; _update_camera(); _save())
	_slider(box, "Camera height", 0.7, 1.5, 0.02, framing, func(value: float): framing = value; _update_camera(); _save())
	_slider(box, "Lighting", 0.25, 2.0, 0.05, light_energy, func(value: float): light_energy = value; light.light_energy = value; _save())
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

func _slider(box: VBoxContainer, title: String, minimum: float, maximum: float, step: float, value: float, changed: Callable) -> void:
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

func _save() -> void:
	settings.set_value("display", "fps", fps_limit)
	settings.set_value("display", "distance", zoom)
	settings.set_value("display", "height", framing)
	settings.set_value("display", "light", light_energy)
	settings.set_value("display", "quality", quality)
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
	var voice_active: bool = bridge.state.get("voice", "unknown") == "active"
	var audio_fresh: bool = bool(bridge.state.get("capturing", false)) and (voice_active or manual_state == Character.State.TALKING)
	var rms: float = float(bridge.state.get("rms", 0.0))
	if demo:
		audio_fresh = true
		rms = (sin(elapsed * 9.0) * 0.5 + 0.5) * 0.15
	character.mouth = envelope.update(rms, audio_fresh, delta)
	var next: int = manual_state
	if next < 0:
		next = Character.State.TALKING if envelope.speaking else (Character.State.LISTENING if voice_active else Character.State.IDLE)
	character.set_state(next as Character.State)
	performance.fps_limit = fps_limit
	Engine.max_fps = performance.frame_cap(character.motion.is_resting())
	var hidden: bool = not performance.focused or performance.minimized
	park.suspended = hidden
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
	connection_label.text = "VOICE " + str(bridge.state.get("voice", "unknown")).to_upper() + ("  ·  Browser connected" if connected else "  ·  Manual controls available")
	detail_label.text = str(bridge.state.get("error", ""))
	voice_button.text = "Waiting for browser…" if bridge.state.get("pending", false) else "Toggle Voice · " + ("F8" if voice_key == KEY_F8 else "F9")
	voice_button.disabled = not connected or bool(bridge.state.get("pending", false))
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
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality == 0 or performance.low_power else Viewport.MSAA_2X

func _apply_performance_settings() -> void:
	if character != null:
		character.animation_intensity = animation_intensity
		character.low_power = performance.low_power
	if park != null:
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
