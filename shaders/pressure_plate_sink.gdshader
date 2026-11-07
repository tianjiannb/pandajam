shader_type canvas_item;

// Active pressure plate: compress the panel toward its center and darken the rim.
uniform float sink_depth : hint_range(0.0, 0.30) = 0.12;
uniform float edge_shadow : hint_range(0.0, 1.0) = 0.45;
uniform vec2 plate_center = vec2(24.0, 24.0);

void vertex() {
	VERTEX = (VERTEX - plate_center) * (1.0 - sink_depth) + plate_center;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 edge = min(UV, vec2(1.0) - UV);
	float rim = 1.0 - smoothstep(0.02, 0.18, min(edge.x, edge.y));
	float shade = 1.0 - rim * edge_shadow;
	COLOR = vec4(tex.rgb * shade, tex.a);
}
