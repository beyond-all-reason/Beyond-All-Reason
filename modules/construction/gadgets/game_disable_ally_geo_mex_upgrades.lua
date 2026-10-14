local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Extractor placement",
		desc = "Asks construction's placement decision for every extractor: an ally's spot is not upgraded in place, and a spot another team holds is not taken; at command time, so a refused order never queues",
		author = "Hobo Joe",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Construction = require("modules/construction/api")

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.BUILD)
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z)
	return Construction.MayPlace(unitDefID, builderTeam, x, y, z), false
end

function gadget:AllowCommand(_unitID, _unitDefID, unitTeam, cmdID, cmdParams)
	if cmdID >= 0 or #cmdParams < 3 or not Construction.IsExtractor(-cmdID) then
		return true
	end
	return Construction.MayPlace(-cmdID, unitTeam, cmdParams[1], cmdParams[2], cmdParams[3])
end
