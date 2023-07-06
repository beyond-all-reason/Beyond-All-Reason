#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//(c) Beherith (mysterme@gmail.com)
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000

in DataGS {
	vec4 g_uv;
	vec4 g_pos;
	flat vec4 g_color;
};

uniform sampler2D DrawPrimitiveAtUnitTexture;
out vec4 fragColor;

vec2 rotate2D(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, -s, s, c);
	return m * v;
}

float LensFlareDistanceSqrt(vec3 pointpos, vec3 lightpos, float radius){
	float sqrtsum = dot(sqrt(abs(pointpos - lightpos)), vec3(1.0));
	return (sqrtsum * sqrtsum) / radius;
}

void main(void)
{
	vec4 texcolor = vec4(1.0);
	//texcolor = texture(DrawPrimitiveAtUnitTexture, g_uv.xy);
	//fragColor.rgba = vec4(g_color.rgb * texcolor.rgb + addRadius, texcolor.a * TRANSPARENCY + addRadius);

	//Match Existing:
	fragColor.rgb = g_color.rgb;
	vec2 centered = (g_uv.xy - vec2(0.5)); // center the UV coordinates to the center of the billboard 
	centered = rotate2D(centered, g_uv.z + timeInfo.x * 0.05);
	centered = abs(centered);
	fragColor.a = 1.0 - smoothstep(0.1,0.5, centered.x + centered.y);
	fragColor.a *= g_color.a;
	fragColor.rgba = clamp(fragColor.rgba, 0,1);
	//fragColor.rgba = vec4(1.0);
	
	// BUBBLES
	vec2 circlepos = (g_uv.xy - vec2(0.5))*2.0;
	fragColor.a = pow(length(circlepos), 3);
	if (fragColor.a > 1.0) fragColor.a = 0.0;
	
	// TENDRILS
	vec2 roted = rotate2D(circlepos, g_uv.z + timeInfo.x * 0.05);
	float sqrtsum = dot(sqrt(abs(roted.xy)), vec2(1.0));
	fragColor.a += 1.0 - sqrtsum;
	
	// SQUARE
	fragColor.a += 0.5*step(max(abs(roted.y),abs(roted.x)),0.4);
	
}