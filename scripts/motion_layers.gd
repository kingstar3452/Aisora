class_name AisoraMotionLayers
extends RefCounted
## Independent, composable pose layers in the imported skeleton's world rest axes.
## Mouth and eyelids remain separate facial layers in AisoraCharacter.
const IDLE: int = 0
const LISTENING: int = 1
const THINKING: int = 2
const TALKING: int = 3
const SLEEPING: int = 4
const GESTURE_DURATION: Dictionary = {"wave": 4.2, "stretch": 5.2, "inspect": 4.8, "settle": 3.4, "explain": 3.5, "nod": 2.0}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mode: int = IDLE
var intensity: float = 1.0
var time: float = 0.0
var breath_phase: float = 0.0
var sleep_progress: float = 0.0
var sleep_amount: float = 0.0
var wake_time: float = 10.0
var weights: Dictionary = {IDLE: 1.0, LISTENING: 0.0, THINKING: 0.0, TALKING: 0.0, SLEEPING: 0.0}
var layers: Dictionary = {}
var poses: Dictionary = {}
var hips_offset: Vector3 = Vector3.ZERO
var gaze: Vector2 = Vector2.ZERO
var gaze_target: Vector2 = Vector2.ZERO
var gaze_wait: float = 0.0
var posture: Vector2 = Vector2.ZERO
var posture_target: Vector2 = Vector2.ZERO
var posture_wait: float = 0.0
var breath_speed: float = 1.2
var breath_target: float = 1.2
var breath_wait: float = 0.0
var gesture: String = ""
var gesture_time: float = 0.0
var gesture_wait: float = 4.0
var gesture_cancel: float = 1.0
var cancelling: bool = false
var gesture_side: float = 1.0
var last_gesture: String = ""
var gesture_serial: int = 0
var phase: float = 0.0
const EMPTY_POSE: Dictionary = {}
var _gesture_work: Dictionary = {}
var _gesture_work_name: String = ""
var _limits: Dictionary = {}

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	phase = rng.randf_range(0.0, TAU)
	breath_phase = phase
	gesture_wait = rng.randf_range(3.0, 6.0)

	layers = {
		"breathing": {"Spine": Vector3.ZERO, "Chest": Vector3.ZERO},
		"posture": {"Spine": Vector3.ZERO, "Chest": Vector3.ZERO, "Neck": Vector3.ZERO, "Head": Vector3.ZERO, "LeftShoulder": Vector3.ZERO, "RightShoulder": Vector3.ZERO, "LeftUpperArm": Vector3.ZERO, "RightUpperArm": Vector3.ZERO, "LeftLowerArm": Vector3.ZERO, "RightLowerArm": Vector3.ZERO, "LeftHand": Vector3.ZERO, "RightHand": Vector3.ZERO},
		"gaze": {"Head": Vector3.ZERO, "Neck": Vector3.ZERO},
		"speech": {"Head": Vector3.ZERO, "Chest": Vector3.ZERO},
		"gesture": {}
	}

func transition_to(next: int) -> void:
	if mode == next:
		return
	if mode == SLEEPING and next != SLEEPING:
		wake_time = 0.0
	mode = next
	gaze_wait = 0.0
	if not gesture.is_empty():
		cancelling = true
	gesture_wait = rng.randf_range(3.0, 6.0)

func start_gesture(name: String) -> bool:
	if mode == SLEEPING or not GESTURE_DURATION.has(name):
		return false
	gesture = name
	last_gesture = name
	gesture_time = 0.0
	gesture_cancel = 1.0
	cancelling = false
	gesture_side = -1.0 if rng.randf() < 0.5 else 1.0
	gesture_serial += 1
	return true

func is_resting() -> bool:
	return mode == SLEEPING and sleep_progress >= 1.0

func tick(delta: float, audio_mouth: float) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0:
		return poses
	var dt: float = minf(delta, 0.1)
	time += dt
	intensity = clampf(intensity, 0.0, 1.6)
	var state_blend: float = 1.0 - exp(-dt * 3.8)
	for state: int in weights:
		weights[state] = lerpf(float(weights[state]), 1.0 if state == mode else 0.0, state_blend)
	sleep_progress = move_toward(sleep_progress, 1.0 if mode == SLEEPING else 0.0, dt / (2.4 if mode == SLEEPING else 1.8))
	sleep_amount = smoothstep(0.0, 1.0, sleep_progress)
	wake_time += dt
	var awake: float = 1.0 - sleep_amount
	var listen: float = float(weights[LISTENING]) * awake
	var think: float = float(weights[THINKING]) * awake
	var talk: float = float(weights[TALKING]) * awake
	var idle: float = float(weights[IDLE]) * awake
	_update_targets(dt)
	breath_speed = lerpf(breath_speed, lerpf(breath_target, 0.72, sleep_amount), 1.0 - exp(-dt * 1.5))
	breath_phase += dt * breath_speed
	var breath: float = sin(breath_phase)
	var sway: float = (sin(time * 0.63 + phase) * 0.55 + posture.x * 0.45) * intensity * awake
	var wake: float = sin(clampf(wake_time / 2.6, 0.0, 1.0) * PI) * intensity
	layers.breathing["Spine"] = Vector3(breath * 0.016 * intensity, 0.0, 0.0)
	layers.breathing["Chest"] = Vector3(breath * 0.013 * intensity, 0.0, 0.0)
	layers.posture["Spine"] = Vector3(sleep_amount * 0.10 - listen * 0.025 - wake * 0.025, think * 0.045, sway * 0.025)
	layers.posture["Chest"] = Vector3(sleep_amount * 0.06, 0.0, -sway * 0.018)
	layers.posture["Neck"] = Vector3(sleep_amount * 0.045, 0.0, listen * 0.055)
	layers.posture["Head"] = Vector3(sleep_amount * 0.19 - wake * 0.07, think * 0.14, sleep_amount * 0.13 + listen * 0.07)
	layers.posture["LeftShoulder"] = Vector3(0.0, 0.0, -sleep_amount * 0.04 + wake * 0.045)
	layers.posture["RightShoulder"] = Vector3(0.0, 0.0, sleep_amount * 0.04 - wake * 0.045)
	layers.posture["LeftUpperArm"] = Vector3(-sleep_amount * 0.18, 0.0, -1.22 + sleep_amount * 0.10 + sway * 0.045)
	layers.posture["RightUpperArm"] = Vector3(-sleep_amount * 0.18 - think * 0.20, 0.0, 1.22 - sleep_amount * 0.10 + sway * 0.045 - think * 0.09)
	layers.posture["LeftLowerArm"] = Vector3(0.0, -0.16 - sleep_amount * 0.25, 0.0)
	layers.posture["RightLowerArm"] = Vector3(0.0, 0.16 + sleep_amount * 0.25 + think * 0.45, 0.0)
	layers.posture["LeftHand"] = Vector3(0.0, 0.0, -sleep_amount * 0.06)
	layers.posture["RightHand"] = Vector3(0.0, 0.0, sleep_amount * 0.06)
	layers.gaze["Head"] = Vector3(gaze.y * 0.07, gaze.x * 0.16, gaze.x * 0.035)
	layers.gaze["Neck"] = Vector3(0.0, gaze.x * 0.055, sin(time * 0.41 + phase) * 0.025 * intensity * awake)
	var speech: float = clampf(audio_mouth * 2.0, 0.0, 1.0) * talk * intensity
	layers.speech["Head"] = Vector3(sin(time * 2.5 + phase) * 0.045 * speech, sin(time * 1.7) * 0.035 * speech, sin(time * 1.2) * 0.025 * speech)
	layers.speech["Chest"] = Vector3(0.0, sin(time * 1.1 + phase) * 0.025 * speech, 0.0)
	hips_offset = Vector3((posture.x * 0.009 + sway * 0.005) * awake * intensity, breath * 0.0025 * intensity - sleep_amount * 0.008, posture.y * 0.003 * idle * intensity)
	_update_gesture(dt)
	layers.gesture = _gesture_pose(awake * intensity)
	for bone: String in poses: poses[bone] = Vector3.ZERO
	for layer_name: String in layers:
		var layer: Dictionary = layers[layer_name]
		for bone: String in layer:
			poses[bone] = Vector3(poses.get(bone, Vector3.ZERO)) + Vector3(layer[bone])
	_limit_poses()
	return poses

func _update_targets(dt: float) -> void:
	gaze_wait -= dt
	posture_wait -= dt
	breath_wait -= dt
	if gaze_wait <= 0.0:
		var focus: float = 0.10 if mode == LISTENING else (0.32 if mode == TALKING else 1.0)
		gaze_target = Vector2(rng.randf_range(-0.95, 0.95) * focus, rng.randf_range(-0.35, 0.35) * focus)
		gaze_wait = rng.randf_range(2.4, 5.8)
	if posture_wait <= 0.0:
		posture_target = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		posture_wait = rng.randf_range(5.5, 10.0)
	if breath_wait <= 0.0:
		breath_target = rng.randf_range(1.0, 1.35)
		breath_wait = rng.randf_range(9.0, 16.0)
	var awake: float = 1.0 - sleep_amount
	gaze = gaze.lerp(gaze_target * awake * intensity, 1.0 - exp(-dt * 2.0))
	posture = posture.lerp(posture_target, 1.0 - exp(-dt * 0.7))

func _update_gesture(dt: float) -> void:
	if not gesture.is_empty():
		gesture_time += dt
		if cancelling:
			gesture_cancel = move_toward(gesture_cancel, 0.0, dt * 2.8)
		if gesture_time >= float(GESTURE_DURATION[gesture]) or gesture_cancel <= 0.0:
			gesture = ""
			gesture_wait = rng.randf_range(8.0, 15.0) if mode == IDLE else rng.randf_range(4.0, 8.0)
		return
	gesture_wait -= dt
	if gesture_wait > 0.0 or mode == SLEEPING or sleep_amount > 0.1 or wake_time < 2.6 or intensity < 0.05:
		return
	var choices: Array = ["wave", "stretch", "inspect", "settle"]
	if mode == TALKING:
		choices = ["explain", "nod"]
	elif mode == LISTENING:
		choices = ["nod"]
	elif mode == THINKING:
		choices = ["inspect", "settle"]
	if choices.size() > 1 and choices.has(last_gesture):
		choices.erase(last_gesture)
	start_gesture(str(choices[rng.randi_range(0, choices.size() - 1)]))

func _gesture_pose(strength: float) -> Dictionary:
	if gesture.is_empty():
		return EMPTY_POSE
	var duration: float = float(GESTURE_DURATION[gesture])
	var fade: float = smoothstep(0.0, 0.75, gesture_time) * (1.0 - smoothstep(duration - 0.8, duration, gesture_time)) * gesture_cancel * strength
	if _gesture_work_name != gesture:
		_gesture_work.clear()
		_gesture_work_name = gesture
	var result: Dictionary = _gesture_work
	match gesture:
		"wave":
			result["LeftUpperArm"] = Vector3(-1.12, 0.0, 0.84)
			result["LeftLowerArm"] = Vector3(0.0, -1.65, 0.0)
			result["LeftHand"] = Vector3(0.0, sin(gesture_time * 8.0) * 0.20, 0.12)
			result["Head"] = Vector3(0.0, -0.055, 0.075)
		"stretch":
			result["LeftUpperArm"] = Vector3(-0.28, 0.0, 1.38)
			result["RightUpperArm"] = Vector3(-0.28, 0.0, -1.38)
			result["LeftLowerArm"] = Vector3(0.0, -0.15, 0.0)
			result["RightLowerArm"] = Vector3(0.0, 0.15, 0.0)
			result["Spine"] = Vector3(-0.085, 0.0, 0.0)
			result["Head"] = Vector3(-0.09, 0.0, 0.0)
		"inspect":
			result["Head"] = Vector3(-0.035, gesture_side * 0.22, gesture_side * 0.065)
			result["Chest"] = Vector3(0.0, gesture_side * 0.065, 0.0)
		"settle":
			result["Spine"] = Vector3(-0.025, 0.0, gesture_side * 0.045)
			result["LeftShoulder"] = Vector3(0.0, 0.0, 0.065)
			result["RightShoulder"] = Vector3(0.0, 0.0, -0.065)
			result["Head"] = Vector3(0.025, 0.0, -gesture_side * 0.055)
		"explain":
			result["RightUpperArm"] = Vector3(-0.65, 0.0, -0.24)
			result["RightLowerArm"] = Vector3(0.0, 0.85, 0.0)
			result["RightHand"] = Vector3(-0.15, 0.12, 0.0)
			result["Head"] = Vector3(sin(gesture_time * 2.0) * 0.035, 0.04, -0.04)
		"nod":
			result["Head"] = Vector3(sin(gesture_time / duration * TAU) * 0.075, 0.0, 0.0)
	for bone: String in result:
		result[bone] = Vector3(result[bone]) * fade
	return result

func _limit_poses() -> void:
	for bone: String in poses:
		if not _limits.has(bone):
			var limit: Vector3 = Vector3(0.22, 0.20, 0.16)
			if bone == "Head":
				limit = Vector3(0.35, 0.38, 0.26)
			elif bone.ends_with("UpperArm"):
				limit = Vector3(1.25, 0.20, 1.48)
			elif bone.ends_with("LowerArm"):
				limit = Vector3(0.12, 1.95, 0.12)
			elif bone.ends_with("Hand"):
				limit = Vector3(0.28, 0.28, 0.28)
			_limits[bone] = limit
		var bound: Vector3 = _limits[bone]
		poses[bone] = Vector3(poses[bone]).clamp(-bound, bound)
