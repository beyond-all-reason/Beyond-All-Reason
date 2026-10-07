-- NETMSG_AICOMMANDS contains one source array and one command array (not their
-- Cartesian product). Keep native Attack queues while batching their transport.
local packetLimit, fixedBytes, sourceBytes = 8192, 17, 2

return function(selectedUnits, targetIDs, options, giveOrderArrayToUnitArray)
	if #selectedUnits == 0 or #targetIDs == 0 then
		return false
	end
	local prepend = options.meta and not options.shift
	local baseOptions = options.ctrl and CMD.OPT_CTRL or 0
	local shiftedOptions = baseOptions + CMD.OPT_SHIFT
	-- IDs and parameter counts are shared by all commands. Replacing a queue
	-- mixes options (first Attack vs shifted tail), costing one byte per command.
	local commandBytes = prepend and 16 or ((options.shift or #targetIDs == 1) and 4 or 5)
	local sourceBatchSize = #selectedUnits
	if fixedBytes + sourceBytes * sourceBatchSize + commandBytes * #targetIDs > packetLimit then
		sourceBatchSize = math.min(sourceBatchSize, 256)
	end
	local commandsPerPacket = math.floor((packetLimit - fixedBytes - sourceBytes * sourceBatchSize) / commandBytes)

	for firstSource = 1, #selectedUnits, sourceBatchSize do
		local sources = {}
		for index = firstSource, math.min(firstSource + sourceBatchSize - 1, #selectedUnits) do
			sources[#sources + 1] = selectedUnits[index]
		end
		for firstCommand = 1, #targetIDs, commandsPerPacket do
			local commands = {}
			for index = firstCommand, math.min(firstCommand + commandsPerPacket - 1, #targetIDs) do
				if prepend then
					-- Every insertion is at zero; reverse the entire sequence, including
					-- packet boundaries, to preserve the requested final queue order.
					commands[#commands + 1] =
						{ CMD.INSERT, { 0, CMD.ATTACK, baseOptions, targetIDs[#targetIDs - index + 1] }, CMD.OPT_ALT }
				else
					local commandOptions = (options.shift or index > 1) and shiftedOptions or baseOptions
					commands[#commands + 1] = { CMD.ATTACK, { targetIDs[index] }, commandOptions }
				end
			end
			giveOrderArrayToUnitArray(sources, commands, false)
		end
	end
	return true
end
