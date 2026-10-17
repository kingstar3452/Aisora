class_name AisoraSakuraPark
extends Node3D
## Original procedural geometry only. Shared meshes/materials and bounded MultiMeshes.
## No physics, shadow maps, textures, external assets or particle simulation service.
const MAX_PETALS: int = 56
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var petal_density: float = 0.45
var low_power: bool = false
var resting: bool = false
var suspended: bool = false
var time: float = 0.0
var petal_clock: float = 0.0
var petals: MultiMeshInstance3D
var blossom_batches: Array[MultiMeshInstance3D] = []
var grass_batch: MultiMeshInstance3D
var petal_positions: Array[Vector3] = []
var petal_speeds: PackedFloat32Array = PackedFloat32Array()
var petal_phases: PackedFloat32Array = PackedFloat32Array()
var tree_count: int = 0
var trunk_transforms: Array[Transform3D] = []
var branch_transforms: Array[Transform3D] = []
var bench: Node3D
var material_cache: Dictionary = {}

func _ready() -> void:
	rng.seed = 20261018
	_build_ground()
	_build_trees()
	_build_bench()
	_build_lantern(Vector3(-1.25, 0.0, -1.6))
	_build_petals()
	apply_performance()

func _material(hex_color: String, vertex_colors: bool = false) -> StandardMaterial3D:
	var key: String = hex_color + str(vertex_colors)
	if material_cache.has(key):
		return material_cache[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(hex_color)
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = vertex_colors
	material_cache[key] = material
	return material

func _mesh_instance(mesh: Mesh, material: Material, location: Vector3, parent: Node = self) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _box(size: Vector3, location: Vector3, material: Material, parent: Node = self) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh_instance(mesh, material, location, parent)

func _batch(mesh: Mesh, material: Material, transforms: Array[Transform3D], batch_name: String, parent: Node = self) -> MultiMeshInstance3D:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = MultiMesh.new()
	instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instance.multimesh.mesh = mesh
	instance.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		instance.multimesh.set_instance_transform(i, transforms[i])
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _build_ground() -> void:
	var grass: PlaneMesh = PlaneMesh.new()
	grass.size = Vector2(90.0, 90.0)
	_mesh_instance(grass, _material("86ae7b"), Vector3(0.0, -0.025, -15.0)).name = "GrassGround"
	# A gently curving strip through the park. One opaque mesh, not layered transparent planes.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var z0: float = 4.0 - i * 1.2
		var z1: float = z0 - 1.2
		var x0: float = _path_center(z0)
		var x1: float = _path_center(z1)
		var a: Vector3 = Vector3(x0 - 0.72, -0.016, z0)
		var b: Vector3 = Vector3(x0 + 0.72, -0.016, z0)
		var c: Vector3 = Vector3(x1 - 0.72, -0.016, z1)
		var d: Vector3 = Vector3(x1 + 0.72, -0.016, z1)
		for vertex: Vector3 in [a, c, b, b, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	_mesh_instance(surface.commit(), _material("e3c8a2"), Vector3.ZERO).name = "WalkingPath"
	# Flat contact oval under her feet, deliberately static and inexpensive.
	var contact: CylinderMesh = CylinderMesh.new()
	contact.top_radius = 0.30
	contact.bottom_radius = 0.30
	contact.height = 0.002
	contact.radial_segments = 32
	var shadow: MeshInstance3D = _mesh_instance(contact, _material("c4ac8c"), Vector3(0.0, -0.012, 0.0))
	shadow.scale.z = 0.58
	shadow.name = "CharacterContact"
	# Distant round garden hills conceal the ground boundary without expensive fog.
	var hill_mesh: SphereMesh = SphereMesh.new()
	hill_mesh.radial_segments = 12
	hill_mesh.rings = 6
	hill_mesh.radius = 1.0
	hill_mesh.height = 2.0
	var hills: Array[Transform3D] = []
	for i in 8:
		hills.append(Transform3D(Basis.IDENTITY.scaled(Vector3(6.0, rng.randf_range(1.0, 2.3), 3.0)), Vector3(-20.0 + i * 6.0, 0.0, -21.0 - (i % 2) * 3.0)))
	_batch(hill_mesh, _material("93b7a0"), hills, "DistantGarden")
	var tuft: PrismMesh = PrismMesh.new()
	tuft.size = Vector3(0.09, 0.16, 0.045)
	var tufts: Array[Transform3D] = []
	for i in 160:
		var x: float = rng.randf_range(-7.0, 7.0)
		var z: float = rng.randf_range(-13.0, 1.5)
		if absf(x - _path_center(z)) < 0.86:
			continue
		var scale_value: float = rng.randf_range(0.5, 1.0)
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value), Vector3(x, 0.06 * scale_value, z)))
	grass_batch = _batch(tuft, _material("6b9863"), tufts, "GrassTufts")
	# Fallen blossoms along the path edges, another single batch.
	var fallen: Array[Transform3D] = []
	var petal_mesh: SphereMesh = _petal_mesh()
	for i in 80:
		var z: float = rng.randf_range(-12.0, 1.5)
		var x: float = _path_center(z) + rng.randf_range(-1.15, 1.15)
		fallen.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(0.8, 0.12, 0.8)), Vector3(x, -0.009, z)))
	_batch(petal_mesh, _material("f4ced8"), fallen, "FallenBlossoms")

func _path_center(z: float) -> float:
	return sin(minf(z, 0.0) * 0.25) * 1.5

func _build_trees() -> void:
	var blossom_mesh: SphereMesh = SphereMesh.new()
	blossom_mesh.radius = 1.0
	blossom_mesh.height = 2.0
	blossom_mesh.radial_segments = 8
	blossom_mesh.rings = 4
	var blooms: Array[Array] = [[], [], []]
	var locations: Array[Vector3] = [Vector3(-2.35, 0, -2.5), Vector3(2.5, 0, -2.9), Vector3(-3.9, 0, -5.8), Vector3(3.9, 0, -6.1), Vector3(-2.4, 0, -9.0), Vector3(1.5, 0, -10.4), Vector3(-5.0, 0, -12.0), Vector3(5.3, 0, -12.6)]
	for location: Vector3 in locations:
		tree_count += 1
		var height: float = rng.randf_range(2.4, 3.1)
		_branch(location, location + Vector3(0.12, height * 0.75, 0.05), 0.13)
		for i in 5:
			var angle: float = i * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
			var spread: Vector3 = Vector3(cos(angle) * 0.85, 0.0, sin(angle) * 0.7)
			var tip: Vector3 = location + spread + Vector3(0.0, height, 0.0)
			_branch(location + Vector3(0.04, height * 0.5, 0.0), tip, 0.052)
			for j in 5:
				var offset: Vector3 = Vector3(rng.randf_range(-0.42, 0.42), rng.randf_range(-0.20, 0.30), rng.randf_range(-0.36, 0.36))
				var size: Vector3 = Vector3(rng.randf_range(0.40, 0.63), rng.randf_range(0.33, 0.49), rng.randf_range(0.40, 0.61))
				var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), 0.0)).scaled(size)
				blooms[(i + j + tree_count) % 3].append(Transform3D(basis, tip + offset))
	for tree_part: String in ["Trunks", "Branches"]:
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.bottom_radius = 1.0
		cylinder.top_radius = 0.5 if tree_part == "Trunks" else 0.35
		cylinder.height = 1.0
		cylinder.radial_segments = 6
		_batch(cylinder, _material("775951"), trunk_transforms if tree_part == "Trunks" else branch_transforms, "Sakura" + tree_part)
	var colors: Array[String] = ["e9a8bb", "f5c5d1", "fbdbe1"]
	for i in 3:
		var transforms: Array[Transform3D] = []
		for transform: Transform3D in blooms[i]:
			transforms.append(transform)
		blossom_batches.append(_batch(blossom_mesh, _material(colors[i]), transforms, "SakuraBlossoms%d" % i))

func _branch(from: Vector3, to: Vector3, radius: float) -> void:
	var direction: Vector3 = (to - from).normalized()
	# Scale in cylinder-local axes, then rotate into the branch direction.
	var basis: Basis = Basis(Quaternion(Vector3.UP, direction)) * Basis.from_scale(Vector3(radius, from.distance_to(to), radius))
	var transform: Transform3D = Transform3D(basis, (from + to) * 0.5)
	if radius > 0.1:
		trunk_transforms.append(transform)
	else:
		branch_transforms.append(transform)

func _build_bench() -> void:
	bench = Node3D.new()
	bench.name = "WoodenBench"
	bench.position = Vector3(1.35, 0.0, -1.45)
	bench.rotation.y = -0.16
	add_child(bench)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	var frame: Array[Transform3D] = []
	var slats: Array[Transform3D] = []
	for x: float in [-0.53, 0.53]:
		frame.append(Transform3D(Basis.from_scale(Vector3(0.075, 0.42, 0.075)), Vector3(x, 0.20, 0.17)))
		frame.append(Transform3D(Basis.from_scale(Vector3(0.075, 0.80, 0.075)), Vector3(x, 0.39, -0.18)))
	for i in 4:
		slats.append(Transform3D(Basis.from_scale(Vector3(1.36, 0.055, 0.085)), Vector3(0.0, 0.43, -0.15 + i * 0.10)))
	for i in 3:
		slats.append(Transform3D(Basis.from_scale(Vector3(1.36, 0.09, 0.045)), Vector3(0.0, 0.58 + i * 0.12, -0.18)))
	_batch(box, _material("755b49"), frame, "Frame", bench)
	_batch(box, _material("b08057"), slats, "SeatAndBack", bench)

func _build_lantern(location: Vector3) -> void:
	var stone: Material = _material("9aaba3")
	_box(Vector3(0.36, 0.08, 0.36), location + Vector3(0, 0.03, 0), stone)
	_box(Vector3(0.12, 0.40, 0.12), location + Vector3(0, 0.25, 0), stone)
	_box(Vector3(0.25, 0.22, 0.25), location + Vector3(0, 0.54, 0), stone)
	_box(Vector3(0.12, 0.10, 0.255), location + Vector3(0, 0.55, 0), _material("dccb99"))
	var roof: CylinderMesh = CylinderMesh.new()
	roof.radial_segments = 4
	roof.top_radius = 0.08
	roof.bottom_radius = 0.30
	roof.height = 0.14
	_mesh_instance(roof, stone, location + Vector3(0, 0.72, 0)).rotation.y = PI / 4.0

func _petal_mesh() -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.026
	mesh.height = 0.015
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

func _build_petals() -> void:
	var transforms: Array[Transform3D] = []
	for i in MAX_PETALS:
		var location: Vector3 = Vector3(rng.randf_range(-3.6, 3.6), rng.randf_range(0.1, 4.3), rng.randf_range(-7.5, 0.7))
		petal_positions.append(location)
		petal_speeds.append(rng.randf_range(0.13, 0.26))
		petal_phases.append(rng.randf_range(0.0, TAU))
		transforms.append(Transform3D(Basis.IDENTITY, location))
	petals = _batch(_petal_mesh(), _material("f9cedc"), transforms, "FallingPetals")
	petals.multimesh.custom_aabb = AABB(Vector3(-5, -0.2, -9), Vector3(10, 5, 11))

func apply_performance() -> void:
	if petals == null:
		return
	var count: int = int(round(MAX_PETALS * clampf(petal_density, 0.0, 1.0)))
	if low_power:
		count = mini(count, 12)
	if resting:
		count = mini(count, 6)
	petals.multimesh.visible_instance_count = count
	grass_batch.multimesh.visible_instance_count = mini(grass_batch.multimesh.instance_count, 64) if low_power else -1

func _process(delta: float) -> void:
	if suspended or petals == null or petals.multimesh.visible_instance_count == 0:
		return
	petal_clock += delta
	var interval: float = 0.1 if low_power or resting else 0.05
	if petal_clock < interval:
		return
	# No catch-up loops on resume; hidden petals consume no update work.
	var dt: float = minf(petal_clock, 0.2)
	petal_clock = 0.0
	time += dt
	for i in petals.multimesh.visible_instance_count:
		var location: Vector3 = petal_positions[i]
		location.y -= petal_speeds[i] * dt
		location.x += (0.07 + sin(time * 0.8 + petal_phases[i]) * 0.045) * dt
		if location.y < 0.0 or location.x > 4.5:
			location = Vector3(rng.randf_range(-3.6, 2.5), rng.randf_range(3.2, 4.3), rng.randf_range(-7.5, 0.7))
		petal_positions[i] = location
		var basis: Basis = Basis.from_euler(Vector3(time * 0.9 + petal_phases[i], petal_phases[i], sin(time + petal_phases[i]) * 0.6))
		petals.multimesh.set_instance_transform(i, Transform3D(basis, location))
