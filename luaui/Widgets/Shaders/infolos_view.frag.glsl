#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D screenCopyTex;
uniform sampler2D losTex;

uniform vec4 blendfactors = vec4(1.0);

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
    vec4 texCoord;
};

out vec4 fragColor;
 /*
-- About:
	-- This API presents an easy -to-use smoothed LOS texture for other widgets to do their shading based on
	-- It exploits truncation of values during blending to provide prevradar and prevlos values too!
	-- The RED channel contains LOS level, where
		-- 0.2-1.0 is LOS level
		-- < 0.2 is _never_been_in_los!
	-- the GREEN channel contains AIRLOS level
		-- 0.2-1.0 is LOS level
		-- < 0.2 is _never_been_in_los!

	-- the BLUE channel contains RADAR coverage
		-- < 0.2 = never been in radar
		-- fragColor.b = 0.2 + 0.8 * clamp(0.75 * radarJammer.r - 0.5 * (radarJammer.g - 0.5),0,1);
		-- >0.2 = radar coverage
		-- <0.5 = jammer
	-- It runs every gameFrame

*/

vec4 Value3D_Deriv( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/Value3D_Deriv.glsl

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
    vec2 hash_mod = vec2( 1.0 / ( 635.298681 + vec2( Pi.z, Pi_inc1.z ) * 48.500388 ) );
    vec4 hash_lowz = fract( Pt * hash_mod.xxxx );
    vec4 hash_highz = fract( Pt * hash_mod.yyyy );

    //	blend the results and return
    vec3 blend = Pf * Pf * Pf * (Pf * (Pf * 6.0 - 15.0) + 10.0);
    vec3 blendDeriv = Pf * Pf * (Pf * (Pf * 30.0 - 60.0) + 30.0);
    vec4 res0 = mix( hash_lowz, hash_highz, blend.z );
    vec4 res1 = mix( res0.xyxz, res0.zwyw, blend.yyxx );
    vec4 res3 = mix( vec4( hash_lowz.xy, hash_highz.xy ), vec4( hash_lowz.zw, hash_highz.zw ), blend.y );
    vec2 res4 = mix( res3.xz, res3.yw, blend.x );
    return vec4( res1.x, 0.0, 0.0, 0.0 ) + ( vec4( res1.yyw, res4.y ) - vec4( res1.xxz, res4.x ) ) * vec4( blend.x, blendDeriv );
}
vec3 hsv2rgb(vec3 c){
	vec4 K=vec4(1.,2./3.,1./3.,3.);
	return c.z*mix(K.xxx,clamp(abs(fract(c.x+K.xyz)*6.-K.w)-K.x, 0, 1),c.y);
}

vec3 rgb2hsv(vec3 c){
	vec4 K=vec4(0.,-1./3.,2./3.,-1.);
	vec4 p=mix(vec4(c.bg ,K.wz),vec4(c.gb,K.xy ),step(c.b,c.g));
	vec4 q=mix(vec4(p.xyw,c.r ),vec4(c.r ,p.yzx),step(p.x,c.r));
	float d=q.x-min(q.w,q.y);
	float e=1e-10;
	return vec3(abs(q.z+(q.w-q.y)/(6.*d+e)),d/(q.x+e),q.x);
}

void main(void) {
    float mapdepth = texture(mapDepths, texCoord.xy).x;
	float modeldepth = texture(modelDepths, texCoord.xy).x;
	float worlddepth = min(mapdepth, modeldepth);
	float ismodel = 0;
    

    if (modeldepth < mapdepth) { // We are processing a model fragment
        ismodel = 1;
    }
    
    vec4 screenColor = texture2D(screenCopyTex, texCoord.xy);

	vec4 fragWorldPos =  vec4( vec3(texCoord.xy * 2.0 - 1.0, worlddepth),  1.0);

	// reconstruct view pos:

	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!

    //clamp fragWorldPos to the infolos tex bounds:
    vec2 infolosUV = clamp(fragWorldPos.xz / mapSize.xy, 0, 1);

    vec4 infolosSample = texture2D(losTex, infolosUV);

    float losvalue = infolosSample.r;
    
    // Desaturate screenColor by losvalue:

    vec3 screenHSV = rgb2hsv(screenColor.rgb);

    screenHSV.y = screenHSV.y * losvalue;

    screenColor.rgb = hsv2rgb(screenHSV);

    // Darken by airlosvalue:

    float airlosvalue = (infolosSample.g );

    screenColor.rgb *= airlosvalue;

    // Add noise by lack of radar:

    float radarvalue = infolosSample.b;
    vec4 radarNoise = Value3D_Deriv(fragWorldPos.xyz * 0.1 + vec3(0,timeInfo.x * 0.1,0));
    if (radarvalue < 0.5){
        screenColor.rgb *= radarNoise.w;
        //screenColor.r = 1.0;
    }

    fragColor.rgb = fract( infolosUV.xxy);
    fragColor.a = 1.0;
    fragColor.rgb = screenColor.rgb;
    //fragColor.rgba = vec4(0.0);
}