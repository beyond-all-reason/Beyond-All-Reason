#version 430

layout (location = 0) in vec4 position; // [-1,1], [0,1] , xyuv

out DataVS {
    vec4 texCoord;
};

void main(void) {
    texCoord = position.zwzw;
    gl_Position = vec4(position.xy, 0.0, 1.0);
}
