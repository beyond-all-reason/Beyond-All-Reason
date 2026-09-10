#version 420
#line 34000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Radar preview minimap pass: a quad over the whole minimap (DrawInMiniMap), the fragment shader
// maps every minimap pixel to its radar cell. Written straight to clip space like the other GL4
// minimap overlays (buildsquare, start polygons); the PIP minimap remaps the viewport for those.

//__DEFINES__

layout (location = 0) in vec4 pos; // xy = clip space position, zw = uv (unused)

out vec2 minimapUV; // 0..1 across the minimap, y up

void main() {
	gl_Position = vec4(pos.xy, 0.0, 1.0);
	minimapUV = pos.xy * 0.5 + 0.5;
	// The engine enables four user clip planes around the Lua minimap draw (CMiniMap::SetClipPlanes), set up
	// for its fixed-function matrices. A custom vertex shader that leaves them alone gets clipped against
	// gl_Position instead, which cuts the quad down to one quadrant, so declare every vertex inside.
	gl_ClipDistance[0] = 1.0;
	gl_ClipDistance[1] = 1.0;
	gl_ClipDistance[2] = 1.0;
	gl_ClipDistance[3] = 1.0;
}
