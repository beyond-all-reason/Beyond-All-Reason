function gadget:GetInfo()
   return {
      name = "Air Transports fix",
      desc = "always unloads its load + better height-unloading at steeper cliffs",
      author = "Floris",
      date = "2015",
      license = "",
      layer = 0,
      enabled = true,
   }
end


if (gadgetHandler:IsSyncedCode()) then

	local GetUnitPosition = Spring.GetUnitPosition
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local GetUnitCommands = Spring.GetUnitCommands
	local GetGameFrame = Spring.GetGameFrame

	local orderQueue = {}

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, synced)
		if not UnitDefs[unitDefID].canFly then
			return true
		end
		if cmdID == CMD.INSERT then
			local queue = GetUnitCommands(unitID)
			local commandPos
			if cmdOpts.alt then
				-- first param is a pos
				commandPos = cmdParams[1]
			else
				-- first param is a command tag
				for pos, command in ipairs(queue) do
					if command.tag == cmdParams[1] then
						commandPos = pos
						break
					end
				end
			end
			local targetCommand = queue[commandPos]
			if targetCommand then
				if (targetCommand.id == CMD.UNLOAD_UNIT or targetCommand.id == CMD.UNLOAD_UNITS) and not cmdOpts.coded then
					--prevent inserting commands between move and unload
					return false
				end
			end
			if (cmdParams[2] == CMD.UNLOAD_UNITS or cmdParams[2] == CMD.UNLOAD_UNIT ) then
				--attempting to insert a unload order, insert a move command as well
				local dest = {cmdParams[4],cmdParams[5],cmdParams[6]}
				if #cmdParams == 4 then
					--target is unitid
					dest =  GetUnitPosition(unitID)
				end
				orderQueue[GetGameFrame() + 1] = orderQueue[GetGameFrame() + 1] or {}
				orderQueue[GetGameFrame() + 1][#orderQueue[GetGameFrame() + 1]+1] = {unitID=unitID,insertPos = commandPos,dest=dest}
			end
		end
		if cmdID == CMD.REMOVE then
			if cmdOpts.alt then
				--prevent removing globally move orders if synced unload are present
				-- params are commandids
				local foundMove = false
				for _, cmdToCompare in pairs(cmdParams) do
					if cmdToCompare == CMD.MOVE then
						cmdToCompare = true
					end
					if cmdToCompare then
						-- if removing move and we have a synced unload, block removal
						for _, command in pairs(GetUnitCommands(unitID)) do
							if command.id == CMD.MOVE and command.options.coded then
								return false
							end
						end
					end

				end
			else
				--prevent removing specific move orders if synced unloads are present
				--params are command tags
				local queue = GetUnitCommands(unitID)
				for _, paramTag in pairs(cmdParams) do
					for _, command in pairs(queue) do
						if command.tag == paramTag then
							if command.id == CMD.MOVE and command.options.coded then
								return false
							end
						end
					end
				end
			end
		end
		return true
	end

	-- add a move cmd in front each air-trans load/unload cmd, because else the trans wont respect smoothmesh
	function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdOpts, cmdParams,cmdTag)
		if not UnitDefs[unitDefID].canFly then
			return
		end
		if (cmdID==CMD.UNLOAD_UNIT or cmdID==CMD.UNLOAD_UNITS) then
			if #cmdParams == 1 then
				--target is unitid
				cmdParams =  GetUnitPosition(unitID)
			end
			local insertPos = 0
			if math.bit_and(cmdOpts,CMD.OPT_SHIFT) ~= 0 then
				insertPos = GetUnitCommands(unitID,0)-1
			end
			orderQueue[GetGameFrame() + 1] = orderQueue[GetGameFrame() + 1] or {}
			orderQueue[GetGameFrame() + 1][#orderQueue[GetGameFrame() + 1]+1] = {unitID=unitID,insertPos = insertPos,dest=cmdParams}
		end
	end

	function gadget:GameFrame(n)
		if not orderQueue[n] then
			return
		end
		for _,order in ipairs(orderQueue[n]) do
			GiveOrderToUnit(order.unitID, CMD.INSERT, {order.insertPos, CMD.MOVE, (CMD.OPT_SHIFT+CMD.OPT_INTERNAL), order.dest[1], order.dest[2], order.dest[3]}, {"alt"})
		end
		orderQueue[n] = nil
	end
end
