class_name AisoraMotionLayers
extends RefCounted
## Independent, composable pose layers in the imported skeleton's world rest axes.
## Mouth and eyelids remain separate facial layers in AisoraCharacter.
const Personality=preload("res://scripts/personality.gd")
const Catalog = preload("res://scripts/action_catalog.gd")
const IDLE: int = 0
const LISTENING: int = 1
const THINKING: int = 2
const TALKING: int = 3
const SLEEPING: int = 4
const GESTURE_DURATION: Dictionary = {"wave": 4.2, "stretch": 5.2, "inspect": 4.8, "settle": 3.4, "explain": 3.5, "nod": 2.0, "breathe":4.8,"look_sides":5.8,"look_up":4.6,"look_down":4.2,"fingers":5.8,"hands":5.5,"back_stretch":5.0,"curious":4.0,"fold_arms":6.0,"hand_face":5.2,"weight_shift":5.5,"brush_hair":4.8,"playful":4.5,"unimpressed":6.,"eye_roll":3.4,"smirk":4.,"dramatic_turn":4.,"mock_annoyance":4.6,"laugh":4.8,"curious_tilt":4.,"disbelief":4.6,"point":4.5,"hand_on_hip":5.5}

const FINGER_CHAINS: Dictionary={
	"Left":[["LeftIndexProximal","LeftIndexIntermediate","LeftIndexDistal"],["LeftMiddleProximal","LeftMiddleIntermediate","LeftMiddleDistal"],["LeftRingProximal","LeftRingIntermediate","LeftRingDistal"],["LeftLittleProximal","LeftLittleIntermediate","LeftLittleDistal"]],
	"Right":[["RightIndexProximal","RightIndexIntermediate","RightIndexDistal"],["RightMiddleProximal","RightMiddleIntermediate","RightMiddleDistal"],["RightRingProximal","RightRingIntermediate","RightRingDistal"],["RightLittleProximal","RightLittleIntermediate","RightLittleDistal"]]
}
const REST_ARM_Z: float=1.04
const ARM_BONES: Dictionary = {"Left":["LeftUpperArm","LeftLowerArm","LeftHand"],"Right":["RightUpperArm","RightLowerArm","RightHand"]}
var personality_intensity: float=.55
var personality_envelope: float=0.
var external_sleep: float=0.
var locomotion_active: bool=false
var queued_gesture: String=""
var context_weights: Dictionary={}
var micro_speed: float=1.0
var gesture_speed: float=1.0
var conversation_active: bool = false
var scheduler_enabled: bool = true
var _scheduler_configured: bool = false
var interval_min: float = 8.0
var interval_max: float = 15.0
var action_weights: Dictionary = Catalog.WEIGHTS.duplicate()
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
	queued_gesture=""
	gesture_wait = rng.randf_range(interval_min,maxf(interval_min,interval_max)) if next==IDLE else rng.randf_range(3.0,6.0)

func start_gesture(name: String) -> bool:
	if mode == SLEEPING or not GESTURE_DURATION.has(name) or (conversation_active and name not in ["nod","explain"]):
		return false
	if not gesture.is_empty():
		queued_gesture=name;cancelling=true;return true
	gesture = name
	last_gesture = name
	gesture_time = 0.0
	gesture_cancel = 1.0
	cancelling = false
	gesture_side = -1.0 if rng.randf() < 0.5 else 1.0
	gesture_serial += 1
	return true

func is_resting() -> bool:
	return (mode == SLEEPING and sleep_progress >= 1.0) or external_sleep>=.999

func tick(delta: float, audio_mouth: float) -> Dictionary:
	if not is_finite(delta) or delta <= 0.0:
		return poses
	var dt: float = minf(delta, 0.1)
	time += dt*micro_speed
	intensity = clampf(intensity, 0.0, 1.6)
	var state_blend: float = 1.0 - exp(-dt * 3.8)
	for state: int in weights:
		weights[state] = lerpf(float(weights[state]), 1.0 if state == mode else 0.0, state_blend)
	sleep_progress = move_toward(sleep_progress, 1.0 if mode == SLEEPING else 0.0, dt / (2.4 if mode == SLEEPING else 1.8))
	sleep_amount = maxf(external_sleep,smoothstep(0.0, 1.0, sleep_progress))
	wake_time += dt
	var awake: float = 1.0 - sleep_amount
	var listen: float = float(weights[LISTENING]) * awake
	var think: float = float(weights[THINKING]) * awake
	var talk: float = float(weights[TALKING]) * awake
	var idle: float = float(weights[IDLE]) * awake
	_update_targets(dt)
	breath_speed = lerpf(breath_speed, lerpf(breath_target, 0.72, sleep_amount), 1.0 - exp(-dt * 1.5))
	breath_phase += dt * breath_speed*micro_speed
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
	layers.posture["LeftUpperArm"] = Vector3(-sleep_amount * 0.18, 0.0, -REST_ARM_Z + sleep_amount * 0.10 + sway * 0.045)
	layers.posture["RightUpperArm"] = Vector3(-sleep_amount * 0.18 - think * 0.20, 0.0, REST_ARM_Z - sleep_amount * 0.10 + sway * 0.045 - think * 0.09)
	layers.posture["LeftLowerArm"] = Vector3(0.0, -0.16 - sleep_amount * 0.25, 0.0)
	layers.posture["RightLowerArm"] = Vector3(0.0, 0.16 + sleep_amount * 0.25 + think * 0.45, 0.0)
	layers.posture["LeftHand"] = Vector3(0.0, 0.0, -sleep_amount * 0.06)
	layers.posture["RightHand"] = Vector3(0.0, 0.0, sleep_amount * 0.06)
	for side: String in ["Left","Right"]:
		for chain: Array in FINGER_CHAINS[side]:layers.posture[chain[0]]=Vector3(0,0,-.12 if side=="Left" else .12)
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
		if conversation_active and gesture not in ["nod","explain"]: cancelling = true;queued_gesture=""
		gesture_time += dt*gesture_speed
		if cancelling:
			gesture_cancel = move_toward(gesture_cancel, 0.0, dt * 2.8)
		if gesture_time >= float(GESTURE_DURATION[gesture]) or gesture_cancel <= 0.0:
			gesture = ""
			if not queued_gesture.is_empty():
				var queued: String=queued_gesture;queued_gesture="";start_gesture(queued)
			gesture_wait = rng.randf_range(clampf(interval_min,5.0,120.0),clampf(maxf(interval_min,interval_max),5.0,180.0)) if mode == IDLE else rng.randf_range(4.0, 8.0)
		return
	gesture_wait -= dt
	if gesture_wait > 0.0 or mode == SLEEPING or sleep_amount > 0.1 or wake_time < 2.6 or intensity < 0.05:
		return
	if mode == IDLE:
		if not scheduler_enabled or conversation_active or locomotion_active:return
		var available: int=0
		for name: String in Catalog.IDS:
			if _action_weight(name)>0.0:available+=1
		var total: float=0.0
		for name: String in Catalog.IDS:
			if name!=last_gesture or available==1:total+=clampf(_action_weight(name),0.0,5.0)
		if total<=0.0:gesture_wait=1.0;return
		var choice: float=rng.randf()*total
		for name: String in Catalog.IDS:
			if name==last_gesture and available>1:continue
			choice-=clampf(_action_weight(name),0.0,5.0)
			if choice<0.0:start_gesture(name);return
		return
	if conversation_active and mode==THINKING:return
	var choices: Array = ["inspect", "settle"]
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
	personality_envelope=0.
	if gesture.is_empty():
		return EMPTY_POSE
	var duration: float = float(GESTURE_DURATION[gesture])
	var fade: float = smoothstep(0.0, 0.9, gesture_time) * (1.0 - smoothstep(duration - 0.9, duration, gesture_time)) * gesture_cancel * minf(strength,1.0)
	if _gesture_work_name != gesture:
		_gesture_work.clear()
		_gesture_work_name = gesture
	var result: Dictionary = _gesture_work
	personality_envelope=fade*personality_intensity if gesture in Personality.IDS else 0.
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
		"breathe":
			result["Chest"]=Vector3(sin(gesture_time/duration*PI)*0.045,0,0)
			result["Head"]=Vector3(-0.035,0,0)
			result["LeftShoulder"]=Vector3(0,0,0.045);result["RightShoulder"]=Vector3(0,0,-0.045)
		"look_sides":
			var turn: float=sin(gesture_time/duration*TAU)
			result["Head"]=Vector3(0,turn*0.34,0);result["Neck"]=Vector3(0,turn*0.08,0)
		"look_up":
			result["Head"]=Vector3(-0.30,0,0);result["Neck"]=Vector3(-0.05,0,0)
		"look_down":
			result["Head"]=Vector3(0.30,0,0);result["Neck"]=Vector3(0.05,0,0)
		"fingers":
			_arm(result,"Left",Vector3(-0.225,-0.46,-0.75),-1.59)
			result["Head"]=Vector3(0.20,0.20,0)
			result["LeftHand"]=Vector3(0.05,0.08,0.12)
			_soft_fingers(result,"Left",.18)
			var curl: float=0.20+0.15*sin(gesture_time*3.0)
			result["LeftIndexProximal"]=Vector3(0,0,-curl)
			result["LeftIndexIntermediate"]=Vector3(0,0,-curl*0.6)
			result["LeftMiddleProximal"]=Vector3(0,0,-0.35)
		"hands":
			_arm(result,"Left",Vector3(0.245,-0.755,-0.39),-1.23)
			_arm(result,"Right",Vector3(0.245,0.755,0.39),1.23)
			_soft_fingers(result,"Left",.10);_soft_fingers(result,"Right",.10)
			result["Head"]=Vector3(0.24,0,0)
			result["LeftHand"]=Vector3(0.08,sin(gesture_time*1.6)*0.20,0.12)
			result["RightHand"]=Vector3(0.08,-sin(gesture_time*1.6)*0.20,-0.12)
		"back_stretch":
			result["Spine"]=Vector3(-0.14,0,0);result["Chest"]=Vector3(-0.10,0,0)
			result["Head"]=Vector3(-0.12,0,0)
			result["LeftShoulder"]=Vector3(0,0,0.06);result["RightShoulder"]=Vector3(0,0,-0.06)
		"curious":
			result["Head"]=Vector3(-0.03,0.04,gesture_side*0.21)
		"fold_arms","unimpressed":
			var inward: float=smoothstep(.8,1.6,gesture_time)*(1.-smoothstep(duration-1.6,duration-.8,gesture_time))
			_arm(result,"Left",Vector3(.245,-.755,-.39).lerp(Vector3(.59,-.92,-.25),inward),lerpf(-1.23,-1.455,inward))
			_arm(result,"Right",Vector3(.245,.755,.39).lerp(Vector3(.72,.92,.20),inward),lerpf(1.23,1.315,inward))
			_soft_fingers(result,"Left",.26);_soft_fingers(result,"Right",.26)
			result["LeftHand"]=Vector3(0,0.12,0.08);result["RightHand"]=Vector3(0,-0.15,-0.08)
			result["LeftIndexProximal"]=Vector3(0,0,-0.25);result["RightIndexProximal"]=Vector3(0,0,0.25)
			result["LeftMiddleProximal"]=Vector3(0,0,-0.35);result["RightMiddleProximal"]=Vector3(0,0,0.35)
		"hand_face":
			_arm(result,"Left",Vector3(-0.66,-0.8,-0.95),-2.05)
			result["Head"]=Vector3(0.02,0.02,-0.05)
			result["LeftHand"]=Vector3(0.12,0.08,0.15)
		"weight_shift":
			var shift: float=sin(gesture_time/duration*TAU)
			result["Spine"]=Vector3(0,0,shift*0.06);result["Chest"]=Vector3(0,0,-shift*0.025)
			result["LeftUpperLeg"]=Vector3(0,0,-shift*0.027);result["RightUpperLeg"]=Vector3(0,0,-shift*0.027)
			result["LeftFoot"]=Vector3(0,0,shift*0.027);result["RightFoot"]=Vector3(0,0,shift*0.027)
			hips_offset.x+=shift*0.022*fade
		"brush_hair":
			_arm(result,"Right",Vector3(-0.96,1.0,0.8),1.885)
			result["Head"]=Vector3(0,0.03,0.055)
			result["RightHand"]=Vector3(-0.10,-0.05,sin(gesture_time*2.0)*0.10)
		"playful":
			_arm(result,"Left",Vector3(-0.285,-0.40,-0.775),-1.30)
			_arm(result,"Right",Vector3(-0.285,0.40,0.775),1.30)
			result["LeftHand"]=Vector3(0,sin(gesture_time*5)*0.18,0.15)
			result["RightHand"]=Vector3(0,-sin(gesture_time*5)*0.18,-0.15)
			result["Head"]=Vector3(0,0,sin(gesture_time*2.0)*0.06)

		"eye_roll":
			result["Head"]=Vector3(-.05,-.08,.09)
		"smirk":
			result["Head"]=Vector3(-.035,.12,-.045)
		"dramatic_turn":
			var theatrical: float=smoothstep(.9,1.5,gesture_time)*(1.-smoothstep(duration-1.4,duration-.7,gesture_time))
			result["Head"]=Vector3(-.06,gesture_side*.36*theatrical,.06)
			result["Chest"]=Vector3(0,gesture_side*.09*theatrical,0)
		"mock_annoyance":
			result["Head"]=Vector3(.08,sin(gesture_time*4.)*.08,.06)
			result["LeftShoulder"]=Vector3(0,0,.055);result["RightShoulder"]=Vector3(0,0,-.055)
		"laugh":
			result["Head"]=Vector3(-.08+sin(gesture_time*7.)*.035,0,.04)
			result["Chest"]=Vector3(sin(gesture_time*7.)*.025,0,0)
			result["LeftShoulder"]=Vector3(0,0,sin(gesture_time*7.)*.025)
			result["RightShoulder"]=Vector3(0,0,-sin(gesture_time*7.)*.025)
		"curious_tilt":
			result["Head"]=Vector3(-.04,.09,gesture_side*.22)
		"disbelief":
			result["Head"]=Vector3(-.13,sin(gesture_time*3.)*.10,gesture_side*.09)
			result["Chest"]=Vector3(-.08,0,0)
			result["LeftShoulder"]=Vector3(0,0,.07);result["RightShoulder"]=Vector3(0,0,-.07)
		"point":
			_arm(result,"Left",Vector3(-.225,-.46,-.75),-1.30)
			_soft_fingers(result,"Left",.43)
			for segment: String in ["Proximal","Intermediate","Distal"]:result["LeftIndex"+segment]=Vector3.ZERO
			result["Head"]=Vector3(0,.10,-.05)
		"hand_on_hip":
			_arm(result,"Right",Vector3(.96,.105,.445),1.37)
			result["Head"]=Vector3(-.07,-.08,-.08)
			result["Chest"]=Vector3(0,-.04,.035)

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
				limit = Vector3(1.25, 1.0, 1.48)
			elif bone.ends_with("LowerArm"):
				limit = Vector3(0.12, 2.2, 0.12)
			elif "Proximal" in bone or "Intermediate" in bone:
				limit = Vector3(0.3,0.3,0.6)
			elif bone.ends_with("Hand"):
				limit = Vector3(0.28, 0.28, 0.28)
			_limits[bone] = limit
		var bound: Vector3 = _limits[bone]
		poses[bone] = Vector3(poses[bone]).clamp(-bound, bound)

func _arm(result: Dictionary, side: String, upper: Vector3, lower_y: float) -> void:
	var bones: Array=ARM_BONES[side]
	var mirror: float=1.0 if side=="Left" else -1.0
	result[bones[0]]=upper-Vector3(0,0,-REST_ARM_Z*mirror)
	result[bones[1]]=Vector3(0,lower_y+0.16*mirror,0)

func configure_scheduler(low: float, high: float, on: bool, weights_value: Dictionary) -> void:
	low=clampf(low,5.0,120.0);high=clampf(maxf(low,high),5.0,180.0)
	if not _scheduler_configured or low!=interval_min or high!=interval_max:
		gesture_wait=rng.randf_range(low,high)
	if scheduler_enabled and not on and mode==IDLE:cancelling=true
	interval_min=low;interval_max=high;scheduler_enabled=on;action_weights=weights_value;_scheduler_configured=true

func _action_weight(name: String) -> float:
	return clampf(float(action_weights.get(name,0.0)),0,5)*float(context_weights.get(name,1.))

func set_context(period: String,weather: String) -> void:
	micro_speed=.78 if period=="nighttime" else (.92 if period=="sunset" else 1.)
	context_weights.clear();gesture_speed=.85 if period=="nighttime" else (.92 if period=="sunset" else 1.)
	if period=="morning":context_weights={"stretch":1.8,"back_stretch":1.5,"look_sides":1.4}
	elif period=="nighttime":context_weights={"breathe":1.8,"curious":.7,"playful":.2,"wave":.4,"stretch":.5}
	elif period=="sunset":context_weights={"breathe":1.4,"weight_shift":1.3,"playful":.6}
	if weather in ["light_rain","heavy_rain"]:context_weights.look_up=1.8;context_weights.look_sides=1.4

func _soft_fingers(result: Dictionary,side: String,amount: float) -> void:
	var mirror: float=-1. if side=="Left" else 1.
	for chain: Array in FINGER_CHAINS[side]:
		result[chain[0]]=Vector3(0,0,amount*mirror)
		result[chain[1]]=Vector3(0,0,amount*.6*mirror)
		result[chain[2]]=Vector3(0,0,amount*.3*mirror)
