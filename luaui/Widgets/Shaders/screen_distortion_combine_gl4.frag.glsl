#version 150 compatibility

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D screenCopyTexture;
uniform sampler2D distortionTexture;
uniform float distortionStrength = 1.0;

//__DEFINES__
void main(void) {
    vec4 distortion = texture2D(distortionTexture, gl_TexCoord[0].st);
    distortion.rgb = distortion.rgb * 2.0 - 1.0;
    vec4 screen = texture2D(screenCopyTexture, gl_TexCoord[0].st + distortionStrength * distortion.rg * 0.01);
    if (gl_TexCoord[0].x > 0.66){ // right half?
        if (gl_TexCoord[0].y > 0.5){ // top right
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
            gl_FragColor = vec4(screen.rgb, 1.0);

    }

    //gl_FragColor = vec4(distortion.stt,1.99);
    //gl_FragColor.rg = gl_TexCoord[0].st; // to debug texture coordinates
}