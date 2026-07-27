
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local MatchFlowVerbs = VFS.Include("modules/matchflow/lib/mission_verbs.lua")

local verbs = MatchFlowVerbs.Make(ModuleHandler.Get("matchflow"))

return {
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { MatchFlow = verbs } }
	end,
}
