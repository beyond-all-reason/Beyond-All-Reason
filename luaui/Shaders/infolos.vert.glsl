#version 430

//__DEFINES__

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position; // [-1,1], [0,1] , xyuv

out DataVS {
    vec4 texCoord;
};

void main(void)	{
    texCoord = position.zwzw;
    gl_Position    = vec4(position.xy * 1.0, 0.00, 1);	
}