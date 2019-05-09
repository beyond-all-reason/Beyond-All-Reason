#version 150 compatibility

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

vec3 hash31(float p) {
	uint n = uint(p);

	n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 789221U) + 1376312589U;
    uvec3 k = n * uvec3(n, n * 16807U, n * 48271U);
    return vec3( k & uvec3(0x7FFFFFFFU) ) / float(0x7FFFFFFF);
}

//----------------------------------------------------------------------------------------

#define SSAO_KERNEL_SIZE ###SSAO_KERNEL_SIZE###

//----------------------------------------------------------------------------------------

flat out vec3 samplingKernel[SSAO_KERNEL_SIZE];

void main() {
	gl_Position = gl_Vertex;
	
	for (int i = 0; i < SSAO_KERNEL_SIZE; i++) {
		vec3 tmp = hash31( float(i) );
		tmp.xy = NORM2SNORM(tmp.xy);
		tmp = normalize(tmp);
		float scale = float(i)/float(SSAO_KERNEL_SIZE);
		scale = clamp(scale * scale, 0.1, 1.0);
		tmp *= scale;
		samplingKernel[i] = tmp;
	}
}