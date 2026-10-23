class_name AisoraGroundGuide
extends Node2D
var seat_points: PackedVector2Array=PackedVector2Array()
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
func show_seat(camera: Camera3D,center: Vector3,height: float,scale_value: float,on: bool) -> void:
 seat_points.clear()
 if not on:queue_redraw();return
 for corner: Vector3 in [Vector3(-.22,height,-.48),Vector3(.22,height,-.48),Vector3(.22,height,-.12),Vector3(-.22,height,-.12)]:
  var point: Vector3=center+corner*scale_value
  if camera.is_position_behind(point):seat_points.clear();return
  seat_points.append(camera.unproject_position(point))
 queue_redraw()
func _draw() -> void:
 if points.size()!=4:return
 draw_colored_polygon(points,Color(.4,.9,.75,.055))
 var outline: PackedVector2Array=points.duplicate();outline.append(points[0]);draw_polyline(outline,Color(.4,.9,.75,.8),2.,true)

 if seat_points.size()==4:
  draw_colored_polygon(seat_points,Color(.95,.75,.4,.13))
  var seat_outline: PackedVector2Array=seat_points.duplicate();seat_outline.append(seat_points[0]);draw_polyline(seat_outline,Color(.95,.75,.4,.85),2.,true)
