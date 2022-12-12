
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "Infolos API",
		version = 3,
		desc = "Draws the info texture needed for many shaders",
		author = "Beherith",
		date = "2022.12.12",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = -10000, -- lol this isnt even a number
		enabled = false
	}
end

local GL_RGBA32F_ARB = 0x8814
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- TODO: 2022.12.12
	-- make it work?
	-- make api share?

---- CONFIGURABLE PARAMETERS: -----------------------------------------

local shaderConfig = {
	-- These are static parameters, cannot be changed during runtime
	RAYMARCHSTEPS = 32, -- must be at least one, quite expensive
	RESOLUTION = 2, -- THIS IS EXTREMELY IMPORTANT and specifies the fog plane resolution as a whole! 1 = max, 2 = half, 4 = quarter etc.
	FOGTOP = 300, -- deprecated
	NOISESAMPLES = 8, -- how many samples of 3D noise to take
	NOISESCALE = 1.2,
	NOISETHRESHOLD = -0.0,
}

---------------------------------------------------------------------------

local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()

local autoreload = true

local infoShader
local infoTexture
local texX, texY
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")



function widget:Initialize()
	local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()
	texX = Game.mapSizeX/8
	texY = Game.mapSizeZ/8
	
	infoTexture = gl.CreateTexture(texX, texY, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
		})
		
	infoShader = LuaShader({
			--while this vertex shader seems to do nothing, it actually does the very important world space to screen space mapping for gl.TexRect!
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
			#extension GL_ARB_texture_query_lod : enable
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
				int lod = int(textureQueryLOD(tex, p).x);
				vec2 texSize = vec2(textureSize(tex, lod));
				vec2 off = vec2(time);
				vec4 c = vec4(0.0);
				for (int i = 0; i<4; i++) {
					off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0) / texSize;
					c += texture2D(tex, p + off);
				}
				c *= 0.25;
				return smoothstep(0.5, 1.0, c);
			}
		#else
			#define getTexel texture2D
		#endif

			const mat2 m = mat2(0.707107, -0.707107, 0.707107, 0.707107);

			float diagLines1(vec2 uv) {
				float col = 1.0;

				uv = m * uv;
				uv *= 2048.0;
				uv += 2.0 * vec2(-time, -time);

				float c = sin(uv.x) * 0.15;
				col -= c;
				col = pow(col, 2.75);

				return col;
			}
			
			float diagLines2(vec2 uv) {
				float col = 1.0;

				uv = m * uv;
				uv *= 2048.0;
				uv += 2.0 * vec2(-time, -time);

				float c = sin(uv.x) * 0.20;
				col -= c;
				col = pow(col, 4.0);

				return col;
			}

			float radarAnim(vec2 uv) {
				float d = distance(vec2(0.5), uv);
				float d0 = 0.1 * time;
				float dt1 = 1.0 - smoothstep(0.0, 0.1, fract(4.0 * (d0 - d)));
				dt1 = pow(dt1, 8.0);

				return mix(1.0, 8.0, dt1);
			}

			float hex2(vec2 p, float width, float coreSize) {
				p.x *= 0.57735 * 2.0;
				p.y += mod(floor(p.x), 2.0) * 0.5;
				p = abs((mod(p, 1.0) - 0.5));
				float val = abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
				return smoothstep(coreSize, width, val);
			}

			void main() {
				gl_FragColor  = vec4(0.0);
				
				float height = texture2D(tex3, texCoord).x;
				float heightStatus = smoothstep(-3.0, 0.0, height);

				vec2 radarJammer = getTexel(tex2, texCoord).rg;

				float radarFull = step(0.8, radarJammer.r);
				float radarEdge = float(radarJammer.r > 0.0 && radarJammer.r <= 0.9);

				vec4 radarColor = mix(radarColor2 * radarEdge, radarColor1 * radarFull, radarJammer.r);

				gl_FragColor += jamColor * radarJammer.g;
				gl_FragColor += radarColor;// * hex2(64.0 * texCoord, 0.025, 0.2) * radarAnim(texCoord);

				float los = getTexel(tex0, texCoord).r;
				float airlos = getTexel(tex1, texCoord).r;
				float losStatus = mix(los, airlos, 0.2);

				gl_FragColor += losColor * losStatus;

				//gl_FragColor.rgb += alwaysColor.rgb * mix(hex2(64.0 * texCoord, 0.025, 0.2), 1.0, max(radarFull, losStatus));

				float terraIncognitaStatus = 1.0 - max(radarFull, losStatus);
				float terraIncognitaEffect = mix(diagLines2(texCoord), diagLines1(texCoord), heightStatus);
				
				gl_FragColor.rgb += alwaysColor.rgb * mix(1.0, terraIncognitaEffect, terraIncognitaStatus);

				gl_FragColor.a = 0.03;
				gl_FragColor.rgba = vec4(0.0);
				
				gl_FragColor.r = los;
				gl_FragColor.g += airlos * 0.33;
				gl_FragColor.b = 0.5;
				gl_FragColor.b += radarJammer.r;
				gl_FragColor.b -= 2*radarJammer.g;
				
				gl_FragColor.a = 0.07;
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
	)
	
	shaderCompiled = infoShader:Initialize()
	if (shaderCompiled == nil) then
		return
	end
end

function widget:Shutdown()
	if infoTexture then gl.DeleteTexture(infoTexture) end

end

local windX = 0
local windZ = 0

local gameFramePassed
function widget:GameFrame(n)
	if (n%2) == 0 then 
		gameFramePassed = true
	end
end

function widget:Update()
end

local function renderToTextureFunc() -- this draws the fogspheres onto the texture
	--gl.DepthMask(false) 
	gl.Texture(0, "$info:los")
	gl.Texture(1, "$info:airlos")
	gl.Texture(2, "$info:radar") --$info:los
	gl.Texture(3, "$heightmap")
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Texture(3, false)
end

function widget:DrawWorldPreUnit() 
	
	gl.DepthMask(false) -- dont write to depth buffer
	gl.Culling(false) -- cause our tris are reversed in plane vbo
	if gameFramePassed then 
		infoShader:Activate()
		infoShader:SetUniformFloat("alwaysColor", alwaysColor[1],alwaysColor[2],alwaysColor[3],alwaysColor[4])
		infoShader:SetUniformFloat("losColor", losColor[1],losColor[2],losColor[3],losColor[4])
		--infoShader:SetUniformFloat("radarColor1", radarColor1)
		--infoShader:SetUniformFloat("jamColor", jamColor)
		--infoShader:SetUniformFloat("radarColor2", radarColor2)
		gl.RenderToTexture(infoTexture, renderToTextureFunc)
		infoShader:Deactivate()
		gameFramePassed = false
	end


	gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
end

function widget:DrawScreen()
	gl.Texture(0, infoTexture)
	gl.Blending(GL.ONE, GL.ZERO)
	gl.TexRect(0, 0, 1000, 1000, 0, 0, 1, 1)
end