function gadget:GetInfo()
	return {
		name = "Construction Turrets Range Check",
		desc = "Stops construction turrets from getting assigned to guards, repair, reclaim and attacks out of reach.",
		author = "Nehroz",
		date = "2024.12.01",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local CMD_STOP = CMD.STOP
local gMaxUnits = Game.maxUnits
local spValidUnitID = Spring.ValidUnitID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitCommands = Spring.GetUnitCommands
local spValidFeatureID = Spring.ValidFeatureID
local spGiveOrderToUnit = Spring.GiveOrderToUnit

--- key is the nano's ID, followed by a Set-like with the unitID of target currently inside the nano's range.
--- Used for CommandArray manipulation
---@type {[integer] : {integer : {cmdTag : integer, status : integer}}}
local trackingTable = {}
local trackingTableSize = 0
local chunkingFrameSize = 1
local chunkingUpdateFrequency = 15
local tagUpdateFrameMax = 1 -- Can be bigger than 1 if you want game freezes.
local unitCanMoveCache = {} ---@type {integer:boolean} single frame cache.

local constructionTurretsDefs = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory == false and unitDef.isStaticBuilder then
		constructionTurretsDefs[unitDefID] = {
			maxBuildDistance = unitDef.buildDistance + unitDef.radius,
			buildRange3D = unitDef.buildRange3D,
		}
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.STOP)
end

function gadget:GameFrame(frame)
	-- update dynamic chunking size
	if frame % chunkingUpdateFrequency then
		if trackingTableSize <= 50 then
			chunkingFrameSize = 1
		elseif trackingTableSize <= 100 then
			-- linear from 50 to 100 nanos, from chunk size 1 to 10.
			-- ratio: 1 = 9/50 * (50+b) -> b = -8
			chunkingFrameSize = math.floor((9 / 50) * trackingTableSize - 8)
		else
			chunkingFrameSize = 10
		end
	end

	local tagUpdates = 0
	local cmdCache = {}
	local pointer = frame % chunkingFrameSize -- chunking offset
	for nanoID, targets in pairs(trackingTable) do
		if pointer % chunkingFrameSize == 0 then
			if next(targets) == nil then -- Clean empty nanos.
				trackingTable[nanoID] = nil
				trackingTableSize = trackingTableSize - 1
			end

			local nanoDefID = spGetUnitDefID(nanoID)
			local maxDistance = constructionTurretsDefs[nanoDefID].maxBuildDistance

			for targetID, commandData in pairs(targets) do
				if spValidUnitID(targetID) then
					-- cmdTag gathering
					if commandData.cmdTag == -1 then
						if tagUpdates >= tagUpdateFrameMax then break end
						if not cmdCache[nanoID] then
							cmdCache[nanoID] = spGetUnitCommands(nanoID, -1)
							tagUpdates = tagUpdates +1
						end
						for _, cmd in ipairs(cmdCache[nanoID]) do
							trackingTable[nanoID][cmd.params[1]].cmdTag = cmd.tag
						end
					end
					-- distance processing
					local distance = spGetUnitSeparation(nanoID, targetID, constructionTurretsDefs[nanoDefID].buildRange3D, false)
					if distance < maxDistance then
						if commandData.status == 0 then -- Entering range.
							commandData.status = 1
						end
					else
						if commandData.status == 1 then -- Exiting range.
							spGiveOrderToUnit(nanoID, CMD.REMOVE, commandData.cmdTag, 0) ---@diagnostic disable-line: param-type-mismatch
							targets[targetID] = nil
						end
					end
				else
					targets[targetID] = nil -- Clean up invalid targets.
				end
			end
		end
		pointer = pointer + 1
	end
	unitCanMoveCache = {}
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID,	cmdParams, cmdOptions, cmdTag, synced, fromLua)
	local constructionTurretsDef = constructionTurretsDefs[unitDefID]
	if not constructionTurretsDef then return true end
	-- Handle stops on nanos
	if cmdID == CMD_STOP then
		if trackingTable[unitID] then
			trackingTable[unitID] = nil
			trackingTableSize = trackingTableSize - 1
		end
	end
	-- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	if #cmdParams ~= 1 then return true end
	local distance = math.huge
	local targetId = cmdParams[1]

	if targetId < gMaxUnits then -- Feature handling
		if not spValidUnitID(targetId) then return end
		local defID = spGetUnitDefID(targetId)
		if not unitCanMoveCache[defID] then
			unitCanMoveCache[defID] = UnitDefs[spGetUnitDefID(targetId)].canMove
		end
		if unitCanMoveCache[defID] then
			if not trackingTable[unitID] then
				trackingTable[unitID] = {}
				trackingTableSize = trackingTableSize + 1
			end
			trackingTable[unitID][cmdParams[1]] = {cmdTag = -1, status = 0} -- default to outside
			return true
		end
		distance = spGetUnitSeparation(unitID, targetId, constructionTurretsDef.buildRange3D, false)
	else
		-- Handle Features
		targetId = targetId - gMaxUnits
		if not spValidFeatureID(targetId) then return end
		distance = spGetUnitFeatureSeparation(unitID, targetId, false)
	end

	if distance > constructionTurretsDef.maxBuildDistance then
		return false
	end
	return true
end

function gadget:UnitDestroyed(unitID)
	if trackingTable[unitID] then
		trackingTable[unitID] = nil
		trackingTableSize = trackingTableSize - 1
	end

	for nanoID, _ in pairs(trackingTable) do
		trackingTable[nanoID][unitID] = nil
	end
end