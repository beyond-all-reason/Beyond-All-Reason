local vs =
[[
	#version 150 compatibility
	#line 10004

	out Data {
		noperspective vec3 noiseSeed;
		noperspective vec2 uv;
	};

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)

	void main() {
		const float noiseFreq = 1.2;
		noiseSeed = (gl_Vertex.xyz) * noiseFreq;
		uv = gl_MultiTexCoord0.xy;

		vec2 uvs = NORM2SNORM(uv);
		gl_Position = vec4(uvs, 0.0, 1.0);
	}
]]

local fs =
[[
	#version 150 compatibility
	#line 20014

	uniform sampler2D unitTex1;
	uniform sampler2D unitTex2;
	uniform sampler2D unitTexN;

	uniform sampler2D wreckTex1;
	uniform sampler2D wreckTex2;
	uniform sampler2D wreckTexN;


	in Data {
		noperspective vec3 noiseSeed;
		noperspective vec2 uv;
	};

	#define NORM2SNORM(value) (value * 2.0 - 1.0)
	#define SNORM2NORM(value) (value * 0.5 + 0.5)

	// rotation matrix for fbm octaves
	mat3 m = mat3( 0.00,  0.80,  0.60,
				  -0.80,  0.36, -0.48,
				  -0.60, -0.48,  0.64 );

//	float hash( float n ) {
//		return fract(sin(n)*43758.5453123);
//	}

	#if 1
		// *** Use this for integer stepped ranges, ie Value-Noise/Perlin noise functions.
		#define HASHSCALE1 .1031
		#define HASHSCALE3 vec3(.1031, .1030, .0973)
		#define HASHSCALE4 vec4(.1031, .1030, .0973, .1099)
	#else
		// For smaller input rangers like audio tick or 0-1 UVs use these...
		#define HASHSCALE1 443.8975
		#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
		#define HASHSCALE4 vec3(443.897, 441.423, 437.195, 444.129)
	#endif


	//----------------------------------------------------------------------------------------
	//  1 out, 1 in...
	float hash11(float p) {
		vec3 p3  = fract(vec3(p) * HASHSCALE1);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.x + p3.y) * p3.z);
	}

	#define hash hash11

	// 3d noise function
	float noise( in vec3 x )
	{
		vec3 p = floor(x);
		vec3 f = fract(x);
		f = f*f*(3.0-2.0*f);
		float n = p.x + p.y*57.0 + 113.0*p.z;
		float res = mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
							mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
						mix(mix( hash(n+113.0), hash(n+114.0),f.x),
							mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
		return res;
	}

	// fbm noise for 2-4 octaves including rotation per octave
	float fbm( vec3 p ) {
		float f = 0.0;
		f += 0.5 * noise( p );
		p = m * p * 2.02;
		f += 0.25 * noise( p );
		// set to 1 for 2 octaves
		#if 1
			return f / 0.75;
		#else
			p = m * p * 2.03;
			f += 0.125 * noise( p );
			// set to 1 for 3 octaves, 0 for 4 octaves
			#if 1
				return f / 0.875;
			#else
				p = m * p * 2.01;
				f += 0.0625 * noise( p );
				return f / 0.9375;
			#endif
		#endif
	}

	// RNM - Already unpacked
	// https://www.shadertoy.com/view/4t2SzR
	vec3 NormalBlendUnpackedRNM(vec3 n1, vec3 n2) {
		n1 += vec3(0.0, 0.0, 1.0);
		n2 *= vec3(-1.0, -1.0, 1.0);

		return n1 * dot(n1, n2) / n1.z - n2;
	}

	void main() {
		vec4 unitTex1Color = textureLod(unitTex1, uv, 0.0);
		vec4 unitTex2Color = textureLod(unitTex2, uv, 0.0);
		vec4 unitTexNormal = textureLod(unitTexN, uv, 0.0);
		unitTexNormal.xyz = normalize(NORM2SNORM(unitTexNormal.xyz));

		vec4 wreckTex1Color = textureLod(wreckTex1, uv, 0.0);
		vec4 wreckTex2Color = textureLod(wreckTex2, uv, 0.0);
		vec4 wreckTexNormal = textureLod(wreckTexN, uv, 0.0);
		wreckTexNormal.xyz = normalize(NORM2SNORM(wreckTexNormal.xyz));

		const vec2 noiseBounds = vec2(0.33, 0.8);

		float mixNoise = smoothstep(noiseBounds.x, noiseBounds.y, fbm(noiseSeed));

		gl_FragData[0] = vec4( mix(unitTex1Color.rgba, wreckTex1Color.rgba, mixNoise));
		gl_FragData[1] = vec4( mix(unitTex2Color.rgb, wreckTex2Color.rgb, mixNoise), max(unitTex2Color.a, wreckTex2Color.a));
		gl_FragData[2] = vec4( SNORM2NORM(normalize(mix(unitTexNormal.xyz, wreckTexNormal.xyz, mixNoise))), max(unitTexNormal.a, wreckTexNormal.a));
	}
]]



local GL_RGBA = 0x1908

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2

local function new(class)
	return setmetatable(
	{
		shader = nil,
		fboAttach = {},
		fbo = {},

		scavUnitDefs = {},

		armTextures = {},
		coreTextures = {},

		armTexInfo = nil,
		corTexInfo = nil,

	}, class)
end

local DrawScavAtlas = setmetatable({}, {
	__call = function(self, ...) return new(self, ...) end,
	})
DrawScavAtlas.__index = DrawScavAtlas


local function GetNormal(unitDef, featureDef)
	local normalMap = "unittextures/blank_normal.dds"

	if unitDef and unitDef.customParams.normaltex and VFS.FileExists(unitDef.customParams.normaltex) then
		return unitDef.customParams.normaltex
	end

	if featureDef then
		local tex1 = featureDef.model.textures.tex1
		local tex2 = featureDef.model.textures.tex2

		local unittexttures = "unittextures/"
		if (VFS.FileExists(unittexttures .. tex1)) and (VFS.FileExists(unittexttures .. tex2)) then
			normalMap = unittexttures .. tex1:gsub("%.","_normals.")
			-- Spring.Echo(normalMap)
			if (VFS.FileExists(normalMap)) then
				return normalMap
			end
			normalMap = unittexttures .. tex1:gsub("%.","_normal.")
			-- Spring.Echo(normalMap)
			if (VFS.FileExists(normalMap)) then
				return normalMap
			end
		end
	end

	return normalMap
end

function DrawScavAtlas:Initialize()
	local armTexMapping = {
		[0] = 0,
		[1] = 1,
		[2] = 2,
	}

	local coreTexMapping = {
		[0] = 3,
		[1] = 4,
		[2] = 5,
	}

	for i = 1, #UnitDefs do
		local name = UnitDefs[i].name
		if string.find(name, "_scav") then
			if name:sub(1,3) == "arm" then
				self.scavUnitDefs[i] = armTexMapping
			elseif name:sub(1,3) == "cor" then
				self.scavUnitDefs[i] = coreTexMapping
			end
		end
	end

	local texParams = {
		format = GL_RGBA,
		border = false,
		min_filter = GL.LINEAR_MIPMAP_LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}

	self.armTextures = {
		[0] = string.format("%%%d:0", UnitDefNames["armpw"].id),
		[1] = string.format("%%%d:1", UnitDefNames["armpw"].id),
		[2] = GetNormal(UnitDefNames["armpw"], nil),
		[3] = string.format("%%-%d:0", FeatureDefNames["armpw_dead"].id),
		[4] = string.format("%%-%d:1", FeatureDefNames["armpw_dead"].id),
		[5] = GetNormal(nil, FeatureDefNames["armpw_dead"]),
	}

	self.coreTextures = {
		[0] = string.format("%%%d:0", UnitDefNames["corak"].id),
		[1] = string.format("%%%d:1", UnitDefNames["corak"].id),
		[2] = GetNormal(UnitDefNames["corak"], nil),
		[3] = string.format("%%-%d:0", FeatureDefNames["corak_dead"].id),
		[4] = string.format("%%-%d:1", FeatureDefNames["corak_dead"].id),
		[5] = GetNormal(nil, FeatureDefNames["corak_dead"]),
	}

	self.armTexInfo = gl.TextureInfo(self.armTextures[0])
	self.corTexInfo = gl.TextureInfo(self.coreTextures[0])

	for i = 0, 2 do
		self.fboAttach[i] = gl.CreateTexture(self.armTexInfo.xsize, self.armTexInfo.ysize, texParams)
		if not self.fboAttach[i] then
			Spring.Echo("DrawScavAtlas: FBO attachment creation error:\n")
		end
	end

	for i = 3, 5 do
		self.fboAttach[i] = gl.CreateTexture(self.corTexInfo.xsize, self.corTexInfo.ysize, texParams)
		if not self.fboAttach[i] then
			Spring.Echo("DrawScavAtlas: FBO attachment creation error:\n")
		end
	end

	self.fbo["arm"] = gl.CreateFBO({
		color0 = self.fboAttach[0],
		color1 = self.fboAttach[1],
		color2 = self.fboAttach[2],
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT},
	})

	self.fbo["core"] = gl.CreateFBO({
		color0 = self.fboAttach[3],
		color1 = self.fboAttach[4],
		color2 = self.fboAttach[5],
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT, GL_COLOR_ATTACHMENT1_EXT, GL_COLOR_ATTACHMENT2_EXT},
	})

	if not self.fbo["arm"] or not self.fbo["core"] then
		Spring.Echo("DrawScavAtlas: FBO creation error:\n")
	end

	self.shader = gl.CreateShader({
		vertex = vs,
		fragment = fs,

		uniformInt = {
			unitTex1 = 0,
			unitTex2 = 1,
			unitTexN = 2,

			wreckTex1 = 3,
			wreckTex2 = 4,
			wreckTexN = 5,
		},
		uniformFloat = {
		},
	})

	local shLog = gl.GetShaderLog() or ""

	if not self.shader then
		Spring.Echo(string.format("DrawScavAtlas: [%s] shader errors:\n%s", "DrawScavAtlas", shLog))
		return false
	elseif shLog ~= "" then
		Spring.Echo(string.format("DrawScavAtlas: [%s] shader warnings:\n%s", "DrawScavAtlas", shLog))
	end

end

function DrawScavAtlas:GetTexture(udID, texNum)
	if self.scavUnitDefs[udID] then
		if texNum >= 0 and texNum <= 3 then
			return self.fboAttach[ self.scavUnitDefs[udID][texNum] ]
		end
	end
end

function DrawScavAtlas:Execute(saveDebug)
	if not self.shader then
		return
	end

	if not gl.IsValidFBO(self.fbo["arm"]) or not gl.IsValidFBO(self.fbo["core"]) then
		return
	end

	gl.ActiveShader(self.shader, function ()

		---------- ARM SCAV ATLAS ------------

		for i = 0, 5 do
			gl.Texture(i, self.armTextures[i])
		end

		gl.DepthTest(false)
		gl.Blending(false)
		gl.Culling(GL.BACK)

		gl.ActiveFBO(self.fbo["arm"], function()
			--[[
			gl.PushPopMatrix(function()
				gl.MatrixMode(GL.PROJECTION); gl.LoadIdentity();
				gl.MatrixMode(GL.MODELVIEW); gl.LoadIdentity();
				--gl.TexRect(-1, -1, 1, 1)
			end)
			]]--
			for i = 1, #UnitDefs do
				local name = UnitDefs[i].name
				if name:sub(1,3) == "arm" and not self.scavUnitDefs[i] then
					gl.UnitShape(i, -1, true, false, true)
				end
			end

			if saveDebug then
				local gf = Spring.GetGameFrame()
				self.fbo["arm"].readbuffer  = GL_COLOR_ATTACHMENT0_EXT
				gl.SaveImage(0, 0, self.armTexInfo.xsize, self.armTexInfo.ysize, string.format("armAtlas_%d_0.png", gf))
				self.fbo["arm"].readbuffer  = GL_COLOR_ATTACHMENT1_EXT
				gl.SaveImage(0, 0, self.armTexInfo.xsize, self.armTexInfo.ysize, string.format("armAtlas_%d_1.png", gf))
				self.fbo["arm"].readbuffer  = GL_COLOR_ATTACHMENT2_EXT
				gl.SaveImage(0, 0, self.armTexInfo.xsize, self.armTexInfo.ysize, string.format("armAtlas_%d_2.png", gf))

			end
		end)

		---------- CORE SCAV ATLAS ------------

		for i = 0, 5 do
			gl.Texture(i, self.coreTextures[i])
		end

		gl.ActiveFBO(self.fbo["core"], function()
			--[[
			gl.PushPopMatrix(function()
				gl.MatrixMode(GL.PROJECTION); gl.LoadIdentity();
				gl.MatrixMode(GL.MODELVIEW); gl.LoadIdentity();
				--gl.TexRect(-1, -1, 1, 1)
			end)
			]]--
			for i = 1, #UnitDefs do
				local name = UnitDefs[i].name
				if name:sub(1,3) == "cor" and not self.scavUnitDefs[i] then
					gl.UnitShape(i, -1, true, false, true)
				end
			end

			if saveDebug then
				local gf = Spring.GetGameFrame()
				self.fbo["core"].readbuffer  = GL_COLOR_ATTACHMENT0_EXT
				gl.SaveImage(0, 0, self.corTexInfo.xsize, self.corTexInfo.ysize, string.format("coreAtlas_%d_0.png", gf))
				self.fbo["core"].readbuffer  = GL_COLOR_ATTACHMENT1_EXT
				gl.SaveImage(0, 0, self.corTexInfo.xsize, self.corTexInfo.ysize, string.format("coreAtlas_%d_1.png", gf))
				self.fbo["core"].readbuffer  = GL_COLOR_ATTACHMENT2_EXT
				gl.SaveImage(0, 0, self.corTexInfo.xsize, self.corTexInfo.ysize, string.format("coreAtlas_%d_2.png", gf))
			end
		end)

	end)

	for i = 0, 5 do
		gl.GenerateMipmap(self.fboAttach[i])
	end

	---------- CORE SCAV ATLAS ------------

	for i = 0, 5 do
		gl.Texture(i, false)
	end
end

function DrawScavAtlas:Finalize()
	gl.DeleteFBO(self.fbo["arm"])
	gl.DeleteFBO(self.fbo["core"])

	for i = 0, 5 do
		gl.DeleteTexture(self.fboAttach[i])
	end

	gl.DeleteShader(self.shader)
end

return DrawScavAtlas
