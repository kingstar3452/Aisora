extends Node3D
## Presentation only: ChatGPT owns the conversation and personality.
const Personality=preload("res://scripts/personality.gd")
const Behavior=preload("res://scripts/behavior_scheduler.gd")
const Character = preload("res://scripts/character_controller.gd")
const Envelope = preload("res://scripts/audio_envelope.gd")
const Bridge = preload("res://scripts/bridge_client.gd")
const Park = preload("res://scripts/sakura_park.gd")
const PerformancePolicy = preload("res://scripts/performance_policy.gd")
const ActionCatalog = preload("res://scripts/action_catalog.gd")
const IllustratedPark = preload("res://scripts/illustrated_park.gd")
const GroundGuide=preload("res://scripts/ground_guide.gd")
const AmbientAudio=preload("res://scripts/ambient_audio.gd")
const ReducedRenderer=preload("res://scripts/character_renderer.gd")
const AdaptiveQuality=preload("res://scripts/adaptive_quality.gd")
const WorldCycle = preload("res://scripts/world_cycle.gd")
const FrameDiagnostics = preload("res://scripts/frame_diagnostics.gd")
const UpdateClient=preload("res://scripts/update_client.gd")
const UpdatePanel=preload("res://scripts/update_panel.gd")
const Autonomy=preload("res://scripts/autonomy.gd")
const MouseAwareness=preload("res://scripts/mouse_awareness.gd")
var autonomy: AisoraAutonomy=Autonomy.new()
var mouse_awareness: AisoraMouseAwareness=MouseAwareness.new()
var autonomy_status: Label
var autonomy_text: Label
var _autonomy_text_seconds: float=0.
var _autonomy_clock: float=0.

const BackgroundBudget=preload("res://scripts/background_budget.gd")

var updater: AisoraUpdateClient
var background_budget: AisoraBackgroundBudget=BackgroundBudget.new()
var face_clarity: bool=true
var voice_face_detail: bool=true
var _conversation_detail: bool=false
var _face_clock: float=0.

var _rest_camera_active: bool=false
var _rest_camera_base: Transform3D
var behavior: AisoraBehaviorScheduler=Behavior.new()
var personality_intensity: float=.55
var personality_weights: Dictionary=Personality.WEIGHTS.duplicate()
var last_personality: String=""
var behavior_status: Label
var full_body_toggle: CheckButton
var seat_height_slider: HSlider
var ground_guide: AisoraGroundGuide
var show_ground_guide: bool=false
var ambience: AisoraAmbientAudio
var ambience_level: float=0.
var ground_auto: bool=false
var _ground_wait: float=120.
var _was_stepping: bool=false
var ground_regions: Dictionary={}
var ground_status: Label
var ground_width_slider: HSlider
var ground_depth_slider: HSlider
var ground_calibration: CheckButton
var night_rest: bool=false
var rest_after: float=180.
var _idle_duration: float=0.
var _morning_stretch: bool=false
var _behavior_period: String=""
var reduced_renderer: AisoraCharacterRenderer
var render_scale: float=1.
var adaptive: AisoraAdaptiveQuality=AdaptiveQuality.new()
var cycle: AisoraWorldCycle=WorldCycle.new()
var _world_pending: bool=false
var _world_clock: float=1.0
var _lighting_clock: float=0.0
var _lighting_dirty: bool=true
var time_status: Label
var time_override_select: OptionButton
var slot_status_labels: Dictionary={}
var legacy_sunset_path: String=""
var _choose_time_slot: String="sunset"
var clean_toggle: CheckButton
var clean_presentation: bool=false
var settings_button: Button
var character_brightness: float=1.0
var character_contrast: float=1.0
var color_matching: bool=true
var weather_mode: String="clear"
var weather_strength: float=.5
var weather_rain: bool=true
var weather_clouds: bool=true
var weather_fog: bool=true
var night_effects: bool=false
var shadow_opacity: float=.65
var shadow_softness: float=1.
var branches_toggle: CheckButton
var decorative_branches: bool=false
var reduced_detail: bool=true
var character: AisoraCharacter
var envelope: AisoraAudioEnvelope = Envelope.new()
var bridge: AisoraBridgeClient
var camera: Camera3D
var light: DirectionalLight3D
var settings: ConfigFile = ConfigFile.new()
var settings_backup_path: String=""
var _settings_writable: bool=true
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
	autonomy.load_settings(settings)
	autonomy.state_changed.connect(_save)
	autonomy.dialogue_requested.connect(_autonomy_event)
	_backup_phase5_settings()
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
	_load_world_settings()
	_apply_quality()
	_build_stage()
	character = Character.new()
	add_child(character)
	character.ground.turn_degrees=clampf(float(settings.get_value("ground","turn_degrees",25.)),15.,90.)
	reduced_renderer=ReducedRenderer.new();add_child(reduced_renderer);reduced_renderer.setup(camera)
	_apply_performance_settings()
	ambience=AmbientAudio.new();add_child(ambience);ambience.level=ambience_level
	bridge = Bridge.new()
	bridge.pairing_path=str(settings.get_value("bridge","pairing_path",""))
	add_child(bridge)
	updater=UpdateClient.new()
	updater.voice_guard=func():return _voice_blocks_update()
	updater.bridge_path=func():return _update_bridge_path()
	updater.health_guard=func():return character!=null and character.skeleton!=null and is_instance_valid(settings_panel) and Engine.get_frames_drawn()>30
	updater.quit_for_update.connect(func():_save();get_tree().quit())
	add_child(updater)
	var guide_layer: CanvasLayer=CanvasLayer.new();guide_layer.layer=5;add_child(guide_layer)
	ground_guide=GroundGuide.new();guide_layer.add_child(ground_guide);ground_guide.visible=false
	_build_ui()
	_update_camera()
	_apply_stage_mode()
	get_viewport().size_changed.connect(_place_character)
	get_window().mouse_exited.connect(mouse_awareness.reset)
	get_viewport().size_changed.connect(_update_ground_guide)
	illustrated.scenery_changed.connect(_world_image_changed)
	_update_world(true)
	_apply_world_lighting()
	ui_layer.visible=not clean_presentation
	# Save only references for migration, never rewrite the existing sunset bitmap.
	if settings.has_section_key("environment","background_path") and not settings.has_section_key("world","slot_paths"):_save()

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
	var saved_paths: Variant=settings.get_value("world","slot_paths",{})
	illustrated.slot_paths=WorldCycle.BUNDLED.duplicate()
	if saved_paths is Dictionary:illustrated.slot_paths.merge(saved_paths,true)
	legacy_sunset_path=str(settings.get_value("world","alternative_sunset",str(settings.get_value("environment","background_path",""))))
	if not FileAccess.file_exists(str(illustrated.slot_paths.get("sunset",""))) and not legacy_sunset_path.is_empty():illustrated.slot_paths.sunset=legacy_sunset_path
	illustrated.displayed_slot=str(settings.get_value("world","displayed_slot","sunset"))
	illustrated.foreground_path = str(settings.get_value("environment","foreground_path",""))
	add_child(illustrated)

func _update_camera() -> void:
	if character!=null and (character.ground.active or character.body.active):return
	camera.position = Vector3(0.0, framing + 0.10, zoom)
	camera.look_at(Vector3(0.0, framing, 0.0))
	_place_character()
	if reduced_renderer!=null:reduced_renderer.sync_camera()
	_update_ground_guide()

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
	settings_button=Button.new();settings_button.text="Settings · Tab"
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);settings_button.position=Vector2(-170,18);settings_button.size=Vector2(150,34)
	settings_button.pressed.connect(_toggle_settings);root.add_child(settings_button)
	state_label=_label("IDLE",16)
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
	bottom_box.add_child(state_label)
	connection_label = _label("Manual Voice available", 13)
	connection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	bottom_box.add_child(connection_label)
	detail_label = _label("", 13, Color("8aa2bc"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_box.add_child(detail_label)
	var action_row: VBoxContainer = VBoxContainer.new()
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
	autonomy_text=_label("",16)
	autonomy_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	autonomy_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	autonomy_text.offset_left=24;autonomy_text.offset_right=-24;autonomy_text.offset_top=-80;autonomy_text.offset_bottom=-16
	autonomy_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(autonomy_text)
	_build_settings(root)
	# Technical status lives inside the collapsed settings, never over the normal scene.
	var settings_box: VBoxContainer=settings_panel.get_child(0).get_child(0)
	footer_panel.reparent(settings_box);settings_box.move_child(footer_panel,1);bottom.queue_free()

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
	var updates: VBoxContainer=UpdatePanel.new();updates.client=updater;box.add_child(updates)
	_check(box,"Clear face and mouth lighting",face_clarity,func(on: bool):face_clarity=on;character.set_face_clarity(on);_save())
	_check(box,"Protect face resolution during Voice",voice_face_detail,func(on: bool):voice_face_detail=on;_configure_character_renderer();_save())
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
	_build_world_settings(box)
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
Use the Phase 6 controls below for calibrated walking, seat/floor rest and personality poses. Unrestricted roaming and 360° turns remain unsupported.",12,Color("b9c8d9"))
	action_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(action_status)
	_build_autonomy_settings(box)
	_build_ground_settings(box)
	_build_scenery_settings(box,root)
	_slider(box, "Camera distance", 1.6, 4.0, 0.05, zoom, func(value: float): zoom = value; _update_camera(); _save())
	_slider(box, "Camera height", 0.7, 1.5, 0.02, framing, func(value: float): framing = value; _update_camera(); _save())
	_slider(box, "Lighting", 0.25, 2.0, 0.05, light_energy, func(value: float): light_energy = value; character.set_lighting(value); _lighting_dirty=true; _apply_world_lighting(); _save())
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
	slider.set_meta("caption",caption);slider.set_meta("title",title)
	box.add_child(slider)
	return slider

func _save() -> void:
	if not _settings_writable:return
	autonomy.save_settings(settings)
	settings.set_value("phase6","version",1)
	settings.set_value("behavior","enabled",behavior.enabled);settings.set_value("behavior","interval_min",behavior.interval_min);settings.set_value("behavior","interval_max",behavior.interval_max);settings.set_value("behavior","weights",behavior.weights)
	settings.set_value("personality","intensity",personality_intensity);settings.set_value("personality","weights",personality_weights)
	settings.set_value("world","ambience",ambience_level)
	settings.set_value("ground","automatic",ground_auto)
	settings.set_value("ground","regions",ground_regions)
	settings.set_value("world","night_rest",night_rest);settings.set_value("world","rest_after",rest_after)
	settings.set_value("world","alternative_sunset",legacy_sunset_path)
	settings.set_value("world","slot_paths",illustrated.slot_paths)
	settings.set_value("world","displayed_slot",illustrated.displayed_slot)
	settings.set_value("world","override",cycle.override_slot)
	settings.set_value("world","boundaries",cycle.boundaries)
	settings.set_value("world","fade_seconds",cycle.transition_seconds)
	settings.set_value("world","weather",weather_mode)
	settings.set_value("world","weather_strength",weather_strength)
	settings.set_value("world","rain",weather_rain);settings.set_value("world","clouds",weather_clouds);settings.set_value("world","fog",weather_fog)
	settings.set_value("world","night_effects",night_effects)
	settings.set_value("world","brightness",character_brightness);settings.set_value("world","contrast",character_contrast);settings.set_value("world","color_matching",color_matching)
	settings.set_value("world","shadow_opacity",shadow_opacity);settings.set_value("world","shadow_softness",shadow_softness);settings.set_value("world","branches",decorative_branches)
	settings.set_value("display","clean",clean_presentation)
	settings.set_value("performance","reduced_detail",reduced_detail)
	settings.set_value("performance","render_scale",render_scale);settings.set_value("performance","adaptive",adaptive.enabled)
	settings.set_value("performance","face_clarity",face_clarity);settings.set_value("performance","voice_face_detail",voice_face_detail)
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
	_world_clock+=delta;_lighting_clock+=delta
	if _world_clock>=1.0:_world_clock=0.;_update_world()
	if _lighting_clock>=.1:
		_lighting_clock=0.
		if _lighting_dirty or illustrated.fade_progress<1.:_apply_world_lighting()
	diagnostics.record(delta)
	_diagnostic_clock += delta
	if diagnostics_visible and _diagnostic_clock >= 0.5:
		_diagnostic_clock = 0.0
		var stats: Dictionary = diagnostics.snapshot()
		diagnostics_label.text = "%.1f FPS · %.1f ms / frame\nP95 %.1f · P99 %.1f ms · Engine process %.2f ms\n%d draw calls · cap %d · %s" % [stats.fps,stats.mean_ms,stats.p95_ms,stats.p99_ms,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Engine.max_fps,["Low","Balanced","High"][quality]]+"\n3D %s · %d%% · %s"%[str(reduced_renderer.viewport.size) if reduced_renderer.active else "native",roundi((reduced_renderer.scale_factor if reduced_renderer.active else 1.)*100),"adaptive" if adaptive.enabled else "manual"]
	var voice_active: bool = bridge.state.get("voice", "unknown") == "active"
	var audio_fresh: bool = bool(bridge.state.get("capturing", false)) and (voice_active or manual_state == Character.State.TALKING)
	var rms: float = float(bridge.state.get("rms", 0.0))
	if demo:
		audio_fresh = true
		rms = (sin(elapsed * 9.0) * 0.5 + 0.5) * 0.15
	character.mouth = envelope.update(rms, audio_fresh, delta)
	character.motion.conversation_active=voice_active or bridge.session_may_be_active or bridge.command_pending() or envelope.speaking or manual_state in [1,2,3]
	_update_autonomy(delta)
	ambience.advance(illustrated.displayed_slot,weather_mode,character.motion.conversation_active,delta)
	character.ground.paused=character.motion.conversation_active
	_update_rest_camera()
	if _was_stepping and not character.ground.active and not character.body.active:
		_update_camera();_world_pending=true
		if ground_status!=null:ground_status.text=character.ground.message
	_was_stepping=character.ground.active or character.body.active
	_ground_wait-=delta
	if ground_auto and not behavior.enabled and character.ground.calibrated and not _world_pending and not character.body.active and _ground_wait<=0. and _idle_duration>60. and manual_state<0 and character.state==Character.State.IDLE and not character.motion.conversation_active and character.motion.gesture.is_empty() and illustrated.displayed_slot in ["morning","daytime"] and illustrated.fade_progress>=1. and illustrated._worker==null:
		if character.ground.play("pace",character):_ground_wait=character.rng.randf_range(120.,240.)
	_idle_duration=0. if character.motion.conversation_active or manual_state>=0 else _idle_duration+delta
	var next: int = manual_state
	if next < 0:
		next = Character.State.TALKING if envelope.speaking else ((Character.State.THINKING if bridge.state.get("activity","")=="thinking" else Character.State.LISTENING) if voice_active else Character.State.IDLE)
	if manual_state<0 and not character.body.active and not character.motion.conversation_active and night_rest and illustrated.displayed_slot=="nighttime" and _idle_duration>=rest_after:next=Character.State.SLEEPING
	character.set_state(next as Character.State)
	if _morning_stretch and next==Character.State.IDLE and not character.motion.conversation_active and character.motion.sleep_amount<.01 and character.motion.gesture.is_empty() and not character.ground.active:
		character.play_gesture("stretch");_morning_stretch=false
	if character.ground.active or character.body.active:
		illustrated.character_anchor=camera.unproject_position(character.ground.shadow_position() if character.ground.active else character.body.origin)/get_viewport().get_visible_rect().size;illustrated.update_character_shadow()
	if behavior.enabled:
		var behavior_action: String=behavior.tick(delta,{"voice":character.motion.conversation_active,"ready":manual_state<0 and character.state==Character.State.IDLE and not _world_pending and not character.ground.active and not character.body.active and character.motion.gesture.is_empty() and illustrated.fade_progress>=1. and illustrated._worker==null and performance.focused and not performance.minimized,"ground":character.ground.calibrated,"rest":character.body.enabled,"period":cycle.local_slot()})
		if not behavior_action.is_empty():_perform_behavior(behavior_action)
	performance.fps_limit = fps_limit
	Engine.max_fps = performance.frame_cap(character.motion.is_resting(),character.motion.conversation_active)
	var hidden: bool = not performance.focused or performance.minimized
	park.suspended = hidden or stage_mode==0
	illustrated.suspended = hidden
	character.backgrounded = hidden
	var conversation_detail: bool=voice_face_detail and character.motion.conversation_active
	if reduced_renderer!=null and (reduced_renderer.minimized!=performance.minimized or _conversation_detail!=conversation_detail):_configure_character_renderer()
	var eligible: bool=not hidden and not settings_panel.visible and not character.motion.is_resting() and illustrated.fade_progress>=1. and illustrated._worker==null
	background_budget.observe(delta,Engine.max_fps,adaptive.enabled and eligible)
	illustrated.set_effect_budget(minf(background_budget.factor,.5 if character.motion.conversation_active else 1.))
	if adaptive.observe(delta,Engine.max_fps,eligible and background_budget.factor<=0. and not conversation_detail):_configure_character_renderer()
	_face_clock+=delta
	if _face_clock>=.1:_face_clock=0.;_update_face_clearance()
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
	var message: String=str(bridge.state.get("error",""))
	settings_button.tooltip_text=message;settings_button.text="Settings · issue" if not message.is_empty() else "Settings · Tab"
	if not settings_panel.visible:return
	var activity: String = "minimized" if performance.minimized else ("inactive" if not performance.focused else "foreground")
	performance_label.text = "%d FPS cap · %s" % [Engine.max_fps, activity]
	state_label.text = Character.STATE_NAMES[character.state] + (" · Full-body " + character.body.desired.replace("_", " ") if character.body.active else "") + ("  ·  TEST" if manual_state >= 0 or demo else "")
	var connected: bool = bool(bridge.state.get("connected", false))
	connection_label.text=("Bridge online" if bridge.age<1.5 else "Bridge offline")+(" · Browser connected" if connected else " · Browser disconnected")+" · Voice "+str(bridge.state.get("voice","unknown"))
	connection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not str(bridge.state.get("project_label","")).is_empty():connection_label.text+=" · Project "+str(bridge.state.project_label)+" (user-selected)"
	detail_label.text = str(bridge.state.get("error", ""))
	settings_button.tooltip_text=detail_label.text
	settings_button.text="Settings · issue" if not detail_label.text.is_empty() else "Settings · Tab"
	voice_button.text = "Waiting for browser…" if bridge.state.get("pending", false) else "Toggle Voice · " + ("F8" if voice_key == KEY_F8 else "F9")
	voice_button.disabled = not connected or bridge.command_pending()
	for button: Button in explicit_voice_buttons:button.disabled=voice_button.disabled
	audio_label.text = "TEST AMPLITUDE" if demo else ("Tab output: %.0f%%" % [envelope.mouth * 100.0] if audio_fresh else "Tab output: off / silent")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var focused: Control=get_viewport().gui_get_focus_owner()
	if (focused is LineEdit or focused is TextEdit) and event.keycode not in [voice_key,KEY_F3,KEY_F11,KEY_ESCAPE]:return
	if event.keycode == voice_key:
		bridge.toggle_voice()
	elif event.keycode >= KEY_0 and event.keycode <= KEY_5:
		_select_state(event.keycode - KEY_0)
	elif event.keycode == KEY_TAB:
		_toggle_settings()
	elif event.keycode == KEY_F3:
		diagnostics_visible = not diagnostics_visible
		diagnostics_label.visible = diagnostics_visible
		diagnostics_toggle.set_pressed_no_signal(diagnostics_visible)
		_save()
	elif event.keycode == KEY_H:
		_set_clean(not clean_presentation)
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
	background_budget.reset()
	get_viewport().msaa_3d = Viewport.MSAA_2X if quality == 2 and not performance.low_power else Viewport.MSAA_DISABLED
	if character != null:
		character.set_visual_quality(0 if performance.low_power else quality)
		character.set_lighting(light_energy)

func _apply_performance_settings() -> void:
	_configure_character_renderer()
	if character != null:
		character.set_face_clarity(face_clarity)
		character.motion.personality_intensity=personality_intensity
		character.motion.set_context(illustrated.displayed_slot if illustrated!=null else "sunset",weather_mode)
		character.motion.configure_scheduler(idle_interval_min,idle_interval_max,scheduler_enabled,action_weights)
		character.animation_intensity = animation_intensity
		character.low_power = performance.low_power
		character.set_visual_quality(0 if performance.low_power else quality)
		character.set_detail_reduction(reduced_detail)
		character.set_lighting(light_energy)
	if illustrated != null:
		illustrated.quality=quality;illustrated.low_power=performance.low_power
		illustrated.intensity=environment_intensity;illustrated.density=petal_density;illustrated.parallax=parallax_enabled
		illustrated.show_branches=decorative_branches
		illustrated.shadow_opacity=shadow_opacity;illustrated.shadow_softness=shadow_softness
		illustrated.weather.mode=weather_mode;illustrated.weather.strength=weather_strength
		illustrated.weather.rain_enabled=weather_rain;illustrated.weather.clouds_enabled=weather_clouds;illustrated.weather.fog_enabled=weather_fog
		illustrated.weather.night_effects=night_effects;illustrated.weather.nighttime=illustrated.displayed_slot=="nighttime" and not illustrated.displayed_path.is_empty()
		illustrated.apply_performance()
		illustrated.petals.material.set_shader_parameter("wind",2.5 if weather_mode=="windy" else 1.0)
		_lighting_dirty=true
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
	_configure_character_renderer()
	illustrated.enabled=stage_mode==0
	illustrated.apply_performance()
	_place_character()

func _place_character() -> void:
	if character!=null and (character.ground.active or character.body.active):return
	if character==null or camera==null or illustrated==null:return
	character.scale=Vector3.ONE*(character_scale if stage_mode==0 else 1.0)
	character.position=Vector3.ZERO
	if stage_mode==0:
		var pixel: Vector2=get_viewport().get_visible_rect().size*character_anchor
		var origin: Vector3=camera.project_ray_origin(pixel)
		var direction: Vector3=camera.project_ray_normal(pixel)
		if absf(direction.z)>0.001:character.position=origin-direction*(origin.z/direction.z)
	illustrated.character_anchor=character_anchor;illustrated.character_scale=character_scale;illustrated.resize()
	if character.ground!=null and not character.ground.active and not character.body.active:character.ground.reset_origin(character)

func _image_selected(path: String) -> void:
	var loaded: bool=illustrated.load_local(path,true) if _choose_overlay else illustrated.assign_time_image(_choose_time_slot,path)
	if loaded:
		if _choose_overlay:
			decorative_branches=true
			if branches_toggle!=null:branches_toggle.set_pressed_no_signal(true)
		stage_mode=0;_apply_stage_mode();_update_world(true);_save()
	image_status.text=illustrated.message
	_refresh_world_labels()

func _build_scenery_settings(box: VBoxContainer, root: Control) -> void:
	box.add_child(_label("Illustrated scenery",18))
	var scenery_select: OptionButton = OptionButton.new()
	scenery_select.add_item("Illustrated background + 3D Aisora")
	scenery_select.add_item("Original 3D park fallback")
	scenery_select.select(stage_mode)
	scenery_select.item_selected.connect(func(index: int):
		if character.ground.active or character.body.active:scenery_select.select(stage_mode);return
		stage_mode=index;_apply_stage_mode();_save()
	)
	box.add_child(scenery_select)
	image_status = _label(illustrated.message,12,Color("a8d4c5"))
	image_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(image_status)
	for overlay: bool in [false,true]:
		var choose: Button=Button.new()
		choose.text="Choose transparent foreground…" if overlay else "Choose sunset park image…"
		choose.pressed.connect(func(): _choose_overlay=overlay; _choose_time_slot="sunset"; image_dialog.popup_centered_ratio(0.7))
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
	if character.ground.active or character.body.active or bridge.state.get("voice","")=="active" or bridge.session_may_be_active or bridge.command_pending() or envelope.speaking:
		action_status.text="Action preview paused during Voice. Your conversation keeps control."
		return false
	_select_state(1);character.set_state(Character.State.IDLE);character.motion.conversation_active=false
	var ok: bool=character.play_gesture(name)
	action_status.text="Preview: "+name.replace("_"," ") if ok else "This action is unavailable."
	return ok

func _load_world_settings() -> void:
	behavior.enabled=bool(settings.get_value("behavior","enabled",false));behavior.interval_min=clampf(float(settings.get_value("behavior","interval_min",45.)),15.,300.);behavior.interval_max=clampf(float(settings.get_value("behavior","interval_max",120.)),behavior.interval_min,600.)
	var saved_behavior: Variant=settings.get_value("behavior","weights",{})
	if saved_behavior is Dictionary:behavior.weights.merge(saved_behavior,true)
	var saved_personality: Variant=settings.get_value("personality","weights",{})
	if saved_personality is Dictionary:personality_weights.merge(saved_personality,true)
	personality_intensity=clampf(float(settings.get_value("personality","intensity",.55)),0.,1.)
	ambience_level=clampf(float(settings.get_value("world","ambience",0.)),0,.25)
	ground_auto=bool(settings.get_value("ground","automatic",false))
	ground_regions=settings.get_value("ground","regions",{}).duplicate() if settings.get_value("ground","regions",{}) is Dictionary else {}
	night_rest=bool(settings.get_value("world","night_rest",false));rest_after=clampf(float(settings.get_value("world","rest_after",180.)),30.,1800.)
	cycle.override_slot=str(settings.get_value("world","override",""))
	if cycle.override_slot not in WorldCycle.SLOTS:cycle.override_slot=""
	var boundaries_value: Variant=settings.get_value("world","boundaries",cycle.boundaries)
	if boundaries_value is PackedInt32Array:cycle.set_boundaries(boundaries_value)
	cycle.transition_seconds=clampf(float(settings.get_value("world","fade_seconds",8.)),.2,30.)
	clean_presentation=bool(settings.get_value("display","clean",false))
	character_brightness=clampf(float(settings.get_value("world","brightness",1.)),.5,1.5)
	character_contrast=clampf(float(settings.get_value("world","contrast",1.)),.7,1.3)
	color_matching=bool(settings.get_value("world","color_matching",true))
	weather_mode=str(settings.get_value("world","weather","clear"))
	if weather_mode not in illustrated_weather_modes():weather_mode="clear"
	weather_strength=clampf(float(settings.get_value("world","weather_strength",.5)),0,1)
	weather_rain=bool(settings.get_value("world","rain",true));weather_clouds=bool(settings.get_value("world","clouds",true));weather_fog=bool(settings.get_value("world","fog",true))
	night_effects=bool(settings.get_value("world","night_effects",false))
	shadow_opacity=clampf(float(settings.get_value("world","shadow_opacity",.65)),0,1);shadow_softness=clampf(float(settings.get_value("world","shadow_softness",1.)),.25,1.25)
	decorative_branches=bool(settings.get_value("world","branches",not str(settings.get_value("environment","foreground_path","")).is_empty()));reduced_detail=bool(settings.get_value("performance","reduced_detail",true))
	render_scale=clampf(float(settings.get_value("performance","render_scale",1.)),.5,1.)
	adaptive.enabled=bool(settings.get_value("performance","adaptive",false));adaptive.reset(render_scale)
	face_clarity=bool(settings.get_value("performance","face_clarity",true))
	voice_face_detail=bool(settings.get_value("performance","voice_face_detail",true))

func _voice_blocks_update() -> bool:
	return bridge!=null and (bridge.state.get("voice","")=="active" or bridge.session_may_be_active or bridge.command_pending() or envelope.speaking or (character!=null and character.motion.conversation_active))

func _update_bridge_path() -> String:
	if bridge==null:return ""
	var path: String=bridge.pairing_path
	if path.is_empty():path=OS.get_environment("AISORA_BRIDGE_CONFIG")
	if path.is_empty() and FileAccess.file_exists("res://.local/bridge.json"):path="res://.local/bridge.json"
	return ProjectSettings.globalize_path(path) if not path.is_empty() else ""

func _configure_character_renderer() -> void:
	if reduced_renderer==null:return
	_conversation_detail=voice_face_detail and character!=null and character.motion.conversation_active
	reduced_renderer.conversation_detail=_conversation_detail
	reduced_renderer.max_edge=1920 if _conversation_detail else 1280
	reduced_renderer.configure(adaptive.effective_scale,stage_mode==0,performance.minimized)

func _update_face_clearance() -> void:
	if illustrated==null or character==null or camera==null:return
	if not face_clarity:
		illustrated.petals.material.set_shader_parameter("face_center",Vector2(-2.,-2.));return
	var head: int=int(character.bone_indices.get("Head",-1))
	if head<0:return
	var point: Vector3=character.skeleton.to_global(character.skeleton.get_bone_global_pose(head).origin)+Vector3(0,.025,.04)*character.scale.x
	var extent: Vector2=get_viewport().get_visible_rect().size
	var center: Vector2=camera.unproject_position(point)/extent
	var size_value: Vector2=(camera.unproject_position(point+Vector3(.12,.15,0)*character.scale.x)/extent-center).abs()
	illustrated.petals.material.set_shader_parameter("face_center",center)
	illustrated.petals.material.set_shader_parameter("face_radius",size_value.max(Vector2(.015,.025)))

func illustrated_weather_modes() -> Array[String]:return ["clear","cloudy","light_rain","heavy_rain","windy","misty"]

func _toggle_settings() -> void:
	if clean_presentation:_set_clean(false,false);settings_panel.visible=true
	else:settings_panel.visible=not settings_panel.visible
	_refresh_world_labels();_update_ground_guide()

func _set_clean(on: bool,save_value: bool=true) -> void:
	clean_presentation=on;ui_layer.visible=not on
	if on and get_viewport().gui_get_focus_owner()!=null:get_viewport().gui_get_focus_owner().release_focus()
	if clean_toggle!=null:clean_toggle.set_pressed_no_signal(on)
	_update_ground_guide()
	if save_value:_save()

func _update_world(force: bool=false) -> void:
	if illustrated==null:return
	var requested: String="rain" if weather_mode in ["light_rain","heavy_rain"] else cycle.local_slot()
	if character!=null and (character.ground.active or character.body.active):
		if character.body.active and (force or requested!=illustrated.requested_slot):character.body.play("stand",character)
		_world_pending=_world_pending or force or requested!=illustrated.requested_slot
		illustrated.message="Scene change waits for the current short step sequence to return home." if requested!=illustrated.requested_slot else illustrated.message
		_refresh_world_labels();return
	if stage_mode==0 and (force or _world_pending or requested!=illustrated.requested_slot):
		_world_pending=false
		illustrated.select_slot(requested,cycle.transition_seconds)
		_lighting_dirty=true
	_refresh_world_labels()

func _world_image_changed() -> void:
	_lighting_dirty=true
	if illustrated.fade_progress>=1.:
		if _behavior_period!="morning" and illustrated.displayed_slot=="morning":_morning_stretch=true
		_behavior_period=illustrated.displayed_slot
		character.motion.set_context(illustrated.displayed_slot,weather_mode)
		_load_ground_region()
		illustrated.weather.nighttime=illustrated.displayed_slot=="nighttime" and not illustrated.displayed_path.is_empty();illustrated.weather.apply()
	_refresh_world_labels();_save()

func _refresh_world_labels() -> void:
	if settings_panel!=null and not settings_panel.visible:return
	if time_status!=null:time_status.text=("Local clock" if cycle.override_slot.is_empty() else "Manual")+" · "+cycle.local_slot().capitalize()+"
"+illustrated.message
	if image_status!=null:image_status.text=illustrated.message
	for slot: String in slot_status_labels:
		slot_status_labels[slot].text=slot.capitalize()+": "+("assigned locally" if FileAccess.file_exists(str(illustrated.slot_paths.get(slot,""))) else "missing · existing image retained")

func _apply_world_lighting() -> void:
	if character==null:return
	var profile: Dictionary=illustrated.lighting_profile() if stage_mode==0 else {"color":Color("fff0e3"),"energy":1.,"ambient":.46}
	var tint: Color=profile.color if color_matching else Color.WHITE
	light.light_color=tint;light.light_energy=light_energy*profile.energy*character_brightness
	stage_environment.ambient_light_color=tint;stage_environment.ambient_light_energy=profile.ambient
	character.set_appearance(tint,profile.energy,character_brightness,character_contrast)
	if reduced_renderer!=null:reduced_renderer.sync_camera()
	_lighting_dirty=false

func _check(box: VBoxContainer,title: String,on: bool,changed: Callable) -> CheckButton:
	var check: CheckButton=CheckButton.new();check.text=title;check.button_pressed=on;check.add_theme_font_size_override("font_size",13);check.toggled.connect(changed);box.add_child(check);return check

func _build_world_settings(box: VBoxContainer) -> void:
	box.add_child(_label("Local time & image slots",18))
	time_status=_label("",12);time_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(time_status)
	time_override_select=OptionButton.new();time_override_select.add_item("Mac local clock · automatic")
	for label: String in WorldCycle.LABELS:time_override_select.add_item(label+" · manual")
	time_override_select.select(0 if cycle.override_slot.is_empty() else WorldCycle.SLOTS.find(cycle.override_slot)+1)
	time_override_select.item_selected.connect(func(index: int):cycle.override_slot="" if index==0 else WorldCycle.SLOTS[index-1];_update_world(true);_save());box.add_child(time_override_select)
	for slot: String in WorldCycle.IMAGE_SLOTS:
		var label: Label=_label("",12);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(label);slot_status_labels[slot]=label
		var choose: Button=Button.new();choose.text="Assign "+slot+" image…"
		choose.pressed.connect(func():_choose_overlay=false;_choose_time_slot=slot;image_dialog.popup_centered_ratio(.7));box.add_child(choose)
	if not legacy_sunset_path.is_empty():
		var alternative: Button=Button.new();alternative.text="Use previous local sunset"
		alternative.pressed.connect(func():
			if illustrated.assign_time_image("sunset",legacy_sunset_path,false):cycle.override_slot="sunset";time_override_select.select(3);_update_world(true);_save()
		);box.add_child(alternative)
	var supplied: Button=Button.new();supplied.text="Use supplied sunset image";supplied.disabled=not FileAccess.file_exists(WorldCycle.BUNDLED.sunset)
	supplied.pressed.connect(func():
		if illustrated.assign_time_image("sunset",WorldCycle.BUNDLED.sunset,false):cycle.override_slot="sunset";time_override_select.select(3);_update_world(true);_save()
	);box.add_child(supplied)
	for index in 4:
		var hour: SpinBox=SpinBox.new();hour.min_value=0;hour.max_value=23.5;hour.step=.5;hour.value=float(cycle.boundaries[index])/60.;hour.prefix=WorldCycle.LABELS[index]+" starts · ";hour.suffix=" h"
		hour.value_changed.connect(func(value: float):
			var candidate: PackedInt32Array=cycle.boundaries.duplicate();candidate[index]=roundi(value*60.)
			if not cycle.set_boundaries(candidate):hour.set_value_no_signal(float(cycle.boundaries[index])/60.)
			else:_update_world(true);_save()
		);box.add_child(hour)
	_slider(box,"Image crossfade (seconds)",.2,30,.2,cycle.transition_seconds,func(value: float):cycle.transition_seconds=value;_save())
	box.add_child(_label("Weather · separate transparent layers",16))
	var weather_select: OptionButton=OptionButton.new()
	for item: String in illustrated_weather_modes():weather_select.add_item(item.replace("_"," ").capitalize())
	weather_select.select(illustrated_weather_modes().find(weather_mode));weather_select.item_selected.connect(func(index: int):weather_mode=illustrated_weather_modes()[index];_apply_performance_settings();_save());box.add_child(weather_select)
	_slider(box,"Weather strength (0 = off)",0,1,.05,weather_strength,func(value: float):weather_strength=value;_apply_performance_settings();_save())
	_check(box,"Animated rain layer",weather_rain,func(on: bool):weather_rain=on;_apply_performance_settings();_save())
	_check(box,"Cloud layer",weather_clouds,func(on: bool):weather_clouds=on;_apply_performance_settings();_save())
	_check(box,"Mist layer",weather_fog,func(on: bool):weather_fog=on;_apply_performance_settings();_save())
	_check(box,"Night fireflies · optional",night_effects,func(on: bool):night_effects=on;_apply_performance_settings();_save())
	branches_toggle=_check(box,"Separate foreground / branch layer",decorative_branches,func(on: bool):decorative_branches=on;_apply_performance_settings();_save())
	_slider(box,"Quiet synthetic ambience (0 = off)",0,.25,.01,ambience_level,func(value: float):ambience_level=value;ambience.level=value;_save())
	box.add_child(_label("Character integration",16))
	_check(box,"Match character light to visible image",color_matching,func(on: bool):color_matching=on;_apply_world_lighting();_save())
	_slider(box,"Character brightness",.5,1.5,.05,character_brightness,func(value: float):character_brightness=value;_apply_world_lighting();_save())
	_slider(box,"Contrast · Low / Balanced",.7,1.3,.05,character_contrast,func(value: float):character_contrast=value;_apply_world_lighting();_save())
	_slider(box,"Contact shadow opacity",0,1,.05,shadow_opacity,func(value: float):shadow_opacity=value;_apply_performance_settings();_save())
	_slider(box,"Contact shadow softness",.25,1.25,.05,shadow_softness,func(value: float):shadow_softness=value;_apply_performance_settings();_save())
	_check(box,"Reduced body/hair detail · native LOD",reduced_detail,func(on: bool):reduced_detail=on;character.set_detail_reduction(on);_save())
	_slider(box,"3D render resolution (1 = native)",.5,1,.05,render_scale,func(value: float):render_scale=value;adaptive.reset(value);background_budget.reset();_configure_character_renderer();_save())
	_check(box,"Adapt background first, then 3D if slow",adaptive.enabled,func(on: bool):adaptive.enabled=on;adaptive.reset(render_scale);background_budget.reset();_configure_character_renderer();_save())
	clean_toggle=_check(box,"Clean presentation · H (Tab restores)",clean_presentation,func(on: bool):_set_clean(on))

func _load_ground_region() -> void:
	if character==null:return
	var region: Dictionary=ground_regions.get(illustrated.displayed_slot,{})
	character.ground.calibrated=bool(region.get("enabled",false)) and str(region.get("path",""))==illustrated.displayed_path and not illustrated.displayed_path.is_empty()
	character.ground.width=clampf(float(region.get("width",.8)),.6,4.);character.ground.depth=clampf(float(region.get("depth",.9)),.6,4.)
	character.body.enabled=character.ground.calibrated and bool(region.get("rest_enabled",false));character.body.seat_height=clampf(float(region.get("seat_height",.48)),.48,.60)
	if full_body_toggle!=null:full_body_toggle.set_pressed_no_signal(character.body.enabled)
	_sync_slider(seat_height_slider,character.body.seat_height)
	if ground_calibration!=null:ground_calibration.set_pressed_no_signal(character.ground.calibrated)
	_sync_slider(ground_width_slider,character.ground.width);_sync_slider(ground_depth_slider,character.ground.depth)
	_update_ground_guide()
	if ground_status!=null:ground_status.text=("Calibrated for "+illustrated.displayed_slot if character.ground.calibrated else "Steps disabled until this image's clear ground is calibrated. No painted-object collision map is inferred.")

func _store_ground_region() -> void:
	ground_regions[illustrated.displayed_slot]={"enabled":character.ground.calibrated,"path":illustrated.displayed_path,"width":character.ground.width,"depth":character.ground.depth,"rest_enabled":character.body.enabled,"seat_height":character.body.seat_height};_save()

func _preview_steps(name: String) -> bool:
	if character.body.active or bridge.command_pending() or bridge.session_may_be_active or character.motion.conversation_active or illustrated.fade_progress<1. or illustrated._worker!=null:return false
	var result: bool=character.ground.play(name,character)
	if ground_status!=null:ground_status.text=character.ground.message
	return result

func _build_ground_settings(box: VBoxContainer) -> void:
	box.add_child(_label("Virtual ground · short steps",16))
	_check(box,"Show virtual ground boundary",false,func(on: bool):show_ground_guide=on;_update_ground_guide())
	ground_status=_label("",12);ground_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(ground_status)
	ground_calibration=_check(box,"I calibrated clear ground for this image",false,func(on: bool):
		if character.ground.active or character.body.active:ground_calibration.set_pressed_no_signal(character.ground.calibrated);return
		if illustrated.displayed_path.is_empty():ground_calibration.set_pressed_no_signal(false);return
		character.ground.calibrated=on;_ground_wait=120.;_store_ground_region();_load_ground_region()
	)
	ground_width_slider=_slider(box,"Clear ground width (meters)",.6,4.,.02,.8,func(value: float):
		if character.ground.active or character.body.active:_sync_slider(ground_width_slider,character.ground.width);return
		character.ground.width=value;_store_ground_region();_update_ground_guide())
	ground_depth_slider=_slider(box,"Clear ground depth (meters)",.6,4.,.02,.9,func(value: float):
		if character.ground.active or character.body.active:_sync_slider(ground_depth_slider,character.ground.depth);return
		character.ground.depth=value;_store_ground_region();_update_ground_guide())
	_check(box,"Occasional calibrated steps when idle",ground_auto,func(on: bool):ground_auto=on;_ground_wait=120.;_save())
	var actions: OptionButton=OptionButton.new()
	for action: String in ["Short steps forward + return","Short steps backward + return","Short forward/back pacing","Step turn left + return","Step turn right + return","Walk forward + return","Walk backward + return","Walk sideways left + return","Walk sideways right + return"]:actions.add_item(action)
	box.add_child(actions)
	var preview: Button=Button.new();preview.text="Preview calibrated short steps";preview.pressed.connect(func():_preview_steps(character.ground.SUPPORTED_ACTIONS[actions.selected]));box.add_child(preview)
	_check(box,"Optional standing night rest when idle",night_rest,func(on: bool):night_rest=on;_idle_duration=0.;_save())
	_slider(box,"Night rest after idle seconds",30,1800,30,rest_after,func(value: float):rest_after=value;_save())
	_build_phase6_settings(box)
	_load_ground_region()

func _update_ground_guide() -> void:
	if ground_guide==null or character==null:return
	ground_guide.show_region(camera,character.ground.origin,character.ground.width,character.ground.depth,show_ground_guide and settings_panel!=null and settings_panel.visible and not clean_presentation and stage_mode==0)
	ground_guide.show_seat(camera,character.ground.origin,character.body.seat_height,character.scale.x,character.body.enabled and ground_guide.visible)

func _sync_slider(slider: HSlider,value: float) -> void:
	if slider==null:return
	slider.set_value_no_signal(value)
	var label: Label=slider.get_meta("caption");label.text="%s · %.2f"%[slider.get_meta("title"),value]

func _perform_behavior(action: String,manual: bool=false) -> bool:
	if action in ["stand","wake"]:return character.body.play(action,character)
	if manual and character.body.active and action in character.body.ACTIONS and not character.motion.conversation_active and not bridge.command_pending() and not bridge.session_may_be_active:
		return character.body.play(action,character)
	if character.motion.conversation_active or bridge.command_pending() or bridge.session_may_be_active or character.ground.active or character.body.active or illustrated.fade_progress<1. or illustrated._worker!=null:return false
	var success: bool=false
	if action=="personality":
		var total: float=0.
		var candidates: Array[String]=[]
		for name: String in Personality.IDS:
			if float(personality_weights.get(name,0.))>0.:candidates.append(name)
		if candidates.size()>1:candidates.erase(last_personality)
		for name: String in candidates:total+=clampf(float(personality_weights.get(name,0.)),0.,5.)
		var choice: float=character.rng.randf()*total
		if total<=0.:return false
		for name: String in candidates:
			choice-=clampf(float(personality_weights.get(name,0.)),0.,5.)
			if choice<0.:action=name;break
	if action in Personality.IDS or action=="stretch":
		success=character.play_gesture(action)
		if success and action in Personality.IDS:last_personality=action
	elif action in character.body.ACTIONS:
		success=character.body.play(action,character)
		if success and not manual:character.body.hold_seconds=behavior.rng.randf_range(45.,90.)
	else:success=character.ground.play(action,character)
	if behavior_status!=null:behavior_status.text=("Selected: " if success else "Unavailable here: ")+action.replace("_"," ")+("" if success else " · check floor bounds, calibration and Voice status")
	return success

func _build_phase6_settings(box: VBoxContainer) -> void:
	box.add_child(_label("Phase 6 · full-body & personality",18))
	behavior_status=_label("No emotion inference. Voice always has priority.",12);behavior_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(behavior_status)
	full_body_toggle=_check(box,"Enable calibrated virtual seat / floor rest",false,func(on: bool):
		if character.body.active:full_body_toggle.set_pressed_no_signal(character.body.enabled);return
		character.body.enabled=on;_store_ground_region()
	)
	seat_height_slider=_slider(box,"Virtual seat surface height (meters)",.48,.60,.01,.48,func(value: float):
		if character.body.active:_sync_slider(seat_height_slider,character.body.seat_height);return
		character.body.seat_height=value;_store_ground_region()
	)
	_slider(box,"Step-turn angle (degrees)",15,90,5,character.ground.turn_degrees,func(value: float):character.ground.turn_degrees=value;settings.set_value("ground","turn_degrees",value);_save())
	_check(box,"Autonomous major actions · opt-in",behavior.enabled,func(on: bool):behavior.enabled=on;behavior.wait=behavior.interval_min;_save())
	_slider(box,"Major action interval minimum (seconds)",15,300,5,behavior.interval_min,func(value: float):behavior.interval_min=value;behavior.interval_max=maxf(value,behavior.interval_max);_save())
	_slider(box,"Major action interval maximum (seconds)",15,600,5,behavior.interval_max,func(value: float):behavior.interval_max=maxf(behavior.interval_min,value);_save())
	_slider(box,"Personality face intensity",0,1,.05,personality_intensity,func(value: float):personality_intensity=value;character.motion.personality_intensity=value;_save())
	var options: OptionButton=OptionButton.new()
	for title: String in Personality.LABELS:options.add_item(title)
	for title: String in ["Sit on calibrated virtual seat","Lie down on calibrated floor","Sleep on calibrated floor","Stand / wake and return"]:options.add_item(title)
	box.add_child(options)
	var preview: Button=Button.new();preview.text="Play selected Phase 6 action"
	preview.pressed.connect(func():
		if manual_state>=0 and not (manual_state in [1,2,3]):_select_state(0);character.set_state(Character.State.IDLE)
		var action: String=Personality.IDS[options.selected] if options.selected<10 else ["sit","lie_down","sleep","stand"][options.selected-10]
		_perform_behavior(action,true)
	);box.add_child(preview)
	var stop: Button=Button.new();stop.text="Return to standing / wake";stop.pressed.connect(func():character.body.play("stand",character));box.add_child(stop)
	for name: String in behavior.DEFAULT_WEIGHTS:
		_slider(box,"Major weight · "+name.replace("_"," "),0,5,.25,float(behavior.weights[name]),func(value: float):behavior.weights[name]=value;_save())
	for name: String in Personality.IDS:
		_slider(box,"Personality weight · "+name.replace("_"," "),0,5,.25,float(personality_weights[name]),func(value: float):personality_weights[name]=value;_save())

func _update_rest_camera() -> void:
	if character.body.active:
		if not _rest_camera_active:_rest_camera_base=camera.transform;_rest_camera_active=true
		var amount: float=smoothstep(0.,1.,character.body.recline)
		var orbit: Basis=Basis(Vector3.UP,deg_to_rad(60.)*amount)
		var pivot: Vector3=character.ground.origin+Vector3(0,.45*character.scale.x,0)
		camera.transform=Transform3D(orbit*_rest_camera_base.basis*Basis(Vector3.RIGHT,-.08*amount),pivot+orbit*(_rest_camera_base.origin-pivot))
		if reduced_renderer!=null:reduced_renderer.sync_camera()
	elif _rest_camera_active:
		camera.transform=_rest_camera_base;_rest_camera_active=false
		if reduced_renderer!=null:reduced_renderer.sync_camera()

func _backup_phase5_settings() -> void:
	if not FileAccess.file_exists(settings_path) or settings.has_section_key("phase6","version"):return
	settings_backup_path=settings_path.get_basename()+"-before-phase6.cfg"
	if FileAccess.file_exists(settings_backup_path):return
	_settings_writable=DirAccess.copy_absolute(ProjectSettings.globalize_path(settings_path),ProjectSettings.globalize_path(settings_backup_path))==OK
	if not _settings_writable:push_warning("Previous settings could not be backed up. Preferences will remain in memory; the existing file is preserved.")

func _autonomy_context() -> Dictionary:
	var effects: Dictionary={"petals":illustrated.petals.visible and illustrated.petals.multimesh.visible_instance_count>0,"rain":illustrated.weather.rain.visible,"fog":illustrated.weather.fog.visible,"branches":illustrated.branches[0].visible or illustrated.branches[1].visible}
	if stage_mode!=0:effects={"petals":park.petals!=null and park.petals.multimesh.visible_instance_count>0,"rain":false,"fog":false,"branches":false}
	return {"scene":"imported_image" if stage_mode==0 else "procedural_park","environment":illustrated.displayed_slot if stage_mode==0 else "procedural_park","time_of_day":cycle.local_slot(),"weather":weather_mode if stage_mode==0 else "clear","effects":effects,"animation":character.body.desired if character.body.active else (character.ground.action if character.ground.active else (character.motion.gesture if not character.motion.gesture.is_empty() else "idle")),"state":Character.STATE_NAMES[character.state].to_lower(),"conversation":character.motion.conversation_active,"voice_uncertain":bridge.session_may_be_active or bridge.command_pending() or (bool(bridge.state.get("connected",false)) and bridge.state.get("voice","unknown")=="unknown"),"sleeping":character.motion.sleep_amount>.1 or character.body.active,"focused":performance.focused and not performance.minimized and not settings_panel.visible}

func _update_autonomy(delta: float) -> void:
	mouse_awareness.sample(delta,self)
	character.motion.cursor_target=mouse_awareness.target
	character.motion.cursor_eyes=autonomy.mouse_tracking
	character.motion.cursor_head=autonomy.head_tracking
	character.motion.cursor_smoothing=autonomy.smoothing
	_autonomy_clock+=delta
	if _autonomy_clock>=.25:
		autonomy.advance(_autonomy_clock,_autonomy_context());_autonomy_clock=0.
		if autonomy_status!=null and settings_panel.visible:autonomy_status.text="Proactive Voice unavailable · local text only\n"+autonomy.status+"\n%d / %d interruptions today"%[autonomy.count,autonomy.daily_limit]
	if _autonomy_text_seconds>0.:
		_autonomy_text_seconds=maxf(0.,_autonomy_text_seconds-delta)
		if _autonomy_text_seconds==0. or character.motion.conversation_active or not autonomy.enabled or autonomy.mode=="quiet" or autonomy.paused or autonomy.dnd or autonomy.silence:
			autonomy_text.text="";_autonomy_text_seconds=0.

func _autonomy_event(event: Dictionary) -> void:
	# Local signal only: no bridge transmission, prompt injection, TTS, or Voice start.
	if event.has("text") and autonomy_text!=null:
		autonomy_text.text=str(event.text);_autonomy_text_seconds=8.
	if not character.motion.conversation_active and not character.body.active and not character.ground.active and character.motion.gesture.is_empty():character.play_gesture("curious_tilt" if event.trigger=="avatar_hover" else "smirk")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:mouse_awareness.moved(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mouse_awareness.hovered and not settings_panel.visible:
		autonomy.request_event("avatar_click",_autonomy_context())

func _build_autonomy_settings(box: VBoxContainer) -> void:
	box.add_child(_label("Aisora Autonomy",18))
	autonomy_status=_label("Local text only · proactive Voice unavailable",12);autonomy_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(autonomy_status)
	_check(box,"Proactive dialogue",autonomy.enabled,func(on: bool):autonomy.enabled=on;_save())
	var modes: OptionButton=OptionButton.new()
	for name_value: String in Autonomy.MODES:modes.add_item(name_value.capitalize())
	modes.select(Autonomy.MODES.find(autonomy.mode));box.add_child(modes)
	_check(box,"Mouse eye tracking · in this window",autonomy.mouse_tracking,func(on: bool):autonomy.mouse_tracking=on;_save())
	_check(box,"Subtle head tracking",autonomy.head_tracking,func(on: bool):autonomy.head_tracking=on;_save())
	_check(box,"Hover reactions",autonomy.hover_reactions,func(on: bool):autonomy.hover_reactions=on;_save())
	_check(box,"Environmental comments",autonomy.environment_comments,func(on: bool):autonomy.environment_comments=on;_save())
	_check(box,"Local text fallback",autonomy.local_text,func(on: bool):autonomy.local_text=on;_save())
	_slider(box,"Cursor sensitivity",.1,1.,.05,autonomy.sensitivity,func(value: float):autonomy.sensitivity=value;_save())
	_slider(box,"Cursor smoothing",1.,12.,.5,autonomy.smoothing,func(value: float):autonomy.smoothing=value;_save())
	var cooldown: HSlider=_slider(box,"Dialogue cooldown (minutes)",10.,120.,1.,autonomy.cooldown_seconds/60.,func(value: float):autonomy.cooldown_seconds=value*60.;_save())
	var limit: HSlider=_slider(box,"Maximum daily interruptions",0.,24.,1.,autonomy.daily_limit,func(value: float):autonomy.daily_limit=int(value);_save())
	modes.item_selected.connect(func(index: int):autonomy.select_mode(Autonomy.MODES[index]);cooldown.value=autonomy.cooldown_seconds/60.;limit.value=autonomy.daily_limit;_save())
	_check(box,"Quiet hours · Mac local clock",autonomy.quiet_hours,func(on: bool):autonomy.quiet_hours=on;_save())
	_slider(box,"Quiet starts at hour",0.,23.,1.,autonomy.quiet_start,func(value: float):autonomy.quiet_start=int(value);_save())
	_slider(box,"Quiet ends at hour",0.,23.,1.,autonomy.quiet_end,func(value: float):autonomy.quiet_end=int(value);_save())
	_check(box,"Pause unsolicited dialogue",autonomy.paused,func(on: bool):autonomy.paused=on;_save())
	_check(box,"Do Not Disturb",autonomy.dnd,func(on: bool):autonomy.dnd=on;_save())
	_check(box,"I requested silence · until unchecked",autonomy.silence,func(on: bool):autonomy.silence=on;_save())
	_check(box,"Greeting on launch",autonomy.greeting,func(on: bool):autonomy.greeting=on;_save())
	_slider(box,"Scheduled chat hour (-1 off)",-1.,23.,1.,autonomy.scheduled_hour,func(value: float):autonomy.scheduled_hour=int(value);_save())
	var topic: LineEdit=LineEdit.new();topic.placeholder_text="Optional saved follow-up topic (local only)";topic.max_length=240;topic.text=autonomy.follow_up
	topic.text_changed.connect(func(value: String):autonomy.follow_up=value;autonomy._followed=false;_save());box.add_child(topic)
	var copy: Button=Button.new();copy.text="Copy Aisora Project instructions";copy.pressed.connect(func():DisplayServer.clipboard_set(FileAccess.get_file_as_string("res://config/aisora-personality.md")));box.add_child(copy)
	var help: Label=_label("Paste into your Aisora ChatGPT Project instructions manually. Voice cannot be prompted automatically. No cursor data is shared; other apps and screen capture are not accessed.",12);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(help)
