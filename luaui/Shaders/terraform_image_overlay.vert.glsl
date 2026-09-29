#version 430

//__DEFINES__

//__ENGINEUNIFORMBUFFERDEFS__

// Fullscreen tex-rect from InstanceVBOTable.MakeTexRectVAO():
// xy in [-1,1] (NDC), zw in [0,1] (screen UV).
layout (location = 0) in vec4 position;

out DataVS {
	vec2 screenUV;
};

void main(void) {
	screenUV = position.zw;
	gl_Position = vec4(position.xy, 0.0, 1.0);
}
