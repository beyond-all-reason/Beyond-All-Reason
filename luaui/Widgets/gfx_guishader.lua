-- Intel GPU compatibility: Use a simplified shader path
-- The complex derivative-based quad message passing doesn't work reliably on Intel GPUs
local isIntelGPU = Platform ~= nil and Platform.gpuVendor == "Intel"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "GUI Shader",
		desc = "Blurs the 3D-world under several other widgets UI elements.",
		author = "Floris (original blurapi widget by: jK)",
		date = "17 february 2015",
		license = "GNU GPL, v2 or later",
		layer = -990000, -- other widgets can be run earlier (lower layer) and thus guishader blur are will lag behind a frame, (like tooltip screenblur)
		enabled = true,
		modalExempt = true, -- the blur behind an open window is this widget's work
	}
end

-- Localized functions for performance
local stringFind = string.find
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMin = math.min
local mathMax = math.max

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry
local spIsGUIHidden = Spring.IsGUIHidden
local spGetConfigFloat = Spring.GetConfigFloat

local uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.7)
local uiOpacityCheckFrame = 0

-- hardware capability
local canShader = gl.CreateShader ~= nil

local LuaShader = gl.LuaShader
local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")

-- the blur is only drawn on the screen tiles (of this many pixels) that hold part of a blurred region
local TILE_SIZE = 32
-- the tile mask is reduced from the stencil in two passes, through blocks of this many pixels
local MASK_STEP = 8

-- Localized GL functions for hot paths
local glTexture = gl.Texture
local glBlending = gl.Blending
local glColor = gl.Color
local glCopyToTexture = gl.CopyToTexture
local glRenderToTexture = gl.RenderToTexture
local glRect = gl.Rect
local glClear = gl.Clear
local glScissor = gl.Scissor
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glDeleteTexture = gl.DeleteTexture
local glUniformInt = gl.UniformInt
local GL_TRIANGLES = GL.TRIANGLES

local renderDlists = {}
local deleteDlistQueue = {}
local blurShader ---@type LuaShader
local tileMaskShader ---@type LuaShader
local toScreenUniform ---@type integer

-- alpha of the regions to blur
local stenciltex ---@type string
local stenciltexScreen ---@type string
-- one texel per tile: does the tile hold part of a region
local tileMask ---@type string
local tileMaskScreen ---@type string
local maskBlocks ---@type string
-- targets of the offscreen passes, B also takes the screen copy for DrawScreen
local blurTexA ---@type string
local blurTexB ---@type string

local tileVAO ---@type VAO
local tileObjects = {}
local tilesX, tilesY = 1, 1
local numTiles = 0 ---@type number

-- the part of the screen DrawScreen copies: all of it, or around the screen rects when there are only rects
local copyX, copyY, copyW, copyH = 0, 0, 0, 0

local screenBlur = false

local guishaderRects = {}
local guishaderDlists = {}
local guishaderScreenRects = {}
local guishaderScreenDlists = {}
local updateStencilTexture = false
local updateStencilTextureScreen = false

-- Which widget registered each region, when it said so (name -> widget). Used only while
-- a modal window hides the interface: a hidden widget's region would otherwise stay on
-- screen as a blurred patch of map. A region with no owner is treated as hidden then.
local rectOwners = {}
local dlistOwners = {}
local screenRectOwners = {}
local screenDlistOwners = {}
local lastModalActive = false
local lastModalRevision = -1

local vsx, vsy, vpx, vpy = spGetViewGeometry()
local blurScale = 1
local extraBlurPasses = 0

-- Cached uniform values
local cachedIvsx = 0.5 / vsx
local cachedIvsy = 0.5 / vsy
local uniformsDirty = true

local tileVertexShader = [[
#version 330
layout (location = 0) in vec2 corner;
layout (location = 1) in vec2 tile;

uniform sampler2D tileMask;
uniform vec2 viewSize;
uniform float tileSize;
uniform int toScreen;

out vec2 texCoord;

void main(void)
{
	ivec2 t = ivec2(tile);
	float covered = texelFetch(tileMask, t, 0).r;
	if (toScreen == 0) {
		// the next pass samples a few pixels past a region's edge, so offscreen passes also fill the tiles around it
		ivec2 last = textureSize(tileMask, 0) - 1;
		for (int y = -1; y <= 1; ++y) {
			for (int x = -1; x <= 1; ++x) {
				covered = max(covered, texelFetch(tileMask, clamp(t + ivec2(x, y), ivec2(0), last), 0).r);
			}
		}
	}
	vec2 pos = min((tile + corner) * tileSize, viewSize);
	texCoord = pos / viewSize;
	// a tile without a region collapses outside the clip volume
	gl_Position = covered > 0.5 ? vec4(texCoord * 2.0 - 1.0, 0.0, 1.0) : vec4(2.0, 2.0, 2.0, 1.0);
}
]]

local blurFragmentShader = [[
uniform sampler2D tex2;
uniform sampler2D tex0;
uniform float ivsx;
uniform float ivsy;
uniform float blurScale;
uniform int toScreen;

in vec2 texCoord;
out vec4 fragColor;

#ifndef INTEL_GPU
vec2 quadGetQuadVector(vec2 screenCoords){
	vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
	vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
	quadVector = quadVector * odd_start_mirror;
	return sign(quadVector);
}
#endif

void main(void)
{
#ifdef INTEL_GPU
	// Intel GPUs: simple box blur with weighted distribution, avoids the derivative functions (dFdx/dFdy)
	float stencil = texture(tex2, texCoord).a;
	if (stencil < 0.01)
	{
		if (toScreen == 1) {
			discard;
		}
		fragColor = texelFetch(tex0, ivec2(gl_FragCoord.xy), 0);
		return;
	}

	// 9-sample weighted blur for smooth, high-quality results
	vec4 sum = vec4(0.0);
	vec2 offset = vec2(ivsx, ivsy) * 6.0 * blurScale;

	// Center sample gets highest weight
	sum += texture(tex0, texCoord) * 4.0;

	// Cardinal directions weighted higher
	sum += texture(tex0, texCoord + vec2(offset.x, 0.0)) * 2.0;
	sum += texture(tex0, texCoord - vec2(offset.x, 0.0)) * 2.0;
	sum += texture(tex0, texCoord + vec2(0.0, offset.y)) * 2.0;
	sum += texture(tex0, texCoord - vec2(0.0, offset.y)) * 2.0;

	// Diagonal corners for smoothness
	sum += texture(tex0, texCoord + offset);
	sum += texture(tex0, texCoord - offset);
	sum += texture(tex0, texCoord + vec2(offset.x, -offset.y));
	sum += texture(tex0, texCoord + vec2(-offset.x, offset.y));

	vec4 blurred = sum / 17.0;
#else
	// pixel quad message passing: 4 lookups per pixel and the quad shares them through the derivatives,
	// so every pixel of a quad samples before the region test
	vec2 quadVector = quadGetQuadVector(gl_FragCoord.xy);
	vec2 subpixel = vec2(ivsx, ivsy);
	subpixel *= quadVector;
	vec4 sum = vec4(0.0);
	for (int i = 0; i <= 1; ++i) {
		for (int j = 0; j <= 1; ++j) {
			vec2 samplingCoords = texCoord + vec2(i, j) * 6.0 * blurScale * subpixel + subpixel;
			sum += texture(tex0, samplingCoords);
		}
	}

	vec4 inputadjx = sum - dFdx(sum) * quadVector.x;
	vec4 inputadjy = sum - dFdy(sum) * quadVector.y;
	vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
	sum += inputadjx + inputadjy + inputdiag;
	vec4 blurred = sum / 16.0;

	float stencil = texture(tex2, texCoord).a;
	if (stencil < 0.01)
	{
		fragColor = toScreen == 1 ? vec4(0.0) : texelFetch(tex0, ivec2(gl_FragCoord.xy), 0);
		return;
	}
#endif
	if (toScreen == 1) {
		fragColor = blurred;
	} else {
		// what blending it onto the screen would have left there
		vec4 below = texelFetch(tex0, ivec2(gl_FragCoord.xy), 0);
		fragColor = vec4(blurred.rgb * blurred.a + below.rgb * (1.0 - blurred.a), blurred.a * blurred.a + below.a * (1.0 - blurred.a));
	}
}
]]

local maskVertexShader = [[
#version 330
layout (location = 0) in vec2 corner;

void main(void)
{
	gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}
]]

-- reduces blocks of `source` to one texel: 1 when any texel's alpha reaches the threshold
local maskFragmentShader = [[
#version 330
uniform sampler2D source;
uniform int blockSize;
uniform float threshold;

out vec4 fragColor;

void main(void)
{
	ivec2 origin = ivec2(gl_FragCoord.xy) * blockSize;
	ivec2 limit = min(origin + blockSize, textureSize(source, 0));
	float covered = 0.0;
	for (int y = origin.y; y < limit.y && covered == 0.0; ++y) {
		for (int x = origin.x; x < limit.x; ++x) {
			if (texelFetch(source, ivec2(x, y), 0).a >= threshold) {
				covered = 1.0;
				break;
			}
		}
	}
	fragColor = vec4(covered);
}
]]

local function DrawTiles()
	tileVAO:DrawElements(GL_TRIANGLES, 6, 0, numTiles)
end

local function DrawMaskQuad()
	tileVAO:DrawElements(GL_TRIANGLES, 6, 0, 1)
end

local function DrawStencilTexture(world, fullscreen)
	--spEcho("DrawStencilTexture",world, fullscreen, Spring.GetDrawFrame(), updateStencilTexture)
	local stencil = world and stenciltex or stenciltexScreen
	glRenderToTexture(stencil, function()
		glScissor(false)
		glClear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		glPushMatrix()
		glTranslate(-1, -1, 0)
		glScale(2 / vsx, 2 / vsy, 0)
		if world then
			for name, rect in pairs(guishaderRects) do
				if widgetHandler:ModalAllows(rectOwners[name]) then
					glRect(rect[1], rect[2], rect[3], rect[4])
				end
			end
			for name, dlist in pairs(guishaderDlists) do
				if widgetHandler:ModalAllows(dlistOwners[name]) then
					glColor(1, 1, 1, 1)
					glCallList(dlist)
				end
			end
		elseif fullscreen then
			glRect(0, 0, vsx, vsy)
		else
			for name, rect in pairs(guishaderScreenRects) do
				if widgetHandler:ModalAllows(screenRectOwners[name]) then
					glRect(rect[1], rect[2], rect[3], rect[4])
				end
			end
			for name, dlist in pairs(guishaderScreenDlists) do
				if widgetHandler:ModalAllows(screenDlistOwners[name]) then
					glColor(1, 1, 1, 1)
					glCallList(dlist)
				end
			end
		end
		glPopMatrix()
	end)

	local mask = world and tileMask or tileMaskScreen
	glBlending(false)
	if fullscreen or not next(world and guishaderDlists or guishaderScreenDlists) then
		-- only rects: mark the tiles they touch instead of reading the stencil back
		local rects = world and guishaderRects or guishaderScreenRects
		local owners = world and rectOwners or screenRectOwners
		glRenderToTexture(mask, function()
			glClear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
			glPushMatrix()
			glTranslate(-1, -1, 0)
			glScale(2 / tilesX, 2 / tilesY, 0)
			glColor(1, 1, 1, 1)
			if fullscreen then
				glRect(0, 0, tilesX, tilesY)
			else
				for name, rect in pairs(rects) do
					if widgetHandler:ModalAllows(owners[name]) then
						glRect(
							mathFloor(mathMin(rect[1], rect[3]) / TILE_SIZE),
							mathFloor(mathMin(rect[2], rect[4]) / TILE_SIZE),
							mathFloor(mathMax(rect[1], rect[3]) / TILE_SIZE) + 1,
							mathFloor(mathMax(rect[2], rect[4]) / TILE_SIZE) + 1
						)
					end
				end
			end
			glPopMatrix()
		end)
	else
		tileMaskShader:Activate()
		glTexture(0, stencil)
		tileMaskShader:SetUniformInt("blockSize", MASK_STEP)
		tileMaskShader:SetUniform("threshold", 0.01) -- the blur shader's region test
		glRenderToTexture(maskBlocks, DrawMaskQuad)
		glTexture(0, maskBlocks)
		tileMaskShader:SetUniformInt("blockSize", TILE_SIZE / MASK_STEP)
		tileMaskShader:SetUniform("threshold", 0.5)
		glRenderToTexture(mask, DrawMaskQuad)
		tileMaskShader:Deactivate()
		glTexture(0, false)
	end
	glBlending(true)
end

-- Offscreen passes fill a tile around each region's tiles and sample a few pixels past those,
-- so two tiles of margin cover everything the blur reads.
local function UpdateScreenCopyRegion(fullscreen)
	copyX, copyY, copyW, copyH = 0, 0, vsx, vsy
	if fullscreen or next(guishaderScreenDlists) then
		return
	end
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for name, rect in pairs(guishaderScreenRects) do
		if widgetHandler:ModalAllows(screenRectOwners[name]) then
			x0 = mathMin(x0, rect[1], rect[3])
			y0 = mathMin(y0, rect[2], rect[4])
			x1 = mathMax(x1, rect[1], rect[3])
			y1 = mathMax(y1, rect[2], rect[4])
		end
	end
	if x0 > x1 then
		copyW = 0
		return
	end
	local margin = 2 * TILE_SIZE
	copyX = mathMax(0, mathFloor(x0 / TILE_SIZE) * TILE_SIZE - margin)
	copyY = mathMax(0, mathFloor(y0 / TILE_SIZE) * TILE_SIZE - margin)
	copyW = mathMin(vsx, (mathFloor(x1 / TILE_SIZE) + 1) * TILE_SIZE + margin) - copyX
	copyH = mathMin(vsy, (mathFloor(y1 / TILE_SIZE) + 1) * TILE_SIZE + margin) - copyY
end

-- Blurs `source` inside the stencil's regions: the extra passes go through the offscreen
-- textures and the last one is blended onto the screen. Expects blending enabled.
local function DrawBlur(source, stencil, mask)
	glTexture(1, mask)
	glTexture(2, stencil)
	blurShader:Activate()
	if uniformsDirty then
		blurShader:SetUniform("ivsx", cachedIvsx)
		blurShader:SetUniform("ivsy", cachedIvsy)
		blurShader:SetUniform("blurScale", blurScale)
		blurShader:SetUniform("viewSize", vsx, vsy)
		uniformsDirty = false
	end
	if extraBlurPasses > 0 then
		glScissor(false)
		glBlending(false)
		glUniformInt(toScreenUniform, 0)
		for pass = 1, extraBlurPasses do
			local target = pass % 2 == 1 and blurTexA or blurTexB
			glTexture(0, source)
			glRenderToTexture(target, DrawTiles)
			source = target
		end
		glUniformInt(toScreenUniform, 1)
		glBlending(true)
	end
	glTexture(0, source)
	DrawTiles()
	blurShader:Deactivate()
	glTexture(2, false)
	glTexture(1, false)
	glTexture(false)
end

local function FboTexture(width, height, filter)
	return gl.CreateTexture(width, height, {
		border = false,
		min_filter = filter,
		mag_filter = filter,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
		fbo = true,
	})
end

-- texture names are never reused, so the old ones can stay in the variables until replaced
local function DeleteResources()
	glDeleteTexture(stenciltex)
	glDeleteTexture(stenciltexScreen)
	glDeleteTexture(tileMask)
	glDeleteTexture(tileMaskScreen)
	glDeleteTexture(maskBlocks)
	glDeleteTexture(blurTexA)
	glDeleteTexture(blurTexB)
	for i = 1, #tileObjects do
		tileObjects[i]:Delete()
	end
	tileObjects = {}
end

-- a unit quad drawn once per tile, the tile index as instance data
local function CreateTileVAO()
	local cornerVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local tileVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local vao = gl.GetVAO()
	if not (cornerVBO and tileVBO and indexVBO and vao) then
		return false
	end
	tileObjects = { vao, cornerVBO, tileVBO, indexVBO }

	cornerVBO:Define(4, { { id = 0, name = "corner", size = 2 } })
	cornerVBO:Upload({ 0, 0, 1, 0, 0, 1, 1, 1 })
	indexVBO:Define(6)
	indexVBO:Upload({ 0, 1, 2, 2, 1, 3 })
	local tiles = {}
	for y = 0, tilesY - 1 do
		for x = 0, tilesX - 1 do
			tiles[#tiles + 1] = x
			tiles[#tiles + 1] = y
		end
	end
	numTiles = tilesX * tilesY
	tileVBO:Define(numTiles, { { id = 1, name = "tile", size = 2 } })
	tileVBO:Upload(tiles)

	-- with all three attached the engine keeps the VAO instead of rebuilding it every draw
	vao:AttachVertexBuffer(cornerVBO)
	vao:AttachInstanceBuffer(tileVBO)
	vao:AttachIndexBuffer(indexVBO)
	tileVAO = vao
	return true
end

local function CreateResources()
	DeleteResources()
	tilesX, tilesY = mathCeil(vsx / TILE_SIZE), mathCeil(vsy / TILE_SIZE)
	local stencil, stencilScreen = FboTexture(vsx, vsy, GL.NEAREST), FboTexture(vsx, vsy, GL.NEAREST)
	local mask, maskScreen = FboTexture(tilesX, tilesY, GL.NEAREST), FboTexture(tilesX, tilesY, GL.NEAREST)
	local blocks = FboTexture(mathCeil(vsx / MASK_STEP), mathCeil(vsy / MASK_STEP), GL.NEAREST)
	local texA, texB = FboTexture(vsx, vsy, GL.LINEAR), FboTexture(vsx, vsy, GL.LINEAR)
	if not (stencil and stencilScreen and mask and maskScreen and blocks and texA and texB) then
		return false
	end
	stenciltex, stenciltexScreen, tileMask, tileMaskScreen = stencil, stencilScreen, mask, maskScreen
	maskBlocks = blocks
	blurTexA, blurTexB = texA, texB
	return CreateTileVAO()
end

function widget:ViewResize(_, _)
	vsx, vsy, vpx, vpy = spGetViewGeometry()

	-- Scale blur for high-resolution displays: gentle sqrt-based sample spread
	-- plus additional blur passes to compound the effect without quality loss
	blurScale = math.max(1.0, math.sqrt(vsy / 1080))
	extraBlurPasses = math.min(3, math.max(0, math.floor(vsy / 1080 + 0.5) - 1))

	-- Cache uniform values
	cachedIvsx = 0.5 / vsx
	cachedIvsy = 0.5 / vsy
	uniformsDirty = true

	if not CreateResources() then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
		widgetHandler:RemoveWidget()
		return
	end

	updateStencilTexture = true
	updateStencilTextureScreen = true
end

local function CheckHardware()
	if not canShader then
		spEcho(
			'guishader api: your hardware does not support shaders, OR: change springsettings: "enable lua shaders" '
		)
		widgetHandler:RemoveWidget()
		return false
	end

	if not NON_POWER_OF_TWO then
		spEcho("guishader api: your hardware does not non-2^n-textures")
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

local function CreateShaders()
	local shader = LuaShader({
		vertex = tileVertexShader,
		fragment = "#version 330\n" .. (isIntelGPU and "#define INTEL_GPU\n" or "") .. blurFragmentShader,

		uniformInt = {
			tex0 = 0,
			tileMask = 1,
			tex2 = 2,
			toScreen = 1,
		},
		uniformFloat = {
			ivsx = 0,
			ivsy = 0,
			blurScale = 1,
			tileSize = TILE_SIZE,
		},
	}, "guishader blurShader")

	if not shader:Initialize() then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: " .. gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return false
	end
	blurShader = shader
	toScreenUniform = shader.uniformLocations.toScreen

	shader = LuaShader({
		vertex = maskVertexShader,
		fragment = maskFragmentShader,

		uniformInt = {
			source = 0,
			blockSize = MASK_STEP,
		},
		uniformFloat = {
			threshold = 0.01,
		},
	}, "guishader tileMaskShader")

	if not shader:Initialize() then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader tileMaskShader: shader error: " .. gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return false
	end
	tileMaskShader = shader

	return true
end

function widget:Shutdown()
	DeleteResources()
	-- stops at the first shader that never compiled
	for _, shader in ipairs({ blurShader, tileMaskShader }) do
		shader:Finalize()
	end
	WG.guishader = nil
	widgetHandler:DeregisterGlobal("GuishaderInsertRect")
	widgetHandler:DeregisterGlobal("GuishaderRemoveRect")
end

function widget:DrawScreenEffects() -- This blurs the world underneath UI elements
	-- Before the early returns on purpose: when a modal window starts or stops hiding the
	-- interface, which regions belong in the stencil changes even though no widget
	-- registered or removed one, and the quit dialog's fullscreen blur skips the rest.
	local modalActive = widgetHandler:IsModalActive()
	local modalRevision = widgetHandler:GetModalRevision()
	if modalActive ~= lastModalActive or modalRevision ~= lastModalRevision then
		lastModalActive = modalActive
		lastModalRevision = modalRevision
		updateStencilTexture = true
		updateStencilTextureScreen = true
	end

	if spIsGUIHidden() or uiOpacity > 0.99 then
		return
	end

	if not screenBlur and blurShader then
		if not next(guishaderRects) and not next(guishaderDlists) then
			return
		end

		local screencopy
		if WG.screencopymanager and WG.screencopymanager.GetScreenCopy then
			screencopy = WG.screencopymanager.GetScreenCopy()
		else
			spEcho("Missing Screencopy Manager, exiting", WG.screencopymanager)
			widgetHandler:RemoveWidget()
			return false
		end

		if screencopy == nil then
			return
		end

		glTexture(false)
		glColor(1, 1, 1, 1)
		glBlending(true)

		if updateStencilTexture then
			DrawStencilTexture(true)
			updateStencilTexture = false
		end

		DrawBlur(screencopy, stenciltex, tileMask)
		glBlending(false)
	end
end

local function DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	if spIsGUIHidden() then
		return
	end

	local numDelete = #deleteDlistQueue
	if numDelete > 0 then
		for i = 1, numDelete do
			glDeleteList(deleteDlistQueue[i])
			deleteDlistQueue[i] = nil
		end
		updateStencilTexture = true
	end

	if (screenBlur or next(guishaderScreenRects) or next(guishaderScreenDlists)) and blurShader then
		glTexture(false)
		glColor(1, 1, 1, 1)
		glBlending(true)

		if updateStencilTextureScreen then
			DrawStencilTexture(false, screenBlur)
			UpdateScreenCopyRegion(screenBlur)
			updateStencilTextureScreen = false
		end

		if copyW > 0 then
			glCopyToTexture(blurTexB, copyX, copyY, vpx + copyX, vpy + copyY, copyW, copyH)
			DrawBlur(blurTexB, stenciltexScreen, tileMaskScreen)
		end
	end

	for k, v in pairs(renderDlists) do
		glColor(1, 1, 1, 1)
		glCallList(k)
	end
end

function widget:DrawScreen()
	uiOpacityCheckFrame = uiOpacityCheckFrame + 1
	if uiOpacityCheckFrame >= 30 then
		uiOpacityCheckFrame = 0
		uiOpacity = spGetConfigFloat("ui_opacity", 0.7)
	end
	DrawScreen()
end

function widget:UpdateCallIns()
	self:ViewResize(vsx, vsy)
end

-- some widgets re-register an unchanged rect every frame, that must not rebuild the stencil
local function sameRect(rect, left, top, right, bottom)
	return rect ~= nil and rect[1] == left and rect[2] == top and rect[3] == right and rect[4] == bottom
end

function widget:Initialize()
	if not CheckHardware() then
		return false
	end

	if not CreateShaders() then
		return
	end

	self:UpdateCallIns()

	WG.guishader = {}
	-- The trailing `owner` argument of the Insert functions is optional and only matters
	-- when a modal window hides the interface: pass the registering `widget` and the
	-- region follows that widget's visibility, otherwise it is dropped while a window is
	-- open. See the "Modal windows" block in barwidgets.lua.
	WG.guishader.InsertDlist = function(dlist, name, force, owner)
		if force or guishaderDlists[name] ~= dlist or dlistOwners[name] ~= owner then
			guishaderDlists[name] = dlist
			dlistOwners[name] = owner
			updateStencilTexture = true
		end
	end
	WG.guishader.RemoveDlist = function(name)
		local found = guishaderDlists[name] ~= nil
		if found then
			guishaderDlists[name] = nil
			dlistOwners[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG.guishader.DeleteDlist = function(name)
		local found = guishaderDlists[name] ~= nil
		if found then
			deleteDlistQueue[#deleteDlistQueue + 1] = guishaderDlists[name]
			guishaderDlists[name] = nil
			dlistOwners[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG.guishader.InsertRect = function(left, top, right, bottom, name, owner)
		if sameRect(guishaderRects[name], left, top, right, bottom) and rectOwners[name] == owner then
			return
		end
		guishaderRects[name] = { left, top, right, bottom }
		rectOwners[name] = owner
		updateStencilTexture = true
	end
	WG.guishader.RemoveRect = function(name)
		local found = guishaderRects[name] ~= nil
		if found then
			guishaderRects[name] = nil
			rectOwners[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG.guishader.InsertScreenDlist = function(dlist, name, owner)
		guishaderScreenDlists[name] = dlist
		screenDlistOwners[name] = owner
		updateStencilTextureScreen = true
	end
	WG.guishader.RemoveScreenDlist = function(name)
		local found = guishaderScreenDlists[name] ~= nil
		if found then
			guishaderScreenDlists[name] = nil
			screenDlistOwners[name] = nil
			updateStencilTextureScreen = true
		end
		return found
	end
	WG.guishader.DeleteScreenDlist = function(name)
		local found = guishaderScreenDlists[name] ~= nil
		if found then
			deleteDlistQueue[#deleteDlistQueue + 1] = guishaderScreenDlists[name]
			guishaderScreenDlists[name] = nil
			screenDlistOwners[name] = nil
		end
		return found
	end
	WG.guishader.InsertScreenRect = function(left, top, right, bottom, name, owner)
		if sameRect(guishaderScreenRects[name], left, top, right, bottom) and screenRectOwners[name] == owner then
			return
		end
		guishaderScreenRects[name] = { left, top, right, bottom }
		screenRectOwners[name] = owner
		updateStencilTextureScreen = true
	end
	WG.guishader.RemoveScreenRect = function(name)
		local found = guishaderScreenRects[name] ~= nil
		if found then
			guishaderScreenRects[name] = nil
			screenRectOwners[name] = nil
			updateStencilTextureScreen = true
		end
		return found
	end

	WG.guishader.setScreenBlur = function(value)
		updateStencilTextureScreen = true
		screenBlur = value
	end
	WG.guishader.getScreenBlur = function(value)
		return screenBlur
	end

	-- will let it draw a given dlist to be rendered on top of screenblur
	WG.guishader.insertRenderDlist = function(value)
		renderDlists[value] = true
	end
	WG.guishader.removeRenderDlist = function(value)
		if renderDlists[value] then
			renderDlists[value] = nil
		end
	end

	WG.guishader.DrawScreen = DrawScreen -- widgethandler won't call DrawScreen when chobby interface is shown, but it will call this one as exception

	widgetHandler:RegisterGlobal("GuishaderInsertRect", WG.guishader.InsertRect)
	widgetHandler:RegisterGlobal("GuishaderRemoveRect", WG.guishader.RemoveRect)
end

function widget:RecvLuaMsg(msg, playerID)
	if stringFind(msg, "LobbyOverlayActive", 1, true) == 1 then
		screenBlur = (stringFind(msg, "LobbyOverlayActive1", 1, true) == 1)
		updateStencilTextureScreen = true
	end
end
