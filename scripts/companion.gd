extends Node3D
## Presentation only: ChatGPT owns the conversation and personality.
const Character = preload("res://scripts/character_controller.gd")
const Envelope = preload("res://scripts/audio_envelope.gd")
const Bridge = preload("res://scripts/bridge_client.gd")

var character: AisoraCharacter
var envelope: AisoraAudioEnvelope = Envelope.new()
var bridge: AisoraBridgeClient
var camera: Camera3D
var light: DirectionalLight3D
var settings: ConfigFile = ConfigFile.new()
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

func _ready() -> void:
	settings.load("user://settings.cfg")
	fps_limit = clampi(int(settings.get_value("display", "fps", 30)), 15, 60)
	zoom = clampf(float(settings.get_value("display", "distance", 3.2)), 1.6, 4.0)
	framing = clampf(float(settings.get_value("display", "height", 0.86)), 0.7, 1.5)
	light_energy = clampf(float(settings.get_value("display", "light", 1.0)), 0.25, 2.0)
	envelope.gain = clampf(float(settings.get_value("audio", "gain", 5.0)), 1.0, 15.0)
	envelope.noise_gate = clampf(float(settings.get_value("audio", "gate", 0.012)), 0.001, 0.08)
	voice_key = KEY_F8 if int(settings.get_value("controls", "voice_key", KEY_F8)) != KEY_F9 else KEY_F9
	quality = clampi(int(settings.get_value("display", "quality", 0)), 0, 1)
	_apply_quality()
	_build_stage()
	character = Character.new()
	add_child(character)
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
	sky.ambient_light_color = Color("b5c8ed")
	sky.ambient_light_energy = 0.65
	sky.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = sky
	add_child(environment)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-24.0, -28.0, 0.0)
	light.light_color = Color("fff0e3")
	light.light_energy = light_energy
	light.shadow_enabled = false
	add_child(light)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 145.0, 0.0)
	fill.light_color = Color("8daeff")
	fill.light_energy = 0.4
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.05
	camera.far = 25.0
	add_child(camera)
	camera.current = true
	# A matte disc; no real-time shadows or post effects.
	var stage: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.57
	disc.bottom_radius = 0.59
	disc.height = 0.025
	disc.radial_segments = 64
	stage.mesh = disc
	var disc_material: StandardMaterial3D = StandardMaterial3D.new()
	disc_material.albedo_color = Color("253c56")
	disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stage.material_override = disc_material
	stage.position.y = -0.014
	add_child(stage)

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
	var title: Label = _label("A I S O R A", 28)
	brand.add_child(title)
	brand.add_child(_label("YOUR LITTLE CORNER OF THE SKY", 11, Color("8aa2bc")))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var controls: VBoxContainer = VBoxContainer.new()
	row.add_child(controls)
	state_label = _label("IDLE", 18, Color("9fdbc9"))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(state_label)
	var settings_button: Button = Button.new()
	settings_button.text = "Settings  ·  Tab"
	settings_button.pressed.connect(func(): settings_panel.visible = not settings_panel.visible)
	controls.add_child(settings_button)
	var bottom: MarginContainer = MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -136
	bottom.add_theme_constant_override("margin_left", 32)
	bottom.add_theme_constant_override("margin_right", 32)
	bottom.add_theme_constant_override("margin_bottom", 18)
	root.add_child(bottom)
	var bottom_box: VBoxContainer = VBoxContainer.new()
	bottom.add_child(bottom_box)
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
	settings_panel.offset_left = -334
	settings_panel.offset_right = -24
	settings_panel.offset_top = -220
	settings_panel.offset_bottom = 220
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
	box.add_child(_label("Make yourself comfortable", 18))
	state_select = OptionButton.new()
	for item in ["Auto · 0", "Idle · 1", "Listening · 2", "Thinking · 3", "Talking · 4", "Sleeping · 5"]:
		state_select.add_item(item)
	state_select.item_selected.connect(_select_state)
	box.add_child(state_select)
	var quality_select: OptionButton = OptionButton.new()
	quality_select.add_item("Low power · no antialiasing")
	quality_select.add_item("Standard · 2× antialiasing")
	quality_select.select(quality)
	quality_select.item_selected.connect(func(index: int): quality = index; _apply_quality(); _save())
	box.add_child(quality_select)
	_slider(box, "Camera distance", 1.6, 4.0, 0.05, zoom, func(value: float): zoom = value; _update_camera(); _save())
	_slider(box, "Camera height", 0.7, 1.5, 0.02, framing, func(value: float): framing = value; _update_camera(); _save())
	_slider(box, "Lighting", 0.25, 2.0, 0.05, light_energy, func(value: float): light_energy = value; light.light_energy = value; _save())
	_slider(box, "Active FPS cap", 15, 60, 5, fps_limit, func(value: float): fps_limit = int(value); _save())
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
	box.add_child(_label(title, 13))
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(changed)
	box.add_child(slider)

func _save() -> void:
	settings.set_value("display", "fps", fps_limit)
	settings.set_value("display", "distance", zoom)
	settings.set_value("display", "height", framing)
	settings.set_value("display", "light", light_energy)
	settings.set_value("display", "quality", quality)
	settings.set_value("audio", "gain", envelope.gain)
	settings.set_value("audio", "gate", envelope.noise_gate)
	settings.set_value("controls", "voice_key", voice_key)
	settings.save("user://settings.cfg")

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
	Engine.max_fps = mini(fps_limit, 10 if next == Character.State.SLEEPING else (20 if next == Character.State.IDLE else fps_limit))
	ui_elapsed += delta
	if ui_elapsed < 0.2:
		return
	ui_elapsed = 0.0
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
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
