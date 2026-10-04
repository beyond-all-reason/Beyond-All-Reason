-- Beheriths notes:
-- This entire lua file gets reloaded every time the f4 view is activated
-- Alpha is blended progressively, so high alphas result in immeditate display
-- NO CONSTGAME HERE !
-- lovely, so the _only_ context available for these shaders is:
-- Spring.Echo("Loading infoMetal.lua")
--[[
LoadFromLua(Shader::IProgramObject* program, const std::string& filename)
...
	p.GetTable("Spring");
	p.AddFunc("GetConfigInt",     LuaUnsyncedRead::GetConfigInt);
	p.AddFunc("GetConfigFloat",   LuaUnsyncedRead::GetConfigFloat);
	p.AddFunc("GetConfigString",  LuaUnsyncedRead::GetConfigString);
	p.AddFunc("GetLosViewColors", LuaUnsyncedRead::GetLosViewColors);
	p.AddFunc("GetSelectedUnitsCount", LuaUnsyncedRead::GetSelectedUnitsCount);
	p.EndTable();
	
for k,v in pairs(Spring) do 
	Spring.Echo(k,v)
end
]]--

-- Author: Beherith (mysterme@gmail.com)

return {
	definitions = {
		Spring.GetConfigInt("HighResInfoTexture") and "#define HIGH_QUALITY\n" or "",
		"#define MetalViewBrightness " .. tostring(Spring.GetConfigFloat("MetalViewBrightness", 1.0) or 1.0),
	},
	vertex = [[#version 130
		varying vec2 texCoord;

		void main() {
			texCoord = gl_MultiTexCoord0.st;
			gl_Position = vec4(gl_Vertex.xyz, 1.0);
		}
	]],
	fragment = [[#version 130
		uniform sampler2D tex0;
		uniform sampler2D tex1;
		varying vec2 texCoord;
		
		vec4 bicubicSample(sampler2D tex, vec2 UV){
			vec2 texSize = textureSize(tex, 0);
			vec2 texSizeInv = 0.33 / texSize;
			vec4 result = vec4(0);
			result += texture2D(tex, vec2(UV.x + texSizeInv.x, UV.y + texSizeInv.y));
			result += texture2D(tex, vec2(UV.x - texSizeInv.x, UV.y + texSizeInv.y));
			result += texture2D(tex, vec2(UV.x - texSizeInv.x, UV.y - texSizeInv.y));
			result += texture2D(tex, vec2(UV.x + texSizeInv.x, UV.y - texSizeInv.y));
			// mixdown:
			return result * 0.25;
		}

		void main() {
			// start with black
			gl_FragColor  = vec4(0.0, 0.0, 0.0, 1.0);
			
			// sample metal and extraction maps
			vec4 metal = bicubicSample(tex0, texCoord);
			vec4 extraction = texture2D(tex1, texCoord);

			// choose between red and cyan based on wether its being extracted
			gl_FragColor.rgb = mix(vec3(0.0, 1.0, 0.6), vec3(0.9, 0, 0), extraction.r);
			
			//Set it black if there is no metal here
			gl_FragColor.rgb =  mix(vec3(0,0,0), gl_FragColor.rgb, metal.r);//step(0.05,metal.r));
			
			//Constrol the brightness of it.
			gl_FragColor.rgb =  mix(vec3(0,0,0), gl_FragColor.rgb, MetalViewBrightness * 1.0);
			
			gl_FragColor.a = 0.25; // default 0.25 quick blend
		}
	]],
	uniformInt = {
		tex0 = 0,
		tex1 = 1,
	},
	textures = {
		[0] = "$info:metal",
		[1] = "$info:metalextraction",
	},
}
