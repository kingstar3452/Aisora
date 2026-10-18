class_name AisoraGroundGuide
extends Node2D
var points: PackedVector2Array=PackedVector2Array()
func show_region(camera: Camera3D,center: Vector3,width: float,depth: float,on: bool) -> void:
 visible=on
 if not on:return
 points.clear()
 for corner: Vector3 in [Vector3(-width*.5,0,-depth*.5),Vector3(width*.5,0,-depth*.5),Vector3(width*.5,0,depth*.5),Vector3(-width*.5,0,depth*.5)]:
  var point: Vector3=center+corner
  if camera.is_position_behind(point):visible=false;return
  points.append(camera.unproject_position(point))
 queue_redraw()
func _draw() -> void:
 if points.size()!=4:return
 draw_colored_polygon(points,Color(.4,.9,.75,.055))
 var outline: PackedVector2Array=points.duplicate();outline.append(points[0]);draw_polyline(outline,Color(.4,.9,.75,.8),2.,true)
