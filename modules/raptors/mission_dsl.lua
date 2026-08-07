local Packs = VFS.Include("modules/raptors/lib/packs.lua")

return {
	-- No Finalize: naming a pack arms nothing, so a trigger file that fails
	-- to parse leaves no director behind.
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Raptors = Packs.Nouns } }
	end,
}
