local Spring = Spring
local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()

return {
	definitions = {
		Spring.GetConfigInt("HighResInfoTexture") and "#define HIGH_QUALITY" or "",
	},
	vertex = [[#version 130
		varying vec2 texCoord;
		void main() {
			texCoord = gl_MultiTexCoord0.st;
			gl_Position = vec4(gl_Vertex.xyz, 1.0);
		}
	]],
	fragment = [[#version 130
	#ifdef HIGH_QUALITY
		//#extension GL_ARB_texture_query_lod : enable
	#endif
		uniform float time;
		uniform vec4 alwaysColor;
		uniform vec4 losColor;
		uniform vec4 radarColor1;
		uniform vec4 radarColor2;
		uniform vec4 jamColor;
		uniform sampler2D tex0;
		uniform sampler2D tex1;
		uniform sampler2D tex2;
		uniform sampler2D tex3;
		varying vec2 texCoord;
	#ifdef HIGH_QUALITY
		//! source: http://www.ozone3d.net/blogs/lab/20110427/glsl-random-generator/
		float rand(const in vec2 n)
		{
			return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
		}
		vec4 getTexel(in sampler2D tex, in vec2 p)
		{
			//int lod = int(textureQueryLOD(tex, p).x);
			int lod = 0;
			vec2 texSize = vec2(textureSize(tex, lod));
			vec4 c = vec4(0.0);
			for (int i = 0; i<4; i++) {
				// previously, offset was identical for all pixels, resulting in little gain from multisampling, makes offsets random for each texel fetch
				vec2 off = vec2(time + float(i) * 0.234567); 
				off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0) / texSize;
				c += texture2D(tex, p + off);
			}
			c *= 0.25;
			return smoothstep(0.5, 1.0, c);
		}
	#else
		#define getTexel texture2D
	#endif

		float diagLines(vec2 uv) {
		        // Returns a value between 0 and 1 that form a diagonal pattern.

		        // To produce "diagonal values", we just add x and y.
		        float xy = uv.x + uv.y;

                        // Multiply xy to decrease the period of the sine wave.
			// This is just an arbitrary number. Lower numbers will result in
			// wider lines and gaps.
			xy *= 1000.0;

                        // We want to return a value between 0 and 1,
			// so scale the sine wave amplitude and shift it up.
			// Subtracting time causes the diagonal lines to move down
			// from the top-left.
                        return sin(xy - time) * 0.5 + 0.5;
		}

		void main() {
		        // There are 3 levels of intel, from highest to lowest:
			// - Line of sight (LOS), direct vision
			// - Radar
			// - Fog of war, no vision or radar
			// We want to color an area using its highest level of intel.
			// Then, we add a final modifier to show jamming coverage.

                        // Fog of war
			// Draw alternating diagonal lines for the fog of war.
			// alwaysColor is the fog of war color.
			// Squaring the diagLines sine wave causes more values to be near zero.
			float diagonalLineStrength = pow(diagLines(texCoord), 2);
			gl_FragColor = mix(alwaysColor, alwaysColor * 0.5, diagonalLineStrength);

                        // Radar
			// radarColor2 is the color of ground covered by radar.
			vec4 tex2Texel = getTexel(tex2, texCoord);
			float radar = tex2Texel.r;
			gl_FragColor = max(gl_FragColor, radarColor2 * radar);

                        // Line of sight (LOS), the higest level of intel
			// losColor is the color of ground covered by direct vison (LOS).
			// Often airlos is greater than groundlos.
			float groundlos = getTexel(tex0, texCoord).r;
			float airlos = getTexel(tex1, texCoord).r;
			float losCombined = mix(groundlos, airlos, 0.2);
			gl_FragColor = max(gl_FragColor, losColor * losCombined);

                        // Radar jamming
			// Unlike the other cases, we add the jamming color instead of taking the maximum.
			// The jamming color may contain negative value. For instance, if you subtract
			// blue and green, then this will give a red jamming color while maintaining a similar
			// lighting intensity.
			float jamming = tex2Texel.g;
			gl_FragColor += jamColor * jamming;

                        // Finally, make sure nothing has changed our desired alpha value.
                        gl_FragColor.a = 0.03;
		}
	]],
	uniformFloat = {
		alwaysColor = alwaysColor,
		losColor    = losColor,
		radarColor1 = radarColor,
		jamColor    = jamColor,
		radarColor2 = radarColor2,
	},
	uniformInt = {
		tex0 = 0,
		tex1 = 1,
		tex2 = 2,
		tex3 = 3,
	},
	textures = {
		[0] = "$info:los",
		[1] = "$info:airlos",
		[2] = "$info:radar",
		[3] = "$heightmap",
	},
}
