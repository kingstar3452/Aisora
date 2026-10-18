shader_type canvas_item;
render_mode unshaded;
uniform float intensity = 1.0;
uniform float paused_at = -1.0;
uniform float time_offset = 0.0;
varying vec3 tint;
void vertex(){
 float t = paused_at >= 0.0 ? paused_at : TIME-time_offset;
 float warmth=(.5+.5*sin(t*.16))*.018*intensity;
 tint=vec3(1.0+warmth*.25,1.0+warmth*.06,1.0-warmth*.35);
}
void fragment(){ COLOR=texture(TEXTURE,UV)*vec4(tint,1.0); }
