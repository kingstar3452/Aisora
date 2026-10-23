shader_type spatial;
render_mode unshaded;
// One texture read, no light passes, normal mapping, outlines or specular work.
uniform sampler2D _MainTex : source_color, filter_linear_mipmap;
uniform vec4 _Color : source_color = vec4(1.0);
uniform vec4 _MainTex_ST = vec4(1.0, 1.0, 0.0, 0.0);
uniform float _Cutoff = 0.5;
uniform float shade_strength = 0.12;
uniform vec4 world_tint : source_color = vec4(1.0);
uniform float world_energy = 1.0;
uniform float appearance_contrast = 1.0;
uniform float face_clarity = 0.0;
varying float soft_shade;
void vertex() {
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	soft_shade = mix(1.0 - shade_strength, 1.0, smoothstep(-0.4, 0.65, dot(world_normal, normalize(vec3(-0.4, 0.8, 0.6)))));
}
void fragment() {
	vec4 tex = texture(_MainTex, UV * _MainTex_ST.xy + _MainTex_ST.zw) * _Color;
	ALBEDO = clamp((tex.rgb - vec3(0.5)) * appearance_contrast + vec3(0.5),vec3(0.0),vec3(1.0)) * mix(soft_shade,1.0,face_clarity*0.55) * mix(world_tint.rgb,vec3(1.0),face_clarity*0.35) * mix(world_energy,max(world_energy,0.78),face_clarity);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = _Cutoff;
}
