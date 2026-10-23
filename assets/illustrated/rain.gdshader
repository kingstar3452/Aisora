shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size=vec2(1280.,800.);
uniform float strength=.5;
uniform float paused_at=-1.;
uniform float time_offset=0.;
uniform float preview_time=-1.;
void vertex(){
 float t=preview_time>=0.?preview_time:(paused_at>=0.?paused_at:TIME-time_offset);
 float speed=220.+INSTANCE_CUSTOM.z*100.;
 VERTEX.x-=VERTEX.y*.18;
 VERTEX+=vec2(mod(INSTANCE_CUSTOM.x*viewport_size.x-t*speed*.18,viewport_size.x+40.)-20.,mod(INSTANCE_CUSTOM.y*viewport_size.y+t*speed,viewport_size.y+50.)-25.);
}
void fragment(){COLOR=vec4(.79,.87,.94,.12+strength*.16);}
