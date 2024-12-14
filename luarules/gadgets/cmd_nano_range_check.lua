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
Spring.SetLogSectionFilterLevel(gadget:GetInfo().name, LOG.INFO) -- WARN Remove in final version.
Spring.Log(gadget:GetInfo().name, LOG.INFO,"Unsync Load.")

--- key is the nano's ID, followed by a Set-like with the unitID of target currently inside the nano's range.
--- Used for CommandArray manipulation
---@type {[number] : {number : {cmdTag : integer, status : integer}}}
local trackingTable = {}
local trackingTableSize = 0
local chunkingFrameSize = 1

local constructionTurretsDefs = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory == false and unitDef.isStaticBuilder then
		constructionTurretsDefs[unitDefID] = {
			maxBuildDistance = unitDef.buildDistance + unitDef.radius,
			buildRange3D = unitDef.buildRange3D,
		}
	end
end

local function isEmptyTable(tbl)
	for _ in pairs(tbl) do
		return false
	end
	return true
end

-- only used for Logging; remove with it.
local function getTableSize(tbl)
	local i = 0
	for _ in pairs(tbl) do
		i = i + 1
	end
	return i
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.STOP)
end

local gate = false
function gadget:GameFrame(frame)
	local removes = 0
	local inside = 0
	local nanosRun = 0
	local unitsCalced = 0

	if frame % 15 then -- update dynamic chunking size
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

	local cmdCache = {}
	local pointer = frame % chunkingFrameSize -- chunking offset
	for nanoID, targets in pairs(trackingTable) do
		if pointer % chunkingFrameSize == 0 then
			local nanoDefID = Spring.GetUnitDefID(nanoID)
			local maxDistance = constructionTurretsDefs[nanoDefID].maxBuildDistance

			for targetID, commandData in pairs(targets) do
				if Spring.ValidUnitID(targetID) then
					-- cmdTag gathering
					if commandData.cmdTag == -1 then
						if not cmdCache[nanoID] then
							-- REVISE Only way to obtain legit tag data; will create light lag.
							cmdCache[nanoID] = Spring.GetUnitCommands(nanoID, -1)
						end
						for _, cmd in ipairs(cmdCache[nanoID]) do
							if cmd.params[1] == targetID then
								trackingTable[nanoID][targetID].cmdTag = cmd.tag
							end
						end
					end
					-- distance processing
					local distance = Spring.GetUnitSeparation(nanoID, targetID, constructionTurretsDefs[nanoDefID].buildRange3D, false)
					if distance < maxDistance then
						if commandData.status == 0 then -- Entering range.
							commandData.status = 1
							inside = inside +1
						end
					else
						if commandData.status == 1 then -- Exiting range.
							Spring.GiveOrderToUnit(nanoID, CMD.REMOVE, commandData.cmdTag, 0) ---@diagnostic disable-line: param-type-mismatch
							targets[targetID] = nil
							removes = removes +1
						end
					end
					unitsCalced = unitsCalced +1
				else
					targets[targetID] = nil -- Clean up invalid targets.
				end
			end
		end
		pointer = pointer + 1

		if next(targets) == nil then -- Clean empty nanos.
			trackingTable[nanoID] = nil
			trackingTableSize = trackingTableSize - 1
		end
	end

	if not isEmptyTable(trackingTable) or gate then
		Spring.Log(gadget:GetInfo().name, LOG.INFO,
			string.format("Tracking: %s, NanoRuns: %s, uProc: %s, dropped: %s, inside: %s.",
				tostring(getTableSize(trackingTable)),
				tostring(nanosRun),
				tostring(unitsCalced),
				tostring(removes),
				tostring(inside)
			)
		)
		gate = true
		if isEmptyTable(trackingTable) then
			Spring.Log(gadget:GetInfo().name, LOG.INFO, "Tracking stopped.")
			gate = false
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID,	cmdParams, cmdOptions, cmdTag, synced, fromLua)
	if not constructionTurretsDefs[unitDefID] then return true end
	-- Handle stops on nanos
	if cmdID == CMD.STOP then
		trackingTable[unitID] = nil
		trackingTableSize = trackingTableSize - 1
	end
	-- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	if #cmdParams ~= 1 then return true end
	local distance = math.huge
	local targetId = cmdParams[1]

	if targetId < Game.maxUnits then -- Feature handling
		if not Spring.ValidUnitID(targetId) then return end
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetId)]
		if targetUnitDef.canMove then
			if not trackingTable[unitID] then
				trackingTable[unitID] = {}
				trackingTableSize = trackingTableSize + 1
			end
			trackingTable[unitID][cmdParams[1]] = {cmdTag = -1, status = 0} -- default to outside
			return true
		end
		distance = Spring.GetUnitSeparation(unitID, targetId, constructionTurretsDefs[unitDefID].buildRange3D, false)
	else
		-- Handle Features
		targetId = targetId - Game.maxUnits
		if not Spring.ValidFeatureID(targetId) then return end
		distance = Spring.GetUnitFeatureSeparation(unitID, targetId, false)
	end

	if distance > constructionTurretsDefs[unitDefID].maxBuildDistance then
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