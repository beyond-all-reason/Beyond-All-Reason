local Packs = VFS.Include("modules/scavengers/lib/packs.lua")

return {
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Scavengers = Packs.Nouns } }
	end,
}
