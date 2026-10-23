local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Image Overlay",
		desc = "Lays a reference image from Terraform Brush/Overlays/ over the terrain (DISPLAY > Image in the Terraformer)",
		author = "PtaQ",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = -4,
		enabled = false, -- enabled on demand by the Terraform Suite launcher
	}
end

-- Reference-image overlay for the map editor. The user drops an image into
-- <write dir>/Terraform Brush/Overlays/ (the install folder on Windows), picks
-- it in the IMAGE OVERLAY window and it is projected onto the ground: a real
-- coastline to sculpt against, or a transparent sheet of guide lines whose
-- alpha is kept so only the lines show.
--
-- Rendering is one fullscreen pass in DrawWorldPreUnit that rebuilds the world
-- position of every pixel from the map gbuffer depth ($map_gbuffer_zvaltex) and
-- samples the image by world XZ. That makes it hug the terrain exactly at any
-- map size for a constant cost, needs no tessellated ground mesh, and units and
-- features drawn afterwards cover it like any decal. The placement (opacity,
-- offset, scale, fit, flips) goes in as uniforms every frame, so slider drags
-- preview live.

if not gl.CreateShader then
	return
end

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
if not LuaShader or not InstanceVBOTable then
	return
end

local OVERLAYS_DIR = "Terraform Brush/Overlays/"
-- Anything DevIL reads; DDS goes through the engine's own loader.
local IMAGE_EXTS = {
	png = true,
	jpg = true,
	jpeg = true,
	tga = true,
	bmp = true,
	dds = true,
	tif = true,
	tiff = true,
	gif = true,
}

local st = {
	enabled = false --[[@as boolean]],
	file = nil --[[@as string?]], -- basename inside OVERLAYS_DIR
	opacity = 0.5, -- 0..1
	offsetX = 0, -- map fractions, -1..1 (0.5 = half a map to the east)
	offsetZ = 0,
	scale = 1, -- 1 = the image spans the whole map
	fit = "stretch" --[[@as string]], -- "stretch" (fill the map) or "fit" (keep the image aspect)
	flipH = false,
	flipV = false,
}

---@type string?
local texName -- VFS path of the loaded image, nil when nothing is loaded
local texW, texH = 0, 0
local lastError = ""
local fileList = nil -- cached scan of OVERLAYS_DIR (basenames)
---@type table?
local shader
---@type table?
local quadVAO
local allowDeferred = (Spring.GetConfigInt("AllowDeferredMapRendering") == 1) --[[@as boolean]]
local warnedNoDeferred = false

local shaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/terraform_image_overlay.vert.glsl",
	fssrcpath = "LuaUI/Shaders/terraform_image_overlay.frag.glsl",
	uniformInt = { mapDepths = 0, overlayTex = 1 },
	uniformFloat = { params1 = { 1, 1, 0, 0 }, params2 = { 1, 1, 0, 0 } },
	shaderName = "Terraform Image Overlay",
	shaderConfig = {},
}

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

local function echo(msg)
	Spring.Echo("[Image Overlay] " .. msg)
end

---------------------------------------------------------------------------
-- Folder + texture
---------------------------------------------------------------------------

local function scanDir()
	local out = {}
	local files = VFS.DirList(OVERLAYS_DIR, "*", VFS.RAW) or {}
	for i = 1, #files do
		local base = files[i]:match("[^/\\]+$") or files[i]
		local ext = base:match("%.([%w]+)$")
		if ext and IMAGE_EXTS[ext:lower()] then
			out[#out + 1] = base
		end
	end
	table.sort(out, function(a, b)
		return a:lower() < b:lower()
	end)
	fileList = out
	return out
end

local function unloadTexture()
	if texName then
		gl.DeleteTexture(texName)
	end
	texName = nil
	texW, texH = 0, 0
end

-- Loads OVERLAYS_DIR .. name through the engine's named-texture path. Returns
-- true on success; on failure lastError says why and nothing stays loaded.
local function loadTexture(name)
	unloadTexture()
	lastError = ""
	if not name or name == "" then
		return false
	end
	local path = OVERLAYS_DIR .. name
	if not VFS.FileExists(path) then
		lastError = "Not found: " .. path
		return false
	end
	-- gl.TextureInfo loads a named file texture on first use and returns nil
	-- when the engine could not decode it.
	local info = gl.TextureInfo(path)
	if not info or (info.xsize or 0) <= 0 or (info.ysize or 0) <= 0 then
		lastError = "Could not decode " .. name
		gl.DeleteTexture(path)
		return false
	end
	texName = path
	texW, texH = info.xsize, info.ysize
	return true
end

-- Aspect-fit divisors for the shader: (1,1) stretches the image over the map;
-- in FIT mode the longer side spans the map and the other is letterboxed.
local function fitDivisors()
	if st.fit ~= "fit" or texW <= 0 or texH <= 0 then
		return 1, 1
	end
	local imgAspect = texW / texH
	local mapAspect = Game.mapSizeX / Game.mapSizeZ
	if imgAspect >= mapAspect then
		return 1, mapAspect / imgAspect
	end
	return imgAspect / mapAspect, 1
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

local function setEnabled(v)
	v = v and true or false
	if v and not texName then
		return false
	end
	st.enabled = v
	return true
end

local function selectFile(name)
	if name == nil or name == "" then
		unloadTexture()
		st.file = nil
		st.enabled = false
		lastError = ""
		return true
	end
	if loadTexture(name) then
		st.file = name
		st.enabled = true
		return true
	end
	st.file = nil
	st.enabled = false
	echo(lastError)
	return false, lastError
end

local function getState()
	local fx, fz = fitDivisors()
	return {
		enabled = st.enabled,
		file = st.file,
		hasImage = texName ~= nil,
		width = texW,
		height = texH,
		opacity = st.opacity,
		offsetX = st.offsetX,
		offsetZ = st.offsetZ,
		scale = st.scale,
		fit = st.fit,
		flipH = st.flipH,
		flipV = st.flipV,
		fitX = fx,
		fitZ = fz,
		error = lastError,
		dir = OVERLAYS_DIR,
		supported = allowDeferred,
	}
end

local function resetPlacement()
	st.offsetX = 0
	st.offsetZ = 0
	st.scale = 1
	st.fit = "stretch"
	st.flipH = false
	st.flipV = false
end

function widget:Initialize()
	Spring.CreateDir(OVERLAYS_DIR)
	shader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not shader then
		echo("shader failed to compile, the overlay will not draw")
	end
	quadVAO = InstanceVBOTable.MakeTexRectVAO()
	if not allowDeferred then
		echo("AllowDeferredMapRendering is off in springsettings.cfg; the overlay cannot project onto the terrain")
	end

	WG.TerraformImageOverlay = {
		getDir = function()
			return OVERLAYS_DIR
		end,
		list = function(rescan)
			if rescan or not fileList then
				scanDir()
			end
			return fileList
		end,
		select = selectFile,
		clear = function()
			return selectFile(nil)
		end,
		setEnabled = setEnabled,
		toggle = function()
			return setEnabled(not st.enabled)
		end,
		isEnabled = function()
			return st.enabled and texName ~= nil
		end,
		hasImage = function()
			return texName ~= nil
		end,
		getState = getState,
		setOpacity = function(v)
			st.opacity = clamp(tonumber(v) or st.opacity, 0, 1)
		end,
		setOffset = function(x, z)
			if x ~= nil then
				st.offsetX = clamp(tonumber(x) or st.offsetX, -1, 1)
			end
			if z ~= nil then
				st.offsetZ = clamp(tonumber(z) or st.offsetZ, -1, 1)
			end
		end,
		nudge = function(dx, dz)
			st.offsetX = clamp(st.offsetX + (tonumber(dx) or 0), -1, 1)
			st.offsetZ = clamp(st.offsetZ + (tonumber(dz) or 0), -1, 1)
		end,
		setScale = function(v)
			st.scale = clamp(tonumber(v) or st.scale, 0.05, 8)
		end,
		setFit = function(mode)
			st.fit = (mode == "fit") and "fit" or "stretch"
		end,
		setFlip = function(h, v)
			if h ~= nil then
				st.flipH = h and true or false
			end
			if v ~= nil then
				st.flipV = v and true or false
			end
		end,
		resetPlacement = resetPlacement,
	}

	-- /tfimage            toggles the overlay
	-- /tfimage <file>     picks a file from Terraform Brush/Overlays/
	-- /tfimage off        unloads it
	widgetHandler:AddAction("tfimage", function(_, optLine)
		local arg = optLine and optLine:match("^%s*(.-)%s*$") or ""
		if arg == "" then
			if not setEnabled(not st.enabled) then
				echo("no image loaded; put one in " .. OVERLAYS_DIR .. " and pick it in DISPLAY > Image")
			end
		elseif arg:lower() == "off" then
			selectFile(nil)
		else
			selectFile(arg)
		end
		return true
	end, nil, "t")

	-- Bring back the image the user had up before a reload; the enabled flag
	-- only survives when the file still loads.
	if st.file then
		local wanted = st.enabled
		if loadTexture(st.file) then
			st.enabled = wanted
		else
			st.file = nil
			st.enabled = false
		end
	end
end

function widget:Shutdown()
	unloadTexture()
	if shader then
		shader:Delete()
		shader = nil
	end
	quadVAO = nil
	WG.TerraformImageOverlay = nil
end

function widget:GetConfigData()
	return {
		enabled = st.enabled,
		file = st.file,
		opacity = st.opacity,
		offsetX = st.offsetX,
		offsetZ = st.offsetZ,
		scale = st.scale,
		fit = st.fit,
		flipH = st.flipH,
		flipV = st.flipV,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	st.file = (type(data.file) == "string" and data.file ~= "") and data.file or nil
	st.enabled = data.enabled == true
	st.opacity = clamp(tonumber(data.opacity) or st.opacity, 0, 1)
	st.offsetX = clamp(tonumber(data.offsetX) or 0, -1, 1)
	st.offsetZ = clamp(tonumber(data.offsetZ) or 0, -1, 1)
	st.scale = clamp(tonumber(data.scale) or 1, 0.05, 8)
	st.fit = (data.fit == "fit") and "fit" or "stretch"
	st.flipH = data.flipH == true
	st.flipV = data.flipV == true
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
	if not (st.enabled and texName and shader and quadVAO) then
		return
	end
	if not allowDeferred then
		if not warnedNoDeferred then
			warnedNoDeferred = true
			echo("cannot draw: AllowDeferredMapRendering is off")
		end
		return
	end

	local fx, fz = fitDivisors()

	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, texName)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Culling(false)
	gl.DepthTest(false)
	gl.DepthMask(false)

	shader:Activate()
	shader:SetUniform("params1", st.opacity, st.scale, st.offsetX, st.offsetZ)
	shader:SetUniform("params2", fx, fz, st.flipH and 1 or 0, st.flipV and 1 or 0)
	quadVAO:DrawArrays(GL.TRIANGLES)
	shader:Deactivate()

	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.DepthTest(true)
end
