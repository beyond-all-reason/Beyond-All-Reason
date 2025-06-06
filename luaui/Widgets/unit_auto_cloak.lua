local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Auto Cloak Units",
		desc      = "Auto cloaks Units with Cloak",
		author    = "wilkubyk",
		date      = "2022.12.29",
		license   = "GNU GPL, v2 or later",
		layer     = -99999,
		enabled   = true
	}
end

-- defaults
local unitdefConfigNames = {
	['armdecom'] = false,
	['cordecom'] = false,
	['armferret'] = false,
	['armamb'] = false,
	['armpb'] = false,
	['armsnipe'] = false,
	['corsktl'] = false,
	['armgremlin'] = true,
	['armamex'] = true,
	['armshockwave'] = true,
	['armckfus'] = true,
	['armspy'] = true,
	['corspy'] = true,
	['corphantom'] = true,
}
-- convert unitname -> unitDefID
local unitdefConfig = {}
for unitName, params in pairs(unitdefConfigNames) do
	if UnitDefNames[unitName] then
		unitdefConfig[UnitDefNames[unitName].id] = params
	end
end
unitdefConfigNames = nil

local CMD_CLOAK = 37382
local cloak = CMD_CLOAK --just simplified Var
local cloakunits = {} -- get UnitID for initial local function
local giveOrderToUnit = Spring.GiveOrderToUnit --optimization
local spUnitTeam = Spring.GetMyTeamID --optimization

local function cloakDeActive(unitID, unitDefID) --DeActivator of Cloak for all units with clock
    if unitdefConfig[unitDefID] then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {0}, 0)
    end
end

local function cloakActive(unitID, unitDefID) --Activator of Cloak
    if unitdefConfig[unitDefID] then
        cloakunits[unitID] = true
        giveOrderToUnit(unitID, cloak, {1}, 0)
    end
end

local function unitIDs(unitID, unitDefID) --check later if could be removed
    if unitdefConfig[unitDefID] then
        cloakunits[unitID] = true
    end
end

local function NewUnit(unitID, unitDefID, unitTeam) --check later if could be removed
    if unitTeam ~= spUnitTeam then
        return
        unitIDs(unitID, unitDefID)
    end
end


local function maybeRemoveSelf()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end


function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end

    WG['autocloak'] = {}
	WG['autocloak'].getUnitdefConfig = function()
		return unitdefConfig
	end
	WG['autocloak'].setUnitdefConfig = function(data)
		local type, value = data[1], data[2]
		unitdefConfig[type] = value
	end

	local allUnits = Spring.GetAllUnits()
	for i=1, #allUnits do
		local unitID = allUnits[i]
		cloakActive(unitID, Spring.GetUnitDefID(unitID))
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	cloakActive(unitID, unitDefID)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if cloakunits[unitID] then
		cloakunits[unitID] = nil
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	NewUnit(unitID, unitDefID, unitTeam)
	cloakDeActive(unitID, unitDefID)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	NewUnit(unitID, unitDefID, unitTeam)
	cloakActive(unitID, unitDefID)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	NewUnit(unitID, unitDefID, unitTeam)
	cloakActive(unitID, unitDefID)
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:GetConfigData()
	local unitdefConfigNames = {}
	for uDefID, params in pairs(unitdefConfig) do
		if UnitDefs[uDefID] then
			unitdefConfigNames[UnitDefs[uDefID].name] = params
		end
	end
	return {
		unitdefConfig = unitdefConfigNames,
	}
end

function widget:SetConfigData(cfg)
	if cfg.unitdefConfig ~= nil then
		for unitName, value in pairs(cfg.unitdefConfig) do
			if UnitDefNames[unitName] then
				local unitDefID = UnitDefNames[unitName].id
				if unitdefConfig[unitDefID] ~= nil then
					unitdefConfig[unitDefID] = value
				end
			end
		end
	end
end
