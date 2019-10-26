function widget:GetInfo()
   return {
      name      = "Unit energy icons",
      desc      = "",
      author    = "Floris",
      date      = "October 2019",
      license   = "GNU GPL, v2 or later",
      layer     = -40,
      enabled   = true
   }
end


local onlyShowOwnTeam = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glDrawFuncAtUnit			= gl.DrawFuncAtUnit

local spIsGUIHidden				= Spring.IsGUIHidden
local spGetUnitDefID			= Spring.GetUnitDefID
local spIsUnitInView 			= Spring.IsUnitInView
local spGetTeamUnits			= Spring.GetTeamUnits
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetTeamResources		= Spring.GetTeamResources
local spGetUnitResources		= Spring.GetUnitResources

local unitConf = {}
local teamEnergy = {}
local teamUnits = {}
local teamList = {}
local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local updateFrame = 0
local lastGameFrame = 0
local sceduledGameFrame = 1

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 6*( xsize^2 + zsize^2 )^0.5
		local buildingNeedingUpkeep = false
		local neededEnergy = 0
		if table.getn(unitDef.weapons) > 0 then
			for i=1, #unitDef.weapons do
				local weaponDefID = unitDef.weapons[i].weaponDef
				local weaponDef   = WeaponDefs[weaponDefID]
				if weaponDef and weaponDef.energyCost > neededEnergy then
                    neededEnergy = weaponDef.energyCost
				end
			end
		elseif unitDef.isBuilding and unitDef.energyUpkeep and unitDef.energyUpkeep > 0 and unitDef.energyUpkeep > unitDef.energyMake then
			neededEnergy = unitDef.energyUpkeep
			buildingNeedingUpkeep = true
		end
		if neededEnergy > 0 then
			unitConf[udid] = {7 +(scale/2.5), neededEnergy, buildingNeedingUpkeep}
		end
	end
end

function init()
	spec, fullview = Spring.GetSpectatingState()
end

function widget:Initialize()
	SetUnitConf()

	WG['unitenergyicons'] = {}
	WG['unitenergyicons'].setOnlyShowOwnTeam = function(value)
		onlyShowOwnTeam = value
	end
	WG['unitenergyicons'].getOnlyShowOwnTeam = function(value)
		return onlyShowOwnTeam
	end

	init()
end

function widget:PlayerChanged(playerID)
	local prevMyTeamID = myTeamID
	myTeamID = Spring.GetMyTeamID()
	if myTeamID ~= prevMyTeamID then
		doUpdate()
	end
	init()
end

function doUpdate()
	teamUnits = {}
	for i, teamID in pairs(teamList) do
		if (fullview and not onlyShowOwnTeam) or not onlyShowOwnTeam or teamID == myTeamID then
			teamUnits[teamID] = {}
			local teamUnitsRaw = spGetTeamUnits(teamID)
			for i=1, #teamUnitsRaw do
				local unitID = teamUnitsRaw[i]
				local unitDefID = spGetUnitDefID(unitID)
				if unitConf[unitDefID] and spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
					teamUnits[teamID][unitID] = unitDefID
				end
			end
		end
	end
	sceduledGameFrame = Spring.GetGameFrame() + 33
end

function widget:Update(dt)
	updateFrame = updateFrame + 1
	if spec then
		fullview = select(2,Spring.GetSpectatingState())
		myTeamID = Spring.GetMyTeamID()
	end
	if Spring.GetGameFrame() ~= lastGameFrame then
		lastGameFrame = Spring.GetGameFrame()
		if onlyShowOwnTeam then
			teamList = Spring.GetTeamList(Spring.GetMyAllyTeamID())
		else
			teamList = Spring.GetTeamList()
		end
		teamEnergy = {}
		for i, teamID in pairs(teamList) do --onlyShowOwnTeam and myTeamID or nil
			if (fullview and not onlyShowOwnTeam) or not onlyShowOwnTeam or teamID == myTeamID then
				teamEnergy[teamID] = select(1, spGetTeamResources(teamID, 'energy'))
			end
		end
	end
	if Spring.GetGameFrame() >= sceduledGameFrame then
		doUpdate()
	end
end

function widget:UnitTaken(unitID, unitDefID, teamID, newTeamID)
	if unitConf[unitDefID] and spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
		if teamUnits[teamID] then
			teamUnits[teamID][unitID] = nil
		end
		if teamUnits[newTeamID] then
			teamUnits[newTeamID][unitID] = unitDefID
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, teamID, oldTeamID)
	if unitConf[unitDefID] and spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
		if teamUnits[oldTeamID] then
			teamUnits[oldTeamID][unitID] = nil
		end
		if teamUnits[teamID] then
			teamUnits[teamID][unitID] = unitDefID
		end

	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if teamUnits[teamID] then
		teamUnits[teamID][unitID] = nil
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function DrawIcon(size, self)
	gl.Color(1,0,0, (self and 0.7 or 0.4))
	gl.Texture(':n:LuaUI/Images/energy2.png')
	gl.Translate(0,size*3,0)
	gl.Billboard()
	gl.TexRect(-(size*0.5), -(size*0.5), (size*0.5), (size*0.5))
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	gl.DepthTest(true)
    gl.Color(1,0,0,0.85)

	for teamID, units in pairs(teamUnits) do
		for unitID, unitDefID in pairs(units) do
			if unitConf[unitDefID] and unitConf[unitDefID][2] > teamEnergy[teamID] and (not unitConf[unitDefID][3] or  ((unitConf[unitDefID][3] and (select(4, spGetUnitResources(unitID))) or 999999) < unitConf[unitDefID][2])) then
				if spIsUnitInView(unitID) then
					glDrawFuncAtUnit(unitID, false, DrawIcon, unitConf[unitDefID][1], (teamID == myTeamID))
				end
			end
		end
	end

	gl.Color(1,1,1,1)
	gl.Texture(false)
	gl.DepthTest(false)
end


function widget:GetConfigData(data)
	savedTable = {}
	savedTable.onlyShowOwnTeam = onlyShowOwnTeam
	return savedTable
end

function widget:SetConfigData(data)
	if data.onlyShowOwnTeam ~= nil then
		onlyShowOwnTeam = data.onlyShowOwnTeam
	end
end
