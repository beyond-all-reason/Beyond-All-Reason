-- $Id$
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local GetGameFrame=Spring.GetGameFrame
local GetUnitHealth=Spring.GetUnitHealth

local GADGET_DIR = "LuaRules/Configs/"

local function DrawUnit(unitID, unitDefID, material, drawMode, luaShaderObj)
	-- Spring.Echo('Arm Tanks drawmode',drawMode)
	--if (drawMode ==1)then -- we can skip setting the uniforms as they only affect fragment color, not fragment alpha or vertex positions, so they dont have an effect on shadows, and drawmode 2 is shadows, 1 is normal mode.
	--Spring.Echo('drawing',UnitDefs[Spring.GetUnitDefID(unitID)].name,GetGameFrame())
	--local  health,maxhealth=GetUnitHealth(unitID)
	--health= 2*maximum(0, (-2*health)/(maxhealth)+1) --inverse of health, 0 if health is 100%-50%, goes to 1 by 0 health

	local usx, usy, usz, speed = Spring.GetUnitVelocity(unitID)
	if speed > 0.01 then speed = 1 end
	local offset = (((GetGameFrame()) % 14) * (2.0 / 4096.0)) * speed
	-- check if moving backwards
	local udx, udy, udz = Spring.GetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		offset = -offset
	end

	luaShaderObj:SetUniformAlways("etcLoc", 0.0, 0.0, offset)

	--end
	--// engine should still draw it (we just set the uniforms for the shader)
	return false
end

local function SunChanged(curShaderObj)
	curShaderObj:SetUniformAlways("shadowDensity", gl.GetSun("shadowDensity" ,"unit"))

	curShaderObj:SetUniformAlways("sunAmbient", gl.GetSun("ambient" ,"unit"))
	curShaderObj:SetUniformAlways("sunDiffuse", gl.GetSun("diffuse" ,"unit"))
	curShaderObj:SetUniformAlways("sunSpecular", gl.GetSun("specular" ,"unit"))

	curShaderObj:SetUniformFloatArrayAlways("pbrParams", {
        Spring.GetConfigFloat("tonemapA", 4.8),
        Spring.GetConfigFloat("tonemapB", 0.8),
        Spring.GetConfigFloat("tonemapC", 3.35),
        Spring.GetConfigFloat("tonemapD", 1.0),
        Spring.GetConfigFloat("tonemapE", 1.15),
        Spring.GetConfigFloat("envAmbient", 0.3),
        Spring.GetConfigFloat("unitSunMult", 1.35),
        Spring.GetConfigFloat("unitExposureMult", 1.0),
	})
end

local default_lua = VFS.Include("materials/Shaders/default.lua")

local matTemplate = {
	shaderDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 0",
		"#define flashlights",
		"#define use_vertex_ao",
		"#define use_treadoffset_core",

		"#define SHADOW_SOFTNESS SHADOW_SOFTER",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.07",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define use_normalmapping",
		"#define deferred_mode 1",
		"#define flashlights",
		"#define use_vertex_ao",
		"#define use_treadoffset_core",

		"#define SHADOW_SOFTNESS SHADOW_HARD",

		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		--"#define ROUGHNESS_PERTURB_NORMAL 0.025",
		--"#define ROUGHNESS_PERTURB_COLOR 0.05",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",

		"#define MAT_IDX 5",
	},
	shaderPlugins = {
		VERTEX_GLOBAL_NAMESPACE = [[
			#ifdef SCAVENGER_VERTEX_DISPLACEMENT
				float Perlin3D( vec3 P ) {
					//  https://github.com/BrianSharpe/Wombat/blob/master/Perlin3D.glsl

					// establish our grid cell and unit position
					vec3 Pi = floor(P);
					vec3 Pf = P - Pi;
					vec3 Pf_min1 = Pf - 1.0;

					// clamp the domain
					Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
					vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

					// calculate the hash
					vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
					Pt *= Pt;
					Pt = Pt.xzxz * Pt.yyww;
					const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
					const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
					vec3 lowz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi.zzz * ZINC ) );
					vec3 highz_mod = vec3( 1.0 / ( SOMELARGEFLOATS + Pi_inc1.zzz * ZINC ) );
					vec4 hashx0 = fract( Pt * lowz_mod.xxxx );
					vec4 hashx1 = fract( Pt * highz_mod.xxxx );
					vec4 hashy0 = fract( Pt * lowz_mod.yyyy );
					vec4 hashy1 = fract( Pt * highz_mod.yyyy );
					vec4 hashz0 = fract( Pt * lowz_mod.zzzz );
					vec4 hashz1 = fract( Pt * highz_mod.zzzz );

					// calculate the gradients
					vec4 grad_x0 = hashx0 - 0.49999;
					vec4 grad_y0 = hashy0 - 0.49999;
					vec4 grad_z0 = hashz0 - 0.49999;
					vec4 grad_x1 = hashx1 - 0.49999;
					vec4 grad_y1 = hashy1 - 0.49999;
					vec4 grad_z1 = hashz1 - 0.49999;
					vec4 grad_results_0 = inversesqrt( grad_x0 * grad_x0 + grad_y0 * grad_y0 + grad_z0 * grad_z0 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x0 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y0 + Pf.zzzz * grad_z0 );
					vec4 grad_results_1 = inversesqrt( grad_x1 * grad_x1 + grad_y1 * grad_y1 + grad_z1 * grad_z1 ) * ( vec2( Pf.x, Pf_min1.x ).xyxy * grad_x1 + vec2( Pf.y, Pf_min1.y ).xxyy * grad_y1 + Pf_min1.zzzz * grad_z1 );

					// Classic Perlin Interpolation
					vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
					vec4 res0 = mix( grad_results_0, grad_results_1, blend.z );
					vec4 blend2 = vec4( blend.xy, vec2( 1.0 - blend.xy ) );
					float final = dot( res0, blend2.zxzx * blend2.wwyy );
					return ( final * 1.1547005383792515290182975610039 );  // scale things to a strict -1.0->1.0 range  *= 1.0/sqrt(0.75)
				}
			#endif
		]],
		VERTEX_PRE_TRANSFORM = [[
			#ifdef SCAVENGER_VERTEX_DISPLACEMENT
				modelPos.xyz += Perlin3D(0.5 * modelPos.xyz) * SCAVENGER_VERTEX_DISPLACEMENT * modelNormal;
			#endif
		]],
	},
	shader    = default_lua,
	deferred  = default_lua,
	usecamera = false,
	force = true,
	culling   = GL.BACK,
	predl  = nil,
	postdl = nil,
	texunits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[2] = "$shadow",
		[3] = "$reflection",
		[4] = "%NORMALTEX",
		[5] = "$info",
		[6] = GG.GetBrdfTexture(),
		[7] = GG.GetEnvTexture(),

	},
	DrawUnit = DrawUnit,
	SunChanged = SunChanged,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Automated normalmap detection

local materials = {}
local unitMaterials = {}

local function PackTableIntoString(tbl, str0)
	local str = str0 or ""
	for k, v in pairs(tbl) do
		str = string.format("%s|%s=%s|", str, tostring(k), tostring(v))
	end
	return str
end

for i = 1, #UnitDefs do
	local udef = UnitDefs[i]
	local udefCM = udef.customParams

	if (udefCM.core_tank and udefCM.normaltex and VFS.FileExists(udefCM.normaltex)) then
		local lm = tonumber(udefCM.lumamult) or 1
		local scvd = tonumber(udefCM.scavVertDisp) or 0

		local params = {
			lm = lm,
			scvd = scvd,
		}

		local matName = PackTableIntoString(params, "normalMappedS3O_core_tank")

		if not materials[matName] then
			materials[matName] = Spring.Utilities.CopyTable(matTemplate, true)

			if lm ~= 1 then
				local lmLM = string.format("#define LUMAMULT %f", lm)
				table.insert(materials[matName].shaderDefinitions, lmLM)
				table.insert(materials[matName].deferredDefinitions, lmLM)
			end

			if scvd ~= 0 then
				local lmLM = string.format("#define SCAVENGER_VERTEX_DISPLACEMENT %f", scvd)
				table.insert(materials[matName].shaderDefinitions, lmLM)
				table.insert(materials[matName].deferredDefinitions, lmLM)
			end
		end

		unitMaterials[udef.name] = {matName,
			TEX1 = GG.GetScavTexture(i, 0) or string.format("%%%%%d:0", i),
			TEX2 = GG.GetScavTexture(i, 1) or string.format("%%%%%d:1", i),
			NORMALTEX = udefCM.normaltex
		}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
