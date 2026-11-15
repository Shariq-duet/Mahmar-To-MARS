shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Uniforms for terrain colors
uniform vec4 regolith_color : source_color = vec4(0.78, 0.32, 0.15, 1.0);      // Mid Mars regolith dust
uniform vec4 low_basin_color : source_color = vec4(0.58, 0.22, 0.12, 1.0);     // Low depression / crater floor
uniform vec4 high_dune_color : source_color = vec4(0.88, 0.42, 0.20, 1.0);     // High sunlit ridges / plateaus
uniform vec4 basalt_rock_color : source_color = vec4(0.20, 0.16, 0.14, 1.0);   // Dark cliff basalt
uniform vec4 cave_entrance_color : source_color = vec4(0.12, 0.09, 0.08, 1.0); // Charred cave opening tint

uniform float planet_radius = 500.0;
uniform vec3 planet_center = vec3(0.0);
uniform float triplanar_sharpness = 4.0;
uniform float macro_noise_scale = 0.06;
uniform float micro_noise_scale = 0.45;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_color;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vertex_color = COLOR;
}

// Pseudo-random 3D hash
float hash3D(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Continuous 3D value noise
float value_noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	float n000 = hash3D(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3D(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3D(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3D(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3D(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3D(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3D(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3D(i + vec3(1.0, 1.0, 1.0));

	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

// Two-octave procedural noise (macro variations + micro detail)
float fbm2_octaves(vec3 p) {
	float n1 = value_noise3D(p);
	float n2 = value_noise3D(p * 2.8 + vec3(17.1, 31.7, 53.2));
	return n1 * 0.68 + n2 * 0.32;
}

void fragment() {
	// 1. Planetary radial reference
	vec3 radial_up = normalize(v_world_pos - planet_center);
	
	// 2. Slope calculation: angle between surface normal and planet radial up
	// Flat ground: dot == 1.0 (slope == 0.0). Steep cliffs/crater walls: dot < 0.85
	float slope_cos = clamp(dot(v_world_normal, radial_up), 0.0, 1.0);
	float steepness = 1.0 - slope_cos;
	float basalt_slope_mask = smoothstep(0.12, 0.36, steepness);

	// 3. Altitude calculation: height above planet base radius
	float altitude = length(v_world_pos - planet_center) - planet_radius;
	float alt_normalized = clamp((altitude + 14.0) / 36.0, 0.0, 1.0);
	vec3 dust_gradient = mix(low_basin_color.rgb, high_dune_color.rgb, alt_normalized);

	// 4. Triplanar procedural noise (two octaves)
	vec3 tri_weights = pow(abs(v_world_normal), vec3(triplanar_sharpness));
	tri_weights /= max(tri_weights.x + tri_weights.y + tri_weights.z, 0.001);

	// Macro noise for geographic coloration
	vec3 macro_pos = v_world_pos * macro_noise_scale;
	float macro_xy = fbm2_octaves(vec3(macro_pos.xy, 0.0));
	float macro_yz = fbm2_octaves(vec3(macro_pos.yz, 0.0));
	float macro_zx = fbm2_octaves(vec3(macro_pos.zx, 0.0));
	float macro_noise = macro_xy * tri_weights.z + macro_yz * tri_weights.x + macro_zx * tri_weights.y;

	// Micro noise for surface grit & roughness texture
	vec3 micro_pos = v_world_pos * micro_noise_scale;
	float micro_xy = fbm2_octaves(vec3(micro_pos.xy, 0.0));
	float micro_yz = fbm2_octaves(vec3(micro_pos.yz, 0.0));
	float micro_zx = fbm2_octaves(vec3(micro_pos.zx, 0.0));
	float micro_noise = micro_xy * tri_weights.z + micro_yz * tri_weights.x + micro_zx * tri_weights.y;

	// 5. Combine Slope + Altitude + Noise for base terrain albedo
	vec3 slope_blended = mix(dust_gradient, basalt_rock_color.rgb, basalt_slope_mask);
	
	// Add macro noise tone variations (sand drifts, mineral veins)
	vec3 modulated_terrain = slope_blended * (0.80 + 0.40 * macro_noise);

	// 6. Blend vertex colour for cave entrance tint
	// Base regolith vertex color has R > 0.65; cave entrance has dark basalt R < 0.35
	float cave_entrance_mask = clamp((0.70 - v_vertex_color.r) / 0.50, 0.0, 1.0);
	vec3 final_cave_tint = mix(v_vertex_color.rgb, cave_entrance_color.rgb, 0.4);
	vec3 final_albedo = mix(modulated_terrain, final_cave_tint, cave_entrance_mask);

	// Water ice patch: pale blue-white (B > 0.50 and B > R)
	float ice_mask = clamp((v_vertex_color.b - 0.50) / 0.35, 0.0, 1.0) * step(v_vertex_color.r, v_vertex_color.b + 0.05);
	final_albedo = mix(final_albedo, v_vertex_color.rgb, ice_mask * 0.95);

	ALBEDO = final_albedo;
	
	// 7. Modulate roughness: rock areas rougher than dust, varying with micro noise
	float base_roughness = mix(0.74, 0.94, basalt_slope_mask);
	base_roughness = mix(base_roughness, 0.96, cave_entrance_mask * 0.5);
	float terrain_roughness = clamp(base_roughness + (micro_noise - 0.5) * 0.24, 0.52, 0.98);
	ROUGHNESS = mix(terrain_roughness, 0.08, ice_mask);
	METALLIC = mix(0.04, 0.02, ice_mask);
	SPECULAR = mix(0.25, 0.92, ice_mask);

	// Subtle icy translucency/rim
	float rim = 1.0 - clamp(dot(v_world_normal, normalize(v_world_pos - planet_center)), 0.0, 1.0);
	EMISSION = mix(vec3(0.0), vec3(0.15, 0.25, 0.35) * rim, ice_mask * 0.5);

	// 8. High-frequency normal perturbation so small surface detail catches directional light
	float eps = 0.06;
	vec3 p_norm = v_world_pos * 1.5;
	float n_c = value_noise3D(p_norm);
	float n_dx = value_noise3D(p_norm + vec3(eps, 0.0, 0.0)) - n_c;
	float n_dy = value_noise3D(p_norm + vec3(0.0, eps, 0.0)) - n_c;
	float n_dz = value_noise3D(p_norm + vec3(0.0, 0.0, eps)) - n_c;
	vec3 noise_grad = vec3(n_dx, n_dy, n_dz) / eps;
	vec3 tangent_perturb = noise_grad - v_world_normal * dot(noise_grad, v_world_normal);
	float perturb_strength = mix(0.18, 0.38, basalt_slope_mask);
	NORMAL = normalize(NORMAL - tangent_perturb * perturb_strength);
}
