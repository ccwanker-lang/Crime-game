// Sky for the day/night cycle (driven by DayNight, scripts/world/day_night.gd).
// Day: the HDRI panorama (its own sun is clamped away, a disc is drawn at the
// real sun direction instead). Sunrise/sunset: warm tint + glow around the sun.
// Night: dark blue gradient, stars, moon disc and the HDRI clouds very dim.
// The script updates the uniforms a few times per second; the Sky uses
// PROCESS_MODE_INCREMENTAL so the radiance (ambient light) follows smoothly.
shader_type sky;
render_mode use_debanding;

uniform sampler2D hdri : source_color, filter_linear, hint_default_black;
uniform float hdri_energy = 1.0;
// HDR values above this are cut off (removes the baked-in sun of the panorama).
uniform float hdri_clamp = 2.2;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
// 0 = night, 1 = full day.
uniform float day = 1.0;
// 0..1 strength of the sunrise/sunset colours.
uniform float twilight = 0.0;
uniform vec4 twilight_color : source_color = vec4(1.0, 0.45, 0.2, 1.0);
uniform vec4 night_zenith : source_color = vec4(0.004, 0.008, 0.025, 1.0);
uniform vec4 night_horizon : source_color = vec4(0.025, 0.04, 0.075, 1.0);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	vec3 hd = min(texture(hdri, SKY_COORDS).rgb * hdri_energy, vec3(hdri_clamp));
	float horizon = 1.0 - clamp(d.y * 2.5, 0.0, 1.0);
	float to_sun = max(dot(d, sun_dir), 0.0);

	// --- Day (with sunrise / sunset tint) ---
	vec3 day_col = hd * mix(vec3(1.0), vec3(1.0, 0.62, 0.5), twilight * 0.75);
	day_col += twilight_color.rgb * twilight * (pow(to_sun, 6.0) * 1.6 + horizon * 0.35);
	// Sun disc + halo (only above the horizon).
	float above = smoothstep(-0.03, 0.02, sun_dir.y);
	vec3 sun_col = mix(vec3(1.0, 0.55, 0.3), vec3(1.0, 0.95, 0.88), clamp(sun_dir.y * 3.0, 0.0, 1.0));
	day_col += sun_col * (smoothstep(0.99955, 0.9998, to_sun) * 40.0 + pow(to_sun, 300.0) * 1.5) * above;

	// --- Night ---
	vec3 night_col = mix(night_horizon.rgb, night_zenith.rgb, clamp(d.y * 1.8, 0.0, 1.0));
	// Clouds of the panorama, faintly lit by the moon and the town.
	float cloud = clamp((hd.r + hd.g + hd.b) / 3.0 - 0.45, 0.0, 1.0);
	night_col = mix(night_col, vec3(0.05, 0.055, 0.07), cloud * 0.6);
	if (d.y > 0.0) {
		vec3 p = d * 260.0;
		vec3 cell = floor(p);
		float h = hash3(cell);
		if (h > 0.996) {
			float s = smoothstep(0.32, 0.0, length(fract(p) - 0.5));
			// No TIME here: that would make Godot re-render the sky radiance every frame.
			float tw = 0.5 + 0.5 * fract(h * 731.0);
			night_col += vec3(0.9, 0.93, 1.0) * s * tw * (1.0 - cloud * 1.5) * smoothstep(0.0, 0.25, d.y) * 1.4;
		}
	}
	float to_moon = dot(d, moon_dir);
	float moon_up = smoothstep(-0.03, 0.03, moon_dir.y);
	night_col += vec3(0.85, 0.9, 1.0) * (smoothstep(0.99935, 0.99955, to_moon) * 6.0
			+ pow(max(to_moon, 0.0), 120.0) * 0.12) * moon_up;
	// Dusk / dawn: the sky stays deep blue for a while after sunset.
	float dusk = smoothstep(-0.32, 0.0, sun_dir.y);
	night_col += vec3(0.05, 0.09, 0.2) * dusk * (1.0 - clamp(d.y, 0.0, 1.0) * 0.6);
	// After sunset / before sunrise the horizon on the sun's side stays warm a while.
	night_col += twilight_color.rgb * twilight * (pow(to_sun, 3.0) * 0.5 + horizon * 0.1) * 0.6;

	COLOR = mix(night_col, day_col, day);
}
