#version 150 compatibility

uniform sampler2D screenCopyTexture;
uniform sampler2D distortionTexture;
uniform float distortionStrength = 1.0;

//__DEFINES__
void main(void) {
    vec4 distortion = texture2D(distortionTexture, gl_TexCoord[0].st);
    distortion.rgb = distortion.rgb * 2.0 - 1.0;
    vec4 screen = texture2D(screenCopyTexture, gl_TexCoord[0].st + distortionStrength * distortion.rg * 0.02);
    if (gl_TexCoord[0].x > 0.5){ // right half?
        if (gl_TexCoord[0].y > 0.5){ // top right
            gl_FragColor = vec4(distortion.rgb, 1.0);
        }else{ // bottom right
        }
    }else{ // left half
        if (gl_TexCoord[0].y > 0.5){ // top left
            gl_FragColor = vec4(screen.rgb, 1.0);
        }else{ // bottom left
            gl_FragColor = vec4(0.0);
        }
    }

    //gl_FragColor = vec4(distortion.stt,1.99);
    //gl_FragColor.rg = gl_TexCoord[0].st; // to debug texture coordinates
}