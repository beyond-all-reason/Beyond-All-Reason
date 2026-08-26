#version 420
#line 30000

// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Beherith (mysterme@gmail.com)
// This shader is part of the Beyond All Reason repository.

// Fullscreen pass vertex shader shared by the radar preview's coverage and smoothing passes.
// Draw with a clip-space rect (InstanceVBOTable.MakeTexRectVAO), no matrices involved.

//__DEFINES__

layout (location = 0) in vec4 pos; // xy = clip space position, zw = uv (unused)

uniform vec4 passRect = vec4(-1.0, -1.0, 1.0, 1.0); // clip-space rectangle the quad is drawn into (whole target by default)

void main() {
	gl_Position = vec4(mix(passRect.xy, passRect.zw, pos.xy * 0.5 + 0.5), 0.0, 1.0);
}
