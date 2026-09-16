shader_type spatial;
// World-aligned paving keeps the slab pattern continuous after grid moves/turns.
uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 4.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(paving, world_position.xz / tile_size).rgb;
	ROUGHNESS = 0.98;
}
