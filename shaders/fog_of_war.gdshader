shader_type canvas_item;

// 已探索记忆遮罩（R 通道：1 = 已探索过，0 = 从未探索）。
uniform sampler2D memory_tex;
uniform vec2 memory_origin;
uniform float memory_world_size;

// 当前视野多边形（世界坐标），用于把世界像素判定为“当前可见”。
uniform vec2 vision_center;
uniform float vision_radius;
uniform vec2 vision_polygon[128];
uniform int vision_point_count;

// 三态颜色：未探索全黑，已探索半透明灰，当前可见完全透明。
uniform vec4 unexplored_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 explored_color : source_color = vec4(0.05, 0.05, 0.08, 0.72);

varying vec2 world_pos;

void vertex() {
	// 该节点不挂在 CanvasLayer 下，MODEL_MATRIX 把本地顶点变换到的坐标
	// 就是游戏世界坐标（与物理空间一致）。
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// 判断点是否在多边形内（射线法）。
bool point_in_polygon(vec2 p, int count) {
	bool inside = false;
	int j = count - 1;
	for (int i = 0; i < count; i++) {
		vec2 pi = vision_polygon[i];
		vec2 pj = vision_polygon[j];
		if ((pi.y > p.y) != (pj.y > p.y)) {
			float slope = (pj.x - pi.x) / (pj.y - pi.y);
			float x_at_p = pi.x + slope * (p.y - pi.y);
			if (p.x < x_at_p) {
				inside = !inside;
			}
		}
		j = i;
	}
	return inside;
}

void fragment() {
	float explored = 0.0;
	vec2 mem_uv = (world_pos - memory_origin) / memory_world_size;
	if (mem_uv.x >= 0.0 && mem_uv.x <= 1.0 && mem_uv.y >= 0.0 && mem_uv.y <= 1.0) {
		explored = texture(memory_tex, mem_uv).r;
	}

	bool visible_now = false;
	if (distance(world_pos, vision_center) <= vision_radius) {
		visible_now = point_in_polygon(world_pos, vision_point_count);
	}

	vec4 result;
	if (visible_now) {
		result = vec4(0.0, 0.0, 0.0, 0.0);
	} else if (explored > 0.5) {
		result = explored_color;
	} else {
		result = unexplored_color;
	}

	COLOR = result;
}
