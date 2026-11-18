--------------------------------------------------------------------------------
-- Decal preview bake module
--
-- Channel-encoded decal bitmaps (mainscars: red filler + green mask; tracks and
-- footprints: red on dark) have no alpha, so a raw <img> shows nothing useful.
-- They are baked once through a small fragment shader into opaque PNGs in a
-- writable cache dir; the widget then creates an <img> whose src is the PNG.
--
-- gl.RenderToTexture only works inside draw callbacks, so the flow is:
--   1. M.enqueueAll(categories, getFallbackPath) once, on the first tile build.
--   2. M.drainQueue() every frame from widget:DrawScreen (BAKES_PER_FRAME each).
--   3. M.consumeResync() in widget:Update: true means bakes finished and the
--      queue is empty, so the widget rebuilds its tiles.
--   4. M.resolve(name, sourcePath, maskMode) per tile: the "/vfs/path" to show,
--      or nil while the bake is pending.
--
-- The disk cache is not trusted across sessions: every start re-bakes (about 60
-- decals at 4 per frame, roughly 0.25s), so a shader edit never leaves stale
-- PNGs. A CACHE_VERSION in the file names would allow reuse later.
--------------------------------------------------------------------------------

local M = {}

local PREVIEW_SIZE = 64
local BAKES_PER_FRAME = 4

local cacheDir -- set by M.init(); caller is responsible for Spring.CreateDir
local previewShader ---@type any?
local uniMaskMode

-- { [decalName] = "/vfs/path" or false (resolution failed). nil = unknown }
local previewResolveCache = {}

-- Enumerated upfront once; drained from DrawScreen.
local bakeQueue = {} -- array of { name, sourcePath, maskMode }
local bakePending = {} -- { [name] = true } dedupe
local resyncRequested = false
local bakesEnqueued = false

--------------------------------------------------------------------------------
-- Shader (lazy-init on first bake)
--------------------------------------------------------------------------------
local function initPreviewShader()
	if previewShader ~= nil then
		return previewShader and true or false
	end
	previewShader = gl.CreateShader({
		vertex = [[
			#version 150 compatibility
			void main() {
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
			}
		]],
		-- Opaque composite: mix a "ground" color with a "decal tint" by the
		-- channel-derived mask, so the PNG shows up on any tile background.
		fragment = [[
			#version 150 compatibility
			uniform sampler2D tex0;
			uniform int maskMode;
			uniform vec3 groundColor;
			uniform vec3 decalTint;
			void main() {
				vec4 c = texture2D(tex0, gl_TexCoord[0].st);
				float mask;
				if (maskMode == 1) {
					// mainscar atlas: red is filler, green encodes shape
					mask = clamp(c.g - c.r * 0.5, 0.0, 1.0);
				} else if (maskMode == 2) {
					// tracks / footprints: dark mark on red background
					mask = clamp(1.0 - c.r, 0.0, 1.0);
					mask = smoothstep(0.05, 0.6, mask);
				} else {
					// generic luminance fallback for unclassified BMPs
					mask = dot(c.rgb, vec3(0.299, 0.587, 0.114));
				}
				vec3 scarred = mix(groundColor, decalTint, mask);
				gl_FragColor = vec4(scarred, 1.0);
			}
		]],
		uniformInt = { tex0 = 0, maskMode = 1 },
		-- groundColor matches .dp-thumb-footprints rgb(96, 72, 56) so the bakes blend
		-- with the category-tinted tile background.
		uniformFloat = { groundColor = { 96 / 255, 72 / 255, 56 / 255 }, decalTint = { 0.12, 0.08, 0.06 } },
	})
	if not previewShader or previewShader == 0 then
		Spring.Echo("[DecalPlacer.bake] shader compile failed: " .. tostring(gl.GetShaderLog()))
		previewShader = false
		return false
	end
	uniMaskMode = gl.GetUniformLocation(previewShader, "maskMode")
	return true
end

--------------------------------------------------------------------------------
-- Path helpers
--------------------------------------------------------------------------------
local function bakedPreviewPath(decalName)
	local safe = decalName:gsub("[^%w_-]", "_")
	return cacheDir .. safe .. ".png"
end

--------------------------------------------------------------------------------
-- Bake one decal. Draw callbacks only (gl.RenderToTexture). Writes the cached
-- PNG and returns true on success.
--------------------------------------------------------------------------------
local function bakeDecalPreview(decalName, sourceTexPath, maskMode)
	if not initPreviewShader() then
		return false
	end

	local cachePath = bakedPreviewPath(decalName)
	local fboTex = gl.CreateTexture(PREVIEW_SIZE, PREVIEW_SIZE, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fboTex then
		return false
	end

	local saved = false
	gl.RenderToTexture(fboTex, function()
		gl.Blending(false)
		gl.DepthTest(false)
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		if gl.Texture(0, sourceTexPath) then
			gl.UseShader(previewShader)
			if uniMaskMode then
				gl.Uniform(uniMaskMode, maskMode)
			end

			gl.BeginEnd(GL.QUADS, function()
				gl.TexCoord(0, 1)
				gl.Vertex(-1, -1, 0)
				gl.TexCoord(1, 1)
				gl.Vertex(1, -1, 0)
				gl.TexCoord(1, 0)
				gl.Vertex(1, 1, 0)
				gl.TexCoord(0, 0)
				gl.Vertex(-1, 1, 0)
			end)

			gl.UseShader(0)
			gl.Texture(0, false)

			-- gl.SaveImage must run inside the FBO callback to read this target.
			gl.SaveImage(0, 0, PREVIEW_SIZE, PREVIEW_SIZE, cachePath, { yflip = false })
			saved = true
		end

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()

		gl.Blending(true)
	end)

	gl.DeleteTexture(fboTex)
	return saved
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Set the cache directory (e.g. "Terraform Brush/DecalPreviews/"). The caller
-- creates it with Spring.CreateDir first.
function M.init(cachePathStr)
	cacheDir = cachePathStr
end

-- Guess the encoding from the file path. Works for the shipped decals but not
-- for arbitrary names. Cleaner options: get the mask mode from the decal API, or
-- convert the channel-encoded BMP atlases to RGBA PNG/TGA so no bake is needed.
-- Returns:
--   -1  normal map: no preview
--    0  PNG/TGA: has alpha, used as-is
--    1  mainscar atlas BMP: green minus red filler mask
--    2  tracks / footprints BMP: inverse red mask
--    3  other BMP: luminance fallback
function M.classifyMaskMode(sourcePath)
	local lower = sourcePath:lower():gsub("\\", "/")
	if lower:find("/normscar") or lower:find("_normal") or lower:find("/normals?/") then
		return -1
	end
	local ext = lower:match("%.([^%.]+)$") or ""
	if ext == "png" or ext == "tga" then
		return 0
	elseif lower:find("/mainscar") then
		return 1
	elseif lower:find("tracks") or lower:find("track") or lower:find("footprint") or lower:find("bigfoot") then
		return 2
	end
	return 3
end

-- The VFS path (leading slash) for the tile's <img src>, or nil if no preview
-- exists yet. Mask-encoded sources return nil until their bake finishes
-- (consumeResync tells the widget to ask again).
function M.resolve(decalName, sourcePath, maskMode)
	if previewResolveCache[decalName] ~= nil then
		return previewResolveCache[decalName] or nil
	end

	if maskMode == -1 then
		previewResolveCache[decalName] = false
		return nil
	end

	if maskMode == 0 then
		local result = "/" .. sourcePath
		previewResolveCache[decalName] = result
		return result
	end

	-- Mask-encoded BMP: baked from DrawScreen.
	return nil
end

-- Queue every mask-encoded source once per session. categories is what
-- WG.DecalPlacer.getDecalCategories() returns; getFallbackPath resolves entries
-- with an empty filename.
function M.enqueueAll(categories, getFallbackPath)
	if bakesEnqueued or not categories then
		return 0
	end

	for _, items in pairs(categories) do
		for _, entry in ipairs(items) do
			local fname = entry.filename
			if (not fname or fname == "") and getFallbackPath then
				fname = getFallbackPath(entry.name)
			end
			if fname and fname ~= "" then
				local sourcePath = fname:gsub("\\", "/"):gsub("^/+", "")
				local maskMode = M.classifyMaskMode(sourcePath)
				if maskMode > 0 and not bakePending[entry.name] then
					bakePending[entry.name] = true
					bakeQueue[#bakeQueue + 1] = {
						name = entry.name,
						sourcePath = sourcePath,
						maskMode = maskMode,
					}
				end
			end
		end
	end
	bakesEnqueued = true
	return #bakeQueue
end

-- Bake up to BAKES_PER_FRAME queued decals. Draw callbacks only
-- (gl.RenderToTexture). Successful bakes set the resync flag.
function M.drainQueue()
	if #bakeQueue == 0 then
		return
	end
	local processed = 0
	while #bakeQueue > 0 and processed < BAKES_PER_FRAME do
		local item = table.remove(bakeQueue, 1)
		bakePending[item.name] = nil
		if bakeDecalPreview(item.name, item.sourcePath, item.maskMode) then
			previewResolveCache[item.name] = "/" .. bakedPreviewPath(item.name)
			resyncRequested = true
		else
			previewResolveCache[item.name] = false
		end
		processed = processed + 1
	end
end

-- True once the queue is empty and at least one bake finished since the last
-- call; clears the flag. The widget rebuilds its tiles on true.
function M.consumeResync()
	if resyncRequested and #bakeQueue == 0 then
		resyncRequested = false
		return true
	end
	return false
end

function M.shutdown()
	if previewShader and previewShader ~= false then
		gl.DeleteShader(previewShader)
	end
	previewShader = nil
	uniMaskMode = nil
	previewResolveCache = {}
	bakeQueue = {}
	bakePending = {}
	resyncRequested = false
	bakesEnqueued = false
end

return M
