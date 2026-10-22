shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size = vec2(1280.0,800.0);
uniform float intensity = 1.0;
uniform float wind = 1.0;
uniform float paused_at = -1.0;
uniform float time_offset = 0.0;
uniform float preview_time = -1.0;
uniform vec2 face_center = vec2(-2.0);
uniform vec2 face_radius = vec2(0.04,0.06);
void vertex() {
 float t = preview_time >= 0.0 ? preview_time : (paused_at >= 0.0 ? paused_at : TIME-time_offset);
 float seed = INSTANCE_CUSTOM.x;
 float a = sin(t*.7+seed*40.0)*.6*intensity;
 VERTEX = mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*VERTEX;
 VERTEX.x += mod(seed*viewport_size.x+t*(8.0+seed*7.0)*intensity*wind+sin(t*.4+seed*20.0)*18.0*intensity,viewport_size.x+40.0)-20.0;
 VERTEX.y += mod(INSTANCE_CUSTOM.y*viewport_size.y+t*(14.0+seed*6.0)*intensity,viewport_size.y+40.0)-20.0;
}
void fragment() {
 float clarity = smoothstep(0.7,1.0,length((SCREEN_UV-face_center)/face_radius));
 COLOR = texture(TEXTURE,UV)*vec4(1.0,1.0,1.0,0.85*clarity);
}
