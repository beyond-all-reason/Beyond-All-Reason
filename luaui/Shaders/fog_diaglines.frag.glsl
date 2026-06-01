#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

uniform sampler2D mapDepths;
uniform sampler2D coverageTex; // accumulated max(los, radar) on LOS-mip resolution

uniform vec4 lineColor;     // rgb = color, a = strength multiplier
uniform float lineFreq;     // elmos per line cycle (world-space; lines anchor to ground)
uniform float lineWidth;    // 0..1 fraction of cycle that is line vs gap (0.5 = equal)
uniform float lineSharpness;// smoothstep half-width at the edge (smaller = sharper)
uniform float scrollSpeed;  // animation speed in cycles per second
uniform float noiseScale;   // elmos per noise cell; larger = bigger, softer blotches
uniform float noiseAmount;  // 0 = lines untouched, 1 = noise can fully fade lines out
uniform float noiseSpeed;   // how fast the noise field drifts/evolves

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
    vec4 texCoord;
};

out vec4 fragColor;

// Cheap 2D value noise: hash the integer grid corners and bilerp with a smooth
// fade. One hash per corner, no octaves — deliberately low cost.
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f); // smoothstep fade
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main(void) {
    // Reconstruct world position from depth. This gives us a way to look up
    // the LOS/radar coverage at the point in the world the screen pixel hits.
    float mapdepth = texture(mapDepths, texCoord.xy).x;

    // Skip pixels where the map gbuffer holds the far plane — that means no
    // map geometry was rendered there (skybox / above-horizon area).
    if (mapdepth >= 0.999999) discard;

    vec4 worldPos = vec4(vec3(texCoord.xy * 2.0 - 1.0, mapdepth), 1.0);
    worldPos = cameraViewProjInv * worldPos;
    worldPos.xyz /= worldPos.w;

    // Skip the map-edge extension: it lies outside the actual playable map.
    if (worldPos.x < 0.0 || worldPos.z < 0.0 ||
        worldPos.x > mapSize.x || worldPos.z > mapSize.y) discard;

    // Sample our temporally smoothed coverage texture (combined los+radar,
    // updated incrementally each gameframe to avoid hard cell-grid jumps as
    // units move). Air-LOS is intentionally excluded.
    vec2 infoUV = clamp(worldPos.xz / mapSize.xy, 0.0, 1.0);
    float coverage = texture(coverageTex, infoUV).r;

    float fogMask = 1.0 - smoothstep(0.0, 1.0, coverage);
    if (fogMask <= 0.001) discard;

    // Diagonal lines computed in world XZ space so they stay anchored to the
    // ground (lines grow when zooming in, shrink when zooming out — matches
    // the behaviour players intuitively expect from a ground overlay).
    // Use a triangle wave (abs of fract) instead of sine so lineWidth maps
    // intuitively to the line-vs-gap fraction of one cycle.
    // lineDir is the (normalised) direction the pattern phase increases along,
    // which sets the line angle: (cos a, sin a) for an angle a measured from the
    // X axis. 36 degrees -> (0.809, 0.588). Keep it normalised so lineFreq stays
    // an honest world-space spacing regardless of angle.
    const vec2 lineDir = vec2(0.80901699, 0.58778525); // 36 degrees
    float scrolled = dot(worldPos.xz, lineDir) / lineFreq - timeInfo.x * scrollSpeed;
    float tri = abs(fract(scrolled) * 2.0 - 1.0); // 0 at line center, 1 at gap center

    // Anti-alias against actual screen-space derivative of the pattern phase.
    // fwidth tells us how many pattern cycles fit in one pixel; we widen the
    // smoothstep band by that to avoid moiré when zoomed out.
    float pixelWidth = fwidth(scrolled) * 2.0;
    float aa = max(lineSharpness, pixelWidth);
    float threshold = clamp(lineWidth, 0.0, 1.0);
    float line = 1.0 - smoothstep(threshold - aa, threshold + aa, tri);

    // Subtle animated noise over the fogged area: low-frequency world-space
    // blotches that slowly drift, locally fading the lines so the pattern feels
    // alive rather than perfectly static. The noise is anchored to the ground
    // (world XZ) and the field itself evolves over time via the z-offset trick.
    vec2 noiseUV = worldPos.xz / noiseScale + vec2(timeInfo.x * noiseSpeed);
    float n = valueNoise(noiseUV);
    // Remap so most of the area is untouched and only the darker patches fade:
    // smoothstep keeps the effect from looking like uniform flicker.
    float fade = 1.0 - noiseAmount * smoothstep(0.35, 0.65, n);
    line *= fade;

    fragColor = vec4(lineColor.rgb, line * fogMask * lineColor.a);
}
