shader_type canvas_item;
render_mode unshaded;
uniform vec2 viewport_size=vec2(1280.,800.);
uniform float strength=.5;
uniform float paused_at=-1.;
uniform float time_offset=0.;
varying float glow;
void vertex(){
 float t=paused_at>=0.?paused_at:TIME-time_offset;
 float seed=INSTANCE_CUSTOM.x;
 VERTEX+=vec2(seed*viewport_size.x+sin(t*.3+seed*20.)*12.,(.55+INSTANCE_CUSTOM.y*.4)*viewport_size.y+sin(t*.4+seed*10.)*8.);
 glow=.35+.65*pow(.5+.5*sin(t*.9+seed*30.),2.);
}
void fragment(){COLOR=vec4(1.,.88,.49,(1.-smoothstep(.0,.5,length(UV-.5)))*glow*.7*strength);}
