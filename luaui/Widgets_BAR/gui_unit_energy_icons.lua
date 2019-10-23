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
local spIsUnitAllied			= Spring.IsUnitAllied
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spGetTeamResources		= Spring.GetTeamResources

local unitConf = {}
local teamEnergy = {}
local spec, fullview = Spring.GetSpectatingState()
local lastUpdateGameFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetMyTeamID()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function SetUnitConf()
	for udid, unitDef in pairs(UnitDefs) do
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 6*( xsize^2 + zsize^2 )^0.5
		local neededEnergy = 0
		if table.getn(unitDef.weapons) > 0 then
			for i=1, #unitDef.weapons do
				local weaponDefID = unitDef.weapons[i].weaponDef
				local weaponDef   = WeaponDefs[weaponDefID]
				if weaponDef and weaponDef.energyCost > neededEnergy then
                    neededEnergy = weaponDef.energyCost
				end
			end
		end
		if neededEnergy > 0 then
			unitConf[udid] = {7 +(scale/2.5), neededEnergy}
		end
	end
end

function init()
	spec, fullview = Spring.GetSpectatingState()
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	init()
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


function widget:Update(dt)
	if spec then
		fullview = select(2,Spring.GetSpectatingState())
		myTeamID = Spring.GetMyTeamID()
	end
	if lastUpdateGameFrame ~= Spring.GetGameFrame() then
		lastUpdateGameFrame = Spring.GetGameFrame()
		teamEnergy = {}
		local teamList
		if onlyShowOwnTeam then
			teamList = Spring.GetTeamList(Spring.GetMyAllyTeamID())
		else
			teamList = Spring.GetTeamList()
		end
		for i, teamID in pairs(teamList) do --onlyShowOwnTeam and myTeamID or nil
			if (fullview and not onlyShowOwnTeam) or not onlyShowOwnTeam or teamID == myTeamID then
				teamEnergy[teamID] = select(1, spGetTeamResources(teamID, 'energy'))
			end
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function DrawIcon(size, self)
	gl.Color(1,0,0, (self and 0.7 or 0.4))
	gl.Texture(':n:LuaUI/Images/energy.png')
	gl.Translate(0,size*3,0)
	gl.Billboard()
	gl.TexRect(-(size*0.5), -(size*0.5), (size*0.5), (size*0.5))
end

function widget:DrawWorld()
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	gl.DepthTest(true)

    gl.Color(1,0,0,0.85)

	for teamID, availibleEnergy in pairs(teamEnergy) do
		local units = spGetTeamUnits(teamID)
		for i=1, #units do
			local unitID = units[i]
			local unitDefID = spGetUnitDefID(unitID)
			if unitConf[unitDefID] and unitConf[unitDefID][2] > availibleEnergy then
				if spIsUnitInView(unitID) then
					if spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
						if fullview or spIsUnitAllied(unitID) then
							local unitScale = unitConf[unitDefID][1]
							glDrawFuncAtUnit(unitID, false, DrawIcon, unitScale, (teamID == myTeamID))
						end
					end
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