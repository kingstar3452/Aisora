shader_type sky;
render_mode disable_fog;

// Static daylight gradient. No textures, volumetrics, moving clouds or post effects.
void sky() {
	float height = smoothstep(-0.12, 0.65, EYEDIR.y);
	COLOR = mix(vec3(0.89, 0.94, 0.85), vec3(0.47, 0.72, 0.83), height);
}
