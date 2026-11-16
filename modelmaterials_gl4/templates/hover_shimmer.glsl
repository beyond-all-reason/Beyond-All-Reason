// Shared by visible CUS units and the Lua ghost renderer (GLSL 1.20 and GL4).
vec3 HoverShimmer(float worldHeight, float simFrame, vec3 highlightColor)
{
	float band = fract(worldHeight * (1.0 / 30.0) + simFrame * (2.0 / 40.0));
	return highlightColor * band * 0.5;
}
