function gadget:GetInfo()
	return {
		name = "Construction Turrets Range Check",
		desc = "Stops construction turrets from getting stuck on orders out of reach.",
		author = "Nehroz",
		date = "2024.12.01",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_STOP = CMD.STOP
local gMaxUnits = Game.maxUnits
local updateInterval = Game.gameSpeed / 2

local spValidUnitID = Spring.ValidUnitID
local spValidFeatureID = Spring.ValidFeatureID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitCommands = Spring.GetUnitCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit

--- Key is the nano's ID, followed by a set-like with the unitID of target currently inside the nano's range.
--- Used for CommandArray manipulation
---@type {[integer] : {integer : {cmdTag : integer, status : integer}}}
local trackingTable = {}
-- Limits how many GetUnitCommands are called inside a frame when required.
-- higher values allow faster tagging synchronization after a new command;
-- which can cause proportional lag when many units are targeted. (long tables returned)
local tagUpdateFrameMax = 1

local statuses = {
	outOfRange = 0,
	inRange = 1,
}

local mobileUnits = {}
local constructionTurretsDefs = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory == false and unitDef.isStaticBuilder then
		constructionTurretsDefs[unitDefID] = {
			maxBuildDistance = unitDef.buildDistance + unitDef.radius,
			buildRange3D = unitDef.buildRange3D,
		}
	end

	if unitDef.canMove then
		mobileUnits[unitDefID] = true
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.STOP)
end

function gadget:GameFrame(frame)
	local tagUpdates = 0
	local cmdCache = {}

	for nanoID, targets in pairs(trackingTable) do
		if nanoID % updateInterval == frame % updateInterval then
			if next(targets) == nil then
				trackingTable[nanoID] = nil
			end

			local nanoDefID = spGetUnitDefID(nanoID)
			local maxDistance = constructionTurretsDefs[nanoDefID].maxBuildDistance

			for targetID, commandData in pairs(targets) do
				if spValidUnitID(targetID) then
					if not commandData.cmdTag then
						if tagUpdates >= tagUpdateFrameMax then break end

						if not cmdCache[nanoID] then
							cmdCache[nanoID] = spGetUnitCommands(nanoID, -1)
							tagUpdates = tagUpdates +1
						end

						for _, cmd in ipairs(cmdCache[nanoID]) do
							trackingTable[nanoID][cmd.params[1]].cmdTag = cmd.tag
						end
					end

					local distance = spGetUnitSeparation(nanoID, targetID, constructionTurretsDefs[nanoDefID].buildRange3D, false)

					if distance < maxDistance then
						if commandData.status == statuses.outOfRange then
							commandData.status = statuses.inRange
						end
					else
						-- Do not blindly remove orders on out-of-range mobile units, as the player may have pre-emptively issued an order before the unit was in range
						-- Instead, only remove the order once the unit has come into range then left again
						if commandData.status == statuses.inRange then
							spGiveOrderToUnit(nanoID, CMD.REMOVE, commandData.cmdTag, 0)
							targets[targetID] = nil
						end
					end
				else
					targets[targetID] = nil
				end
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID,	cmdParams, cmdOptions, cmdTag, synced, fromLua)
	local constructionTurretDef = constructionTurretsDefs[unitDefID]
	if not constructionTurretDef then return true end

	if cmdID == CMD_STOP then
		trackingTable[unitID] = nil
	end

	-- Rather than trying to handle area commands, let them fallthrough, then catch the resulting list of single-target commands
	if #cmdParams ~= 1 then return true end

	local distance = math.huge
	local targetId = cmdParams[1]

	if targetId < gMaxUnits then
		if not spValidUnitID(targetId) then return end
		local defID = spGetUnitDefID(targetId)

		if mobileUnits[defID] then
			trackingTable[unitID] = trackingTable[unitID] or {}
			trackingTable[unitID][targetId] = {status = statuses.outOfRange}
			return true
		end

		distance = spGetUnitSeparation(unitID, targetId, constructionTurretDef.buildRange3D, false)
	else
		targetId = targetId - gMaxUnits
		if not spValidFeatureID(targetId) then return end
		distance = spGetUnitFeatureSeparation(unitID, targetId, false)
	end

	if distance > constructionTurretDef.maxBuildDistance then
		return false
	end

	return true
end

function gadget:UnitDestroyed(unitID)
	for _, targets in pairs(trackingTable) do
		targets[unitID] = nil
	end
	trackingTable[unitID] = nil
end