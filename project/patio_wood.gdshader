shader_type spatial;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 baked_green : source_color;
uniform vec4 base_color : source_color;
uniform vec3 grain_origin;
uniform vec3 grain_size = vec3(1.0);
uniform vec3 grain_scale = vec3(2.0, 5.0, 6.0);
uniform float grain_offset = 0.0;
varying vec3 piece_position;

vec3 sample_layer(vec2 point, float layer) {
	vec2 tile = vec2(mod(layer, 8.0), floor(layer / 8.0));
	vec2 pixel = tile * 128.0 + vec2(0.5) + clamp(point / 8.0, 0.0, 1.0) * 127.0;
	return texture(atlas, vec2(pixel.x, 1024.0-pixel.y) / 1024.0).rgb;
}

void vertex() {
	piece_position = VERTEX;
}

void fragment() {
	vec3 p = (piece_position - grain_origin) / max(grain_size, vec3(0.001));
	p = p * grain_scale + vec3(grain_offset);
	float slice = clamp(p.z * 63.0 / 8.0, 0.0, 63.0);
	vec3 baked = mix(sample_layer(p.xy, floor(slice)), sample_layer(p.xy, ceil(slice)), fract(slice));
	float variation = clamp(baked.g / max(baked_green.g, 0.01), 0.8, 1.2);
	ALBEDO = base_color.rgb * variation;
	ROUGHNESS = 0.82;
}
