function widget:GetInfo()
	return {
		name = "Info Metal View",
		version = 3,
		desc = "Draws Metal Amount and Metal Extraction maps",
		author = "Beherith",
		date = "2024.12.22",
		license = "GPL V2",
		layer = 10001, 
		enabled = true,
		depends = {"shaders"},
	}
end

-- Author: Beherith (mysterme@gmail.com)
-- TODO:
-- [x] USE BICUBIC SAMPLER! 
    -- nope, tried, suxx
-- [x] Flip minimap?
-- [x] calc tex sizes from map size
-- [ ] override F4 keysym
-- [ ] fade alpha in

local autoreload = true
local alpha = 0.75

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped

local fullScreenQuadVAO
local infoMetalShader

local shaderSourceCache =  {
	vssrcpath = "LuaUI/Widgets/Shaders/info_metal.vert.glsl",
	fssrcpath = "LuaUI/Widgets/Shaders/info_metal.frag.glsl",
	uniformInt = {
        metalTex = 0, 
        metalExtractionTex = 1,
        mapDepths = 2,
	},
    uniformFloat = {
        alpha = 0.5,
        minimap = 0,
        flipMiniMap = getMiniMapFlipped() and 1 or 0,
    },
    shaderName = "Info Metal View GL4",
	shaderConfig = {
        METALTEXX = Game.mapSizeX/16,
        METALTEXY = Game.mapSizeZ/16,
    },
}

local callins = {'DrawWorldPreUnit', 'DrawInMiniMapBackground'}
if autoreload then
	callins[#callins+1] = 'DrawScreen'
end

local viewEnabled = true -- will disable at Initialize

local function ShowInfoMetal(cmd, line, words, playerID)
	if #words > 0 then
		local enabled = (words[1] == '1')
		if enabled == viewEnabled then return end

		viewEnabled = enabled
	else
		viewEnabled = not viewEnabled
	end
	for _, callinName in pairs(callins) do
		if viewEnabled then
			widgetHandler:UpdateCallIn(callinName)
		else
			widgetHandler:RemoveCallIn(callinName)
		end
	end
	WG.metalView = viewEnabled
end

function widget:Initialize()
	WG.metalView = false
	infoMetalShader =  LuaShader.CheckShaderUpdates(shaderSourceCache)
	shaderCompiled = infoMetalShader:Initialize()
	if not shaderCompiled then Spring.Echo("Failed to compile Info Metal View GL4") end

	fullScreenQuadVAO = MakeTexRectVAO()--  -1, -1, 1, 0,   0,0,1, 0.5

	widgetHandler:AddAction("showinfometal", ShowInfoMetal, nil, "t") -- 'p' is coming from somewhere else
	ShowInfoMetal(nil, nil, {"0"})
end

function widget:Shutdown()
	widgetHandler:RemoveAction("showinfometal")
end

function DrawInfoMetal(inminimap)
    gl.Texture(0, "$info:metal")
    gl.Texture(1, "$info:metalextraction")
    if not inminimap then
        gl.Texture(2, "$map_gbuffer_zvaltex")
    end
    
    gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    gl.Culling(false) -- ffs
    gl.DepthTest(false)
    gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
    infoMetalShader:Activate()
    infoMetalShader:SetUniformFloat("alpha", alpha)
    infoMetalShader:SetUniformFloat("minimap", inminimap and 1 or 0)
    infoMetalShader:SetUniformFloat("flipMiniMap", getMiniMapFlipped() and 1 or 0)
    fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
    infoMetalShader:Deactivate()
    gl.DepthTest(true)
    gl.Texture(0, false)
    gl.Texture(1, false)
    if not inminimap then 
        gl.Texture(2, false)
    end
end

function widget:DrawWorldPreUnit()
    if autoreload then
        infoMetalShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or infoMetalShader
    end
    DrawInfoMetal(false)
end

function widget:DrawInMiniMapBackground()
    DrawInfoMetal(true)
end

function widget:DrawScreen()
    if infoMetalShader.DrawPrintf then infoMetalShader.DrawPrintf() end
end
