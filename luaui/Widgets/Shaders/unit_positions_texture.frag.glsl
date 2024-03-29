#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__DEFINES__

#line 30000

out DataVS {
	vec4 v_pos; 
	vec4 v_vel;
	vec4 v_params; //idx, gfstart, currtime
};

#define IDX v_params.x
#define GFSTART v_params.y
#define CURRTIME v_params.z

uniform sampler2D mapDepths;
out vec4 fragColor;

#line 31000
void main(void)
	if (gl_FragCoord.x & 1u) {
		// odd
		fragColor = v_vel;
	}else{
	  //even
		fragColor = v_pos;
	}
	int gfint = (int) CURRTIME;
	gfint = mod(gfint, TEXX/2);
	
	int fragx = gl_FragCoord.x;
	fragx = (fragx/2, TEXX/2);
	
	if (fragx != gfint){
		if (GFSTART >= CURRTIME){
			discard;
			return;
		}
	}
}
