#version 420

uniform sampler2D losTex;
uniform sampler2D radarTex;
uniform float blendAlpha; // how strongly the new sample replaces the accumulator (0..1)

in DataVS {
    vec4 texCoord;
};

out vec4 fragColor;

void main(void) {
    float losCov   = texture(losTex,   texCoord.xy).r;
    float radarCov = texture(radarTex, texCoord.xy).r;
    float coverage = max(losCov, radarCov);

    // Output coverage in the red channel; src-alpha blending against the
    // existing accumulator gives an exponential moving average:
    //   accum = blendAlpha * coverage + (1 - blendAlpha) * accum
    fragColor = vec4(coverage, 0.0, 0.0, blendAlpha);
}
