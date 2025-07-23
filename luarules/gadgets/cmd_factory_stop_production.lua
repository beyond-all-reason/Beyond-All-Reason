local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Factory Stop Production",
		desc = "Adds a command to clear the factory queue",
		author = "GoogleFrog,badosu",
		date = "13 November 2016",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local identifier = "StopProduction"

if gadgetHandler:IsSyncedCode() then

	local isFactory = {}
	for udid = 1, #UnitDefs do
		local ud = UnitDefs[udid]
		if ud.isFactory then
			isFactory[udid] = true
		end
	end

	local spGetRealBuildQueue = Spring.GetRealBuildQueue
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc

	local CMD_STOP_PRODUCTION = GameCMD.STOP_PRODUCTION
	local CMD_WAIT = CMD.WAIT
	local EMPTY = {}
	local DEQUEUE_OPTS = CMD.OPT_RIGHT -- right: dequeue, ctrl+shift: 100

	local stopProductionCmdDesc = {
		id = CMD_STOP_PRODUCTION,
		type = CMDTYPE.ICON,
		name = "Stop Production",
		action = "stopproduction",
		cursor = "Stop", -- Probably does nothing
		tooltip = "Stop Production: Clear factory production queue.",
	}

	function gadget:AllowCommand_GetWantedCommand()
		return { [CMD_STOP_PRODUCTION] = true }
	end

	function gadget:AllowCommand_GetWantedUnitDefID()
		return isFactory
	end

	local function orderDequeue(unitID, buildDefID, count)
		while count > 0 do
			local opts = DEQUEUE_OPTS
			if count >= 100 then
			count = count - 100
				opts = opts + CMD.OPT_SHIFT + CMD.OPT_CTRL
			elseif count >= 20 then
				count = count - 20
				opts = opts + CMD.OPT_CTRL
			elseif count >= 5 then
				count = count - 5
				opts = opts + CMD.OPT_SHIFT
			else
				count = count - 1
			end

			spGiveOrderToUnit(unitID, -buildDefID, EMPTY, opts)
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		if not isFactory[unitDefID] then
			return true
		end

		-- Dequeue build order by sending build command to factory to minimize number of commands sent
		-- As opposed to removing each build command individually
		local queue = spGetRealBuildQueue(unitID)
		if queue ~= nil then
			local total = 0
			for _, buildPair in ipairs(queue) do
				local _, count = next(buildPair, nil)
				total = total + count
			end
			local keepDefID
			if total > 1 then
				local firstCommand = Spring.GetFactoryCommands(unitID, 1)
				local firstID = firstCommand[1]['id']
				if firstID < 0 then
					keepDefID = -firstID
				end
			end
			for _, buildPair in ipairs(queue) do
				local buildUnitDefID, count = next(buildPair, nil)
				if keepDefID == buildUnitDefID then
					count = count - 1
					keepDefID = nil
				end
				orderDequeue(unitID, buildUnitDefID, count)
			end
		end

		spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0) -- Removes wait if there is a wait but doesn't readd it.
		spGiveOrderToUnit(unitID, CMD_WAIT, EMPTY, 0) -- If a factory is waiting, it will not clear the current build command, even if the cmd is removed.
		-- See: http://zero-k.info/Forum/Post/237176#237176 for details.
		SendToUnsynced(identifier, unitID, unitDefID, unitTeam, CMD_STOP_PRODUCTION)
	end

	-- Add the command to factories
	function gadget:UnitCreated(unitID, unitDefID)
		if isFactory[unitDefID] then
			spInsertUnitCmdDesc(unitID, stopProductionCmdDesc)
		end
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_STOP_PRODUCTION)
		gadgetHandler:RegisterAllowCommand(CMD_STOP_PRODUCTION)
		for _, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end
else
	local myTeamID, isSpec

	local function stopProduction(_, unitID, unitDefID, unitTeam, cmdID)
		if isSpec or Spring.AreTeamsAllied(unitTeam, myTeamID) then
			Script.LuaUI.UnitCommand(unitID, unitDefID, unitTeam, cmdID, {}, {coded = 0})
		end
	end

	function gadget:PlayerChanged()
		myTeamID = Spring.GetMyTeamID()
		isSpec = Spring.GetSpectatingState()
	end

	function gadget:Initialize()
		gadget:PlayerChanged()
		gadgetHandler:AddSyncAction(identifier, stopProduction)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(identifier)
	end
end
