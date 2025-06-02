local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "API Unit Tracker Tester GL4",
      desc      = "Tracks visibleunitslist",
      author    = "Beherith",
      date      = "2022.03.01",
      license   = "GNU GPL, v2 or later",
      layer     = -8288887,
      enabled   = false
   }
end

local myvisibleUnits = {} -- table of unitID : unitDefID

local unitTrackerVBO = nil
local unitTrackerShader = nil
local luaShaderDir = "LuaUI/Include/"
local texture = "luaui/images/solid.png"

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.TRANSPARENCY = 0.5	
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
	unitTrackerVBO, unitTrackerShader = InitDrawPrimitiveAtUnit(shaderConfig, "unitTrackerTester")
	if unitTrackerVBO == nil then 
		widgetHandler:RemoveWidget()
	end
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	Spring.Echo("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam)
	local teamID = Spring.GetUnitTeam(unitID) or 0 
	local gf = Spring.GetGameFrame()
	myvisibleUnits[unitID] = unitDefID
	pushElementInstance(
		unitTrackerVBO, -- push into this Instance VBO Table
		{
			96, 96, 8, 8,  -- lengthwidthcornerheight
			teamID, -- teamID
			12, -- how many trianges should we make (2 = cornerrect)
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
	Spring.Echo("widget:VisibleUnitsChanged",extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(unitTrackerVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do 
		widget:VisibleUnitAdded(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end

function widget:VisibleUnitRemoved(unitID)
	Spring.Echo("widget:VisibleUnitRemoved",unitID)
	if unitTrackerVBO.instanceIDtoIndex[unitID] then 
		popElementInstance(unitTrackerVBO, unitID)
		myvisibleUnits[unitID] = nil
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end

	if unitTrackerVBO.usedElements > 0 then
		gl.Texture(0, texture)
		unitTrackerShader:Activate()
		unitTrackerShader:SetUniform("iconDistance", 99999) -- pass
		unitTrackerShader:SetUniform("addRadius", 0)
		gl.DepthTest(true)
		gl.DepthMask(false)
		unitTrackerVBO.VAO:DrawArrays(GL.POINTS, unitTrackerVBO.usedElements)
		unitTrackerShader:Deactivate()
		gl.Texture(0, false)
	end
end

function widget:Initialize()
	initGL4()
end
