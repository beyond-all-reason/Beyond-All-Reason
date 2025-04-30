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
float filteredGrid( in vec2 p, in vec2 dpdx, in vec2 dpdy, float resolution)
{

    vec2 w = max(abs(dpdx), abs(dpdy));
    vec2 a = p + 0.5*w;                        
    vec2 b = p - 0.5*w;           
    vec2 i = (floor(a)+min(fract(a)*resolution,1.0)-
              floor(b)-min(fract(b)*resolution,1.0))/(resolution*w);
    return (1.0-i.x)*(1.0-i.y);
}

// This function allows you to threshold a value at a fixed screen resolution
float filteredStep( in float p, in float resolution)
{
    resolution *= 1.1;
    float dpdx = dFdx(p);
    float dpdy = dFdy(p);
    float dpddiag =  dFdy(dpdx) ;
    float w = max(max(abs(dpdx), abs(dpdy)), abs(dpddiag));
    float w1k = w * 1000.0;

    if (w < 1e-6) return 0.0; // dont divide by zero later on
    float a = p + 0.5*w;                        
    float b = p - 0.5*w;           
    float i = (floor(a)+min(fract(a)*resolution,10.1)-
              floor(b)-min(fract(b)*resolution,10.1))/(resolution*w);
    
    return clamp(i-1, 0, 1);

}

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
        -- TODO: how do we know if an area is under radar coverage, but jammed?
	-- It runs every gameFrame


// TODO LIST:
// Shade map edge extension via a clamped sampling of the edge so its pretty
// Pull back water surface stuff so that the water surface is the one thats being shaded
// Blend also the fact that underwater stuff needs alternate handling
// Add a nice static noise, that is slaved to screenUV and time maybe, instead of others?
// Experiment with scanline-type shading for terrible areas
// How should radar jammed areas be handled, if at all?
// We dont have any sonar info, thats pretty bad in the usability front. 

*/


/*
// 4x4 bicubic filter using 4 bilinear texture lookups 
// See GPU Gems 2: "Fast Third-Order Texture Filtering", Sigg & Hadwiger:
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter20.html

// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a)
{
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a)
{
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a)
{
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a)
{
    return (1.0/6.0)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a)
{
    return w0(a) + w1(a);
}

float g1(float a)
{
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a)
{
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a)
{
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 texture_bicubic(sampler2D tex, vec2 uv, vec4 texelSize)
{
	uv = uv*texelSize.zw + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;
	
    return g0(fuv.y) * (g0x * texture(tex, p0)  +
                        g1x * texture(tex, p1)) +
           g1(fuv.y) * (g0x * texture(tex, p2)  +
                        g1x * texture(tex, p3));
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (fragCoord.xy - iMouse.xy) / iResolution.xy;
    
    vec2 uv = p*0.1;
	
    //---------------------------------------------	
	// regular texture map filtering
    //---------------------------------------------	
	vec3 colA = texture( iChannel0, uv ).xyz;

    // bicubic
    vec4 texelSize = vec4( 1.0 / iChannelResolution[0].xy,  iChannelResolution[0].xy);
	vec3 colB = texture_bicubic( iChannel0, uv, texelSize ).xyz;	
    
    //---------------------------------------------	
    // mix between the two colors
    //---------------------------------------------	
	vec3 col = mix( colA, colB, smoothstep( -0.3, 0.3, sin(1.0*p.x + 3.1416*iTime) ) );
    
    fragColor = vec4( col, 1.0 );
}
*/

float gradientStep(float x, float width){
    return smoothstep(0.0,  1.0, (0.5 - width * abs(x-0.5)) * 2.0);
}
void main(void) {
    
    vec4 screenColor = texture2D(screenCopyTex, texCoord.xy);

    float mapdepth = texture(mapDepths, texCoord.xy).x;
    #if (PREUNIT == 0)
        float modeldepth = texture(modelDepths, texCoord.xy).x;
        float worlddepth = min(mapdepth, modeldepth);
        // We might need to use information that we are processing a model fragment and need to shade differently
        float ismodel = (modeldepth < mapdepth? 1.0: 0.0) ;
    #else
        float worlddepth = mapdepth;
        // We might need to use information that we are processing a model fragment and need to shade differently
        float ismodel = 0.0 ;
    #endif
	vec4 fragWorldPos =  vec4( vec3(texCoord.xy * 2.0 - 1.0, worlddepth),  1.0);

	// reconstruct view pos:
	fragWorldPos = cameraViewProjInv * fragWorldPos;
	fragWorldPos.xyz = fragWorldPos.xyz / fragWorldPos.w; // YAAAY this works!

    vec3 waterSurfacePos = vec3(0,0,0);

    //clamp fragWorldPos to the infolos tex bounds:
    vec2 infolosUV = clamp(fragWorldPos.xz / mapSize.xy, 0, 1);
    vec4 infolosSample = texture2D(losTex, infolosUV);

    //printf(infolosSample.xyzw);

    // Known constants:
    vec3 current_losairradar = smoothstep(0.227, 0.973, infolosSample.rgb);
    vec3 hasbeen_losairradar = step(0.2, infolosSample.rgb);
    //printf(current_losairradar.rgb);
    //printf(hasbeen_losairradar.rgb);
    float isjammed = (infolosSample.b < 0.5 ? 1.0 : 0.0);

    
    // Find the HSV value of the screen color
    vec3 screenHSV = rgb2hsv(screenColor.rgb);
    //printf(screenHSV.rgb);
    // Darken unsaturated areas
    // Everything from now on will be done via mix!

    
    screenHSV = mix( screenHSV * vec3(1,0.5,1), screenHSV, current_losairradar.g);
    screenHSV = mix( screenHSV * vec3(1,0,1), screenHSV, current_losairradar.r);

    float unsaturation = 1.0 - screenHSV.y;
    //screenHSV.z *= (screenHSV.y ) * (1.0 - current_losairradar.r);
    //screenHSV.y = screenHSV.y * current_losairradar.r;

    screenColor.rgb = hsv2rgb(screenHSV);

    // Darken by airlosvalue:

    //screenColor.rgb *= airlosvalue;

    // Add noise by lack of radar:

    #if 0
        vec4 radarNoise = Value3D_Deriv(fragWorldPos.xyz * 0.125 + vec3(0,timeInfo.x * 0.1,0));
        screenColor.rgb = mix(screenColor.rgb, radarNoise.rgb, (1.0 - current_losairradar.b) * 0.1);
    #endif
    // Scanlines?

    vec3 scanlineColor = screenColor.rgb * 0.75;
    screenColor.rgb = mix(screenColor.rgb, scanlineColor,  (1.0 - current_losairradar.b) *step(0.5, fract(gl_FragCoord.y/4.0)));
    
    
    // Gradient step
    #if 0
    screenColor.rgb *= (1.0 - 0.3 * gradientStep(current_losairradar.b, 3.4));
    #endif

    // fixed-width gradient step:
    #if 1
        float timeCorrection = timeInfo.w;
        if (timeCorrection < 0.0) timeCorrection = 0;
        if (timeCorrection > 1.0) timeCorrection = 0;
        float losEdge = filteredStep(current_losairradar.b - 0.5 - (timeCorrection * 0.00), 0.5);
        screenColor.g += 0.2 * losEdge;
    #endif


    fragColor.rgb = screenColor.rgb;
    #if 1 // GRID DEBUGGING
        vec2 gridpos = (fragWorldPos.xz + vec2(0.5)) /64.0 ;
        float grid = 1.0 - filteredGrid( gridpos.xy, dFdx(gridpos.xy), dFdy(gridpos.xy) , 64.0);
        gridpos = (fragWorldPos.xz  + vec2(0.5) ) /8.0;
        grid += filteredGrid( gridpos.xy, dFdx(gridpos.xy), dFdy(gridpos.xy) , 64.0);
        fragColor.rgb += 0.2 * (1.0 - grid);
    #endif
    fragColor.a = 1.0;
    //fragColor.rgba = vec4(infolosSample.rrr, 1.0);
}