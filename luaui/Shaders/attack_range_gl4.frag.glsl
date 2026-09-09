#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.  

//_DEFINES__

#line 20000

uniform float selUnitCount = 1.0;
uniform float selBuilderCount = 1.0;
uniform float drawAlpha = 1.0;
uniform float drawMode = 0.0;

//_ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	flat vec4 blendedcolor;
	vec4 circleprogress;
	float groupselectionfadescale;
	float weaponType;
};

out vec4 fragColor;

void main() {
	// -- we need to mod alpha based on groupselectionfadescale and weaponType
	// -- innerRingDim = group_selection_fade_scale * 0.1 * numUnitsSelected
	float numUnitsSelected = selUnitCount;

	// -- nano is 2
	if(weaponType == 2.0) {
		numUnitsSelected = selBuilderCount;
	}
	numUnitsSelected = clamp(numUnitsSelected, 1, 25);

	float innerRingDim = groupselectionfadescale * 0.1 * numUnitsSelected;
	float finalAlpha = drawAlpha;
	if(drawMode == 2.0) {
		finalAlpha = drawAlpha / pow(innerRingDim, 2);
	}
	finalAlpha = clamp(finalAlpha, 0.0, 1.0);

	fragColor = vec4(blendedcolor.x, blendedcolor.y, blendedcolor.z, blendedcolor.w * finalAlpha);
	//fragColor = mix(vec4(1,0,0,1), vec4(0,1,0,1), circleprogress.w);
}