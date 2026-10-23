shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float time_origin = 0.0;
uniform float pause_time = -1.0;
uniform float preview_time = -1.0;
// Every petal has a static seed/position. Motion is analytic on the GPU: zero CPU transforms.
void vertex() {
	float t = preview_time >= 0.0 ? preview_time : (pause_time >= 0.0 ? pause_time : TIME - time_origin);
	float seed = INSTANCE_CUSTOM.x;
	float cycle = mod(INSTANCE_CUSTOM.y + t * (0.11 + seed * 0.08), 4.3);
	VERTEX.x += sin(t * 0.7 + seed * 30.0) * 0.20 + sin(t * 0.21 + seed) * 0.15;
	VERTEX.y += 3.8 - cycle;
	VERTEX.z += sin(t * 0.5 + seed * 20.0) * 0.10;
}
void fragment() { ALBEDO = vec3(0.96, 0.77, 0.85); }
