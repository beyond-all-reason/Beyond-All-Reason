#version 120

uniform float time;
uniform vec2 center;
uniform vec4 u_color;

varying vec4 worldPos;
varying vec4 vColor;

// =======================================================================
// [CONFIGURATION]
// =======================================================================

// 1. SIZE: Lower = Bigger clouds
const float NOISE_SCALE = 0.005;

// 2. SPEED: [UPDATED] Very slow drift now (Fire from above doesn't "run" away)
const vec2 SCROLL_SPEED = vec2(0.1, -0.1);

// 3. CONTRAST: 1.0 = Blurry/Flat. 0.0 = Sharp edges.
const float SHARPNESS = 0.2;

// 4. VISIBILITY:
const float OPACITY_MIN = 0.35;
const float OPACITY_MAX = 0.5;

// 5. DETAIL: 0.0 to 1.0
const float DETAIL_STRENGTH = 0.4;

// 6. ACCENT COLOR (The 2nd color - "hot" parts).
const vec3 ACCENT_COLOR = vec3(1.0, 0.91, 0.29);

// 7. COLOR MIX STRENGTH
const float COLOR_MIX_AMOUNT = 0.1;

// 8. WIND WOBBLE (Randomness)
const float WOBBLE_STRENGTH = 0.1;
const float WOBBLE_FREQ = 0.5;

// How fast does it grow/shrink?
const float PULSE_SPEED = 1;

// How much does the size change? (0.0 = None, 0.5 = Massive pulsing)
const float PULSE_AMPLITUDE = 0.001;

// =======================================================================

float random(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    // 1. Setup Coordinates & Pulse
    vec2 uv = (worldPos.xz - center) * NOISE_SCALE;

    // Pulse effect (zoom in/out slightly)
    float pulse = 1.0 + sin(time * PULSE_SPEED) * PULSE_AMPLITUDE;
    uv *= pulse;

    // 2. Movement Logic
    vec2 baseFlow = time * SCROLL_SPEED;
    vec2 wander   = vec2(sin(time * WOBBLE_FREQ), cos(time * WOBBLE_FREQ * 2.0));
    vec2 flow     = baseFlow + (wander * WOBBLE_STRENGTH);

    // 3. Noise Generation
    float n1 = noise(uv - flow);
    float n2 = noise(uv * 2.0 + flow * 1.5);
    float n3 = noise(uv * 4.0 + flow * 3.0);

    float weightedNoise = (n1 * 0.5) + (n2 * 0.3) + (n3 * DETAIL_STRENGTH);
    weightedNoise /= (0.8 + DETAIL_STRENGTH);

    // 4. Sharpness & Alpha
    float density = smoothstep(0.5 - (0.5 * SHARPNESS), 0.5 + (0.5 * SHARPNESS), weightedNoise);
    float finalAlpha = mix(OPACITY_MIN, OPACITY_MAX, density);

    // 5. Final Color
    vec3 mixedColor = mix(vColor.rgb, ACCENT_COLOR, density * COLOR_MIX_AMOUNT);

    gl_FragColor = vec4(mixedColor, vColor.a * finalAlpha);
}
