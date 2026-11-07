// ui_countdown_handdrawn.gdshader
//
// 手绘风格倒计时材质（UI-02）。
// 用途：倒计时数字、副本倒计时；也可挂在任意图标/纸片 Control 上做墨迹抖动。
//
// 用法要点：
//  * 图集模式（推荐）：TextureRect + AtlasTexture，按单元格设置 atlas_cell_uv =
//      vec4(cell_x / atlas_w, cell_y / atlas_h, cell_w / atlas_w, cell_h / atlas_h)
//    此时抖动 / 旋转都限制在本格内，不会串到相邻数字。
//  * 整图模式：atlas_cell_uv 保持默认 vec4(0,0,1,1)。
//  * Label（字体）模式：TEXTURE 是字体图集，UV 不是 0..1 的单元格坐标，
//    请把 rotation_jitter 设为 0，只保留墨迹边缘与噪声偏移。
//
// 场景脚本（ui/scripts/ui_countdown.gd）负责：
//  * 每位数复制一份材质并写入 atlas_cell_uv / time_seed
//  * 警告态切换 materials/ui_countdown_warning.tres 或把 danger_mix 拉到 1
//  * 数字脉冲（pulse）、整体呼吸由脚本动画完成，shader 只负责"墨迹感"

shader_type canvas_item;
render_mode blend_mix;

// —— 抖动 ——
uniform float jitter_strength : hint_range(0.0, 0.02) = 0.0035; // UV 偏移幅度，约 0.004 ≈ 1px@256px
uniform float noise_scale : hint_range(1.0, 120.0) = 18.0;      // 抖动噪声缩放
uniform float rotation_jitter : hint_range(0.0, 8.0) = 1.4;     // 每位数旋转抖动（度，图集模式）
uniform float jitter_speed : hint_range(0.0, 8.0) = 1.0;        // 抖动速度
uniform float time_seed : hint_range(0.0, 100.0) = 0.0;         // 每位数不同的随机种子

// —— 墨迹边缘 ——
uniform float ink_edge_strength : hint_range(0.0, 1.0) = 0.8;   // 边缘墨迹强度（0=干净边缘）
uniform float ink_noise_scale : hint_range(1.0, 200.0) = 55.0;  // 墨迹噪声缩放
uniform float ink_bleed : hint_range(0.0, 1.0) = 0.45;          // 外渗墨晕强度
uniform float ink_width : hint_range(0.0, 6.0) = 2.0;           // 墨晕采样宽度（纹理像素）

// —— 状态 ——
uniform float danger_mix : hint_range(0.0, 1.0) = 0.0;          // 0=普通 1=最后 3 秒警告
uniform float pulse : hint_range(0.0, 1.0) = 0.0;               // 警告脉冲（脚本动画）
uniform float base_alpha : hint_range(0.0, 1.0) = 1.0;          // 整体透明度（副本身份调低）

// —— 颜色 ——
uniform vec4 base_color : source_color = vec4(0.945, 0.820, 0.510, 1.0);   // GOLD #F1D183
uniform vec4 danger_color : source_color = vec4(0.945, 0.565, 0.537, 1.0); // DANGER #F19089
uniform vec4 ink_color : source_color = vec4(0.039, 0.078, 0.102, 1.0);    // INK_DARK #0A141A

// —— 图集单元格 ——
uniform vec4 atlas_cell_uv = vec4(0.0, 0.0, 1.0, 1.0);

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
    // 1) 换算到单元格局部坐标，旋转抖动在单元格中心进行
    vec2 cell_origin = atlas_cell_uv.xy;
    vec2 cell_size = max(atlas_cell_uv.zw, vec2(0.0001));
    vec2 local = (UV - cell_origin) / cell_size;

    float n0 = vnoise(vec2(time_seed * 1.7, TIME * jitter_speed * 0.45 + time_seed));
    float wobble = (n0 - 0.5) * 2.0;
    float ang = radians(rotation_jitter) * wobble;
    float cs = cos(ang);
    float sn = sin(ang);
    local = mat2(vec2(cs, -sn), vec2(sn, cs)) * (local - vec2(0.5)) + vec2(0.5);

    // 2) 低频噪声位移：让边缘像手抖着画出来的
    vec2 nuv = local * noise_scale + vec2(time_seed * 5.31, TIME * jitter_speed);
    vec2 warp = vec2(
        vnoise(nuv + vec2(0.0, 0.0)),
        vnoise(nuv + vec2(19.7, 7.3))
    ) - 0.5;
    local += warp * jitter_strength * 2.0;
    local = clamp(local, vec2(0.0), vec2(1.0));
    vec2 uv = cell_origin + local * cell_size;

    // 3) 原始 alpha 与墨晕（膨胀采样）
    float core = texture(TEXTURE, uv).a;
    vec2 px = TEXTURE_PIXEL_SIZE * max(ink_width, 0.0001);
    float dil = 0.0;
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(px.x, 0.0), vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(-px.x, 0.0), vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(0.0, px.y), vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(0.0, -px.y), vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(px.x, px.y) * 0.7, vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(-px.x, px.y) * 0.7, vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(px.x, -px.y) * 0.7, vec2(0.001), vec2(0.999))).a);
    dil = max(dil, texture(TEXTURE, clamp(uv + vec2(-px.x, -px.y) * 0.7, vec2(0.001), vec2(0.999))).a);

    // 4) 边缘侵蚀：用噪声打掉一部分边缘像素，形成不均匀墨边
    float n1 = vnoise(uv * ink_noise_scale + vec2(time_seed * 2.0, TIME * 0.35));
    float eroded = smoothstep(0.0, 1.0, core * (0.45 + 1.05 * n1));
    float a = mix(core, min(core, eroded), ink_edge_strength);

    float bleed = clamp(dil - core, 0.0, 1.0) * ink_bleed;

    // 5) 颜色：墨色描边 + 主体色，纸面颗粒做轻微明暗
    float grain = vnoise(uv * ink_noise_scale * 1.63 + vec2(7.7, 3.1));
    vec3 glyph = mix(base_color.rgb, danger_color.rgb, danger_mix);
    glyph *= 0.92 + 0.16 * grain;
    glyph += pulse * 0.35 * (1.0 - glyph);
    vec3 col = mix(ink_color.rgb, glyph, smoothstep(0.0, 0.72, a));

    float alpha = max(a, bleed * 0.85) * base_alpha;
    if (alpha < 0.01) {
        discard;
    }
    COLOR = vec4(col, alpha);
}
