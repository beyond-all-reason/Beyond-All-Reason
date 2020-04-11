local scavDisplacementPlugin = {
	GLOBAL_OPTIONS = [[
		#define OPTION_SCAV_DISPLACEMENT
	]]
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
		{
			//modelPos.xyz += Perlin3D(0.1 * modelPos.xyz) * SCAVENGER_VERTEX_DISPLACEMENT * normalize(mix(normalize(modelPos.xyz), modelNormal, 0.2));	// this causes gaps
			modelPos.xyz += Perlin3D(0.1 * modelPos.xyz) * SCAVENGER_VERTEX_DISPLACEMENT * normalize(modelPos.xyz);
		}
		#endif
	]],
}

local treeDisplacementPlugun = {
	GLOBAL_OPTIONS = [[
		#define OPTION_TREEWIND
	]],
	VERTEX_GLOBAL_NAMESPACE = [[
		vec2 getWind(int period) {
			vec2 wind;
			wind.x = sin(period * 5.0);
			wind.y = cos(period * 5.0);
			return wind * 12.0f;
		}
	]],
	VERTEX_PRE_TRANSFORM = [[
		// adapted from 0ad's model_common.vs

		vec2 curWind = getWind(simFrame / 750);
		vec2 nextWind = getWind(simFrame / 750 + 1);
		float tweenFactor = smoothstep(0.0f, 1.0f, max(simFrame % 750 - 600, 0) / 150.0f);
		vec2 wind = mix(curWind, nextWind, tweenFactor);




		// fractional part of model position, clamped to >.4
		vec4 fractModelPos = gl_ModelViewMatrix[3];
		fractModelPos = fract(fractModelPos);
		fractModelPos = clamp(fractModelPos, 0.4, 1.0);

		// crude measure of wind intensity
		float abswind = abs(wind.x) + abs(wind.y);

		vec4 cosVec;
		float simTime = 0.02 * simFrame;
		// these determine the speed of the wind's "cosine" waves.
		cosVec.w = 0.0;
		cosVec.x = simTime * fractModelPos[0] + fractModelPos.x;
		cosVec.y = simTime * fractModelPos[2] / 3.0 + fractModelPos.x;
		cosVec.z = simTime * 1.0 + fractModelPos.z;

		// calculate "cosines" in parallel, using a smoothed triangle wave
		vec4 tri = abs(fract(cosVec + 0.5) * 2.0 - 1.0);
		cosVec = tri * tri *(3.0 - 2.0 * tri);

		float limit = clamp((fractModelPos.x * fractModelPos.z * fractModelPos.y) / 3000.0, 0.0, 0.2);

		float diff = cosVec.x * limit;
		float diff2 = cosVec.y * clamp(fractModelPos.y / 30.0, 0.05, 0.2);

		fractModelPos.xyz += cosVec.z * limit * clamp(abswind, 1.2, 1.7);

		fractModelPos.xz += diff + diff2 * wind;
	]]
}

local movingThreadsPlugin = {
	GLOBAL_OPTIONS = [[
		#define OPTION_MOVING_THREADS_ARM
		#define OPTION_MOVING_THREADS_CORE
	]],
	VERTEX_UV_TRANSFORM = [[
		if (BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS_ARM) || BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS_CORE)) {
			#define trackTexOffset floatOptions[0]
			vec4 treadBoundaries;
			if (BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS_ARM) {
				const float atlasSize = 4096.0;
				// note, invert we invert Y axis
				vec4 treadBoundaries = vec4(2572.0, 3070.0, 1548.0, 1761.0) / atlasSize; //(x, X, y, Y);
			}

			if (BITMASK_FIELD(bitOptions, OPTION_MOVING_THREADS_CORE) {
				const float atlasSize = 2048.0;
				// note, invert we invert Y axis
				vec4 treadBoundaries = vec4(1536.0, 2048.0, 1792.0, 2048.0) / atlasSize; //(x, X, y, Y);
			}

			//invert Y axis of texture, swap y and Y because of axis inversion
			treadBoundaries.wz = vec2(1.0) - treadBoundaries.zw;
			if ( all(bvec4(
					greaterThanEqual(modelUV, treadBoundaries.xz),
					lessThanEqual(modelUV, treadBoundaries.yw)))) {
				modelUV.x += trackTexOffset
			}
			#undef trackTexOffset
		}
	]],
}

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

local function PackTableIntoString(tbl, str0)
	local str = str0 or ""
	for k, v in pairs(tbl) do
		str = string.format("%s|%s=%s|", str, tostring(k), tostring(v))
	end
	return str
end

local function FillMaterials(unitMaterials, materials, matTemplate, matParentName, udID)
	local udef = UnitDefs[udID]
	local udefCM = udef.customParams
	local lm = tonumber(udefCM.lumamult) or 1
	local scvd = tonumber(udefCM.scavvertdisp) or 0

	local params = {
		lm = lm,
		scvd = scvd,
	}

	local matName = PackTableIntoString(params, matParentName)

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
		TEX1 = GG.GetScavTexture(udID, 0) or string.format("%%%%%d:0", udID),
		TEX2 = GG.GetScavTexture(udID, 1) or string.format("%%%%%d:1", udID),
		NORMALTEX = udefCM.normaltex
	}
end


return {
	scavDisplacementPlugin = scavDisplacementPlugin,
	treeDisplacementPlugun = treeDisplacementPlugun,
	SunChanged = SunChanged,
	FillMaterials = FillMaterials,
}