class_name AisoraLocalImages
extends RefCounted
## Thread-safe bitmap work. RenderingServer/ImageTexture calls stay on the main thread.
const MAX_BYTES: int = 20*1024*1024
static func decode(path: String, edge_limit: int=1920) -> Dictionary:
 var file: FileAccess=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>MAX_BYTES:return {"error":"Image unavailable or larger than 20 MiB. Existing scenery retained."}
 var header: PackedByteArray=file.get_buffer(file.get_length());file.close()
 var kind: String=path.get_extension().to_lower()
 var signature_ok: bool=(kind=="png" and header.size()>=24 and header.slice(0,8)==PackedByteArray([137,80,78,71,13,10,26,10])) or (kind in ["jpg","jpeg"] and header.size()>=3 and header[0]==255 and header[1]==216 and header[2]==255) or (kind=="webp" and header.size()>=12 and header.slice(0,4).get_string_from_ascii()=="RIFF" and header.slice(8,12).get_string_from_ascii()=="WEBP")
 if not signature_ok:return {"error":"Choose a valid PNG, JPEG or WebP image. Existing scenery retained."}
 var dimensions: Vector2i=_dimensions(header,kind)
 if dimensions.x<=0 or dimensions.y<=0 or dimensions.x>8192 or dimensions.y>8192 or dimensions.x*dimensions.y>16000000:return {"error":"Use an image no larger than 16 megapixels / 8192 pixels per edge."}
 var value: Image=Image.new()
 var result: Error=ERR_FILE_UNRECOGNIZED
 match kind:
  "png":result=value.load_png_from_buffer(header)
  "jpg","jpeg":result=value.load_jpg_from_buffer(header)
  "webp":result=value.load_webp_from_buffer(header)
 if result!=OK or value.is_empty():return {"error":"Image could not be decoded. Existing scenery retained."}
 fit(value,edge_limit)
 return {"image":value}

static func fit(value: Image, limit: int) -> void:
 var edge: int=maxi(value.get_width(),value.get_height())
 if edge>limit:
  value.resize(maxi(1,roundi(value.get_width()*float(limit)/edge)),maxi(1,roundi(value.get_height()*float(limit)/edge)),Image.INTERPOLATE_LANCZOS)

static func _dimensions(data: PackedByteArray, kind: String) -> Vector2i:
 # Read dimensions before allocating a decoded bitmap. No per-frame image work.
 if kind=="png" and data.size()>=24:
  return Vector2i(_be32(data,16),_be32(data,20))
 if kind=="webp" and data.size()>=30:
  var chunk: String=data.slice(12,16).get_string_from_ascii()
  if chunk=="VP8X":return Vector2i(1+data[24]+(data[25]<<8)+(data[26]<<16),1+data[27]+(data[28]<<8)+(data[29]<<16))
  if chunk=="VP8 ":return Vector2i((data[26]+(data[27]<<8))&16383,(data[28]+(data[29]<<8))&16383)
  if chunk=="VP8L":return Vector2i(1+data[21]+((data[22]&63)<<8),1+(data[22]>>6)+(data[23]<<2)+((data[24]&15)<<10))
 if kind in ["jpg","jpeg"]:
  var at: int=2
  while at+4<data.size():
   if data[at]!=255:at+=1;continue
   var marker: int=data[at+1];at+=2
   if marker==255:at-=1;continue
   if marker in [216,217,1] or (marker>=208 and marker<=215):continue
   var length_value: int=(data[at]<<8)+data[at+1]
   if length_value<2 or at+length_value>data.size():return Vector2i.ZERO
   if marker in [192,193,194,195,197,198,199,201,202,203,205,206,207] and length_value>=7:
    return Vector2i((data[at+5]<<8)+data[at+6],(data[at+3]<<8)+data[at+4])
   at+=length_value
 return Vector2i.ZERO

static func _be32(data: PackedByteArray, at: int) -> int:
 return (data[at]<<24)+(data[at+1]<<16)+(data[at+2]<<8)+data[at+3]
