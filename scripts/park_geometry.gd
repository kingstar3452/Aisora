class_name AisoraParkGeometry
extends RefCounted
## Build once: merged opaque vertex-painted geometry with baked soft directional shading.
var surface: SurfaceTool = SurfaceTool.new()
var triangle_count: int = 0
func _init() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3 = Vector3.UP) -> void:
	var shade: float = 0.78 + maxf(0.0, normal.dot(Vector3(-0.4, 0.8, 0.5).normalized())) * 0.22
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(Color(color.r * shade, color.g * shade, color.b * shade))
		surface.add_vertex(vertex)
	triangle_count += 1
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, normal: Vector3 = Vector3.UP) -> void:
	triangle(a, b, c, color, normal)
	triangle(a, c, d, color, normal)
func box(size: Vector3, at: Vector3, color: Color, rotation: Basis = Basis.IDENTITY) -> void:
	var p: Array[Vector3] = []
	for v: Vector3 in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:
		p.append(at + rotation * (v * size * 0.5))
	var faces: Array = [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]
	var normals: Array[Vector3] = [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN]
	for i in 6:
		var f: Array = faces[i]
		quad(p[f[0]],p[f[1]],p[f[2]],p[f[3]],color,rotation * normals[i])
func tube(points: Array[Vector3], radius: float, tip_radius: float, color: Color, sides: int = 7) -> void:
	for i in points.size() - 1:
		var direction: Vector3 = (points[i+1] - points[i]).normalized()
		var reference: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.9 else Vector3.UP
		var x: Vector3 = direction.cross(reference).normalized()
		var z: Vector3 = direction.cross(x).normalized()
		var r0: float = lerpf(radius, tip_radius, float(i) / (points.size() - 1))
		var r1: float = lerpf(radius, tip_radius, float(i+1) / (points.size() - 1))
		for j in sides:
			var a: float = TAU * j / sides
			var b: float = TAU * (j+1) / sides
			var n0: Vector3 = x * cos(a) + z * sin(a)
			var n1: Vector3 = x * cos(b) + z * sin(b)
			var ridge0: float = 1.0 + sin(a * 3.0 + i * 0.5) * 0.045
			var ridge1: float = 1.0 + sin(b * 3.0 + i * 0.5) * 0.045
			quad(points[i] + n0*r0*ridge0, points[i+1] + n0*r1*ridge0, points[i+1] + n1*r1*ridge1, points[i] + n1*r0*ridge1, color, (n0+n1).normalized())
func finish() -> ArrayMesh:
	return surface.commit()
func dome(at: Vector3, size: Vector3, color: Color) -> void:
	# Rounded distant shrubs; a merged mesh with baked shading, no live lights.
	for row in 6:
		for column in 16:
			var corners: Array[Vector3] = []
			for uv: Vector2 in [Vector2(column,row),Vector2(column+1,row),Vector2(column+1,row+1),Vector2(column,row+1)]:
				var angle: float = uv.x*TAU/16.0
				var elevation: float = uv.y*PI/12.0
				corners.append(Vector3(cos(angle)*cos(elevation),sin(elevation),sin(angle)*cos(elevation)))
			for index: int in [0,1,2,0,2,3]:
				var normal: Vector3 = corners[index]
				# Per-vertex baked color interpolates smoothly across the low-poly dome.
				var shade: float = 0.85+maxf(0.0,normal.dot(Vector3(-0.4,0.8,0.5).normalized()))*0.15
				surface.set_normal(normal)
				surface.set_color(Color(color.r*shade,color.g*shade,color.b*shade))
				surface.add_vertex(at+normal*size)
			triangle_count += 2
static func curve(a: Vector3, b: Vector3, c: Vector3, d: Vector3, steps: int = 7) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in steps + 1:
		var t: float = float(i) / steps
		points.append(a.bezier_interpolate(b,c,d,t))
	return points
