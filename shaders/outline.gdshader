
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 outline_color : source_color = vec4(0.12, 0.65, 0.62, 1.0);
uniform float outline_width_px = 2.0;
uniform vec2 viewport_size = vec2(1920.0, 1080.0);

void vertex() {
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 view_normal = normalize(
        (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz
    );

    vec4 clip_pos = PROJECTION_MATRIX * view_pos;
    vec4 clip_normal = PROJECTION_MATRIX * vec4(view_normal, 0.0);

    vec2 screen_normal = normalize(clip_normal.xy + vec2(0.000001));

    clip_pos.xy += screen_normal *
        (2.0 * outline_width_px / viewport_size) * clip_pos.w;

    POSITION = clip_pos;
}

void fragment() {
    ALBEDO = outline_color.rgb;
}
