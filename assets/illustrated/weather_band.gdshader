shader_type canvas_item;
render_mode unshaded;
uniform bool is_fog=false;
uniform float strength=.5;
uniform float paused_at=-1.;
uniform float time_offset=0.;
uniform vec2 viewport_size=vec2(1280.,800.);
uniform float preview_time=-1.;
varying float drift;
void vertex(){float t=preview_time>=0.?preview_time:(paused_at>=0.?paused_at:TIME-time_offset);drift=t*.015;}
void fragment(){
 float wave=.12*sin(UV.x*7.+drift)+.08*sin(UV.x*13.-drift*.6);
 float band=is_fog?smoothstep(.0,.7,UV.y):1.-smoothstep(.12+wave,.85+wave,UV.y);
 COLOR=vec4(is_fog?vec3(.83,.86,.87):vec3(.65,.71,.77),band*strength*(is_fog?.14:.11));
}
