// Drawn with gl.TexRect; the filter pass also computes the per-frame focus here instead of per fragment

#if (PASS == FILTER_SIZE_PASS)
uniform sampler2D blurTex0; // depth copy

uniform mat4 projectionMat;
uniform vec2 resolution;
uniform vec2 mouseDepthCoord;

uniform int autofocus;
uniform float autofocusFudgeFactor;
uniform float autofocusPower;
uniform float autofocusFocalLength;
uniform int mousefocus;
uniform float manualFocusDepth;
uniform float fStop;

flat out float focusDepthV;
flat out float apertureV;

const int KERNEL_RADIUS = 5;
const float inFocusThreshold = 0.4 / float(KERNEL_RADIUS);

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

float LinearizeDepth(vec2 uv){
	float depthNDC = textureLod(blurTex0, uv, 0.0).r;
	#if (DEPTH_CLIP01 == 0)
		depthNDC = NORM2SNORM(depthNDC);
	#endif
	return -(projectionMat[3][2] / (projectionMat[2][2] + depthNDC)) / BLUR_START_DIST;
}

float ApertureSizeToKeepFocusFor(float targetInFocusDepth, float focusDepth)
{
	return (targetInFocusDepth * inFocusThreshold) / abs(targetInFocusDepth - focusDepth);
}
#endif

void main()
{
	#if (PASS == FINAL_BLUR_PASS || PASS == FINAL_NEAR_BLUR_PASS)
		gl_Position = gl_Vertex; // drawn in clip space
	#else
		gl_Position = ftransform();
	#endif
	gl_TexCoord[0] = gl_MultiTexCoord0;

	#if (PASS == FILTER_SIZE_PASS)
		float aspectRatio = resolution.y / resolution.x;
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

		focusDepthV = focusDepth;
		apertureV = aperture;
	#endif
}
