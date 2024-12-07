#version 150 compatibility

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D screenCopyTexture;
uniform sampler2D distortionTexture;
uniform float distortionStrength = 1.0;
uniform vec2 inverseScreenResolution = vec2(1.0/1920.0, 1.0/1080.0);


vec2 softClampScreen(vec2 UV){
    return clamp(UV, 0.5 * inverseScreenResolution, 1.0 - 0.5 * inverseScreenResolution);
}

//__DEFINES__
void main(void) {

    // As of yet, distortion coords are still stored as centered around 0.5, so we need to shift them to 0.0
    vec4 distortion = texture2D(distortionTexture, gl_TexCoord[0].st);
    distortion.rgb = distortion.rgb * 2.0 - 1.0;
    distortion.rg = (1536.0 * distortion.rg) * inverseScreenResolution;
    if (length(distortion.rg) < 0.001) {
        // Bail early if no real distortion is present
        gl_FragColor = vec4(0.0);
        return;
    }
    // Declare the UV sets and final screen color
    vec2 offsetUV1;
    vec2 offsetUV2;
    vec2 offsetUV3;
    vec4 outputRGBA = vec4(0.0);

  
    // Regular distortion
    if (distortion.b > -1.0 ) {
        vec2 distortionXY = distortion.rg * distortionStrength * 0.01;
        offsetUV1 = softClampScreen(gl_TexCoord[0].st + distortionXY);
        offsetUV2 = softClampScreen(gl_TexCoord[0].st + distortionXY / CHROMATIC_ABERRATION);
        offsetUV3 = softClampScreen(gl_TexCoord[0].st + distortionXY * CHROMATIC_ABERRATION);
    }else{
    // Motion blur
        vec2 blurdirection = distortion.rg * 0.8;
        offsetUV1 = softClampScreen(gl_TexCoord[0].st - 2 * inverseScreenResolution * blurdirection);
        offsetUV2 = softClampScreen(gl_TexCoord[0].st + 2 * inverseScreenResolution * blurdirection);
        offsetUV3 = softClampScreen(gl_TexCoord[0].st + 4 * inverseScreenResolution * blurdirection);
    }
    
    
    vec3 sample1 = texture2D(screenCopyTexture, offsetUV1).rgb;
    vec3 sample2 = texture2D(screenCopyTexture, offsetUV2).rgb;
    vec3 sample3 = texture2D(screenCopyTexture, offsetUV3).rgb;


    if (distortion.b > -1.0 ) { // Regular distortion
        outputRGBA.g = sample1.g;
        outputRGBA.r = sample2.r;
        outputRGBA.b = sample3.b;
        outputRGBA.a = 1.0;
    }else{ // Motion Blur
        outputRGBA.rgb = (sample1.rgb + sample2.rgb + sample3.rgb) / 3.0;
        outputRGBA.a = 0.7;
        //outputRGBA = vec4( sample1, 1.0);
 
    }

    #if (DEBUGCOMBINER == 0)
        gl_FragColor = outputRGBA;

    #else
        if (gl_TexCoord[0].x > 0.66){ // right half?
            if (gl_TexCoord[0].y > 0.75){ // top right
                if (distortion.b < -0.01 )
                gl_FragColor = vec4(vec3(distortion.rg, 0.0) * 0.5 + 0.5, 0.7);
                else gl_FragColor = vec4(outputRGBA.rgb, 0.0);
            }else{ // bottom right just straight up debug out the actual distortion RGB texture
                gl_FragColor = vec4(distortion.rgb * 0.5 + 0.5, 1.0);
            }
        }else{ // left half
            gl_FragColor = outputRGBA;
        }
    #endif


}