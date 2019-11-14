#define NORMALIZE_FILTER(fullRangeFilter) (fullRangeFilter * 0.25) + 0.5
#define UNNORMALIZE_FILTER(normedFilter) ((2.0 * normedFilter) - 1.0) * 2.0

uniform sampler2D origTex;

uniform sampler2D blurTex0;
uniform sampler2D blurTex1;
uniform sampler2D blurTex2;
uniform sampler2D blurTex3;

uniform vec3 eyePos;
uniform mat4 projectionMat;
uniform vec2 resolution;
uniform vec2 distanceLimits;
uniform vec2 mouseDepthCoord;

uniform int autofocus;
uniform float autofocusFudgeFactor;
uniform float autofocusPower;
uniform float autofocusFocalLength;
uniform int mousefocus;
uniform float manualFocusDepth;
uniform float fStop;
uniform int quality;

uniform int pass;

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
//Main blur pass paramters
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
//Blur pass parameters for objects near camera
const vec4 KernelNearBracketsRealXY_ImZW = vec4(0.034624,0.050280,-0.027250,0.190460);
const vec2 KernelNearWeights_RealX_ImY = vec2(5.268909,-0.886528);
const vec4 KernelNear_RealX_ImY_RealZ_ImW[] = vec4[](
	vec4(/*XY: Non Bracketed*/0.044566,-0.027250,/*Bracketed WZ:*/0.197749,0.000000),
	vec4(/*XY: Non Bracketed*/0.042298,-0.015499,/*Bracketed WZ:*/0.152642,0.061698),
	vec4(/*XY: Non Bracketed*/0.039368,-0.007880,/*Bracketed WZ:*/0.094353,0.101698),
	vec4(/*XY: Non Bracketed*/0.036836,-0.003243,/*Bracketed WZ:*/0.044003,0.126048),
	vec4(/*XY: Non Bracketed*/0.035189,-0.000773,/*Bracketed WZ:*/0.011253,0.139018),
	vec4(/*XY: Non Bracketed*/0.034624,-0.000000,/*Bracketed WZ:*/0.000000,0.143075),
	vec4(/*XY: Non Bracketed*/0.035189,-0.000773,/*Bracketed WZ:*/0.011253,0.139018),
	vec4(/*XY: Non Bracketed*/0.036836,-0.003243,/*Bracketed WZ:*/0.044003,0.126048),
	vec4(/*XY: Non Bracketed*/0.039368,-0.007880,/*Bracketed WZ:*/0.094353,0.101698),
	vec4(/*XY: Non Bracketed*/0.042298,-0.015499,/*Bracketed WZ:*/0.152642,0.061698),
	vec4(/*XY: Non Bracketed*/0.044566,-0.027250,/*Bracketed WZ:*/0.197749,0.000000)
);

const float baseStepValMag = 1.0/540.0;

const float colorPower = 1.9;

const float inFocusThreshold = 0.4 / float(KERNEL_RADIUS);
const float focusMixDepthRange = (float(KERNEL_RADIUS) * 2.0);
const float maxFilterRadius = 1.2; //keep between 0 and 2. Any higher than 2 will require modifying the normalization maths
								   //(currently does (radius/4)+0.5 to get [-2..2] to [0..1])

//Approximately a circle, but bulging slightly up to help with focus making sense when looking down ramps
const vec2 autofocusTestCoordOffsets[] = vec2[](
	vec2(-0.71, -0.71),
	vec2(-0.71, 0.76),
	vec2(0.71, 0.76),
	vec2(0.71, -0.71),
	vec2(-1.0, 0.0),
	vec2(0.0, 1.1),
	vec2(0.0, -1.0),
	vec2(1.0, 0.0)
);

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
vec2 get1CompFilters(int x)
{
	return KernelNear_RealX_ImY_RealZ_ImW[x].xy;
}

float LinearizeDepth(vec2 uv){
	float depthNDC = texture2D(blurTex0, uv).r;
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
	return UNNORMALIZE_FILTER(texture2D(origTex, uv).a);
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

float ApertureSizeToKeepFocusFor(float targetInFocusDepth, float focusDepth)
{
	return (targetInFocusDepth * inFocusThreshold) / abs(targetInFocusDepth - focusDepth);
}

void main()
{
	vec4 fragColor = vec4(0,0,0,0);
	vec2 uv = gl_TexCoord[0].st;
	float aspectRatio = resolution.y / resolution.x;
	vec2 stepVal = vec2(baseStepValMag * aspectRatio, baseStepValMag);

	if (pass == FILTER_SIZE_PASS)
	{

		float depth = LinearizeDepth(uv);
		float focusDepth = manualFocusDepth;
		float aperture = 1.0/fStop;

		vec2 centerUV = vec2(0.5,0.5);
		if (mousefocus == 1)
		{
			centerUV = mouseDepthCoord;
			focusDepth = LinearizeDepth(mouseDepthCoord);
		}

		if (autofocus == 1)
		{
			//The numbers in the autofocus computation that look like magic numbers are,
			//found by experimentation to work well enough in practice, but not sacred.
			float centerDepth = LinearizeDepth(centerUV);
			focusDepth = centerDepth;
			float testFocusDepth = focusDepth;

			//Find the depths to use as a safety bound for the in-focus region
			float minTestDepth = focusDepth;
			float maxTestDepth = focusDepth;
			float testDepth = 0.0;
			int autofocusTestCoordCount = 8;
			for (int i = 0; i < autofocusTestCoordCount; ++i)
			{
				testDepth = LinearizeDepth(centerUV +
					(vec2(autofocusTestCoordOffsets[i].x * aspectRatio,
						autofocusTestCoordOffsets[i].y) * clamp(focusDepth * 3.3, 0.1, 0.225)));
				//We use averages here instead of just directly min/max testing testDepth in order to have smoother focus transitions
				//across big changes to focus depth, such as the camera scrolling over a cliff or being zoomed in on a unit.
				minTestDepth = min(minTestDepth, (3.0 * minTestDepth + 2.0 * testDepth) / 5.0);
				maxTestDepth = max(maxTestDepth, (3.0 * maxTestDepth + 2.0 * testDepth) / 5.0);
			}

			//pull focus back a bit to bias slightly towards air units and against distant terrain
			float focusDepthAirFactor = clamp(0.92 + (focusDepth * 12.0), 0.92, 1.2);
			testFocusDepth /= max(focusDepthAirFactor, 1.0);
			focusDepth /= max(focusDepthAirFactor, 1.0);

			//The min depth bound is scaled more strongly to reduce air unit blurring when zoomed moderately out
			minTestDepth = min(minTestDepth / focusDepthAirFactor, focusDepth);
			maxTestDepth =
				max(focusDepthAirFactor > 1.0 ?
					(maxTestDepth + 2.5 * maxTestDepth * focusDepthAirFactor) / 3.5 :
					maxTestDepth * focusDepthAirFactor, focusDepth);

			float minFStop = 1.0;
			float curveDepth = autofocusPower;
			float baseAperture = autofocusFocalLength/max(testFocusDepth * exp(curveDepth * testFocusDepth), minFStop * autofocusFocalLength);

			float apertureBoundsFudgeFactor = 1.0 / autofocusFudgeFactor; //Used to control bounds depths without having to change inFocusThreshold
			float maxDepthAperture = ApertureSizeToKeepFocusFor(maxTestDepth, focusDepth) * apertureBoundsFudgeFactor;
			float minDepthAperture = ApertureSizeToKeepFocusFor(minTestDepth, focusDepth) * apertureBoundsFudgeFactor;

			aperture = min(baseAperture, min(maxDepthAperture, minDepthAperture));
		}

		float filterRadius = clamp(((depth - focusDepth) * aperture)/depth, -maxFilterRadius, maxFilterRadius);

		vec4 colors = texture2D(origTex, uv);
		//Add extra brightness to brighter colours in blurrier spots to maintain a consistent exposure.
		//In real life there would be a wide enough range of light levels to make bright blurry regions not
		//lose brightness when blurring, but we need to fudge that here.
		float lum = dot(colors.rgb,vec3(0.2126,0.7152,0.0722))*(min(0.2 + 0.65 * abs(filterRadius), 1.5));
		colors = colors *(1.0 + 0.2*lum*lum*lum);
		//Raise colours to a power to increase the sharpness of the blur discs
		colors = vec4(pow(colors.r, colorPower), pow(colors.g, colorPower), pow(colors.b, colorPower), colors.a);

		fragColor = vec4(colors.rgb, NORMALIZE_FILTER(filterRadius));

		gl_FragData[0] = fragColor;
		if (quality > LOW_QUALITY)
		{
			gl_FragData[1] = fragColor;
		}
	}

	else if (pass == INITIAL_BLUR_PASS)
	{
		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		float filterRadius = GetFilterRadius(uv);
		float targetFilterRadius = 0.0;
		int compI = 0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			compI = i;
			vec2 coords = GetFilterCoords(i, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius);
			if (compI < -KERNEL_RADIUS) continue;

			vec4 imageTexelRGB = texture2D(origTex, coords);
			vec4 c0_c1 = get2CompFilters(compI+KERNEL_RADIUS);
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

	else if (pass == FINAL_BLUR_PASS)
	{
		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		float filterRadius = GetFilterRadius(uv);
		float targetFilterRadius = 0.0;
		int compI = 0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			compI = i;
			vec2 coords = GetFilterCoords(i, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius);
			if (compI < -KERNEL_RADIUS) continue;
			vec4 imageTexelR = texture2D(blurTex0, coords);
			vec4 imageTexelG = texture2D(blurTex1, coords);
			vec4 imageTexelB = texture2D(blurTex2, coords);

			vec4 c0_c1 = get2CompFilters(compI+KERNEL_RADIUS);


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

		fragColor = vec4(vec3(pow(redChannel, 1.0/colorPower),pow(greenChannel, 1.0/colorPower),
			pow(blueChannel, 1.0/colorPower)), NORMALIZE_FILTER(filterRadius));
		gl_FragData[0] = fragColor;
	}

	else if (pass == INITIAL_NEAR_BLUR_PASS)
	{
		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		vec4 valA = vec4(0,0,0,0);
		//Start by finding the maximum possible relevant blur radius, since we're blurring things
		//that will end up in front of more in-focus objects.
		float baseFilterRadius = GetFilterRadius(uv);
		float filterRadius = min(baseFilterRadius, GetEdgeNearFilterRadius(uv, stepVal));
		filterRadius = min(filterRadius, GetEdgeNearFilterRadius(uv, vec2(stepVal.y, 0.0)));
		float targetFilterRadius = 0.0;
		int compI = 0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			compI = i;
			vec2 coords = GetFilterCoords(i, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius);
			if (compI < -KERNEL_RADIUS) continue;

			vec4 imageTexelRGB = texture2D(origTex, coords);
			float alpha = FocusThresholdMixFactor(-targetFilterRadius, inFocusThreshold);
			alpha = min(alpha, clamp(abs(targetFilterRadius - baseFilterRadius) / 0.05, 0.0, 1.0));

			// vec2 c0 = get1CompFilters(compI+KERNEL_RADIUS);
			// valRG.xy += imageTexelRGB.r * c0;
			// valRG.zw += imageTexelRGB.g * c0;
			// valBA.xy += imageTexelRGB.b * c0;
			// valBA.zw += alpha * c0;

			vec4 c0_c1 = get2CompFilters(compI+KERNEL_RADIUS);
			valR.xy += imageTexelRGB.r * c0_c1.xy;
			valR.zw += imageTexelRGB.r * c0_c1.zw;
			valG.xy += imageTexelRGB.g * c0_c1.xy;
			valG.zw += imageTexelRGB.g * c0_c1.zw;
			valB.xy += imageTexelRGB.b * c0_c1.xy;
			valB.zw += imageTexelRGB.b * c0_c1.zw;
			valA.xy += alpha * c0_c1.xy;
			valA.zw += alpha * c0_c1.zw;
		}
		// gl_FragData[0] = valRG;
		// gl_FragData[1] = valBA;

		gl_FragData[0] = valR;
		gl_FragData[1] = valG;
		gl_FragData[2] = valB;
		gl_FragData[3] = valA;

	}

	else if (pass == FINAL_NEAR_BLUR_PASS)
	{
		vec4 valR = vec4(0,0,0,0);
		vec4 valG = vec4(0,0,0,0);
		vec4 valB = vec4(0,0,0,0);
		vec4 valA = vec4(0,0,0,0);
		float baseFilterRadius = GetFilterRadius(uv);
		float filterRadius = min(GetFilterRadius(uv), GetEdgeNearFilterRadius(uv, stepVal));
		filterRadius = min(filterRadius, GetEdgeNearFilterRadius(uv, vec2(stepVal.x, 0.0)));
		float targetFilterRadius = 0.0;
		int compI = 0;
		for (int i=-KERNEL_RADIUS; i <=KERNEL_RADIUS; ++i)
		{
			compI = i;
			vec2 coords = GetFilterCoords(i, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius);
			if (compI < -KERNEL_RADIUS) continue;

			//imageTexelBA/imageTexelA has the alpha from the initial pass, but we need to also get it for the
			//final pass separately since alpha represents the edge of different filter radii, and
			//that's not something a single pass of a 2-pass blur will fully pick up.
			float finalPassAlpha = FocusThresholdMixFactor(-targetFilterRadius, inFocusThreshold);
			finalPassAlpha = min(finalPassAlpha, clamp(abs(targetFilterRadius - baseFilterRadius) / 0.05, 0.0, 1.0));

			// vec4 imageTexelRG = texture2D(blurTex0, coords);
			// vec4 imageTexelBA = texture2D(blurTex1, coords);

			// vec2 c0 = get1CompFilters(compI+KERNEL_RADIUS);

			// valR.xy += multComplex(imageTexelRG.xy,c0);
			// valG.xy += multComplex(imageTexelRG.zw,c0);
			// valB.xy += multComplex(imageTexelBA.xy,c0);
			// valA.xy += multComplex(imageTexelBA.zw,c0);
			// valA.xy += finalPassAlpha * c0;

			vec4 imageTexelR = texture2D(blurTex0, coords);
			vec4 imageTexelG = texture2D(blurTex1, coords);
			vec4 imageTexelB = texture2D(blurTex2, coords);
			vec4 imageTexelA = texture2D(blurTex3, coords);

			vec4 c0_c1 = get2CompFilters(compI+KERNEL_RADIUS);

			valR.xy += multComplex(imageTexelR.xy,c0_c1.xy);
			valR.zw += multComplex(imageTexelR.zw,c0_c1.zw);

			valG.xy += multComplex(imageTexelG.xy,c0_c1.xy);
			valG.zw += multComplex(imageTexelG.zw,c0_c1.zw);

			valB.xy += multComplex(imageTexelB.xy,c0_c1.xy);
			valB.zw += multComplex(imageTexelB.zw,c0_c1.zw);

			valA.xy += multComplex(imageTexelA.xy,c0_c1.xy);
			valA.zw += multComplex(imageTexelA.zw,c0_c1.zw);
			valA.xy += finalPassAlpha * c0_c1.xy;
			valA.zw += finalPassAlpha * c0_c1.zw;
		}
		// float redChannel	 = dot(valR.xy,KernelNearWeights_RealX_ImY);
		// float greenChannel = dot(valG.xy,KernelNearWeights_RealX_ImY);
		// float blueChannel	= dot(valB.xy,KernelNearWeights_RealX_ImY);
		// float alphaChannel	= dot(valA.xy, KernelNearWeights_RealX_ImY);

		float redChannel	 = dot(valR.xy,Kernel0Weights_RealX_ImY)+dot(valR.zw,Kernel1Weights_RealX_ImY);
		float greenChannel = dot(valG.xy,Kernel0Weights_RealX_ImY)+dot(valG.zw,Kernel1Weights_RealX_ImY);
		float blueChannel	= dot(valB.xy,Kernel0Weights_RealX_ImY)+dot(valB.zw,Kernel1Weights_RealX_ImY);
		float alphaChannel	= dot(valA.xy,Kernel0Weights_RealX_ImY)+dot(valA.zw,Kernel1Weights_RealX_ImY);

		fragColor = vec4(pow(redChannel, 1.0/colorPower),pow(greenChannel, 1.0/colorPower),
			pow(blueChannel, 1.0/colorPower), clamp(alphaChannel, 0.0, 1.0));
		gl_FragData[0] = fragColor;
	}

	else if (pass == COMPOSITION_PASS)
	{
		vec4 blurTexAtUV = texture2D(blurTex0, uv);
		vec4 origTexAtUV = texture2D(origTex, uv);
		float filterRadius = UNNORMALIZE_FILTER(blurTexAtUV.a);
		float mixFactor = FocusThresholdMixFactor(abs(filterRadius), inFocusThreshold);
		fragColor = origTexAtUV;

		// if (quality >= HIGH_QUALITY)
		// {
		//	 float mixFactor = FocusThresholdMixFactor(abs(filterRadius), inFocusThreshold * 2.5); //Need to blur later since full screen blurring helps transition
		//	 if (abs(filterRadius) > inFocusThreshold)
		//	 {
		//		 float targetFilterRadius = 0.0;
		//		 fragColor += texture2D(origTex, GetFilterCoords(KERNEL_RADIUS, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(-KERNEL_RADIUS, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(KERNEL_RADIUS, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(-KERNEL_RADIUS, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(KERNEL_RADIUS / 2, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(-KERNEL_RADIUS / 2, uv, vec2(stepVal.x, 0.0), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(KERNEL_RADIUS / 2, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius))
		//		 + texture2D(origTex, GetFilterCoords(-KERNEL_RADIUS / 2, uv, vec2(0.0, stepVal.y), filterRadius, targetFilterRadius));
		//		 fragColor /= 9.0;
		//	 }
		// }

		fragColor = mix(fragColor, blurTexAtUV, mixFactor);

		if (quality > LOW_QUALITY)
		{
			vec4 nearBlurTexAtUV = texture2D(blurTex1, uv);
			float alpha = clamp(nearBlurTexAtUV.a * 1.5, 0.0, 1.0);
			fragColor.rgb = mix(fragColor.rgb, nearBlurTexAtUV.rgb, alpha);
			// fragColor = vec4(alpha);
		}

		gl_FragData[0] = fragColor;
	}

}
