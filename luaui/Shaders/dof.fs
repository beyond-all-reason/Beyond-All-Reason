#define NORMALIZE_FILTER(fullRangeFilter) (fullRangeFilter * 0.25) + 0.5
#define UNNORMALIZE_FILTER(normedFilter) ((2.0 * normedFilter) - 1.0) * 2.0

// One program per pass: PASS selects it, HIGH_QUALITY adds the near (foreground) blur to the composition

uniform sampler2D origTex;

uniform sampler2D blurTex0;
uniform sampler2D blurTex1;
uniform sampler2D blurTex2;
uniform sampler2D blurTex3;
uniform sampler2D tileMask; // per TILE_SIZE^2 tile: whether farV, farH, nearV, nearH can change the result there

uniform mat4 projectionMat;
uniform vec2 resolution;

#if (PASS == FILTER_SIZE_PASS)
flat in float focusDepthV;
flat in float apertureV;
#endif

// Circular DOF by Kleber Garcia "Kecho" - 2017
// Publication & Filter generator: https://github.com/kecho/CircularDofFilterGenerator

/** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
**/
//Main blur pass parameters
const int KERNEL_RADIUS = 5;
const int KERNEL_COUNT = 11;
const vec4 Kernel0BracketsRealXY_ImZW = vec4(-0.056556,0.920040,-0.035849,0.611305);
const vec2 Kernel0Weights_RealX_ImY = vec2(0.411259,-0.548794);
const vec4 Kernel0_RealX_ImY_RealZ_ImW[] = vec4[](
	vec4(/*XY: Non Bracketed*/0.022302,-0.035849,/*Bracketed WZ:*/0.085711,0.000000),
	vec4(/*XY: Non Bracketed*/-0.056556,-0.013273,/*Bracketed WZ:*/0.000000,0.036931),
	vec4(/*XY: Non Bracketed*/-0.023847,0.070538,/*Bracketed WZ:*/0.035552,0.174032),
	vec4(/*XY: Non Bracketed*/0.059140,0.066382,/*Bracketed WZ:*/0.125751,0.167233),
	vec4(/*XY: Non Bracketed*/0.096696,0.020687,/*Bracketed WZ:*/0.166571,0.092483),
	vec4(/*XY: Non Bracketed*/0.102454,0.000000,/*Bracketed WZ:*/0.172829,0.058643),
	vec4(/*XY: Non Bracketed*/0.096696,0.020687,/*Bracketed WZ:*/0.166571,0.092483),
	vec4(/*XY: Non Bracketed*/0.059140,0.066382,/*Bracketed WZ:*/0.125751,0.167233),
	vec4(/*XY: Non Bracketed*/-0.023847,0.070538,/*Bracketed WZ:*/0.035552,0.174032),
	vec4(/*XY: Non Bracketed*/-0.056556,-0.013273,/*Bracketed WZ:*/0.000000,0.036931),
	vec4(/*XY: Non Bracketed*/0.022302,-0.035849,/*Bracketed WZ:*/0.085711,0.000000)
);
const vec4 Kernel1BracketsRealXY_ImZW = vec4(0.000181,0.552380,0.000000,0.180493);
const vec2 Kernel1Weights_RealX_ImY = vec2(0.513282,4.561110);
const vec4 Kernel1_RealX_ImY_RealZ_ImW[] = vec4[](
	vec4(/*XY: Non Bracketed*/0.000181,0.014423,/*Bracketed WZ:*/0.000000,0.079908),
	vec4(/*XY: Non Bracketed*/0.015852,0.024540,/*Bracketed WZ:*/0.028370,0.135962),
	vec4(/*XY: Non Bracketed*/0.042831,0.026910,/*Bracketed WZ:*/0.077211,0.149093),
	vec4(/*XY: Non Bracketed*/0.072553,0.018473,/*Bracketed WZ:*/0.131019,0.102347),
	vec4(/*XY: Non Bracketed*/0.094542,0.005900,/*Bracketed WZ:*/0.170826,0.032690),
	vec4(/*XY: Non Bracketed*/0.102454,0.000000,/*Bracketed WZ:*/0.185149,0.000000),
	vec4(/*XY: Non Bracketed*/0.094542,0.005900,/*Bracketed WZ:*/0.170826,0.032690),
	vec4(/*XY: Non Bracketed*/0.072553,0.018473,/*Bracketed WZ:*/0.131019,0.102347),
	vec4(/*XY: Non Bracketed*/0.042831,0.026910,/*Bracketed WZ:*/0.077211,0.149093),
	vec4(/*XY: Non Bracketed*/0.015852,0.024540,/*Bracketed WZ:*/0.028370,0.135962),
	vec4(/*XY: Non Bracketed*/0.000181,0.014423,/*Bracketed WZ:*/0.000000,0.079908)
);

const float baseStepValMag = 1.0/540.0;

const float colorPower = 1.9;

const float inFocusThreshold = 0.4 / float(KERNEL_RADIUS);
const float focusMixDepthRange = (float(KERNEL_RADIUS) * 2.0);
const float maxFilterRadius = 1.2; //keep between 0 and 2. Any higher than 2 will require modifying the normalization maths
								   //(currently does (radius/4)+0.5 to get [-2..2] to [0..1])

// Per-texel flags for skipping blur tiles, with margin for the 8-bit radius in finalBlurTex and the 16-bit one in the
// base texture: the composition only mixes in the far blur where |radius| > inFocusThreshold, and the near blur
// only gets alpha from radii < -inFocusThreshold
const float tileFarRadius = 0.06;
const float tileNearRadius = 0.07;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec2 multComplex(vec2 p, vec2 q)
{
	return vec2(p.x*q.x-p.y*q.y, p.x*q.y+p.y*q.x);
}

vec4 get2CompFilters(int x)
{
	vec2 c0 = Kernel0_RealX_ImY_RealZ_ImW[x].xy;
	vec2 c1 = Kernel1_RealX_ImY_RealZ_ImW[x].xy;
	return vec4(c0.x, c0.y, c1.x, c1.y);
}

float LinearizeDepth(vec2 uv){
	float depthNDC = textureLod(blurTex0, uv, 0.0).r;
	#if (DEPTH_CLIP01 == 0)
		depthNDC = NORM2SNORM(depthNDC);
	#else
		// no need to do anything depthNDC is already in [0;1] range
	#endif

	//return ((abs(((1.0 + depthNDC) * (1.0 + n22))/(2.0 * (depthNDC + n22)))
	//	* (distanceLimits.y - distanceLimits.x)) + distanceLimits.x) / BLUR_START_DIST;
	return -(projectionMat[3][2] / (projectionMat[2][2] + depthNDC)) / BLUR_START_DIST;
}

float GetFilterRadius(vec2 uv)
{
	return UNNORMALIZE_FILTER(textureLod(origTex, uv, 0.0).a);
}

float GetEdgeNearFilterRadius(vec2 uv, vec2 stepVal)
{
	vec2 maxCoordsOffset = stepVal * maxFilterRadius * KERNEL_RADIUS;
	vec2 maxCoordsOffsetPerp = vec2(stepVal.y, -stepVal.x) * maxFilterRadius * KERNEL_RADIUS;
	float edgeRadius =
	min(min(GetFilterRadius(uv + maxCoordsOffset), GetFilterRadius(uv - maxCoordsOffset)),
	min(GetFilterRadius(uv + maxCoordsOffsetPerp), GetFilterRadius(uv - maxCoordsOffsetPerp)));
	float halfEdgeRadius =
	min(min(GetFilterRadius(uv + maxCoordsOffset / 2.0), GetFilterRadius(uv - maxCoordsOffset / 2.0)),
	min(GetFilterRadius(uv + maxCoordsOffsetPerp / 2.0), GetFilterRadius(uv - maxCoordsOffsetPerp / 2.0)));
	return min(edgeRadius, halfEdgeRadius);
}

vec2 GetFilterCoords(int i, vec2 uv, vec2 stepVal, float filterRadius, out float targetFilterRadius)
{
	float filterDistance = float(i)*abs(filterRadius);
	vec2 coords = uv + stepVal*filterDistance;
	targetFilterRadius = GetFilterRadius(coords);

	//Taking the filter radius for the first candidate sampled pixel if it's less than the base filter radius
	//makes sure that we both don't blur in-focus objects into out-of-focus regions behind them, and
	//also blur in the out-of-focus objects nearer to the camera than the in-focus region.
	//This works because it's basically checking if the first candidate sampled pixel's blur radius is large
	//enough to hit the pixel we are gathering into now, that means its circle of confusion is big enough to reach
	//that starting pixel.
	if (targetFilterRadius - filterRadius < -0.02 / float(KERNEL_RADIUS))
	{
		filterDistance = (float(i))*abs(targetFilterRadius);
		coords = uv + stepVal*filterDistance;
	}
	return coords;
}

//Used to find the mix value to blend between the full-size screen texture and the
//downscaled out-of-focus textures.
float FocusThresholdMixFactor(float filterRadius, float threshold)
{
	return clamp((filterRadius - threshold) * focusMixDepthRange, 0.0, 1.0);
}

#define TILE_NEEDED(channel) (texelFetch(tileMask, ivec2(gl_FragCoord.xy) / TILE_SIZE, 0).channel > 0.5)

// The centre tap (i == 0) of every blur lands on uv with the centre's radius, so it reuses the centre fetch.
void main()
{
	vec2 uv = gl_TexCoord[0].st;
	float aspectRatio = resolution.y / resolution.x;
	vec2 stepVal = vec2(baseStepValMag * aspectRatio, baseStepValMag);

	#if (PASS == FILTER_SIZE_PASS)
	{
		float depth = LinearizeDepth(uv);
		float filterRadius = clamp(((depth - focusDepthV) * apertureV)/depth, -maxFilterRadius, maxFilterRadius);

		vec4 colors = textureLod(origTex, uv, 0.0);
		//Add extra brightness to brighter colours in blurrier spots to maintain a consistent exposure.
		//In real life there would be a wide enough range of light levels to make bright blurry regions not
		//lose brightness when blurring, but we need to fudge that here.
		float lum = dot(colors.rgb,vec3(0.2126,0.7152,0.0722))*(min(0.2 + 0.65 * abs(filterRadius), 1.5));
		colors = colors *(1.0 + 0.2*lum*lum*lum);
		//Raise colours to a power to increase the sharpness of the blur discs
		colors = vec4(pow(colors.r, colorPower), pow(colors.g, colorPower), pow(colors.b, colorPower), colors.a);

		gl_FragData[0] = vec4(colors.rgb, NORMALIZE_FILTER(filterRadius));
		gl_FragData[1] = vec4(abs(filterRadius) > tileFarRadius ? 1.0 : 0.0, filterRadius < -tileNearRadius ? 1.0 : 0.0, 0.0, 0.0);
	}
	#elif (PASS == INITIAL_BLUR_PASS)
	{
		if (!TILE_NEEDED(r))
			discard;

		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		vec4 centerTexel = textureLod(origTex, uv, 0.0);
		float filterRadius = UNNORMALIZE_FILTER(centerTexel.a);
		float targetFilterRadius = 0.0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			vec4 imageTexelRGB = centerTexel;
			if (i != 0)
			{
				vec2 coords = GetFilterCoords(i, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius);
				imageTexelRGB = textureLod(origTex, coords, 0.0);
			}

			vec4 c0_c1 = get2CompFilters(i+KERNEL_RADIUS);
			valR.xy += imageTexelRGB.r * c0_c1.xy;
			valR.zw += imageTexelRGB.r * c0_c1.zw;
			valG.xy += imageTexelRGB.g * c0_c1.xy;
			valG.zw += imageTexelRGB.g * c0_c1.zw;
			valB.xy += imageTexelRGB.b * c0_c1.xy;
			valB.zw += imageTexelRGB.b * c0_c1.zw;
		}
		gl_FragData[0] = valR;
		gl_FragData[1] = valG;
		gl_FragData[2] = valB;
	}
	#elif (PASS == FINAL_BLUR_PASS)
	{
		float filterRadius = GetFilterRadius(uv);
		float normalizedRadius = NORMALIZE_FILTER(filterRadius);
		// the composition reads the radius everywhere, the colour only where the tile mask says it can be mixed in
		if (!TILE_NEEDED(g))
		{
			gl_FragData[0] = vec4(0.0, 0.0, 0.0, normalizedRadius);
			return;
		}

		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		float targetFilterRadius = 0.0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			vec2 coords = uv;
			if (i != 0)
			{
				coords = GetFilterCoords(i, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius);
			}
			vec4 imageTexelR = textureLod(blurTex0, coords, 0.0);
			vec4 imageTexelG = textureLod(blurTex1, coords, 0.0);
			vec4 imageTexelB = textureLod(blurTex2, coords, 0.0);

			vec4 c0_c1 = get2CompFilters(i+KERNEL_RADIUS);

			valR.xy += multComplex(imageTexelR.xy,c0_c1.xy);
			valR.zw += multComplex(imageTexelR.zw,c0_c1.zw);

			valG.xy += multComplex(imageTexelG.xy,c0_c1.xy);
			valG.zw += multComplex(imageTexelG.zw,c0_c1.zw);

			valB.xy += multComplex(imageTexelB.xy,c0_c1.xy);
			valB.zw += multComplex(imageTexelB.zw,c0_c1.zw);
		}

		float redChannel	 = dot(valR.xy,Kernel0Weights_RealX_ImY)+dot(valR.zw,Kernel1Weights_RealX_ImY);
		float greenChannel = dot(valG.xy,Kernel0Weights_RealX_ImY)+dot(valG.zw,Kernel1Weights_RealX_ImY);
		float blueChannel	= dot(valB.xy,Kernel0Weights_RealX_ImY)+dot(valB.zw,Kernel1Weights_RealX_ImY);

		gl_FragData[0] = vec4(vec3(pow(redChannel, 1.0/colorPower),pow(greenChannel, 1.0/colorPower),
			pow(blueChannel, 1.0/colorPower)), normalizedRadius);
	}
	#elif (PASS == INITIAL_NEAR_BLUR_PASS)
	{
		if (!TILE_NEEDED(b))
			discard;

		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		vec4 valA = vec4(0,0,0,0);
		//Start by finding the maximum possible relevant blur radius, since we're blurring things
		//that will end up in front of more in-focus objects.
		vec4 centerTexel = textureLod(origTex, uv, 0.0);
		float baseFilterRadius = UNNORMALIZE_FILTER(centerTexel.a);
		float filterRadius = min(baseFilterRadius, GetEdgeNearFilterRadius(uv, stepVal));
		filterRadius = min(filterRadius, GetEdgeNearFilterRadius(uv, vec2(stepVal.y, 0.0)));
		float targetFilterRadius = 0.0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			vec4 c0_c1 = get2CompFilters(i+KERNEL_RADIUS);
			vec4 imageTexelRGB = centerTexel;
			// the centre tap's alpha is min(.., |base - base| / 0.05) = 0
			if (i != 0)
			{
				vec2 coords = GetFilterCoords(i, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius);
				imageTexelRGB = textureLod(origTex, coords, 0.0);
				float alpha = FocusThresholdMixFactor(-targetFilterRadius, inFocusThreshold);
				alpha = min(alpha, clamp(abs(targetFilterRadius - baseFilterRadius) / 0.05, 0.0, 1.0));
				valA.xy += alpha * c0_c1.xy;
				valA.zw += alpha * c0_c1.zw;
			}

			valR.xy += imageTexelRGB.r * c0_c1.xy;
			valR.zw += imageTexelRGB.r * c0_c1.zw;
			valG.xy += imageTexelRGB.g * c0_c1.xy;
			valG.zw += imageTexelRGB.g * c0_c1.zw;
			valB.xy += imageTexelRGB.b * c0_c1.xy;
			valB.zw += imageTexelRGB.b * c0_c1.zw;
		}

		gl_FragData[0] = valR;
		gl_FragData[1] = valG;
		gl_FragData[2] = valB;
		gl_FragData[3] = valA;
	}
	#elif (PASS == FINAL_NEAR_BLUR_PASS)
	{
		// no foreground in reach: alpha is exactly 0, and no mixed-in pixel samples this texel's colour
		if (!TILE_NEEDED(a))
		{
			gl_FragData[0] = vec4(0.0);
			return;
		}

		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		vec4 valA = vec4(0,0,0,0);
		float baseFilterRadius = GetFilterRadius(uv);
		float filterRadius = min(baseFilterRadius, GetEdgeNearFilterRadius(uv, stepVal));
		filterRadius = min(filterRadius, GetEdgeNearFilterRadius(uv, vec2(stepVal.x, 0.0)));
		float targetFilterRadius = 0.0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			vec4 c0_c1 = get2CompFilters(i+KERNEL_RADIUS);
			vec2 coords = uv;
			// the centre tap's alpha is min(.., |base - base| / 0.05) = 0
			if (i != 0)
			{
				coords = GetFilterCoords(i, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius);

				//imageTexelA has the alpha from the initial pass, but we need to also get it for the
				//final pass separately since alpha represents the edge of different filter radii, and
				//that's not something a single pass of a 2-pass blur will fully pick up.
				float finalPassAlpha = FocusThresholdMixFactor(-targetFilterRadius, inFocusThreshold);
				finalPassAlpha = min(finalPassAlpha, clamp(abs(targetFilterRadius - baseFilterRadius) / 0.05, 0.0, 1.0));
				valA.xy += finalPassAlpha * c0_c1.xy;
				valA.zw += finalPassAlpha * c0_c1.zw;
			}

			vec4 imageTexelR = textureLod(blurTex0, coords, 0.0);
			vec4 imageTexelG = textureLod(blurTex1, coords, 0.0);
			vec4 imageTexelB = textureLod(blurTex2, coords, 0.0);
			vec4 imageTexelA = textureLod(blurTex3, coords, 0.0);

			valR.xy += multComplex(imageTexelR.xy,c0_c1.xy);
			valR.zw += multComplex(imageTexelR.zw,c0_c1.zw);

			valG.xy += multComplex(imageTexelG.xy,c0_c1.xy);
			valG.zw += multComplex(imageTexelG.zw,c0_c1.zw);

			valB.xy += multComplex(imageTexelB.xy,c0_c1.xy);
			valB.zw += multComplex(imageTexelB.zw,c0_c1.zw);

			valA.xy += multComplex(imageTexelA.xy,c0_c1.xy);
			valA.zw += multComplex(imageTexelA.zw,c0_c1.zw);
		}

		float redChannel	 = dot(valR.xy,Kernel0Weights_RealX_ImY)+dot(valR.zw,Kernel1Weights_RealX_ImY);
		float greenChannel = dot(valG.xy,Kernel0Weights_RealX_ImY)+dot(valG.zw,Kernel1Weights_RealX_ImY);
		float blueChannel	= dot(valB.xy,Kernel0Weights_RealX_ImY)+dot(valB.zw,Kernel1Weights_RealX_ImY);
		float alphaChannel	= dot(valA.xy,Kernel0Weights_RealX_ImY)+dot(valA.zw,Kernel1Weights_RealX_ImY);

		gl_FragData[0] = vec4(pow(redChannel, 1.0/colorPower),pow(greenChannel, 1.0/colorPower),
			pow(blueChannel, 1.0/colorPower), clamp(alphaChannel, 0.0, 1.0));
	}
	#elif (PASS == COMPOSITION_PASS)
	{
		vec4 blurTexAtUV = textureLod(blurTex0, uv, 0.0);
		float filterRadius = UNNORMALIZE_FILTER(blurTexAtUV.a);
		float mixFactor = FocusThresholdMixFactor(abs(filterRadius), inFocusThreshold);
		#if (HIGH_QUALITY == 1)
			vec4 nearBlurTexAtUV = textureLod(blurTex1, uv, 0.0);
			float alpha = clamp(nearBlurTexAtUV.a * 1.5, 0.0, 1.0);
			// in focus: the result would be the screen copy, so leave the screen (and its MSAA samples) untouched
			if (mixFactor == 0.0 && alpha == 0.0)
				discard;
		#else
			if (mixFactor == 0.0)
				discard;
		#endif

		vec4 fragColor = mix(textureLod(origTex, uv, 0.0), blurTexAtUV, mixFactor);
		#if (HIGH_QUALITY == 1)
			fragColor.rgb = mix(fragColor.rgb, nearBlurTexAtUV.rgb, alpha);
		#endif

		gl_FragData[0] = fragColor;
	}
	#elif (PASS == TILE_FLAG_PASS)
	{
		// one fragment per tile of the filter pass's per-texel flags (origTex): a bilinear fetch between 2x2 texels
		// is above 0 if any of them is set
		vec2 texelSize = 1.0 / vec2(textureSize(origTex, 0));
		vec2 firstCorner = (vec2(ivec2(gl_FragCoord.xy) * TILE_SIZE) + 1.0) * texelSize;
		vec2 flags = vec2(0.0);
		for (int y = 0; y < TILE_SIZE; y += 2)
		{
			for (int x = 0; x < TILE_SIZE; x += 2)
			{
				flags = max(flags, textureLod(origTex, firstCorner + vec2(x, y) * texelSize, 0.0).rg);
			}
		}
		gl_FragData[0] = vec4(flags.r > 0.0 ? 1.0 : 0.0, flags.g > 0.0 ? 1.0 : 0.0, 0.0, 0.0);
	}
	#elif (PASS == TILE_MASK_PASS)
	{
		// grow the tile flags (origTex) by how far each pass reaches: a tap moves up to KERNEL_RADIUS * maxFilterRadius
		// steps, plus bilinear neighbours and the final passes' slightly oversized quad; the composition's bilinear
		// upsampling adds a texel (reachNear) or a tile (far)
		float maxTapTexels = float(KERNEL_RADIUS) * maxFilterRadius * baseStepValMag * resolution.y;
		int reachH = int(ceil((maxTapTexels + 2.0) / float(TILE_SIZE)));
		int reachNear = int(ceil((maxTapTexels + 3.0) / float(TILE_SIZE)));
		int rangeX = max(reachH + 1, reachH + reachNear);
		int rangeY = max(1, reachNear);

		ivec2 tiles = textureSize(origTex, 0);
		ivec2 tile = ivec2(gl_FragCoord.xy);
		bvec4 needed = bvec4(false); // farV, farH, nearV, nearH
		for (int dy = -rangeY; dy <= rangeY; ++dy)
		{
			for (int dx = -rangeX; dx <= rangeX; ++dx)
			{
				ivec2 t = tile + ivec2(dx, dy);
				if (any(lessThan(t, ivec2(0))) || any(greaterThanEqual(t, tiles)))
					continue;

				vec2 flags = texelFetch(origTex, t, 0).rg;
				int ax = abs(dx);
				int ay = abs(dy);
				if (flags.r > 0.5)
				{
					needed.x = needed.x || (ax <= reachH + 1 && ay <= 1);
					needed.y = needed.y || (ax <= 1 && ay <= 1);
				}
				if (flags.g > 0.5)
				{
					needed.z = needed.z || (ax <= reachH + reachNear && ay <= reachNear);
					needed.w = needed.w || (ax <= reachNear && ay <= reachNear);
				}
			}
		}
		gl_FragData[0] = vec4(needed);
	}
	#endif
}
