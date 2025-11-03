local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "resurrected param",
        desc      = "marks resurrected units as resurrected.",
        author    = "Floris, Chronographer",
        date      = "4 November 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        enabled   = true
    }
end

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local spGetUnitHealth = Spring.GetUnitHealth
local spGetGameFrame = Spring.GetGameFrame
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local CMD_WAIT = CMD.WAIT

local canResurrect = {}
local isBuilding = {}
local isBuilder = {}

local createdFrame = {}
local toBeUnWaited = {}
local prevHealth = {}
local currentCmd = {}

for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.canResurrect then
        canResurrect[unitDefID] = true
    end
	if unitDef.isBuilding then
		isBuilding[unitDefID] = true
	end
	if unitDef.isBuilder then
		isBuilder[unitDefID] = true
	end
end

-- detect resurrected units here
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and canResurrect[Spring.GetUnitDefID(builderID)] then
		if not Spring.Utilities.Gametype.IsScavengers() then -- FIXME: Scavengers have constructors which can also resurrect, which f***s over the whole thing.
			local rezRulesParam = Spring.GetUnitRulesParam(unitID, "resurrected")
			if rezRulesParam == nil then
				Spring.SetUnitRulesParam(unitID, "resurrected", 1, {inlos=true})
			end
			if (not isBuilding[unitDefID]) and (not isBuilder[unitDefID]) then
				createdFrame[unitID] = spGetGameFrame()
				toBeUnWaited[unitID] = true
				prevHealth[unitID] = 0
				spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
			end
		end
		Spring.SetUnitHealth(unitID, spGetUnitHealth(unitID) * 0.05)
	end
	-- See: https://github.com/beyond-all-reason/spring/pull/471
	-- if builderID and Spring.GetUnitCurrentCommand(builderID) == CMD.RESURRECT then
	--	Spring.SetUnitHealth(unitID, Spring.GetUnitHealth(unitID) * 0.05)
	-- end
	-- this code is buggy.
	-- Spring.GetUnitCurrentCommand(builderID) does not return CMD.RESURRECT in all cases
	-- Switch to using same rule as the halo visual
	-- which does have the limitation that *any* unit created by a builder that can rez
	-- will be created at 5% HP
	-- currently not an issue with BAR's current units, but is a limitation on any
	-- future multi-purpose rez unit
end

function gadget:GameFrame(n)
	if n % 10 == 0 then
		if next(toBeUnWaited) ~= nil then
			for unitID, check in pairs(toBeUnWaited) do
				local health = spGetUnitHealth(unitID)
				if health <= prevHealth[unitID] then -- stopped healing
					createdFrame[unitID] = nil
					toBeUnWaited[unitID] = nil
					prevHealth[unitID] = nil
					currentCmd = spGetUnitCurrentCommand(unitID, 1)
					if currentCmd and currentCmd == CMD_WAIT then
						spGiveOrderToUnit(unitID, CMD_WAIT, {}, 0)
					end
				else
					prevHealth[unitID] = health
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	createdFrame[unitID] = nil
	toBeUnWaited[unitID] = nil
	prevHealth[unitID] = nil
end
