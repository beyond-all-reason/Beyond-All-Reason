#version 150 compatibility

//__DEFINES__

out vec2 v_uv;

void main(void)	{
    v_uv = gl_Vertex.zw;
    gl_Position    = vec4(gl_Vertex.xy * 1.0, 0.00, 1);	
}
