--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "LOS View GL4",
		version = 3,
		desc = "Draws LOS view into screencopy",
		author = "Beherith",
		date = "2024.11.19",
		license = "GPL V2",
		layer = -10000, -- lol this isn't even a number
		enabled = false,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

local glBlending = gl.Blending
local glCulling = gl.Culling
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture

--------------------------------------------------------------------------------
--- TODO:
---	- [ ] Customize grid
--- - [ ] Ensure draw order is correct after decals_gl4
--- - [ ] Mark los edge with white line
--- - [ ] Mark radar edge with stippled green line
--- - [ ] Find a nice noise approach
--- - [ ] Implement desat-darken approach
--- - [ ] scanlines dont work underwater if drawn preunit :'(
--- - [ ] If drawn postunit, then ghosts are shaded incorrectly
---
---
--------------------------------------------------------------------------------

local autoreload = false

local shaderConfig = {
	DEBUG = autoreload and 1 or 0,
	PREUNIT = 1, -- 1 for preunit, 0 for postunit
}

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local losViewShader = nil
local fullScreenQuadVAO = nil
local losViewShaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/infolos_view.vert.glsl",
	fssrcpath = "LuaUI/Shaders/infolos_view.frag.glsl",
	uniformFloat = {
		blendfactors = { 1, 1, 1, 1 },
	},
	uniformInt = {
		mapDepths = 0,
		modelDepths = 1,
		screenCopyTex = 2,
		losTex = 3,
	},
	shaderName = "LosViewShader GL4",
	shaderConfig = shaderConfig,
}

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not WG.infolosapi then
		spEcho("Los View GL4: Missing InfoLOS API")
		widgetHandler:RemoveWidget()
		return
	end
	if not WG.screencopymanager then
		spEcho("Los View GL4: Missing Screencopy Manager")
		widgetHandler:RemoveWidget()
		return
	end

	losViewShader = LuaShader.CheckShaderUpdates(losViewShaderSourceCache) -- this compiles it
	if not losViewShader then
		spEcho("Failed to compile losViewShader GL4")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenQuadVAO = InstanceVBOTable.MakeTexRectVAO() --  -1, -1, 1, 0,   0,0,1, 0.5)
	WG.infolosapi.GetInfoLOSTexture() -- starts the API's updates before our first draw
end

function widget:Shutdown()
	if losViewShader then
		losViewShader:Finalize()
		losViewShader = nil
	end
end

function widget:DrawPreDecals()
	if autoreload then
		losViewShader = LuaShader.CheckShaderUpdates(losViewShaderSourceCache) or losViewShader
	end
	local infolosapi, screencopymanager = WG.infolosapi, WG.screencopymanager
	if not (infolosapi and screencopymanager) then
		return
	end
	screencopymanager.InvalidateScreenCopy() -- a copy taken earlier this frame would not hold the map yet
	local screenCopy = screencopymanager.GetScreenCopy()
	if not screenCopy then -- the manager's very first copy comes back nil
		return
	end

	glTexture(0, "$map_gbuffer_zvaltex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, screenCopy)
	glTexture(3, infolosapi.GetInfoLOSTexture()) -- the local allyteam's
	glBlending(false) -- the shader writes alpha 1, blending would only read the screen back
	glCulling(false) -- ffs
	glDepthTest(false)
	glDepthMask(false) --"BK OpenGL state resets", default is already false, could remove

	losViewShader:Activate()
	fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
	losViewShader:Deactivate()
	screencopymanager.InvalidateScreenCopy() -- later readers of the copy (guishader, CAS) need the shaded screen
	glDepthTest(true)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	for i = 0, 3 do
		glTexture(i, false)
	end
end

if autoreload then
	function widget:DrawScreen()
		if losViewShader.DrawPrintf then
			losViewShader.DrawPrintf()
		end
	end
end
