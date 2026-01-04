local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Resurrection Halos GL4",
      desc      = "Gives units have have been resurrected a little halo above it",
      author    = "Beherith",
      date      = "2022.03.05",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end

local resurrectionHalosVBO = nil
local resurrectionHalosShader = nil
local luaShaderDir = "LuaUI/Include/"

local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

local texture = 'LuaUI/Images/halo.dds'
local chobbyInterface

local OPTIONS = {
	haloSize				= 0.8,
	haloDistance			= 2.0,
	skipBuildings			= true,
}

local unitConf = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if not OPTIONS.skipBuildings or (OPTIONS.skipBuildings and not (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0)) then
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 3*( xsize*xsize + zsize*zsize )^0.5
		unitConf[unitDefID] = {scale=scale, iconSize=scale*OPTIONS.haloSize, height=math.ceil((unitDef.height+(OPTIONS.haloDistance * (scale/7))))}
	end
end

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.TRANSPARENCY = 0.5
	shaderConfig.ANIMATION = 1
	shaderConfig.HEIGHTOFFSET = 3.99
	shaderConfig.BREATHERATE = 15.0 -- how fast it periodicly grows
	shaderConfig.BREATHESIZE = 0.075 -- how much it periodicly grows
	shaderConfig.MAXVERTICES = 4 -- how much it periodicly grows
	shaderConfig.INITIALSIZE = 0.5 -- What size the stuff starts off at when spawned
	shaderConfig.GROWTHRATE = 15 -- How fast it grows to full size
	shaderConfig.POST_SHADING = "fragColor.rgba = texcolor;"

	resurrectionHalosVBO, resurrectionHalosShader = InitDrawPrimitiveAtUnit(shaderConfig, "ResurrectionHalos")
	if resurrectionHalosVBO == nil then 
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	local rezRulesParam = Spring.GetUnitRulesParam(unitID, "resurrected")
	if unitConf[unitDefID] == nil or not rezRulesParam or rezRulesParam == 0 then return end

	local gf = Spring.GetGameFrame()
	pushElementInstance(
		resurrectionHalosVBO, -- push into this Instance VBO Table
		{
			unitConf[unitDefID].iconSize, unitConf[unitDefID].iconSize, 8, unitConf[unitDefID].height ,  -- lengthwidthcornerheight
			0, -- teamID
			4, -- how many trianges should we make (2 = cornerrect)
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you are doing
		unitID -- last one should be UNITID?
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(resurrectionHalosVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end

function widget:VisibleUnitRemoved(unitID)
	--Spring.Echo("widget:VisibleUnitRemoved",unitID)
	if resurrectionHalosVBO.instanceIDtoIndex[unitID] then
		popElementInstance(resurrectionHalosVBO, unitID)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then
		return
	end

	if resurrectionHalosVBO.usedElements > 0 then
		gl.Texture(0, texture)
		resurrectionHalosShader:Activate()
		resurrectionHalosShader:SetUniform("iconDistance", 99999) -- pass
		resurrectionHalosShader:SetUniform("addRadius", 0)
		gl.DepthTest(true)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		resurrectionHalosVBO.VAO:DrawArrays(GL.POINTS, resurrectionHalosVBO.usedElements)
		resurrectionHalosShader:Deactivate()
		gl.Texture(0, false)
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then return end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID)
		end
	end
end
