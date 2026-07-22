--------------------------------------------------------------------------------
-- Decal preview bake module
--
-- Channel-encoded source bitmaps (mainscars: red filler + green mask;
-- tracks/footprints: red-on-dark) have no alpha and don't render usefully via
-- a raw <img>. We pre-bake them through a one-shot fragment shader into RGBA
-- PNGs in a writable cache dir, then the widget renders the cached PNG via
-- plain <img data-attr-src="...">.
--
-- Spring restricts gl.RenderToTexture to draw callbacks, so the widget can't
-- bake inline from syncDecals/Initialize. The flow is:
--   1. widget calls M.enqueueAll(categories, fallbackResolver) once after
--      first sync — module enumerates and queues every mask-encoded decal.
--   2. widget calls M.drainQueue(N) every frame from widget:DrawScreen — the
--      module bakes up to N decals per frame and writes their PNGs.
--   3. widget calls M.consumeResync() in widget:Update — true means at least
--      one bake completed since the last consume, and the queue is now
--      empty, so the widget should re-run its sync to pick up new srcPaths.
--   4. widget calls M.resolve(name, sourcePath, maskMode) per row in its
--      sync — returns the "/vfs/path" once the decal is baked (or
--      immediately for PNG/TGA sources that don't need baking), or nil.
--
-- STARTUP OVERHEAD (deliberate trade-off): we do NOT trust on-disk cache
-- between sessions. Every widget startup re-bakes every mask-encoded decal.
-- ~60 bakes × 4 per frame ≈ 0.25s of startup work, spread across DrawScreen
-- ticks (no single-frame stutter). Tiles render blank for ~0.25s on first
-- open, then populate as bakes complete.
--
-- Why no cache? While the shader is being iterated, trusting cached PNGs
-- meant stale baked output survived shader edits — cost hours of debugging.
-- When the shader stabilises, switch to versioned cache filenames keyed off
-- a CACHE_VERSION constant; that's a 5-line change to invalidate cleanly
-- on shader edits and keep instant reloads otherwise.
--------------------------------------------------------------------------------

local M = {}

local PREVIEW_SIZE     = 64
local BAKES_PER_FRAME  = 4

local cacheDir         -- set by M.init(); caller is responsible for Spring.CreateDir
local previewShader    ---@type any?
local uniMaskMode

-- { [decalName] = "/vfs/path" or false (resolution failed). nil = unknown }
local previewResolveCache = {}

-- Enumerated upfront once; drained from DrawScreen.
local bakeQueue        = {}    -- array of { name, sourcePath, maskMode }
local bakePending      = {}    -- { [name] = true } dedupe
local resyncRequested  = false
local bakesEnqueued    = false

--------------------------------------------------------------------------------
-- Shader (lazy-init on first bake)
--------------------------------------------------------------------------------
local function initPreviewShader()
	if previewShader ~= nil then return previewShader and true or false end
	previewShader = gl.CreateShader({
		vertex = [[
			#version 150 compatibility
			void main() {
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
			}
		]],
		-- OPAQUE composite (matches the original GL renderer that visibly
		-- worked pre-refactor): mix a "ground" color with a "decal tint" by
		-- the channel-derived mask. The cached PNG is fully opaque so it
		-- always renders something visible regardless of how the underlying
		-- tile bg is styled.
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
		uniformInt   = { tex0 = 0, maskMode = 1 },
		-- groundColor matches .dp-thumb-footprints rgb(96, 72, 56) so the
		-- baked previews blend visually with the category-tinted tile bg.
		uniformFloat = { groundColor = { 96/255, 72/255, 56/255 }, decalTint = { 0.12, 0.08, 0.06 } },
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
	-- Sanitize for filesystem
	local safe = decalName:gsub("[^%w_-]", "_")
	return cacheDir .. safe .. ".png"
end

--------------------------------------------------------------------------------
-- Bake one decal. Must be called inside a draw callback (gl.RenderToTexture
-- restriction). Writes the cached PNG and returns true on success.
--------------------------------------------------------------------------------
local function bakeDecalPreview(decalName, sourceTexPath, maskMode)
	if not initPreviewShader() then return false end

	local cachePath = bakedPreviewPath(decalName)
	local fboTex = gl.CreateTexture(PREVIEW_SIZE, PREVIEW_SIZE, {
		border     = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
		fbo        = true,
	})
	if not fboTex then return false end

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
			if uniMaskMode then gl.Uniform(uniMaskMode, maskMode) end

			gl.BeginEnd(GL.QUADS, function()
				gl.TexCoord(0, 1); gl.Vertex(-1, -1, 0)
				gl.TexCoord(1, 1); gl.Vertex( 1, -1, 0)
				gl.TexCoord(1, 0); gl.Vertex( 1,  1, 0)
				gl.TexCoord(0, 0); gl.Vertex(-1,  1, 0)
			end)

			gl.UseShader(0)
			gl.Texture(0, false)

			-- Save inside the FBO callback — proven-required pattern from
			-- cmd_terraform_brush.lua heightmap export.
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

-- Set the cache directory (e.g. "Terraform Brush/DecalPreviews/"). Caller
-- should Spring.CreateDir() it themselves before calling.
function M.init(cachePathStr)
	cacheDir = cachePathStr
end

-- TODO: filename-pattern heuristic. Works for the known decal set but isn't
-- robust to new decals or non-conforming names. Two cleaner paths exist:
--
--   (A) Metadata path — WG.DecalPlacer (or the engine API it wraps) exposes
--       the encoding/maskMode per entry. We pass it through to M.resolve
--       and delete this function. Cheap; just needs a few lines added to
--       cmd_decal_placer.lua and the engine query.
--
--   (B) Standardization path — re-author / convert the channel-encoded BMP
--       atlases (mainscars, tracks, footprints) into RGBA PNG/TGA with
--       proper alpha. Then EVERY decal becomes maskMode 0 (alpha-as-mask),
--       no shader bake needed at all, this whole module collapses to ~30
--       lines of pure path resolution. This is the "real" fix and how
--       modern game asset pipelines do it; the legacy encodings are a
--       holdover from older Spring engine days.
--
-- (B) is more work (asset-pipeline change, ~60 source files, possibly
-- overriding via BAR.sdd VFS shadowing of engine-archive files), but it's
-- the end state worth aiming for. Until then, this heuristic + the bake
-- machinery is the engineering compromise.
--
-- Returns:
--   -1  normal map — skip preview entirely
--    0  PNG/TGA — has alpha already, use source as-is, no bake needed
--    1  mainscar atlas BMP — green-channel-minus-red-filler mask
--    2  tracks / footprints BMP — inverse-red mask
--    3  generic BMP — luminance fallback
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

-- Returns the VFS path (with leading slash) to use as <img src>, or nil if
-- no preview is available yet. For mask-encoded sources not yet baked,
-- returns nil — the upfront enqueueAll + DrawScreen drain handles them; the
-- widget will re-derive once the bake completes (signaled via consumeResync).
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

	-- Mask-encoded BMP. Will be baked from DrawScreen.
	return nil
end

-- One-shot enumeration: walk every category entry, queue every mask-encoded
-- source. Idempotent (only enumerates once per session). Pass categories as
-- returned by WG.DecalPlacer.getDecalCategories(), and a fallback resolver
-- (typically findPreviewPath) for entries with empty filename.
function M.enqueueAll(categories, getFallbackPath)
	if bakesEnqueued or not categories then return 0 end

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

	if #bakeQueue > 0 then
		Spring.Echo(string.format("[Decal Placer] queued %d decal previews to bake", #bakeQueue))
	end
	return #bakeQueue
end

-- Drain up to BAKES_PER_FRAME bakes from the queue. MUST be called from a
-- draw callback (Spring restricts gl.RenderToTexture). Sets the internal
-- resync flag if any bakes succeeded; widget polls via consumeResync.
function M.drainQueue()
	if #bakeQueue == 0 then return end
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

-- Number of bakes still pending. Useful if the widget wants to gate its
-- re-sync on full drain (avoid syncing partway through bake batches).
function M.queueLen()
	return #bakeQueue
end

-- True once the queue is empty AND at least one bake completed since the
-- last call. Atomic: clears the internal flag. Widget should re-run its
-- sync when this returns true.
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
