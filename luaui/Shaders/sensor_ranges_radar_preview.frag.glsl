#version 420
#line 20000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview cube pass, fragment stage: per-face shading and zoom-independent edge lines.

//__DEFINES__

in DataVS {
	vec3 localPos; // position on the unit cube
	vec4 fx;       // coverage, glow, beam, spawn
};

// Occlusion is tested against the deferred g-buffer depths instead of the regular depth buffer, so
// terrain (and units) hide the cubes but things drawn into the depth buffer by widgets, like grass, don't.
#if TERRAIN_DEPTH_TEST
uniform sampler2D mapDepths; // $map_gbuffer_zvaltex
#endif
#if MODEL_DEPTH_TEST
uniform sampler2D modelDepths; // $model_gbuffer_zvaltex
#endif

//__ENGINEUNIFORMBUFFERDEFS__

#line 21000

out vec4 fragColor;

const vec3 baseColor = BASE_COLOR;
const vec3 highlightColor = HIGHLIGHT_COLOR;
const float baseAlpha = float(BASE_ALPHA);
const float lineAlpha = float(LINE_ALPHA);
const float depthBias = 1e-6; // window-space depth tolerance (a few elmo far away, sub-elmo up close)

void main() {
#if TERRAIN_DEPTH_TEST
	vec2 screenUV = (gl_FragCoord.xy - viewGeometry.zw) / viewGeometry.xy;
	float sceneDepth = texture(mapDepths, screenUV).x;
	#if MODEL_DEPTH_TEST
	sceneDepth = min(sceneDepth, texture(modelDepths, screenUV).x);
	#endif
	if (gl_FragCoord.z > sceneDepth + depthBias) {
		discard;
	}
#endif

	// which face are we on? the largest |coordinate| of the centered cube decides
	vec3 centered = vec3(localPos.x, localPos.y - 0.5, localPos.z);
	vec3 a = abs(centered);
	vec3 normal;
	vec2 facePos;
	if (a.y >= a.x && a.y >= a.z) {
		normal = vec3(0.0, sign(centered.y), 0.0);
		facePos = centered.xz;
	} else if (a.x >= a.z) {
		normal = vec3(sign(centered.x), 0.0, 0.0);
		facePos = centered.yz;
	} else {
		normal = vec3(0.0, 0.0, sign(centered.z));
		facePos = centered.xy;
	}

	// lit top, sides shaded by the map's sun direction
	vec2 sunXZ = normalize(sunDir.xz + vec2(1e-4, 0.0));
	float shade = (normal.y > 0.5) ? 1.0 : 0.5 + 0.3 * (0.5 + 0.5 * dot(normal.xz, sunXZ));

	// ~1 px anti-aliased edge lines regardless of zoom level; LINE_ALPHA <= 0 disables them entirely
	float line = 0.0;
	if (lineAlpha > 0.0) {
		float edgeDist = min(0.5 - abs(facePos.x), 0.5 - abs(facePos.y));
		float lineWidth = fwidth(edgeDist) * 1.2 + 0.01;
		line = 1.0 - smoothstep(0.0, lineWidth, edgeDist);
	}

	float coverage = fx.x;
	float glow = min(fx.y, 1.0);
	float beam = fx.z;
	float spawn = fx.w;

	vec3 color = mix(baseColor * shade, highlightColor, glow * 0.55);
	color = mix(color, highlightColor, line * 0.6);
	color += highlightColor * beam * 0.25;

	float alpha = (baseAlpha + 0.3 * glow) * (0.8 + 0.2 * coverage);
	alpha = max(alpha, line * lineAlpha);
	fragColor = vec4(color, alpha * spawn);
}
