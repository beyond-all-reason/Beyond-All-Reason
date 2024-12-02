#version 150 compatibility

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D screenCopyTexture;
uniform sampler2D distortionTexture;
uniform float distortionStrength = 1.0;
uniform vec2 inverseScreenResolution = vec2(1920, 1080);

//__DEFINES__
void main(void) {
    vec4 distortion = texture2D(distortionTexture, gl_TexCoord[0].st);
    distortion.rgb = distortion.rgb * 2.0 - 1.0;
    if (length(distortion.rg) < 0.01) {
        gl_FragColor = vec4(0.0);
        return;
    }
    vec2 distortedUVs  = gl_TexCoord[0].st + distortionStrength * distortion.rg * 0.01;

    // hard clamp near the edges of the screen
    vec2 halfTexelSize = inverseScreenResolution;

    #ifndef CHROMATIC_ABERRATION
        distortedUVs = clamp(distortedUVs, halfTexelSize, 1.0-halfTexelSize);
        vec4 screen = texture2D(screenCopyTexture, distortedUVs);
    #else
        // Chromatic aberration.
        //Scale the UVs by distortion strenth, and generate 3 new UV coordinates to sample the screen texture.
        vec4 screen = vec4(0);
        distortedUVs  = gl_TexCoord[0].st + distortionStrength * distortion.rg * (0.01 ) ;
        distortedUVs = clamp(distortedUVs, halfTexelSize, 1.0-halfTexelSize);
        screen.ga = texture2D(screenCopyTexture, distortedUVs).ga;

        distortedUVs  = gl_TexCoord[0].st + distortionStrength * distortion.rg * (0.01 / CHROMATIC_ABERRATION);
        distortedUVs = clamp(distortedUVs, halfTexelSize, 1.0-halfTexelSize);
        screen.r = texture2D(screenCopyTexture, distortedUVs).r;

        distortedUVs  = gl_TexCoord[0].st + distortionStrength * distortion.rg * (0.01 * CHROMATIC_ABERRATION);
        distortedUVs = clamp(distortedUVs, halfTexelSize, 1.0-halfTexelSize);
        screen.b = texture2D(screenCopyTexture, distortedUVs).b;
    #endif
    #if 1
    if (distortion.b < -1.0){
        //NEAT!
        //Motion Blur
        //screen = texture2D(screenCopyTexture, gl_TexCoord[0].st);
        vec2 blurdirection = distortion.rg * 0.8;
        screen = texture2D(screenCopyTexture, gl_TexCoord[0].st + 2*halfTexelSize *blurdirection);
        screen += texture2D(screenCopyTexture, gl_TexCoord[0].st - 2*halfTexelSize *blurdirection);
        screen += texture2D(screenCopyTexture, gl_TexCoord[0].st - 4*halfTexelSize* blurdirection);
        screen /= 3.0;
        gl_FragColor.rgba = vec4(screen.rgb, 0.65);
        return;
    }
    #endif
    if (gl_TexCoord[0].x > 0.66){ // right half?
        if (gl_TexCoord[0].y > 0.75){ // top right
            if (distortion.b < -0.01 )
            gl_FragColor = vec4(vec3(distortion.rg, 0.0) * 0.5 + 0.5, 0.7);
            else gl_FragColor = vec4(screen.rgb, 0.0);
        }else{ // bottom right just straight up debug out the actual distortion RGB texture
            if (distortion.a > 0.01 )
              gl_FragColor = vec4(distortion.rgb * 0.5 + 0.5, 1.0);
            else gl_FragColor = vec4(fract(gl_FragCoord.xy * 0.1), 0.0, 0.2 * step(0.5, fract(gl_FragCoord.x * 0.1)));
        }
    }else{ // left half
        //if (gl_TexCoord[0].y > 0.5){ // top left
        if (gl_TexCoord[0].y < 0.75){ // top right
            gl_FragColor = vec4(screen.rgb, 1.0);

        }else{
            
            gl_FragColor = vec4(0.0);
        }
    }

    //gl_FragColor = vec4(distortion.stt,1.99);
    //gl_FragColor.rg = gl_TexCoord[0].st; // to debug texture coordinates
}