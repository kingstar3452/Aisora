shader_type canvas_item;
// Opaque base images need no framebuffer read/blend. Incoming crossfades
// and images with alpha continue using the original ambient shader.
render_mode unshaded, blend_disabled;
uniform float intensity=1.;
uniform float paused_at=-1.;
uniform float time_offset=0.;
varying vec3 tint;
varying vec4 canvas_modulation;
void vertex(){
 float t=paused_at>=0.?paused_at:TIME-time_offset;
 float warmth=(.5+.5*sin(t*.16))*.018*intensity;
 tint=vec3(1.+warmth*.25,1.+warmth*.06,1.-warmth*.35);
 canvas_modulation=COLOR;
}
void fragment(){COLOR=texture(TEXTURE,UV)*vec4(tint,1.)*canvas_modulation;}
