local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Death Cache",
		desc = "Share dead-or-invalid unit checks between synced gadgets",
		author = "eun-ice",
		license = "GNU GPL, v2 or later",
		layer = -2000000000, -- Update membership before consumers handle lifecycle events.
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local getUnitIsDead = Spring.GetUnitIsDead
local getUnitDefID = Spring.GetUnitDefID
local dead = table.ensureTable(GG, "IsUnitDead")
local transportDefs = {}
for unitDefID, def in pairs(UnitDefs) do
	if (def.transportCapacity or 0) > 0 then
		transportDefs[unitDefID] = true
	end
end
local liveTransports = {}
local recentDead = {}
local previousDead = {}
local interval = 10 * Game.gameSpeed

local function rememberDead(unitID)
	dead[unitID] = true
	recentDead[unitID] = true
	previousDead[unitID] = nil
	return true
end

-- This is a full-read synced API, not a replacement inside CallAsTeam or LuaUI.
-- true means dead OR invalid; false means alive. Missing entries are queried lazily.
local function lookup(_, unitID)
	if getUnitIsDead(unitID) ~= false then
		return rememberDead(unitID)
	end
	-- ForcedKillUnit releases cargo before UnitDestroyed. Nested cargo callbacks
	-- can observe a dead transporter while its last cached value would be alive.
	-- Keep querying live transporters until their death is observed.
	if not liveTransports[unitID] then
		if transportDefs[getUnitDefID(unitID)] then
			liveTransports[unitID] = true
		else
			dead[unitID] = false
		end
	end
	return false
end

function gadget:Initialize()
	-- Keep the shared table identity across reloads; rebuild from engine queries.
	for unitID in pairs(dead) do
		dead[unitID] = nil
	end
	-- Reconstruct forced carriers as well as normal transports after a reload.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local transportID = Spring.GetUnitTransporter(unitID)
		if transportID then
			liveTransports[transportID] = true
		end
	end
	setmetatable(dead, { __index = lookup })
end

function gadget:UnitCreated(unitID, unitDefID)
	dead[unitID] = nil
	recentDead[unitID] = nil
	previousDead[unitID] = nil
	liveTransports[unitID] = transportDefs[unitDefID]
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID)
	-- Lua can force cargo onto units whose definition has no transport capacity.
	dead[transportID] = nil
	liveTransports[transportID] = true
end

function gadget:UnitDestroyed(unitID)
	liveTransports[unitID] = nil
	rememberDead(unitID)
end

function gadget:GameFrame(frame)
	if frame % interval ~= 0 then
		return
	end
	-- Retain death/invalid entries for 10-20 seconds, without per-entry timestamps.
	for unitID in pairs(previousDead) do
		dead[unitID] = nil
		previousDead[unitID] = nil
	end
	previousDead, recentDead = recentDead, previousDead
end

function gadget:Shutdown()
	for unitID in pairs(dead) do
		dead[unitID] = nil
	end
	-- Existing consumers remain correct if this gadget is disabled.
	setmetatable(dead, {
		__index = function(_, unitID)
			return getUnitIsDead(unitID) ~= false
		end,
	})
end
