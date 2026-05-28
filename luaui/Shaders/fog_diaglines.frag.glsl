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

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
    vec4 texCoord;
};

out vec4 fragColor;

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
    float scrolled = (worldPos.x + worldPos.z) / lineFreq - timeInfo.x * scrollSpeed;
    float tri = abs(fract(scrolled) * 2.0 - 1.0); // 0 at line center, 1 at gap center

    // Anti-alias against actual screen-space derivative of the pattern phase.
    // fwidth tells us how many pattern cycles fit in one pixel; we widen the
    // smoothstep band by that to avoid moiré when zoomed out.
    float pixelWidth = fwidth(scrolled) * 2.0;
    float aa = max(lineSharpness, pixelWidth);
    float threshold = clamp(lineWidth, 0.0, 1.0);
    float line = 1.0 - smoothstep(threshold - aa, threshold + aa, tri);

    fragColor = vec4(lineColor.rgb, line * fogMask * lineColor.a);
}
