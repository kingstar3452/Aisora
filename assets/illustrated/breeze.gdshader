shader_type canvas_item;
render_mode unshaded;
uniform float intensity = 1.0;
uniform float paused_at = -1.0;
uniform float time_offset = 0.0;
void vertex(){
 float t = paused_at >= 0.0 ? paused_at : TIME-time_offset;
 float a = sin(t*.45)*.009*intensity;
 VERTEX = mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*VERTEX;
}
