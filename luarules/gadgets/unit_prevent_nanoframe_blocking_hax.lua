function gadget:GetInfo()
  return {
    name      = "Prevent Nanoframe Blocking Hax",
    desc      = "Prevents nanoframes from blocking projectiles until they have reached x% build progress",
    author    = "",
    date      = "",
    license   = "Hornswaggle",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if not gadgetHandler:IsSyncedCode() then return end

local blockingBuildProgress = 0.1
------------

local AlreadyProcessedThisFrame = {} --skips on curFrame
local blockSkip = {} -- skip blocking if already blocked
local bpCheckSkip = {} -- skip checking bp if already 1.0

local function NoBlocking(unitID)
	local arg1,arg2 = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, arg1,arg2, false) -- non-blocking for projectiles
	Spring.SetUnitNeutral(unitID, true)
end

local function Blocking(unitID)
	local arg1,arg2 = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, arg1,arg2, true) -- assume all units are (normally) blocking for projectiles
	Spring.SetUnitNeutral(unitID, false)
end

------------

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
	if not (bpCheckSkip[unitID] or AlreadyProcessedThisFrame[unitID]) then -- Avoid checking same unit by multiple builders on same frame, skip if already checked, if unit was finished no need to check at all
		local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
		if buildProgress < blockingBuildProgress then
			NoBlocking(unitID)
			blockSkip[unitID] = false
		elseif not blockSkip[unitID] then -- Unit reached > 0.1 build progress, but decay might still cause it to revert under 0.1 => Must check buildProgress but no need to reapply blocking if it's still > 0.10
			Blocking(unitID)
			blockSkip[unitID] = true 
		end
		AlreadyProcessedThisFrame[unitID] = true
	end
	return true
end

function gadget:UnitFinished(unitID) -- unit was finished, build progress will never decay
	if not blockSkip[unitID] then
		Blocking(unitID)
		blockSkip[unitID] = true
	end
	bpCheckSkip[unitID] = true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	blockSkip[unitID] = nil
	AlreadyProcessedThisFrame[unitID] = nil
	bpCheckSkip[unitID] = nil
end

function gadget:GameFrame()
	AlreadyProcessedThisFrame = {}
end

