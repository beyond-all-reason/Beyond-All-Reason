function widget:GetInfo()
   return {
      name      = "Unit Energy Icons", -- GL4
      desc      = "Shows the lack of energy symbol above units",
      author    = "Floris, Beherith",
      date      = "October 2019",
      license   = "GNU GPL, v2 or later",
      layer     = -40,
      enabled   = true
   }
end

local weaponEnergyCostFloor = 6

local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetTeamResources		= Spring.GetTeamResources
local spGetUnitResources		= Spring.GetUnitResources
local spGetUnitTeam		        = Spring.GetUnitTeam

local teamEnergy = {} -- table of teamid to current energy amount
local teamUnits = {} -- table of teamid to table of stallable unitID : unitDefID
local teamList = {} -- {team1, team2, team3....}

local spec, fullview = Spring.GetSpectatingState()
local lastGameFrame = 0

local chobbyInterface

local unitConf = {} -- table of unitid to {iconsize, iconheight, neededEnergy, bool buildingNeedingUpkeep}
local maxStall = 0
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 6*( xsize^2 + zsize^2 )^0.5
	local buildingNeedingUpkeep = false
	local neededEnergy = 0
	local weapons = unitDef.weapons
	if #weapons > 0 then
		for i=1, #weapons do
			local weaponDefID = weapons[i].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if weaponDef then
				if weaponDef.stockpile then
					neededEnergy = math.floor(weaponDef.energyCost / (weaponDef.stockpileTime/30))
				elseif weaponDef.energyCost > neededEnergy and weaponDef.energyCost >= weaponEnergyCostFloor then
					neededEnergy = weaponDef.energyCost
				end
			end
		end
	elseif unitDef.isBuilding and unitDef.energyUpkeep and unitDef.energyUpkeep > 0 and unitDef.energyUpkeep > unitDef.energyMake then
		neededEnergy = unitDef.energyUpkeep
		buildingNeedingUpkeep = true
	end
	if neededEnergy > 0 then
		unitConf[udid] = {7.5 +(scale/2.2), unitDef.height, neededEnergy, buildingNeedingUpkeep}
	end
	maxStall = math.max(maxStall, neededEnergy)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- how shit should work
-- init
	--stallable unitdefs
	--count maxstall amount
	--unitdefheights
	--unitdefscales

-- on unitcreated:
	-- per team
	-- if unit is stallable, add to watch list
	-- update maxstall
-- on destroyed:
	-- per team
	-- if unit in stallable list, remove from it
	-- if unit in stalling list, pop it
	-- update maxstall?
-- on slow update:
	-- for each team
		-- check if energy < maxstall
		-- check if unit is under construction
		-- check all stalling units if they are still stalling
			-- pop if not stalling any more
		-- check stallable units if they now stall
			-- push if stalling
		-- additional smartness for global stall/unstall

-- GL4 Backend stuff:
local energyIconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

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
	shaderConfig.BREATHESIZE = 0.1
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 32 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	energyIconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if energyIconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateTeamEnergy()
	for i, teamID in pairs(teamList) do
		teamEnergy[teamID] = select(1, spGetTeamResources(teamID, 'energy'))
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	spec, fullview = Spring.GetSpectatingState()
	if spec then
		fullview = select(2,Spring.GetSpectatingState())
	end
	if not fullview then
		teamList = Spring.GetTeamList(Spring.GetMyAllyTeamID())
	else
		teamList = Spring.GetTeamList()
	end

	UpdateTeamEnergy()
	clearInstanceTable(energyIconVBO) -- clear all instances
	teamUnits = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
	uploadAllElements(energyIconVBO) -- upload them all
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then return end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

local function updateStalling()
	local gf = Spring.GetGameFrame()
	for teamID, units in pairs(teamUnits) do
		--Spring.Echo('teamID',teamID)
		if teamEnergy[teamID] and teamEnergy[teamID] < maxStall then
			for unitID, unitDefID in pairs(units) do
				if teamEnergy[teamID] and unitConf[unitDefID][3] > teamEnergy[teamID] and -- more neededEnergy than we have
					(not unitConf[unitDefID][4] or ((unitConf[unitDefID][4] and (select(4, spGetUnitResources(unitID))) or 999999) < unitConf[unitDefID][3])) then

					if not Spring.GetUnitIsBeingBuilt(unitID) and
						energyIconVBO.instanceIDtoIndex[unitID] == nil then -- not already being drawn
						if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
							pushElementInstance(
								energyIconVBO, -- push into this Instance VBO Table
									{unitConf[unitDefID][1], unitConf[unitDefID][1], 0, unitConf[unitDefID][2],  -- lengthwidthcornerheight
									0, --Spring.GetUnitTeam(featureID), -- teamID
									4, -- how many vertices should we make ( 2 is a quad)
									gf, 0, 0.75 , 0, -- the gameFrame (for animations), and any other parameters one might want to add
									0,1,0,1, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
									0, 0, 0, 0}, -- these are just padding zeros, that will get filled in
								unitID, -- this is the key inside the VBO Table, should be unique per unit
								false, -- update existing element
								true, -- noupload, dont use unless you know what you want to batch push/pop
								unitID) -- last one should be featureID!
						end
					end
				elseif energyIconVBO.instanceIDtoIndex[unitID] then
					popElementInstance(energyIconVBO, unitID, true)
				end
			end
		end
	end
	if energyIconVBO.dirty then
		uploadAllElements(energyIconVBO)
	end
end

function widget:Update(dt)
	if Spring.GetGameFrame() ~= lastGameFrame then
		lastGameFrame = Spring.GetGameFrame()
		UpdateTeamEnergy()
	end
end

function widget:GameFrame(n)
	if Spring.GetGameFrame() %9 == 0 then
		updateStalling()
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam) -- remove the corresponding ground plate if it exists
	if unitConf[unitDefID] and not Spring.GetUnitIsBeingBuilt(unitID) then
		if teamUnits[unitTeam] == nil then teamUnits[unitTeam] = {} end
		teamUnits[unitTeam][unitID] = unitDefID
	end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	local unitTeam = spGetUnitTeam(unitID)
	if teamUnits[unitTeam] then
		teamUnits[unitTeam][unitID] = nil
	end
	if energyIconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(energyIconVBO, unitID)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end

	if energyIconVBO.usedElements > 0 then
		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
		gl.DepthTest(true)
		gl.DepthMask(false)
		gl.Texture('LuaUI/Images/energy-red.png')
		energyIconShader:Activate()
		energyIconShader:SetUniform("iconDistance",disticon)
		energyIconShader:SetUniform("addRadius",0)
		energyIconVBO.VAO:DrawArrays(GL.POINTS,energyIconVBO.usedElements)
		energyIconShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(true)
	end
end
