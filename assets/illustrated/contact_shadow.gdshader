shader_type canvas_item;
render_mode unshaded;
uniform float opacity=.65;
uniform float softness=1.;
void fragment(){float r=length((UV-.5)*2.);float a=1.-smoothstep(clamp(1.-softness*.8,.0,.85),1.,r);COLOR=vec4(.17,.16,.20,a*.27*opacity);}
