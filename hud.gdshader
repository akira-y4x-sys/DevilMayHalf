shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// ================= PSX =================
uniform int resolution_x = 320;
uniform int resolution_y = 240;
uniform int color_bit_depth = 4;

uniform float jitter_amount = 0.008;
uniform float jitter_speed = 1.2;
uniform float jitter_frequency = 180.0;

uniform float chromatic_aberration_strength = 0.015;

// ================= CRT / VHS =================
uniform float curvature = 0.14;
uniform float corner_soften = 0.06;

uniform float wobble_px = 1.5;
uniform float jitter_px = 1.8;

uniform float tape_noise = 0.22;
uniform float tape_lines = 0.35;

uniform float glow_strength = 0.25;
uniform float glow_threshold = 0.65;

uniform float mask_strength = 0.22;
uniform float mask_scale = 1.0;

// ================= ULTRAKILL =================
uniform float posterize_levels = 32.0;
uniform float contrast = 1.0;
uniform vec3 color_tint = vec3(1.05, 0.92, 0.85);
uniform float grain_intensity = 0.08;

// ================= HELPERS =================
float hash(vec2 p){
    return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

vec2 crt_curve(vec2 uv, float k){
    vec2 cc = uv * 2.0 - 1.0;
    vec2 d = cc * cc;
    cc *= 1.0 + k * vec2(d.y, d.x);
    return cc * 0.5 + 0.5;
}

vec2 psx_jitter(vec2 uv){
    float t = floor(TIME * jitter_speed * 8.0) / 8.0;

    float h = hash(vec2(floor(uv.y * jitter_frequency), t)) - 0.5;
    float v = hash(vec2(floor(uv.x * jitter_frequency), t)) - 0.5;

    return uv + vec2(h, v) * jitter_amount;
}

// ================= MAIN =================
void fragment(){
    vec2 px = SCREEN_PIXEL_SIZE;
    vec2 res = 1.0 / px;
    vec2 uv = SCREEN_UV;

    // === PSX PIXEL SNAP ===
    vec2 grid = vec2(1.0/float(resolution_x), 1.0/float(resolution_y));
    uv = floor(uv / grid) * grid + grid * 0.5;

    uv = psx_jitter(uv);

    // === CRT DISTORTION ===
    uv = crt_curve(uv, curvature);

    // VHS wobble
    uv.x += sin(uv.y * 8.0 + TIME) * wobble_px * px.x;

    // === CHROMATIC (PSX STYLE) ===
    vec2 offset = (uv - 0.5) * chromatic_aberration_strength;

    vec3 col;
    col.r = texture(screen_texture, uv + offset).r;
    col.g = texture(screen_texture, uv).g;
    col.b = texture(screen_texture, uv - offset).b;

    // === COLOR CRUNCH ===
    float levels = pow(2.0, float(color_bit_depth));
    col = floor(col * levels) / levels;

    // === ULTRAKILL STYLE ===
    col = floor(col * posterize_levels) / posterize_levels;
    col = (col - 0.5) * contrast + 0.5;
    col *= color_tint;

    // === VHS NOISE ===
    float n = hash(FRAGCOORD.xy + TIME);
    col += (n - 0.5) * tape_noise * 0.1;

    // === GLOW ===
    vec3 blur = (
        texture(screen_texture, uv).rgb +
        texture(screen_texture, uv + vec2(px.x,0)).rgb +
        texture(screen_texture, uv - vec2(px.x,0)).rgb +
        texture(screen_texture, uv + vec2(0,px.y)).rgb +
        texture(screen_texture, uv - vec2(0,px.y)).rgb
    ) / 5.0;

    vec3 glow = max(blur - vec3(glow_threshold), vec3(0.0));
    col += glow * glow_strength;

    // === MASK ===
    float m = mod(floor(FRAGCOORD.x / mask_scale), 3.0);
    vec3 mask = (m < 1.0) ? vec3(1.1,0.85,0.85) :
                (m < 2.0) ? vec3(0.85,1.1,0.85) :
                            vec3(0.85,0.85,1.1);

    col *= mix(vec3(1.0), mask, mask_strength);

    // === GRAIN ===
    float g = hash(SCREEN_UV + fract(TIME));
    col += (g - 0.5) * grain_intensity;

    COLOR = vec4(col, 1.0);
}