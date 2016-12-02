
if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name     = "Wind generators",
		desc     = "adds extra wind energy income as defined in customparams.windgen",
		author   = "Floris",
		date     = "November, 2016",
		license  = "GNU GPL, v2 or later",
		layer    = 0,
		enabled  = true -- loaded by default?
	}
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local windDefs = {
	[ UnitDefNames['armwin'].id ] = UnitDefs[UnitDefNames['armwin'].id].customParams.windgen,
	[ UnitDefNames['corwin'].id ] = UnitDefs[UnitDefNames['corwin'].id].customParams.windgen,
}

local windmills = {}

local teamList = Spring.GetTeamList()
local teamEnergy = {}

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Speed-ups

local spGetWind              = Spring.GetWind
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitIsStunned     = Spring.GetUnitIsStunned
local spAddUnitResource      = Spring.AddUnitResource

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:GameFrame(n)
	if (n % 30 < 0.1) then
		if (next(windmills)) then
			for i = 1, #teamList do
				teamEnergy[teamList[i]] = 0
			end
			local _, _, _, windStrength, _, _, _ = spGetWind()
			local windEnergy = windStrength * 0.5
			for unitID, entry in pairs(windmills) do
				local paralyzed = spGetUnitIsStunned(unitID)
				if (not paralyzed) then
					teamEnergy[entry[1]] = teamEnergy[entry[1]] + windEnergy -- monitor team energy
					spAddUnitResource(unitID, 'energy', windEnergy)
				end
			end
		end
	end
end


function gadget:Initialize()

	-- in case a /luarules reload has been executed
	local allUnits = Spring.GetAllUnits()
	for _, unitID in pairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		if (unitDefID and windDefs[unitDefID]) then
		  windmills[unitID] = {spGetUnitTeam(unitID)}
		end
	end
	
	for i = 1, #teamList do
		teamEnergy[teamList[i]] = 0
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if (windDefs[unitDefID]) then 
		windmills[unitID] = {unitTeam}
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, unitTeam)
	if (windDefs[unitDefID]) then 
		if windmills[unitID] then
			windmills[unitID] = {unitTeam}
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if (windDefs[unitDefID]) then 
		windmills[unitID] = nil
	end
end