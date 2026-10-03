-- Sends ordered target lists without exceeding the engine command packet limit.
-- Both area-command widgets use this path so source batching, Shift-append and
-- Space-prepend keep the same target order.

local CMD_UNIT_SET_TARGETS = GameCMD.UNIT_SET_TARGETS
local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS

-- Spring.GiveOrderToUnitArray uses NETMSG_AICOMMANDS. Its current wire format
-- has 17 bytes of fixed data, two bytes per source unit ID, and four bytes per
-- command parameter, and the engine drops packets larger than 8192 bytes.
local targetListPacketSizeLimit = 8192
local targetListPacketFixedSize = 17
local targetListSourceIDSize = 2
local targetListParamSize = 4
local targetListPreferredSourceBatchSize = 256
local insertCommandParamCount = 3

local function giveTargetList(listCommandID, selectedUnits, targetIDs, options, giveOrderToUnitArray)
	if not listCommandID or #targetIDs == 0 then
		return false
	end

	local baseCommandOptions = 0
	if options.shift then
		baseCommandOptions = baseCommandOptions + CMD.OPT_SHIFT
	end
	if options.ctrl then
		baseCommandOptions = baseCommandOptions + CMD.OPT_CTRL
	end
	if options.meta and listCommandID == CMD_UNIT_SET_TARGETS then
		baseCommandOptions = baseCommandOptions + CMD.OPT_META
	end

	local prepend = options.meta and not options.shift
	local extraParamCount = prepend and insertCommandParamCount or 0
	local maxTargetsPerPacket = math.floor(
		(
			targetListPacketSizeLimit
			- targetListPacketFixedSize
			- targetListPreferredSourceBatchSize * targetListSourceIDSize
		) / targetListParamSize
	) - extraParamCount

	local targetChunks = {}
	for firstTargetIndex = 1, #targetIDs, maxTargetsPerPacket do
		local lastTargetIndex = math.min(firstTargetIndex + maxTargetsPerPacket - 1, #targetIDs)
		local targetChunk = {}
		for targetIndex = firstTargetIndex, lastTargetIndex do
			targetChunk[#targetChunk + 1] = targetIDs[targetIndex]
		end
		targetChunks[#targetChunks + 1] = targetChunk
	end

	local function giveTargetChunk(targetChunk, chunkIndex)
		local commandOptions = baseCommandOptions
		if chunkIndex > 1 and not options.shift and (not prepend or listCommandID == CMD_ATTACK_TARGETS) then
			commandOptions = commandOptions + CMD.OPT_SHIFT
		end

		local commandID = listCommandID
		local params = targetChunk
		local outerOptions = commandOptions
		if prepend then
			params = { 0, listCommandID, commandOptions }
			for targetIndex = 1, #targetChunk do
				params[targetIndex + insertCommandParamCount] = targetChunk[targetIndex]
			end
			commandID = CMD.INSERT
			outerOptions = CMD.OPT_ALT
		end

		local packetParamCount = #targetChunk + extraParamCount
		local sourceBatchSize = math.floor(
			(targetListPacketSizeLimit - targetListPacketFixedSize - packetParamCount * targetListParamSize)
				/ targetListSourceIDSize
		)
		sourceBatchSize = math.max(1, math.min(sourceBatchSize, targetListPreferredSourceBatchSize))

		for firstSourceIndex = 1, #selectedUnits, sourceBatchSize do
			local lastSourceIndex = math.min(firstSourceIndex + sourceBatchSize - 1, #selectedUnits)
			local sourceBatch = {}
			for sourceIndex = firstSourceIndex, lastSourceIndex do
				sourceBatch[#sourceBatch + 1] = selectedUnits[sourceIndex]
			end
			giveOrderToUnitArray(sourceBatch, commandID, params, outerOptions)
		end
	end

	if prepend then
		-- Every insert is placed at queue position zero. Send chunks backwards so
		-- they end up in their original order. Set Target consumes each inserted
		-- command immediately and prepends it; Attack keeps shifted later chunks
		-- adjacent so its controller can combine them.
		for chunkIndex = #targetChunks, 1, -1 do
			giveTargetChunk(targetChunks[chunkIndex], chunkIndex)
		end
	else
		for chunkIndex = 1, #targetChunks do
			giveTargetChunk(targetChunks[chunkIndex], chunkIndex)
		end
	end
	return true
end

return giveTargetList
