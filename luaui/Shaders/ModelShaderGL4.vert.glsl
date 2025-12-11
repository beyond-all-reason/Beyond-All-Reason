layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
layout (location = 5) in uint pieceIndex;

layout (location = 6) in uvec4 instData;
// u32 matOffset
// u32 uniOffset
// u32 {teamIdx, drawFlag, unused, unused}
// u32 unused

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardView;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;

	mat4 shadowView;
	mat4 shadowProj;
	mat4 shadowViewProj;

	mat4 reflectionView;
	mat4 reflectionProj;
	mat4 reflectionViewProj;

	mat4 orthoProj01;

	// transforms for [0] := Draw, [1] := DrawInMiniMap, [2] := Lua DrawInMiniMap
	mat4 mmDrawView; //world to MM
	mat4 mmDrawProj; //world to MM
	mat4 mmDrawViewProj; //world to MM

	mat4 mmDrawIMMView; //heightmap to MM
	mat4 mmDrawIMMProj; //heightmap to MM
	mat4 mmDrawIMMViewProj; //heightmap to MM

	mat4 mmDrawDimView; //mm dims
	mat4 mmDrawDimProj; //mm dims
	mat4 mmDrawDimViewProj; //mm dims
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo;     //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize;      //xz, xzPO2
	vec4 mapHeight;    //height minCur, maxCur, minInit, maxInit

	vec4 fogColor;  //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}

	vec4 sunDir;

	vec4 sunAmbientModel;
	vec4 sunAmbientMap;
	vec4 sunDiffuseModel;
	vec4 sunDiffuseMap;
	vec4 sunSpecularModel;
	vec4 sunSpecularMap;

	vec4 shadowDensity; // {ground, units, 0.0, 0.0}

	vec4 windInfo; // windx, windy, windz, windStrength
	vec2 mouseScreenPos; //x, y. Screen space.
	uint mouseStatus; // bits 0th to 32th: LMB, MMB, RMB, offscreen, mmbScroll, locked
	uint mouseUnused;
	vec4 mouseWorldPos; //x,y,z; w=0 -- offmap. Ignores water, doesn't ignore units/features under the mouse cursor

	vec4 teamColor[255]; //all team colors
};

layout(std140, binding = 0) readonly buffer MatrixBuffer {
	mat4 mat[];
};

uniform int drawMode = 0;
uniform mat4 staticModelMatrix = mat4(1.0);

uniform vec4 clipPlane0 = vec4(0.0, 0.0, 0.0, 1.0); //upper construction clip plane
uniform vec4 clipPlane1 = vec4(0.0, 0.0, 0.0, 1.0); //lower construction clip plane
uniform vec4 clipPlane2 = vec4(0.0, 0.0, 0.0, 1.0); //water clip plane

uniform float teamColorAlpha = 1.0;

uniform float intOptions = 0.0;

out Data {
	vec4 uvCoord;
	vec4 teamCol;

	vec4 worldPos;
	vec3 worldNormal;
	
	vec4 modelVertexPos;
	vec4 pieceVertexPosOrig;
	vec4 worldVertexPos;
	// TBN matrix components
	vec3 worldTangent;
	vec3 worldBitangent;
	// main light vector(s)
	vec3 worldCameraDir;

	// shadowPosition
	vec4 shadowVertexPos;

	// auxilary varyings
	float aoTerm;
	float selfIllumMod;
	float fogFactor;
};
//out float gl_ClipDistance[3];

#line 11000
float simFrame = (timeInfo.x + timeInfo.w);
/***********************************************************************/
	// Misc functions

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

	float hash11(float p) {
		const float HASHSCALE1 = 0.1031;
		vec3 p3  = fract(vec3(p) * HASHSCALE1);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.x + p3.y) * p3.z);
	}

	vec3 hash31(float p) {
		const vec3 HASHSCALE3 = vec3(0.1031, 0.1030, 0.0973);
		vec3 p3 = fract(vec3(p) * HASHSCALE3);
		p3 += dot(p3, p3.yzx + 19.19);
		return fract((p3.xxy + p3.yzz) * p3.zyx);
	}

	/***********************************************************************/

#line 120000

/***********************************************************************/
	// Auxilary functions

	vec2 GetWind(float period) {
		vec2 wind;
		wind.x = sin(period * 5.0);
		wind.y = cos(period * 5.0);
		return wind * 10.0f;
	}

	void DoWindVertexMove(inout vec4 mVP) {
		vec2 curWind = GetWind(simFrame * 0.001333);
		vec2 nextWind = GetWind(simFrame * 0.001333 + 1.0);
		float tweenFactor = smoothstep(0.0f, 1.0f, max(mod(simFrame, 750.0) - 600, 0) / 150.0f);
		vec2 wind = mix(curWind, nextWind, tweenFactor);

		vec3 modelXYZ = 16.0 * hash31(intOptions);
		
		modelXYZ = fract(modelXYZ);
		modelXYZ = clamp(modelXYZ, 0.4, 1.0);

		// crude measure of wind intensity
		float abswind = abs(wind.x) + abs(wind.y);

		vec4 cosVec;
		float simTime = 0.02 * simFrame;
		// these determine the speed of the wind"s "cosine" waves.
		cosVec.w = 0.0;
		cosVec.x = simTime * modelXYZ.x + mVP.x;
		cosVec.y = simTime * modelXYZ.z / 3.0 + modelXYZ.x;
		cosVec.z = simTime * 1.0 + mVP.z;

		// calculate "cosines" in parallel, using a smoothed triangle wave
		vec4 tri = abs(fract(cosVec + 0.5) * 2.0 - 1.0);
		cosVec = tri * tri *(3.0 - 2.0 * tri);

		float limit = clamp((mVP.x * mVP.z * mVP.y) / 3000.0, 0.0, 0.2);

		float diff = cosVec.x * limit;
		float diff2 = cosVec.y * clamp(mVP.y / 30.0, 0.05, 0.2);

		mVP.xyz += cosVec.z * limit * clamp(abswind, 1.2, 1.7);

		mVP.xz += diff + diff2 * wind;
	}


	/***********************************************************************/

void TransformPlayerCam(vec4 worldPos) {
	gl_Position = cameraViewProj * worldPos;
}

void TransformPlayerReflCam(vec4 worldPos) {
	gl_Position = reflectionViewProj * worldPos;
}

void TransformPlayerCamStaticMat(vec4 worldPos) {
	gl_Position = cameraViewProj * worldPos;
}

#define GetPieceMatrix(staticModel) (mat[instData.x + pieceIndex + uint(!staticModel)])

void main(void)
{
	
	mat4 pieceMatrix = GetPieceMatrix(bool(drawMode < 0));
	mat4 worldMatrix = (drawMode >= 0) ? mat[instData.x] : staticModelMatrix;

	mat4 worldPieceMatrix = worldMatrix * pieceMatrix; // for the below

	mat3 normalMatrix = mat3(worldPieceMatrix);



	vec4 piecePos = vec4(pos, 1.0);
	vec4 modelPos = pieceMatrix * piecePos;
	vec4 worldPos = worldPieceMatrix * piecePos;
	worldPos.x += 32;

	worldNormal = normalMatrix * normal;

	gl_ClipDistance[0] = dot(modelPos, clipPlane0); //upper construction clip plane
	gl_ClipDistance[1] = dot(modelPos, clipPlane1); //lower construction clip plane
	gl_ClipDistance[2] = dot(worldPos, clipPlane2); //water clip plane

	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	teamCol = teamColor[teamIndex];
	teamCol.a = teamColorAlpha;

	uvCoord = uv;

	shadowVertexPos = shadowView * worldPos;
	shadowVertexPos.xy += vec2(0.5);  //no need for shadowParams anymore

	vec4 cameraPos = cameraViewInv * vec4(0, 0, 0, 1);
	worldCameraDir = cameraPos.xyz - worldPos.xyz; //from fragment to camera, world space, not normalized(!)

	#if (DEFERRED_MODE == 0)
		float fogDist = length(worldCameraDir);
		fogFactor = (fogParams.y - fogDist) * fogParams.w;
		fogFactor = clamp(fogFactor, 0.0, 1.0);
	#endif

	#if (OPTION_VERTEX_AO == 0) 
		aoTerm = 1.0;
	#else
		aoTerm = clamp(1.0 * fract(gl_TexCoord[0].x * 16384.0), 0.1, 1.0);
	#endif
	
	#if (OPTION_FLASHLIGHTS == 0)
		selfIllumMod = 1.0;
	#else
		selfIllumMod = max(-0.2, sin(simFrame * 2.0/30.0 + (worldMatrix[3][0] + worldMatrix[3][2]) * 0.1)) + 0.2;
	#endif

	// TODO fogFactor
	fogFactor = 1.0;

	switch(drawMode) {
		case  1: // water reflection
			TransformPlayerReflCam(worldPos);
			//TransformPlayerCam(worldPos);
			break;
		case  2: // water refraction
			TransformPlayerCam(worldPos);
			break;
		default: // player, (-1) static model, (0) normal rendering
			TransformPlayerCam(worldPos);
			break;
	};
}