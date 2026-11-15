shader_type sky;

// mars_sky.gdshader
// NASA-authentic Martian sky shader:
// - Mie scattering: Butterscotch / peach daytime sky.
// - Famous NASA Blue Sunset around the setting sun disc.
// - Crisp, deep-space starfield at night with Milky Way band.

uniform vec3 sun_direction = vec3(0.707, 0.707, 0.0);
uniform vec3 planet_up = vec3(0.0, 1.0, 0.0);

// Mars palette
uniform vec3 day_horizon_color : source_color = vec3(0.82, 0.58, 0.38);  // Butterscotch dust
uniform vec3 day_zenith_color : source_color = vec3(0.62, 0.40, 0.28);   // Warm ochre
uniform vec3 blue_sunset_color : source_color = vec3(0.25, 0.65, 0.95);  // Forward Mie blue glow
uniform vec3 twilight_horizon_color : source_color = vec3(0.48, 0.25, 0.18); // Dark reddish bronze
uniform vec3 night_color : source_color = vec3(0.008, 0.010, 0.022);     // Deep cosmos

// Hash function for procedural starfield
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);
	vec3 up_dir = normalize(planet_up);

	// Angle relative to player's local planet zenith
	float elevation = dot(ray, up_dir);
	float sun_height = dot(sun_dir, up_dir); // >0 = above horizon, <0 = night
	float sun_dot = dot(ray, sun_dir);

	// Day/night blend factors
	float day_factor = clamp((sun_height + 0.05) / 0.25, 0.0, 1.0);
	float sunset_factor = 1.0 - abs(sun_height) / 0.22;
	sunset_factor = clamp(sunset_factor, 0.0, 1.0);

	// 1. Daytime atmospheric gradient (horizon to zenith)
	float grad = clamp(pow(max(0.0, elevation), 0.6), 0.0, 1.0);
	vec3 day_sky = mix(day_horizon_color, day_zenith_color, grad);

	// 2. NASA Blue Sunset effect
	// On Mars, fine dust forward-scatters blue light, creating a bright cyan/blue halo around the setting sun
	float sun_halo = pow(max(0.0, sun_dot), 8.0);
	float blue_glow_intensity = sunset_factor * (sun_halo * 1.5 + pow(max(0.0, sun_dot), 24.0) * 2.5);
	vec3 sunset_sky = mix(twilight_horizon_color, blue_sunset_color, clamp(blue_glow_intensity, 0.0, 1.0));

	// 3. Nighttime Starfield
	// Generate crisp starlight in deep space
	vec3 star_grid = floor(ray * 380.0);
	float star_rnd = hash(star_grid);
	float star_intensity = 0.0;
	if (star_rnd > 0.988) {
		float star_dist = length(fract(ray * 380.0) - vec3(0.5));
		star_intensity = smoothstep(0.35, 0.05, star_dist) * (0.6 + 0.4 * sin(star_rnd * 50.0 + TIME * 1.5));
	}
	// Faint Milky Way dust band
	float milky_way = pow(max(0.0, 1.0 - abs(dot(ray, vec3(0.6, 0.3, -0.7)))), 4.0) * 0.07;
	vec3 night_sky = night_color + vec3(star_intensity * 0.95 + milky_way * 0.4);

	// 4. Blend Day, Sunset, and Night
	vec3 base_sky = mix(night_sky, day_sky, day_factor);
	base_sky = mix(base_sky, sunset_sky, sunset_factor * 0.65);

	// 5. Sun Disc
	// The Sun on Mars is smaller than on Earth (0.35 degrees vs 0.5 degrees)
	if (sun_dot > 0.9994 && sun_height > -0.04) {
		// Sun core
		vec3 sun_disc_color = mix(vec3(1.0, 0.95, 0.85), blue_sunset_color, sunset_factor * 0.6);
		base_sky += sun_disc_color * 12.0;
	} else if (sun_dot > 0.996 && sun_height > -0.06) {
		// Sun inner corona
		float corona = (sun_dot - 0.996) / 0.0034;
		vec3 corona_color = mix(vec3(1.0, 0.8, 0.5), blue_sunset_color, sunset_factor * 0.7);
		base_sky += corona_color * corona * 2.5;
	}

	COLOR = max(vec3(0.0), base_sky);
}
