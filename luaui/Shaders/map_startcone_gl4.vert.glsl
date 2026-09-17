//map_startcone_gl4.vert.glsl

#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com), licensed under the MIT license

#line 5000
layout (location = 0) in vec4 position; // xyz and etc garbage
//layout locations 1 and 2 contain primitive specific garbage and should not be used
layout (location = 3) in vec4 worldposrad; // l w rot and maxalpha
layout (location = 4) in vec4 teamcolor;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float isMinimap = 0;
uniform int rotationMiniMap = 0;
uniform float startPosScale = 0.0005;
uniform vec4 pipVisibleArea = vec4(0, 1, 0, 1); // left, right, bottom, top in normalized [0,1] coords for PIP minimap

out DataVS {
	vec4 v_worldposrad;
	vec4 v_teamcolor;
};


#line 11000
void main()
{
	v_teamcolor = teamcolor;
	vec4 worldPos = vec4(position.xyz, 1.0);
	
	if (isMinimap < 0.5) { // world
		worldPos.xyz = worldPos.xyz + worldposrad.xyz;
		v_worldposrad = vec4(worldPos.xyz, worldposrad.w);
		gl_Position = cameraViewProj * worldPos;
	}else{
		// Calculate cone offset in screen space
		vec2 coneOffset = position.xz * startPosScale;
		coneOffset.y *= mapSize.x/mapSize.y;

		// Get world position of the start point in normalized coords [0,1]
		vec2 normPos = worldposrad.xz / mapSize.xy;
		
		// Convert to NDC first (standard minimap transform)
		vec2 ndcxy = normPos * 2.0 - 1.0;
		
		// Apply rotation
		if (rotationMiniMap == 0) {
			ndcxy.y *= -1;
		}else if (rotationMiniMap == 1) {
			ndcxy.xy = ndcxy.yx;
		}else if (rotationMiniMap == 2) {
			ndcxy.x *= -1;
		}else if (rotationMiniMap == 3) {
			ndcxy.xy = -ndcxy.yx;
		}
		
		// Check if PIP mode (visible area not default)
		bool isPip = (pipVisibleArea.x != 0.0 || pipVisibleArea.y != 1.0 || pipVisibleArea.z != 0.0 || pipVisibleArea.w != 1.0);
		
		// For PIP: transform from world-normalized to visible area screen coords AFTER rotation
		if (isPip) {
			// Convert NDC back to [0,1] for transform
			vec2 screenPos = ndcxy * 0.5 + 0.5;
			// Map from world [0,1] to screen position based on visible area
			// World position normPos.x in [visL, visR] -> screen [0,1]
			screenPos.x = (normPos.x - pipVisibleArea.x) / (pipVisibleArea.y - pipVisibleArea.x);
			// Flip Y: world Z in [visB, visT] -> screen Y flipped
			screenPos.y = 1.0 - (normPos.y - pipVisibleArea.z) / (pipVisibleArea.w - pipVisibleArea.z);
			// Apply rotation to screen position
			if (rotationMiniMap == 0) {
				screenPos.y = 1.0 - screenPos.y;
			}else if (rotationMiniMap == 1) {
				screenPos.xy = screenPos.yx;
			}else if (rotationMiniMap == 2) {
				screenPos.x = 1.0 - screenPos.x;
			}else if (rotationMiniMap == 3) {
				screenPos.xy = vec2(1.0) - screenPos.yx;
			}
			ndcxy = screenPos * 2.0 - 1.0;
			// Scale cone offset for zoom level
			float zoomFactor = 1.0 / max(pipVisibleArea.y - pipVisibleArea.x, 0.001);
			coneOffset *= zoomFactor;
		}
		
		// Add cone offset
		ndcxy += coneOffset;
		
		gl_Position = vec4(ndcxy, 0.0, 1.0);
	}
}