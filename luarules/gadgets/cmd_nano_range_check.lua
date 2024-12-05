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
---@type {[number] : {number : boolean}}
local trackingTable = {}

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
end

local gate = false
function gadget:GameFrame(frame)
	local removes = 0
	local inside = 0
	local nanosRun = 0
	local unitsCalced = 0

	if frame % 60 > 10 then return end -- run 10 frames, skip 50; allow LuaUser.cpp to catch up. running full every 1s
	local pointer = frame % 10
	for nanoID in pairs(trackingTable) do
		if pointer % 10 == 0 then
			local nanoDefID = Spring.GetUnitDefID(nanoID)
			local maxDistance = constructionTurretsDefs[nanoDefID].maxBuildDistance
			local commands = Spring.GetUnitCommands(nanoID, -1)

			for i=#commands, 1, -1 do
				local unitID = commands[i].params[1]
				if Spring.ValidUnitID(unitID) then
					local distance = Spring.GetUnitSeparation(nanoID, unitID, constructionTurretsDefs[nanoDefID].buildRange3D, false)
					if distance < maxDistance then -- Inside range
						trackingTable[nanoID][unitID] = true
						inside = inside +1
					elseif trackingTable[nanoID][unitID] then -- Outside range
						trackingTable[nanoID][unitID] = nil
						Spring.GiveOrderToUnit(nanoID, CMD.REMOVE, commands[i].tag, 0)
						removes = removes +1
					end
					unitsCalced = unitsCalced +1
				end
			end
			-- clear nano when chaining commands
			if #commands == 1  then
				if commands[1].id == CMD.FIGHT then --expected idle
					trackingTable[nanoID] = nil
				end
			end
			nanosRun = nanosRun +1
		end
		pointer = pointer + 1
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
	-- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	if #cmdParams ~= 1 then return true end
	local distance = math.huge
	local targetId = cmdParams[1]

	if targetId < Game.maxUnits then
		if not Spring.ValidUnitID(targetId) then return end
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetId)]
		if targetUnitDef.canMove then
			if not trackingTable[unitID] then
				trackingTable[unitID] = {}
			end
			return true
		end
		distance = Spring.GetUnitSeparation(unitID, targetId, constructionTurretsDefs[unitDefID].buildRange3D, false)
	else
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
	trackingTable[unitID] = nil

	for nanoID, _ in pairs(trackingTable) do
		trackingTable[nanoID][unitID] = nil
	end
end