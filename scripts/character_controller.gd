class_name AisoraCharacter
extends Node3D
## Layers procedural movement over the actual imported VRM rest pose and facial bindings.
const Motion = preload("res://scripts/motion_layers.gd")

enum State { IDLE, LISTENING, THINKING, TALKING, SLEEPING }
const STATE_NAMES: Array[String] = ["IDLE", "LISTENING", "THINKING", "TALKING", "SLEEPING"]
var state: State = State.IDLE
var model: Node3D
var skeleton: Skeleton3D
var expressions: Dictionary = {}
var shape_bindings: Dictionary = {}
var rest_rotations: Dictionary = {}
var rest_positions: Dictionary = {}
var motion: AisoraMotionLayers = Motion.new()
var animation_intensity: float = 1.0
var low_power: bool = true
var bone_indices: Dictionary = {}
var parent_rest_axes: Dictionary = {}
var hair_roots: Array[int] = []
var mouth: float = 0.0
var time: float = 0.0
var blink_wait: float = 2.0
var blink_time: float = -1.0
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
			var bone_name: String = skeleton.get_bone_name(i)
			bone_indices[bone_name] = i
			var parent: int = skeleton.get_bone_parent(i)
			parent_rest_axes[i] = skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
			if bone_name.begins_with("J_Sec_Hair1_") and skeleton.get_bone_name(parent) == "Head":
				hair_roots.append(i)
	# Keep the authored baseline; bounded procedural roots replace per-frame springs.
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
		motion.transition_to(next)

func play_gesture(name: String) -> bool:
	return motion.start_gesture(name)

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if skeleton == null:
		return
	time += delta
	motion.intensity = animation_intensity
	var poses: Dictionary = motion.tick(delta, mouth)
	for bone_name: String in poses:
		_world_pose(bone_name, poses[bone_name])
	var hips: int = int(bone_indices.get("Hips", -1))
	if hips >= 0:
		skeleton.set_bone_pose_position(hips, Vector3(rest_positions[hips]) + motion.hips_offset)
	# Small authored-axis root rotations provide wind/secondary lag without spring collisions.
	for i in hair_roots.size():
		var index: int = hair_roots[i]
		var hair_offset: Vector3 = Vector3.ZERO
		if not low_power or i % 2 == 0:
			var strength: float = animation_intensity * (1.0 - motion.sleep_amount * 0.8)
			hair_offset = Vector3(sin(time * 1.4 + i * 0.7) * 0.032, 0.0, sin(time * 1.1 + i) * 0.04) * strength
		skeleton.set_bone_pose_rotation(index, rest_rotations[index] * Quaternion.from_euler(hair_offset))
	# Eye rotations use the imported eye rest axes; head/gaze and eyelids never own the same track.
	_local_pose("LeftEye", Vector3(motion.gaze.y * 0.025, 0.0, motion.gaze.x * 0.065))
	_local_pose("RightEye", Vector3(motion.gaze.y * 0.025, 0.0, motion.gaze.x * 0.065))
	blink_wait -= delta
	if blink_wait <= 0.0 and blink_time < 0.0:
		blink_time = 0.0
		blink_wait = rng.randf_range(2.5, 6.5) if rng.randf() > 0.16 else 0.42
	var blink: float = 0.0
	if blink_time >= 0.0:
		blink_time += delta
		blink = sin(clampf(blink_time / 0.20, 0.0, 1.0) * PI)
		if blink_time >= 0.20:
			blink_time = -1.0
			blink = 0.0
	var sleep: float = motion.sleep_amount
	var awake: float = 1.0 - sleep
	var thought: float = float(motion.weights[State.THINKING])
	var talk: float = float(motion.weights[State.TALKING])
	# Do not invent a jaw bone: this VRM's aa morph contains the visible mouth/jaw deformation.
	# Amplitude and silence still exclusively drive the mouth; gestures cannot open it.
	_apply_expressions({"blink": lerpf(blink, 1.0, sleep), "aa": mouth * awake,
		"relaxed": (0.13 + talk * 0.12) * awake, "sad": thought * 0.10 * awake})

func _local_pose(bone_name: String, offset: Vector3) -> void:
	var index: int = int(bone_indices.get(bone_name, -1))
	if index >= 0:
		skeleton.set_bone_pose_rotation(index, rest_rotations[index] * Quaternion.from_euler(offset))

func _world_pose(bone_name: String, offset: Vector3) -> void:
	var index: int = int(bone_indices.get(bone_name, -1))
	if index < 0:
		return
	var axes: Basis = parent_rest_axes[index]
	# Explicit order permits an upper-arm twist then relaxation, with mirrored elbow flexion.
	var rotation: Basis = Basis(Vector3.BACK, offset.z) * Basis(Vector3.RIGHT, offset.x) * Basis(Vector3.UP, offset.y)
	var local_delta: Quaternion = (axes.inverse() * rotation * axes).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, local_delta * rest_rotations[index])

func _apply_expressions(values: Dictionary) -> void:
	for binding: Dictionary in shape_bindings.values():
		binding.mesh.set_blend_shape_value(binding.shape, 0.0)
	for expression_name: String in values:
		for binding: Dictionary in expressions.get(expression_name, []):
			var mesh: MeshInstance3D = binding.mesh
			var current: float = mesh.get_blend_shape_value(binding.shape)
			mesh.set_blend_shape_value(binding.shape, clampf(current + binding.value * float(values[expression_name]), 0.0, 1.0))
