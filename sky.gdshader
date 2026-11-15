shader_type sky;

// sky.gdshader
// Cheap procedural starry sky with hash-based stars and faint Milky Way band.
// Zero loops, zero textures, pure mathematical hash of EYEDIR.

uniform vec3 deep_space_color : source_color = vec3(0.003, 0.004, 0.008);
uniform vec3 milky_way_color : source_color = vec3(0.08, 0.075, 0.11);
uniform float star_density : hint_range(20.0, 150.0) = 57.3; // ~1 star per 2 degrees of sky
uniform float star_intensity : hint_range(0.5, 10.0) = 4.5;
uniform float milky_way_intensity : hint_range(0.0, 3.0) = 1.2;

// Cheap 3D pseudo-random hash without textures or loops
vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Low-frequency value noise for the Milky Way clouds
float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.1, 0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	
	return mix(mix(mix(hash13(i + vec3(0.0, 0.0, 0.0)),
	                   hash13(i + vec3(1.0, 0.0, 0.0)), u.x),
	               mix(hash13(i + vec3(0.0, 1.0, 0.0)),
	                   hash13(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
	           mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)),
	                   hash13(i + vec3(1.0, 0.0, 1.0)), u.x),
	               mix(hash13(i + vec3(0.0, 1.0, 1.0)),
	                   hash13(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

// Single-layer star cell evaluator (no loops)
vec3 get_stars(vec3 dir, vec3 offset) {
	vec3 p = (dir + offset) * star_density;
	vec3 id = floor(p);
	vec3 pos = fract(p);
	
	vec3 h = hash33(id);
	// Roughly 1 star per 2 degrees of sky (~28% of cells contain a noticeable star)
	if (h.x > 0.72) {
		vec3 star_pos = h.yzx * 0.72 + 0.14;
		vec3 delta = pos - star_pos;
		float d2 = dot(delta, delta);
		float radius2 = 0.035; // ~2.5 - 3 pixels wide on 1080p for crisp visibility
		if (d2 < radius2) {
			float core = 1.0 - (d2 / radius2);
			core = core * core * core;
			// Random brightness and small color variation (cool blue-white to warm amber)
			float brightness = pow(h.x, 3.5) * star_intensity;
			vec3 star_tint = mix(vec3(0.85, 0.93, 1.0), vec3(1.0, 0.86, 0.68), h.y);
			return star_tint * core * brightness;
		}
	}
	return vec3(0.0);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	
	// 1. Base Deep Space
	vec3 sky_color = deep_space_color;
	
	// 2. Faint Milky Way Band (low frequency noise term along tilted galactic plane)
	vec3 mw_normal = normalize(vec3(0.35, 0.75, -0.55));
	float dist_from_plane = abs(dot(dir, mw_normal));
	float galactic_band = exp(-dist_from_plane * dist_from_plane * 24.0);
	
	if (galactic_band > 0.005) {
		float mw_noise = noise3d(dir * 4.0) * 0.65 + noise3d(dir * 9.0) * 0.35;
		vec3 mw_dust = mix(milky_way_color * 0.7, milky_way_color * 1.5, mw_noise);
		sky_color += galactic_band * mw_dust * (0.35 + 0.65 * mw_noise) * milky_way_intensity;
	}
	
	// 3. Grid-hashed stars without loops or textures (2 offset layers for seamless coverage)
	vec3 stars = get_stars(dir, vec3(0.0));
	stars += get_stars(dir, vec3(0.37, 0.59, 0.23));
	
	sky_color += stars;
	
	COLOR = sky_color;
}
