class_name AisoraCharacter
extends Node3D
## Procedural state machine layered over imported VRM expression bindings.
## No assumed animation clips. Each frame starts from the imported resting pose.

enum State { IDLE, LISTENING, THINKING, TALKING, SLEEPING }
const STATE_NAMES: Array[String] = ["IDLE", "LISTENING", "THINKING", "TALKING", "SLEEPING"]
var state: State = State.IDLE
var model: Node3D
var skeleton: Skeleton3D
var expressions: Dictionary = {}
var shape_bindings: Dictionary = {}
var rest_rotations: Dictionary = {}
var rest_positions: Dictionary = {}
var weights: Dictionary = {}
var mouth: float = 0.0
var time: float = 0.0
var blink_wait: float = 2.0
var blink_time: float = -1.0
var look_wait: float = 0.0
var gaze: Vector2 = Vector2.ZERO
var gaze_target: Vector2 = Vector2.ZERO
var state_blend: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var scene: PackedScene = load("res://assets/character/aisora.vrm")
	if scene == null:
		push_error("Aisora VRM not imported. Enable the bundled VRM plugins and reimport.")
		return
	model = scene.instantiate()
	add_child(model)
	# VRM 0.x is converted to face Godot's +Z by the importer; camera faces -Z.
	_scan(model)
	if skeleton:
		for i in skeleton.get_bone_count():
			rest_rotations[i] = skeleton.get_bone_pose_rotation(i)
			rest_positions[i] = skeleton.get_bone_pose_position(i)
	# Hair physics is optional. Keep its authored pose and avoid per-frame springs.
	_disable_secondary(model)

func _disable_secondary(node: Node) -> void:
	if node.get_script() != null and str(node.get_script().resource_path).ends_with("vrm_secondary.gd"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is SkeletonModifier3D and node.name == "VRM_internal_skeleton_modifier":
		node.active = false
	for child in node.get_children(true):
		_disable_secondary(child)

func _scan(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node
	if node is AnimationPlayer:
		var player: AnimationPlayer = node
		for expression_name in player.get_animation_list():
			var animation: Animation = player.get_animation(expression_name)
			var bindings: Array = []
			for track in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_BLEND_SHAPE:
					continue
				var path: NodePath = animation.track_get_path(track)
				var mesh: MeshInstance3D = player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names())) as MeshInstance3D
				if mesh == null or animation.track_get_key_count(track) == 0:
					continue
				var shape: int = mesh.find_blend_shape_by_name(path.get_subname(0))
				if shape < 0:
					continue
				var binding: Dictionary = {"mesh": mesh, "shape": shape, "value": float(animation.track_get_key_value(track, 0))}
				bindings.append(binding)
				shape_bindings["%d:%d" % [mesh.get_instance_id(), shape]] = binding
			expressions[expression_name] = bindings
	for child in node.get_children():
		_scan(child)

func set_state(next: State) -> void:
	if state != next:
		state = next
		state_blend = 0.0

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if skeleton == null:
		return
	time += delta
	state_blend = minf(state_blend + delta * 3.0, 1.0)
	blink_wait -= delta
	if blink_wait <= 0.0 and blink_time < 0.0:
		blink_time = 0.0
		blink_wait = rng.randf_range(2.5, 6.5)
	var blink: float = 0.0
	if blink_time >= 0.0:
		blink_time += delta
		blink = sin(clampf(blink_time / 0.18, 0.0, 1.0) * PI)
		if blink_time >= 0.18:
			blink_time = -1.0
			blink = 0.0
	look_wait -= delta
	if look_wait <= 0.0:
		gaze_target = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4))
		look_wait = rng.randf_range(2.0, 5.0)
	gaze = gaze.lerp(gaze_target, 1.0 - exp(-delta * 2.0))
	var sleepy: float = _weight("sleep", 1.0 if state == State.SLEEPING else 0.0, delta)
	var attentive: float = _weight("listen", 1.0 if state == State.LISTENING else 0.0, delta)
	var thoughtful: float = _weight("think", 1.0 if state == State.THINKING else 0.0, delta)
	var talking: float = _weight("talk", 1.0 if state == State.TALKING else 0.0, delta)
	var movement: float = 1.0 - sleepy * 0.85
	_pose("Spine", Vector3(sin(time * 1.5) * 0.009 * movement + sleepy * 0.04, 0.0, sin(time * 0.35) * 0.012 * movement))
	_pose("Neck", Vector3(0.0, sin(time * 0.31) * 0.025 * movement, attentive * 0.07))
	_pose("Head", Vector3(sleepy * 0.12 + sin(time * 0.9) * 0.015 * movement, thoughtful * 0.12 + gaze.x * 0.025 * movement, attentive * 0.045))
	# Relax the imported T-pose in world coordinates, independently of bone axes.
	_world_arm("LeftUpperArm", -1.22 + talking * sin(time * 1.8) * 0.035)
	_world_arm("RightUpperArm", 1.22 + thoughtful * 0.08 + talking * sin(time * 1.3) * 0.045)
	_pose("LeftLowerArm", Vector3(-0.12 - talking * 0.08, 0.0, 0.0))
	_pose("RightLowerArm", Vector3(-0.12 - thoughtful * 0.12, 0.0, 0.0))
	if rest_positions.has(skeleton.find_bone("Hips")):
		var hips: int = skeleton.find_bone("Hips")
		skeleton.set_bone_pose_position(hips, rest_positions[hips] + Vector3(0.0, sin(time * 1.5) * 0.002 * movement, 0.0))
	# Eye rotations are tiny offsets from the authored rest, independent of eyelids.
	_pose("LeftEye", Vector3(gaze.y * 0.02 * movement, 0.0, gaze.x * 0.035 * movement))
	_pose("RightEye", Vector3(gaze.y * 0.02 * movement, 0.0, gaze.x * 0.035 * movement))
	_apply_expressions({"blink": maxf(blink * (1.0 - sleepy), sleepy), "aa": mouth * (1.0 - sleepy), "relaxed": 0.10 * (1.0 - sleepy) + talking * 0.05, "sad": thoughtful * 0.06})

func _weight(key_name: String, target: float, delta: float) -> float:
	var value: float = lerpf(float(weights.get(key_name, 0.0)), target, 1.0 - exp(-5.0 * delta))
	weights[key_name] = value
	return value

func _pose(bone_name: String, offset: Vector3) -> void:
	var index: int = skeleton.find_bone(bone_name)
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, rest_rotations[index] * Quaternion.from_euler(offset))

func _world_arm(bone_name: String, angle: float) -> void:
	var index: int = skeleton.find_bone(bone_name)
	if index < 0:
		return
	var parent: int = skeleton.get_bone_parent(index)
	var basis: Basis = skeleton.get_bone_global_rest(parent).basis
	var local_delta: Quaternion = (basis.inverse() * Basis(Vector3.FORWARD, -angle) * basis).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, local_delta * rest_rotations[index])

func _apply_expressions(values: Dictionary) -> void:
	for binding: Dictionary in shape_bindings.values():
		binding.mesh.set_blend_shape_value(binding.shape, 0.0)
	for expression_name: String in values:
		for binding: Dictionary in expressions.get(expression_name, []):
			var mesh: MeshInstance3D = binding.mesh
			var current: float = mesh.get_blend_shape_value(binding.shape)
			mesh.set_blend_shape_value(binding.shape, clampf(current + binding.value * float(values[expression_name]), 0.0, 1.0))
