class_name AisoraSakuraPark
extends Node3D
## Original baked art + instanced cutout canopies. Build geometry once; no per-frame mesh work.
const Geometry = preload("res://scripts/park_geometry.gd")
const MAX_PETALS: int = 56
const TREE_LOCATIONS: Array[Vector3] = [Vector3(-2.5,0,-3.0),Vector3(2.3,0,-3.8),Vector3(-3.7,0,-6.8),Vector3(3.9,0,-7.8),Vector3(-1.3,0,-10),Vector3(2.6,0,-11.8),Vector3(-5,0,-15),Vector3(5,0,-16)]
var build_on_ready: bool = true
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var petal_density: float = 0.45
var quality: int = 0
var low_power: bool = false
var resting: bool = false
var suspended: bool = false:
	set(value):
		if suspended == value: return
		suspended = value
		_update_pause()
var petals: MultiMeshInstance3D
var petal_material: ShaderMaterial
var blossom_batches: Array[MultiMeshInstance3D] = []
var grass_batch: MultiMeshInstance3D
var tree_count: int = 0
var bench: Node3D
var branch_count: int = 0
var _canopy_full_count: int = 0
var _pause_started: float = 0.0
var _time_origin: float = 0.0
var _paint: StandardMaterial3D

func _ready() -> void:
	set_process(false)
	if build_on_ready:ensure_built()

func ensure_built() -> void:
	if petals!=null:return
	rng.seed = 31018
	_paint = StandardMaterial3D.new()
	_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_paint.vertex_color_use_as_albedo = true
	_paint.vertex_color_is_srgb = true
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_ground()
	_build_trees()
	_build_props()
	_build_grass()
	_build_petals()
	if suspended:_update_pause()
	apply_performance()
	set_process(false)

func _mesh(mesh: Mesh, material: Material, object_name: String, parent: Node = self) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = object_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _batch(mesh: Mesh, material: Material, transforms: Array[Transform3D], object_name: String, colors: Array[Color] = []) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = object_name
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.use_colors = not colors.is_empty()
	instance.multimesh.mesh = mesh
	instance.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		instance.multimesh.set_instance_transform(i, transforms[i])
		if not colors.is_empty(): instance.multimesh.set_instance_color(i, colors[i])
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _ground_tint(at: Vector3) -> Color:
	var shade: float = 1.0
	for tree: Vector3 in TREE_LOCATIONS:
		var distance: float = Vector2(at.x-tree.x-0.5, (at.z-tree.z)*0.75).length()
		shade -= exp(-distance*distance*0.75) * 0.12
	shade -= exp(-Vector2(at.x*3.0, at.z*5.0).length_squared()) * 0.13
	# Low-contrast baked dappled shade, no noise or shadow calculation in the fragment shader.
	shade -= (sin(at.x*7.1 + at.z*2.3) * sin(at.z*5.3-at.x) * 0.5 + 0.5) * 0.025
	return Color(shade, shade, shade)

func _path_center(z: float) -> float:
	return sin(minf(z,0.0)*0.23)*1.6 + sin(minf(z,0.0)*0.51)*0.20

func _build_ground() -> void:
	var ground: SurfaceTool = SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in 38:
		for xi in 40:
			var x: float = -20.0 + xi
			var z: float = 5.0 - zi
			for v: Vector3 in [Vector3(x, -0.025,z),Vector3(x,-0.025,z-1),Vector3(x+1,-0.025,z),Vector3(x+1,-0.025,z),Vector3(x,-0.025,z-1),Vector3(x+1,-0.025,z-1)]:
				ground.set_normal(Vector3.UP)
				ground.set_color(_ground_tint(v))
				ground.set_uv(Vector2(v.x,v.z)*0.8)
				ground.add_vertex(v)
	var grass_material: StandardMaterial3D = _paint.duplicate()
	grass_material.albedo_texture = load("res://assets/park/grass_tile.svg")
	grass_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mesh(ground.commit(),grass_material,"GrassGround")
	var path: SurfaceTool = SurfaceTool.new()
	path.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 90:
		var z0: float = 4.0-i*0.36
		var z1: float = z0-0.36
		for j in 8:
			var t0: float = float(j)/8.0
			var t1: float = float(j+1)/8.0
			for p: Vector2 in [Vector2(t0,z0),Vector2(t0,z1),Vector2(t1,z0),Vector2(t1,z0),Vector2(t0,z1),Vector2(t1,z1)]:
				var half_width: float = 0.72 + sin(p.y*1.7)*0.035 + sin(p.y*3.2)*0.018
				var point: Vector3 = Vector3(_path_center(p.y)+(p.x*2.0-1.0)*half_width, -0.015, p.y)
				var edge: float = pow(absf(p.x*2.0-1.0), 12.0)*0.70
				var color: Color = Color("d8c8b2").lerp(Color("acbf96"),edge)
				color *= _ground_tint(point)
				path.set_normal(Vector3.UP)
				path.set_color(color)
				path.add_vertex(point)
	_mesh(path.commit(),_paint,"WalkingPath")
	# Layered distant garden silhouettes with a pale atmospheric tint.
	var distant: Geometry = Geometry.new()
	for i in 24:
		var x: float = -20.0+i*1.8
		var h: float = 1.25+sin(i*1.8)*0.45
		distant.dome(Vector3(x,-0.12,-24.0+sin(i)*1.3),Vector3(1.9,h,1.5),Color("b5c9bd").lerp(Color("c9d6cc"),float(i%3)*0.15))
	_mesh(distant.finish(),_paint,"DistantGarden")

func _build_trees() -> void:
	var wood: Geometry = Geometry.new()
	var card_sets: Array[Array] = []
	for tree in TREE_LOCATIONS.size():
		var root: Vector3 = TREE_LOCATIONS[tree]
		var direction: float = 1.0 if root.x < 0.0 else -1.0
		var height: float = rng.randf_range(2.5,3.0)
		var tip: Vector3 = root+Vector3(direction*0.48,height,0.12)
		var trunk: Array[Vector3] = Geometry.curve(root,root+Vector3(-direction*0.34,0.9,0.14),tip-Vector3(direction*0.35,0.65,0.32),tip,10)
		var depth_tint: float = clampf((-root.z-4.0)/20.0,0.0,0.55)
		var bark: Color = Color("715a64").lerp(Color("bdabb9"),depth_tint)
		wood.tube(trunk,0.19,0.025,bark,9)
		var cards: Array[Transform3D] = []
		for arm in 5:
			var angle: float = arm*TAU/5.0 + tree*0.32
			var end: Vector3 = tip+Vector3(cos(angle)*0.92, rng.randf_range(-0.25,0.12), sin(angle)*0.72)
			var start: Vector3 = trunk[4+arm%4]
			var limb: Array[Vector3] = Geometry.curve(start,start+Vector3(cos(angle)*0.65,0.18,sin(angle)*0.42),end-Vector3(cos(angle)*0.35,0.02,sin(angle)*0.25),end,8)
			wood.tube(limb,0.064,0.006,bark)
			var twig_end: Vector3 = end+Vector3(-sin(angle)*0.24,0.15,cos(angle)*0.18)
			wood.tube(Geometry.curve(limb[5],limb[6],twig_end-Vector3(0,0.12,0),twig_end,4),0.022,0.003,bark,5)
			branch_count += 1
		# Overlapping textured clusters form an airy volume rather than polygonal balls.
		for layer in 12:
			var angle: float = layer*2.39996+tree*0.4
			var radius: float = 0.28+sqrt(float(layer)/12.0)*0.80
			var center: Vector3 = tip + Vector3(cos(angle)*radius, 0.10+sin(layer*1.8)*0.25, sin(angle)*radius*0.66)
			var size: float = rng.randf_range(1.0,1.45)
			cards.append(Transform3D(Basis.from_scale(Vector3(size*1.25,size,1.0)),center))
		card_sets.append(cards)
		tree_count += 1
	_mesh(wood.finish(),_paint,"TreeWood")
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# Prefix LOD always retains every tree, instead of hiding whole trees in lower presets.
	for layer in 12:
		for tree in TREE_LOCATIONS.size():
			transforms.append(card_sets[tree][layer])
			var depth: float = clampf((-TREE_LOCATIONS[tree].z-3.0)/22.0,0.0,0.45)
			colors.append(Color.WHITE.lerp(Color("e7e4ed"),depth))
	var material: StandardMaterial3D = _paint.duplicate()
	material.vertex_color_use_as_albedo = false
	material.albedo_texture = load("res://assets/park/blossom_cluster.svg")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.4
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	blossom_batches.append(_batch(quad,material,transforms,"SakuraBlossoms",colors))
	_canopy_full_count = transforms.size()

func _build_props() -> void:
	var props: Geometry = Geometry.new()
	bench = Node3D.new()
	bench.name = "WoodenBench"
	bench.position = Vector3(1.18,0.0,-2.0)
	add_child(bench)
	var origin: Vector3 = bench.position
	var wood: Color = Color("aa836e")
	var frame: Color = Color("6f6266")
	for x: float in [-0.43,0.43]:
		props.box(Vector3(0.045,0.34,0.045),origin+Vector3(x,0.17,0.13),frame)
		props.box(Vector3(0.045,0.68,0.045),origin+Vector3(x,0.34,-0.15),frame)
		# Curved arm rests with smoothly connected tube segments.
		props.tube(Geometry.curve(origin+Vector3(x,0.35,0.17),origin+Vector3(x,0.55,0.15),origin+Vector3(x,0.53,-0.10),origin+Vector3(x,0.48,-0.15),5),0.025,0.025,wood,6)
	for i in 4:
		var at: Vector3 = origin+Vector3(0,0.35,-0.12+i*0.08)
		props.box(Vector3(1.05,0.035,0.068),at,wood.lerp(Color("c3a18b"),float(i%2)*0.15))
		# Baked grain strips are merged into the same opaque mesh, not separate materials.
		props.box(Vector3(0.93,0.001,0.004),at+Vector3(0.02,0.018,-0.015),Color("a37f6c"))
	for i in 3:
		props.box(Vector3(1.05,0.075,0.035),origin+Vector3(0,0.48+i*0.09,-0.15-i*0.01),wood)
	var lamp: Vector3 = Vector3(-1.15,0,-1.9)
	var stone: Color = Color("b0b3ad")
	props.box(Vector3(0.30,0.055,0.30),lamp+Vector3(0,0.02,0),stone)
	props.tube([lamp+Vector3(0,0.04,0),lamp+Vector3(0,0.14,0),lamp+Vector3(0,0.32,0)],0.095,0.06,stone,8)
	props.box(Vector3(0.24,0.035,0.24),lamp+Vector3(0,0.33,0),stone)
	props.box(Vector3(0.16,0.14,0.16),lamp+Vector3(0,0.42,0),Color("e6d5ad"))
	for x: float in [-0.09,0.09]:
		for z: float in [-0.09,0.09]: props.box(Vector3(0.035,0.18,0.035),lamp+Vector3(x,0.42,z),stone)
	# Curved pagoda roof profile, four overhanging eaves and a small rounded finial.
	props.tube([lamp+Vector3(0,0.51,0),lamp+Vector3(0,0.55,0),lamp+Vector3(0,0.59,0),lamp+Vector3(0,0.63,0)],0.24,0.045,stone,4)
	props.tube([lamp+Vector3(0,0.63,0),lamp+Vector3(0,0.69,0)],0.04,0.015,stone,8)
	# A distant low bridge and rail add scenery depth without dynamic water/reflections.
	for i in 10:
		var z: float = -8.55-i*0.1
		props.box(Vector3(1.1,0.035,0.085),Vector3(-1.25,0.03+sin(i*PI/9.0)*0.05,z),Color("b49a88"))
	for x: float in [-1.83,-0.67]:
		for z: float in [-8.5,-9.5]: props.box(Vector3(0.04,0.35,0.04),Vector3(x,0.17,z),Color("a28f84"))
		props.box(Vector3(0.035,0.04,1.08),Vector3(x,0.30,-9.0),Color("a28f84"))
	_mesh(props.finish(),_paint,"GardenFurniture")
	var water: Geometry = Geometry.new()
	for i in 32:
		var x: float = -12+i*0.75
		var z0: float = -9.1+sin(x*0.35)*0.45
		var z1: float = -9.1+sin((x+0.75)*0.35)*0.45
		water.quad(Vector3(x,-0.012,z0-0.30),Vector3(x,-0.012,z0+0.30),Vector3(x+0.75,-0.012,z1+0.30),Vector3(x+0.75,-0.012,z1-0.30),Color("a7c9c6"))
	_mesh(water.finish(),_paint,"QuietStream")

func _build_grass() -> void:
	var grass: Geometry = Geometry.new()
	for blade in 3:
		var x: float = (blade-1)*0.025
		var height: float = 0.07+blade*0.012
		grass.quad(Vector3(x-0.008,0,0),Vector3(x+0.008,0,0),Vector3(x+0.016,height*0.6,0.01),Vector3(x+0.004,height*0.6,0.01),Color("91ad85"))
		grass.triangle(Vector3(x+0.004,height*0.6,0.01),Vector3(x+0.016,height*0.6,0.01),Vector3(x+0.025,height,0.02),Color("b3c99b"))
	var transforms: Array[Transform3D] = []
	for i in 220:
		var x: float = rng.randf_range(-6.0,6.0)
		var z: float = rng.randf_range(-13.0,1.5)
		if absf(x-_path_center(z)) < 0.9: continue
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),Vector3(x,-0.02,z)))
	grass_batch = _batch(grass.finish(),_paint,transforms,"GrassTufts")
	var fallen_geometry: Geometry = Geometry.new()
	var a: Vector3 = Vector3(-0.014,0,0)
	fallen_geometry.quad(a,Vector3(0,-0.001,0.02),Vector3(0.014,0,0),Vector3(0,0,-0.02),Color("efd4df"))
	var fallen: Array[Transform3D] = []
	for i in 100:
		var z: float = rng.randf_range(-12,2)
		fallen.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),Vector3(_path_center(z)+rng.randf_range(-1.0,1.0),-0.01,z)))
	_batch(fallen_geometry.finish(),_paint,fallen,"FallenBlossoms")

func _build_petals() -> void:
	var mesh: ArrayMesh
	var geometry: Geometry = Geometry.new()
	geometry.quad(Vector3(-0.012,0,0),Vector3(0,0.018,0.005),Vector3(0.012,0,0),Vector3(0,-0.018,0.005),Color.WHITE,Vector3.BACK)
	mesh = geometry.finish()
	var transforms: Array[Transform3D] = []
	for i in MAX_PETALS:
		transforms.append(Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-3.8,3.8),0.0,rng.randf_range(-8,0.5))))
	petal_material = ShaderMaterial.new()
	petal_material.shader = load("res://assets/park/petals.gdshader")
	_time_origin = Time.get_ticks_msec()/1000.0
	petal_material.set_shader_parameter("time_origin",_time_origin)
	petals = _batch(mesh,petal_material,transforms,"FallingPetals")
	# Changing the buffer format requires reallocating instance_count; transforms are restored once.
	petals.multimesh.instance_count = 0
	petals.multimesh.use_custom_data = true
	petals.multimesh.instance_count = MAX_PETALS
	for i in MAX_PETALS:
		petals.multimesh.set_instance_transform(i,transforms[i])
		petals.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf_range(0,4.3),0,1))
	petals.multimesh.custom_aabb = AABB(Vector3(-5,-0.6,-9),Vector3(10,5,11))

func apply_performance() -> void:
	if petals == null: return
	var effective: int = 0 if low_power else clampi(quality,0,2)
	var count: int = int(round(MAX_PETALS*clampf(petal_density,0,1)))
	count = mini(count,[24,40,56][effective])
	if low_power: count = mini(count,12)
	if resting: count = mini(count,6)
	petals.multimesh.visible_instance_count = count
	blossom_batches[0].multimesh.visible_instance_count = [64,80,96][effective]
	grass_batch.multimesh.visible_instance_count = mini(grass_batch.multimesh.instance_count,[64,120,180][effective])

func _update_pause() -> void:
	if petal_material == null: return
	var now: float = Time.get_ticks_msec()/1000.0
	if suspended:
		_pause_started = now
		petal_material.set_shader_parameter("pause_time",now-_time_origin)
	else:
		_time_origin += now-_pause_started
		petal_material.set_shader_parameter("time_origin",_time_origin)
		petal_material.set_shader_parameter("pause_time",-1.0)

func _process(_delta: float) -> void:
	# Kept callable for the benchmark harness. There is no per-frame CPU petal simulation.
	pass
