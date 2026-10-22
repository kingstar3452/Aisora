class_name AisoraCharacter
extends Node3D
## Layers procedural movement over the actual imported VRM rest pose and facial bindings.
const FullBody=preload("res://scripts/full_body.gd")
const Personality=preload("res://scripts/personality.gd")
const GroundMotion=preload("res://scripts/ground_motion.gd")
const PoseSafety = preload("res://scripts/pose_safety.gd")
const Motion = preload("res://scripts/motion_layers.gd")

enum State { IDLE, LISTENING, THINKING, TALKING, SLEEPING }
const STATE_NAMES: Array[String] = ["IDLE", "LISTENING", "THINKING", "TALKING", "SLEEPING"]
var body: AisoraFullBody=FullBody.new()
var profiling_enabled: bool=false
var profile_ticks: int=0
var profile_usec: PackedInt64Array=PackedInt64Array([0,0,0,0,0,0])
var ground: AisoraGroundMotion=GroundMotion.new()
var pose_safety: AisoraPoseSafety
var _safety_tail: float=0.0
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
var parent_quaternions: Dictionary = {}
var parent_inverse_quaternions: Dictionary = {}
var _offset_cache: Dictionary={}
var _rotation_cache: Dictionary={}
var _last_rotations: Dictionary = {}
var _last_hips: Vector3 = Vector3.INF
var _secondary_clock: float = 1.0
var backgrounded: bool = false
var visual_quality: int = -1
var lighting: float = 1.0
var world_tint: Color=Color.WHITE
var world_energy: float=1.0
var appearance_brightness: float=1.0
var appearance_contrast: float=1.0
var reduced_detail: bool=true
var face_clarity: bool=true
var material_slots: Array[Dictionary] = []
var _fast_materials: Dictionary = {}
var _face_meshes: Array[MeshInstance3D] = []
var _face_shapes: PackedInt32Array = PackedInt32Array()
var _face_last: PackedFloat32Array = PackedFloat32Array()
var _face_target: PackedFloat32Array = PackedFloat32Array()
var _face_bindings: Array[Array] = []
var _personality_dirty: bool=false
var _personality_bindings: Array[Dictionary]=[]
var _personality_last: PackedFloat32Array=PackedFloat32Array()
var _face_weights: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0])
var bone_writes: int = 0
var face_writes: int = 0
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
			parent_quaternions[i] = Basis(parent_rest_axes[i]).get_rotation_quaternion()
			parent_inverse_quaternions[i] = Quaternion(parent_quaternions[i]).inverse()
			_last_rotations[i] = rest_rotations[i]
			if bone_name.begins_with("J_Sec_Hair1_") and skeleton.get_bone_name(parent) == "Head":
				hair_roots.append(i)
	# Keep the authored baseline; bounded procedural roots replace per-frame springs.
	_disable_secondary(model)
	pose_safety=PoseSafety.new(self)
	ground.setup(self)
	body.setup(self)
	_cache_face_bindings()
	_cache_personality()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			material_slots.append({"mesh": mesh, "surface": surface, "original": mesh.get_active_material(surface)})

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
	var sampled_at: int=Time.get_ticks_usec() if profiling_enabled else 0
	time += delta
	motion.intensity = animation_intensity
	body.advance(self,delta)
	var poses: Dictionary = motion.tick(delta, mouth)
	body.compose(self,poses)
	if profiling_enabled:sampled_at=_profile_stamp(0,sampled_at)
	_safety_tail=0.6 if not motion.gesture.is_empty() else maxf(0.,_safety_tail-delta)
	pose_safety.constrain(poses,motion.hips_offset,minf(delta,.1),_safety_tail>0. and not body.active)
	if profiling_enabled:sampled_at=_profile_stamp(1,sampled_at)
	for bone_name: String in poses:
		_world_pose(bone_name, poses[bone_name])
	var hips: int = int(bone_indices.get("Hips", -1))
	if hips >= 0:
		var position_target: Vector3 = Vector3(rest_positions[hips]) + motion.hips_offset
		if not position_target.is_equal_approx(_last_hips):
			skeleton.set_bone_pose_position(hips, position_target)
			_last_hips = position_target
	if profiling_enabled:sampled_at=_profile_stamp(2,sampled_at)
	# Secondary animation gets its own lower rate; primary gesture/breath poses stay continuous.
	_secondary_clock += delta
	var secondary_interval: float = 0.25 if backgrounded else (0.125 if low_power or visual_quality == 0 else 0.083333)
	if _secondary_clock >= secondary_interval or animation_intensity == 0.0:
		_secondary_clock = 0.0
		for i in hair_roots.size():
			var index: int = hair_roots[i]
			var hair_offset: Vector3 = Vector3.ZERO
			if (not low_power or i % 2 == 0) and not body.active:
				var strength: float = animation_intensity * (1.0 - motion.sleep_amount * 0.8)
				hair_offset = Vector3(sin(time * 1.4 + i * 0.7) * 0.032, 0.0, sin(time * 1.1 + i) * 0.04) * strength
			if not body.active:_write_rotation(index, rest_rotations[index] * Quaternion.from_euler(hair_offset))
	# Eye motion stays at the full animation rate; only hair roots are sampled.
	var roll: float=motion.personality_envelope if motion.gesture=="eye_roll" else 0.
	var cursor: Vector2=motion.cursor_gaze if motion.cursor_eyes else Vector2.ZERO
	_local_pose("LeftEye", Vector3(cursor.y*.035+motion.gaze.y * 0.025-roll*.16, 0.0, motion.gaze.x * 0.065+roll*.06-cursor.x*.06))
	_local_pose("RightEye", Vector3(cursor.y*.035+motion.gaze.y * 0.025-roll*.16, 0.0, motion.gaze.x * 0.065+roll*.06-cursor.x*.06))
	if profiling_enabled:sampled_at=_profile_stamp(3,sampled_at)
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
	_face_weights[0] = lerpf(blink, 1.0, sleep)
	_face_weights[1] = mouth * awake
	_face_weights[2] = (0.13 + talk * 0.12) * awake
	_face_weights[3] = thought * 0.10 * awake
	_update_face()
	_update_personality(blink,sleep)
	if profiling_enabled:sampled_at=_profile_stamp(4,sampled_at)
	ground.tick(self,delta)
	body.apply(self)
	if profiling_enabled:_profile_stamp(5,sampled_at);profile_ticks+=1

func _local_pose(bone_name: String, offset: Vector3) -> void:
	var index: int = int(bone_indices.get(bone_name, -1))
	if index >= 0:
		_write_rotation(index, rest_rotations[index] * Quaternion.from_euler(offset))

func _world_pose(bone_name: String, offset: Vector3) -> void:
	var index: int = int(bone_indices.get(bone_name, -1))
	if index < 0:
		return
	if offset == Vector3.ZERO and Quaternion(_last_rotations[index]).is_equal_approx(rest_rotations[index]):
		return
	if _offset_cache.get(index,Vector3.INF)==offset:
		_write_rotation(index,_rotation_cache[index]);return
	# Cached rest-axis quaternions avoid per-bone matrix inversion/conversion every frame.
	var world_rotation: Quaternion = Quaternion(Vector3.BACK, offset.z) * Quaternion(Vector3.RIGHT, offset.x) * Quaternion(Vector3.UP, offset.y)
	var local_delta: Quaternion = parent_inverse_quaternions[index] * world_rotation * parent_quaternions[index]
	_offset_cache[index]=offset;_rotation_cache[index]=local_delta*rest_rotations[index]
	_write_rotation(index,_rotation_cache[index])

func _write_rotation(index: int, rotation: Quaternion) -> void:
	if not rotation.is_equal_approx(_last_rotations[index]):
		skeleton.set_bone_pose_rotation(index, rotation)
		_last_rotations[index] = rotation
		bone_writes += 1

func _cache_face_bindings() -> void:
	var slots: Dictionary = {}
	# Only the four owned facial layers are evaluated. Other imported expressions remain available.
	for expression_name: String in ["blink", "aa", "relaxed", "sad"]:
		var bindings: Array = []
		for binding: Dictionary in expressions.get(expression_name, []):
			var key: String = "%d:%d" % [binding.mesh.get_instance_id(), binding.shape]
			if not slots.has(key):
				slots[key] = _face_meshes.size()
				_face_meshes.append(binding.mesh)
				_face_shapes.append(binding.shape)
				_face_last.append(0.0)
				_face_target.append(0.0)
			bindings.append(Vector2(float(slots[key]), binding.value))
		_face_bindings.append(bindings)

func _update_face() -> void:
	_face_target.fill(0.0)
	for expression_index in _face_bindings.size():
		for binding: Vector2 in _face_bindings[expression_index]:
			_face_target[int(binding.x)] += binding.y * _face_weights[expression_index]
	for slot in _face_shapes.size():
		var value: float = clampf(_face_target[slot], 0.0, 1.0)
		if absf(value - _face_last[slot]) > 0.0001 or (value == 0.0 and _face_last[slot] != 0.0):
			_face_meshes[slot].set_blend_shape_value(_face_shapes[slot], value)
			_face_last[slot] = value
			face_writes += 1

func set_visual_quality(preset: int) -> void:
	preset = clampi(preset, 0, 2)
	if preset == visual_quality:
		return
	visual_quality = preset
	_apply_mesh_detail()
	for slot: Dictionary in material_slots:
		var original: ShaderMaterial = slot.original as ShaderMaterial
		if original == null:
			continue
		if preset == 2:
			slot.mesh.set_surface_override_material(slot.surface, original)
			continue
		var cache_key: String = "%d:%d" % [original.get_instance_id(), preset]
		if not _fast_materials.has(cache_key):
			var shader_name: String = original.shader.resource_path.get_file()
			var suffix: String = ""
			if shader_name.contains("trans"):
				suffix = "_alpha_double" if shader_name.contains("cull_off") else "_alpha"
			elif shader_name.contains("cull_off"):
				suffix = "_double"
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = load("res://assets/character/simple_toon%s.gdshader" % suffix)
			material.resource_name = original.resource_name + " (efficient)"
			material.render_priority = original.render_priority
			for parameter: String in ["_MainTex", "_Color", "_MainTex_ST", "_Cutoff"]:
				var value: Variant = original.get_shader_parameter(parameter)
				if value != null: material.set_shader_parameter(parameter, value)
			var base_color: Color = original.get_shader_parameter("_Color")
			material.set_shader_parameter("_Color",_lit_color(base_color))
			material.set_shader_parameter("shade_strength", 0.10 if preset == 0 else 0.16)
			material.set_shader_parameter("face_clarity",1. if face_clarity and slot.mesh.name=="Face" else 0.)
			_apply_material_appearance(material)
			_fast_materials[cache_key] = material
		slot.mesh.set_surface_override_material(slot.surface, _fast_materials[cache_key])

func _lit_color(color: Color) -> Color:
	var gain: float = 0.8+lighting*0.2
	return Color(color.r*gain,color.g*gain,color.b*gain,color.a)

func set_lighting(value: float) -> void:
	if is_equal_approx(value,lighting): return
	lighting = value
	# Preset/slider events only. Keep the source colors and transparency intact.
	for slot: Dictionary in material_slots:
		for preset in 2:
			var key: String = "%d:%d" % [slot.original.get_instance_id(),preset]
			if _fast_materials.has(key):
				_fast_materials[key].set_shader_parameter("_Color",_lit_color(slot.original.get_shader_parameter("_Color")))

func _apply_mesh_detail() -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		# Use the importer's existing index LODs; never replace the facial mesh/expressions.
		mesh.lod_bias=128. if mesh.name=="Face" and face_clarity else ([0.4,0.7,1.0][clampi(visual_quality,0,2)] if reduced_detail and mesh.name!="Face" else 1.0)

func set_face_clarity(on: bool) -> void:
	if face_clarity==on:return
	face_clarity=on;_apply_mesh_detail()
	for slot: Dictionary in material_slots:
		for preset in 2:
			var key: String="%d:%d"%[slot.original.get_instance_id(),preset]
			if _fast_materials.has(key):_fast_materials[key].set_shader_parameter("face_clarity",1. if on and slot.mesh.name=="Face" else 0.)

func set_detail_reduction(on: bool) -> void:
	if reduced_detail==on:return
	reduced_detail=on
	if model!=null:_apply_mesh_detail()

func set_appearance(tint: Color,energy: float,brightness: float,contrast: float) -> void:
	if tint.is_equal_approx(world_tint) and is_equal_approx(energy,world_energy) and is_equal_approx(brightness,appearance_brightness) and is_equal_approx(contrast,appearance_contrast):return
	world_tint=tint;world_energy=energy;appearance_brightness=brightness;appearance_contrast=contrast
	for material: ShaderMaterial in _fast_materials.values():_apply_material_appearance(material)

func _apply_material_appearance(material: ShaderMaterial) -> void:
	material.set_shader_parameter("world_tint",Color(world_tint.r,world_tint.g,world_tint.b,1))
	material.set_shader_parameter("world_energy",world_energy*appearance_brightness)
	material.set_shader_parameter("appearance_contrast",appearance_contrast)

func _cache_personality() -> void:
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name!="Face":continue
		for name_value: String in Personality.SHAPES:
			var shape: int=mesh.find_blend_shape_by_name(name_value)
			if shape>=0:_personality_bindings.append({"mesh":mesh,"shape":shape,"index":Personality.SHAPES.find(name_value)})
	_personality_last.resize(_personality_bindings.size());_personality_last.fill(0.)

func _update_personality(blink: float,sleep: float) -> void:
	if motion.personality_envelope<=0. and not _personality_dirty:return
	_personality_dirty=motion.personality_envelope>0.
	for i in _personality_bindings.size():
		var binding: Dictionary=_personality_bindings[i]
		var value: float=Personality.face(motion.gesture,binding.index)*motion.personality_envelope*(1.-sleep)
		if binding.index in [4,5,6]:value*=1.-blink
		if binding.index>=7:value*=1.-mouth
		if not is_equal_approx(value,_personality_last[i]):
			binding.mesh.set_blend_shape_value(binding.shape,value);_personality_last[i]=value;face_writes+=1

func _profile_stamp(stage: int,started: int) -> int:
	var now: int=Time.get_ticks_usec();profile_usec[stage]+=now-started;return now
