function gadget:GetInfo()
	return {
		name = "Construction Turrets Range Check",
		desc = "Stops construction turrets from getting assigned to guards, repair, reclaim and attacks out of reach.",
		author = "Nehroz",
		date = "2024.11.09", -- update date.
		license = "GNU GPL, v2 or later",
		layer = 0,
		version = "1.0",
		enabled = true,
	}
end

local function isNano(unitDef)
	return unitDef.isFactory == false and unitDef.isStaticBuilder
end

local function isValidCommandID(commandID)
	return (
		   commandID == CMD.REPAIR
		or commandID == CMD.GUARD
		or commandID == CMD.RECLAIM
		or commandID == CMD.ATTACK
	)
end

local function reindexArray(tbl)
    local newTbl = {}
    for _, value in pairs(tbl) do
        table.insert(newTbl, value)
    end
    return newTbl
end

local function cmdToCmdSpec(tbl)
	local newTbl = {}
	for _, cmd in pairs(tbl) do
		table.insert(newTbl, {cmd.id, cmd.params, cmd.options})
	end
	return newTbl
end

local frequency = 5
--- key is the nano's ID, followed by a lists with the unitID of target currently inside; when they leave they get removed.
---@type {[number] : {number : boolean}}
local trackingTable = {}

function gadget:GameFrame(frame)
	if frame % frequency ~= 0 then return end
	for nanoID, v in pairs(trackingTable) do
		if not Spring.ValidUnitID(nanoID) then
			trackingTable[nanoID] = nil
		else
			local nanoDef = UnitDefs[Spring.GetUnitDefID(nanoID)]
			local maxDistance = nanoDef.buildDistance + nanoDef.radius
			local cmds = Spring.GetUnitCommands(nanoID, -1)
			local isChanged = false

			for i = #cmds, 1, -1 do
				local cmd = cmds[i]
				for j = #cmd["params"], 1, -1 do
					local uID = cmd["params"][j]
					if Spring.ValidUnitID(uID) then
						local distance = Spring.GetUnitSeparation(nanoID, uID, false, false)
						if distance < maxDistance then -- Are inside.
							trackingTable[nanoID][uID] = true
						end

						if trackingTable[nanoID][uID] then
							if distance > maxDistance then -- outside
								cmd["params"][j] = nil
								trackingTable[nanoID][uID] = nil
								isChanged = true
							end
						end

						if #cmd["params"] == 0 then
							trackingTable[nanoID] = nil
							cmds[i] = nil
						end
					end
				end
			end
			if isChanged then
				cmds = reindexArray(cmds)
				cmds[1].options.shift = false
				Spring.GiveOrderArrayToUnit(nanoID, cmdToCmdSpec(cmds))
			end
		end
	end
end


function gadget:AllowCommand(unitID, unitDefID, _teamID, cmdID,
	cmdParams, _cmdOptions, _cmdTag, _synced, _fromLua)

	local unitDef = UnitDefs[unitDefID]
	if not isNano(unitDef) then return true end
	if not isValidCommandID(cmdID) then return true end
	if #cmdParams ~= 1 then return true end -- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	local distance = 1/0 -- INF
	local targetDef = UnitDefs[Spring.GetUnitDefID(cmdParams[1])]
	if targetDef ~= nil then --when in definitions (unit)
		if targetDef.canMove then -- ignore movable targets, add to tracking
			if not trackingTable[unitID] then
				trackingTable[unitID] = {}
			end
			return true
		end
		distance = Spring.GetUnitSeparation(unitID, cmdParams[1], false, false)
	else -- when undefined
		-- NOTE Not properly docummented under Recoil as of 22/11/24, view SpringRTS Lua SyncedRead instead.
		distance = Spring.GetUnitFeatureSeparation(unitID, cmdParams[1] - 32000, true) -- Magic Number is offset to unit max
	end
	if distance > (unitDef.buildDistance + unitDef.radius) then
		return false
	end
	return true
end

function gadget:UnitDestroyed(unitID)
	for nanoID in pairs(trackingTable) do
		trackingTable[nanoID] = nil
	end
	for nanoID, v in pairs(trackingTable) do
		trackingTable[nanoID][unitID] = nil
	end
end