#version 120
uniform sampler2D diffuseTex;
uniform sampler2D shadingTex;
uniform vec4 ghostColor;
uniform vec4 teamColor;
uniform vec3 sunDir;
uniform vec3 sunAmbient;
uniform vec3 sunDiffuse;
uniform float simFrame;
varying vec3 worldNormal;
varying float worldHeight;
varying vec2 uv;
varying float fogFactor;
//__HOVER_SHIMMER__
void main()
{
	vec4 diffuse = texture2D(diffuseTex, uv);
	vec4 shading = texture2D(shadingTex, uv);
	float alpha = ghostColor.a * shading.a;
	if (alpha <= 0.0) discard;
	vec3 light = sunAmbient + sunDiffuse * max(dot(normalize(worldNormal), sunDir), 0.0);
	vec3 rgb = mix(diffuse.rgb, teamColor.rgb, diffuse.a) * (light + shading.rrr);
	rgb = mix(gl_Fog.color.rgb, rgb, fogFactor) * ghostColor.rgb;
	rgb += HoverShimmer(worldHeight, simFrame, ghostColor.rgb);
	gl_FragColor = vec4(rgb, alpha);
}
