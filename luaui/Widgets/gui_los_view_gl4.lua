
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name = "LOS View GL4",
		version = 3,
		desc = "Draws LOS view into screencopy",
		author = "Beherith",
		date = "2024.11.19",
		license = "GPL V2",
		layer = -10000, -- lol this isnt even a number
		enabled = false
	}
end

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

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local currentAllyTeam = 0
local ScreenCopyTexture = nil
local vsx, vsy, vpx, vpy
local losViewShader = nil
local fullScreenQuadVAO = nil
local losViewShaderSourceCache = {
		vssrcpath = "LuaUI/Shaders/infolos_view.vert.glsl",
		fssrcpath = "LuaUI/Shaders/infolos_view.frag.glsl",
		uniformFloat = {
			blendfactors = {1,1,1,1},
		},
		uniformInt = {
			mapDepths = 0,
			modelDepths = 1,
			screenCopyTex = 2,
			losTex = 3,
		},
		shaderName = "LosViewShader GL4",
		shaderConfig = shaderConfig
	}


function widget:PlayerChanged(playerID)
	currentAllyTeam = Spring.GetMyAllyTeamID()
end

function widget:ViewResize()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	if ScreenCopyTexture then gl.DeleteTexture(ScreenCopyTexture) end
	ScreenCopyTexture = gl.CreateTexture(vsx  , vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
		format = GL.RGBA8, -- more than enough
	})
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
    if not WG['infolosapi'] then
        Spring.Echo("Los View GL4: Missing InfoLOS API")
        widgetHandler:RemoveWidget()
        return
    end

    widget:ViewResize()
    losViewShader = LuaShader.CheckShaderUpdates(losViewShaderSourceCache)
    fullScreenQuadVAO = MakeTexRectVAO()--  -1, -1, 1, 0,   0,0,1, 0.5)
    losViewShader:Initialize()
    if not losViewShader then Spring.Echo("Failed to compile losViewShader GL4") end
end

function widget:Shutdown()
	if ScreenCopyTexture then gl.DeleteTexture(ScreenCopyTexture) end
end

function widget:DrawPreDecals()
    if autoreload then
        losViewShader = LuaShader.CheckShaderUpdates(losViewShaderSourceCache) or losViewShader
    end
    
    gl.CopyToTexture(ScreenCopyTexture, 0, 0, vpx, vpy, vsx, vsy)
    gl.Texture(0, "$map_gbuffer_zvaltex")
    gl.Texture(1, "$model_gbuffer_zvaltex")
    gl.Texture(2, ScreenCopyTexture)
    gl.Texture(3, WG['infolosapi'].GetInfoLOSTexture(currentAllyTeam))
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.Culling(false) -- ffs
    gl.DepthTest(false)
    gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove

    losViewShader:Activate()
    losViewShader:SetUniformFloat("blendfactors", {1,1,1,1})
    fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
    losViewShader:Deactivate()
    gl.DepthTest(true)
    for i = 0,3 do gl.Texture(i, false) end
end

if autoreload then 
    function widget:DrawScreen()
        if losViewShader.DrawPrintf then losViewShader.DrawPrintf() end
    end
end