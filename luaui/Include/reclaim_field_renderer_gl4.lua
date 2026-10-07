-- GL4 renderer for the reclaim field highlight (gui_reclaim_field_highlight.lua).
--
-- Every field hull lives in a chunked VBO: a chunk holds POINTS_PER_CHUNK hull points as gradient
-- triangles (fan to an inner ring plus the inner->outer ramp) in one buffer and as outline lines in
-- another. Per-chunk parameters (centre, pulse scale, alpha, resource type, fade bypass) sit in an
-- SSBO indexed by gl_VertexID / vertsPerChunk, and the vertex shader applies the camera distance
-- fade. Drawing all fields is two draw calls; CPU work happens only when a hull or an animation
-- changes. Hull tables are the keys: a hull reused across reclusters, or kept alive by a fading
-- field, keeps its chunks. Freed chunks get alpha 0 and are overwritten by the next allocation.

local LuaShader = gl.LuaShader

local POINTS_PER_CHUNK = 32 ---@type integer
local GRAD_VERTS = 9 * POINTS_PER_CHUNK ---@type integer per point: 3 fan + 6 ramp vertices
local EDGE_VERTS = 2 * POINTS_PER_CHUNK ---@type integer per point: one line segment
local PARAM_VEC4S = 2 ---@type integer per chunk: (cx, cy, cz, scale), (alpha, type, bypass, 0)
local SSBO_BINDING = 9 -- 0, 1, 4, 5, 6 are taken by other BAR shaders
local INITIAL_CHUNKS = 256 -- 32 points each; growth copies the buffers on the GPU but still costs a frame
local UPLOADS_PER_SYNC = 16 -- geometry uploads per sync pass; the rest waits for the next frame

local KIND_FILL, KIND_GRADIENT, KIND_EDGE = 0, 1, 2

local R = {}

---@class ReclaimFieldSpan
---@field start integer first chunk
---@field count integer chunks
---@field points integer hull points uploaded
---@field cx number
---@field cy number
---@field cz number
---@field uid number|nil
---@field isEnergy boolean
---@field alpha number
---@field scale number
---@field bypass number 0 or 1
---@field mark integer
---@field hull table the hull table currently keyed to this span
---@field hash number content hash of the hull
---@field v1x number first hull point, for verifying a hash match
---@field v1z number
---@field vnx number last hull point
---@field vnz number

---@type LuaShader?
local shader
---@type VBO?
local gradVBO
---@type VBO?
local edgeVBO
---@type VBO?
local paramSSBO
---@type VAO?
local gradVAO
---@type VAO?
local edgeVAO
local capacity = 0 -- chunks
local highWater = 0 -- chunks in use (highest allocated end)
local freeStart = {} ---@type integer[] free spans sorted by start
local freeCount = {} ---@type integer[]
local spans = {} ---@type table<table, ReclaimFieldSpan?> keyed by hull table
local spansByUid = {} ---@type table<number, ReclaimFieldSpan?>
-- content hash -> span: a recluster hands out new hull tables for unchanged fields; a new table whose
-- geometry matches a span that is not live any more adopts it instead of re-uploading
local spansByHash = {} ---@type table<number, ReclaimFieldSpan?>
local innerRadius = 0.75
local gradScratch, edgeScratch, paramScratch = {}, {}, {}
local zeroParams = {}
local liveMark = 0
-- counters for the debug output: geometry uploads, spans adopted by a new hull table, adoption
-- candidates whose geometry did not verify
local statUploads, statAdopted, statVerifyFailed = 0, 0, 0
local syncUploads = 0 -- geometry uploads in the current sync pass
local syncDeferred = false -- a field was skipped because the pass hit UPLOADS_PER_SYNC

local shaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/reclaim_field_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/reclaim_field_gl4.frag.glsl",
	uniformInt = {
		vertsPerChunk = GRAD_VERTS,
	},
	uniformFloat = {
		toggles = { 0, 0 },
		yOffset = 0,
		fadeDist = { 4500, 7000 },
		fillColorMetal = { 0, 0, 0, 0.055 },
		fillColorEnergy = { 0.8, 0.8, 0, 0.055 },
		edgeColorMetal = { 1, 1, 1, 0.18 },
		edgeColorEnergy = { 1, 0.9, 0, 0.18 },
		gradientAlpha = 0.13,
		energyOpacity = 0.44,
	},
	shaderName = "Reclaim Field GL4",
	shaderConfig = {
		SSBO_BINDING = SSBO_BINDING,
	},
}

local function deleteBuffers()
	if gradVBO then
		gradVBO:Delete()
	end
	if edgeVBO then
		edgeVBO:Delete()
	end
	if paramSSBO then
		paramSSBO:Delete()
	end
	if gradVAO then
		gradVAO:Delete()
	end
	if edgeVAO then
		edgeVAO:Delete()
	end
	gradVBO, edgeVBO, paramSSBO, gradVAO, edgeVAO = nil, nil, nil, nil, nil
end

-- uploads are rare (hull or animation changes), so the buffers take the static usage hint
---@return VBO? gradient, VBO? edge, VBO? params, VAO? gradientVAO, VAO? edgeVAO
local function createBuffers(chunks)
	local g = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local e = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local p = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
	local gv, ev = gl.GetVAO(), gl.GetVAO()
	if not g or not e or not p or not gv or not ev then
		return nil
	end
	g:Define(chunks * GRAD_VERTS, { { id = 0, name = "posKind", size = 4 } })
	e:Define(chunks * EDGE_VERTS, { { id = 0, name = "posKind", size = 4 } })
	p:Define(chunks * PARAM_VEC4S, { { id = 0, name = "params", size = 1 } })
	gv:AttachVertexBuffer(g)
	ev:AttachVertexBuffer(e)
	return g, e, p, gv, ev
end

-- Chunk allocator: first fit over a sorted free list, neighbours coalesced on release.
---@param count integer
---@return integer? start
local function allocChunks(count)
	for i = 1, #freeStart do
		local avail = freeCount[i] or 0
		if avail >= count then
			local start = freeStart[i] or 0
			if avail == count then
				table.remove(freeStart, i)
				table.remove(freeCount, i)
			else
				freeStart[i] = start + count
				freeCount[i] = avail - count
			end
			if start + count > highWater then
				highWater = start + count
			end
			return start
		end
	end
	return nil
end

---@param start integer
---@param count integer
local function freeChunks(start, count)
	local n = #freeStart
	local i = 1
	while i <= n and (freeStart[i] or 0) < start do
		i = i + 1
	end
	table.insert(freeStart, i, start)
	table.insert(freeCount, i, count)
	-- coalesce with the next, then with the previous span
	local nextStart, nextCount = freeStart[i + 1], freeCount[i + 1]
	if nextStart and nextCount and start + count == nextStart then
		count = count + nextCount
		freeCount[i] = count
		table.remove(freeStart, i + 1)
		table.remove(freeCount, i + 1)
	end
	local prevStart, prevCount = freeStart[i - 1], freeCount[i - 1]
	if prevStart and prevCount and prevStart + prevCount == start then
		start = prevStart
		count = count + prevCount
		freeCount[i - 1] = count
		table.remove(freeStart, i)
		table.remove(freeCount, i)
	end
	if start + count >= highWater then
		highWater = start
	end
end

---@param i integer
---@return integer
local function put(t, i, x, y, z, k)
	t[i + 1] = x
	t[i + 2] = y
	t[i + 3] = z
	t[i + 4] = k
	return i + 4
end

-- cheap content signature of a hull: point count, centre and the coordinate sums (heights included,
-- so terrain deformation produces a different hull)
local function hullHash(hull, n, center)
	local sx, sy, sz = 0, 0, 0
	for j = 1, n do
		local p = hull[j]
		sx = sx + p.x
		sy = sy + p.y
		sz = sz + p.z
	end
	return n * 1e9 + math.floor(sx * 4 + sz * 0.25 + sy * 16) + math.floor(center.x) * 0.001
end

local function sameGeometry(span, hull, n, center)
	local p1, pn = hull[1], hull[n]
	return span.points == n
		and span.cx == center.x
		and span.cy == center.y
		and span.cz == center.z
		and span.v1x == p1.x
		and span.v1z == p1.z
		and span.vnx == pn.x
		and span.vnz == pn.z
end

local function uploadGeometry(span, hull)
	if not gradVBO or not edgeVBO then
		return
	end
	statUploads = statUploads + 1
	local n = #hull
	local cx, cy, cz = span.cx, span.cy, span.cz
	local g, e = gradScratch, edgeScratch
	local gi, ei = 0, 0
	local ir = innerRadius
	for j = 1, n do
		local o = hull[j]
		local o2 = hull[j % n + 1]
		local ox, oy, oz = o.x, o.y, o.z
		local o2x, o2y, o2z = o2.x, o2.y, o2.z
		local ix, iy, iz = cx + (ox - cx) * ir, oy, cz + (oz - cz) * ir
		local i2x, i2y, i2z = cx + (o2x - cx) * ir, o2y, cz + (o2z - cz) * ir
		-- inner disc
		gi = put(g, gi, cx, cy, cz, KIND_FILL)
		gi = put(g, gi, ix, iy, iz, KIND_FILL)
		gi = put(g, gi, i2x, i2y, i2z, KIND_FILL)
		-- ramp ring, two triangles per segment
		gi = put(g, gi, ix, iy, iz, KIND_FILL)
		gi = put(g, gi, ox, oy, oz, KIND_GRADIENT)
		gi = put(g, gi, i2x, i2y, i2z, KIND_FILL)
		gi = put(g, gi, i2x, i2y, i2z, KIND_FILL)
		gi = put(g, gi, ox, oy, oz, KIND_GRADIENT)
		gi = put(g, gi, o2x, o2y, o2z, KIND_GRADIENT)
		-- outline
		ei = put(e, ei, ox, oy, oz, KIND_EDGE)
		ei = put(e, ei, o2x, o2y, o2z, KIND_EDGE)
	end
	-- pad the span with zero-area geometry at the centre
	for _ = n + 1, span.count * POINTS_PER_CHUNK do
		for _ = 1, 9 do
			gi = put(g, gi, cx, cy, cz, KIND_FILL)
		end
		ei = put(e, ei, cx, cy, cz, KIND_EDGE)
		ei = put(e, ei, cx, cy, cz, KIND_EDGE)
	end
	gradVBO:Upload(g, -1, math.floor(span.start * GRAD_VERTS), 1, gi)
	edgeVBO:Upload(e, -1, math.floor(span.start * EDGE_VERTS), 1, ei)
end

local function uploadParams(span)
	if not paramSSBO then
		return
	end
	local p = paramScratch
	local i = 0
	local cx, cy, cz, scale = span.cx, span.cy, span.cz, span.scale
	local alpha, typ, bypass = span.alpha, span.isEnergy and 1 or 0, span.bypass
	for _ = 1, span.count do
		p[i + 1], p[i + 2], p[i + 3], p[i + 4] = cx, cy, cz, scale
		p[i + 5], p[i + 6], p[i + 7], p[i + 8] = alpha, typ, bypass, 0
		i = i + 8
	end
	paramSSBO:Upload(p, -1, math.floor(span.start * PARAM_VEC4S), 1, i)
end

local function clearParams(start, count)
	if not paramSSBO then
		return
	end
	local n = math.floor(count * PARAM_VEC4S * 4)
	for i = #zeroParams + 1, n do
		zeroParams[i] = 0
	end
	paramSSBO:Upload(zeroParams, -1, math.floor(start * PARAM_VEC4S), 1, n)
end

local function releaseSpan(hull, span)
	spans[hull] = nil
	if span.uid and spansByUid[span.uid] == span then
		spansByUid[span.uid] = nil
	end
	if spansByHash[span.hash] == span then
		spansByHash[span.hash] = nil
	end
	clearParams(span.start, span.count)
	freeChunks(span.start, span.count)
end

-- grow the buffers so that minChunks fit; the old contents are copied on the GPU. Returns the old
-- capacity, or nil when the buffers could not be created.
local function grow(minChunks)
	local oldCap = capacity
	local newCap = math.max(capacity * 2, INITIAL_CHUNKS)
	while newCap < minChunks do
		newCap = newCap * 2
	end
	local g, e, p, gv, ev = createBuffers(newCap)
	if not g or not e or not p then
		return nil
	end
	local oldGrad, oldEdge, oldParams = gradVBO, edgeVBO, paramSSBO
	if oldGrad and oldEdge and oldParams then
		oldGrad:CopyTo(g, oldCap * GRAD_VERTS * 16)
		oldEdge:CopyTo(e, oldCap * EDGE_VERTS * 16)
		oldParams:CopyTo(p, oldCap * PARAM_VEC4S * 16)
	end
	deleteBuffers()
	gradVBO, edgeVBO, paramSSBO, gradVAO, edgeVAO = g, e, p, gv, ev
	capacity = newCap
	clearParams(oldCap, newCap - oldCap) -- the new tail starts invisible
	return oldCap
end

--------------------------------------------------------------------------------

---Create the shader and buffers. Returns false and a reason when GL4 is not usable.
---@param cfg table innerRadius, fadeStart, fadeEnd, fillColorMetal, fillColorEnergy, edgeColorMetal, edgeColorEnergy, gradientAlpha, energyOpacity
---@return boolean ok
---@return string? reason
function R.Init(cfg)
	innerRadius = cfg.innerRadius or innerRadius
	local uf = shaderSourceCache.uniformFloat
	uf.fadeDist = { cfg.fadeStart, cfg.fadeEnd }
	uf.fillColorMetal = cfg.fillColorMetal
	uf.fillColorEnergy = cfg.fillColorEnergy
	uf.edgeColorMetal = cfg.edgeColorMetal
	uf.edgeColorEnergy = cfg.edgeColorEnergy
	uf.gradientAlpha = cfg.gradientAlpha
	uf.energyOpacity = cfg.energyOpacity
	if not LuaShader then
		return false, "LuaShader missing"
	end
	shader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not shader then
		return false, "shader failed to compile"
	end
	spans, spansByUid, spansByHash, freeStart, freeCount = {}, {}, {}, {}, {}
	capacity, highWater = 0, 0
	gradVBO, edgeVBO, paramSSBO, gradVAO, edgeVAO = createBuffers(INITIAL_CHUNKS)
	if not gradVBO then
		return false, "buffers could not be created"
	end
	capacity = INITIAL_CHUNKS
	clearParams(0, capacity)
	freeStart[1], freeCount[1] = 0, capacity
	return true
end

function R.Shutdown()
	deleteBuffers()
	if shader then
		shader:Finalize()
		shader = nil
	end
	spans, spansByUid, spansByHash, freeStart, freeCount = {}, {}, {}, {}, {}
	capacity, highWater = 0, 0
end

---Start a sync pass: hulls not touched before EndSync() are released.
function R.BeginSync()
	liveMark = liveMark + 1
	syncUploads = 0
	syncDeferred = false
end

---Register (or refresh) one field. Uploads geometry for a hull not seen before and parameters
---whenever they changed.
---@param hull table hull points {x,y,z}; the table identity is the key
---@param center table {x,y,z}
---@param uid number|nil animation identity for SetAnim
---@param isEnergy boolean
---@param alpha number animation alpha (0..1)
---@param scale number pulse scale about the centre
---@param bypass boolean true: ignore the distance fade
function R.Touch(hull, center, uid, isEnergy, alpha, scale, bypass)
	local n = #hull
	if n < 3 or not center then
		return
	end
	local span = spans[hull]
	local bypassF = bypass and 1 or 0
	if not span then
		-- a new table with the geometry of a span whose own table is gone takes that span over
		local hash = hullHash(hull, n, center)
		local candidate = spansByHash[hash]
		if candidate and candidate.mark ~= liveMark then
			if sameGeometry(candidate, hull, n, center) then
				spans[candidate.hull] = nil
				candidate.hull = hull
				spans[hull] = candidate
				span = candidate
				statAdopted = statAdopted + 1
			else
				statVerifyFailed = statVerifyFailed + 1
			end
		end
	end
	if not span then
		if syncUploads >= UPLOADS_PER_SYNC then
			syncDeferred = true -- picked up by the next sync pass; the field stays hidden until then
			return
		end
		syncUploads = syncUploads + 1
		local count = math.ceil(n / POINTS_PER_CHUNK)
		local start = allocChunks(count)
		if not start then
			local oldCap = grow(highWater + count)
			if not oldCap then
				return
			end
			freeChunks(oldCap, capacity - oldCap)
			start = allocChunks(count)
			if not start then
				return
			end
		end
		local p1, pn = hull[1], hull[n]
		span = {
			start = start,
			count = count,
			points = n,
			cx = center.x,
			cy = center.y,
			cz = center.z,
			uid = uid,
			isEnergy = isEnergy,
			alpha = alpha,
			scale = scale,
			bypass = bypassF,
			mark = liveMark,
			hull = hull,
			hash = hullHash(hull, n, center),
			v1x = p1.x,
			v1z = p1.z,
			vnx = pn.x,
			vnz = pn.z,
		}
		spans[hull] = span
		if not spansByHash[span.hash] then
			spansByHash[span.hash] = span
		end
		uploadGeometry(span, hull)
		uploadParams(span)
	else
		local moved = span.cx ~= center.x or span.cy ~= center.y or span.cz ~= center.z or span.points ~= n
		if moved then
			-- same table, different content: re-upload the geometry too
			span.cx, span.cy, span.cz, span.points = center.x, center.y, center.z, n
			if spansByHash[span.hash] == span then
				spansByHash[span.hash] = nil
			end
			local p1, pn = hull[1], hull[n]
			span.hash = hullHash(hull, n, center)
			span.v1x, span.v1z, span.vnx, span.vnz = p1.x, p1.z, pn.x, pn.z
			if not spansByHash[span.hash] then
				spansByHash[span.hash] = span
			end
			uploadGeometry(span, hull)
		end
		if
			moved
			or span.alpha ~= alpha
			or span.scale ~= scale
			or span.bypass ~= bypassF
			or span.isEnergy ~= isEnergy
		then
			span.alpha, span.scale, span.bypass, span.isEnergy = alpha, scale, bypassF, isEnergy
			uploadParams(span)
		end
		if span.uid ~= uid then
			if span.uid and spansByUid[span.uid] == span then
				spansByUid[span.uid] = nil
			end
			span.uid = uid
		end
		span.mark = liveMark
	end
	if uid then
		spansByUid[uid] = span
	end
end

---Finish a sync pass. Returns true when fields were deferred and another pass is needed; dead
---spans are kept until then so the deferred fields can still adopt them.
---@return boolean again
function R.EndSync()
	if syncDeferred then
		return true
	end
	for hull, span in pairs(spans) do
		if span.mark ~= liveMark then
			releaseSpan(hull, span)
		end
	end
	return false
end

---A hull is being recycled: hide its field now, but keep the chunks until the next EndSync so a
---rebuilt hull with the same geometry (the usual recluster outcome) can adopt them without an upload.
function R.Release(hull)
	local span = spans[hull]
	if span then
		span.mark = -1
		if span.uid and spansByUid[span.uid] == span then
			spansByUid[span.uid] = nil
		end
		span.uid = nil
		if span.alpha ~= -1 then
			span.alpha = -1 -- any real alpha re-uploads the parameters on adoption
			clearParams(span.start, span.count)
		end
	end
end

---Re-upload a field whose point heights or centre changed in place (terrain deformation).
---@param hull table
---@param center table {x,y,z}
function R.Refresh(hull, center)
	local span = spans[hull]
	local n = #hull
	if not span or n ~= span.points then
		return
	end
	span.cx, span.cy, span.cz = center.x, center.y, center.z
	if spansByHash[span.hash] == span then
		spansByHash[span.hash] = nil
	end
	local p1, pn = hull[1], hull[n]
	span.hash = hullHash(hull, n, center)
	span.v1x, span.v1z, span.vnx, span.vnz = p1.x, p1.z, pn.x, pn.z
	if not spansByHash[span.hash] then
		spansByHash[span.hash] = span
	end
	uploadGeometry(span, hull)
	uploadParams(span)
end

---Update the animation values of a field by uid; no-op for unknown uids.
function R.SetAnim(uid, alpha, scale)
	local span = spansByUid[uid]
	if span and (span.alpha ~= alpha or span.scale ~= scale) then
		span.alpha, span.scale = alpha, scale
		uploadParams(span)
	end
end

---Draw every field: gradient fills, then outlines.
---@param toggleMetal number group fade of the metal fields (0..1), 0 skips them
---@param toggleEnergy number same for energy fields
---@param lineWidth number outline width in pixels
function R.Draw(toggleMetal, toggleEnergy, lineWidth)
	if highWater == 0 or not shader or not paramSSBO or not gradVAO or not edgeVAO then
		return
	end
	shader:Activate()
	shader:SetUniform("toggles", toggleMetal, toggleEnergy)
	paramSSBO:BindBufferRange(SSBO_BINDING)

	shader:SetUniformInt("vertsPerChunk", GRAD_VERTS)
	shader:SetUniform("yOffset", -1) -- the fill sits one elmo below the outline, as before
	gradVAO:DrawArrays(GL.TRIANGLES, highWater * GRAD_VERTS, 0)

	gl.LineWidth(lineWidth)
	shader:SetUniformInt("vertsPerChunk", EDGE_VERTS)
	shader:SetUniform("yOffset", 0)
	edgeVAO:DrawArrays(GL.LINES, highWater * EDGE_VERTS, 0)
	gl.LineWidth(1)

	paramSSBO:UnbindBufferRange(SSBO_BINDING)
	shader:Deactivate()
end

---Debug counters: chunks in use, chunk capacity, fields held, geometry uploads so far, spans adopted
---by a new hull table, adoption candidates that failed verification.
---@return integer, integer, integer, integer, integer, integer
function R.GetStats()
	local n = 0
	for _ in pairs(spans) do
		n = n + 1
	end
	return highWater, capacity, n, statUploads, statAdopted, statVerifyFailed
end

return R
