--- Transfer's contribution to the mission sandbox. The loader composes the
--- authoring environment from the missions manifest's requires list; each
--- contributing module ships a mission_dsl.lua returning a per-file factory.
--- Missions gets this vocabulary because it requires transfer — the same
--- dependency that puts the edge on the module graph.

local TransferVerbs = VFS.Include("modules/transfer/lib/mission_verbs.lua")

return {
	-- No Finalize: transfer arms nothing at load.
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = { Transfer = TransferVerbs.MakeTransfer(file.groups or {}) } }
	end,
}
