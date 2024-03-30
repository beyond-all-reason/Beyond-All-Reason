#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__DEFINES__

#line 30000

in DataVS {
	vec4 v_params; //idx, gfstart, currtime
	vec4 v_pos; 
	vec4 v_vel;
};

#define IDX v_params.x
#define GFSTART v_params.y
#define CURRTIME v_params.z

uniform sampler2D mapDepths;
out vec4 fragColor;

#line 31000
void main(void){

	ivec4 iparams = ivec4(v_params); 
	int textureIndex = iparams.x;
	int GameFrameStart = iparams.y;
	int currTime = iparams.z;
	ivec2 fragCoord = ivec2(gl_FragCoord.xy);
	
	if ((fragCoord.x & 1u) == 1u) {
		// odd
		fragColor = v_vel;
	}else{
	  //even
		fragColor = v_pos;
	}
	int numSamples = TEXX/2;
	

	int nowFrameIndex = currTime - numSamples * (currTime / numSamples);
	int startFrameIndex = GameFrameStart - numSamples * ( GameFrameStart / numSamples);
	int fragmentIndex = fragCoord.x / 2;
	
	
	if (fragmentIndex == nowFrameIndex){
		// we are working the current pixels
	} else{
		// we are working all other pixels
		if (GFSTART <= CURRTIME){
			// reset all other pixels to current if we need to initialize a unit
			
			//fragColor = vec4(1.5);
			discard;
		}
	}
}
