function widget:GetInfo()
   return {
      name      = "Unit energy icons",
      desc      = "",
      author    = "Floris",
      date      = "October 2019",
      layer     = -40,
      enabled   = true
   }
end

local weaponEnergyCostFloor = 6
local onlyShowOwnTeam = false
local fadeTime = 0.4

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
local math_min = math.min

local unitConf = {}
local teamEnergy = {}
local teamUnits = {}
local teamList = {}
local unitIconTimes = {}
local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local updateFrame = 0
local lastGameFrame = 0
local sceduledGameFrame = 1

local chobbyInterface

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
	end
end

function init()
	spec, fullview = Spring.GetSpectatingState()
end

function widget:Initialize()
	WG['unitenergyicons'] = {}
	WG['unitenergyicons'].setOnlyShowOwnTeam = function(value)
		onlyShowOwnTeam = value
	end
	WG['unitenergyicons'].getOnlyShowOwnTeam = function(value)
		return onlyShowOwnTeam
	end
    SetUnitConf()
	init()
end

function widget:PlayerChanged(playerID)
	local prevMyTeamID = myTeamID
	myTeamID = Spring.GetMyTeamID()
	if myTeamID ~= prevMyTeamID then
        unitIconTimes = {}
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
        unitIconTimes[unitID] = nil
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
        unitIconTimes[unitID] = nil
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if teamUnits[teamID] then
		teamUnits[teamID][unitID] = nil
        unitIconTimes[unitID] = nil
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function DrawIcon(size, height, self, mult)
	gl.Color(1,0,0, 0.66 * (mult or 1))
	gl.Texture('LuaUI/Images/energy.png')
	gl.Translate(0,5+height+(size*0.5),0)
	gl.Billboard()
	gl.TexRect(-(size*0.5), -(size*0.5), (size*0.5), (size/2))
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

    local now = os.clock()

	gl.DepthTest(true)
    gl.Color(1,0,0,0.85)

	for teamID, units in pairs(teamUnits) do
		for unitID, unitDefID in pairs(units) do
            if teamEnergy[teamID] and unitConf[unitDefID][3] > teamEnergy[teamID] and (not unitConf[unitDefID][4] or ((unitConf[unitDefID][4] and (select(4, spGetUnitResources(unitID))) or 999999) < unitConf[unitDefID][3])) then
                if not unitIconTimes[unitID] then
                    unitIconTimes[unitID] = now
                end
                if spIsUnitInView(unitID) then
                    local mult = math_min(1, (now-unitIconTimes[unitID])/fadeTime)
                    glDrawFuncAtUnit(unitID, false, DrawIcon, unitConf[unitDefID][1], unitConf[unitDefID][2], (teamID == myTeamID), mult)
                end
            elseif unitIconTimes[unitID] then
                if (now-unitIconTimes[unitID])/(fadeTime*0.4) > 1.1 then
                    unitIconTimes[unitID] = now
                end
                local mult = 1 - math_min(1, (now-unitIconTimes[unitID])/(fadeTime*0.4))
                if mult > 0 then
                    glDrawFuncAtUnit(unitID, false, DrawIcon, unitConf[unitDefID][1], unitConf[unitDefID][2], (teamID == myTeamID), mult)
                else
                    unitIconTimes[unitID] = nil
                end
            end
		end
	end

	gl.Color(1,1,1,1)
	gl.Texture(false)
	gl.DepthTest(false)
end


function widget:GetConfigData(data)
	return {onlyShowOwnTeam = onlyShowOwnTeam}
end

function widget:SetConfigData(data)
	if data.onlyShowOwnTeam ~= nil then
		onlyShowOwnTeam = data.onlyShowOwnTeam
	end
end
