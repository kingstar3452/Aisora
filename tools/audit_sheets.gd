extends SceneTree
## Compile captured actual-rig views into review sheets; no runtime use.
func _initialize() -> void:
 var source: String="res://.local/phase6-audit"
 for angle: int in [-65,0,65]:
  var personality: Image=Image.create(1500,600,false,Image.FORMAT_RGB8)
  var names: Array[String]=load("res://scripts/personality.gd").IDS
  for i in names.size():
   var picture: Image=Image.load_from_file(source.path_join("personality-%s-%d.png"%[names[i],angle]));picture.convert(Image.FORMAT_RGB8);picture.resize(300,300,Image.INTERPOLATE_LANCZOS);personality.blit_rect(picture,Rect2i(0,0,300,300),Vector2i((i%5)*300,(i/5)*300))
  personality.save_png("res://docs/images/phase6-personality-%d.png"%angle)
  var rest: Image=Image.create(1440,540,false,Image.FORMAT_RGB8)
  var row: int=0
  for action: String in ["sit","lie_down","sleep"]:
   var column: int=0
   for frame: int in [30,60,90,120,150,180,220,300]:
    var picture: Image=Image.load_from_file(source.path_join("%s-%d-%d.png"%[action,frame,angle]));picture.convert(Image.FORMAT_RGB8);picture.resize(180,180,Image.INTERPOLATE_LANCZOS);rest.blit_rect(picture,Rect2i(0,0,180,180),Vector2i(column*180,row*180));column+=1
   row+=1
  rest.save_png("res://docs/images/phase6-rest-%d.png"%angle)
 print("Phase 6 actual-rig audit sheets written.");quit()
