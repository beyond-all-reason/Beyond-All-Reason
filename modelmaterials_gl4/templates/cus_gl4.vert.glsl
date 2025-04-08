//shader version is added via widget

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
#if (SKINSUPPORT == 0)
	layout (location = 5) in uint pieceIndex;
#else
	layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
	#define pieceIndex (bonesInfo.x & 0x000000FFu)
#endif
#ifndef STATICMODEL
	layout (location = 6) in uvec4 instData;
#else
	layout (location = 6) in vec4 offsetpos_targetpiece;
	layout (location = 7) in vec4 offsetrot;
	layout (location = 8) in uvec4 instData;
#endif

// u32 matOffset
// u32 uniOffset
// u32 {teamIdx, drawFlag, unused, unused}
// u32 unused


layout(std140, binding = 0) readonly buffer MatrixBuffer {
	mat4 mat[];
};

struct SUniformsBuffer {
	uint composite; //     u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

// Unit Uniforms:
#define UNITUNIFORMS uni[instData.y]
#define UNITID (uni[instData.y].composite >> 16)
#define TREADOFFSET uni[instData.y].speed.w

%%GLOBAL_NAMESPACE%%

%%VERTEX_GLOBAL_NAMESPACE%%

/***********************************************************************/
#line 10010

/***********************************************************************/
// Options in use
#define OPTION_SHADOWMAPPING 0
#define OPTION_NORMALMAPPING 1
#define OPTION_SHIFT_RGBHSV 2
#define OPTION_VERTEX_AO 3
#define OPTION_FLASHLIGHTS 4

#define OPTION_TREADS_ARM 5
#define OPTION_TREADS_CORE 6

#define OPTION_HEALTH_TEXTURING 7
#define OPTION_HEALTH_DISPLACE 8
#define OPTION_HEALTH_TEXRAPTORS 9

#define OPTION_MODELSFOG 10

#define OPTION_TREEWIND 11

#define OPTION_TREADS_LEG 13

%%GLOBAL_OPTIONS%%

/***********************************************************************/
// Definitions
#define BITMASK_FIELD(value, pos) ((uint(value) & (1u << uint(pos))) != 0u)

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)


uniform int drawPass = 1;
//BITS:
//1: deferred/forward,
//2: opaque/alpha
//3: reflection
//4: refraction
//5: shadows

/***********************************************************************/
vec3 cameraPos	 = cameraViewInv[3].xyz;
vec3 cameraDir = -1.0 * vec3(cameraView[0].z,cameraView[1].z,cameraView[2].z);


//[0]-healthMix, 0.0 for full health, ~0.8 for max damage
//[1]-healthMod, customparams.healthlookmod, 0.4 for scavengers
//[2]-vertDisplacement, for scavs, its min(10.0, 5.5 + (footprintx+footprintz) /12 )
//[3]-tracks speed = floor(4 * speed + 0.5) / 4
uniform float baseVertexDisplacement = 0.0; // this is for the scavengers,
const float vertexDisplacement = 6.0; // Strength of vertex displacement on health change
const float treadsvelocity = 0.5;
#line 10200

uniform int bitOptions;
//int bitOptions = 1 +  2 + 8 + 16 + 128 + 256 + 512;

//uniform vec4 clipPlane2 = vec4(0.0, 0.0, 0.0, 1.0); //water clip plane
//uniform vec4 clipPlane0 = vec4(0.0, 0.0, 0.0, 1.0); //upper construction clip plane
//uniform vec4 clipPlane1 = vec4(0.0, 0.0, 0.0, 1.0); //lower construction clip plane
uniform vec4 clipPlane0 = vec4(0.0, 0.0, 0.0, 1.0); //water clip plane


/***********************************************************************/
// Varyings
out Data {
	// this amount of varyings is already more than we can handle safely
	//vec4 modelVertexPos;
	vec4 modelVertexPosOrig; // .w contains model maxY
	vec4 worldVertexPos; //.w contains cloakTime
	// TBN matrix components
	vec3 worldTangent;
	vec3 worldBitangent;
	vec3 worldNormal;

	vec2 uvCoords;
	flat vec4 teamCol; // .a contains selectedness

	// main light vector(s)
	vec3 worldCameraDir;

	// shadowPosition
	vec4 shadowVertexPos;

	//vec3 debugvarying; // for passing through debug garbage
	// auxilary varyings
	float aoTerm;
	float fogFactor;
	flat float selfIllumMod;
	flat float healthFraction;
	flat int unitID;
	flat vec4 userDefined2;

};


/***********************************************************************/
// Misc functions

float simFrame = (timeInfo.x + timeInfo.w);

float Perlin3D( vec3 P ) {
	//return 0.5;
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
// Auxilary functions

vec2 GetWind(float period) {
	vec2 wind;
	wind = sin( vec2 (0, 1.56) + period * 5.0);
	//wind.x = sin(period * 5.0);
	//wind.y = cos(period * 5.0);
	return wind * 10.0f;
}

void DoWindVertexMove(inout vec4 mVP) {
	float simFrameFloor = floor(simFrame *  0.001333);
	float simFrameFract = fract(simFrame *  0.001333);
	vec2 curWind = GetWind(simFrameFloor);
	vec2 nextWind = GetWind(simFrameFloor + 1.0);
	float tweenFactor = smoothstep(0.0f, 1.0f, simFrameFract);
	vec2 wind = mix(curWind, nextWind, tweenFactor);

	#if 0
		// fractional part of model position, clamped to >.4
		vec3 modelXYZ = gl_ModelViewMatrix[3].xyz;
	#else
		vec3 modelXYZ = 16.0 * hash31(float(unitID));
	#endif
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
	//mVP.y += float(UNITID/256);// + sin(simFrame *0.1)+15; // whoops this was meant as debug
}

#ifdef USESKINNING
	uint GetUnpackedValue(uint packedValue, uint byteNum) {
		return (packedValue >> (8u * byteNum)) & 0xFFu;
	}
	// See: https://github.com/beyond-all-reason/spring/blob/d37412acca1ae14a602d0cf46243d0aedd132701/cont/base/springcontent/shaders/GLSL/ModelVertProgGL4.glsl#L135C1-L191C2

	// The only difference is that displacedPos is passed in, and we always assume staticModel = false
	void GetModelSpaceVertex(in vec3 displacedPos, out vec4 msPosition, out vec3 msNormal)
	{
		#ifndef STATICMODEL
			bool staticModel = false;// (matrixMode > 0);
		#else
			bool staticModel = true;// (matrixMode > 0);
		#endif

		vec4 piecePos = vec4(displacedPos, 1.0);

		vec4 weights = vec4(
			float(GetUnpackedValue(bonesInfo.y, 0)) / 255.0,
			float(GetUnpackedValue(bonesInfo.y, 1)) / 255.0,
			float(GetUnpackedValue(bonesInfo.y, 2)) / 255.0,
			float(GetUnpackedValue(bonesInfo.y, 3)) / 255.0
		);

		uint b0 = GetUnpackedValue(bonesInfo.x, 0); //first boneID
		mat4 b0BoneMat = mat[instData.x + b0 + uint(!staticModel)];
		mat3 b0NormMat = mat3(b0BoneMat);

		weights[0] *= b0BoneMat[3][3];

		msPosition = b0BoneMat * piecePos;
		msNormal   = b0NormMat * normal;

		if (staticModel || weights[0] == 1.0)
			return;

		float wSum = 0.0;

		msPosition *= weights[0];
		msNormal   *= weights[0];
		wSum       += weights[0];

		uint numPieces = GetUnpackedValue(instData.z, 3);
		mat4 bposeMat    = mat[instData.w + b0];

		// Vertex[ModelSpace,BoneX] = PieceMat[BoneX] * InverseBindPosMat[BoneX] * BindPosMat[Bone0] * Vertex[Bone0]
		for (uint bi = 1; bi < 3; ++bi) {
			uint bID = GetUnpackedValue(bonesInfo.x, bi);

			if (bID == 0xFFu || weights[bi] == 0.0)
				continue;

			mat4 bposeInvMat = mat[instData.w + numPieces + bID];
			mat4 boneMat     = mat[instData.x +        1u + bID];

			weights[bi] *= boneMat[3][3];

			mat4 skinMat = boneMat * bposeInvMat * bposeMat;
			mat3 normMat = mat3(skinMat);

			msPosition += skinMat * piecePos * weights[bi];
			msNormal   += normMat * normal   * weights[bi];
			wSum       += weights[bi];
		}

		msPosition /= wSum;
		msNormal   /= wSum;
	}
#endif

mat4 rotationMatrix(vec3 rot) {
	float c1 = cos(rot.x);
	float s1 = sin(rot.x);
	float c2 = cos(rot.y);
	float s2 = sin(rot.y);
	float c3 = cos(rot.z);
	float s3 = sin(rot.z);

	// Rotation matrices for each axis
	mat4 rx = mat4(1.0, 0.0, 0.0, 0.0,
				   0.0, c1, -s1, 0.0,
				   0.0, s1, c1, 0.0,
				   0.0, 0.0, 0.0, 1.0);

	mat4 ry = mat4(c2, 0.0, s2, 0.0,
				   0.0, 1.0, 0.0, 0.0,
				   -s2, 0.0, c2, 0.0,
				   0.0, 0.0, 0.0, 1.0);

	mat4 rz = mat4(c3, -s3, 0.0, 0.0,
				   s3, c3, 0.0, 0.0,
				   0.0, 0.0, 1.0, 0.0,
				   0.0, 0.0, 0.0, 1.0);

	// Combined rotation matrix, order is important
	return rz * ry * rx;
}


/***********************************************************************/
// Vertex shader main()

#define GetPieceMatrix(staticModel) (mat[instData.x + pieceIndex + uint(!staticModel)])
#line 12000
void main(void)
{
	unitID = int(UNITID);
	userDefined2 = UNITUNIFORMS.userDefined[2];
	userDefined2.w = UNITUNIFORMS.userDefined[0].x; // pass in construction progress 0-1
	#ifndef STATICMODEL
		// pieceMatrix looks up the model-space transform matrix for unit being drawn
		mat4 pieceMatrix = mat[instData.x + pieceIndex + 1u];

		// Then it places it in the world
		mat4 worldMatrix = mat[instData.x];
	#else
		// First lets orient the

		// pieceMatrix looks up the model-space transform matrix for the unit we are drawing onto!
		uint targetPieceIndex = uint(offsetpos_targetpiece.w);
		mat4 pieceMatrix = mat[instData.x + targetPieceIndex + 1u];

		// Then it places it in the world
		mat4 worldMatrix = mat[instData.x];

	#endif


	mat4 worldPieceMatrix = worldMatrix * pieceMatrix; // for the below
	mat3 normalMatrix = mat3(worldPieceMatrix);


	vec4 piecePos = vec4(pos, 1.0);

	uvCoords = uv.xy;
	healthFraction = clamp(UNITUNIFORMS.health / UNITUNIFORMS.maxHealth, 0.0, 1.0);
	
	// Also mix in buildprogress into health fraction:
	#if ENABLE_OPTION_HEALTH_TEXTURING
		float buildProgress = UNITUNIFORMS.userDefined[0].x;
		if (buildProgress > -0.5){
			// healthFraction, cannot, in theory be more than buildProgress
			healthFraction = clamp(healthFraction / max(0.00000001,buildProgress), 0.0, 1.0);
		}
	#endif

	//modelVertexPos = piecePos;

	#ifdef TREE_RANDOMIZATION
		float randomScale = fract(float(unitID)*0.01)*0.2 + 0.9;
		piecePos.xyz *= randomScale;
	#endif


	#if (XMAS == 1)
	//	piecePos.xyz +=  piecePos.xyz * 10.0 * UNITUNIFORMS.userDefined[2].y; // number 9
	#endif

	modelVertexPosOrig = piecePos;
	vec3 modelVertexNormal = normal;

	%%VERTEX_PRE_TRANSFORM%%

	if (BITMASK_FIELD(bitOptions, OPTION_TREEWIND)) {
		DoWindVertexMove(piecePos);
	}

	#ifdef ENABLE_OPTION_HEALTH_DISPLACE
	if (BITMASK_FIELD(bitOptions, OPTION_HEALTH_DISPLACE)) {
		if (healthFraction < 0.95 || baseVertexDisplacement > 0.01){
			vec3 seedVec = 0.1 * piecePos.xyz;
			seedVec.y += 1024.0 * hash11(float(unitID));
			float damageAmount = (1.0 - healthFraction) * 0.8;
			piecePos.xyz +=
				max(damageAmount , baseVertexDisplacement) *
				vertexDisplacement *							//vertex displacement value
				Perlin3D(seedVec) * normalize(piecePos.xyz);

		}
	}
	#endif

	#ifdef USESKINNING
		// What in the lords name do we have to do here?
		vec4 modelPos; // model-space positision
		GetModelSpaceVertex(piecePos.xyz, modelPos, modelVertexNormal);
		vec4 worldPos = worldMatrix * modelPos;
	#else
		vec4 modelPos = pieceMatrix * piecePos;
		vec4 worldPos = worldPieceMatrix * piecePos;
	#endif
	//worldPos.x += 64; // for dem debuggins
	modelVertexPosOrig.w = modelPos.y / (max(1.0, UNITUNIFORMS.userDefined[2].w)); //11 is unit height

	//gl_TexCoord[0] = gl_MultiTexCoord0;
	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	teamCol = teamColor[teamIndex];

	// Pack selectedness into teamCol.a
	teamCol.a = UNITUNIFORMS.userDefined[1].z;

	#if (RENDERING_MODE != 2) //non-shadow pass

		%%VERTEX_UV_TRANSFORM%%

		#ifdef ENABLE_OPTION_TREADS
		if (BITMASK_FIELD(bitOptions, OPTION_TREADS_ARM) || BITMASK_FIELD(bitOptions, OPTION_TREADS_CORE) || BITMASK_FIELD(bitOptions, OPTION_TREADS_LEG)) {
			#define ATLAS_SIZE 4096.0
			#define PX_TO_UV(x) (float(x) / ATLAS_SIZE)
			#define IN_PIXEL_RECT(uv, left, top, width, height) (all(bvec4(	uv.x >= PX_TO_UV(left),         uv.y <= 1.f - PX_TO_UV(top),  uv.x <= PX_TO_UV(left + width), uv.y >= 1.f - PX_TO_UV(top + height) 	)))

			// apply a minimum amount of "speed" when not completely stopped
			// so that tracks appear to "spin up/down as they dig into the ground"
			// instead of jittering strangely at low speed
			float unitSpeed = uni[instData.y].speed.w;

			if (unitSpeed > 0.5) {
				unitSpeed = max(3, unitSpeed);
			}

			// unitSpeed gets multiplied by [0, 1, 2, 3, ..., loop end)
			// keep this low or else track animation will vary too much based on abritary frame count
			// applies a sort of "jitter" effect to the track UVs based on unit speed

			// it is a very poor estimation of "distance traveled"
			// but...
			// as long as the end result looks like the tracks are moving it is good enough for now

			float loopingFrameCount = mod(simFrame, 8.0); // Greatest Common Factor (12, 20, 56, ...) = 4
			float baseOffset = loopingFrameCount * unitSpeed;

			// ################# ARMADA ##################
			if (BITMASK_FIELD(bitOptions, OPTION_TREADS_ARM)) {
				const float texSpeedMult = 4.0;
				if (IN_PIXEL_RECT(uvCoords, 2573, 1548, 498, 82)) {
					// Arm small (top) width 12px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult, 12.0));
				} else if (IN_PIXEL_RECT(uvCoords, 2572, 1631, 500, 132)) {
					// Arm big (bot) width 20px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult, 20.0));
				}
			}

			// ################# CORTEX ##################
			if (BITMASK_FIELD(bitOptions, OPTION_TREADS_CORE)) {
				const float texSpeedMult = -6.0;
				const float texSpeedMult2 = 3.0;

				if (IN_PIXEL_RECT(uvCoords, 3042, 3839, (ATLAS_SIZE - 3042), (ATLAS_SIZE - 3839))) {
					// tracks are right up against the bottom right of the texture
					// Cor big (right bot) width 56px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult, 56.0));
				} else if (IN_PIXEL_RECT(uvCoords, 192, 636, 511, 68)) {
					// Cor small (top) width 24px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult2, 24.0));
				} else if (IN_PIXEL_RECT(uvCoords, 189, 705, 506, 94)) {
					// Cor small (bot) width 28px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult2, 28.0));
				}
			}

			// ################# LEGION ##################
			if (BITMASK_FIELD(bitOptions, OPTION_TREADS_LEG)) {
				const float texSpeedMult = -6.0;

				if (IN_PIXEL_RECT(uvCoords, 2613, 768, 660, 404)) {
					// Legion Rubber and Steel tracks (top right) width 55px
					uvCoords.x += PX_TO_UV(mod(baseOffset * texSpeedMult, 55.0));
				}
			}

			#undef ATLAS_SIZE
			#undef IN_PIXEL_RECT
			#undef PIXELS_TO_UV
		}
		#endif

		worldVertexPos = worldPos;
		/***********************************************************************/
		// Main vectors for lighting
		// V
		worldCameraDir = normalize(cameraPos - worldVertexPos.xyz); //from fragment to camera, world space

		//if (BITMASK_FIELD(bitOptions, OPTION_SHADOWMAPPING)) {
			shadowVertexPos = shadowView * worldPos;
			//shadowVertexPos.xyz = shadowVertexPos.xyz / shadowVertexPos.w
			shadowVertexPos.xy += vec2(0.5);  //no need for shadowParams anymore
			//shadowVertexPos = shadowProj * shadowVertexPos;
		//}

		// Calculate Normals:
		//no need to do Gram-Schmidt re-orthogonalization, because engine does it for us anyway
		vec3 safeT = T; // already defined REM
		vec3 safeB = B; // already defined REM
		if (dot(safeT, safeT) < 0.1 || dot(safeB, safeB) < 0.1) {
			safeT = vec3(1.0, 0.0, 0.0);
			safeB = vec3(0.0, 0.0, 1.0);
		}
		// tangent --> world space transformation (for vectors)
		worldTangent = normalMatrix * safeT;
		worldBitangent = normalMatrix * safeB;
		worldNormal = normalMatrix * modelVertexNormal;

		if (BITMASK_FIELD(bitOptions, OPTION_VERTEX_AO)) {
			//aoTerm = clamp(1.0 * fract(uv.x * 16384.0), shadowDensity.y, 1.0);
			aoTerm = clamp(1.0 * fract(uv.x * 16384.0), 0.1, 1.0);
		} else {
			aoTerm = 1.0;
		}

		if (BITMASK_FIELD(bitOptions, OPTION_FLASHLIGHTS)) {
			// modelMatrix[3][0] + modelMatrix[3][2] are Tx, Tz elements of translation of matrix
			selfIllumMod = max(-0.2, sin(simFrame * 2.0/30.0 + float(UNITID) * 0.1)) + 0.2;
		} else {
			selfIllumMod = 1.0;
		}

		//gl_Position = projectionMatrix * viewMatrix * worldVertexPos; // OOOOLD

		if (BITMASK_FIELD(bitOptions, OPTION_MODELSFOG)) {
			vec4 ClipVertex = cameraView * worldVertexPos;
			// emulate linear fog
			float fogCoord = length(ClipVertex.xyz);
			fogFactor = (fogParams.y - fogCoord) * fogParams.w; // gl_Fog.scale == 1.0 / (gl_Fog.end - gl_Fog.start)
			fogFactor = clamp(fogFactor, 0.0, 1.0);
		}

		// are we drawing reflection pass, if yes, use reflection camera!
		if ((uint(drawPass) & 4u ) == 4u){
			gl_Position = reflectionViewProj * worldPos;
			// Dot world position against vec4(0,0,1,0), which will result in negative for underwater, discarding it
			gl_ClipDistance[0] = dot(worldPos, clipPlane0);
		}
		else{
			gl_Position = cameraViewProj * worldPos;
			//gl_ClipDistance[0] = dot(worldPos, vec4(0.0, -1.0, 0.0, -1.0));
		}
		%%VERTEX_POST_TRANSFORM%%
	
	worldVertexPos.w = UNITUNIFORMS.userDefined[3].x; // cloakTime
	#elif (RENDERING_MODE == 2) //shadow pass

		vec4 lightVertexPos = shadowView * worldPos;
		vec3 lightVertexNormal = normal;

		float NdotL = clamp(dot(lightVertexNormal, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);

		//use old bias formula from GetShadowPCFRandom(), but this time to write down shadow depth map values
		const float cb = 5e-5;
		float bias = cb * tan(acos(NdotL));
		bias = clamp(bias, 0.0, 5.0 * cb);

		lightVertexPos.xy += vec2(0.5);
		lightVertexPos.z += bias;

		gl_Position = shadowProj * lightVertexPos; //TODO figure out gl_ProjectionMatrix replacement ?
	#endif
}
