
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), released under the MIT license
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition; // x,y in range [-1,1], progress in range [0,1]
layout (location = 1) in vec4 posscale; // abs pos for static units, offset for dynamic units, scale is actual range, Y is turretheight
layout (location = 2) in vec4 color1; // Base color for the circle
layout (location = 3) in vec4 visibility; // FadeStart, FadeEnd, StartAlpha, EndAlpha
layout (location = 4) in vec4 projectileParams; // projectileSpeed, iscylinder, heightBoostFactor , heightMod
layout (location = 5) in vec4 additionalParams; // groupselectionfadescale, weaponType, ISDGUN, MAXANGLEDIF
layout (location = 6) in uvec4 instData;

uniform float lineAlphaUniform = 1.0;
uniform float cannonmode = 0.0;
uniform float fadeDistOffset = 0.0;
uniform float inMiniMap = 0.0;


uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;
uniform float staticUnits = 0.0; // 1 if static units, 0 if dynamic units

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?
uniform sampler2D mapNormalTex; // hmm maybe?

// Ease-of-use defines for the vertex shader outputs
#define V_CIRCLEPROGRESS v_params.x
#define V_GROUPSELECTIONFADESCALE v_params.y
#define V_WEAPONTYPE v_params.z

out DataVS {
	flat vec4 v_blendedcolor;	
	#if (DEBUG == 1)
		vec4 v_debug;
	#endif
};

//__ENGINEUNIFORMBUFFERDEFS__


struct SUniformsBuffer {
	uint composite; //     u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 drawPos; // Note that this is map height at unit.xz
	vec4 speed;
	vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#define UNITUNIFORMS uni[instData.y]
#define UNITID (uni[instData.y].composite >> 16)


#line 11000

vec2 inverseMapSize = 1.0 / mapSize.xy;

float heightAtWorldPos(vec2 w){
	// Some texel magic to make the heightmap tex perfectly align:
	const vec2 heightmaptexel = vec2(8.0, 8.0);
	w +=  vec2(-8.0, -8.0) * (w * inverseMapSize) + vec2(4.0, 4.0) ;

	vec2 uvhm = clamp(w, heightmaptexel, mapSize.xy - heightmaptexel);
	uvhm = uvhm	* inverseMapSize;

	return textureLod(heightmapTex, uvhm, 0.0).x;
}

vec4 normalsAndHeightAtWorldPos(vec2 w){
	// Some texel magic to make the heightmap tex perfectly align:
	// Some texel magic to make the heightmap tex perfectly align:
	const vec2 heightmaptexel = vec2(8.0, 8.0);
	w +=  vec2(-8.0, -8.0) * (w * inverseMapSize) + vec2(4.0, 4.0) ;

	vec2 uvhm = clamp(w, heightmaptexel, mapSize.xy - heightmaptexel);
	uvhm = uvhm	* inverseMapSize;
	vec4 heightAndNormal = vec4(0.0);
	heightAndNormal.w = textureLod(mapNormalTex, uvhm, 0.0).x;
	heightAndNormal.xz = textureLod(mapNormalTex, uvhm, 0.1).ra;
	heightAndNormal.y = 1.0 - sqrt(1.0 - dot(heightAndNormal.xz, heightAndNormal.xz));
	return heightAndNormal;
}

float GetRangeFactor(float projectileSpeed) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
	// on first run, with yDiff = 0, what do we get?
	float speed2d = projectileSpeed * 0.707106;
	float gravity =  120.0 	* (0.001111111);
	return ((speed2d * speed2d) * 2.0 ) / (gravity);
}

float GetRange2DCannon(float yDiff,float projectileSpeed,float rangeFactor,float heightBoostFactor) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
	// on first run, with yDiff = 0, what do we get?

	//float factor = 0.707106;
	float smoothHeight = 100.0;
	float speed2d = projectileSpeed*0.707106;
	float speed2dSq = speed2d * speed2d;
	float gravity = -1.0*  (120.0 /900);

	if (heightBoostFactor < 0){
		heightBoostFactor = (2.0 - rangeFactor) / sqrt(rangeFactor);
	}

	if (yDiff < -100.0){
		yDiff = yDiff * heightBoostFactor;
	}else {
		if (yDiff < 0.0) {
			yDiff = yDiff * (1.0 + (heightBoostFactor - 1.0 ) * (-1.0 * yDiff) * 0.01);
		}
	}

	float root1 = speed2dSq + 2 * gravity *yDiff;
	if (root1 < 0.0 ){
		return 0.0;
	}else{
		return rangeFactor * ( speed2dSq + speed2d * sqrt( root1 ) ) / (-1.0 * gravity);
	}
}

vec2 rotate2D(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

//float heightMod  default: 0.2 (0.8 for #Cannon, 1.0 for #BeamLaser and #LightningCannon)
//Changes the spherical weapon range into an ellipsoid. Values above 1.0 mean the weapon cannot target as high as it can far, values below 1.0 mean it can target higher than it can far. For example 0.5 would allow the weapon to target twice as high as far.

//float heightBoostFactor default: -1.0
//Controls the boost given to range by high terrain. Values > 1.0 result in increased range, 0.0 means the cannon has fixed range regardless of height difference to target. Any value < 0.0 (i.e. the default value) result in an automatically calculated value based on range and theoretical maximum range.

// Ease of use defines for the vertex shader inputs:
#define RANGE 					posscale.w
#define TURRETHEIGHT			posscale.y

#define PROJECTILESPEED 		projectileParams.x
#define ISCYLINDER 				projectileParams.y
#define HEIGHTBOOSTFACTOR 		projectileParams.z
#define HEIGHTMOD 				projectileParams.w

#define GROUPSELECTIONFADESCALE	additionalParams.x
#define WEAPONTYPE				additionalParams.y
#define ISDGUN 					additionalParams.z
#define MAXANGLEDIF 			additionalParams.w

#define FADESTART				visibility.x
#define FADEEND					visibility.y
#define STARTALPHA				visibility.z
#define ENDALPHA				visibility.w

#define UNUSEDALPHA				alphaControl.x
#define OUTOFBOUNDSALPHA		alphaControl.y
#define FADEALPHA				alphaControl.z
#define MOUSEALPHA				alphaControl.w

#define SELECTEDNESS uni[instData.y].userDefined[1].z

#ifndef HEIGHTMAP_SAMPLE_STEPS
	#define HEIGHTMAP_SAMPLE_STEPS 16
#endif

bool isSphereVisible(vec3 position, float radius)
{
    vec4 planes[6];
    mat4 m = cameraViewProj;

    // Extract the frustum planes from the combined view-projection matrix
    planes[0] = m[3] + m[0]; // Left plane
    planes[1] = m[3] - m[0]; // Right plane
    planes[2] = m[3] + m[1]; // Bottom plane
    planes[3] = m[3] - m[1]; // Top plane
    planes[4] = m[3] + m[2]; // Near plane
    planes[5] = m[3] - m[2]; // Far plane

    // Normalize the plane equations
    for(int i = 0; i < 6; i++)
    {
        float length = length(planes[i].xyz);
        planes[i] /= length;
    }

    // Check if the sphere is outside any of the frustum planes
    for(int i = 0; i < 6; i++)
    {
        float distance = dot(planes[i].xyz, position) + planes[i].w;
        if(distance < -radius)
            return false; // Sphere is completely outside this plane
    }

    return true; // Sphere is at least partially inside the frustum
}

void main() {
	vec4 circleWorldPos = vec4(1.0);
	vec3 modelWorldPos = vec3(0.0);		
	float maxAngleDif = 1;
	float mainDirDegrees = 0; 
	vec4 circleprogress = vec4(0.0);
	circleprogress.xy = circlepointposition.xy;
	if (staticUnits > 0.5) {
		// we need to add the aim pos of the turret coming in at posscale.y to the actual ground height.
		modelWorldPos = posscale.xyz;
		float modelposgroundheight = heightAtWorldPos(modelWorldPos.xz);
		modelWorldPos.y = modelposgroundheight + posscale.y;
		circleWorldPos.xz = circlepointposition.xy * RANGE +  modelWorldPos.xz;
	}else {
		// Get the center pos of the unit
		modelWorldPos = uni[instData.y].drawPos.xyz;

		// The turret is a bit higher up than drawPos.y (which is the ground pos)
		modelWorldPos.y += TURRETHEIGHT;

		// Get its heading
		float unitHeading = uni[instData.y].drawPos.w ;
		
		
		// find angle between unit Heading and circleprogress.xy
		//unitHeading is -pi to +pi, with zero on z+, and increasing towards x+
		//circleheading is -pi to +pi, with zero z-, and increasing towards x+ 
		
		// rotate the circle into unit space, wierd that it has to be rotated on other direction
		if (MAXANGLEDIF > 0.0) {
			maxAngleDif = fract(MAXANGLEDIF);// goes from 0.0 to 1.0, where 0.25 would mean a 90 deg cone
			mainDirDegrees = MAXANGLEDIF - maxAngleDif;// Is the offset in degrees. 
		}
		circleprogress.xy = rotate2D(circleprogress.xy, (3.141592 -1.0*unitHeading + mainDirDegrees * 3.141592 / 180.0));
		if (ISDGUN > 0.5) {
			// TODO move this to config instead of here
			circleWorldPos.xz = circleprogress.xy * RANGE * 1.05 + modelWorldPos.xz;
		} else {
			circleWorldPos.xz = circleprogress.xy * RANGE +  modelWorldPos.xz;
		}
	}



	circleprogress.w = circlepointposition.z;
	v_blendedcolor = color1;

	if (staticUnits > 0.5) {
		//gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0); return;
	}

	vec4 alphaControl = vec4(1.0);

	// get heightmap
	circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
	#if (DEBUG == 1)
		v_debug = vec4(modelWorldPos.xyzy);
	#endif
	
	if (cannonmode > 0.5){

		// BAR only has 3 distinct ballistic projectiles, heightBoostFactor is only a handful from -1 to 2.8 and 6 and 8
		// gravity we can assume to be linear

		float heightDiff = (circleWorldPos.y - modelWorldPos.y) * 0.5;

		float rangeFactor = RANGE /  GetRangeFactor(PROJECTILESPEED); //correct
		if (rangeFactor > 1.0 ) rangeFactor = 1.0;
		if (rangeFactor <= 0.0 ) rangeFactor = 1.0;
		float radius = RANGE;// - heightDiff;
		float adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
		float adjustment = radius * 0.5;
		float yDiff = 0;
		float adds = 0;
		//	for (int i = 0; i < mod(timeInfo.x/8,16); i ++){ //i am a debugging god
		for (int i = 0; i < HEIGHTMAP_SAMPLE_STEPS; i ++){
				if (adjRadius > radius){
					radius = radius + adjustment;
					adds = adds + 1;
				}else{
					radius = radius - adjustment;
					adds = adds - 1;
				}
				adjustment = adjustment * 0.5;
				circleWorldPos.xz = circleprogress.xy * radius + modelWorldPos.xz;
				float newY = heightAtWorldPos(circleWorldPos.xz );
				yDiff = abs(circleWorldPos.y - newY);
				circleWorldPos.y = max(0, newY);
				heightDiff = circleWorldPos.y - modelWorldPos.y;
				adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
		}
	}else{
		// IF ITS A SPHERE:
		if (ISCYLINDER < 0.5){ 
			//simple implementation, 4 samples per point
			//for (int i = 0; i<mod(timeInfo.x/4,30); i++){ // DEBuGGING
			//vec4 heightAndNormal = normalsAndHeightAtWorldPos(circleWorldPos.xz);
			float surfaceSphereClampHeight = 0.0;
			if (modelWorldPos.y > 0 ) surfaceSphereClampHeight = 0.0;
			else surfaceSphereClampHeight = modelWorldPos.y;

			for (int i = 0; i< HEIGHTMAP_SAMPLE_STEPS / 2; i++){
				// draw vector from centerpoint to new height point and normalize it to range length
				vec3 tonew = circleWorldPos.xyz - modelWorldPos.xyz;
				tonew.y *= HEIGHTMOD;

				tonew = normalize(tonew) * RANGE;
			
				circleWorldPos.xz = modelWorldPos.xz + tonew.xz;
				circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
				// if underwater model
				#if 1
					circleWorldPos.y = max(surfaceSphereClampHeight, circleWorldPos.y);
				#endif
			}
		}
	}
	

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	OUTOFBOUNDSALPHA = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);
	
	
	// -- Better drawing of underwater stuff
	if (modelWorldPos.y > -20) { // for submerged units, try to keep the ranges above the water for clarity
		modelWorldPos.y = max(1, modelWorldPos.y);
		circleWorldPos.y = max(1, circleWorldPos.y);
	}
	

	
	// -- HANDLE MAXANGLEDIFF
	// If the unit cant fire in that direction due to maxanglediff constraints, then put the point back to modelWorldPos
	// Also, dont 
	// convert current circleprogress to relative heading:
	float relheadingradians = abs(((circleprogress.w - 0.5)) * 2);
	if (MAXANGLEDIF != 0.0) {
		if(relheadingradians > maxAngleDif){
			circleWorldPos.xyz = modelWorldPos.xyz;
		}
		OUTOFBOUNDSALPHA = 1.0;
	}
	
	circleWorldPos.y += 4; // lift it from the ground


	//--- DISTANCE FADE ---
	vec4 camPos = cameraViewInv[3];

	// Note that this is not the same as the distance from the unit to the camera, but the distance from the circle to the camera
	float distToCam = length(modelWorldPos.xyz - camPos.xyz) ; //dist from cam
	// FadeStart, FadeEnd, StartAlpha, EndAlpha
	float fadeDist = FADEEND - FADESTART;
																							 
	// TODO VALIDATE
	if (ISDGUN > 0.5) {
		FADEALPHA  = clamp((FADEEND + fadeDistOffset + 1000 - distToCam)/(fadeDist), ENDALPHA, STARTALPHA);
	} else {
		FADEALPHA  = clamp((FADEEND + fadeDistOffset -        distToCam)/(fadeDist), ENDALPHA, STARTALPHA);
	}
		// -- IN-SHADER MOUSE-POS BASED HIGHLIGHTING
	float disttomousefromunit = 1.0 - smoothstep(48, 64, length(modelWorldPos.xz - mouseWorldPos.xz));
	// this will be positive if in mouse, negative else
	float highlightme = clamp( (disttomousefromunit ) + 0.0, 0.0, 1.0) * MOUSEOVERALPHAMULTIPLIER;
	// Note that this doesnt really work well with boundary-only stenciling, due to random draw order. 
	MOUSEALPHA = (0.1  + 0.5 * step(0.5,drawMode)) * highlightme;


	if (inMiniMap> 0.5){
		// No extra fade control when on the minimap
		FADEALPHA = 1.0;
	}else{
		// TODO if the sphere were to be completely faded out, dont draw it at all:
		if (highlightme < 0.0 ){
			if (FADESTART < FADEEND) { 
				// Rings that fade out on distance
				if ((distToCam + RANGE) > FADEEND) {
					FADEALPHA = 0.0;
					circleWorldPos.xz = modelWorldPos.xz;
				}
			}else {
				// Rings that fade out when close to the camera 
				// TODO ANTINUKES!
				if ((distToCam - RANGE) < FADEEND) {
					FADEALPHA = 0.0;
					//circleWorldPos.xz = modelWorldPos.xz;
				}
			}

			//--- Optimize by anything faded out getting transformed back to origin with 0 range?
			//seems pretty ok!
			
			//if a sphere at modelworldpos.xyz, with range poscale.w is out of the viewport, set visible to false:
			if (isSphereVisibleXY(vec4(modelWorldPos.xyz, 1.0), posscale.w * 3.0 )){
				//circleWorldPos.xz = modelWorldPos.xz;
			}
		}
	}	

	//FADEALPHA  = clamp((FADEEND + fadeDistOffset - distToCam)/(fadeDist), ENDALPHA, STARTALPHA);


	if (cannonmode > 0.5){
		// cannons should fade distance based on their range
		//float cvmin = max(FADESTART + fadeDistOffset, 2* RANGE);
		//float cvmax = max(FADEEND + fadeDistOffset, 4* RANGE);
		//FADEALPHA = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),STARTALPHA , ENDALPHA);
	}

	v_blendedcolor = color1;

	// -- DARKEN OUT OF LOS
	//vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
	//float inlos = dot(losTexSample.rgb,vec3(0.33));
	//inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
	//v_blendedcolor.rgb *= inlos;

	// --- YES FOG
	float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
	float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0, 1);
	v_blendedcolor.rgb = mix(fogColor.rgb, vec3(v_blendedcolor), fogFactor);


 


	// ------------ dump the stuff for FS --------------------
	//V_CIRCLEPROGRESS = circlepointposition.z; // save circle progress here
															  

	if (inMiniMap < 0.5) {
		gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
		//pull 16 elmos forward in Z:
		gl_Position.z = (gl_Position.z) - 128.0 / (gl_Position.w); // send 16 elmos forward in Z
	} else {
		gl_Position = mmDrawViewProj * vec4(circleWorldPos.xyz, 1.0);
	}

	//lets blend the alpha here, and save work in FS:
	float outalpha = OUTOFBOUNDSALPHA * (MOUSEALPHA + FADEALPHA *  lineAlphaUniform);
	v_blendedcolor.a *= outalpha ;
	if (ISDGUN > 0.5) {
		v_blendedcolor.a = clamp(v_blendedcolor.a * 3, 0.1, 1.0);
	}
	// Additional unituniform based selectedness metrics:

	// 0 = unit is un selected, 1 = unit is selected, 0.5 =  ally also selected unit, +2 = its mouseovered
	float selectedness = 0.0;
	
	if (staticUnits > 0.5) {
		selectedness = UNITUNIFORMS.userDefined[1].z;
	}

	float selectedUnitCount = selUnitCount;
	// -- nano is 2
	if(WEAPONTYPE == 2.0) {
		selectedUnitCount = selBuilderCount;
	}
	selectedUnitCount = clamp(selUnitCount, 1, 25);

	float innerRingDim = GROUPSELECTIONFADESCALE * 0.1 * selectedUnitCount;
	float finalAlpha = drawAlpha;
	if(drawMode == 2.0) {
		finalAlpha = drawAlpha / pow(innerRingDim, 2);
	}
	finalAlpha = clamp(finalAlpha, 0.0, 1.0);
	v_blendedcolor.a *= finalAlpha;

	//vec4 heightAndNormal = normalsAndHeightAtWorldPos(circleWorldPos.xz);
	//v_blendedcolor.rgb = heightAndNormal.xyz * 0.5 + 0.5;
	//v_blendedcolor.rgb = vec3(fract(distToCam/100));
}
