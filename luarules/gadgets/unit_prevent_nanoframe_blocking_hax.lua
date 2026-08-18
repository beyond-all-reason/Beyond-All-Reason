local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Nanoframe Blocking Hax",
		desc = "Prevents nanoframes from blocking projectiles until they have reached x% build progress",
		author = "",
		date = "",
		license = "Hornswaggle",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local blockingBuildProgress = 0.05

local newNanoFrameNeutralState = {} -- hash table, unitID -> original neutral state
local CMD_ATTACK = CMD.ATTACK

local function AddNanoFrame(unitID)
	local a, b, c, d, e, f, g = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, a, b, false, d, e, f, g) -- non-blocking for projectiles

	local neutral = Spring.GetUnitNeutral(unitID)
	newNanoFrameNeutralState[unitID] = neutral
	Spring.SetUnitNeutral(unitID, true)
end

local function removeNanoFrame(unitID)
	if Spring.ValidUnitID(unitID) then
		local a, b, c, d, e, f, g = Spring.GetUnitBlocking(unitID)
		Spring.SetUnitBlocking(unitID, a, b, true, d, e, f, g) -- blocking for projectiles

		local neutral = newNanoFrameNeutralState[unitID]
		-- If a unit has already been set to neutral=false, don't overwrite that here
		if Spring.GetUnitNeutral(unitID) then
			Spring.SetUnitNeutral(unitID, neutral)
		end
	end
	newNanoFrameNeutralState[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID then
		local _, _, projectileBlocking = Spring.GetUnitBlocking(unitID)
		if projectileBlocking then
			AddNanoFrame(unitID)
		end
	end
end

function gadget:UnitBuildStepPost(unitID)
	if newNanoFrameNeutralState[unitID] ~= nil then
		local _, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
		if buildProgress and buildProgress >= blockingBuildProgress then
			removeNanoFrame(unitID)
		end
	end
end

-- make it not manually or accidentally targetable
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD.ATTACK
	if not cmdParams[2] and newNanoFrameNeutralState[cmdParams[1]] ~= nil then
		return false
	else
		return true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	newNanoFrameNeutralState[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	-- handle luarules reload
	local units = Spring.GetAllUnits()
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end
end
