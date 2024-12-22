#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

// This shader is (c) Beherith (mysterme@gmail.com), Licensed under the MIT License

uniform sampler2D metalTex;
uniform sampler2D metalExtractionTex;
uniform sampler2D mapDepths;

uniform float alpha = 1.0;
uniform float minimap = 0.0;
uniform float flipMiniMap = 0.0;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
    vec4 texCoord;
};

out vec4 fragColor;

#if 0 
    vec2 CubicSampler(vec2 uvsin, vec2 texdims){
        vec2 r = uvsin * texdims - 0.5;
        vec2 tf = fract(r);
        vec2 ti = r - tf;
        tf = tf * tf * (3.0 - 2.0 * tf);
        return (tf + ti + 0.5)/texdims;
    }
#endif

void main(void) {
    vec2 infoUV = texCoord.xy;

    if (minimap < 0.5) { // world space
        float mapdepth = texture(mapDepths, infoUV.xy).x;
        vec4 fragWorldPos =  vec4( vec3(infoUV.xy * 2.0 - 1.0, mapdepth),  1.0);

        // reconstruct view pos:
        fragWorldPos = cameraViewProjInv * fragWorldPos;
        fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!

        //clamp fragWorldPos to the infolos tex bounds:
        infoUV = clamp(fragWorldPos.xz / mapSize.xy, 0, 1);

    }else{
        //minimap space is flipped fuck if i know why
        infoUV.y = 1.0 - infoUV.y;
        if (flipMiniMap > 0.5){
            infoUV = 1.0 - infoUV;
        }
    }

    vec2 texDims = vec2(METALTEXX, METALTEXY);
    vec2 centroids = infoUV.xy * texDims;

    vec4 metalSample = texture2D(metalTex, infoUV).rgba;
    //vec4 metalSample = texture2D(metalTex, CubicSampler(infoUV, texDims)).rgba;
    vec4 metalExtractionSample = texture2D(metalExtractionTex, infoUV).rgba;

    vec4 outColor = vec4(0.0, 0.0, 0.0, 0.0);
    outColor.rgb = mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), metalSample.r); // metalness
    outColor.rgb = mix(outColor.rgb, vec3(1.0, 0.0, 0.0), metalExtractionSample.r); // extractedness
    if (minimap < 0.5) { // world
    
        outColor.a = 1.0 *  metalSample.r * alpha; // alpha
    }else { // minimap
        
        outColor.rgb = mix(vec3(0), outColor.rgb, metalSample.r);
        outColor.a = 1.0 *  clamp(metalSample.r, 0.75, 1.0); // alpha

    }

    fragColor = outColor;
}