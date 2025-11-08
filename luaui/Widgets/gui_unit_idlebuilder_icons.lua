local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Unit Idle Builder Icons",
      desc      = "Shows the sleeping icon above workers that are idle",
      author    = "Floris, Beherith",
      date      = "June 2024",
      license   = "GNU GPL, v2 or later",
      layer     = -40,
      enabled   = true
   }
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local onlyOwnTeam = true

local idleUnitDelay = 8	-- how long a unit must be idle before the icon shows up

local iconSequenceImages = 'Luaui/Images/idleicon/idlecon_' 	-- must be png's
local iconSequenceNum = 59	-- always starts at 1
local iconSequenceFrametime = 0.02	-- duration per frame

local unitScope = {} -- table of teamid to table of stallable unitID : unitDefID
local idleUnitList = {}

local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitTeam = Spring.GetUnitTeam
local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

local unitConf = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams
	if not (cp.virtualunit == "1") then
		if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and not string.find(unitDef.name, 'infestor') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase then
			local xsize, zsize = unitDef.xsize, unitDef.zsize
			local scale = 3.3 * ( (xsize+2)^2 + (zsize+2)^2 )^0.5
			unitConf[unitDefID] = {7.5 +(scale/2.2), unitDef.height-0.1, unitDef.isFactory}
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GL4 Backend stuff:

local InstanceVBOTable = gl.InstanceVBOTable

local uploadAllElements   = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

local iconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Include/"

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.75
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0--0.1
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	iconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if iconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(iconVBO) -- clear all instances
	unitScope = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	uploadAllElements(iconVBO) -- upload them all
end


function widget:Initialize()
	if spec or not gl.CreateShader or  not initGL4() then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end


local function updateIcons()
	local gf = spGetGameFrame()
	local queue
	for unitID, unitDefID in pairs(unitScope) do
		queue = unitConf[unitDefID][3] and spGetFactoryCommands(unitID, 0) or spGetUnitCommandCount(unitID, 0)
		if queue == 0 then
			if iconVBO.instanceIDtoIndex[unitID] == nil then -- not already being drawn
				if spValidUnitID(unitID) and not spGetUnitIsDead(unitID) and not spGetUnitIsBeingBuilt(unitID) then
					if not idleUnitList[unitID] then
						idleUnitList[unitID] = os.clock()
					elseif idleUnitList[unitID] < os.clock() - idleUnitDelay then
						pushElementInstance(
							iconVBO, -- push into this Instance VBO Table
							{unitConf[unitDefID][1], unitConf[unitDefID][1], 0, unitConf[unitDefID][2],  -- lengthwidthcornerheight
							 0, --Spring.GetUnitTeam(featureID), -- teamID
							 4, -- how many vertices should we make ( 2 is a quad)
							 gf, 0, 0.8 , 0, -- the gameFrame (for animations), and any other parameters one might want to add
							 1,0,1,0, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
							 0, 0, 0, 0}, -- these are just padding zeros, that will get filled in
							unitID, -- this is the key inside the VBO Table, should be unique per unit
							false, -- update existing element
							true, -- noupload, dont use unless you know what you want to batch push/pop
							unitID) -- last one should be featureID!
					end
				end
			end
		else
			if iconVBO.instanceIDtoIndex[unitID] then
				popElementInstance(iconVBO, unitID, true)
			end
			idleUnitList[unitID] = nil
		end
	end
	if iconVBO.dirty then
		uploadAllElements(iconVBO)
	end
end

function widget:GameFrame(n)
	if spGetGameFrame() % 25 == 0 then
		updateIcons()
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- remove the corresponding ground plate if it exists
	if (not onlyOwnTeam or myTeamID == unitTeam) and unitConf[unitDefID] then
		unitScope[unitID] = unitDefID
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	unitScope[unitID] = nil
	if iconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(iconVBO, unitID)
	end
	idleUnitList[unitID] = nil
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	if iconVBO.usedElements > 0 then
		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
		gl.DepthTest(true)
		gl.DepthMask(false)
		local clock = os.clock() * (1*(iconSequenceFrametime*iconSequenceNum))	-- adjust speed relative to anim frame speed of 0.02sec per frame (59 frames in total)
		local animFrame = math.max(1, math.ceil(iconSequenceNum * (clock - math.floor(clock))))
		gl.Texture(iconSequenceImages .. (animFrame < 100 and '0' or '') .. (animFrame < 10 and '0' or '') .. animFrame .. '.png')
		energyIconShader:Activate()
		energyIconShader:SetUniform("iconDistance",disticon)
		energyIconShader:SetUniform("addRadius",0)
		iconVBO.VAO:DrawArrays(GL.POINTS,iconVBO.usedElements)
		energyIconShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(true)
	end
end
