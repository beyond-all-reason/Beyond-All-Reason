#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 posscale;
layout (location = 2) in vec4 color1;
layout (location = 3) in vec4 visibility; // FadeStart, FadeEnd, StartAlpha, EndAlpha
layout (location = 4) in vec4 projectileParams; // projectileSpeed, iscylinder!!!! , heightBoostFactor , heightMod
layout (location = 5) in vec4 additionalParams; // groupselectionfadescale, weaponType, +2 reserved
layout (location = 6) in uvec4 instData;

uniform float lineAlphaUniform = 1.0;
uniform float cannonmode = 0.0;
uniform float fadeDistOffset = 0.0;
uniform float drawMode = 0.0;
uniform float inMiniMap = 0.0;


uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

out DataVS {
	flat vec4 blendedcolor;
	vec4 circleprogress;
	float groupselectionfadescale;
	float weaponType;
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

	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#define UNITID (uni[instData.y].composite >> 16)


#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =  heightmapUVatWorldPos(w);
	return textureLod(heightmapTex, uvhm, 0.0).x;
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

vec2 rotate(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

//float heightMod  default: 0.2 (0.8 for #Cannon, 1.0 for #BeamLaser and #LightningCannon)
//Changes the spherical weapon range into an ellipsoid. Values above 1.0 mean the weapon cannot target as high as it can far, values below 1.0 mean it can target higher than it can far. For example 0.5 would allow the weapon to target twice as high as far.

//float heightBoostFactor default: -1.0
//Controls the boost given to range by high terrain. Values > 1.0 result in increased range, 0.0 means the cannon has fixed range regardless of height difference to target. Any value < 0.0 (i.e. the default value) result in an automatically calculated value based on range and theoretical maximum range.

#define RANGE posscale.w
#define PROJECTILESPEED projectileParams.x
#define ISCYLINDER projectileParams.y
#define HEIGHTBOOSTFACTOR projectileParams.z
#define HEIGHTMOD projectileParams.w
#define YGROUND posscale.y

#define OUTOFBOUNDSALPHA alphaControl.y
#define FADEALPHA alphaControl.z
#define MOUSEALPHA alphaControl.w

#define ISDGUN additionalParams.z

#define MAXANGLEDIF additionalParams.w

void main() {
	// Get the center pos of the unit
	vec3 modelWorldPos = uni[instData.y].drawPos.xyz;
	
	float unitHeading = uni[instData.y].drawPos.w ;
	
	circleprogress.xy = circlepointposition.xy;
	
	// find angle between unit Heading and circleprogress.xy
	//unitHeading is -pi to +pi, with zero on z+, and increasing towards x+
	//circleheading is -pi to +pi, with zero z-, and increasing towards x+ 
	
	// rotate the circle into unit space, wierd that it has to be rotated on other direction
	float maxAngleDif = 1;
	float mainDirDegrees = 0; 
	if (MAXANGLEDIF > 0.0) {
		maxAngleDif = fract(MAXANGLEDIF);// goes from 0.0 to 1.0, where 0.25 would mean a 90 deg cone
		mainDirDegrees = MAXANGLEDIF - maxAngleDif;// Is the offset in degrees. 
	}
	circleprogress.xy = rotate(circleprogress.xy, (3.141592 -1.0*unitHeading + mainDirDegrees * 3.141592 / 180.0));
	
	circleprogress.w = circlepointposition.z;
	blendedcolor = color1;
	groupselectionfadescale = additionalParams.x;
	weaponType = additionalParams.y;

	// translate to world pos:
	vec4 circleWorldPos = vec4(1.0);
	float range2 = RANGE;
	if (ISDGUN > 0.5) {
		circleWorldPos.xz = circleprogress.xy * RANGE * 1.05 + modelWorldPos.xz;
	} else {
		circleWorldPos.xz = circleprogress.xy * RANGE +  modelWorldPos.xz;
	}

	vec4 alphaControl = vec4(1.0);

	// get heightmap
	circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);


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
		//for (int i = 0; i < mod(timeInfo.x/8,16); i ++){ //i am a debugging god
		for (int i = 0; i < 16; i ++){
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
		if (ISCYLINDER < 0.5){ // isCylinder
			//simple implementation, 4 samples per point
			//for (int i = 0; i<mod(timeInfo.x/4,30); i++){
			for (int i = 0; i<8; i++){
				// draw vector from centerpoint to new height point and normalize it to range length
				vec3 tonew = circleWorldPos.xyz - modelWorldPos.xyz;
				tonew.y *= HEIGHTMOD;

				tonew = normalize(tonew) * RANGE;
				circleWorldPos.xz = modelWorldPos.xz + tonew.xz;
				circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
			}
		}
	}
	
	

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	OUTOFBOUNDSALPHA = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);
	
	
	// -- Better drawing of underwater stuff
	if (modelWorldPos.y > -20) { // for submerged units, try to keep the ranges above the water for clarity
		modelWorldPos.y = max(0, modelWorldPos.y);
		circleWorldPos.y = max(0, circleWorldPos.y);
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
	
	circleWorldPos.y += 6; // lift it from the ground


	//--- DISTANCE FADE ---
	vec4 camPos = cameraViewInv[3];

	// Note that this is not the same as the distance from the unit to the camera, but the distance from the circle to the camera
	float distToCam = length(modelWorldPos.xyz - camPos.xyz); //dist from cam
	// FadeStart, FadeEnd, StartAlpha, EndAlpha
	float fadeDist = visibility.y - visibility.x;

	if (ISDGUN > 0.5) {
		FADEALPHA  = clamp((visibility.y + fadeDistOffset + 1000 - distToCam)/(fadeDist),visibility.w,visibility.z);
	} else {
		FADEALPHA  = clamp((visibility.y + fadeDistOffset - distToCam)/(fadeDist),visibility.w,visibility.z);
	}

	if (inMiniMap> 0.5){
		FADEALPHA = 1.0;
	}
	
	//FADEALPHA  = clamp((visibility.y + fadeDistOffset - distToCam)/(fadeDist),visibility.w,visibility.z);

	//--- Optimize by anything faded out getting transformed back to origin with 0 range?
	//seems pretty ok!
	if (FADEALPHA < 0.001) {
		circleWorldPos.xyz = modelWorldPos.xyz;
	}

	if (cannonmode > 0.5){
	// cannons should fade distance based on their range
		//float cvmin = max(visibility.x+fadeDistOffset, 2* RANGE);
		//float cvmax = max(visibility.y+fadeDistOffset, 4* RANGE);
		//FADEALPHA = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),visibility.z,visibility.w);
	}

	blendedcolor = color1;

	// -- DARKEN OUT OF LOS
	//vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
	//float inlos = dot(losTexSample.rgb,vec3(0.33));
	//inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
	//blendedcolor.rgb *= inlos;

	// --- YES FOG
	float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
	float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0, 1);
	blendedcolor.rgb = mix(fogColor.rgb, vec3(blendedcolor), fogFactor);


	// -- IN-SHADER MOUSE-POS BASED HIGHLIGHTING
	float disttomousefromunit = 1.0 - smoothstep(48, 64, length(modelWorldPos.xz - mouseWorldPos.xz));
	// this will be positive if in mouse, negative else
	float highlightme = clamp( (disttomousefromunit ) + 0.0, 0.0, 1.0);
	// Note that this doesnt really work well with boundary-only stenciling, due to random draw order. 
	MOUSEALPHA = (0.1  + 0.5 * step(0.5,drawMode)) * highlightme;

	// ------------ dump the stuff for FS --------------------
	//worldPos = circleWorldPos;
	//worldPos.a = RANGE;
	alphaControl.x = circlepointposition.z; // save circle progress here

	if (inMiniMap < 0.5) {
		gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
	} else {
		gl_Position = mmDrawViewProj * vec4(circleWorldPos.xyz, 1.0);
	}

	//lets blend the alpha here, and save work in FS:
	float outalpha = OUTOFBOUNDSALPHA * (MOUSEALPHA + FADEALPHA *  lineAlphaUniform);
	blendedcolor.a *= outalpha ;
	if (ISDGUN > 0.5) {
		blendedcolor.a = clamp(blendedcolor.a * 3, 0.1, 1.0);
	}
	//blendedcolor.rgb = vec3(fract(distToCam/100));
}
